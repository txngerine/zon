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
    "speed": ("dashboard-dark", (548, 345, 2131, 624), 1400),
    "torrent": ("torrent", (2200, 0, 2880, 1665), 680),
    "media": ("media-dialog", (862, 80, 2018, 1510), 1156),
    "history": ("history", (480, 0, 2200, 1700), 1400),
    "settings": ("settings", (480, 0, 2200, 1700), 1400),
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


def og_image() -> None:
    """1200x630 social card: headline on the left, the app bleeding off the right."""
    card = Image.new("RGB", (1200, 630), "#000")
    glow = Image.new("RGB", (1200, 630), "#000")
    ImageDraw.Draw(glow).ellipse((300, -420, 1300, 380), fill="#0f3a28")
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

    icon = Image.open("assets/brand/zon_icon.png").convert("RGBA").resize((56, 56))
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
    draw.text((64, 540), "zon.vercel.app", font=label, fill="#3ddc97")
    card.save("site/public/og.png", optimize=True)
    print("og.png 1200x630")


if __name__ == "__main__":
    main()
    og_image()
