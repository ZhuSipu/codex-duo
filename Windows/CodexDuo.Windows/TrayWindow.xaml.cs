using System.Windows;
using System.Windows.Input;

namespace CodexDuo.Windows;

public partial class TrayWindow : Window
{
    private readonly MainViewModel viewModel;

    public TrayWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        this.viewModel = viewModel;
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
        var workArea = SystemParameters.WorkArea;
        Left = Math.Max(workArea.Left, workArea.Right - ActualWidth - 8);
        Top = Math.Max(workArea.Top, workArea.Bottom - ActualHeight - 8);
    }

    private void Settings_Click(object sender, RoutedEventArgs e)
    {
        Hide();
        new SettingsWindow(viewModel).ShowDialog();
    }
}
