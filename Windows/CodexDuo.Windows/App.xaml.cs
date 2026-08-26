using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;
using H.NotifyIcon;

namespace CodexDuo.Windows;

public partial class App : Application, IDisposable
{
    private Mutex? instanceMutex;
    private bool ownsInstanceMutex;
    private TaskbarIcon? trayIcon;
    private MainViewModel? viewModel;
    private TrayWindow? trayWindow;

    protected override void OnStartup(StartupEventArgs e)
    {
        instanceMutex = new Mutex(true, "Local\\CodexDuo.Windows.SingleInstance", out ownsInstanceMutex);
        if (!ownsInstanceMutex)
        {
            Shutdown();
            return;
        }

        base.OnStartup(e);
        viewModel = new MainViewModel();
        trayWindow = new TrayWindow(viewModel);
        trayIcon = new TaskbarIcon
        {
            IconSource = new BitmapImage(new Uri("pack://application:,,,/Resources/CodexDuo.ico")),
            ToolTipText = "Codex Duo",
            ContextMenu = BuildContextMenu(),
        };
        trayIcon.TrayLeftMouseUp += (_, _) => trayWindow.ToggleNearTray();
        trayIcon.ForceCreate();
        viewModel.SettingsApplied += (_, _) => trayIcon.ContextMenu = BuildContextMenu();

        if (!viewModel.Settings.DidPresentSetup && !viewModel.HasAccounts)
        {
            new SettingsWindow(viewModel).Show();
        }
    }

    private ContextMenu BuildContextMenu()
    {
        var menu = new ContextMenu();
        var open = new MenuItem { Header = viewModel!.Text["accounts"] };
        open.Click += (_, _) => trayWindow!.ToggleNearTray();
        var refresh = new MenuItem { Header = viewModel.Text["refresh"], Command = viewModel.RefreshCommand };
        var settings = new MenuItem { Header = viewModel.Text["settings"] };
        settings.Click += (_, _) => new SettingsWindow(viewModel).Show();
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
        Dispose();
        base.OnExit(e);
    }

    public void Dispose()
    {
        trayIcon?.Dispose();
        trayIcon = null;
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
