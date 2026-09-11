using System.Threading;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Threading;
using CodexDuo.Windows.Core;
using H.NotifyIcon;
using Microsoft.Win32;

namespace CodexDuo.Windows;

public partial class App : Application, IDisposable
{
    private const int SmallIconWidth = 49;
    private const int SmallIconHeight = 50;
    private Mutex? instanceMutex;
    private bool ownsInstanceMutex;
    private TaskbarIcon? trayIcon;
    private Stream? trayIconStream;
    private System.Drawing.Icon? trayDrawingIcon;
    private MainViewModel? viewModel;
    private TrayWindow? trayWindow;
    private SettingsWindow? settingsWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        DiagnosticLog.Write("app.start");
        if (DetachedStartup.IsDetachedLaunch(e.Args))
        {
            DiagnosticLog.Write("app.detached-start");
            DetachedStartup.CompleteDetachedLaunch(e.Args);
        }
        else
        {
            // Always move the tray app into a Task Scheduler process before it
            // can switch accounts. Parent-process inspection is not a reliable
            // safety check on Windows: a parent can exit and be re-parented
            // while this process is still associated with Codex's job. Killing
            // the packaged Codex process would then kill Codex Duo before the
            // account command runs. A scheduled launch has an independent
            // lifetime regardless of whether Duo came from Codex, Explorer, or
            // a terminal.
            var executable = Environment.ProcessPath;
            string? detachError = null;
            if (!string.IsNullOrWhiteSpace(executable)
                && DetachedStartup.TryRelaunchIndependent(executable, Environment.ProcessId, e.Args, out detachError))
            {
                DiagnosticLog.Write("app.detach-requested");
                Shutdown();
                return;
            }
            DiagnosticLog.Write("app.detach-failed", detachError);
        }

        instanceMutex = new Mutex(true, "Local\\CodexDuo.Windows.SingleInstance", out ownsInstanceMutex);
        if (!ownsInstanceMutex)
        {
            DiagnosticLog.Write("app.secondary-instance-exit");
            Shutdown();
            return;
        }

        base.OnStartup(e);
        viewModel = new MainViewModel();
        viewModel.SettingsApplied += ViewModel_SettingsApplied;
        trayWindow = new TrayWindow(viewModel, ShowSettingsWindow);
        trayIcon = new TaskbarIcon
        {
            ToolTipText = "Codex Duo",
        };
        UpdateTrayIcon();
        trayIcon.TrayLeftMouseUp += (_, _) => trayWindow.ToggleNearTray();
        trayIcon.ForceCreate();
        SystemEvents.UserPreferenceChanged += SystemEvents_UserPreferenceChanged;

        if (e.Args.Contains("--settings", StringComparer.OrdinalIgnoreCase)
            || !viewModel.Settings.DidPresentSetup && !viewModel.HasAccounts)
        {
            ShowSettingsWindow();
        }
    }

    private void SystemEvents_UserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (Dispatcher.HasShutdownStarted || Dispatcher.HasShutdownFinished) return;
        _ = Dispatcher.BeginInvoke(DispatcherPriority.Background, () =>
        {
            UpdateTrayIcon();
            if (viewModel?.Settings.Appearance == "system") ApplyCurrentWindowTheme();
        });
    }

    private void ViewModel_SettingsApplied(object? sender, EventArgs e) => ApplyCurrentWindowTheme();

    private void ApplyCurrentWindowTheme()
    {
        if (viewModel is null) return;
        ThemeManager.Apply(viewModel.Settings.Appearance);
        if (trayWindow is not null) ThemeManager.ApplyWindowTheme(trayWindow, viewModel.Settings.Appearance);
        if (settingsWindow is not null) ThemeManager.ApplyWindowTheme(settingsWindow, viewModel.Settings.Appearance);
    }

    private void UpdateTrayIcon()
    {
        if (trayIcon is null) return;
        var resourceName = ThemeManager.SystemTaskbarUsesDarkTheme()
            ? "CodexDuo.Tray.Dark.ico"
            : "CodexDuo.Tray.Light.ico";
        var iconResource = GetResourceStream(new Uri($"pack://application:,,,/Resources/{resourceName}"))
            ?? throw new InvalidDataException("The tray icon resource is missing.");
        var iconStream = iconResource.Stream;
        var drawingIcon = new System.Drawing.Icon(
            iconStream,
            Math.Max(16, GetSystemMetrics(SmallIconWidth)),
            Math.Max(16, GetSystemMetrics(SmallIconHeight)));

        trayIcon.Icon = drawingIcon;
        trayDrawingIcon?.Dispose();
        trayIconStream?.Dispose();
        trayDrawingIcon = drawingIcon;
        trayIconStream = iconStream;
    }

    private void ShowSettingsWindow()
    {
        if (settingsWindow is not null)
        {
            if (settingsWindow.WindowState == WindowState.Minimized)
            {
                settingsWindow.WindowState = WindowState.Normal;
            }
            settingsWindow.Show();
            settingsWindow.Activate();
            return;
        }

        settingsWindow = new SettingsWindow(viewModel!);
        settingsWindow.Closed += (_, _) => settingsWindow = null;
        settingsWindow.Show();
        settingsWindow.Activate();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        DiagnosticLog.Write("app.exit");
        Dispose();
        base.OnExit(e);
    }

    public void Dispose()
    {
        SystemEvents.UserPreferenceChanged -= SystemEvents_UserPreferenceChanged;
        if (viewModel is not null) viewModel.SettingsApplied -= ViewModel_SettingsApplied;
        trayIcon?.Dispose();
        trayIcon = null;
        trayDrawingIcon?.Dispose();
        trayDrawingIcon = null;
        trayIconStream?.Dispose();
        trayIconStream = null;
        settingsWindow?.Close();
        settingsWindow = null;
        viewModel?.Dispose();
        viewModel = null;
        if (ownsInstanceMutex)
        {
            instanceMutex?.ReleaseMutex();
            ownsInstanceMutex = false;
        }
        instanceMutex?.Dispose();
        instanceMutex = null;
        GC.SuppressFinalize(this);
    }

    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);
}
