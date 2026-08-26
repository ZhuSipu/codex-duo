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
        Assert.Equal(["switch", selector], CodexAuthCommands.SwitchAccount(selector));
        Assert.Equal(["alias", "set", selector, "New Alias"], CodexAuthCommands.SetAlias(selector, " New Alias "));
        Assert.Equal(["remove", selector], CodexAuthCommands.RemoveAccount(selector));
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
}
