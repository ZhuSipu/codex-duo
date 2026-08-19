import Foundation

@main
enum ModelTests {
    static func main() throws {
        let fixture = #"""
        {
          "schema_version": 4,
          "active_account_key": "account-a",
          "accounts": [
            {
              "account_key": "account-a",
              "email": "first@example.com",
              "alias": "first",
              "plan": "plus",
              "last_usage_at": 123,
              "last_usage": {
                "primary": {"used_percent": 25, "window_minutes": 300, "resets_at": 4102444800},
                "secondary": {"used_percent": 60, "window_minutes": 10080, "resets_at": 4102444800}
              }
            },
            {
              "account_key": "account-b",
              "email": "second@example.com",
              "alias": null,
              "plan": "plus",
              "last_usage_at": null,
              "last_usage": {
                "primary": {"used_percent": 10, "window_minutes": 10080, "resets_at": 4102444800},
                "secondary": null
              }
            }
          ]
        }
        """#

        let registry = try JSONDecoder().decode(CodexRegistry.self, from: Data(fixture.utf8))
        precondition(registry.schemaVersion == 4)
        precondition(registry.accounts.count == 2)
        precondition(registry.accounts[0].displayName == "first")
        precondition(registry.accounts[0].lastUsage?.fiveHour?.remainingPercent() == 75)
        precondition(registry.accounts[0].lastUsage?.weekly?.remainingPercent() == 40)
        precondition(registry.accounts[1].lastUsage?.fiveHour == nil)
        precondition(registry.accounts[1].lastUsage?.weekly?.remainingPercent() == 90)
        precondition(registry.activeAccount?.accountKey == "account-a")
        precondition(registry.switchTarget(accountKey: "account-a") == nil)
        precondition(registry.switchTarget(accountKey: "account-b")?.email == "second@example.com")

        let manyAccountObjects = (0..<12).map { index in
            """
            {"account_key":"account-\(index)","email":"user\(index)@example.com","alias":null,"plan":"plus","last_usage_at":null,"last_usage":null}
            """
        }.joined(separator: ",")
        let manyFixture = """
        {"schema_version":4,"active_account_key":"account-11","accounts":[\(manyAccountObjects)]}
        """
        let manyRegistry = try JSONDecoder().decode(CodexRegistry.self, from: Data(manyFixture.utf8))
        precondition(manyRegistry.accounts.count == 12)
        precondition(manyRegistry.menuAccounts.count == 10)
        precondition(manyRegistry.menuAccounts.last?.accountKey == "account-11")
        precondition(manyRegistry.switchTarget(accountKey: "account-10") == nil)
        precondition(manyRegistry.switchTarget(accountKey: "account-8")?.email == "user8@example.com")
        precondition(manyRegistry.switchTarget(accountKey: "account-11") == nil)
        precondition(CodexRegistry.preview(accountCount: 0).menuAccounts.count == 1)
        precondition(CodexRegistry.preview(accountCount: 10).menuAccounts.count == 10)
        precondition(CodexRegistry.preview(accountCount: 11).menuAccounts.count == 10)

        let preferenceSuite = "CodexDuoTests.\(UUID().uuidString)"
        guard let testDefaults = UserDefaults(suiteName: preferenceSuite) else { fatalError("Unable to create test defaults") }
        defer { testDefaults.removePersistentDomain(forName: preferenceSuite) }
        let preferences = AppPreferences(defaults: testDefaults)
        precondition(preferences.appearanceMode == .system)
        precondition(preferences.refreshInterval == .twoMinutes)
        preferences.appearanceMode = .dark
        preferences.refreshInterval = .off
        precondition(preferences.appearanceMode == .dark)
        precondition(preferences.refreshInterval == .off)

        let testNow = Date(timeIntervalSince1970: 100_000)
        let countdown = RateLimitWindow(
            usedPercent: 20,
            windowMinutes: 300,
            resetsAt: 188_260)
        precondition(countdown.resetText(now: testNow) == "1d 31min")

        let weeklyReset: TimeInterval = 670_660
        let weeklyCountdown = RateLimitWindow(
            usedPercent: 20,
            windowMinutes: 10_080,
            resetsAt: weeklyReset)
        precondition(weeklyCountdown.resetText(now: testNow) == "6d 14h")

        let hourlyReset: TimeInterval = 111_520
        let hourlyCountdown = RateLimitWindow(
            usedPercent: 20,
            windowMinutes: 300,
            resetsAt: hourlyReset)
        precondition(hourlyCountdown.resetText(now: testNow) == "3h 12min")

        precondition(RateLimitWindow(
            usedPercent: 20,
            windowMinutes: 300,
            resetsAt: 101_860).resetText(
                now: testNow) == "31min")
        print("Model tests passed")
    }
}
