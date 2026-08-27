using System.Xml.Linq;

namespace CodexDuo.Windows.Tests;

public sealed class XamlBindingTests
{
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
