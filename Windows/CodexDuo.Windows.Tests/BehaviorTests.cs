using CodexDuo.Windows.Core;

namespace CodexDuo.Windows.Tests;

public sealed class BehaviorTests
{
    [Fact]
    public void Settings_DefaultsMatchSharedSpecification()
    {
        var settings = new AppSettings();
        Assert.Equal("system", settings.Appearance);
        Assert.Equal("system", settings.Language);
        Assert.Equal(120, settings.RefreshIntervalSeconds);
        Assert.False(settings.LaunchAtLogin);
        Assert.True(settings.AutoActivateRefreshedAccounts);
    }

    [Fact]
    public void Settings_NormalizeUnsupportedValues()
    {
        var settings = new AppSettings { Appearance = "neon", Language = "xx", RefreshIntervalSeconds = 42 };
        settings.Normalize();
        Assert.Equal("system", settings.Appearance);
        Assert.Equal("system", settings.Language);
        Assert.Equal(120, settings.RefreshIntervalSeconds);
    }

    [Fact]
    public void Activation_RetriesAfterOneHourAndNeverRepeatsSuccessfulWindow()
    {
        var now = DateTimeOffset.FromUnixTimeSeconds(2_000_000_000);
        var settings = new AppSettings();
        settings.AutoActivationAttempts["account"] = now.AddMinutes(-59).ToUnixTimeSeconds();
        Assert.False(settings.ShouldAttemptActivation("account", 1_900_000_000, now));

        settings.AutoActivationAttempts["account"] = now.AddHours(-1).ToUnixTimeSeconds();
        Assert.True(settings.ShouldAttemptActivation("account", 1_900_000_000, now));

        settings.AutoActivationSuccesses["account"] = 1_900_000_000;
        Assert.False(settings.ShouldAttemptActivation("account", 1_900_000_000, now));
    }

    [Fact]
    public void RefreshTimeoutMarker_IsFailureEvenWithZeroExitCode()
    {
        var normalized = CodexAuthService.NormalizeRefreshResult(new CommandResult(0, "Usage refresh: TimedOut", string.Empty));
        Assert.False(normalized.Succeeded);
        Assert.True(normalized.TimedOut);
        Assert.Equal(75, normalized.ExitCode);
    }

    [Fact]
    public void RefreshInvalidatedLogin_IsFailureEvenWithZeroExitCode()
    {
        var normalized = CodexAuthService.NormalizeRefreshResult(new CommandResult(
            0,
            "01 account@example.com Plus 401 token_invalidated 401 token_invalidated",
            string.Empty));

        Assert.False(normalized.Succeeded);
        Assert.Equal(77, normalized.ExitCode);
        Assert.Contains("Sign in", normalized.StandardError, StringComparison.Ordinal);
    }

    [Fact]
    public void SafeError_RedactsCredentialBearingOutput()
    {
        var result = new CommandResult(1, string.Empty, "Authorization: Bearer secret-token access_token=another-secret");
        var safe = result.SafeError("failed");
        Assert.DoesNotContain("secret-token", safe, StringComparison.Ordinal);
        Assert.DoesNotContain("another-secret", safe, StringComparison.Ordinal);
        Assert.Contains("[REDACTED]", safe, StringComparison.Ordinal);
    }

    [Fact]
    public void CommandBuilders_KeepSelectorsAsSingleArguments()
    {
        var selector = "name & whoami@example.com";
        Assert.Equal(["switch", selector, "--json"], CodexAuthCommands.SwitchAccount(selector));
        Assert.Equal(["switch", selector], CodexAuthCommands.LegacySwitchAccount(selector));
        Assert.Equal(["alias", "set", selector, "New Alias"], CodexAuthCommands.SetAlias(selector, " New Alias "));
        Assert.Equal(["remove", selector], CodexAuthCommands.RemoveAccount(selector));
    }

    [Fact]
    public void SwitchJson_AcceptsMatchingAccountKeyAndUnknownFields()
    {
        var json = """{"schema_version":1,"command":"switch","future":true,"switched_to":{"account_key":"key-1","future":"value"}}""";
        var normalized = CodexAuthService.NormalizeSwitchResult(new CommandResult(0, json, string.Empty), "key-1");
        Assert.True(normalized.Succeeded);
    }

