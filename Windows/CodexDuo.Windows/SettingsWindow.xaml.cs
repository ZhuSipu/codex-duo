using Microsoft.VisualBasic;
using System.Windows;
using System.Windows.Controls;

namespace CodexDuo.Windows;

public partial class SettingsWindow : Window
{
    private readonly App app; private bool loading;
    public SettingsWindow(App app) { this.app = app; InitializeComponent(); Reload(); }
    public void Reload()
    {
        if (!IsInitialized) return; loading = true;
        AppearanceBox.SelectedIndex = (int)app.Preferences.Appearance;
        foreach (ComboBoxItem item in RefreshBox.Items) if (int.Parse(item.Tag.ToString()!) == app.Preferences.RefreshSeconds) { RefreshBox.SelectedItem = item; break; }
        StartupCheck.IsChecked = StartupManager.IsEnabled;
        AccountsList.ItemsSource = app.Registry?.MenuAccounts;
        DependencyText.Text = app.Service.IsAvailable ? $"codex-auth is ready · {app.Registry?.Accounts.Count ?? 0} account(s)" : "codex-auth is required and was not found. Install Node.js first if npm is unavailable.";
        InstallButton.Visibility = app.Service.IsAvailable ? Visibility.Collapsed : Visibility.Visible;
        loading = false;
    }
    private void AppearanceBox_Changed(object sender, SelectionChangedEventArgs e) { if (!loading && AppearanceBox.SelectedIndex >= 0) app.Preferences.Appearance = (AppearanceMode)AppearanceBox.SelectedIndex; }
    private void RefreshBox_Changed(object sender, SelectionChangedEventArgs e) { if (!loading && RefreshBox.SelectedItem is ComboBoxItem item) app.Preferences.RefreshSeconds = int.Parse(item.Tag.ToString()!); }
    private void StartupCheck_Changed(object sender, RoutedEventArgs e) { if (!loading) try { StartupManager.SetEnabled(StartupCheck.IsChecked == true); } catch (Exception ex) { System.Windows.MessageBox.Show(ex.Message, "Startup setting failed", MessageBoxButton.OK, MessageBoxImage.Error); } }
    private void Add_Click(object sender, RoutedEventArgs e) { var result = app.Service.OpenLoginTerminal(); if (!result.Succeeded) System.Windows.MessageBox.Show(result.Stderr, "Unable to add account", MessageBoxButton.OK, MessageBoxImage.Error); }
    private async void Rename_Click(object sender, RoutedEventArgs e)
    {
        if (AccountsList.SelectedItem is not CodexAccount account) { SelectAccount(); return; }
        var alias = Interaction.InputBox($"Enter a display name for {account.Email}. Leave it empty to clear the alias.", "Rename account", account.Alias ?? "");
        var result = await app.Service.SetAliasAsync(account.AccountKey, alias); await app.ReloadRegistryAsync(); if (!result.Succeeded) ShowError(result);
    }
    private async void Remove_Click(object sender, RoutedEventArgs e)
    {
        if (AccountsList.SelectedItem is not CodexAccount account) { SelectAccount(); return; }
        if (System.Windows.MessageBox.Show($"Remove {account.DisplayName} from codex-auth? This does not revoke the account itself.", "Remove account", MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes) return;
        var result = await app.Service.RemoveAsync(account.AccountKey); await app.ReloadRegistryAsync(); if (!result.Succeeded) ShowError(result);
    }
    private async void Refresh_Click(object sender, RoutedEventArgs e) => await app.RefreshUsageAsync();
    private void Install_Click(object sender, RoutedEventArgs e) { try { app.Service.OpenDependencyInstaller(); } catch (Exception ex) { System.Windows.MessageBox.Show("Unable to start npm. Install Node.js, then run:\n\nnpm install -g @loongphy/codex-auth@next\n\n" + ex.Message, "Dependency installation", MessageBoxButton.OK, MessageBoxImage.Information); } }
    private void SelectAccount() => System.Windows.MessageBox.Show("Select an account first.", "Codex Duo", MessageBoxButton.OK, MessageBoxImage.Information);
    private static void ShowError(CommandResult result) => System.Windows.MessageBox.Show(string.IsNullOrWhiteSpace(result.Stderr) ? $"Command failed ({result.Status})." : result.Stderr.Trim(), "Codex Duo", MessageBoxButton.OK, MessageBoxImage.Error);
}
