using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using CodexDuo.Windows.Core;

namespace CodexDuo.Windows;

public sealed class AccountViewModel
{
    public AccountViewModel(CodexAccount account, bool active, AppSettings settings, Localizer text, MainViewModel owner, DateTimeOffset now)
    {
        Account = account;
        IsActive = active;
        DisplayName = account.DisplayName;
        Subtitle = string.IsNullOrWhiteSpace(account.Plan) ? account.Email : $"{account.Email} · {account.Plan}";
        AgeText = account.UsageAgeText(now);
        ActiveText = text["active"];
        FiveHourLabel = text["fiveHour"];
        WeeklyLabel = text["weekly"];
        RemainingLabel = text["remaining"];
        FiveHourRemaining = account.LastUsage?.FiveHour?.RemainingPercent(now);
        FiveHourReset = account.LastUsage?.FiveHour?.ResetText(now);
        WeeklyRemaining = account.LastUsage?.Weekly?.RemainingPercent(now);
        WeeklyReset = account.LastUsage?.Weekly?.DisplayResetText(settings.ActivationStart(account.AccountKey), now);
        SwitchCommand = new AsyncCommand(() => owner.SwitchAccountAsync(account), () => !IsActive && !owner.IsBusy);
    }

    public CodexAccount Account { get; }
    public bool IsActive { get; }
    public string DisplayName { get; }
    public string Subtitle { get; }
    public string? AgeText { get; }
    public string ActiveText { get; }
    public string FiveHourLabel { get; }
    public string WeeklyLabel { get; }
    public string RemainingLabel { get; }
    public int? FiveHourRemaining { get; }
    public string? FiveHourReset { get; }
    public int? WeeklyRemaining { get; }
    public string? WeeklyReset { get; }
    public bool HasFiveHour => FiveHourRemaining is not null;
    public bool HasWeekly => WeeklyRemaining is not null;
    public ICommand SwitchCommand { get; }
}

public sealed class MainViewModel : INotifyPropertyChanged, IDisposable
{
    private readonly CodexAuthService auth = new();
    private readonly SettingsStore settingsStore = new();
    private readonly SemaphoreSlim operationGate = new(1, 1);
    private readonly DispatcherTimer refreshTimer = new();
    private CodexRegistry? registry;
    private AppSettings settings;
    private Localizer text;
    private bool isBusy;
    private string? warning;
    private string? error;

