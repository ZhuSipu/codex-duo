using System.Text.Json.Serialization;

namespace CodexDuo.Windows;

public sealed class CodexRegistry
{
    public const int MaximumSupportedAccounts = 10;
    [JsonPropertyName("schema_version")] public int SchemaVersion { get; init; }
    [JsonPropertyName("active_account_key")] public string? ActiveAccountKey { get; init; }
    [JsonPropertyName("accounts")] public List<CodexAccount> Accounts { get; init; } = [];

    [JsonIgnore] public CodexAccount? ActiveAccount => Accounts.FirstOrDefault(x => x.AccountKey == ActiveAccountKey);
    [JsonIgnore] public IReadOnlyList<CodexAccount> MenuAccounts
    {
        get
        {
            if (Accounts.Count <= MaximumSupportedAccounts) return Accounts;
            var result = Accounts.Take(MaximumSupportedAccounts).ToList();
            var active = ActiveAccount;
            if (active is not null && result.All(x => x.AccountKey != active.AccountKey)) result[^1] = active;
            return result;
        }
    }
}

public sealed class CodexAccount
{
    [JsonPropertyName("account_key")] public string AccountKey { get; init; } = "";
    [JsonPropertyName("email")] public string Email { get; init; } = "";
    [JsonPropertyName("alias")] public string? Alias { get; init; }
    [JsonPropertyName("plan")] public string? Plan { get; init; }
    [JsonPropertyName("last_usage")] public UsageSnapshot? LastUsage { get; init; }
    [JsonPropertyName("last_usage_at")] public long? LastUsageAt { get; init; }
    [JsonIgnore] public string DisplayName => string.IsNullOrWhiteSpace(Alias) ? Email : Alias.Trim();
    [JsonIgnore] public string CompactName => DisplayName.Length == 0 ? "?" : DisplayName[..1].ToUpperInvariant();
}

public sealed class UsageSnapshot
{
    [JsonPropertyName("primary")] public RateLimitWindow? Primary { get; init; }
    [JsonPropertyName("secondary")] public RateLimitWindow? Secondary { get; init; }
    public RateLimitWindow? Window(int minutes) => Primary?.WindowMinutes == minutes ? Primary : Secondary?.WindowMinutes == minutes ? Secondary : null;
    [JsonIgnore] public RateLimitWindow? FiveHour => Window(300);
    [JsonIgnore] public RateLimitWindow? Weekly => Window(10_080);
}

public sealed class RateLimitWindow
{
    [JsonPropertyName("used_percent")] public double UsedPercent { get; init; }
    [JsonPropertyName("window_minutes")] public int? WindowMinutes { get; init; }
    [JsonPropertyName("resets_at")] public double? ResetsAt { get; init; }
    public int RemainingPercent(DateTimeOffset? now = null)
    {
        var current = now ?? DateTimeOffset.Now;
        if (ResetsAt is not null && ResetsAt <= current.ToUnixTimeSeconds()) return 100;
        return Math.Clamp((int)Math.Floor(100 - UsedPercent), 0, 100);
    }
    public string? ResetText(DateTimeOffset? now = null)
    {
        if (ResetsAt is null) return null;
        var seconds = Math.Max(0, (int)Math.Ceiling(ResetsAt.Value - (now ?? DateTimeOffset.Now).ToUnixTimeSeconds()));
        if (seconds == 0) return "now";
        var totalMinutes = Math.Max(1, (int)Math.Ceiling(seconds / 60d));
        var days = totalMinutes / 1440; var hours = totalMinutes % 1440 / 60; var minutes = totalMinutes % 60;
        if (days > 0) return hours > 0 ? $"{days}d {hours}h" : minutes > 0 ? $"{days}d {minutes}min" : $"{days}d";
        return hours > 0 ? (minutes > 0 ? $"{hours}h {minutes}min" : $"{hours}h") : $"{minutes}min";
    }
}
