using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace CodexDuo.Windows;

public partial class TrayWindow : Window
{
    private readonly App app;
    public TrayWindow(App app) { this.app = app; InitializeComponent(); }
    public void Rebuild()
    {
        if (!IsInitialized) return;
        AccountsPanel.Children.Clear();
        var registry = app.Registry;
        if (registry is null || registry.MenuAccounts.Count == 0)
        {
            AccountsPanel.Children.Add(new TextBlock { Text = app.LastError ?? "No accounts configured.", TextWrapping = TextWrapping.Wrap, Margin = new Thickness(12, 40, 12, 40), HorizontalAlignment = System.Windows.HorizontalAlignment.Center, Opacity = .7 });
        }
        else foreach (var account in registry.MenuAccounts) AccountsPanel.Children.Add(AccountRow(account, account.AccountKey == registry.ActiveAccountKey));
        StatusText.Text = app.IsBusy ? "Working…" : app.LastError ?? $"{registry?.Accounts.Count ?? 0} account(s)";
    }
    private System.Windows.Controls.Button AccountRow(CodexAccount account, bool active)
    {
        var button = new System.Windows.Controls.Button { Style = (Style)FindResource("AccountButton"), Tag = account, IsEnabled = !active && !app.IsBusy, ToolTip = active ? "Current account" : "Switch to this account" };
        var grid = new Grid(); grid.ColumnDefinitions.Add(new ColumnDefinition()); grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var left = new StackPanel();
        left.Children.Add(new TextBlock { Text = (active ? "●  " : "○  ") + account.DisplayName, FontWeight = active ? FontWeights.SemiBold : FontWeights.Normal, TextTrimming = TextTrimming.CharacterEllipsis });
        left.Children.Add(new TextBlock { Text = account.Alias is null ? account.Plan?.ToUpperInvariant() ?? "ACCOUNT" : account.Email, FontSize = 10.5, Opacity = .58, Margin = new Thickness(18, 3, 0, 0) });
        grid.Children.Add(left);
        var usage = new StackPanel { HorizontalAlignment = System.Windows.HorizontalAlignment.Right };
        AddUsage(usage, "5H", account.LastUsage?.FiveHour); AddUsage(usage, "WEEK", account.LastUsage?.Weekly);
        Grid.SetColumn(usage, 1); grid.Children.Add(usage); button.Content = grid;
        button.Click += async (_, _) => await app.SwitchAsync(account);
        return button;
    }
    private static void AddUsage(System.Windows.Controls.Panel panel, string title, RateLimitWindow? window)
    {
        if (window is null) return;
        var reset = window.ResetText(); panel.Children.Add(new TextBlock { Text = $"{title}  {window.RemainingPercent()}%{(reset is null ? "" : " · " + reset)}", FontSize = 11, Opacity = .78, HorizontalAlignment = System.Windows.HorizontalAlignment.Right, Margin = new Thickness(12, 1, 0, 1) });
    }
    private void Window_Deactivated(object sender, EventArgs e) => Hide();
    private void Settings_Click(object sender, RoutedEventArgs e) { Hide(); app.ShowSettings(); }
    private void Quit_Click(object sender, RoutedEventArgs e) => app.Quit();
}
