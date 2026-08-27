using System.Windows;
using System.Windows.Input;
using System.Windows.Controls;

namespace CodexDuo.Windows;

public partial class TrayWindow : Window
{
    private readonly MainViewModel viewModel;
    private readonly Action showSettings;

    public TrayWindow(MainViewModel viewModel, Action showSettings)
    {
        InitializeComponent();
        this.viewModel = viewModel;
        this.showSettings = showSettings;
        DataContext = viewModel;
        Deactivated += (_, _) => Hide();
        PreviewKeyDown += (_, args) => { if (args.Key == Key.Escape) Hide(); };
    }

    public void ToggleNearTray()
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
