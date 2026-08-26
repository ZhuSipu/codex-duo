using System.Text.Json.Serialization;

namespace CodexDuo.Windows.Core;

public sealed class CodexRegistry
{
    public const int MaximumSupportedAccounts = 10;

    [JsonPropertyName("schema_version")]
    public int SchemaVersion { get; init; }

    [JsonPropertyName("active_account_key")]
    public string? ActiveAccountKey { get; init; }

    [JsonPropertyName("accounts")]
    public List<CodexAccount> Accounts { get; init; } = [];

    [JsonIgnore]
    public IReadOnlyList<CodexAccount> DisplayAccounts
    {
        get
        {
            if (Accounts.Count <= MaximumSupportedAccounts)
            {
                return Accounts;
            }

            var result = Accounts.Take(MaximumSupportedAccounts).ToList();
            if (!string.IsNullOrWhiteSpace(ActiveAccountKey)
                && result.All(account => account.AccountKey != ActiveAccountKey)
                && Accounts.FirstOrDefault(account => account.AccountKey == ActiveAccountKey) is { } active)
            {
                result[^1] = active;
            }

            return result;
        }
    }

    [JsonIgnore]
    public CodexAccount? ActiveAccount => Accounts.FirstOrDefault(account => account.AccountKey == ActiveAccountKey);

    public CodexAccount? SwitchTarget(string accountKey) =>
        accountKey == ActiveAccountKey ? null : DisplayAccounts.FirstOrDefault(account => account.AccountKey == accountKey);
}

public sealed class CodexAccount
{
    [JsonPropertyName("account_key")]
    public string AccountKey { get; init; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; init; } = string.Empty;

    [JsonPropertyName("alias")]
    public string? Alias { get; init; }

    [JsonPropertyName("plan")]
    public string? Plan { get; init; }

    [JsonPropertyName("last_usage")]
    public UsageSnapshot? LastUsage { get; init; }

    [JsonPropertyName("last_usage_at")]
    public long? LastUsageAt { get; init; }

    [JsonIgnore]
    public string DisplayName => string.IsNullOrWhiteSpace(Alias) ? Email : Alias.Trim();

    [JsonIgnore]
    public string CommandSelector => DisplayName;

    public string? UsageAgeText(DateTimeOffset now)
    {
        if (LastUsage is null || LastUsageAt is null)
        {
            return null;
        }

        var seconds = Math.Max(0, now.ToUnixTimeSeconds() - LastUsageAt.Value);
        return seconds switch
        {
            < 900 => null,
            < 3_600 => $"{seconds / 60}M OLD",
            < 86_400 => $"{seconds / 3_600}H OLD",
            _ => $"{seconds / 86_400}D OLD",
        };
    }

    public long? WeeklyRefreshBoundary(CodexAccount? previous, DateTimeOffset now)
    {
        var current = LastUsage?.Weekly;
        if (current?.ResetsAt is not { } currentReset)
        {
            return null;
        }

        if (currentReset <= now.ToUnixTimeSeconds())
        {
            return (long)Math.Floor(currentReset);
        }

        if (current.RemainingPercent(now) == 100)
        {
            return (long)Math.Floor(currentReset - (current.WindowMinutes ?? 10_080) * 60d);
        }

        var previousReset = previous?.LastUsage?.Weekly?.ResetsAt;
        if (previousReset is not null && previousReset <= now.ToUnixTimeSeconds() && currentReset > previousReset)
        {
            return (long)Math.Floor(previousReset.Value);
        }

        return null;
    }
}

public sealed class UsageSnapshot
{
    [JsonPropertyName("primary")]
    public RateLimitWindow? Primary { get; init; }

    [JsonPropertyName("secondary")]
    public RateLimitWindow? Secondary { get; init; }

    [JsonIgnore]
    public RateLimitWindow? FiveHour => Window(300);

    [JsonIgnore]
    public RateLimitWindow? Weekly => Window(10_080);

    public RateLimitWindow? Window(int minutes)
    {
        if (Primary?.WindowMinutes == minutes)
        {
            return Primary;
        }

        return Secondary?.WindowMinutes == minutes ? Secondary : null;
    }
}

public sealed class RateLimitWindow
{
    [JsonPropertyName("used_percent")]
    public double UsedPercent { get; init; }

    [JsonPropertyName("window_minutes")]
    public int? WindowMinutes { get; init; }

    [JsonPropertyName("resets_at")]
    public double? ResetsAt { get; init; }

    public int RemainingPercent(DateTimeOffset now)
    {
        if (ResetsAt is not null && ResetsAt <= now.ToUnixTimeSeconds())
        {
            return 100;
        }

        return Math.Clamp((int)Math.Floor(100d - UsedPercent), 0, 100);
    }

    public string? ResetText(DateTimeOffset now)
    {
        if (ResetsAt is null)
        {
            return null;
        }

        var seconds = Math.Max(0, (long)Math.Ceiling(ResetsAt.Value - now.ToUnixTimeMilliseconds() / 1000d));
        if (seconds == 0)
        {
            return "now";
        }

        var totalMinutes = Math.Max(1, (long)Math.Ceiling(seconds / 60d));
        var days = totalMinutes / 1_440;
        var hours = totalMinutes % 1_440 / 60;
        var minutes = totalMinutes % 60;

        if (days > 0)
        {
            return hours > 0 ? $"{days}d {hours}h" : minutes > 0 ? $"{days}d {minutes}min" : $"{days}d";
        }

        return hours > 0 ? (minutes > 0 ? $"{hours}h {minutes}min" : $"{hours}h") : $"{minutes}min";
    }

    public string? DisplayResetText(DateTimeOffset? activationStart, DateTimeOffset now)
    {
        if (WindowMinutes != 10_080 || RemainingPercent(now) != 100)
        {
            return ResetText(now);
        }

        if (activationStart is { } start)
        {
            var anchoredReset = start.AddDays(7);
            if (anchoredReset > now)
            {
                return new RateLimitWindow
                {
                    UsedPercent = UsedPercent,
                    WindowMinutes = WindowMinutes,
                    ResetsAt = anchoredReset.ToUnixTimeMilliseconds() / 1000d,
                }.ResetText(now);
            }
        }

        return "7d";
    }
}
