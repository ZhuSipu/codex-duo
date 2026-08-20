using System.Text.Json;
using System.IO;

namespace CodexDuo.Windows;

public enum AppearanceMode { System, Light, Dark }

public sealed class AppPreferences
{
    private sealed class State { public AppearanceMode Appearance { get; set; } = AppearanceMode.System; public int RefreshSeconds { get; set; } = 120; public bool DidPresentSetup { get; set; } }
    private readonly string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Codex Duo", "settings.json");
    private State state;
    public event EventHandler? Changed;
    public AppPreferences() { try { state = JsonSerializer.Deserialize<State>(File.ReadAllText(path)) ?? new(); } catch { state = new(); } }
    public AppearanceMode Appearance { get => state.Appearance; set { state.Appearance = value; Save(); } }
    public int RefreshSeconds { get => new[] { 0, 60, 120, 300, 600, 900 }.Contains(state.RefreshSeconds) ? state.RefreshSeconds : 120; set { state.RefreshSeconds = value; Save(); } }
    public bool DidPresentSetup { get => state.DidPresentSetup; set { state.DidPresentSetup = value; Save(false); } }
    private void Save(bool notify = true) { Directory.CreateDirectory(Path.GetDirectoryName(path)!); File.WriteAllText(path, JsonSerializer.Serialize(state, new JsonSerializerOptions { WriteIndented = true })); if (notify) Changed?.Invoke(this, EventArgs.Empty); }
}
