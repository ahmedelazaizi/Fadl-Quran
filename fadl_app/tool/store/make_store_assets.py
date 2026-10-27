"""Generate the Google Play store graphics in docs/store-assets/.

    python3 tool/store/make_store_assets.py

- icon-512.png: the 512×512 store icon (from tool/icon/make_icon.py).
- feature-graphic.png: the 1024×500 feature graphic, 24-bit PNG without
  transparency as Google Play requires.
Needs Pillow built with libraqm for Arabic shaping.
"""

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, features

PROJECT = Path(__file__).resolve().parents[2]
FONTS = PROJECT / "assets" / "fonts"
OUT = PROJECT / "docs" / "store-assets"
ICON = PROJECT / "tool" / "icon" / "icon_512.png"

GREEN = (1, 52, 40)
EMERALD = (30, 75, 62)
GOLD = (199, 167, 92)
GOLD_LIGHT = (230, 198, 135)
WHITE = (241, 252, 247)
W, H = 1024, 500


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size, layout_engine=ImageFont.Layout.RAQM)


def feature_graphic():
    image = Image.new("RGB", (W, H), GREEN)
    # Soft light behind the icon.
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((60, 30, 500, 470), fill=150)
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    image.paste(Image.new("RGB", (W, H), EMERALD), mask=glow)

    pen = ImageDraw.Draw(image)
    # Thin gold frame.
    pen.rounded_rectangle((18, 18, W - 18, H - 18), radius=28, outline=GOLD, width=2)

    icon = Image.open(ICON).convert("RGBA").resize((300, 300), Image.LANCZOS)
    image.paste(icon, (130, 100), icon)

    right = W - 90
    # Positions are baselines, so each line clears the descenders above it.
    lines = [
        ("فضل", font("Amiri-Bold.ttf", 130), GOLD_LIGHT, 200),
        ("قرآن • أذان • أذكار", font("Tajawal-Bold.ttf", 46), WHITE, 320),
        ("صدقة جارية • مجاني بلا إعلانات", font("Tajawal-Medium.ttf", 32), GOLD, 385),
    ]
    for text, face, color, baseline in lines:
        pen.text((right, baseline), text, font=face, fill=color, anchor="rs", direction="rtl")
    return image


def main():
    if not features.check("raqm"):
        raise SystemExit("Pillow needs libraqm to shape Arabic text")
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ICON, OUT / "icon-512.png")
    feature_graphic().save(OUT / "feature-graphic.png", optimize=True)
    for name in ("icon-512.png", "feature-graphic.png"):
        with Image.open(OUT / name) as im:
            print(f"{name}: {im.size[0]}x{im.size[1]} {im.mode}")


if __name__ == "__main__":
    main()
