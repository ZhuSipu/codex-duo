using System.Windows;
using System.Windows.Forms;
using System.Windows.Media;
using Drawing = System.Drawing;
using Timer = System.Threading.Timer;

namespace CodexDuo.Windows;

public partial class App : System.Windows.Application
{
    private Mutex? singleInstance;
    private NotifyIcon? trayIcon;
    private TrayWindow? trayWindow;
    private SettingsWindow? settingsWindow;
    private readonly CodexAuthService service = new();
    private readonly AppPreferences preferences = new();
    private Timer? registryTimer;
    private Timer? refreshTimer;
    public CodexRegistry? Registry { get; private set; }
    public string? LastError { get; private set; }
    public bool IsBusy { get; private set; }

    protected override async void OnStartup(StartupEventArgs e)
    {
        singleInstance = new Mutex(true, "Local\\CodexDuo.Windows", out var created);
        if (!created) { Shutdown(); return; }
        base.OnStartup(e);
        ApplyTheme();
        trayWindow = new TrayWindow(this);
        trayIcon = new NotifyIcon { Icon = Drawing.SystemIcons.Application, Text = "Codex Duo", Visible = true };
        trayIcon.MouseClick += (_, args) => { if (args.Button == MouseButtons.Left) ShowTrayWindow(); };
        var menu = new ContextMenuStrip();
        menu.Items.Add("Open", null, (_, _) => ShowTrayWindow());
        menu.Items.Add("Settings", null, (_, _) => ShowSettings());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit", null, (_, _) => Shutdown());
        trayIcon.ContextMenuStrip = menu;
        preferences.Changed += (_, _) => { ApplyTheme(); ScheduleRefresh(); trayWindow?.Rebuild(); settingsWindow?.Reload(); };
        await ReloadRegistryAsync();
        registryTimer = new Timer(async _ => await Dispatcher.InvokeAsync(ReloadRegistryAsync), null, TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(5));
        ScheduleRefresh();
        if (preferences.RefreshSeconds > 0) _ = RefreshUsageAsync();
        if ((Registry?.Accounts.Count ?? 0) == 0 && !preferences.DidPresentSetup)
        {
            preferences.DidPresentSetup = true;
            ShowSettings();
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        registryTimer?.Dispose(); refreshTimer?.Dispose();
        if (trayIcon is not null) { trayIcon.Visible = false; trayIcon.Dispose(); }
        singleInstance?.Dispose();
        base.OnExit(e);
    }

    public async Task ReloadRegistryAsync()
    {
        try { Registry = await service.LoadRegistryAsync(); if (!IsBusy) LastError = null; }
        catch (Exception ex) { Registry = null; LastError = service.IsAvailable ? ex.Message : "codex-auth is not installed."; }
        UpdateViews();
    }
    public async Task RefreshUsageAsync()
    {
        if (IsBusy) return;
        IsBusy = true; UpdateViews();
        var result = await service.RefreshAsync();
        LastError = result.Succeeded ? null : ErrorText(result);
        IsBusy = false; await ReloadRegistryAsync();
    }
    public async Task SwitchAsync(CodexAccount account)
    {
        if (IsBusy || Registry?.ActiveAccountKey == account.AccountKey) return;
        if (System.Windows.MessageBox.Show(
                $"Codex must close and restart to switch to {account.DisplayName}. Finish or stop active work before continuing.",
                "Switch Codex account?",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
        IsBusy = true; LastError = null; UpdateViews(); trayWindow?.Hide();
        var result = await service.SwitchAndRestartCodexAsync(account);
        IsBusy = false; LastError = result.Succeeded ? null : ErrorText(result);
        await ReloadRegistryAsync();
        if (!result.Succeeded) System.Windows.MessageBox.Show(LastError, "Account switch failed", MessageBoxButton.OK, MessageBoxImage.Error);
    }
    public CodexAuthService Service => service;
    public AppPreferences Preferences => preferences;
    public void ShowSettings() { settingsWindow ??= new SettingsWindow(this); settingsWindow.Reload(); settingsWindow.Show(); settingsWindow.Activate(); }
    public void Quit() => Shutdown();

    private void ShowTrayWindow()
    {
        if (trayWindow is null) return;
        trayWindow.Rebuild();
        var area = Screen.PrimaryScreen?.WorkingArea ?? new Drawing.Rectangle(0, 0, 1200, 800);
        var cursor = System.Windows.Forms.Cursor.Position;
        trayWindow.Left = Math.Clamp(cursor.X - trayWindow.Width / 2, area.Left + 8, area.Right - trayWindow.Width - 8);
        trayWindow.Top = Math.Clamp(cursor.Y - trayWindow.Height - 12, area.Top + 8, area.Bottom - trayWindow.Height - 8);
        trayWindow.Show(); trayWindow.Activate();
    }
    private void UpdateViews()
    {
        trayWindow?.Rebuild(); settingsWindow?.Reload();
        if (trayIcon is null) return;
        var accounts = Registry?.MenuAccounts ?? [];
        var summary = accounts.Count == 0 ? "Codex Duo — no accounts" : string.Join(" · ", accounts.Take(2).Select(a =>
        {
            var remaining = a.LastUsage?.Weekly?.RemainingPercent() ?? a.LastUsage?.FiveHour?.RemainingPercent();
            return $"{a.CompactName} {(remaining is null ? "—" : remaining)}%";
        }));
        trayIcon.Text = summary.Length > 63 ? summary[..63] : summary;
    }
    private void ScheduleRefresh()
    {
        refreshTimer?.Dispose(); refreshTimer = null;
        if (preferences.RefreshSeconds > 0) refreshTimer = new Timer(async _ => await Dispatcher.InvokeAsync(RefreshUsageAsync), null, TimeSpan.FromSeconds(preferences.RefreshSeconds), TimeSpan.FromSeconds(preferences.RefreshSeconds));
    }
    private void ApplyTheme()
    {
        var dark = preferences.Appearance == AppearanceMode.Dark || (preferences.Appearance == AppearanceMode.System && IsSystemDark());
        Resources[System.Windows.SystemColors.WindowBrushKey] = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(dark ? "#202124" : "#F7F8FA"));
        Resources[System.Windows.SystemColors.WindowTextBrushKey] = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(dark ? "#F2F3F5" : "#17181A"));
        Resources[System.Windows.SystemColors.ControlBrushKey] = new SolidColorBrush((System.Windows.Media.Color)System.Windows.Media.ColorConverter.ConvertFromString(dark ? "#292B30" : "#FFFFFF"));
        Resources[System.Windows.SystemColors.ControlTextBrushKey] = Resources[System.Windows.SystemColors.WindowTextBrushKey];
        foreach (Window window in Windows) { window.Background = (System.Windows.Media.Brush)Resources[System.Windows.SystemColors.WindowBrushKey]; window.Foreground = (System.Windows.Media.Brush)Resources[System.Windows.SystemColors.WindowTextBrushKey]; }
    }
    private static bool IsSystemDark()
    {
        using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        return key?.GetValue("AppsUseLightTheme") is int value && value == 0;
    }
    private static string ErrorText(CommandResult result) => string.IsNullOrWhiteSpace(result.Stderr) ? $"Command failed with exit code {result.Status}." : result.Stderr.Trim();
}
