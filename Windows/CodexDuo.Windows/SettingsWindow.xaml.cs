using System.Windows;
using CodexDuo.Windows.Core;
using Microsoft.VisualBasic;

namespace CodexDuo.Windows;

public partial class SettingsWindow : Window
{
    private readonly MainViewModel viewModel;

    public SettingsWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        this.viewModel = viewModel;
        PopulateChoices();
        LoadValues();
        ApplyText();
    }

    private void PopulateChoices()
    {
        AppearanceBox.ItemsSource = new Dictionary<string, string> { ["system"] = "System", ["light"] = "Light", ["dark"] = "Dark" };
        LanguageBox.ItemsSource = new Dictionary<string, string>
        {
            ["system"] = "System",
            ["en"] = "English",
            ["zh-Hans"] = "简体中文",
            ["zh-Hant"] = "繁體中文",
            ["ja"] = "日本語",
            ["ko"] = "한국어",
            ["es"] = "Español",
            ["fr"] = "Français",
            ["de"] = "Deutsch",
        };
        IntervalBox.ItemsSource = new Dictionary<int, string>
        {
            [0] = "Off",
            [60] = "Every minute",
            [120] = "Every 2 minutes",
            [300] = "Every 5 minutes",
            [600] = "Every 10 minutes",
            [900] = "Every 15 minutes",
        };
    }

    private void LoadValues()
    {
        AppearanceBox.SelectedValue = viewModel.Settings.Appearance;
        LanguageBox.SelectedValue = viewModel.Settings.Language;
        IntervalBox.SelectedValue = viewModel.Settings.RefreshIntervalSeconds;
        StartupCheck.IsChecked = viewModel.Settings.LaunchAtLogin;
        ActivationCheck.IsChecked = viewModel.Settings.AutoActivateRefreshedAccounts;
        AccountList.ItemsSource = viewModel.Registry?.DisplayAccounts;
    }

    private void ApplyText()
    {
        var text = viewModel.Text;
        SettingsHeading.Text = text["settings"];
        AppearanceLabel.Text = text["appearance"];
        LanguageLabel.Text = text["language"];
        IntervalLabel.Text = text["interval"];
        StartupCheck.Content = text["startup"];
        ActivationCheck.Content = text["activation"];
        AccountsLabel.Text = text["accounts"];
        AddButton.Content = text["add"];
        RenameButton.Content = text["rename"];
        RemoveButton.Content = text["remove"];
        ApplyButton.Content = text["apply"];
    }

    private void Apply_Click(object sender, RoutedEventArgs e)
    {
        var current = viewModel.Settings;
        var updated = new AppSettings
        {
            Appearance = AppearanceBox.SelectedValue as string ?? "system",
            Language = LanguageBox.SelectedValue as string ?? "system",
            RefreshIntervalSeconds = IntervalBox.SelectedValue is int interval ? interval : 120,
            LaunchAtLogin = StartupCheck.IsChecked == true,
            AutoActivateRefreshedAccounts = ActivationCheck.IsChecked == true,
            DidPresentSetup = true,
            AutoActivationAttempts = new Dictionary<string, long>(current.AutoActivationAttempts, StringComparer.Ordinal),
            AutoActivationSuccesses = new Dictionary<string, long>(current.AutoActivationSuccesses, StringComparer.Ordinal),
        };
        viewModel.ApplySettings(updated);
        ApplyText();
    }

    private void Add_Click(object sender, RoutedEventArgs e)
    {
        if (viewModel.AddAccount())
        {
            MessageBox.Show("Finish the codex-auth login in the terminal, then choose Refresh Now.", "Codex Duo", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }

    private async void Rename_Click(object sender, RoutedEventArgs e)
    {
        if (AccountList.SelectedItem is not CodexAccount account) return;
        var alias = Interaction.InputBox("Enter a new alias. Leave it empty to clear the alias.", "Rename Account", account.Alias ?? string.Empty);
        await viewModel.RenameAccountAsync(account, alias);
        AccountList.ItemsSource = viewModel.Registry?.DisplayAccounts;
    }

    private async void Remove_Click(object sender, RoutedEventArgs e)
    {
        if (AccountList.SelectedItem is not CodexAccount account) return;
        var result = MessageBox.Show(
            $"Remove {account.DisplayName} from the codex-auth registry? This does not delete the OpenAI account.",
            "Remove Account",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (result != MessageBoxResult.Yes) return;
        await viewModel.RemoveAccountAsync(account);
        AccountList.ItemsSource = viewModel.Registry?.DisplayAccounts;
    }
}
