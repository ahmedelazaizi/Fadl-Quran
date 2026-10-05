"""Generate the Fadl Android launcher icons and store preview."""

import math
from pathlib import Path

from PIL import Image, ImageDraw


PROJECT = Path(__file__).resolve().parents[2]
RES = PROJECT / "android" / "app" / "src" / "main" / "res"
SCALE = 8
CANVAS = 108 * SCALE
GREEN = "#013428"
GOLD = "#C7A75C"
GOLD_LIGHT = "#E6C687"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def points(vertices):
    return [(round(x * SCALE), round(y * SCALE)) for x, y in vertices]


def draw_book(canvas):
    pen = ImageDraw.Draw(canvas)
    left_page = [(54, 44), (43, 38), (27, 37), (27, 69), (42, 70), (54, 78)]
    right_page = [(54, 44), (65, 38), (81, 37), (81, 69), (66, 70), (54, 78)]
    pen.polygon(points(left_page), fill=GOLD)
    pen.polygon(points(right_page), fill=GOLD)

    # The narrower inner pages leave a bold silhouette at launcher sizes.
    pen.polygon(points([(31, 42), (42, 43), (51, 48), (51, 70), (42, 65), (31, 64)]), fill=(0, 0, 0, 0))
    pen.polygon(points([(77, 42), (66, 43), (57, 48), (57, 70), (66, 65), (77, 64)]), fill=(0, 0, 0, 0))
    pen.line(points([(54, 46), (54, 76)]), fill=GOLD_LIGHT, width=2 * SCALE)
    pen.line(points([(31, 43), (41, 44), (49, 48)]), fill=GOLD_LIGHT, width=SCALE)
    pen.line(points([(77, 43), (67, 44), (59, 48)]), fill=GOLD_LIGHT, width=SCALE)
    pen.line(points([(25, 71), (42, 73), (54, 81), (66, 73), (83, 71)]),
             fill=GOLD_LIGHT, width=2 * SCALE, joint="curve")

    star = []
    for step in range(16):
        angle = step * math.pi / 8
        radius = 6 if step % 2 == 0 else 2.6
        star.append((54 + radius * math.sin(angle), 27 - radius * math.cos(angle)))
    pen.polygon(points(star), fill=GOLD_LIGHT)


def render_foreground(size):
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw_book(canvas)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def render_legacy(size):
    background = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    ImageDraw.Draw(background).rounded_rectangle(
        (0, 0, CANVAS - 1, CANVAS - 1), radius=22 * SCALE, fill=GREEN
    )
    foreground = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw_book(foreground)
    background.alpha_composite(foreground)
    return background.resize((size, size), Image.Resampling.LANCZOS)


def main():
    for density, factor in DENSITIES.items():
        folder = RES / f"mipmap-{density}"
        render_legacy(round(48 * factor)).save(folder / "ic_launcher.png", format="PNG")
        render_foreground(round(108 * factor)).save(
            folder / "ic_launcher_foreground.png", format="PNG"
        )

    adaptive = RES / "mipmap-anydpi-v26"
    adaptive.mkdir(exist_ok=True)
    (adaptive / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n', encoding="utf-8"
    )
    (RES / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <color name="ic_launcher_background">#013428</color>\n'
        '</resources>\n', encoding="utf-8"
    )
    render_legacy(512).save(Path(__file__).with_name("icon_512.png"), format="PNG")


if __name__ == "__main__":
    main()
