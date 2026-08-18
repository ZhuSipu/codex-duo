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
        precondition(registry.otherAccount()?.accountKey == "account-b")

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
