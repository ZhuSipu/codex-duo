using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.Win32;

namespace CodexDuo.Windows.Core;

public sealed class CodexAuthService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private readonly ICommandRunner runner;
    private readonly IToolLocator locator;

    public CodexAuthService(ICommandRunner? runner = null, IToolLocator? locator = null, string? registryPath = null)
    {
        this.runner = runner ?? new ProcessCommandRunner();
        this.locator = locator ?? new ToolLocator();
        RegistryPath = registryPath ?? System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".codex",
            "accounts",
            "registry.json");
    }

    public string RegistryPath { get; }
    public bool IsAvailable => locator.FindCodexAuth() is not null;

    public CodexRegistry LoadRegistry()
    {
        using var stream = new FileStream(RegistryPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        var registry = JsonSerializer.Deserialize<CodexRegistry>(stream, JsonOptions)
            ?? throw new InvalidDataException("The codex-auth registry is empty.");
        return registry;
    }

    public async Task<CommandResult> RefreshAsync(CancellationToken cancellationToken = default)
    {
        var result = await RunCodexAuthAsync(["list"], TimeSpan.FromSeconds(30), true, cancellationToken);
        return NormalizeRefreshResult(result);
    }

    public static CommandResult NormalizeRefreshResult(CommandResult result)
    {
        if (!result.Succeeded) return result;
        if (result.StandardOutput.Contains("TimedOut", StringComparison.OrdinalIgnoreCase))
        {
            return new CommandResult(75, result.StandardOutput, "The usage API timed out. Showing the newest verified values.", true);
        }
        if (result.StandardOutput.Contains("401 token_invalidated", StringComparison.OrdinalIgnoreCase))
        {
            return new CommandResult(
                77,
                result.StandardOutput,
                "One or more accounts have an invalidated login. Sign in to the affected account again, then refresh.");
        }
        return result;
    }

    public Task<CommandResult> SetAliasAsync(string selector, string? alias, CancellationToken cancellationToken = default) =>
        RunCodexAuthAsync(CodexAuthCommands.SetAlias(selector, alias), TimeSpan.FromSeconds(30), true, cancellationToken);

    public Task<CommandResult> RemoveAccountAsync(string selector, CancellationToken cancellationToken = default) =>
        RunCodexAuthAsync(CodexAuthCommands.RemoveAccount(selector), TimeSpan.FromSeconds(30), true, cancellationToken);

    public async Task<CommandResult> SwitchAsync(
        string accountKey,
        string legacySelector,
        CancellationToken cancellationToken = default)
    {
        var result = await RunCodexAuthAsync(
            CodexAuthCommands.SwitchAccount(accountKey),
            TimeSpan.FromSeconds(30),
            true,
            cancellationToken);
        if (JsonSwitchIsUnsupported(result))
        {
            DiagnosticLog.Write("switch.json-unavailable", "using-legacy-cli");
            return await RunCodexAuthAsync(
                CodexAuthCommands.LegacySwitchAccount(legacySelector),
                TimeSpan.FromSeconds(30),
                true,
                cancellationToken);
        }
        return NormalizeSwitchResult(result, accountKey);
    }

    public static bool JsonSwitchIsUnsupported(CommandResult result) =>
        result.ExitCode == 2
        && (result.StandardOutput.Contains("--json", StringComparison.OrdinalIgnoreCase)
            || result.StandardError.Contains("--json", StringComparison.OrdinalIgnoreCase));

    public static CommandResult NormalizeSwitchResult(CommandResult result, string requestedAccountKey)
    {
        try
        {
            using var document = JsonDocument.Parse(result.StandardOutput);
            var root = document.RootElement;
            if (root.TryGetProperty("error", out var error))
            {
                var code = error.TryGetProperty("code", out var codeValue) ? codeValue.GetString() : null;
                var message = error.TryGetProperty("message", out var messageValue) ? messageValue.GetString() : null;
                var fallback = code == "state_uncertain"
                    ? "codex-auth could not confirm the switch. Refresh the account list before retrying."
                    : "Account switching failed.";
                return new CommandResult(
                    result.ExitCode == 0 ? 1 : result.ExitCode,
                    result.StandardOutput,
                    string.IsNullOrWhiteSpace(message) ? fallback : message,
                    result.TimedOut);
            }

            var schemaIsSupported = root.TryGetProperty("schema_version", out var schema)
                && schema.ValueKind == JsonValueKind.Number
                && schema.GetInt32() == 1;
            var commandIsSwitch = root.TryGetProperty("command", out var command)
                && command.ValueKind == JsonValueKind.String
                && command.GetString() == "switch";
            var accountMatches = root.TryGetProperty("switched_to", out var switchedTo)
                && switchedTo.ValueKind == JsonValueKind.Object
                && switchedTo.TryGetProperty("account_key", out var accountKey)
                && accountKey.ValueKind == JsonValueKind.String
                && string.Equals(accountKey.GetString(), requestedAccountKey, StringComparison.Ordinal);

            if (result.Succeeded && schemaIsSupported && commandIsSwitch && accountMatches)
            {
                return result;
            }

            return new CommandResult(
                result.ExitCode == 0 ? 65 : result.ExitCode,
                result.StandardOutput,
                "codex-auth returned an unexpected switch result. The active account was not accepted as verified.",
                result.TimedOut);
        }
        catch (JsonException)
        {
            return result.Succeeded
                ? new CommandResult(65, result.StandardOutput, "codex-auth did not return valid JSON. Reinstall Codex Duo and retry.")
                : result;
        }
    }

    public async Task<CommandResult> LoginInTerminalAsync(CancellationToken cancellationToken = default)
    {
        var command = locator.FindCodexAuth();
        if (command is null) return new CommandResult(127, string.Empty, IncompleteInstallationMessage);
        var shell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
            "WindowsPowerShell", "v1.0", "powershell.exe");
        var start = new ProcessStartInfo
        {
            FileName = shell,
            UseShellExecute = false,
            CreateNoWindow = false,
            WorkingDirectory = Path.GetTempPath(),
        };
        WindowsProxyEnvironment.ApplyTo(start.Environment);
        start.ArgumentList.Add("-NoLogo");
        start.ArgumentList.Add("-NoProfile");
        start.ArgumentList.Add("-EncodedCommand");
        start.ArgumentList.Add(Convert.ToBase64String(System.Text.Encoding.Unicode.GetBytes(BuildLoginScript(command))));
        try
        {
            using var process = Process.Start(start);
            if (process is null) return new CommandResult(126, string.Empty, "Could not open Windows PowerShell. Choose Add to retry.");
            await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
            return new CommandResult(process.ExitCode, string.Empty,
                process.ExitCode == 0 ? string.Empty : "Login was cancelled or failed. Choose Add to retry.");
        }
        catch (Exception error) when (error is IOException or System.ComponentModel.Win32Exception or InvalidOperationException)
        {
            return new CommandResult(126, string.Empty, "Could not open the login terminal. Choose Add to retry.");
        }
    }

    public const string IncompleteInstallationMessage = "Codex Duo installation is incomplete. Download and reinstall the complete app.";

    public static string BuildLoginScript(ToolCommand command)
    {
        var arguments = command.PrefixArguments.Concat(["login"]).Select(PowerShellQuote);
        // Restrict package discovery to the official desktop app and its CLI resource.
        // Change PATH only in this visible login terminal, never in user settings.
        return """
            $ErrorActionPreference = 'Stop'
            $env:PSModulePath = (Join-Path $PSHOME 'Modules') + ';' + $env:PSModulePath
            $Host.UI.RawUI.WindowTitle = 'Codex Duo - Add Account'
            try {
                $package = Get-AppxPackage -Name OpenAI.Codex | Where-Object { $_.PackageFamilyName -eq 'OpenAI.Codex_2p2nqsd0c76g0' } | Select-Object -First 1
                $cliDirectory = if ($package) { Join-Path $package.InstallLocation 'app\resources' } else { $null }
                if ($cliDirectory -and (Test-Path -LiteralPath (Join-Path $cliDirectory 'codex.exe'))) {
                    $env:PATH = $cliDirectory + ';' + $env:PATH
                } else {
                    $cliDirectory = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin\build'
                    if (Test-Path -LiteralPath (Join-Path $cliDirectory 'codex.exe')) {
                        $env:PATH = $cliDirectory + ';' + $env:PATH
                    } elseif (-not (Get-Command codex.exe -ErrorAction SilentlyContinue)) {
                        throw 'Install and launch the official Codex app, then choose Add again.'
                    }
                }
            """ + "\n& " + PowerShellQuote(command.FileName) + " " + string.Join(" ", arguments) + "\n" + """
                $loginExitCode = $LASTEXITCODE
                if ($loginExitCode -ne 0) {
                    Write-Host 'Login did not complete. Choose Add in Codex Duo to retry.'
                    Start-Sleep -Seconds 4
                }
                exit $loginExitCode
            } catch {
                Write-Host 'Login could not start. Check the official Codex app installation and choose Add to retry.'
                Start-Sleep -Seconds 4
                exit 126
            }
            """;
    }

    private Task<CommandResult> RunCodexAuthAsync(
        IEnumerable<string> arguments,
        TimeSpan timeout,
        bool captureOutput,
        CancellationToken cancellationToken)
    {
        var command = locator.FindCodexAuth();
        return command is null
            ? Task.FromResult(new CommandResult(127, string.Empty, IncompleteInstallationMessage))
            : runner.RunAsync(command, arguments, timeout, captureOutput, cancellationToken);
    }

    private static string PowerShellQuote(string value) => "'" + value.Replace("'", "''", StringComparison.Ordinal) + "'";


}

