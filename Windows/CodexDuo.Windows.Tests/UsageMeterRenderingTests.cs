namespace CodexDuo.Windows.Tests;

using System.Runtime.ExceptionServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Markup;
using System.Xml.Linq;
using CodexDuo.Windows.Core;

public sealed class UsageMeterRenderingTests
{
    private static readonly double[] Widths = [120, 240];
    private static readonly int[] RemainingValues = [54, 0, 100, 23];

    [Fact]
    public void MeterFillTracksBoundQuotaAndAvailableWidth()
    {
        Exception? failure = null;
        var thread = new Thread(() =>
        {
            try
            {
                var document = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "Fixtures", "TrayWindow.xaml"));
                XNamespace presentation = "http://schemas.microsoft.com/winfx/2006/xaml/presentation";
                XNamespace x = "http://schemas.microsoft.com/winfx/2006/xaml";
                var styleElement = document.Descendants(presentation + "Style")
                    .Single(element => (string?)element.Attribute(x + "Key") == "MeterStyle");
                styleElement = new XElement(styleElement);
                styleElement.SetAttributeValue(XNamespace.Xmlns + "x", x.NamespaceName);
                var meter = new ProgressBar { Style = (Style)XamlReader.Parse(styleElement.ToString()) };
                meter.SetBinding(ProgressBar.ValueProperty, new Binding("Remaining") { Mode = BindingMode.OneWay });

                foreach (var width in Widths)
                {
                    foreach (var remaining in RemainingValues)
                    {
                        meter.DataContext = new UsageMeterPresentation("5H", remaining, null);
                        meter.Width = width;
                        meter.Measure(new Size(width, 3));
                        meter.Arrange(new Rect(0, 0, width, 3));
                        meter.UpdateLayout();

                        Assert.Equal((double)remaining, meter.Value);
                        var indicator = Assert.IsAssignableFrom<FrameworkElement>(
                            meter.Template.FindName("PART_Indicator", meter));
                        Assert.Equal(width * remaining / 100, indicator.ActualWidth, precision: 5);
                        Assert.Equal(3d, indicator.ActualHeight);
                    }
                }
            }
            catch (Exception exception)
            {
                failure = exception;
            }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        Assert.True(thread.Join(TimeSpan.FromSeconds(30)), "WPF layout test timed out.");
        if (failure is not null) ExceptionDispatchInfo.Capture(failure).Throw();
    }
}
