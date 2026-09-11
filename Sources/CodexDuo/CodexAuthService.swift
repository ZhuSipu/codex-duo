import AppKit
import Darwin
import Foundation
import SystemConfiguration

struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool { self.status == 0 }
}

final class CodexAuthService {
    static let shared = CodexAuthService()

    private let fileManager = FileManager.default
    private let customProxyURLProvider: () -> String
    private let bundledExecutableURLProvider: () -> URL?
    private let codexBundleIdentifier = "com.openai.codex"
    private let localUsageReader = LocalCodexUsageReader()
    private let localUsageStore = LocalUsageStore()
    private let localUsageMergeLock = NSLock()
    private let localUsageStateLock = NSLock()
    private var observedActiveAccountKey: String?
    private var activeAccountObservedAt = Date()

    init(
        customProxyURLProvider: @escaping () -> String = { AppPreferences.shared.customProxyURL },
        bundledExecutableURLProvider: @escaping () -> URL? = {
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Helpers/codex-auth", isDirectory: false)
        })
    {
        self.customProxyURLProvider = customProxyURLProvider
        self.bundledExecutableURLProvider = bundledExecutableURLProvider
    }

    var registryURL: URL {
        self.fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/accounts/registry.json", isDirectory: false)
    }

    var isAvailable: Bool { self.executableURL() != nil }

    func loadRegistry() throws -> CodexRegistry {
        let data = try Data(contentsOf: self.registryURL)
        let registry = try JSONDecoder().decode(CodexRegistry.self, from: data)
        guard let activeKey = registry.activeAccountKey else { return registry }
        self.localUsageMergeLock.lock()
        defer { self.localUsageMergeLock.unlock() }

        let now = Date()
        self.localUsageStateLock.lock()
        let previousActiveKey = self.observedActiveAccountKey
        let previousThreshold = self.activeAccountObservedAt
        if self.observedActiveAccountKey == nil {
            self.observedActiveAccountKey = activeKey
            self.activeAccountObservedAt = now.addingTimeInterval(-600)
        } else if self.observedActiveAccountKey != activeKey {
            self.observedActiveAccountKey = activeKey
            self.activeAccountObservedAt = now
        }
        let threshold = self.activeAccountObservedAt
        self.localUsageStateLock.unlock()

        let historyThreshold = now.addingTimeInterval(-604_800)
        let samples = self.localUsageReader.latestSamples(notBefore: min(threshold, historyThreshold))
        var stored = self.localUsageStore.load().filter { key, _ in
            registry.accounts.contains(where: { $0.accountKey == key })
        }

        func retainNewest(_ sample: LocalUsageSample, for accountKey: String) {
            if stored[accountKey].map({ $0.observedAt >= sample.observedAt }) == true { return }
            stored[accountKey] = sample
        }

        if let previousActiveKey, previousActiveKey != activeKey,
           let previousAccount = registry.accounts.first(where: { $0.accountKey == previousActiveKey }),
           let sample = samples.filter({
               $0.observedAt >= previousThreshold && $0.observedAt <= now && previousAccount.acceptsLocalUsage($0)
           }).max(by: { $0.observedAt < $1.observedAt })
        {
            retainNewest(sample, for: previousActiveKey)
        }
        if let activeAccount = registry.activeAccount,
           let sample = samples.filter({
               $0.observedAt >= threshold && activeAccount.acceptsLocalUsage($0)
           }).max(by: { $0.observedAt < $1.observedAt })
        {
            retainNewest(sample, for: activeKey)
        }
        for sample in samples {
            guard let accountKey = registry.uniqueAccountKey(matching: sample),
                  let account = registry.accounts.first(where: { $0.accountKey == accountKey }),
                  account.acceptsLocalUsage(sample)
            else { continue }
            retainNewest(sample, for: accountKey)
        }

        stored = stored.filter { key, sample in
            registry.accounts.first(where: { $0.accountKey == key })?.acceptsLocalUsage(sample) == true
        }
        self.localUsageStore.save(stored)
        return registry.mergingLocalUsage(stored)
    }

    func refreshUsage() -> CommandResult {
        Self.normalizedUsageRefreshResult(
            self.runCodexAuth(arguments: ["list"], timeout: 30))
    }