public static class CodexAppController
{
    public const string AppUserModelId = "OpenAI.Codex_2p2nqsd0c76g0!App";
    public const string PackageFamilyName = "OpenAI.Codex_2p2nqsd0c76g0";
    private const uint ProcessQueryLimitedInformation = 0x1000;
    private const int ErrorInsufficientBuffer = 122;

    public static async Task<CommandResult> StopAsync(CancellationToken cancellationToken = default)
    {
        if (IsCurrentProcessDescendantOfCodex())
        {
            DiagnosticLog.Write("codex.stop.blocked", "duo-is-in-codex-process-tree");
            return new CommandResult(
                5,
                string.Empty,
                "Codex Duo is still attached to the Codex process. Quit Duo and reopen it from the Start menu, then retry.");
        }

        var frontends = FindCodexProcesses();
        if (frontends.Count == 0) return new CommandResult(0, string.Empty, string.Empty);
        var processes = frontends.Concat(FindCodexBackendProcesses(frontends)).ToList();
        DiagnosticLog.Write("codex.stop.begin", $"frontend={frontends.Count}; total={processes.Count}");

        foreach (var process in frontends)
        {
            try { process.CloseMainWindow(); } catch (InvalidOperationException) { }
        }

        // The packaged app keeps background Electron processes alive after its
        // window closes. Give it a short chance to flush UI state, then stop
        // only the remaining verified Codex processes so switching is prompt.
        var deadline = DateTimeOffset.UtcNow.AddSeconds(1);
        while (DateTimeOffset.UtcNow < deadline && processes.Any(process => !HasExited(process)))
        {
            await Task.Delay(50, cancellationToken);
        }

        var forcedCount = 0;
        foreach (var process in processes.Where(process => !HasExited(process)))
        {
            try
            {
                process.Kill(entireProcessTree: false);
                forcedCount++;
            }
            catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception) { }
        }
        if (forcedCount > 0) DiagnosticLog.Write("codex.stop.forced", $"count={forcedCount}");

