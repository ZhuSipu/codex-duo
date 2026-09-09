using System.Windows;
using System.Windows.Input;
using System.Windows.Controls;
using CodexDuo.Windows.Core;

namespace CodexDuo.Windows;

public partial class TrayWindow : Window
{
    private readonly MainViewModel viewModel;
    private readonly Action showSettings;
    private bool isToggling;

    public TrayWindow(MainViewModel viewModel, Action showSettings)
    {
        InitializeComponent();
        this.viewModel = viewModel;
        this.showSettings = showSettings;
        DataContext = viewModel;
        SourceInitialized += (_, _) => ThemeManager.ApplyWindowTheme(this, viewModel.Settings.Appearance);
        Deactivated += (_, _) => Hide();
        PreviewKeyDown += (_, args) => { if (args.Key == Key.Escape) Hide(); };
    }

    public void ToggleNearTray()
    {
        // Window.Show() pumps messages while creating the native window. A
        // second tray notification can therefore re-enter this method before
        // IsVisible becomes true and attempt to attach the same root visual
        // twice, which terminates the process with an ArgumentException.
        if (isToggling)
        {
            DiagnosticLog.Write("tray.toggle-reentrant-ignored");
            return;
        }

        isToggling = true;
        try
        {
            if (IsVisible) { Hide(); return; }
            viewModel.LoadRegistry();
            Show();
            Activate();
            UpdateLayout();
            var workArea = SystemParameters.WorkArea;
            Left = Math.Max(workArea.Left, workArea.Right - ActualWidth - 8);
            Top = Math.Max(workArea.Top, workArea.Bottom - ActualHeight - 8);
        }
        finally
        {
            isToggling = false;
        }
    }

    private void Account_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { DataContext: AccountViewModel account } || !account.CanSwitch) return;
        if (account.SwitchCommand.CanExecute(null)) account.SwitchCommand.Execute(null);
    }

    private void Settings_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        showSettings();
    }

    private void Quit_Click(object sender, RoutedEventArgs e) => Application.Current.Shutdown();
}
