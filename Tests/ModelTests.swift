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
        precondition(registry.accounts[0].codexAuthSelector == "first")
        precondition(registry.accounts[1].codexAuthSelector == "second@example.com")
        precondition(registry.activeAccount?.accountKey == "account-a")
        precondition(registry.switchTarget(accountKey: "account-a") == nil)
        precondition(registry.switchTarget(accountKey: "account-b")?.email == "second@example.com")

        let localLine = #"{"timestamp":"2026-08-25T11:34:31.137Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":6.0,"window_minutes":10080,"resets_at":1788260768},"secondary":null}}}"#
        let localSample = LocalCodexUsageReader.parseLine(localLine)
        precondition(localSample?.snapshot.weekly?.remainingPercent() == 94)
        let mergedRegistry = registry.replacingActiveUsage(with: localSample!.snapshot, observedAt: localSample!.observedAt)
        precondition(mergedRegistry.activeAccount?.lastUsage?.weekly?.remainingPercent() == 94)
        let inactiveRegistry = registry.replacingUsage(
            for: "account-b",
            with: localSample!.snapshot,
            observedAt: localSample!.observedAt)
        precondition(inactiveRegistry.accounts[1].lastUsage?.weekly?.remainingPercent() == 94)
        precondition(inactiveRegistry.accounts[0].lastUsage?.weekly?.remainingPercent() == 40)
        precondition(mergedRegistry.accounts[1].lastUsage?.weekly?.remainingPercent() == 90)
        precondition(LocalCodexUsageReader.parseLine(#"{"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"other"}}}"#) == nil)
        let dualWindowLine = #"{"timestamp":"2026-08-25T14:42:07.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":2.0,"window_minutes":300,"resets_at":1787686864},"secondary":{"used_percent":0.0,"window_minutes":10080,"resets_at":1788273664}}}}"#
        let dualWindowSample = LocalCodexUsageReader.parseLine(dualWindowLine)
        precondition(dualWindowSample?.snapshot.fiveHour?.remainingPercent(now: Date(timeIntervalSince1970: 1_787_668_000)) == 98)
        precondition(dualWindowSample?.snapshot.weekly?.remainingPercent(now: Date(timeIntervalSince1970: 1_787_668_000)) == 100)

        let matchingFixture = #"{"schema_version":4,"active_account_key":"account-a","accounts":[{"account_key":"account-a","email":"a@example.com","alias":null,"plan":"plus","last_usage_at":100,"last_usage":{"primary":{"used_percent":10,"window_minutes":10080,"resets_at":1000000},"secondary":null}},{"account_key":"account-b","email":"b@example.com","alias":null,"plan":"plus","last_usage_at":100,"last_usage":{"primary":{"used_percent":20,"window_minutes":10080,"resets_at":1200000},"secondary":null}}]}"#
        let matchingRegistry = try JSONDecoder().decode(CodexRegistry.self, from: Data(matchingFixture.utf8))
        let accountASample = LocalUsageSample(
            observedAt: Date(timeIntervalSince1970: 200),
            snapshot: UsageSnapshot(
                primary: RateLimitWindow(usedPercent: 67, windowMinutes: 10_080, resetsAt: 1_000_030),
                secondary: nil))
        precondition(matchingRegistry.uniqueAccountKey(matching: accountASample) == "account-a")
        let reconciledRegistry = matchingRegistry.mergingLocalUsage(["account-a": accountASample])
        precondition(reconciledRegistry.accounts[0].lastUsage?.weekly?.remainingPercent(now: Date(timeIntervalSince1970: 300)) == 33)
        precondition(reconciledRegistry.accounts[1].lastUsage?.weekly?.remainingPercent(now: Date(timeIntervalSince1970: 300)) == 80)
        precondition(reconciledRegistry.accounts[0].usageAgeText(now: Date(timeIntervalSince1970: 1_100)) == "15M OLD")
        precondition(reconciledRegistry.accounts[0].usageAgeText(now: Date(timeIntervalSince1970: 7_400)) == "2H OLD")
        precondition(reconciledRegistry.accounts[0].usageAgeText(now: Date(timeIntervalSince1970: 173_000)) == "2D OLD")
        let addedFiveHour = LocalUsageSample(
            observedAt: Date(timeIntervalSince1970: 201),
            snapshot: UsageSnapshot(
                primary: RateLimitWindow(usedPercent: 2, windowMinutes: 300, resetsAt: 18_000),
                secondary: RateLimitWindow(usedPercent: 67, windowMinutes: 10_080, resetsAt: 1_000_030)))
        let registryWithAddedWindow = matchingRegistry.mergingLocalUsage(["account-a": addedFiveHour])
        precondition(registryWithAddedWindow.accounts[0].lastUsage?.fiveHour?.remainingPercent(now: Date(timeIntervalSince1970: 300)) == 98)

        let olderSample = LocalUsageSample(
            observedAt: Date(timeIntervalSince1970: 50),
            snapshot: accountASample.snapshot)
        precondition(!matchingRegistry.accounts[0].acceptsLocalUsage(olderSample))
        precondition(matchingRegistry.mergingLocalUsage(["account-a": olderSample]).accounts[0].lastUsageAt == 100)

        let ambiguousFixture = #"{"schema_version":4,"active_account_key":"account-a","accounts":[{"account_key":"account-a","email":"a@example.com","alias":null,"plan":"plus","last_usage_at":0,"last_usage":{"primary":{"used_percent":10,"window_minutes":10080,"resets_at":1000000},"secondary":null}},{"account_key":"account-b","email":"b@example.com","alias":null,"plan":"plus","last_usage_at":0,"last_usage":{"primary":{"used_percent":20,"window_minutes":10080,"resets_at":1000300},"secondary":null}}]}"#
        let ambiguousRegistry = try JSONDecoder().decode(CodexRegistry.self, from: Data(ambiguousFixture.utf8))
        precondition(ambiguousRegistry.uniqueAccountKey(matching: accountASample) == nil)

        let usageStoreSuite = "CodexDuoUsageStoreTests.\(UUID().uuidString)"
        guard let usageDefaults = UserDefaults(suiteName: usageStoreSuite) else { fatalError("Unable to create usage defaults") }
        defer { usageDefaults.removePersistentDomain(forName: usageStoreSuite) }
        let usageStore = LocalUsageStore(defaults: usageDefaults)
        usageStore.save(["account-a": accountASample])
        precondition(usageStore.load()["account-a"]?.snapshot.weekly?.usedPercent == 67)
        usageStore.save([:])
        precondition(usageStore.load().isEmpty)

        let readerRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexDuoReaderTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: readerRoot) }
        let oldSessionDirectory = readerRoot.appendingPathComponent("2026/08/22", isDirectory: true)
        try FileManager.default.createDirectory(at: oldSessionDirectory, withIntermediateDirectories: true)
        let readerFixture = [
            #"{"timestamp":"2026-08-22T10:00:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":60.0,"window_minutes":10080,"resets_at":2000000},"secondary":null}}}"#,
            #"{"timestamp":"2026-08-22T10:01:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":67.0,"window_minutes":10080,"resets_at":2000200},"secondary":null}}}"#,
            #"{"timestamp":"2026-08-22T10:02:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":25.0,"window_minutes":10080,"resets_at":3000000},"secondary":null}}}"#,
        ].joined(separator: "\n")
        try Data(readerFixture.utf8).write(to: oldSessionDirectory.appendingPathComponent("rollout-test.jsonl"))
        let reader = LocalCodexUsageReader(sessionsRoot: readerRoot)
        let readerNow = ISO8601DateFormatter().date(from: "2026-08-25T12:00:00Z")!
        let recoveredSamples = reader.latestSamples(
            notBefore: ISO8601DateFormatter().date(from: "2026-08-18T12:00:00Z")!,
            now: readerNow)
        precondition(recoveredSamples.count == 2)
        precondition(recoveredSamples.contains(where: { $0.snapshot.weekly?.usedPercent == 67 }))

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
        precondition(preferences.language == .system)
        precondition(preferences.refreshInterval == .twoMinutes)
        precondition(preferences.autoActivateRefreshedAccounts)
        preferences.appearanceMode = .dark
        preferences.language = .simplifiedChinese
        preferences.refreshInterval = .off
        preferences.autoActivateRefreshedAccounts = false
        precondition(preferences.appearanceMode == .dark)
        precondition(preferences.language == .simplifiedChinese)
        precondition(SettingsText.value("accounts", language: .simplifiedChinese) == "账户")
        precondition(SettingsText.value("refreshNow", language: .japanese) == "更新")
        precondition(SettingsText.value("appearance", language: .french) == "Apparence")
        for language in AppLanguage.allCases.dropFirst() {
            precondition(SettingsText.value("window.title", language: language) != "window.title")
            precondition(!language.displayName.isEmpty)
        }
        precondition(preferences.refreshInterval == .off)
        precondition(!preferences.autoActivateRefreshedAccounts)
        preferences.autoActivateRefreshedAccounts = true
        let activationNow = Date(timeIntervalSince1970: 200_000)
        precondition(preferences.shouldAttemptAutoActivation(accountKey: "account-a", boundary: 190_000, now: activationNow))
        preferences.recordAutoActivationAttempt(accountKey: "account-a", at: activationNow)
        precondition(!preferences.shouldAttemptAutoActivation(accountKey: "account-a", boundary: 190_000, now: activationNow))
        preferences.recordAutoActivationSuccess(accountKey: "account-a", at: activationNow)
        precondition(!preferences.shouldAttemptAutoActivation(accountKey: "account-a", boundary: 190_000, now: activationNow.addingTimeInterval(4_000)))
        precondition(preferences.autoActivationStart(accountKey: "account-a") == activationNow)

        let selector = "unique@example.com"
        precondition(CodexAuthCommands.switchAccount(selector: selector) == ["switch", selector])
        precondition(CodexAuthCommands.removeAccount(selector: selector) == ["remove", selector])
        precondition(CodexAuthCommands.setAlias(selector: selector, alias: "work") == ["alias", "set", selector, "work"])
        precondition(CodexAuthCommands.setAlias(selector: selector, alias: "  ") == ["alias", "clear", selector])
        precondition(!CodexAuthCommands.removeAccount(selector: selector).contains("--skip-api"))
        let activationCommand = CodexAuthCommands.activateQuota()
        precondition(activationCommand.first == "exec")
        precondition(activationCommand.contains("--ephemeral"))
        precondition(activationCommand.contains("--ignore-user-config"))
        precondition(activationCommand.contains("read-only"))
        precondition(activationCommand.contains("gpt-5.4-mini"))
        precondition(activationCommand.contains("model_reasoning_effort=\"low\""))
        precondition(activationCommand.last == CodexAuthCommands.activationPrompt)
        let timedOutRefresh = CodexAuthService.normalizedUsageRefreshResult(
            CommandResult(status: 0, stdout: "01 account Plus TimedOut TimedOut", stderr: ""))
        precondition(!timedOutRefresh.succeeded)
        precondition(timedOutRefresh.stderr.contains("newest verified local values"))
        let freshRefresh = CodexAuthService.normalizedUsageRefreshResult(
            CommandResult(status: 0, stdout: "01 account Plus 80% 70%", stderr: ""))
        precondition(freshRefresh.succeeded)
        let proxySettings: [String: Any] = [
            "HTTPEnable": 1, "HTTPProxy": "proxy.internal.example", "HTTPPort": 8080,
            "HTTPSEnable": 1, "HTTPSProxy": "secure-proxy.example", "HTTPSPort": 8443,
            "SOCKSEnable": 1, "SOCKSProxy": "socks-proxy.example", "SOCKSPort": 1080,
            "ExceptionsList": ["127.0.0.1", "localhost"],
        ]
        let proxyEnvironment = CodexAuthService.applyingSystemProxySettings(proxySettings, to: ["PATH": "/usr/bin"])
        precondition(proxyEnvironment["HTTP_PROXY"] == "http://proxy.internal.example:8080")
        precondition(proxyEnvironment["https_proxy"] == "http://secure-proxy.example:8443")
        precondition(proxyEnvironment["ALL_PROXY"] == "socks5h://socks-proxy.example:1080")
        precondition(proxyEnvironment["NO_PROXY"] == "127.0.0.1,localhost")
        let preservedProxy = CodexAuthService.applyingSystemProxySettings(
            proxySettings,
            to: ["https_proxy": "http://custom:9000"])
        precondition(preservedProxy["https_proxy"] == "http://custom:9000")
        precondition(preservedProxy["HTTPS_PROXY"] == nil)

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

        let expiredFixture = #"{"schema_version":4,"active_account_key":"account-a","accounts":[{"account_key":"account-a","email":"first@example.com","alias":null,"plan":"plus","last_usage_at":null,"last_usage":{"primary":{"used_percent":0,"window_minutes":10080,"resets_at":99000},"secondary":null}}]}"#
        let expiredRegistry = try JSONDecoder().decode(CodexRegistry.self, from: Data(expiredFixture.utf8))
        precondition(expiredRegistry.accounts[0].weeklyRefreshBoundary(comparedTo: nil, now: testNow) == 99_000)

        let advancedFixture = #"{"schema_version":4,"active_account_key":"account-a","accounts":[{"account_key":"account-a","email":"first@example.com","alias":null,"plan":"plus","last_usage_at":null,"last_usage":{"primary":{"used_percent":0,"window_minutes":10080,"resets_at":704800},"secondary":null}}]}"#
        let advancedRegistry = try JSONDecoder().decode(CodexRegistry.self, from: Data(advancedFixture.utf8))
        precondition(advancedRegistry.accounts[0].weeklyRefreshBoundary(comparedTo: expiredRegistry.accounts[0], now: testNow) == 100_000)

        let dormantFixture = #"{"schema_version":4,"active_account_key":"account-a","accounts":[{"account_key":"account-a","email":"first@example.com","alias":null,"plan":"plus","last_usage_at":null,"last_usage":{"primary":{"used_percent":0,"window_minutes":10080,"resets_at":670660},"secondary":null}}]}"#
        let dormantRegistry = try JSONDecoder().decode(CodexRegistry.self, from: Data(dormantFixture.utf8))
        precondition(dormantRegistry.accounts[0].weeklyRefreshBoundary(comparedTo: nil, now: testNow) == 65_860)
        let dormantWindow = dormantRegistry.accounts[0].lastUsage!.weekly!
        precondition(dormantWindow.resetText(now: testNow) == "6d 14h")
        precondition(dormantWindow.displayResetText(activationStart: nil, now: testNow) == "7d")
        precondition(dormantWindow.displayResetText(
            activationStart: testNow.addingTimeInterval(-46_800),
            now: testNow) == "6d 11h")

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
