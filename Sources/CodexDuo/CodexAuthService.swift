import Foundation

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

    var registryURL: URL {
        self.fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/accounts/registry.json", isDirectory: false)
    }

    func loadRegistry() throws -> CodexRegistry {
        let data = try Data(contentsOf: self.registryURL)
        return try JSONDecoder().decode(CodexRegistry.self, from: data)
    }

    func refreshUsage() -> CommandResult {
        self.runCodexAuth(arguments: ["list"])
    }

    func switchAccountAndRestartCodex(selector: String, expectedAccountKey: String) -> CommandResult {
        let quitResult = self.quitCodexApp()
        if !quitResult.succeeded, self.isCodexAppRunning() {
            return quitResult
        }

        self.waitForCodexAppToExit(timeout: 10)
        if self.isCodexAppRunning() {
            _ = self.runExecutable(path: "/usr/bin/pkill", arguments: ["-TERM", "-x", "ChatGPT"])
            self.waitForCodexAppToExit(timeout: 4)
        }

        let switchResult = self.runCodexAuth(arguments: ["switch", selector])
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

    private func quitCodexApp() -> CommandResult {
        guard self.isCodexAppRunning() else {
            return CommandResult(status: 0, stdout: "", stderr: "")
        }
        return self.runExecutable(
            path: "/usr/bin/osascript",
            arguments: ["-e", "tell application id \"\(self.codexBundleIdentifier)\" to quit"])
    }

    private func openCodexApp() -> CommandResult {
        self.runExecutable(path: "/usr/bin/open", arguments: ["-b", self.codexBundleIdentifier])
    }

    private func isCodexAppRunning() -> Bool {
        let result = self.runExecutable(
            path: "/usr/bin/osascript",
            arguments: ["-e", "application id \"\(self.codexBundleIdentifier)\" is running"])
        return result.succeeded && result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
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

    private func runCodexAuth(arguments: [String]) -> CommandResult {
        guard let executableURL = self.executableURL() else {
            return CommandResult(status: 127, stdout: "", stderr: "codex-auth was not found.")
        }
        return self.runExecutable(path: executableURL.path, arguments: arguments)
    }

    private func runExecutable(path: String, arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        let extraPath = self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path
        environment["PATH"] = "\(extraPath):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
            process.waitUntilExit()
            let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return CommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
        } catch {
            return CommandResult(status: 126, stdout: "", stderr: error.localizedDescription)
        }
    }
}
