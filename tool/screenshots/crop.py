"""Crops the raw renders in build/site_shots into the images site/ uses.

Coordinates are in the 2x pixels of a 1440x900 window (2880x1800).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC = Path("build/site_shots")
OUT = Path("site/public/shots")

# name: (source, box or None for the full frame, output width)
SHOTS = {
    "dashboard-dark": ("dashboard-dark", None, 2400),
    "dashboard-light": ("dashboard-light", None, 2400),
    "speed": ("dashboard-dark", (560, 335, 2120, 635), 1400),
    "torrent": ("torrent", (2170, 180, 2866, 1410), 696),
    "torrent-files": ("torrent-dialog", (862, 80, 2018, 1440), 1156),
    "media": ("media-dialog", (862, 80, 2018, 1510), 1156),
    "history": ("history", (0, 0, 2160, 1716), 1400),
    "settings": ("settings", (0, 0, 2160, 1716), 1400),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (source, box, width) in SHOTS.items():
        image = Image.open(SRC / f"{source}.png").convert("RGB")
        if box:
            image = image.crop(box)
        if image.width > width:
            height = round(image.height * width / image.width)
            image = image.resize((width, height), Image.LANCZOS)
        image.save(OUT / f"{name}.webp", "WEBP", quality=86, method=6)
        print(f"{name}.webp {image.width}x{image.height}")


# The Z mark, in the 248-unit space of site/public/logo.svg (keep in sync).
BRAND = "#00674f"


def logo(size: int, radius: float = 0) -> Image.Image:
    """Renders the logo at `size` px; `radius` rounds the square (logo units)."""
    k = size * 4 / 248  # 4x supersampling

    def p(v: float) -> float:
        return v * k

    image = Image.new("RGBA", (size * 4, size * 4), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), p(radius), BRAND)
    width = 50.5
    joints = [(77.5, 74), (171, 74), (78.5, 171)]
    for a, b in zip(joints, joints[1:]):
        draw.line([(p(a[0]), p(a[1])), (p(b[0]), p(b[1]))], "#000", round(p(width)))
    for x, y in joints:
        r = width / 2
        draw.ellipse((p(x - r), p(y - r), p(x + r), p(y + r)), "#000")
    draw.ellipse((p(169 - 25), p(169 - 25), p(169 + 25), p(169 + 25)), "#000")
    return image.resize((size, size), Image.LANCZOS)


def icons() -> None:
    logo(512, radius=56).save("site/public/favicon.png", optimize=True)
    logo(180).save("site/public/apple-touch-icon.png", optimize=True)
    print("favicon.png 512, apple-touch-icon.png 180")


def og_image() -> None:
    """1200x630 social card: headline on the left, the app bleeding off the right."""
    card = Image.new("RGB", (1200, 630), "#000")
    glow = Image.new("RGB", (1200, 630), "#000")
    ImageDraw.Draw(glow).ellipse((300, -420, 1300, 380), fill="#00422f")
    card = Image.blend(card, glow.filter(ImageFilter.GaussianBlur(120)), 1)

    shot = Image.open(SRC / "dashboard-dark.png").convert("RGB")
    shot = shot.resize((1040, 650), Image.LANCZOS)
    frame = Image.new("RGB", (1042, 652), "#2e2e2e")
    frame.paste(shot, (1, 1))
    card.paste(frame, (560, 150))

    sf = "/System/Library/Fonts/SFNS.ttf"
    draw = ImageDraw.Draw(card)
    bold = ImageFont.truetype(sf, 64)
    bold.set_variation_by_name("Bold")
    text = ImageFont.truetype(sf, 24)
    label = ImageFont.truetype(sf, 20)
    label.set_variation_by_name("Semibold")

    icon = logo(56, radius=56)
    card.paste(icon, (64, 64), icon)
    draw.text((136, 78), "Z O N", font=label, fill="#ffffff")
    draw.text((64, 190), "Every download.", font=bold, fill="#ffffff")
    draw.text((64, 262), "One quiet app.", font=bold, fill="#8a8a8a")
    draw.multiline_text(
        (64, 370),
        "HTTP, YouTube & 1000+ sites,\nand torrents — for macOS,\nWindows and Linux.",
        font=text,
        fill="#b4b4b4",
        spacing=10,
    )
    draw.text((64, 540), "zon.vercel.app", font=label, fill="#2ecf9f")
    card.save("site/public/og.png", optimize=True)
    print("og.png 1200x630")


if __name__ == "__main__":
    main()
    icons()
    og_image()
