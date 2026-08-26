using System.Diagnostics;
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

    public static CommandResult NormalizeRefreshResult(CommandResult result) =>
        result.Succeeded && result.StandardOutput.Contains("TimedOut", StringComparison.OrdinalIgnoreCase)
            ? new CommandResult(75, result.StandardOutput, "The usage API timed out. Showing the newest verified values.", true)
            : result;

    public Task<CommandResult> SetAliasAsync(string selector, string? alias, CancellationToken cancellationToken = default) =>
        RunCodexAuthAsync(CodexAuthCommands.SetAlias(selector, alias), TimeSpan.FromSeconds(30), true, cancellationToken);

    public Task<CommandResult> RemoveAccountAsync(string selector, CancellationToken cancellationToken = default) =>
        RunCodexAuthAsync(CodexAuthCommands.RemoveAccount(selector), TimeSpan.FromSeconds(30), true, cancellationToken);

    public Task<CommandResult> SwitchAsync(string selector, CancellationToken cancellationToken = default) =>
        RunCodexAuthAsync(CodexAuthCommands.SwitchAccount(selector), TimeSpan.FromSeconds(30), true, cancellationToken);

    public Task<CommandResult> RefreshActiveAsync(CancellationToken cancellationToken = default) =>
        RunCodexAuthAsync(["list", "--active"], TimeSpan.FromSeconds(30), false, cancellationToken);

    public Task<CommandResult> ActivateQuotaAsync(CancellationToken cancellationToken = default)
    {
        var command = locator.FindCodexCli();
        return command is null
            ? Task.FromResult(new CommandResult(127, string.Empty, "Codex CLI was not found."))
            : runner.RunAsync(command, CodexAuthCommands.ActivateQuota(), TimeSpan.FromSeconds(45), false, cancellationToken);
    }

    public bool OpenLoginInTerminal()
    {
        var command = locator.FindCodexAuth();
        if (command is null) return false;

        var shell = FindOnPath("wt.exe") ?? FindOnPath("powershell.exe");
        if (shell is null) return false;

        var start = new ProcessStartInfo { FileName = shell, UseShellExecute = true };
        if (System.IO.Path.GetFileName(shell).Equals("wt.exe", StringComparison.OrdinalIgnoreCase))
        {
            start.ArgumentList.Add("--title");
            start.ArgumentList.Add("Codex Duo - Add Account");
            start.ArgumentList.Add("powershell.exe");
        }
        start.ArgumentList.Add("-NoExit");
        start.ArgumentList.Add("-Command");
        var arguments = command.PrefixArguments.Concat(["login"]).Select(PowerShellQuote);
        start.ArgumentList.Add("& " + PowerShellQuote(command.FileName) + " " + string.Join(" ", arguments));
        Process.Start(start);
        return true;
    }

    private Task<CommandResult> RunCodexAuthAsync(
        IEnumerable<string> arguments,
        TimeSpan timeout,
        bool captureOutput,
        CancellationToken cancellationToken)
    {
        var command = locator.FindCodexAuth();
        return command is null
            ? Task.FromResult(new CommandResult(127, string.Empty, "codex-auth was not found. Install it with npm install -g @loongphy/codex-auth@next."))
            : runner.RunAsync(command, arguments, timeout, captureOutput, cancellationToken);
    }

    private static string PowerShellQuote(string value) => "'" + value.Replace("'", "''", StringComparison.Ordinal) + "'";

    private static string? FindOnPath(string fileName)
    {
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(System.IO.Path.PathSeparator))
        {
            if (string.IsNullOrWhiteSpace(directory)) continue;
            var candidate = System.IO.Path.Combine(directory.Trim('"'), fileName);
            if (File.Exists(candidate)) return candidate;
        }
        return null;
    }
}

public static class CodexAppController
{
    public const string AppUserModelId = "OpenAI.Codex_2p2nqsd0c76g0!App";

    public static async Task<CommandResult> StopAsync(CancellationToken cancellationToken = default)
    {
        var processes = FindCodexProcesses().ToList();
        if (processes.Count == 0) return new CommandResult(0, string.Empty, string.Empty);

        foreach (var process in processes)
        {
            try { process.CloseMainWindow(); } catch (InvalidOperationException) { }
        }

        var deadline = DateTimeOffset.UtcNow.AddSeconds(5);
        while (DateTimeOffset.UtcNow < deadline && processes.Any(process => !HasExited(process)))
        {
            await Task.Delay(200, cancellationToken);
        }

        foreach (var process in processes.Where(process => !HasExited(process)))
        {
            try { process.Kill(entireProcessTree: true); } catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception) { }
        }

        await Task.Delay(300, cancellationToken);
        return processes.Any(process => !HasExited(process))
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
            return new CommandResult(0, string.Empty, string.Empty);
        }
        catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return new CommandResult(126, string.Empty, $"Codex could not be launched: {error.Message}");
        }
    }

    private static List<Process> FindCodexProcesses()
    {
        var result = Process.GetProcessesByName("Codex").ToList();
        foreach (var process in Process.GetProcessesByName("ChatGPT"))
        {
            try
            {
                if (process.MainModule?.FileName.Contains("\\WindowsApps\\OpenAI.Codex_", StringComparison.OrdinalIgnoreCase) == true)
                {
                    result.Add(process);
                }
            }
            catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception) { }
        }

        return result;
    }

    private static bool HasExited(Process process)
    {
        try { return process.HasExited; }
        catch (InvalidOperationException) { return true; }
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
