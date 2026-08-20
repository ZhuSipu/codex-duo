import Foundation

enum CodexAuthCommands {
    static func switchAccount(accountKey: String) -> [String] {
        ["switch", accountKey]
    }

    static func setAlias(accountKey: String, alias: String?) -> [String] {
        if let alias, !alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ["alias", "set", accountKey, alias]
        }
        return ["alias", "clear", accountKey]
    }

    static func removeAccount(accountKey: String) -> [String] {
        ["remove", accountKey]
    }
}
