using System.Diagnostics;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace CodexDuo.Windows.Core;

public sealed record ToolCommand(string FileName, IReadOnlyList<string> PrefixArguments)
{
    public static ToolCommand Executable(string path) => new(path, []);
    public static ToolCommand NodeScript(string nodePath, string scriptPath) => new(nodePath, [scriptPath]);
}

public sealed partial record CommandResult(int ExitCode, string StandardOutput, string StandardError, bool TimedOut = false)
{
    public bool Succeeded => ExitCode == 0 && !TimedOut;

    public string SafeError(string fallback)
    {
        var value = string.IsNullOrWhiteSpace(StandardError) ? fallback : StandardError.Trim();
        value = BearerTokenPattern().Replace(value, "$1[REDACTED]");
        value = JsonTokenPattern().Replace(value, "$1[REDACTED]");
        return value.Length <= 2_048 ? value : value[..2_048];
    }

    [GeneratedRegex(@"(?i)(bearer\s+)[^\s\""']+")]
    private static partial Regex BearerTokenPattern();

    [GeneratedRegex(@"(?i)(\""?(?:access_token|refresh_token|id_token)\""?\s*[:=]\s*\""?)[^\""\s,}]+")]
    private static partial Regex JsonTokenPattern();
}

public interface ICommandRunner
{
    Task<CommandResult> RunAsync(ToolCommand command, IEnumerable<string> arguments, TimeSpan timeout, bool captureOutput = true, CancellationToken cancellationToken = default);
}

public sealed class ProcessCommandRunner : ICommandRunner
{
    public async Task<CommandResult> RunAsync(
        ToolCommand command,
        IEnumerable<string> arguments,
        TimeSpan timeout,
        bool captureOutput = true,
        CancellationToken cancellationToken = default)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = command.FileName,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = captureOutput,
            RedirectStandardError = captureOutput,
            WorkingDirectory = System.IO.Path.GetTempPath(),
        };

        foreach (var argument in command.PrefixArguments.Concat(arguments))
        {
            startInfo.ArgumentList.Add(argument);
        }

        WindowsProxyEnvironment.ApplyTo(startInfo.Environment);

        using var process = new Process { StartInfo = startInfo };
        try
        {
            if (!process.Start())
            {
                return new CommandResult(126, string.Empty, "The command could not be started.");
            }

            var stdoutTask = captureOutput ? process.StandardOutput.ReadToEndAsync(cancellationToken) : Task.FromResult(string.Empty);
            var stderrTask = captureOutput ? process.StandardError.ReadToEndAsync(cancellationToken) : Task.FromResult(string.Empty);
            using var timeoutSource = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeoutSource.CancelAfter(timeout);
            try
            {
                await process.WaitForExitAsync(timeoutSource.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                try { process.Kill(entireProcessTree: true); } catch (InvalidOperationException) { }
                await process.WaitForExitAsync(CancellationToken.None).ConfigureAwait(false);
                return new CommandResult(124, string.Empty, $"Command timed out after {(int)timeout.TotalSeconds} seconds.", true);
            }

            return new CommandResult(process.ExitCode, await stdoutTask.ConfigureAwait(false), await stderrTask.ConfigureAwait(false));
        }
        catch (Exception error) when (error is IOException or System.ComponentModel.Win32Exception or InvalidOperationException)
        {
            return new CommandResult(126, string.Empty, error.Message);
        }
    }
}

public interface IToolLocator
{
    ToolCommand? FindCodexAuth();
    ToolCommand? FindCodexCli();
}

public sealed class ToolLocator : IToolLocator
{
    public ToolCommand? FindCodexAuth() => FindNpmTool("codex-auth", "@loongphy", "codex-auth");
    public ToolCommand? FindCodexCli() => FindNpmTool("codex", "@openai", "codex");

    private static ToolCommand? FindNpmTool(string executableName, string scope, string packageName)
    {
        if (FindOnPath(executableName + ".exe") is { } executable)
        {
            return ToolCommand.Executable(executable);
        }

        var node = FindOnPath("node.exe");
        if (node is null) return null;

        foreach (var npmRoot in NpmRoots())
        {
            var packageRoot = System.IO.Path.Combine(npmRoot, scope, packageName);
            var packageJson = System.IO.Path.Combine(packageRoot, "package.json");
            if (!File.Exists(packageJson)) continue;

            try
            {
                using var document = JsonDocument.Parse(File.ReadAllText(packageJson));
                if (!document.RootElement.TryGetProperty("bin", out var bin)) continue;
                string? relative = bin.ValueKind switch
                {
                    JsonValueKind.String => bin.GetString(),
                    JsonValueKind.Object when bin.TryGetProperty(executableName, out var value) => value.GetString(),
                    _ => null,
                };
                if (relative is null) continue;
                var script = System.IO.Path.GetFullPath(System.IO.Path.Combine(packageRoot, relative));
                if (File.Exists(script)) return ToolCommand.NodeScript(node, script);
            }
            catch (JsonException) { }
        }

        return null;
    }

    private static IEnumerable<string> NpmRoots()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        if (!string.IsNullOrWhiteSpace(appData)) yield return System.IO.Path.Combine(appData, "npm", "node_modules");

        var prefix = Environment.GetEnvironmentVariable("NPM_CONFIG_PREFIX");
        if (!string.IsNullOrWhiteSpace(prefix)) yield return System.IO.Path.Combine(prefix, "node_modules");
    }

    private static string? FindOnPath(string fileName)
    {
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? string.Empty).Split(System.IO.Path.PathSeparator))
        {
            if (string.IsNullOrWhiteSpace(directory)) continue;
            try
            {
                var candidate = System.IO.Path.Combine(directory.Trim('"'), fileName);
                if (File.Exists(candidate)) return candidate;
            }
            catch (ArgumentException) { }
        }

        return null;
    }
}

public static class CodexAuthCommands
{
    public const string ActivationPrompt = "This is an automated quota-window activation from Codex Duo. Reply with OK only and do not use tools.";

    public static IReadOnlyList<string> SwitchAccount(string accountKey) => ["switch", accountKey, "--json"];
    public static IReadOnlyList<string> LegacySwitchAccount(string selector) => ["switch", selector];
    public static IReadOnlyList<string> SetAlias(string selector, string? alias) =>
        string.IsNullOrWhiteSpace(alias) ? ["alias", "clear", selector] : ["alias", "set", selector, alias.Trim()];
    public static IReadOnlyList<string> RemoveAccount(string selector) => ["remove", selector];
    public static IReadOnlyList<string> ActivateQuota() =>
    [
        "exec", "--ephemeral", "--ignore-user-config", "--ignore-rules",
        "--skip-git-repo-check", "--sandbox", "read-only",
        "--model", "gpt-5.4-mini", "--config", "model_reasoning_effort=\"low\"",
        ActivationPrompt,
    ];
}
