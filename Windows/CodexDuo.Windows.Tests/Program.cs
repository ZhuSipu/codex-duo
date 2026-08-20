using System.Text.Json;
using CodexDuo.Windows;

const string fixture = """
{"schema_version":4,"active_account_key":"account-a","accounts":[
 {"account_key":"account-a","email":"first@example.com","alias":"first","plan":"plus","last_usage":{"primary":{"used_percent":25,"window_minutes":300,"resets_at":4102444800},"secondary":{"used_percent":60,"window_minutes":10080,"resets_at":4102444800}}},
 {"account_key":"account-b","email":"second@example.com","alias":null,"plan":"plus","last_usage":{"primary":{"used_percent":10,"window_minutes":10080,"resets_at":4102444800},"secondary":null}}
]}
""";
var registry = JsonSerializer.Deserialize<CodexRegistry>(fixture) ?? throw new Exception("Decode failed");
Assert(registry.SchemaVersion == 4 && registry.Accounts.Count == 2, "registry shape");
Assert(registry.ActiveAccount?.AccountKey == "account-a", "active account");
Assert(registry.Accounts[0].DisplayName == "first", "alias display");
Assert(registry.Accounts[0].LastUsage?.FiveHour?.RemainingPercent() == 75, "5-hour quota");
Assert(registry.Accounts[0].LastUsage?.Weekly?.RemainingPercent() == 40, "weekly quota");
var many = new CodexRegistry { ActiveAccountKey = "11", Accounts = Enumerable.Range(0, 12).Select(i => new CodexAccount { AccountKey = i.ToString(), Email = $"user{i}@example.com" }).ToList() };
Assert(many.MenuAccounts.Count == 10 && many.MenuAccounts[^1].AccountKey == "11", "ten-account cap retains active account");
var now = DateTimeOffset.FromUnixTimeSeconds(100_000);
Assert(new RateLimitWindow { UsedPercent = 20, ResetsAt = 188_260 }.ResetText(now) == "1d 31min", "day countdown");
Assert(new RateLimitWindow { UsedPercent = 20, ResetsAt = 111_520 }.ResetText(now) == "3h 12min", "hour countdown");
const string accountKey = "user-id::workspace-id";
Assert(CodexAuthCommands.SwitchAccount(accountKey).SequenceEqual(["switch", accountKey]), "switch uses unique account key");
Assert(CodexAuthCommands.RemoveAccount(accountKey).SequenceEqual(["remove", accountKey]), "remove uses selector mode without incompatible flags");
Assert(CodexAuthCommands.SetAlias(accountKey, "work").SequenceEqual(["alias", "set", accountKey, "work"]), "alias uses unique account key");
Assert(!CodexAuthCommands.RemoveAccount(accountKey).Contains("--skip-api"), "selector remove excludes skip-api");
Console.WriteLine("Windows model tests passed");
static void Assert(bool condition, string name) { if (!condition) throw new Exception("Assertion failed: " + name); }
