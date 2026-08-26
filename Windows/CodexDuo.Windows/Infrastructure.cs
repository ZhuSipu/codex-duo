using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Media;
using Microsoft.Win32;

namespace CodexDuo.Windows;

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

public static class ThemeManager
{
    public static void Apply(string mode)
    {
        var dark = mode == "dark" || mode == "system" && SystemUsesDarkTheme();
        Set("WindowBackgroundBrush", dark ? "#FF15171C" : "#FFF7F8FC");
        Set("CardBrush", dark ? "#FF22252C" : "#FFFFFFFF");
        Set("PrimaryTextBrush", dark ? "#FFF4F6FA" : "#FF111827");
        Set("SecondaryTextBrush", dark ? "#FFAAB1BE" : "#FF667085");
        Set("BorderBrush", dark ? "#33FFFFFF" : "#1A101828");
        Set("AccentBrush", dark ? "#FF59A5FF" : "#FF367AF6");
    }

    private static void Set(string key, string color) =>
        Application.Current.Resources[key] = new SolidColorBrush((Color)ColorConverter.ConvertFromString(color));

    private static bool SystemUsesDarkTheme()
    {
        using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
        return key?.GetValue("AppsUseLightTheme") is int value && value == 0;
    }
}
