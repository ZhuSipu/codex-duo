from io import BytesIO
from pathlib import Path
import struct

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Windows" / "CodexDuo.Windows" / "Resources" / "CodexDuo.png"
OUTPUT = ROOT / "Windows" / "CodexDuo.Windows" / "Resources" / "CodexDuo.Tray.ico"
# Native shell sizes from 100% through 300% scaling. In particular, Windows
# uses 28 px at 175%; omitting it makes the shell resample a neighbouring frame
# and turns a binary-white glyph grey again.
SIZES = (16, 20, 24, 28, 32, 40, 48)


def render_frame(size: int) -> Image.Image:
    # Use the application's light outline as a hollow monochrome tray glyph.
    # The dark body stays transparent so the compact mark remains airy and
    # recognizable at notification-area sizes.
    source = Image.open(SOURCE).convert("RGBA")
    pixels = source.load()
    mask = Image.new("L", source.size)
    mask_pixels = mask.load()
    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, alpha = pixels[x, y]
            luminance = (red * 54 + green * 183 + blue * 19) // 256
            lightness = max(0, min(255, (luminance - 64) * 2))
            mask_pixels[x, y] = alpha * lightness // 255

    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError("The application icon contains no light outline")

    margin = max(1, round(size * 0.08))
    available = size - 2 * margin
    outline = mask.crop(bounds)
    outline.thumbnail((available, available), Image.Resampling.LANCZOS)

    # Windows composites the alpha channel against the taskbar. Any
    # antialiased white pixel therefore becomes visibly grey. The tray asset is
    # intentionally binary: every retained mark pixel is opaque white and
    # every other pixel is fully transparent. This matches native monochrome
    # system-tray glyphs even at 16 px.
    _, maximum_alpha = outline.getextrema()
    if maximum_alpha <= 0:
        raise ValueError("The resized tray icon contains no visible outline")
    threshold = maximum_alpha * 0.16
    outline = outline.point(lambda value: 255 if value >= threshold else 0)

    frame = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    x = (size - outline.width) // 2
    y = (size - outline.height) // 2
    alpha = Image.new("L", (size, size))
    alpha.paste(outline, (x, y))
    frame.putalpha(alpha)
    return frame


def write_ico(frames: list[tuple[int, Image.Image]]) -> None:
    encoded: list[tuple[int, bytes]] = []
    for size, frame in frames:
        buffer = BytesIO()
        frame.save(buffer, format="PNG", optimize=True)
        encoded.append((size, buffer.getvalue()))

    offset = 6 + 16 * len(encoded)
    entries: list[bytes] = []
    payload: list[bytes] = []
    for size, data in encoded:
        entries.append(struct.pack("<BBBBHHII", size, size, 0, 0, 1, 32, len(data), offset))
        payload.append(data)
        offset += len(data)

    with OUTPUT.open("wb") as output:
        output.write(struct.pack("<HHH", 0, 1, len(encoded)))
        output.write(b"".join(entries))
        output.write(b"".join(payload))


def main() -> None:
    write_ico([(size, render_frame(size)) for size in SIZES])


if __name__ == "__main__":
    main()
