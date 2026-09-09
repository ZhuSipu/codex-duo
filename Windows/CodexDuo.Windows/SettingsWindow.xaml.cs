using System.Windows;
using System.Windows.Controls;
using System.Diagnostics;
using CodexDuo.Windows.Core;
using Microsoft.VisualBasic;

namespace CodexDuo.Windows;

public partial class SettingsWindow : Window
{
    private readonly MainViewModel viewModel;
    private bool loading = true;

    public SettingsWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        this.viewModel = viewModel;
        DataContext = viewModel;
        SourceInitialized += (_, _) => ThemeManager.ApplyWindowTheme(this, viewModel.Settings.Appearance);
        PopulateChoices();
        LoadValues();
        ApplyText();
        loading = false;
        UpdateButtonState();
        viewModel.PropertyChanged += ViewModel_PropertyChanged;
        Closed += (_, _) => viewModel.PropertyChanged -= ViewModel_PropertyChanged;
    }

    private void ViewModel_PropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        if (string.IsNullOrEmpty(e.PropertyName)
            || e.PropertyName is nameof(MainViewModel.IsBusy)
                or nameof(MainViewModel.HasAccounts)
                or nameof(MainViewModel.CanAddAccounts))
        {
            UpdateButtonState();
        }
    }

    private void PopulateChoices()
    {
        var text = viewModel.Text;
        LanguageBox.ItemsSource = new Dictionary<string, string>
        {
            ["system"] = text["system"],
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
            [0] = text["off"],
            [60] = text["everyMinute"],
            [120] = string.Format(System.Globalization.CultureInfo.CurrentCulture, text["everyMinutes"], 2),
            [300] = string.Format(System.Globalization.CultureInfo.CurrentCulture, text["everyMinutes"], 5),
            [600] = string.Format(System.Globalization.CultureInfo.CurrentCulture, text["everyMinutes"], 10),
            [900] = string.Format(System.Globalization.CultureInfo.CurrentCulture, text["everyMinutes"], 15),
        };
    }

    private void LoadValues()
    {
        LanguageBox.SelectedValue = viewModel.Settings.Language;
        IntervalBox.SelectedValue = viewModel.Settings.RefreshIntervalSeconds;
        SystemAppearance.IsChecked = viewModel.Settings.Appearance == "system";
        LightAppearance.IsChecked = viewModel.Settings.Appearance == "light";
        DarkAppearance.IsChecked = viewModel.Settings.Appearance == "dark";
        StartupCheck.IsChecked = viewModel.Settings.LaunchAtLogin;
    }

    private void ApplyText()
    {
        var text = viewModel.Text;
        Title = $"Codex Duo {text["settings"]}";
        GeneralHeading.Text = text["general"];
        AccountsHeading.Text = text["accounts"];
        AppearanceLabel.Text = text["appearance"];
        LanguageLabel.Text = text["language"];
        IntervalLabel.Text = text["interval"];
        StartupText.Text = text["startup"];
        TrayGuideExpander.Header = text["trayGuideHeading"];
        TrayGuideExpander.Tag = text["trayGuideTitle"];
        TrayGuideBody.Text = text["trayGuideBody"];
        TrayGuideSteps.Text = text["trayGuideSteps"];
        OpenTaskbarSettingsText.Text = text["openTaskbarSettings"];
        AddButtonText.Text = text["add"];
        RenameButtonText.Text = text["rename"];
        RemoveButtonText.Text = text["remove"];
        InstallButtonText.Text = text["install"];
        RefreshButtonText.Text = text["refresh"];
        OpenTaskbarSettingsButton.ToolTip = text["openTaskbarSettings"];
        AddButton.ToolTip = text["add"];
        RenameButton.ToolTip = text["rename"];
        RemoveButton.ToolTip = text["remove"];
        InstallButton.ToolTip = text["install"];
        RefreshButton.ToolTip = text["refresh"];
        SystemAppearance.Content = text["system"];
        LightAppearance.Content = text["light"];
        DarkAppearance.Content = text["dark"];
    }

    private string SelectedAppearance =>
        LightAppearance.IsChecked == true ? "light" : DarkAppearance.IsChecked == true ? "dark" : "system";

    private void SaveCurrentSettings()
    {
        if (loading) return;
        var updated = new AppSettings
        {
            Appearance = SelectedAppearance,
            Language = LanguageBox.SelectedValue as string ?? "system",
            RefreshIntervalSeconds = IntervalBox.SelectedValue is int interval ? interval : 120,
            LaunchAtLogin = StartupCheck.IsChecked == true,
            DidPresentSetup = true,
        };
        viewModel.ApplySettings(updated);
        ThemeManager.ApplyWindowTheme(this, updated.Appearance);
        loading = true;
        PopulateChoices();
        LoadValues();
        loading = false;
        ApplyText();
        UpdateButtonState();
    }

    private void Choice_Changed(object sender, SelectionChangedEventArgs e) => SaveCurrentSettings();
    private void Appearance_Click(object sender, RoutedEventArgs e) => SaveCurrentSettings();

    private void Check_Changed(object sender, RoutedEventArgs e)
    {
        if (loading) return;
        SaveCurrentSettings();
    }

    private void AccountList_SelectionChanged(object sender, SelectionChangedEventArgs e) => UpdateButtonState();

    private void UpdateButtonState()
    {
        var hasSelection = AccountList.SelectedItem is AccountViewModel;
        AddButton.IsEnabled = viewModel.CanAddAccounts && !viewModel.IsBusy;
        RenameButton.IsEnabled = hasSelection && !viewModel.IsBusy;
        RemoveButton.IsEnabled = hasSelection && !viewModel.IsBusy;
        RefreshButton.IsEnabled = viewModel.HasAccounts && !viewModel.IsBusy;
        InstallButton.Visibility = viewModel.IsDependencyAvailable ? Visibility.Collapsed : Visibility.Visible;
    }

    private void Add_Click(object sender, RoutedEventArgs e)
    {
        if (viewModel.AddAccount())
        {
            StatusLabel.Text = "Complete login in Terminal, then click Refresh Now.";
        }
        else
        {
            MessageBox.Show(viewModel.Error ?? viewModel.Text["dependency"], "Codex Duo", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
    }

    private async void Rename_Click(object sender, RoutedEventArgs e)
    {
        if (AccountList.SelectedItem is not AccountViewModel selected) return;
        var account = selected.Account;
        var alias = Interaction.InputBox("Enter a new alias. Leave it empty to clear the alias.", "Rename Account", account.Alias ?? string.Empty);
        StatusLabel.Text = "Updating alias…";
        await viewModel.RenameAccountAsync(account, alias);
        StatusLabel.Text = viewModel.Error ?? "Account settings updated";
        UpdateButtonState();
    }

    private async void Remove_Click(object sender, RoutedEventArgs e)
    {
        if (AccountList.SelectedItem is not AccountViewModel selected) return;
        var account = selected.Account;
        var result = MessageBox.Show(
            $"Remove {account.DisplayName} from the codex-auth registry? This does not delete the OpenAI account.",
            "Remove Account",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (result != MessageBoxResult.Yes) return;
        StatusLabel.Text = "Removing account…";
        await viewModel.RemoveAccountAsync(account);
        StatusLabel.Text = viewModel.Error ?? "Account settings updated";
        UpdateButtonState();
    }

    private async void Refresh_Click(object sender, RoutedEventArgs e)
    {
        StatusLabel.Text = "Refreshing usage…";
        UpdateButtonState();
        await viewModel.RefreshAsync(manual: true);
        StatusLabel.Text = viewModel.Error ?? viewModel.Warning ?? "Refresh requested";
        UpdateButtonState();
    }

    private void Install_Click(object sender, RoutedEventArgs e)
    {
        Clipboard.SetText("npm install -g @loongphy/codex-auth@next");
        StatusLabel.Text = "Install command copied";
    }

    private void OpenTaskbarSettings_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo("ms-settings:taskbar") { UseShellExecute = true });
            TrayGuideStatus.Text = viewModel.Text["taskbarSettingsOpened"];
        }
        catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            TrayGuideStatus.Text = viewModel.Text["taskbarSettingsFailed"];
        }
    }
}
