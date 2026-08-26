import Foundation

enum CodexAuthCommands {
    static let activationPrompt = "This is an automated quota-window activation from Codex Duo. Reply with OK only and do not use tools."

    static func switchAccount(selector: String) -> [String] {
        ["switch", selector]
    }

    static func setAlias(selector: String, alias: String?) -> [String] {
        if let alias, !alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ["alias", "set", selector, alias]
        }
        return ["alias", "clear", selector]
    }

    static func removeAccount(selector: String) -> [String] {
        ["remove", selector]
    }

    static func activateQuota() -> [String] {
        [
            "exec", "--ephemeral", "--ignore-user-config", "--ignore-rules",
            "--skip-git-repo-check", "--sandbox", "read-only",
            "--model", "gpt-5.4-mini", "--config", "model_reasoning_effort=\"low\"",
            self.activationPrompt,
        ]
    }
}