    static func normalizedUsageRefreshResult(_ result: CommandResult) -> CommandResult {
        guard result.succeeded, result.stdout.localizedCaseInsensitiveContains("TimedOut") else { return result }
        return CommandResult(
            status: 75,
            stdout: result.stdout,
            stderr: "The usage API timed out. Showing the newest verified local values; inactive accounts update after Codex observes them.")
    }

    func setAlias(selector: String, alias: String?) -> CommandResult {
        self.runCodexAuth(arguments: CodexAuthCommands.setAlias(selector: selector, alias: alias))
    }

    func removeAccount(selector: String) -> CommandResult {
        self.runCodexAuth(arguments: CodexAuthCommands.removeAccount(selector: selector))
    }

    func openLoginInTerminal() -> CommandResult {
        guard let executableURL = self.executableURL() else {
            return CommandResult(status: 127, stdout: "", stderr: "codex-auth was not found.")
        }
        let scriptURL = self.fileManager.temporaryDirectory
            .appendingPathComponent("codex-duo-login-\(UUID().uuidString).command")
        let outcomeURL = scriptURL.deletingPathExtension().appendingPathExtension("result")
        let script = Self.loginScript(
            executablePath: executableURL.path,
            scriptPath: scriptURL.path,
            outcomePath: outcomeURL.path)
        do {
            try Data(script.utf8).write(to: scriptURL, options: .atomic)
            try self.fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)
        } catch {
            return CommandResult(status: 126, stdout: "", stderr: "Unable to prepare the login window: \(error.localizedDescription)")
        }

