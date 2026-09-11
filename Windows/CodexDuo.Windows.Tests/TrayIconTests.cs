namespace CodexDuo.Windows.Tests;

using System.Windows.Media;
using System.Windows.Media.Imaging;

public sealed class TrayIconTests
{
    [Fact]
    public void TrayIcon_ProvidesPixelOptimizedCommonSizes()
    {
        using var stream = File.OpenRead(Path.Combine(AppContext.BaseDirectory, "Fixtures", "CodexDuo.Tray.Dark.ico"));
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

    [Theory]
    [InlineData("CodexDuo.Tray.Dark.ico", 255)]
    [InlineData("CodexDuo.Tray.Light.ico", 0)]
    public void TrayIcons_UseContrastingMonochromeArtwork(string fileName, byte channel)
    {
        using var stream = File.OpenRead(Path.Combine(AppContext.BaseDirectory, "Fixtures", fileName));
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
                Assert.Equal(channel, pixels[offset]);
                Assert.Equal(channel, pixels[offset + 1]);
                Assert.Equal(channel, pixels[offset + 2]);
            }

            Assert.True(visiblePixels > 0);
        }
    }

    [Fact]
    public void TrayIcons_ShareTheSameGeometryAcrossThemes()
    {
        static IReadOnlyList<(int Width, int Height, byte[] Alpha)> ReadAlpha(string fileName)
        {
            using var stream = File.OpenRead(Path.Combine(AppContext.BaseDirectory, "Fixtures", fileName));
            var decoder = BitmapDecoder.Create(stream, BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad);
            return decoder.Frames.Select(frame =>
            {
                var bitmap = new FormatConvertedBitmap(frame, PixelFormats.Bgra32, null, 0);
                var pixels = new byte[bitmap.PixelWidth * bitmap.PixelHeight * 4];
                bitmap.CopyPixels(pixels, bitmap.PixelWidth * 4, 0);
                var alpha = new byte[bitmap.PixelWidth * bitmap.PixelHeight];
                for (var index = 0; index < alpha.Length; index++) alpha[index] = pixels[index * 4 + 3];
                return (bitmap.PixelWidth, bitmap.PixelHeight, alpha);
            }).ToArray();
        }

        var dark = ReadAlpha("CodexDuo.Tray.Dark.ico");
        var light = ReadAlpha("CodexDuo.Tray.Light.ico");
        Assert.Equal(dark.Count, light.Count);
        for (var index = 0; index < dark.Count; index++)
        {
            Assert.Equal(dark[index].Width, light[index].Width);
            Assert.Equal(dark[index].Height, light[index].Height);
            Assert.Equal(dark[index].Alpha, light[index].Alpha);
        }
    }

    [Fact]
    public void TrayIcon_UsesNativeIconWithoutWpfBitmapConversion()
    {
        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "App.xaml.cs"));

        Assert.Contains("trayIcon.Icon = drawingIcon", source, StringComparison.Ordinal);
        Assert.DoesNotContain("IconSource =", source, StringComparison.Ordinal);
        Assert.Contains("GetSystemMetrics(SmallIconWidth)", source, StringComparison.Ordinal);
        Assert.Contains("SystemTaskbarUsesDarkTheme()", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SystemThemeChangesRefreshWindowsAndTrayIcon()
    {
        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "App.xaml.cs"));
        var infrastructure = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "Infrastructure.cs"));

        Assert.Contains("SystemEvents.UserPreferenceChanged += SystemEvents_UserPreferenceChanged", source, StringComparison.Ordinal);
        Assert.Contains("viewModel?.Settings.Appearance == \"system\"", source, StringComparison.Ordinal);
        Assert.Contains("ApplyCurrentWindowTheme()", source, StringComparison.Ordinal);
        Assert.Contains("AppsUseLightTheme", infrastructure, StringComparison.Ordinal);
        Assert.Contains("SystemUsesLightTheme", infrastructure, StringComparison.Ordinal);
    }

    [Fact]
    public void TrayIcon_DoesNotProvideARightClickMenu()
    {
        var source = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "App.xaml.cs"));

        Assert.DoesNotContain("ContextMenu =", source, StringComparison.Ordinal);
        Assert.DoesNotContain("BuildContextMenu", source, StringComparison.Ordinal);
    }
}
