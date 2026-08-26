import Foundation

struct CodexRegistry: Decodable {
    static let maximumSupportedAccounts = 10

    let schemaVersion: Int
    let activeAccountKey: String?
    let accounts: [CodexAccount]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case activeAccountKey = "active_account_key"
        case accounts
    }

    var menuAccounts: [CodexAccount] {
        guard self.accounts.count > Self.maximumSupportedAccounts else { return self.accounts }
        var result = Array(self.accounts.prefix(Self.maximumSupportedAccounts))
        if let activeAccountKey,
           !result.contains(where: { $0.accountKey == activeAccountKey }),
           let active = self.accounts.first(where: { $0.accountKey == activeAccountKey })
        {
            result[result.count - 1] = active
        }
        return result
    }

    var activeAccount: CodexAccount? {
        guard let activeAccountKey else { return nil }
        return self.accounts.first { $0.accountKey == activeAccountKey }
    }

    func switchTarget(accountKey: String) -> CodexAccount? {
        guard accountKey != self.activeAccountKey else { return nil }
        return self.menuAccounts.first { $0.accountKey == accountKey }
    }

    func replacingActiveUsage(with snapshot: UsageSnapshot, observedAt: Date) -> CodexRegistry {
        guard let activeAccountKey else { return self }
        return self.replacingUsage(
            for: activeAccountKey,
            with: snapshot,
            observedAt: observedAt)
    }

    func replacingUsage(for accountKey: String, with snapshot: UsageSnapshot, observedAt: Date) -> CodexRegistry {
        let updated = self.accounts.map { account in
            guard account.accountKey == accountKey else { return account }
            return CodexAccount(
                accountKey: account.accountKey,
                email: account.email,
                alias: account.alias,
                plan: account.plan,
                lastUsage: snapshot,
                lastUsageAt: Int64(observedAt.timeIntervalSince1970))
        }
        return CodexRegistry(schemaVersion: self.schemaVersion, activeAccountKey: activeAccountKey, accounts: updated)
    }

    func mergingLocalUsage(_ samplesByAccount: [String: LocalUsageSample]) -> CodexRegistry {
        samplesByAccount.reduce(self) { registry, entry in
            guard let account = registry.accounts.first(where: { $0.accountKey == entry.key }),
                  account.acceptsLocalUsage(entry.value)
            else { return registry }
            return registry.replacingUsage(
                for: entry.key,
                with: entry.value.snapshot,
                observedAt: entry.value.observedAt)
        }
    }

    func uniqueAccountKey(matching sample: LocalUsageSample) -> String? {
        guard let localReset = sample.snapshot.weekly?.resetsAt else { return nil }
        let candidates = self.accounts.compactMap { account -> (String, TimeInterval)? in
            guard let cachedReset = account.lastUsage?.weekly?.resetsAt else { return nil }
            let distance = abs(cachedReset - localReset)
            return distance <= 86_400 ? (account.accountKey, distance) : nil
        }.sorted { $0.1 < $1.1 }
        guard let best = candidates.first else { return nil }
        if candidates.count > 1, candidates[1].1 - best.1 < 3_600 { return nil }
        return best.0
    }

    static func preview(accountCount: Int) -> CodexRegistry {
        let count = max(1, min(Self.maximumSupportedAccounts, accountCount))
        let accounts = (0..<count).map { index in
            let used = Double((index * 13 + 17) % 92)
            return CodexAccount(
                accountKey: "preview-\(index)",
                email: "account\(index + 1)@example.com",
                alias: nil,
                plan: "plus",
                lastUsage: UsageSnapshot(
                    primary: RateLimitWindow(
                        usedPercent: used,
                        windowMinutes: 10_080,
                        resetsAt: Date().addingTimeInterval(Double(index + 1) * 43_200).timeIntervalSince1970),
                    secondary: nil),
                lastUsageAt: nil)
        }
        return CodexRegistry(
            schemaVersion: 4,
            activeAccountKey: accounts[min(1, accounts.count - 1)].accountKey,
            accounts: accounts)
    }
}

struct CodexAccount: Decodable {
    let accountKey: String
    let email: String
    let alias: String?
    let plan: String?
    let lastUsage: UsageSnapshot?
    let lastUsageAt: Int64?

