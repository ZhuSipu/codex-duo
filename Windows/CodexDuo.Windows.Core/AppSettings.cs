using System.Text.Json;

namespace CodexDuo.Windows.Core;

public static class SettingValues
{
    public static readonly HashSet<string> Appearances = new(StringComparer.Ordinal) { "system", "light", "dark" };
    public static readonly HashSet<string> Languages = new(StringComparer.Ordinal) { "system", "en", "zh-Hans", "zh-Hant", "ja", "ko", "es", "fr", "de" };
    public static readonly HashSet<int> RefreshIntervals = [0, 60, 120, 300, 600, 900];
}

public sealed class AppSettings
{
    public string Appearance { get; set; } = "system";
    public string Language { get; set; } = "system";
    public int RefreshIntervalSeconds { get; set; } = 120;
    public bool LaunchAtLogin { get; set; }
    public bool DidPresentSetup { get; set; }

    public void Normalize()
    {
        if (!SettingValues.Appearances.Contains(Appearance)) Appearance = "system";
        if (!SettingValues.Languages.Contains(Language)) Language = "system";
        if (!SettingValues.RefreshIntervals.Contains(RefreshIntervalSeconds)) RefreshIntervalSeconds = 120;
    }
}

public sealed class SettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private readonly string path;

    public SettingsStore(string? path = null)
    {
        this.path = path ?? System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Codex Duo",
            "settings.json");
    }

    public string Path => path;

    public AppSettings Load()
    {
        try
        {
            if (!File.Exists(path)) return new AppSettings();
            var settings = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(path), JsonOptions) ?? new AppSettings();
            settings.Normalize();
            return settings;
        }
        catch (JsonException)
        {
            return new AppSettings();
        }
        catch (IOException)
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        settings.Normalize();
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path)!);
        var temporary = path + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(settings, JsonOptions));
        File.Move(temporary, path, true);
    }
}
