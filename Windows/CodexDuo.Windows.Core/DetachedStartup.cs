using System.Diagnostics;

namespace CodexDuo.Windows.Core;

public static class DetachedStartup
{
    public const string DetachedArgument = "--codex-duo-detached";
    public const string ParentArgument = "--codex-duo-parent";
    public const string TaskArgument = "--codex-duo-task";

    public static bool IsDetachedLaunch(IReadOnlyList<string> arguments) =>
        arguments.Contains(DetachedArgument, StringComparer.OrdinalIgnoreCase);

    public static bool TryRelaunchIndependent(string executablePath, int currentProcessId, out string? error)
    {
        error = null;
        var taskName = $"CodexDuo.Detach.{Guid.NewGuid():N}";
        var launchArguments = $"{Quote(executablePath)} {DetachedArgument} {ParentArgument} {currentProcessId} {TaskArgument} {taskName}";
        var startAt = DateTime.Now.AddMinutes(1).ToString("HH:mm", System.Globalization.CultureInfo.InvariantCulture);

        var create = RunTaskScheduler([
            "/Create", "/TN", taskName, "/TR", launchArguments,
            "/SC", "ONCE", "/ST", startAt, "/RL", "LIMITED", "/F",
        ]);
        if (!create.Succeeded)
        {
            error = create.StandardError;
            return false;
        }

        var run = RunTaskScheduler(["/Run", "/TN", taskName]);
        if (run.Succeeded) return true;

        _ = RunTaskScheduler(["/Delete", "/TN", taskName, "/F"]);
        error = run.StandardError;
        return false;
    }

    public static void CompleteDetachedLaunch(IReadOnlyList<string> arguments)
    {
        var taskName = ValueAfter(arguments, TaskArgument);
        if (!string.IsNullOrWhiteSpace(taskName))
        {
            _ = RunTaskScheduler(["/Delete", "/TN", taskName, "/F"]);
        }

        if (int.TryParse(ValueAfter(arguments, ParentArgument), out var parentId))
        {
            try
            {
                using var parent = Process.GetProcessById(parentId);
                parent.WaitForExit(15_000);
            }
            catch (ArgumentException) { }
            catch (InvalidOperationException) { }
        }
    }

    public static string? ValueAfter(IReadOnlyList<string> arguments, string name)
    {
        for (var index = 0; index + 1 < arguments.Count; index++)
        {
            if (string.Equals(arguments[index], name, StringComparison.OrdinalIgnoreCase))
            {
                return arguments[index + 1];
            }
        }
        return null;
    }

    private static CommandResult RunTaskScheduler(IEnumerable<string> arguments)
    {
        var start = new ProcessStartInfo
        {
            FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "schtasks.exe"),
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        foreach (var argument in arguments) start.ArgumentList.Add(argument);

        try
        {
            using var process = Process.Start(start);
            if (process is null) return new CommandResult(126, string.Empty, "Task Scheduler could not be started.");
            var output = process.StandardOutput.ReadToEnd();
            var error = process.StandardError.ReadToEnd();
            if (!process.WaitForExit(10_000))
            {
                try { process.Kill(); } catch (InvalidOperationException) { }
                return new CommandResult(124, output, "Task Scheduler timed out.", true);
            }
            return new CommandResult(process.ExitCode, output, error);
        }
        catch (Exception exception) when (exception is IOException or InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return new CommandResult(126, string.Empty, exception.Message);
        }
    }

    private static string Quote(string value) => "\"" + value.Replace("\"", "\\\"", StringComparison.Ordinal) + "\"";
}
