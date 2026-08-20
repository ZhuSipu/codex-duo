using System.Diagnostics;
using System.IO;
using System.Text.Json;

namespace CodexDuo.Windows;

public sealed record CommandResult(int Status, string Stdout, string Stderr) { public bool Succeeded => Status == 0; }

public sealed class CodexAuthService
{
    public string RegistryPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".codex", "accounts", "registry.json");
    public string? ExecutablePath => FindExecutable();
    public bool IsAvailable => ExecutablePath is not null;

    public async Task<CodexRegistry> LoadRegistryAsync(CancellationToken token = default)
    {
        await using var stream = File.OpenRead(RegistryPath);
        return await JsonSerializer.DeserializeAsync<CodexRegistry>(stream, cancellationToken: token) ?? throw new InvalidDataException("The codex-auth registry is empty.");
    }
    public Task<CommandResult> RefreshAsync() => RunAsync(["list"]);
    public Task<CommandResult> SetAliasAsync(string account, string? alias) => string.IsNullOrWhiteSpace(alias) ? RunAsync(["alias", "clear", account]) : RunAsync(["alias", "set", account, alias.Trim()]);
    public Task<CommandResult> RemoveAsync(string account) => RunAsync(["remove", account, "--skip-api"]);

    public CommandResult OpenLoginTerminal()
    {
        var executable = ExecutablePath;
        if (executable is null) return new(127, "", "codex-auth was not found.");
        var command = $"{QuoteForCmd(executable)} login";
        Process.Start(new ProcessStartInfo("cmd.exe", $"/k {command}") { UseShellExecute = true });
        return new(0, "", "");
    }
    public void OpenDependencyInstaller() => Process.Start(new ProcessStartInfo("cmd.exe", "/k npm install -g @loongphy/codex-auth@next") { UseShellExecute = true });

    public async Task<CommandResult> SwitchAndRestartCodexAsync(CodexAccount target)
    {
        var appId = await FindCodexStartAppIdAsync();
        if (appId is null) return new(4, "", "The official Codex app was not found in the Windows Start menu. Install or launch it once, then retry.");
        var close = await CloseCodexDesktopAsync();
        if (!close.Succeeded) return close;
        var switched = await RunAsync(["switch", target.Email]);
        if (!switched.Succeeded) { LaunchCodex(appId); return switched; }
        try
        {
            var registry = await LoadRegistryAsync();
            if (registry.ActiveAccountKey != target.AccountKey) { LaunchCodex(appId); return new(2, switched.Stdout, "codex-auth completed, but the active account did not match the requested account."); }
        }
        catch (Exception ex) { LaunchCodex(appId); return new(3, switched.Stdout, ex.Message); }
        LaunchCodex(appId);
        return new(0, switched.Stdout, "");
    }

    private async Task<CommandResult> CloseCodexDesktopAsync()
    {
        var processes = Process.GetProcesses().Where(p =>
        {
            try { return p.MainWindowHandle != IntPtr.Zero && (p.ProcessName.Equals("Codex", StringComparison.OrdinalIgnoreCase) || p.ProcessName.Equals("OpenAI.Codex", StringComparison.OrdinalIgnoreCase)); }
            catch { return false; }
        }).ToList();
        foreach (var process in processes) { try { process.CloseMainWindow(); } catch { } }
        var deadline = DateTime.UtcNow.AddSeconds(10);
        while (DateTime.UtcNow < deadline && processes.Any(p => { try { return !p.HasExited; } catch { return false; } })) await Task.Delay(250);
        if (processes.Any(p => { try { return !p.HasExited; } catch { return false; } })) return new(5, "", "Codex did not close within 10 seconds. Finish or stop active work, close Codex, and retry. Codex Duo will not force-kill it.");
        return new(0, "", "");
    }
    private static void LaunchCodex(string appId) => Process.Start(new ProcessStartInfo("explorer.exe", $"shell:AppsFolder\\{appId}") { UseShellExecute = true });
    private static async Task<string?> FindCodexStartAppIdAsync()
    {
        var script = "$a=Get-StartApps | Where-Object {$_.Name -eq 'Codex' -or $_.Name -eq 'OpenAI Codex'} | Select-Object -First 1 -ExpandProperty AppID; if($a){[Console]::Write($a)}";
        var result = await RunProcessAsync("powershell.exe", ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script]);
        return result.Succeeded && !string.IsNullOrWhiteSpace(result.Stdout) ? result.Stdout.Trim() : null;
    }
    private async Task<CommandResult> RunAsync(IReadOnlyList<string> arguments)
    {
        var executable = ExecutablePath;
        if (executable is null) return new(127, "", "codex-auth was not found.");
        if (executable.EndsWith(".cmd", StringComparison.OrdinalIgnoreCase) || executable.EndsWith(".bat", StringComparison.OrdinalIgnoreCase))
            return await RunProcessAsync("cmd.exe", ["/d", "/s", "/c", QuoteForCmd(executable) + " " + string.Join(" ", arguments.Select(QuoteForCmd))]);
        return await RunProcessAsync(executable, arguments);
    }
    private static async Task<CommandResult> RunProcessAsync(string fileName, IReadOnlyList<string> arguments)
    {
        var info = new ProcessStartInfo(fileName) { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        foreach (var argument in arguments) info.ArgumentList.Add(argument);
        try { using var process = Process.Start(info)!; var stdout = process.StandardOutput.ReadToEndAsync(); var stderr = process.StandardError.ReadToEndAsync(); await process.WaitForExitAsync(); return new(process.ExitCode, await stdout, await stderr); }
        catch (Exception ex) { return new(126, "", ex.Message); }
    }
    private static string QuoteForCmd(string value) => "\"" + value.Replace("\"", "\"\"") + "\"";
    private static string? FindExecutable()
    {
        var explicitPath = Environment.GetEnvironmentVariable("CODEX_AUTH_PATH");
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var candidates = new List<string?> { explicitPath, Path.Combine(home, ".local", "bin", "codex-auth.exe"), Path.Combine(home, ".local", "bin", "codex-auth.cmd"), Path.Combine(appData, "npm", "codex-auth.exe"), Path.Combine(appData, "npm", "codex-auth.cmd") };
        foreach (var folder in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries))
            foreach (var name in new[] { "codex-auth.exe", "codex-auth.cmd", "codex-auth.bat" }) candidates.Add(Path.Combine(folder.Trim('"'), name));
        return candidates.FirstOrDefault(path => !string.IsNullOrWhiteSpace(path) && File.Exists(path));
    }
}
