import Foundation

enum StatusItemPresentation {
    static func title(for registry: CodexRegistry) -> String {
        let accounts = registry.menuAccounts
        guard !accounts.isEmpty else { return "—" }

        let active = accounts.first { $0.accountKey == registry.activeAccountKey }
        var candidates: [CodexAccount] = []
        if let active, self.remainingPercent(for: active) != nil {
            candidates.append(active)
        }
        candidates.append(contentsOf: accounts.filter { account in
            account.accountKey != active?.accountKey && self.remainingPercent(for: account) != nil
        })

        let summaries = candidates.prefix(2).compactMap { account -> String? in
            guard let remaining = self.remainingPercent(for: account) else { return nil }
            return "\(account.compactName) \(remaining)%"
        }
        return summaries.isEmpty ? "—" : summaries.joined(separator: " · ")
    }

    private static func remainingPercent(for account: CodexAccount) -> Int? {
        account.lastUsage?.preferredStatusWindow?.remainingPercent()
    }
}