        // Kill() only requests termination. Electron commonly needs several
        // hundred milliseconds to tear down its process tree, and can briefly
        // replace a utility process while doing so. A single snapshot after
        // 150 ms therefore reported a false failure even though Codex exited
        // moments later. Poll the verified frontend set through a bounded
        // grace period and stop any short-lived replacements it creates.
        var shutdownDeadline = DateTimeOffset.UtcNow.AddSeconds(3);
        var remainingCount = 0;
        do
        {
            await Task.Delay(100, cancellationToken);
            var remainingFrontends = FindCodexProcesses();
            remainingCount = remainingFrontends.Count
                + processes.Count(process => !HasExited(process));

            foreach (var process in remainingFrontends)
            {
                if (!HasExited(process))
                {
                    try { process.Kill(entireProcessTree: false); }
                    catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception) { }
                }
                process.Dispose();
            }
        }
        while (remainingCount > 0 && DateTimeOffset.UtcNow < shutdownDeadline);

        var failed = remainingCount > 0;
        foreach (var process in processes) process.Dispose();
        DiagnosticLog.Write(
            failed ? "codex.stop.failed" : "codex.stop.complete",
            failed ? $"remaining={remainingCount}" : null);
        return failed
            ? new CommandResult(5, string.Empty, "Codex could not be closed. Stop active work or close Codex manually, then retry.")
            : new CommandResult(0, string.Empty, string.Empty);
    }

    public static CommandResult Launch()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "explorer.exe",
                UseShellExecute = true,
                Arguments = $"shell:AppsFolder\\{AppUserModelId}",
            });
            DiagnosticLog.Write("codex.launch.requested");
            return new CommandResult(0, string.Empty, string.Empty);
        }
        catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return new CommandResult(126, string.Empty, $"Codex could not be launched: {error.Message}");
        }
    }

    public static async Task<CommandResult> LaunchAndWaitAsync(
        TimeSpan? timeout = null,
        CancellationToken cancellationToken = default)
    {
        var deadline = DateTimeOffset.UtcNow.Add(timeout ?? TimeSpan.FromSeconds(24));
        if (HasVisibleCodexWindow())
        {
            DiagnosticLog.Write("codex.launch.already-running");
            return new CommandResult(0, string.Empty, string.Empty);
        }

        CommandResult? lastLaunch = null;
        for (var attempt = 1; attempt <= 2; attempt++)
        {
            lastLaunch = Launch();
            if (!lastLaunch.Succeeded) return lastLaunch;
            DiagnosticLog.Write("codex.launch.wait", $"attempt={attempt}");

            var attemptDeadline = attempt == 1
                ? DateTimeOffset.UtcNow.AddSeconds(10)
                : deadline;
            if (attemptDeadline > deadline) attemptDeadline = deadline;
            while (DateTimeOffset.UtcNow < attemptDeadline)
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (HasVisibleCodexWindow())
                {
                    DiagnosticLog.Write("codex.launch.ready", $"attempt={attempt}");
                    return new CommandResult(0, string.Empty, string.Empty);
                }
                await Task.Delay(250, cancellationToken);
            }

            if (attempt == 1 && DateTimeOffset.UtcNow < deadline)
            {
                DiagnosticLog.Write("codex.launch.retry");
                await Task.Delay(1_000, cancellationToken);
            }
        }

        DiagnosticLog.Write("codex.launch.failed", "window-not-detected");
        return new CommandResult(
            lastLaunch?.ExitCode ?? 5,
            string.Empty,
            "Windows accepted the Codex launch request, but no Codex window appeared. Open Codex manually and retry.");
    }

    private static bool HasVisibleCodexWindow()
    {
        var processes = FindCodexProcesses();
        try
        {
            return processes.Any(process => !HasExited(process) && process.MainWindowHandle != IntPtr.Zero);
        }
        finally
        {
            foreach (var process in processes) process.Dispose();
        }
    }

    private static List<Process> FindCodexProcesses()
    {
        var result = new List<Process>();
        foreach (var process in Process.GetProcessesByName("ChatGPT"))
        {
            try
            {
                if (HasCodexPackageIdentity(process) || IsCodexDesktopExecutable(TryGetExecutablePath(process)))
                {
                    result.Add(process);
                    continue;
                }
            }
            catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception) { }
            process.Dispose();
        }

        return result;
    }

    private static List<Process> FindCodexBackendProcesses(IReadOnlyCollection<Process> frontends)
    {
        var frontendIds = frontends.Select(process => process.Id).ToHashSet();
        var result = new List<Process>();
        foreach (var process in Process.GetProcessesByName("codex"))
        {
            if (frontendIds.Contains(GetParentProcessId(process))
                && IsCodexDesktopBackendExecutable(TryGetExecutablePath(process)))
            {
                result.Add(process);
            }
            else
            {
                process.Dispose();
            }
        }
        return result;
    }

    public static bool IsCodexDesktopExecutable(string? executablePath) =>
        !string.IsNullOrWhiteSpace(executablePath)
        && executablePath.Contains("\\WindowsApps\\OpenAI.Codex_", StringComparison.OrdinalIgnoreCase)
        && executablePath.EndsWith("\\app\\ChatGPT.exe", StringComparison.OrdinalIgnoreCase);

    public static bool IsCodexDesktopBackendExecutable(string? executablePath) =>
        !string.IsNullOrWhiteSpace(executablePath)
        && executablePath.Contains("\\AppData\\Local\\OpenAI\\Codex\\bin\\", StringComparison.OrdinalIgnoreCase)
        && executablePath.EndsWith("\\codex.exe", StringComparison.OrdinalIgnoreCase);

    public static bool IsCodexDesktopProcess(Process process) =>
        HasCodexPackageIdentity(process) || IsCodexDesktopExecutable(TryGetExecutablePath(process));

    public static bool IsCurrentProcessDescendantOfCodex()
    {
        using var current = Process.GetCurrentProcess();
        var parentId = GetParentProcessId(current);
        var visited = new HashSet<int> { current.Id };
        for (var depth = 0; depth < 32 && parentId > 0 && visited.Add(parentId); depth++)
        {
            Process? parent = null;
            try
            {
                parent = Process.GetProcessById(parentId);
                var name = parent.ProcessName;
                var path = TryGetExecutablePath(parent);
                if ((name.Equals("ChatGPT", StringComparison.OrdinalIgnoreCase)
                        && (HasCodexPackageIdentity(parent) || IsCodexDesktopExecutable(path)))
                    || (name.Equals("codex", StringComparison.OrdinalIgnoreCase)
                        && IsCodexDesktopBackendExecutable(path)))
                {
                    return true;
                }
                parentId = GetParentProcessId(parent);
            }
            catch (Exception error) when (error is ArgumentException or InvalidOperationException or System.ComponentModel.Win32Exception)
            {
                return false;
            }
            finally
            {
                parent?.Dispose();
            }
        }
        return false;
    }

    private static bool HasCodexPackageIdentity(Process process)
    {
        IntPtr handle = IntPtr.Zero;
        try
        {
            handle = OpenProcess(ProcessQueryLimitedInformation, false, process.Id);
            if (handle == IntPtr.Zero) return false;

            uint length = 0;
            var status = GetPackageFamilyName(handle, ref length, null);
            if (status != ErrorInsufficientBuffer || length == 0) return false;

            var familyName = new char[length];
            status = GetPackageFamilyName(handle, ref length, familyName);
            var valueLength = Array.IndexOf(familyName, '\0');
            if (valueLength < 0) valueLength = familyName.Length;
            return status == 0
                && string.Equals(new string(familyName, 0, valueLength), PackageFamilyName, StringComparison.OrdinalIgnoreCase);
        }
        catch (Exception error) when (error is ArgumentException or InvalidOperationException)
        {
            return false;
        }
        finally
        {
            if (handle != IntPtr.Zero) CloseHandle(handle);
        }
    }

    private static string? TryGetExecutablePath(Process process)
    {
        try { return process.MainModule?.FileName; }
        catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception) { return null; }
    }

    private static int GetParentProcessId(Process process)
    {
        IntPtr handle = IntPtr.Zero;
        try
        {
            handle = OpenProcess(ProcessQueryLimitedInformation, false, process.Id);
            if (handle == IntPtr.Zero) return -1;
            var information = new ProcessBasicInformation();
            var status = NtQueryInformationProcess(
                handle,
                0,
                ref information,
                Marshal.SizeOf<ProcessBasicInformation>(),
                out _);
            return status == 0 ? information.InheritedFromUniqueProcessId.ToInt32() : -1;
        }
        catch (Exception error) when (error is ArgumentException or InvalidOperationException or OverflowException)
        {
            return -1;
        }
        finally
        {
            if (handle != IntPtr.Zero) CloseHandle(handle);
        }
    }

    private static bool HasExited(Process process)
    {
        try { return process.HasExited; }
        catch (InvalidOperationException) { return true; }
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint desiredAccess, [MarshalAs(UnmanagedType.Bool)] bool inheritHandle, int processId);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetPackageFamilyName(IntPtr process, ref uint packageFamilyNameLength, [Out] char[]? packageFamilyName);

    [DllImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("ntdll.dll")]
    private static extern int NtQueryInformationProcess(
        IntPtr processHandle,
        int processInformationClass,
        ref ProcessBasicInformation processInformation,
        int processInformationLength,
        out int returnLength);

    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessBasicInformation
    {
        public IntPtr Reserved1;
        public IntPtr PebBaseAddress;
        public IntPtr Reserved2_0;
        public IntPtr Reserved2_1;
        public IntPtr UniqueProcessId;
        public IntPtr InheritedFromUniqueProcessId;
    }
}

public static class StartupManager
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "Codex Duo";

    public static bool IsEnabled(string executablePath)
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false);
        var expected = $"\"{executablePath}\" --startup";
        return string.Equals(key?.GetValue(ValueName) as string, expected, StringComparison.OrdinalIgnoreCase);
    }

    public static void SetEnabled(bool enabled, string executablePath)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath, true)
            ?? throw new InvalidOperationException("Windows startup settings could not be opened.");
        if (enabled)
        {
            key.SetValue(ValueName, $"\"{executablePath}\" --startup", RegistryValueKind.String);
        }
        else
        {
            key.DeleteValue(ValueName, false);
        }
    }
}
