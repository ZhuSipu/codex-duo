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
    private let codexBundleIdentifier = "com.openai.codex"
    private let localUsageReader = LocalCodexUsageReader()
    private let localUsageStore = LocalUsageStore()
    private let localUsageMergeLock = NSLock()
    private let localUsageStateLock = NSLock()
    private var observedActiveAccountKey: String?
    private var activeAccountObservedAt = Date()

    var registryURL: URL {
        self.fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/accounts/registry.json", isDirectory: false)
    }

    var isAvailable: Bool { self.executableURL() != nil }

    var versionText: String? {
        guard let executableURL = self.executableURL() else { return nil }
        let result = self.runExecutable(path: executableURL.path, arguments: ["--version"])
        guard result.succeeded else { return nil }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
        let command = "\(self.shellQuote(executableURL.path)) login"
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "tell application \"Terminal\" to do script \"\(escaped)\"\ntell application \"Terminal\" to activate"
        return self.runExecutable(path: "/usr/bin/osascript", arguments: ["-e", appleScript])
    }

    func switchAccountAndRestartCodex(selector: String, expectedAccountKey: String) -> CommandResult {
        let stopResult = self.stopCodexApp()
        guard stopResult.succeeded else { return stopResult }

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
        return CommandResult(status: 0, stdout: switchResult.stdout, stderr: "")
    }

    func activateRefreshedAccountAndRestartCodex(selector: String, expectedAccountKey: String) -> CommandResult {
        let stopResult = self.stopCodexApp()
        guard stopResult.succeeded else { return stopResult }

        let switchResult = self.runCodexAuth(arguments: CodexAuthCommands.switchAccount(selector: selector))
        guard switchResult.succeeded else {
            _ = self.openCodexApp()
            return switchResult
        }

        do {
            let registry = try self.loadRegistry()
            guard registry.activeAccountKey == expectedAccountKey else {
                _ = self.openCodexApp()
                return CommandResult(status: 2, stdout: switchResult.stdout, stderr: "The active account did not match the refreshed account.")
            }
        } catch {
            _ = self.openCodexApp()
            return CommandResult(status: 3, stdout: switchResult.stdout, stderr: error.localizedDescription)
        }

        guard let codexURL = self.codexExecutableURL() else {
            _ = self.openCodexApp()
            return CommandResult(status: 127, stdout: switchResult.stdout, stderr: "Codex CLI was not found, so the refreshed window could not be activated.")
        }
        let activation = self.runExecutable(
            path: codexURL.path,
            arguments: CodexAuthCommands.activateQuota(),
            currentDirectoryURL: self.fileManager.temporaryDirectory,
            timeout: 45,
            captureOutput: false)
        guard activation.succeeded else {
            _ = self.openCodexApp()
            return activation
        }

        _ = self.runCodexAuth(arguments: ["list", "--active"], timeout: 30, captureOutput: false)
        let launchResult = self.openCodexApp()
        guard launchResult.succeeded else { return launchResult }
        return CommandResult(status: 0, stdout: activation.stdout, stderr: "")
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

    private func executableURL() -> URL? {
        let candidates = [
            self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/codex-auth"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex-auth"),
            URL(fileURLWithPath: "/usr/local/bin/codex-auth"),
        ]
        return candidates.first { self.fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func codexExecutableURL() -> URL? {
        let candidates = [
            self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex"),
        ]
        return candidates.first { self.fileManager.isExecutableFile(atPath: $0.path) }
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
        if inheritSystemProxy,
           let settings = SCDynamicStoreCopyProxies(nil) as? [String: Any]
        {
            environment = Self.applyingSystemProxySettings(settings, to: environment)
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

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
