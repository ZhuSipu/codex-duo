namespace CodexDuo.Windows;

public static class CodexAuthCommands
{
    public static IReadOnlyList<string> SwitchAccount(string accountKey) => ["switch", accountKey];
    public static IReadOnlyList<string> SetAlias(string accountKey, string? alias) => string.IsNullOrWhiteSpace(alias)
        ? ["alias", "clear", accountKey]
        : ["alias", "set", accountKey, alias.Trim()];
    public static IReadOnlyList<string> RemoveAccount(string accountKey) => ["remove", accountKey];
}