    public MainViewModel()
    {
        settings = settingsStore.Load();
        settings.LaunchAtLogin = StartupManager.IsEnabled(Environment.ProcessPath ?? string.Empty);
        text = new Localizer(settings.Language);
        Accounts = [];
        RefreshCommand = new AsyncCommand(() => RefreshAsync(manual: true), () => !IsBusy);
        refreshTimer.Tick += async (_, _) => await RefreshAsync(manual: false);
        ConfigureTimer();
        ThemeManager.Apply(settings.Appearance);
        LoadRegistry();
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    public event EventHandler? SettingsApplied;
    public ObservableCollection<AccountViewModel> Accounts { get; }
    public AsyncCommand RefreshCommand { get; }
    public AppSettings Settings => settings;
    public CodexRegistry? Registry => registry;
    public Localizer Text => text;
    public string AccountsTitle => text["accounts"];
    public string RefreshText => text["refresh"];
    public string SettingsText => text["settings"];
    public string QuitText => text["quit"];
    public string EmptyText => auth.IsAvailable ? text["empty"] : text["dependency"];
    public bool HasAccounts => Accounts.Count > 0;
    public bool HasNoAccounts => !HasAccounts;
    public bool HasWarning => !string.IsNullOrWhiteSpace(Warning);
    public bool HasError => !string.IsNullOrWhiteSpace(Error);

    public bool IsBusy
    {
        get => isBusy;
        private set { if (Set(ref isBusy, value)) RefreshCommand.RaiseCanExecuteChanged(); }
    }

    public string? Warning
    {
        get => warning;
        private set { if (Set(ref warning, value)) OnPropertyChanged(nameof(HasWarning)); }
    }

    public string? Error
    {
        get => error;
        private set { if (Set(ref error, value)) OnPropertyChanged(nameof(HasError)); }
    }

    public void LoadRegistry()
    {
        try
        {
            registry = auth.LoadRegistry();
            RebuildAccounts();
            Error = null;
        }
        catch (Exception loadError) when (loadError is IOException or UnauthorizedAccessException or InvalidDataException or System.Text.Json.JsonException)
        {
            registry = null;
            Accounts.Clear();
            Error = auth.IsAvailable ? loadError.Message : text["dependency"];
            NotifyAccountState();
        }
    }

    public async Task RefreshAsync(bool manual)
    {
        await RunExclusiveAsync(async () =>
        {
            var previous = registry;
            var result = await auth.RefreshAsync();
            if (!result.Succeeded)
            {
                Warning = result.SafeError("Usage refresh failed.");
                LoadRegistry();
                return;
            }

            Warning = null;
            LoadRegistry();
            if (registry is not null && settings.AutoActivateRefreshedAccounts)
            {
                await TryActivateOneAccountAsync(previous, registry);
            }
        }, manual ? "Another account operation is already running." : null);
    }

    public async Task SwitchAccountAsync(CodexAccount account)
    {
        await RunExclusiveAsync(async () =>
        {
            if (registry?.SwitchTarget(account.AccountKey) is null) return;
            var stop = await CodexAppController.StopAsync();
            if (!stop.Succeeded) { Error = stop.SafeError("Codex could not be closed."); return; }

            var switched = await auth.SwitchAsync(account.CommandSelector);
            if (!switched.Succeeded)
            {
                CodexAppController.Launch();
                Error = switched.SafeError("Account switching failed.");
                return;
            }

            try
            {
                var verified = auth.LoadRegistry();
                if (verified.ActiveAccountKey != account.AccountKey)
                {
                    CodexAppController.Launch();
                    Error = "codex-auth completed, but the active account did not match the requested account.";
                    return;
                }

                registry = verified;
                var launch = CodexAppController.Launch();
                Error = launch.Succeeded ? null : launch.SafeError("Codex could not be launched.");
                RebuildAccounts();
            }
            catch (Exception verifyError) when (verifyError is IOException or InvalidDataException or System.Text.Json.JsonException)
            {
                CodexAppController.Launch();
                Error = verifyError.Message;
            }
        }, "Another account operation is already running.");
    }

    public bool AddAccount()
    {
        if (IsBusy) return false;
        var opened = auth.OpenLoginInTerminal();
        if (!opened) Error = text["dependency"];
        return opened;
    }

    public Task RenameAccountAsync(CodexAccount account, string? alias) => RunExclusiveAsync(async () =>
    {
        var result = await auth.SetAliasAsync(account.CommandSelector, alias);
        if (!result.Succeeded) { Error = result.SafeError("The account could not be renamed."); return; }
        LoadRegistry();
    }, "Another account operation is already running.");

    public Task RemoveAccountAsync(CodexAccount account) => RunExclusiveAsync(async () =>
    {
        var result = await auth.RemoveAccountAsync(account.CommandSelector);
        if (!result.Succeeded) { Error = result.SafeError("The account could not be removed."); return; }
        LoadRegistry();
    }, "Another account operation is already running.");

    public void ApplySettings(AppSettings updated)
    {
        updated.Normalize();
        var executable = Environment.ProcessPath ?? string.Empty;
        StartupManager.SetEnabled(updated.LaunchAtLogin, executable);
        settings = updated;
        settings.LaunchAtLogin = StartupManager.IsEnabled(executable);
        settingsStore.Save(settings);
        text = new Localizer(settings.Language);
        ThemeManager.Apply(settings.Appearance);
        ConfigureTimer();
        RebuildAccounts();
        OnPropertyChanged(string.Empty);
        SettingsApplied?.Invoke(this, EventArgs.Empty);
    }

    private async Task TryActivateOneAccountAsync(CodexRegistry? previous, CodexRegistry current)
    {
        var now = DateTimeOffset.Now;
        var candidate = current.Accounts
            .Select(account => new
            {
                Account = account,
                Boundary = account.WeeklyRefreshBoundary(previous?.Accounts.FirstOrDefault(item => item.AccountKey == account.AccountKey), now),
            })
            .Where(item => item.Boundary is not null
                && item.Account.LastUsage?.Weekly?.RemainingPercent(now) == 100
                && settings.ShouldAttemptActivation(item.Account.AccountKey, item.Boundary!.Value, now))
            .OrderBy(item => item.Boundary)
            .FirstOrDefault();
        if (candidate is null) return;

        settings.AutoActivationAttempts[candidate.Account.AccountKey] = now.ToUnixTimeSeconds();
        settingsStore.Save(settings);
        var stop = await CodexAppController.StopAsync();
        if (!stop.Succeeded) { Warning = stop.SafeError("Codex could not be closed for quota activation."); return; }

        var switched = await auth.SwitchAsync(candidate.Account.CommandSelector);
        if (!switched.Succeeded) { CodexAppController.Launch(); Warning = switched.SafeError("Quota activation account switch failed."); return; }
        CodexRegistry verified;
        try { verified = auth.LoadRegistry(); }
        catch (Exception verifyError) { CodexAppController.Launch(); Warning = verifyError.Message; return; }
        if (verified.ActiveAccountKey != candidate.Account.AccountKey)
        {
            CodexAppController.Launch();
            Warning = "The active account did not match the refreshed account.";
            return;
        }

        var activated = await auth.ActivateQuotaAsync();
        if (!activated.Succeeded) { CodexAppController.Launch(); Warning = activated.SafeError("Quota activation failed."); return; }
        await auth.RefreshActiveAsync();
        var launch = CodexAppController.Launch();
        if (!launch.Succeeded) { Warning = launch.SafeError("Codex could not be launched after quota activation."); return; }

        settings.AutoActivationSuccesses[candidate.Account.AccountKey] = DateTimeOffset.Now.ToUnixTimeSeconds();
        settingsStore.Save(settings);
        Warning = null;
        LoadRegistry();
    }

    private async Task RunExclusiveAsync(Func<Task> operation, string? busyMessage)
    {
        if (!await operationGate.WaitAsync(0))
        {
            if (busyMessage is not null) Warning = busyMessage;
            return;
        }

        IsBusy = true;
        try { await operation(); }
        catch (Exception operationError) { Error = operationError.Message; }
        finally { IsBusy = false; operationGate.Release(); }
    }

    private void RebuildAccounts()
    {
        Accounts.Clear();
        if (registry is not null)
        {
            var now = DateTimeOffset.Now;
            foreach (var account in registry.DisplayAccounts)
            {
                Accounts.Add(new AccountViewModel(account, account.AccountKey == registry.ActiveAccountKey, settings, text, this, now));
            }
        }
        NotifyAccountState();
    }

    private void NotifyAccountState()
    {
        OnPropertyChanged(nameof(HasAccounts));
        OnPropertyChanged(nameof(HasNoAccounts));
        OnPropertyChanged(nameof(EmptyText));
    }

    private void ConfigureTimer()
    {
        refreshTimer.Stop();
        var seconds = settings.RefreshIntervalSeconds == 0
            ? (settings.AutoActivateRefreshedAccounts ? 120 : 0)
            : settings.RefreshIntervalSeconds;
        if (seconds <= 0) return;
        refreshTimer.Interval = TimeSpan.FromSeconds(seconds);
        refreshTimer.Start();
    }

    private bool Set<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        OnPropertyChanged(propertyName);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));

    public void Dispose()
    {
        refreshTimer.Stop();
        operationGate.Dispose();
    }
}