    [Fact]
    public void SwitchJson_RejectsMismatchedAccountKey()
    {
        var json = """{"schema_version":1,"command":"switch","switched_to":{"account_key":"key-2"}}""";
        var normalized = CodexAuthService.NormalizeSwitchResult(new CommandResult(0, json, string.Empty), "key-1");
        Assert.False(normalized.Succeeded);
        Assert.Equal(65, normalized.ExitCode);
    }

    [Fact]
    public void SwitchJson_ReportsStateUncertainAsFailure()
    {
        var json = """{"schema_version":1,"error":{"code":"state_uncertain","message":"stored state may have changed"}}""";
        var normalized = CodexAuthService.NormalizeSwitchResult(new CommandResult(1, json, string.Empty), "key-1");
        Assert.False(normalized.Succeeded);
        Assert.Contains("stored state", normalized.StandardError, StringComparison.Ordinal);
    }

    [Fact]
    public void SwitchJson_OnlyFallsBackForOldCliUsageError()
    {
        Assert.True(CodexAuthService.JsonSwitchIsUnsupported(new CommandResult(2, string.Empty, "unknown option: --json")));
        Assert.False(CodexAuthService.JsonSwitchIsUnsupported(new CommandResult(1, string.Empty, "unknown option: --json")));
        Assert.False(CodexAuthService.JsonSwitchIsUnsupported(new CommandResult(2, "{\"error\":{\"code\":\"usage\"}}", string.Empty)));
    }

    [Fact]
    public void DetachedStartup_ParsesLaunchMetadata()
    {
        string[] arguments = [DetachedStartup.DetachedArgument, DetachedStartup.ParentArgument, "42", DetachedStartup.TaskArgument, "task-name"];
        Assert.True(DetachedStartup.IsDetachedLaunch(arguments));
        Assert.Equal("42", DetachedStartup.ValueAfter(arguments, DetachedStartup.ParentArgument));
        Assert.Equal("task-name", DetachedStartup.ValueAfter(arguments, DetachedStartup.TaskArgument));
    }

