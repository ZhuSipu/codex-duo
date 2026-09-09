using System.Threading;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using CodexDuo.Windows.Core;
using H.NotifyIcon;

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
        trayWindow = new TrayWindow(viewModel, ShowSettingsWindow);
        var trayIconResource = GetResourceStream(new Uri("pack://application:,,,/Resources/CodexDuo.Tray.ico"))
            ?? throw new InvalidDataException("The tray icon resource is missing.");
        trayIconStream = trayIconResource.Stream;
        trayDrawingIcon = new System.Drawing.Icon(
            trayIconStream,
            Math.Max(16, GetSystemMetrics(SmallIconWidth)),
            Math.Max(16, GetSystemMetrics(SmallIconHeight)));
        trayIcon = new TaskbarIcon
        {
            Icon = trayDrawingIcon,
            ToolTipText = "Codex Duo",
        };
        trayIcon.TrayLeftMouseUp += (_, _) => trayWindow.ToggleNearTray();
        trayIcon.ForceCreate();

        if (e.Args.Contains("--settings", StringComparer.OrdinalIgnoreCase)
            || !viewModel.Settings.DidPresentSetup && !viewModel.HasAccounts)
        {
            ShowSettingsWindow();
        }
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
