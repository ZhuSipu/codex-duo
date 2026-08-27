using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using CodexDuo.Windows.Core;
using H.NotifyIcon;

namespace CodexDuo.Windows;

public partial class App : Application, IDisposable
{
    private Mutex? instanceMutex;
    private bool ownsInstanceMutex;
    private TaskbarIcon? trayIcon;
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
        else if (CodexAppController.IsCurrentProcessDescendantOfCodex())
        {
            var executable = Environment.ProcessPath;
            string? detachError = null;
            if (!string.IsNullOrWhiteSpace(executable)
                && DetachedStartup.TryRelaunchIndependent(executable, Environment.ProcessId, out detachError))
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
        trayIcon = new TaskbarIcon
        {
            IconSource = new BitmapImage(new Uri("pack://application:,,,/Resources/CodexDuo.ico")),
            ToolTipText = "Codex Duo",
            ContextMenu = BuildContextMenu(),
        };
        trayIcon.TrayLeftMouseUp += (_, _) => trayWindow.ToggleNearTray();
        trayIcon.ForceCreate();
        viewModel.SettingsApplied += (_, _) => trayIcon.ContextMenu = BuildContextMenu();

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

    private ContextMenu BuildContextMenu()
    {
        var menu = new ContextMenu();
        var open = new MenuItem { Header = viewModel!.Text["accounts"] };
        open.Click += (_, _) => trayWindow!.ToggleNearTray();
        var refresh = new MenuItem { Header = viewModel.Text["refresh"], Command = viewModel.RefreshCommand };
        var settings = new MenuItem { Header = viewModel.Text["settings"] };
        settings.Click += (_, _) => ShowSettingsWindow();
        var quit = new MenuItem { Header = viewModel.Text["quit"] };
        quit.Click += (_, _) => Shutdown();
        menu.Items.Add(open);
        menu.Items.Add(refresh);
        menu.Items.Add(settings);
        menu.Items.Add(new Separator());
        menu.Items.Add(quit);
        return menu;
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
}
