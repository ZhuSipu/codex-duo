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

        let countdown = RateLimitWindow(
            usedPercent: 20,
            windowMinutes: 300,
            resetsAt: 100_000 + 86_400 + 31 * 60)
        precondition(countdown.resetText(now: Date(timeIntervalSince1970: 100_000)) == "1d 31min")
        precondition(RateLimitWindow(
            usedPercent: 20,
            windowMinutes: 10_080,
            resetsAt: 100_000 + 6 * 86_400 + 14 * 3_600 + 31 * 60).resetText(
                now: Date(timeIntervalSince1970: 100_000)) == "6d 14h")
        precondition(RateLimitWindow(
            usedPercent: 20,
            windowMinutes: 300,
            resetsAt: 100_000 + 3 * 3_600 + 12 * 60).resetText(
                now: Date(timeIntervalSince1970: 100_000)) == "3h 12min")
        precondition(RateLimitWindow(
            usedPercent: 20,
            windowMinutes: 300,
            resetsAt: 100_000 + 31 * 60).resetText(
                now: Date(timeIntervalSince1970: 100_000)) == "31min")
        print("Model tests passed")
    }
}
