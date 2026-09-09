using System.Globalization;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Markup;
using System.Windows.Media;
using CodexDuo.Windows.Core;
using Microsoft.Win32;

namespace CodexDuo.Windows;

public static class TypographyManager
{
    public static void Apply(string language)
    {
        var (fontFamily, languageTag) = Localizer.ResolveLanguage(language) switch
        {
            "zh-Hans" => ("Microsoft YaHei UI", "zh-CN"),
            "zh-Hant" => ("Microsoft JhengHei UI", "zh-TW"),
            "ja" => ("Yu Gothic UI", "ja-JP"),
            "ko" => ("Malgun Gothic", "ko-KR"),
            "es" => ("Segoe UI Variable Text, Segoe UI", "es-ES"),
            "fr" => ("Segoe UI Variable Text, Segoe UI", "fr-FR"),
            "de" => ("Segoe UI Variable Text, Segoe UI", "de-DE"),
            _ => ("Segoe UI Variable Text, Segoe UI", "en-US"),
        };

        var resources = Application.Current?.Resources;
        if (resources is null) return;
        resources["InterfaceFontFamily"] = new FontFamily(fontFamily);
        resources["InterfaceLanguage"] = XmlLanguage.GetLanguage(languageTag);
    }
}

public sealed class AsyncCommand(Func<Task> execute, Func<bool>? canExecute = null) : ICommand
{
    private bool running;
    public event EventHandler? CanExecuteChanged;
    public bool CanExecute(object? parameter) => !running && (canExecute?.Invoke() ?? true);
    public async void Execute(object? parameter)
    {
        if (!CanExecute(parameter)) return;
        running = true;
        CanExecuteChanged?.Invoke(this, EventArgs.Empty);
        try { await execute(); }
        finally { running = false; CanExecuteChanged?.Invoke(this, EventArgs.Empty); }
    }
    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}

public sealed class RelayCommand(Action execute, Func<bool>? canExecute = null) : ICommand
{
    public event EventHandler? CanExecuteChanged;
    public bool CanExecute(object? parameter) => canExecute?.Invoke() ?? true;
    public void Execute(object? parameter) => execute();
    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}

public sealed class BooleanToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is true ? Visibility.Visible : Visibility.Collapsed;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}

public sealed class StringToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        string.IsNullOrWhiteSpace(value as string) ? Visibility.Collapsed : Visibility.Visible;
    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) => Binding.DoNothing;
}

public sealed class AccountCountToScrollBarVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is int count && count > 3 ? ScrollBarVisibility.Auto : ScrollBarVisibility.Disabled;
    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => Binding.DoNothing;
}

public static class ThemeManager
{
    private const int UseImmersiveDarkMode = 20;
    private const int UseImmersiveDarkModeBefore20H1 = 19;
    private const int WindowCornerPreference = 33;
    private const int RoundWindowCorners = 2;

    public static void Apply(string mode)
    {
        var dark = mode == "dark" || mode == "system" && SystemUsesDarkTheme();
        Set("WindowBackgroundBrush", dark ? "#FF17181A" : "#FFF3F4F6");
        Set("PanelBrush", dark ? "#F21F2023" : "#F7F7F7F9");
        Set("CardBrush", dark ? "#D9252629" : "#E6FFFFFF");
        Set("ElevatedBrush", dark ? "#F235363A" : "#F7FFFFFF");
        Set("InsetBrush", dark ? "#14FFFFFF" : "#09000000");
        Set("BadgeBrush", dark ? "#0FFFFFFF" : "#08000000");
        Set("PrimaryTextBrush", dark ? "#F2FFFFFF" : "#E8000000");
        Set("SecondaryTextBrush", dark ? "#A8FFFFFF" : "#92000000");
        Set("TertiaryTextBrush", dark ? "#72FFFFFF" : "#65000000");
        Set("QuaternaryTextBrush", dark ? "#45FFFFFF" : "#40000000");
        Set("BorderBrush", dark ? "#16FFFFFF" : "#14000000");
        Set("StrongBorderBrush", dark ? "#36FFFFFF" : "#22000000");
        Set("HoverBrush", dark ? "#12FFFFFF" : "#0D000000");
        Set("PressedBrush", dark ? "#20FFFFFF" : "#17000000");
        Set("TrackBrush", dark ? "#18FFFFFF" : "#10000000");
        Set("MeterBrush", dark ? "#62FFFFFF" : "#4D000000");
        Set("LowMeterBrush", dark ? "#99FFFFFF" : "#78000000");
        Set("ActiveMarkerBrush", dark ? "#D1FFFFFF" : "#B8000000");
        Set("DangerTextBrush", dark ? "#FFFF7770" : "#FFC43A3A");
        Set("WarningTextBrush", dark ? "#FFFFC35C" : "#FF8A6200");
        Set("AccentBrush", dark ? "#FF0A84FF" : "#FF007AFF");
        Set("AccentTextBrush", "#FFFFFFFF");
    }

    private static void Set(string key, string color) =>
        Application.Current.Resources[key] = new SolidColorBrush((Color)ColorConverter.ConvertFromString(color));

    public static void ApplyWindowTheme(Window window, string mode)
    {
        var dark = mode == "dark" || mode == "system" && SystemUsesDarkTheme();
        var enabled = dark ? 1 : 0;
        var handle = new WindowInteropHelper(window).Handle;
        if (handle == IntPtr.Zero) return;
        if (DwmSetWindowAttribute(handle, UseImmersiveDarkMode, ref enabled, sizeof(int)) != 0)
        {
            _ = DwmSetWindowAttribute(handle, UseImmersiveDarkModeBefore20H1, ref enabled, sizeof(int));
        }
        var corners = RoundWindowCorners;
        _ = DwmSetWindowAttribute(handle, WindowCornerPreference, ref corners, sizeof(int));
    }

    private static bool SystemUsesDarkTheme()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        return key?.GetValue("AppsUseLightTheme") is int value && value == 0;
    }

    [DllImport("dwmapi.dll")]
    [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
    private static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int valueSize);
}
