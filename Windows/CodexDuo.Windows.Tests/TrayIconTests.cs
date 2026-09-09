namespace CodexDuo.Windows.Tests;

using System.Windows.Media;
using System.Windows.Media.Imaging;

public sealed class TrayIconTests
{
    [Fact]
    public void TrayIcon_ProvidesPixelOptimizedCommonSizes()
    {
        using var stream = File.OpenRead(Path.Combine(AppContext.BaseDirectory, "Fixtures", "CodexDuo.Tray.ico"));
        using var reader = new BinaryReader(stream);

        Assert.Equal(0, reader.ReadUInt16());
        Assert.Equal(1, reader.ReadUInt16());
        var count = reader.ReadUInt16();
        var sizes = new HashSet<int>();
        for (var index = 0; index < count; index++)
        {
            var width = reader.ReadByte();
            var height = reader.ReadByte();
            reader.ReadBytes(4);
            Assert.Equal(32, reader.ReadUInt16());
            reader.ReadBytes(8);
            Assert.Equal(width, height);
            sizes.Add(width == 0 ? 256 : width);
        }

        int[] expectedSizes = [16, 20, 24, 28, 32, 40, 48];
        Assert.True(expectedSizes.All(sizes.Contains));
    }

    [Fact]
    public void TrayIcon_IsPureWhiteOnTransparentBackground()
    {
        using var stream = File.OpenRead(Path.Combine(AppContext.BaseDirectory, "Fixtures", "CodexDuo.Tray.ico"));
        var decoder = BitmapDecoder.Create(stream, BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad);
        foreach (var frame in decoder.Frames)
        {
            var bitmap = new FormatConvertedBitmap(frame, PixelFormats.Bgra32, null, 0);
            var pixels = new byte[bitmap.PixelWidth * bitmap.PixelHeight * 4];
            bitmap.CopyPixels(pixels, bitmap.PixelWidth * 4, 0);

            var visiblePixels = 0;
            for (var offset = 0; offset < pixels.Length; offset += 4)
            {
                var alpha = pixels[offset + 3];
                if (alpha == 0)
                {
                    continue;
                }

                visiblePixels++;
                Assert.Equal(255, alpha);
                Assert.Equal(255, pixels[offset]);
                Assert.Equal(255, pixels[offset + 1]);
                Assert.Equal(255, pixels[offset + 2]);
            }

            Assert.True(visiblePixels > 0);
        }
    }

    [Fact]
    public void TrayIcon_UsesNativeIconWithoutWpfBitmapConversion()
    {
        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "App.xaml.cs"));

        Assert.Contains("Icon = trayDrawingIcon", source, StringComparison.Ordinal);
        Assert.DoesNotContain("IconSource =", source, StringComparison.Ordinal);
        Assert.Contains("GetSystemMetrics(SmallIconWidth)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void TrayIcon_DoesNotProvideARightClickMenu()
    {
        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "App.xaml.cs"));

        Assert.DoesNotContain("ContextMenu =", source, StringComparison.Ordinal);
        Assert.DoesNotContain("BuildContextMenu", source, StringComparison.Ordinal);
    }
}
