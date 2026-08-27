using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Globalization;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using CodexDuo.Windows.Core;

namespace CodexDuo.Windows;

public sealed class AccountViewModel
{
    public AccountViewModel(CodexAccount account, bool active, bool showsSeparator, AppSettings settings, Localizer text, MainViewModel owner, DateTimeOffset now)
    {
        Account = account;
        IsActive = active;
        CanSwitch = !active;
        ShowsSeparator = showsSeparator;
        DisplayName = account.DisplayName;
        Subtitle = string.IsNullOrWhiteSpace(account.Plan) ? account.Email : $"{account.Email} · {account.Plan}";
        SecondaryText = account.DisplayName == account.Email ? Capitalize(account.Plan ?? "Unknown") : account.Email;
        PlanText = Capitalize(account.Plan ?? "Unknown");
        AgeText = account.UsageAgeText(now);
        ActiveText = text["active"];
        FiveHourLabel = "5H";
        WeeklyLabel = "WEEK";
        RemainingLabel = text["remaining"];
        UsageMeters = AccountUsagePresentation.Build(account, settings, now);
        SwitchCommand = new AsyncCommand(() => owner.SwitchAccountAsync(account), () => !IsActive && !owner.IsBusy);
    }

    public CodexAccount Account { get; }
    public bool IsActive { get; }
    public bool CanSwitch { get; }
    public bool ShowsSeparator { get; }
    public string DisplayName { get; }
    public string Subtitle { get; }
    public string SecondaryText { get; }
    public string PlanText { get; }
    public string? AgeText { get; }
    public string ActiveText { get; }
    public string FiveHourLabel { get; }
    public string WeeklyLabel { get; }
    public string RemainingLabel { get; }
    public IReadOnlyList<UsageMeterPresentation> UsageMeters { get; }
    public int UsageColumnCount => Math.Clamp(UsageMeters.Count, 1, 2);
    public ICommand SwitchCommand { get; }

    private static string Capitalize(string value) => string.IsNullOrEmpty(value)
        ? value
        : char.ToUpperInvariant(value[0]) + value[1..];
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
    public string GeneralText => text["general"];
    public string DependencyText => auth.IsAvailable ? text["dependencyReady"] : text["dependency"];
    public string AccountCountText => Accounts.Count == 0
        ? text["none"]
        : string.Format(CultureInfo.CurrentCulture, text["accountCount"], Accounts.Count);
    public bool IsDependencyAvailable => auth.IsAvailable;
    public bool CanAddAccounts => auth.IsAvailable && Accounts.Count < CodexRegistry.MaximumSupportedAccounts;
    public string EmptyText => Error ?? (auth.IsAvailable ? text["empty"] : text["dependency"]);
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
        private set
        {
            if (!Set(ref error, value)) return;
            OnPropertyChanged(nameof(HasError));
            OnPropertyChanged(nameof(EmptyText));
        }
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
            Error = null;
            DiagnosticLog.Write("switch.begin");
            var stop = await CodexAppController.StopAsync();
            if (!stop.Succeeded) { Error = stop.SafeError("Codex could not be closed."); return; }
            try
            {
                var switched = await auth.SwitchAsync(account.AccountKey, account.CommandSelector);
                if (!switched.Succeeded)
                {
                    Error = switched.SafeError("Account switching failed.");
                    DiagnosticLog.Write("switch.command-failed", $"exit={switched.ExitCode}");
                    return;
                }

                var verified = auth.LoadRegistry();
                if (verified.ActiveAccountKey != account.AccountKey)
                {
                    Error = "codex-auth completed, but the active account did not match the requested account.";
                    DiagnosticLog.Write("switch.verify-failed");
                    return;
                }

                registry = verified;
                RebuildAccounts();
                DiagnosticLog.Write("switch.verified");
            }
            finally
            {
                var launch = await CodexAppController.LaunchAndWaitAsync();
                if (!launch.Succeeded)
                {
                    var launchError = launch.SafeError("Codex could not be launched.");
                    Error = string.IsNullOrWhiteSpace(Error) ? launchError : $"{Error} {launchError}";
                }
                DiagnosticLog.Write(launch.Succeeded ? "switch.relaunch-complete" : "switch.relaunch-failed");
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
        DiagnosticLog.Write("activation.begin");
        var stop = await CodexAppController.StopAsync();
        if (!stop.Succeeded) { Warning = stop.SafeError("Codex could not be closed for quota activation."); return; }
        var activationCompleted = false;
        try
        {
            var switched = await auth.SwitchAsync(candidate.Account.AccountKey, candidate.Account.CommandSelector);
            if (!switched.Succeeded) { Warning = switched.SafeError("Quota activation account switch failed."); return; }
            var verified = auth.LoadRegistry();
            if (verified.ActiveAccountKey != candidate.Account.AccountKey)
            {
                Warning = "The active account did not match the refreshed account.";
                return;
            }

            var activated = await auth.ActivateQuotaAsync();
            if (!activated.Succeeded) { Warning = activated.SafeError("Quota activation failed."); return; }
            await auth.RefreshActiveAsync();
            activationCompleted = true;
        }
        finally
        {
            var launch = await CodexAppController.LaunchAndWaitAsync();
            if (!launch.Succeeded)
            {
                var launchError = launch.SafeError("Codex could not be launched after quota activation.");
                Warning = string.IsNullOrWhiteSpace(Warning) ? launchError : $"{Warning} {launchError}";
                activationCompleted = false;
            }
            DiagnosticLog.Write(launch.Succeeded ? "activation.relaunch-complete" : "activation.relaunch-failed");
        }
        if (!activationCompleted) return;

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
            var displayAccounts = registry.DisplayAccounts;
            for (var index = 0; index < displayAccounts.Count; index++)
            {
                var account = displayAccounts[index];
                Accounts.Add(new AccountViewModel(
                    account,
                    account.AccountKey == registry.ActiveAccountKey,
                    index < displayAccounts.Count - 1,
                    settings,
                    text,
                    this,
                    now));
            }
        }
        NotifyAccountState();
    }

    private void NotifyAccountState()
    {
        OnPropertyChanged(nameof(HasAccounts));
        OnPropertyChanged(nameof(HasNoAccounts));
        OnPropertyChanged(nameof(EmptyText));
        OnPropertyChanged(nameof(AccountCountText));
        OnPropertyChanged(nameof(DependencyText));
        OnPropertyChanged(nameof(IsDependencyAvailable));
        OnPropertyChanged(nameof(CanAddAccounts));
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
