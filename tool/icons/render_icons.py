"""Renders every ZON icon from the brand mark in site/public/logo.svg.

The mark is a round-capped "Z" stroke plus a dot on a #00674f field, drawn
here from the same geometry (248-unit canvas) so all sizes stay crisp.

    python3 tool/icons/render_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

GREEN = (0, 103, 79, 255)
BLACK = (0, 0, 0, 255)

# Geometry of site/public/logo.svg, in its 248x248 viewBox.
UNIT = 248
STROKE = [(77.5, 74), (171, 74), (78.5, 171)]
STROKE_WIDTH = 50.5
DOT = (169, 169, 25)

SUPERSAMPLE = 4


def draw_mark(size, color=BLACK, inset=0.0):
    """The Z + dot on a transparent square; [inset] shrinks it inward."""
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    scale = big * (1 - 2 * inset) / UNIT
    offset = big * inset

    def point(x, y):
        return (offset + x * scale, offset + y * scale)

    width = STROKE_WIDTH * scale
    points = [point(x, y) for x, y in STROKE]
    draw.line(points, fill=color, width=round(width), joint="curve")
    for x, y in points:  # round caps and join
        r = width / 2
        draw.ellipse((x - r, y - r, x + r, y + r), fill=color)
    cx, cy = point(DOT[0], DOT[1])
    r = DOT[2] * scale
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)
    return image.resize((size, size), Image.LANCZOS)


def tile(size, radius=0.0):
    """Green square (optionally rounded) with the mark, full bleed."""
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(image).rounded_rectangle(
        (0, 0, big - 1, big - 1), radius=radius * big, fill=GREEN
    )
    image = image.resize((size, size), Image.LANCZOS)
    image.alpha_composite(draw_mark(size))
    return image


def mac_icon(size):
    """macOS Big Sur grid: 824/1024 rounded square, centred, soft shadow."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    body = round(size * 824 / 1024)
    margin = (size - body) // 2
    if size >= 64:
        shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            (margin, margin + size * 0.012, margin + body, margin + body),
            radius=body * 0.225,
            fill=(0, 0, 0, 90),
        )
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size * 0.012)))
    canvas.alpha_composite(tile(body, radius=0.225), (margin, margin))
    return canvas


def main():
    root = Path(__file__).resolve().parents[2]

    # In-app logo (ZonLogo rounds the corners itself).
    tile(1024).convert("RGB").save(root / "assets/brand/zon_icon.png")

    # macOS app icon.
    iconset = root / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        mac_icon(size).save(iconset / f"app_icon_{size}.png")

    # Windows: rounded tile, every size Explorer asks for.
    sizes = [16, 24, 32, 48, 64, 128, 256]
    tile(256, radius=0.2).save(
        root / "windows/runner/resources/app_icon.ico",
        sizes=[(s, s) for s in sizes],
    )

    # Tray: macOS template (black mark, the system tints it), and a
    # colored tile for Windows/Linux trays.
    tray = root / "assets/tray"
    draw_mark(44, inset=0.06).save(tray / "tray_icon.png")
    draw_mark(88, inset=0.06).save(tray / "tray_icon@2x.png")
    tile(64, radius=0.22).save(tray / "tray_icon_color.png")


if __name__ == "__main__":
    main()
