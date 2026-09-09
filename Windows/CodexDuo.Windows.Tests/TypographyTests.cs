using System.Xml.Linq;

namespace CodexDuo.Windows.Tests;

public sealed class TypographyTests
{
    private static readonly string[] StyledControls = ["TextBlock", "Window", "Button", "ComboBox", "CheckBox"];
    private static readonly string[] SettingsCheckboxes = ["StartupCheck"];

    [Fact]
    public void InterfaceTypography_UsesLanguageSpecificFontsAndLanguageTags()
    {
        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "Infrastructure.cs"));

        Assert.Contains("\"zh-Hans\" => (\"Microsoft YaHei UI\", \"zh-CN\")", source, StringComparison.Ordinal);
        Assert.Contains("\"zh-Hant\" => (\"Microsoft JhengHei UI\", \"zh-TW\")", source, StringComparison.Ordinal);
        Assert.Contains("resources[\"InterfaceFontFamily\"]", source, StringComparison.Ordinal);
        Assert.Contains("resources[\"InterfaceLanguage\"]", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SharedStyles_UseDynamicInterfaceTypography()
    {
        var document = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "App.xaml"));
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";
        var styles = document.Descendants(presentation + "Style");

        foreach (var targetType in StyledControls)
        {
            var style = Assert.Single(styles, element => (string?)element.Attribute("TargetType") == targetType);
            Assert.Contains(style.Elements(presentation + "Setter"), setter =>
                (string?)setter.Attribute("Property") == "FontFamily"
                && (string?)setter.Attribute("Value") == "{DynamicResource InterfaceFontFamily}");
        }

        var windowStyle = Assert.Single(styles, element => (string?)element.Attribute("TargetType") == "Window");
        Assert.Contains(windowStyle.Elements(presentation + "Setter"), setter =>
            (string?)setter.Attribute("Property") == "Language"
            && (string?)setter.Attribute("Value") == "{DynamicResource InterfaceLanguage}");
    }

    [Fact]
    public void SettingsCheckboxes_AlignWithTheControlColumn()
    {
        var document = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "SettingsWindow.xaml"));
        XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";
        XNamespace x = "http://schemas.microsoft.com/winfx/2006/xaml";

        foreach (var name in SettingsCheckboxes)
        {
            var checkbox = Assert.Single(document.Descendants(presentation + "CheckBox"), element =>
                (string?)element.Attribute(x + "Name") == name);
            Assert.Equal("1", (string?)checkbox.Attribute("Grid.Column"));
            Assert.Equal("Right", (string?)checkbox.Attribute("HorizontalAlignment"));
            var label = Assert.Single(checkbox.Elements(presentation + "TextBlock"));
            Assert.Equal("Wrap", (string?)label.Attribute("TextWrapping"));
        }
    }
}
