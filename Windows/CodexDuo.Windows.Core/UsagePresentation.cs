namespace CodexDuo.Windows.Core;

public sealed record UsageMeterPresentation(string Label, int? Remaining, string? Reset)
{
    public bool HasReset => !string.IsNullOrWhiteSpace(Reset);
    public bool IsLow => Remaining < 40;
    public string PercentageText => Remaining is null ? "—" : $"{Remaining}%";
}

public static class AccountUsagePresentation
{
    public static IReadOnlyList<UsageMeterPresentation> Build(
        CodexAccount account,
        AppSettings settings,
        DateTimeOffset now)
    {
        var result = new List<UsageMeterPresentation>(2);
        if (account.LastUsage?.FiveHour is { } fiveHour)
        {
            result.Add(new UsageMeterPresentation("5H", fiveHour.RemainingPercent(now), fiveHour.ResetText(now)));
        }
        if (account.LastUsage?.Weekly is { } weekly)
        {
            result.Add(new UsageMeterPresentation(
                "WEEK",
                weekly.RemainingPercent(now),
                weekly.DisplayResetText(settings.ActivationStart(account.AccountKey), now)));
        }
        if (result.Count == 0) result.Add(new UsageMeterPresentation("USAGE", null, null));
        return result;
    }
}