    enum CodingKeys: String, CodingKey {
        case accountKey = "account_key"
        case email
        case alias
        case plan
        case lastUsage = "last_usage"
        case lastUsageAt = "last_usage_at"
    }

    var displayName: String {
        let cleanedAlias = self.alias?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedAlias?.isEmpty == false ? cleanedAlias! : self.email
    }

    var codexAuthSelector: String { self.displayName }

    var compactName: String {
        if let alias = self.alias?.trimmingCharacters(in: .whitespacesAndNewlines), !alias.isEmpty {
            return String(alias.prefix(1)).uppercased()
        }
        return String(self.email.prefix(1)).uppercased()
    }

    func acceptsLocalUsage(_ sample: LocalUsageSample) -> Bool {
        guard sample.observedAt.timeIntervalSince1970 > TimeInterval(self.lastUsageAt ?? 0),
              let cachedReset = self.lastUsage?.weekly?.resetsAt,
              let localReset = sample.snapshot.weekly?.resetsAt
        else { return false }
        return abs(cachedReset - localReset) <= 86_400
    }

    func usageAgeText(now: Date = Date()) -> String? {
        guard self.lastUsage != nil, let lastUsageAt = self.lastUsageAt else { return nil }
        let seconds = max(0, Int(now.timeIntervalSince1970) - Int(lastUsageAt))
        guard seconds >= 900 else { return nil }
        if seconds < 3_600 { return "\(seconds / 60)M OLD" }
        if seconds < 86_400 { return "\(seconds / 3_600)H OLD" }
        return "\(seconds / 86_400)D OLD"
    }

    func weeklyRefreshBoundary(comparedTo previous: CodexAccount?, now: Date = Date()) -> TimeInterval? {
        guard let current = self.lastUsage?.weekly,
              let currentReset = current.resetsAt
        else { return nil }

        let nowSeconds = now.timeIntervalSince1970
        if currentReset <= nowSeconds { return currentReset }
        if current.remainingPercent(now: now) == 100 {
            let duration = TimeInterval((current.windowMinutes ?? 10_080) * 60)
            return currentReset - duration
        }

        guard let previousWindow = previous?.lastUsage?.weekly,
              let previousReset = previousWindow.resetsAt,
              previousReset <= nowSeconds,
              currentReset > previousReset
        else { return nil }
        return previousReset
    }
}

struct UsageSnapshot: Codable {
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?

    func window(minutes: Int) -> RateLimitWindow? {
        if self.primary?.windowMinutes == minutes { return self.primary }
        if self.secondary?.windowMinutes == minutes { return self.secondary }
        return nil
    }

    var fiveHour: RateLimitWindow? { self.window(minutes: 300) }
    var weekly: RateLimitWindow? { self.window(minutes: 10_080) }
}

struct RateLimitWindow: Codable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case windowMinutes = "window_minutes"
        case resetsAt = "resets_at"
    }

    func remainingPercent(now: Date = Date()) -> Int {
        if let resetsAt = self.resetsAt, resetsAt <= now.timeIntervalSince1970 { return 100 }
        return max(0, min(100, Int((100 - self.usedPercent).rounded(.down))))
    }

    func resetText(now: Date = Date()) -> String? {
        guard let resetsAt = self.resetsAt else { return nil }
        let seconds = max(0, Int(ceil(resetsAt - now.timeIntervalSince1970)))
        if seconds == 0 { return "now" }
        let totalMinutes = max(1, Int(ceil(Double(seconds) / 60.0)))

        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            if hours > 0 { return "\(days)d \(hours)h" }
            if minutes > 0 { return "\(days)d \(minutes)min" }
            return "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        }
        return "\(minutes)min"
    }

    func displayResetText(activationStart: Date?, now: Date = Date()) -> String? {
        guard self.windowMinutes == 10_080, self.remainingPercent(now: now) == 100 else {
            return self.resetText(now: now)
        }
        if let activationStart {
            let anchoredReset = activationStart.addingTimeInterval(604_800).timeIntervalSince1970
            if anchoredReset > now.timeIntervalSince1970 {
                let anchoredWindow = RateLimitWindow(
                    usedPercent: self.usedPercent,
                    windowMinutes: self.windowMinutes,
                    resetsAt: anchoredReset)
                return anchoredWindow.resetText(now: now)
            }
        }
        return "7d"
    }
}