    [Fact]
    public void SettingsStore_RoundTripsWithoutCredentialData()
    {
        var directory = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "CodexDuoTests", Guid.NewGuid().ToString("N"));
        var path = System.IO.Path.Combine(directory, "settings.json");
        try
        {
            var store = new SettingsStore(path);
            store.Save(new AppSettings { Language = "zh-Hans", RefreshIntervalSeconds = 300 });
            var loaded = store.Load();
            Assert.Equal("zh-Hans", loaded.Language);
            Assert.Equal(300, loaded.RefreshIntervalSeconds);
            Assert.DoesNotContain("token", File.ReadAllText(path), StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }

    [Fact]
    public void SystemProxy_ImportsSingleWindowsProxyForHttpAndHttps()
    {
        var environment = new Dictionary<string, string?> { ["PATH"] = "C:\\Windows" };
        WindowsProxyEnvironment.ApplySettings(
            new Dictionary<string, object?>
            {
                ["ProxyEnable"] = 1,
                ["ProxyServer"] = "127.0.0.1:7897",
                ["ProxyOverride"] = "localhost;127.*;*.internal.example;<local>",
            },
            environment);

        Assert.Equal("http://127.0.0.1:7897", environment["HTTP_PROXY"]);
        Assert.Equal("http://127.0.0.1:7897", environment["HTTPS_PROXY"]);
        Assert.Equal("localhost,127.*,.internal.example,127.0.0.1,::1", environment["NO_PROXY"]);
    }

    [Fact]
    public void SystemProxy_ImportsProtocolSpecificAndSocksValues()
    {
        var environment = new Dictionary<string, string?>();
        WindowsProxyEnvironment.ApplySettings(
            new Dictionary<string, object?>
            {
                ["ProxyEnable"] = 1,
                ["ProxyServer"] = "http=proxy.example:8080;https=secure.example:8443;socks=127.0.0.1:1080",
            },
            environment);

        Assert.Equal("http://proxy.example:8080", environment["HTTP_PROXY"]);
        Assert.Equal("http://secure.example:8443", environment["HTTPS_PROXY"]);
        Assert.Equal("socks5h://127.0.0.1:1080", environment["ALL_PROXY"]);
    }

    [Fact]
    public void SystemProxy_PreservesExplicitEnvironmentVariables()
    {
        var environment = new Dictionary<string, string?>(StringComparer.Ordinal)
        {
            ["https_proxy"] = "http://custom.example:9000",
            ["NO_PROXY"] = "custom.internal",
        };
        WindowsProxyEnvironment.ApplySettings(
            new Dictionary<string, object?>
            {
                ["ProxyEnable"] = 1,
                ["ProxyServer"] = "127.0.0.1:7897",
                ["ProxyOverride"] = "localhost",
            },
            environment);

        Assert.Equal("http://127.0.0.1:7897", environment["HTTP_PROXY"]);
        Assert.Equal("http://custom.example:9000", environment["https_proxy"]);
        Assert.False(environment.ContainsKey("HTTPS_PROXY"));
        Assert.Equal("custom.internal", environment["NO_PROXY"]);
    }

    [Fact]
    public void SystemProxy_IgnoresDisabledSettings()
    {
        var environment = new Dictionary<string, string?>();
        WindowsProxyEnvironment.ApplySettings(
            new Dictionary<string, object?> { ["ProxyEnable"] = 0, ["ProxyServer"] = "127.0.0.1:7897" },
            environment);

        Assert.Empty(environment);
    }

    [Fact]
    public void UsagePresentation_AlwaysOrdersFiveHourBeforeWeekly()
    {
        var now = DateTimeOffset.FromUnixTimeSeconds(2_000_000_000);
        var account = new CodexAccount
        {
            AccountKey = "account",
            LastUsage = new UsageSnapshot
            {
                Primary = new RateLimitWindow { WindowMinutes = 10_080, UsedPercent = 44, ResetsAt = 2_000_500_000 },
                Secondary = new RateLimitWindow { WindowMinutes = 300, UsedPercent = 46, ResetsAt = 2_000_010_000 },
            },
        };

        var meters = AccountUsagePresentation.Build(account, new AppSettings(), now);

        Assert.Collection(
            meters,
            meter => { Assert.Equal("5H", meter.Label); Assert.Equal(54, meter.Remaining); },
            meter => { Assert.Equal("WEEK", meter.Label); Assert.Equal(56, meter.Remaining); });
    }

    [Fact]
    public void UsagePresentation_DoesNotFabricateMissingWindow()
    {
        var now = DateTimeOffset.FromUnixTimeSeconds(2_000_000_000);
        var account = new CodexAccount
        {
            LastUsage = new UsageSnapshot
            {
                Primary = new RateLimitWindow { WindowMinutes = 10_080, UsedPercent = 13, ResetsAt = 2_000_500_000 },
            },
        };

        var meter = Assert.Single(AccountUsagePresentation.Build(account, new AppSettings(), now));
        Assert.Equal("WEEK", meter.Label);
        Assert.Equal(87, meter.Remaining);
    }

    [Fact]
    public void UsagePresentation_ShowsUnavailableOnlyWhenNoKnownWindowExists()
    {
        var meter = Assert.Single(AccountUsagePresentation.Build(
            new CodexAccount(),
            new AppSettings(),
            DateTimeOffset.FromUnixTimeSeconds(2_000_000_000)));

        Assert.Equal("USAGE", meter.Label);
        Assert.Null(meter.Remaining);
    }

    [Theory]
    [InlineData(@"C:\Program Files\WindowsApps\OpenAI.Codex_26.820.7780.0_x64__2p2nqsd0c76g0\app\ChatGPT.exe", true)]
    [InlineData(@"C:\Users\person\AppData\Local\OpenAI\Codex\bin\build\codex.exe", false)]
    [InlineData(@"C:\Program Files\WindowsApps\OpenAI.ChatGPT_1.0.0.0_x64__abc\app\ChatGPT.exe", false)]
    [InlineData(@"C:\Tools\CodexDuo.exe", false)]
    public void CodexDesktopProcessDetection_OnlyMatchesPackagedCodexFrontend(string path, bool expected)
    {
        Assert.Equal(expected, CodexAppController.IsCodexDesktopExecutable(path));
    }

    [Theory]
    [InlineData(@"C:\Users\person\AppData\Local\OpenAI\Codex\bin\build\codex.exe", true)]
    [InlineData(@"C:\Tools\codex.exe", false)]
    [InlineData(@"C:\Users\person\AppData\Local\OpenAI\Codex\bin\build\CodexDuo.exe", false)]
    public void CodexBackendDetection_OnlyMatchesDesktopManagedBinary(string path, bool expected)
    {
        Assert.Equal(expected, CodexAppController.IsCodexDesktopBackendExecutable(path));
    }
}
