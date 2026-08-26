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

        Assert.Equal(6, usageBindings.Length);
        Assert.All(usageBindings, binding => Assert.Contains("Mode=OneWay", binding, StringComparison.Ordinal));
    }
}
