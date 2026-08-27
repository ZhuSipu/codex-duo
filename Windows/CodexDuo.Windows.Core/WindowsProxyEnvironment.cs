using Microsoft.Win32;
using System.Globalization;
using System.Security;

namespace CodexDuo.Windows.Core;

public static class WindowsProxyEnvironment
{
    private const string InternetSettingsPath = @"Software\Microsoft\Windows\CurrentVersion\Internet Settings";

    public static void ApplyTo(IDictionary<string, string?> environment)
    {
        ArgumentNullException.ThrowIfNull(environment);
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(InternetSettingsPath, false);
            if (key is null) return;
            ApplySettings(
                new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase)
                {
                    ["ProxyEnable"] = key.GetValue("ProxyEnable"),
                    ["ProxyServer"] = key.GetValue("ProxyServer"),
                    ["ProxyOverride"] = key.GetValue("ProxyOverride"),
                },
                environment);
        }
        catch (Exception error) when (error is IOException or SecurityException or UnauthorizedAccessException)
        {
            // System proxy import is best-effort; explicit process variables still work.
        }
    }

    public static void ApplySettings(
        IReadOnlyDictionary<string, object?> settings,
        IDictionary<string, string?> environment)
    {
        ArgumentNullException.ThrowIfNull(settings);
        ArgumentNullException.ThrowIfNull(environment);
        if (!IsEnabled(settings.GetValueOrDefault("ProxyEnable"))) return;
        if (settings.GetValueOrDefault("ProxyServer") is not string proxyServer
            || string.IsNullOrWhiteSpace(proxyServer)) return;

        var entries = proxyServer.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var protocolEntries = entries
            .Select(entry => entry.Split('=', 2, StringSplitOptions.TrimEntries))
            .Where(parts => parts.Length == 2 && parts[0].Length > 0 && parts[1].Length > 0)
            .ToArray();

        if (protocolEntries.Length == 0)
        {
            var proxy = NormalizeProxy(proxyServer, "http");
            SetIfMissing(environment, "HTTP_PROXY", proxy);
            SetIfMissing(environment, "HTTPS_PROXY", proxy);
        }
        else
        {
            foreach (var parts in protocolEntries)
            {
                switch (parts[0].ToLowerInvariant())
                {
                    case "http":
                        SetIfMissing(environment, "HTTP_PROXY", NormalizeProxy(parts[1], "http"));
                        break;
                    case "https":
                        SetIfMissing(environment, "HTTPS_PROXY", NormalizeProxy(parts[1], "http"));
                        break;
                    case "socks":
                    case "socks5":
                        SetIfMissing(environment, "ALL_PROXY", NormalizeProxy(parts[1], "socks5h"));
                        break;
                }
            }
        }

        if (settings.GetValueOrDefault("ProxyOverride") is string proxyOverride)
        {
            var noProxy = NormalizeBypassList(proxyOverride);
            if (noProxy.Length > 0) SetIfMissing(environment, "NO_PROXY", noProxy);
        }
    }

    private static bool IsEnabled(object? value)
    {
        if (value is null) return false;
        try
        {
            return Convert.ToInt32(value, CultureInfo.InvariantCulture) != 0;
        }
        catch (Exception error) when (error is FormatException or InvalidCastException or OverflowException)
        {
            return false;
        }
    }

    private static string NormalizeProxy(string value, string defaultScheme)
    {
        var trimmed = value.Trim();
        return trimmed.Contains("://", StringComparison.Ordinal)
            ? trimmed
            : $"{defaultScheme}://{trimmed}";
    }

    private static string NormalizeBypassList(string value)
    {
        var result = new List<string>();
        foreach (var entry in value.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (entry.Equals("<local>", StringComparison.OrdinalIgnoreCase))
            {
                AddUnique(result, "localhost");
                AddUnique(result, "127.0.0.1");
                AddUnique(result, "::1");
                continue;
            }
            if (entry.StartsWith('<') && entry.EndsWith('>')) continue;
            AddUnique(result, entry.StartsWith("*.", StringComparison.Ordinal) ? entry[1..] : entry);
        }
        return string.Join(',', result);
    }

    private static void AddUnique(List<string> values, string value)
    {
        if (!values.Contains(value, StringComparer.OrdinalIgnoreCase)) values.Add(value);
    }

    private static void SetIfMissing(IDictionary<string, string?> environment, string name, string value)
    {
        if (environment.Any(item => item.Key.Equals(name, StringComparison.OrdinalIgnoreCase)
            && !string.IsNullOrWhiteSpace(item.Value))) return;
        environment[name] = value;
    }
}
