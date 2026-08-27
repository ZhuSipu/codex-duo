namespace CodexDuo.Windows.Core;

public static class DiagnosticLog
{
    private static readonly object Gate = new();
    private static readonly string LogPath = System.IO.Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Codex Duo",
        "codex-duo.log");

    public static string Path => LogPath;

    public static void Write(string eventName, string? detail = null)
    {
        try
        {
            var safeEvent = Sanitize(eventName, 120);
            var safeDetail = Sanitize(detail, 500);
            var line = $"{DateTimeOffset.Now:O}\t{safeEvent}";
            if (safeDetail.Length > 0) line += $"\t{safeDetail}";

            lock (Gate)
            {
                Directory.CreateDirectory(System.IO.Path.GetDirectoryName(LogPath)!);
                File.AppendAllText(LogPath, line + Environment.NewLine);
            }
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            // Diagnostics must never affect application behavior.
        }
    }

    private static string Sanitize(string? value, int maximumLength)
    {
        if (string.IsNullOrWhiteSpace(value)) return string.Empty;
        var normalized = value.Replace('\r', ' ').Replace('\n', ' ').Replace('\t', ' ').Trim();
        return normalized.Length <= maximumLength ? normalized : normalized[..maximumLength];
    }
}
