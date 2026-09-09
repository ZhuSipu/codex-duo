import Foundation

enum CodexAuthCommands {
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
}
