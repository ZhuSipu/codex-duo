using System.Text.Json;
using CodexDuo.Windows.Core;

namespace CodexDuo.Windows.Tests;

public sealed class ModelTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.FromUnixTimeSeconds(2_000_000_000);

    [Fact]
    public void DisplayAccounts_PreservesActiveAccountBeyondLimit()
    {
        var accounts = Enumerable.Range(0, 12)
            .Select(index => new CodexAccount { AccountKey = $"key-{index}", Email = $"user-{index}@example.com" })
            .ToList();
        var registry = new CodexRegistry { ActiveAccountKey = "key-11", Accounts = accounts };

        Assert.Equal(10, registry.DisplayAccounts.Count);
        Assert.Equal("key-11", registry.DisplayAccounts[^1].AccountKey);
        Assert.DoesNotContain(registry.DisplayAccounts, account => account.AccountKey == "key-9");
    }

    [Fact]
    public void DisplayName_UsesTrimmedAliasAndFallsBackToEmail()
    {
        Assert.Equal("Work", new CodexAccount { Email = "mail@example.com", Alias = "  Work  " }.DisplayName);
        Assert.Equal("mail@example.com", new CodexAccount { Email = "mail@example.com", Alias = "  " }.DisplayName);
    }

    [Theory]
    [InlineData(0, 100)]
    [InlineData(0.1, 99)]
    [InlineData(42.9, 57)]
    [InlineData(101, 0)]
    [InlineData(-5, 100)]
    public void RemainingPercent_FloorsAndClamps(double used, int expected)
    {
        var window = new RateLimitWindow { UsedPercent = used, ResetsAt = Now.AddHours(1).ToUnixTimeSeconds() };
        Assert.Equal(expected, window.RemainingPercent(Now));
    }

    [Fact]
    public void RemainingPercent_ReturnsFullWhenExpired()
    {
        var window = new RateLimitWindow { UsedPercent = 80, ResetsAt = Now.ToUnixTimeSeconds() };
        Assert.Equal(100, window.RemainingPercent(Now));
        Assert.Equal("now", window.ResetText(Now));
    }

    [Theory]
    [InlineData(899, null)]
    [InlineData(900, "15M OLD")]
    [InlineData(3_600, "1H OLD")]
    [InlineData(86_400, "1D OLD")]
    public void UsageAgeText_UsesSpecificationThresholds(long age, string? expected)
    {
        var account = new CodexAccount
        {
            LastUsage = new UsageSnapshot(),
            LastUsageAt = Now.ToUnixTimeSeconds() - age,
        };
        Assert.Equal(expected, account.UsageAgeText(Now));
    }

    [Fact]
    public void ResetText_RoundsUpAndUsesDayHourMinutePrecision()
    {
        var window = new RateLimitWindow { ResetsAt = Now.ToUnixTimeSeconds() + 86_401 };
        Assert.Equal("1d 1min", window.ResetText(Now));
    }

    [Fact]
    public void FullWeeklyWindow_ShowsSevenDaysUntilActivated()
    {
        var window = new RateLimitWindow
        {
            UsedPercent = 0,
            WindowMinutes = 10_080,
            ResetsAt = Now.AddDays(7).ToUnixTimeSeconds(),
        };
        Assert.Equal("7d", window.DisplayResetText(null, Now));
        Assert.Equal("6d 23h", window.DisplayResetText(Now, Now.AddMinutes(1)));
    }

    [Fact]
    public void UsageSnapshot_OnlyReturnsPresentRecognizedWindows()
    {
        var snapshot = new UsageSnapshot
        {
            Primary = new RateLimitWindow { WindowMinutes = 10_080 },
        };
        Assert.Null(snapshot.FiveHour);
        Assert.Same(snapshot.Primary, snapshot.Weekly);
    }

    [Fact]
    public void RegistryJson_DecodesExternalSchema()
    {
        const string json = """
            {
              "schema_version": 4,
              "active_account_key": "account-1",
              "accounts": [{
                "account_key": "account-1",
                "email": "user@example.com",
                "alias": "Personal",
                "plan": "plus",
                "last_usage": {
                  "primary": {"used_percent": 12.5, "window_minutes": 10080, "resets_at": 2000001000},
                  "secondary": null
                },
                "last_usage_at": 2000000000
              }]
            }
            """;
        var registry = JsonSerializer.Deserialize<CodexRegistry>(json)!;
        Assert.Equal("account-1", registry.ActiveAccount?.AccountKey);
        Assert.Equal(87, registry.ActiveAccount?.LastUsage?.Weekly?.RemainingPercent(Now));
    }
}
