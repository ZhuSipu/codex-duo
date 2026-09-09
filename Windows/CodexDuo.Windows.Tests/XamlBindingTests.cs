using System.Xml.Linq;

namespace CodexDuo.Windows.Tests;

public sealed class XamlBindingTests
{
    [Fact]
    public void TextRendering_IsPixelAlignedAndTrayWindowIsOpaque()
    {
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";
        var tray = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "TrayWindow.xaml"));
        var trayWindow = Assert.Single(tray.Elements(presentation + "Window"));

        Assert.Equal("False", (string?)trayWindow.Attribute("AllowsTransparency"));
        Assert.Equal("True", (string?)trayWindow.Attribute("UseLayoutRounding"));
        Assert.Equal("True", (string?)trayWindow.Attribute("SnapsToDevicePixels"));
        Assert.Equal("ClearType", (string?)trayWindow.Attribute("TextOptions.TextRenderingMode"));
        Assert.DoesNotContain("ScaleTransform", tray.ToString(), StringComparison.Ordinal);

        var app = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "App.xaml"));
        var textStyle = Assert.Single(app.Descendants(presentation + "Style"), element =>
            (string?)element.Attribute("TargetType") == "TextBlock");
        var setters = textStyle.Elements(presentation + "Setter")
            .ToDictionary(element => (string)element.Attribute("Property")!, element => (string)element.Attribute("Value")!);

        Assert.Equal("True", setters["SnapsToDevicePixels"]);
        Assert.Equal("Display", setters["TextOptions.TextFormattingMode"]);
        Assert.Equal("ClearType", setters["TextOptions.TextRenderingMode"]);
        Assert.Equal("Fixed", setters["TextOptions.TextHintingMode"]);
    }

    [Fact]
    public void TrayToggle_GuardsWindowShowAgainstReentrancy()
    {
        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "TrayWindow.xaml.cs"));
        var guard = source.IndexOf("if (isToggling)", StringComparison.Ordinal);
        var enter = source.IndexOf("isToggling = true", guard, StringComparison.Ordinal);
        var show = source.IndexOf("Show();", enter, StringComparison.Ordinal);
        var cleanup = source.IndexOf("finally", show, StringComparison.Ordinal);
        var exit = source.IndexOf("isToggling = false", cleanup, StringComparison.Ordinal);

        Assert.True(guard >= 0, "The tray toggle must reject a reentrant call.");
        Assert.True(enter > guard && show > enter, "The guard must be entered before Window.Show().");
        Assert.True(cleanup > show && exit > cleanup, "The guard must be released in a finally block.");
    }

    [Fact]
    public void Startup_AlwaysDetachesBeforeCreatingTheTrayApplication()
    {
        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "App.xaml.cs"));
        var detachedCheck = source.IndexOf("DetachedStartup.IsDetachedLaunch", StringComparison.Ordinal);
        var relaunch = source.IndexOf("DetachedStartup.TryRelaunchIndependent", detachedCheck, StringComparison.Ordinal);
        var mutex = source.IndexOf("new Mutex", relaunch, StringComparison.Ordinal);

        Assert.True(detachedCheck >= 0 && relaunch > detachedCheck,
            "Every ordinary launch must be moved outside the Codex process lifetime.");
        Assert.True(mutex > relaunch,
            "Detachment must happen before the long-lived tray instance and its mutex are created.");
        Assert.Contains("Environment.ProcessId, e.Args, out detachError", source, StringComparison.Ordinal);
        Assert.DoesNotContain("else if (CodexAppController.IsCurrentProcessDescendantOfCodex())", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SettingsWindow_ProvidesTrayVisibilityGuide()
    {
        var document = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "SettingsWindow.xaml"));
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";
        XNamespace x = "http://schemas.microsoft.com/winfx/2006/xaml";

        var button = Assert.Single(document.Descendants(presentation + "Button"), element =>
            (string?)element.Attribute(x + "Name") == "OpenTaskbarSettingsButton");
        Assert.Equal("OpenTaskbarSettings_Click", (string?)button.Attribute("Click"));
        var expander = Assert.Single(document.Descendants(presentation + "Expander"), element =>
            (string?)element.Attribute(x + "Name") == "TrayGuideExpander");
        Assert.Equal("False", (string?)expander.Attribute("IsExpanded"));
        Assert.Contains(button.Ancestors(presentation + "Expander"), element => element == expander);
        Assert.Contains(document.Descendants(presentation + "TextBlock"), element =>
            (string?)element.Attribute(x + "Name") == "TrayGuideSteps"
            && (string?)element.Attribute("TextWrapping") == "Wrap");

        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "SettingsWindow.xaml.cs"));
        Assert.Contains("ms-settings:taskbar", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SettingsWindow_UsesACompactSingleColumnProductSurface()
    {
        var document = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "SettingsWindow.xaml"));
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";
        XNamespace x = "http://schemas.microsoft.com/winfx/2006/xaml";

        var surface = Assert.Single(document.Descendants(presentation + "Border"), element =>
            (string?)element.Attribute(x + "Name") == "SettingsSurface");
        Assert.Equal("{StaticResource Surface}", (string?)surface.Attribute("Style"));

        var window = Assert.Single(document.Elements(presentation + "Window"));
        Assert.Equal("560", (string?)window.Attribute("Width"));
        Assert.Single(surface.Elements(presentation + "ScrollViewer"));
        Assert.Empty(surface.Elements(presentation + "Grid"));

        var accountList = Assert.Single(document.Descendants(presentation + "ListBox"), element =>
            (string?)element.Attribute(x + "Name") == "AccountList");
        Assert.Equal("112", (string?)accountList.Attribute("MaxHeight"));

        string[] alignedControls = ["LanguageBox", "AppearanceControl", "IntervalBox", "StartupCheck"];
        foreach (var name in alignedControls)
        {
            var element = Assert.Single(document.Descendants(), candidate =>
                (string?)candidate.Attribute(x + "Name") == name);
            Assert.Equal("1", (string?)element.Attribute("Grid.Column"));
            Assert.Equal("Right", (string?)element.Attribute("HorizontalAlignment"));
        }

        var startup = Assert.Single(document.Descendants(presentation + "CheckBox"), element =>
            (string?)element.Attribute(x + "Name") == "StartupCheck");
        Assert.Equal("Right", (string?)startup.Attribute("HorizontalAlignment"));
    }

    [Fact]
    public void SettingsWindow_ActionButtonsPairIconsWithLabels()
    {
        var document = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "SettingsWindow.xaml"));
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";
        XNamespace x = "http://schemas.microsoft.com/winfx/2006/xaml";

        string[] actionButtons =
        [
            "OpenTaskbarSettingsButton", "AddButton", "RenameButton", "RemoveButton", "InstallButton", "RefreshButton",
        ];
        foreach (var name in actionButtons)
        {
            var button = Assert.Single(document.Descendants(presentation + "Button"), element =>
                (string?)element.Attribute(x + "Name") == name);
            var content = Assert.Single(button.Elements(presentation + "StackPanel"));
            Assert.Equal("Horizontal", (string?)content.Attribute("Orientation"));
            Assert.True(content.Elements(presentation + "TextBlock").Count() >= 2,
                $"{name} should contain both a Fluent icon and a label.");
        }
    }

    [Fact]
    public void ReadOnlyUsageValuesAreBoundOneWay()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Fixtures", "TrayWindow.xaml");
        var document = XDocument.Load(path);
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";

        var progressBindings = document
            .Descendants(presentation + "ProgressBar")
            .Select(element => (string?)element.Attribute("Value"))
            .OfType<string>();
        var runBindings = document
            .Descendants(presentation + "Run")
            .Select(element => (string?)element.Attribute("Text"))
            .OfType<string>()
            .Where(value => value.StartsWith("{Binding", StringComparison.Ordinal));
        var usageBindings = progressBindings
            .Concat(runBindings)
            .ToArray();

        Assert.Single(usageBindings);
        Assert.All(usageBindings, binding => Assert.Contains("Mode=OneWay", binding, StringComparison.Ordinal));
    }
    [Fact]
    public void TrayWindow_ShowsOperationErrors()
    {
        var document = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "TrayWindow.xaml"));
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";

        Assert.Contains(document.Descendants(presentation + "TextBlock"), element =>
            (string?)element.Attribute("Text") == "{Binding Error}");
    }

    [Fact]
    public void TrayWindow_ShowsOperationWarnings()
    {
        var document = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "TrayWindow.xaml"));
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";

        Assert.Contains(document.Descendants(presentation + "TextBlock"), element =>
            (string?)element.Attribute("Text") == "{Binding Warning}");
    }

    [Fact]
    public void QuotaWindowsUseAdaptiveSideBySideColumns()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Fixtures", "TrayWindow.xaml");
        var document = XDocument.Load(path);
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";

        var meterPanel = Assert.Single(
            document.Descendants(presentation + "UniformGrid"),
            element => (string?)element.Attribute("Rows") == "1");

        Assert.Contains("UsageColumnCount", document.ToString(), StringComparison.Ordinal);
        Assert.Contains("Tag", (string?)meterPanel.Attribute("Columns"), StringComparison.Ordinal);
    }
}