        let result = self.runExecutable(
            path: "/usr/bin/open",
            arguments: ["-a", "Terminal", scriptURL.path])
        guard result.succeeded else {
            try? self.fileManager.removeItem(at: scriptURL)
            return result
        }
        return CommandResult(status: 0, stdout: outcomeURL.path, stderr: "")
    }

    static func loginScript(executablePath: String, scriptPath: String, outcomePath: String) -> String {
        let executable = Self.shellQuoted(executablePath)
        let script = Self.shellQuoted(scriptPath)
        let outcome = Self.shellQuoted(outcomePath)
        return """
        #!/bin/zsh
        login_script=\(script)
        outcome_file=\(outcome)
        trap 'rm -f -- "$login_script"' EXIT
        printf '\\nCodex Duo account login\\n\\n'
        \(executable) login
        login_status=$?
        printf '%d' $login_status > "$outcome_file"
        if [[ $login_status -eq 0 ]]; then
          printf '\\nLogin complete. Return to Codex Duo.\\n'
          sleep 1
        else
          printf '\\nLogin failed (exit %d). Review the message above.\\n' $login_status
          printf 'Press Return to close this window. '
          read -r _
        fi
        exit $login_status
        """
    }

    func switchAccountAndRestartCodex(selector: String, expectedAccountKey: String) -> CommandResult {
        let stopResult = self.stopCodexApp()
        guard stopResult.succeeded else { return stopResult }

        let switchStartedAt = Date()
        let switchResult = self.runCodexAuth(arguments: CodexAuthCommands.switchAccount(selector: selector))
        guard switchResult.succeeded else {
            _ = self.openCodexApp()
            return switchResult
        }

        do {
            let registry = try self.loadRegistry()
            guard registry.activeAccountKey == expectedAccountKey else {
                _ = self.openCodexApp()
                return CommandResult(
                    status: 2,
                    stdout: switchResult.stdout,
                    stderr: "codex-auth completed, but the active account did not match the requested account.")
            }
        } catch {
            _ = self.openCodexApp()
            return CommandResult(status: 3, stdout: switchResult.stdout, stderr: error.localizedDescription)
        }

        let launchResult = self.openCodexApp()
        guard launchResult.succeeded else { return launchResult }
        guard self.waitForCodexAppToLaunch(after: switchStartedAt, timeout: 10) else {
            return CommandResult(
                status: 6,
                stdout: switchResult.stdout,
                stderr: "Codex did not restart with the selected account.")
        }
        return CommandResult(status: 0, stdout: switchResult.stdout, stderr: "")
    }

    func isCodexRuntimeSynchronized(with registry: CodexRegistry) -> Bool {
        let applications = NSRunningApplication.runningApplications(withBundleIdentifier: self.codexBundleIdentifier)
        return Self.runtimeIsSynchronized(
            appIsRunning: !applications.isEmpty,
            launchDate: applications.compactMap(\.launchDate).min(),
            activationTimeMilliseconds: registry.activeAccountActivatedAtMS)
    }

    static func runtimeIsSynchronized(
        appIsRunning: Bool,
        launchDate: Date?,
        activationTimeMilliseconds: Int64?) -> Bool
    {
        guard appIsRunning else { return true }
        guard let activationTimeMilliseconds else { return true }
        guard let launchDate else { return false }
        let activationDate = Date(timeIntervalSince1970: Double(activationTimeMilliseconds) / 1_000)
        return launchDate.addingTimeInterval(1) >= activationDate
    }

    private func stopCodexApp() -> CommandResult {
        var applications = NSRunningApplication.runningApplications(withBundleIdentifier: self.codexBundleIdentifier)
        guard !applications.isEmpty else { return CommandResult(status: 0, stdout: "", stderr: "") }

        applications.forEach { _ = $0.terminate() }
        self.waitForCodexAppToExit(timeout: 3)
        applications = NSRunningApplication.runningApplications(withBundleIdentifier: self.codexBundleIdentifier)
        applications.forEach { _ = $0.forceTerminate() }
        self.waitForCodexAppToExit(timeout: 3)

        guard !self.isCodexAppRunning() else {
            return CommandResult(status: 5, stdout: "", stderr: "Codex could not be restarted because it did not close.")
        }
        return CommandResult(status: 0, stdout: "", stderr: "")
    }

    private func openCodexApp() -> CommandResult {
        self.runExecutable(path: "/usr/bin/open", arguments: ["-b", self.codexBundleIdentifier])
    }

    private func isCodexAppRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: self.codexBundleIdentifier).isEmpty
    }

    private func waitForCodexAppToExit(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, self.isCodexAppRunning() {
            Thread.sleep(forTimeInterval: 0.25)
        }
    }

    private func waitForCodexAppToLaunch(after earliestLaunchDate: Date, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let applications = NSRunningApplication.runningApplications(withBundleIdentifier: self.codexBundleIdentifier)
            if applications.contains(where: { ($0.launchDate ?? .distantPast) >= earliestLaunchDate }) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    private func executableURL() -> URL? {
        let externalCandidates = [
            self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/codex-auth"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex-auth"),
            URL(fileURLWithPath: "/usr/local/bin/codex-auth"),
        ]
        return Self.preferredExecutableURL(
            bundledURL: self.bundledExecutableURLProvider(),
            externalURLs: externalCandidates,
            fileManager: self.fileManager)
    }

    static func preferredExecutableURL(
        bundledURL: URL?,
        externalURLs: [URL],
        fileManager: FileManager = .default) -> URL?
    {
        ([bundledURL].compactMap { $0 } + externalURLs).first {
            fileManager.isExecutableFile(atPath: $0.path)
        }
    }

    private func runCodexAuth(
        arguments: [String],
        timeout: TimeInterval? = nil,
        captureOutput: Bool = true) -> CommandResult
    {
        guard let executableURL = self.executableURL() else {
            return CommandResult(status: 127, stdout: "", stderr: "codex-auth was not found.")
        }
        return self.runExecutable(
            path: executableURL.path,
            arguments: arguments,
            timeout: timeout,
            captureOutput: captureOutput,
            inheritSystemProxy: true)
    }

    static func applyingSystemProxySettings(
        _ settings: [String: Any],
        to source: [String: String]) -> [String: String]
    {
        var environment = source

        func enabled(_ key: String) -> Bool {
            (settings[key] as? NSNumber)?.boolValue == true
        }
        func proxyURL(scheme: String, hostKey: String, portKey: String) -> String? {
            guard let host = settings[hostKey] as? String, !host.isEmpty,
                  let port = (settings[portKey] as? NSNumber)?.intValue, port > 0
            else { return nil }
            let formattedHost = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
            return "\(scheme)://\(formattedHost):\(port)"
        }
        func setProxy(_ value: String?, upper: String, lower: String) {
            guard let value, environment[upper] == nil, environment[lower] == nil else { return }
            environment[upper] = value
            environment[lower] = value
        }

        if enabled("HTTPEnable") {
            setProxy(proxyURL(scheme: "http", hostKey: "HTTPProxy", portKey: "HTTPPort"), upper: "HTTP_PROXY", lower: "http_proxy")
        }
        if enabled("HTTPSEnable") {
            setProxy(proxyURL(scheme: "http", hostKey: "HTTPSProxy", portKey: "HTTPSPort"), upper: "HTTPS_PROXY", lower: "https_proxy")
        }
        if enabled("SOCKSEnable") {
            setProxy(proxyURL(scheme: "socks5h", hostKey: "SOCKSProxy", portKey: "SOCKSPort"), upper: "ALL_PROXY", lower: "all_proxy")
        }
        if environment["NO_PROXY"] == nil, environment["no_proxy"] == nil,
           let exceptions = settings["ExceptionsList"] as? [String], !exceptions.isEmpty
        {
            let value = exceptions.joined(separator: ",")
            environment["NO_PROXY"] = value
            environment["no_proxy"] = value
        }
        return environment
    }

    static func normalizedProxyURL(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https", "socks5", "socks5h"].contains(scheme),
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              components.port.map({ (1...65_535).contains($0) }) ?? true
        else { return nil }
        return trimmed
    }

    static func applyingProxyConfiguration(
        customProxyURL: String,
        systemSettings: [String: Any]?,
        to source: [String: String]) -> [String: String]
    {
        guard !Self.containsProxyConfiguration(source) else { return source }
        if let proxyURL = Self.normalizedProxyURL(customProxyURL), !proxyURL.isEmpty {
            return Self.applyingCustomProxyURL(proxyURL, to: source)
        }
        guard let systemSettings else { return source }
        return Self.applyingSystemProxySettings(systemSettings, to: source)
    }

    private static func containsProxyConfiguration(_ environment: [String: String]) -> Bool {
        ["HTTP_PROXY", "http_proxy", "HTTPS_PROXY", "https_proxy", "ALL_PROXY", "all_proxy"].contains {
            environment[$0]?.isEmpty == false
        }
    }

    private static func applyingCustomProxyURL(_ proxyURL: String, to source: [String: String]) -> [String: String] {
        guard let scheme = URLComponents(string: proxyURL)?.scheme?.lowercased() else { return source }
        var environment = source
        switch scheme {
        case "http", "https":
            environment["HTTP_PROXY"] = proxyURL
            environment["http_proxy"] = proxyURL
            environment["HTTPS_PROXY"] = proxyURL
            environment["https_proxy"] = proxyURL
        case "socks5", "socks5h":
            environment["ALL_PROXY"] = proxyURL
            environment["all_proxy"] = proxyURL
        default:
            break
        }
        return environment
    }

    private func runExecutable(
        path: String,
        arguments: [String],
        currentDirectoryURL: URL? = nil,
        timeout: TimeInterval? = nil,
        captureOutput: Bool = true,
        inheritSystemProxy: Bool = false) -> CommandResult
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        var environment = ProcessInfo.processInfo.environment
        let extraPath = self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path
        environment["PATH"] = "\(extraPath):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if inheritSystemProxy {
            environment = Self.applyingProxyConfiguration(
                customProxyURL: self.customProxyURLProvider(),
                systemSettings: SCDynamicStoreCopyProxies(nil) as? [String: Any],
                to: environment)
        }
        process.environment = environment

        let output = captureOutput ? Pipe() : nil
        let errors = captureOutput ? Pipe() : nil
        process.standardOutput = output ?? Pipe()
        process.standardError = errors ?? Pipe()
        if !captureOutput {
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        do {
            try process.run()
            if let timeout {
                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
                if process.isRunning {
                    process.terminate()
                    let terminateDeadline = Date().addingTimeInterval(2)
                    while process.isRunning, Date() < terminateDeadline { Thread.sleep(forTimeInterval: 0.1) }
                    if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
                    process.waitUntilExit()
                    return CommandResult(status: 124, stdout: "", stderr: "Command timed out after \(Int(timeout)) seconds.")
                }
            } else {
                process.waitUntilExit()
            }
            let stdout = output.map { String(data: $0.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "" } ?? ""
            let stderr = errors.map { String(data: $0.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "" } ?? ""
            return CommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
        } catch {
            return CommandResult(status: 126, stdout: "", stderr: error.localizedDescription)
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
