#!/usr/bin/env python3
"""Generate the deterministic RJ ZeitZentrale app-icon PNG set."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "App" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"

SIZES = {
    "Icon-1024.png": 1024,
    "Icon-20@1x-ipad.png": 20,
    "Icon-20@2x-ipad.png": 40,
    "Icon-20@2x.png": 40,
    "Icon-20@3x.png": 60,
    "Icon-29@1x-ipad.png": 29,
    "Icon-29@2x-ipad.png": 58,
    "Icon-29@2x.png": 58,
    "Icon-29@3x.png": 87,
    "Icon-40@1x-ipad.png": 40,
    "Icon-40@2x-ipad.png": 80,
    "Icon-40@2x.png": 80,
    "Icon-40@3x.png": 120,
    "Icon-60@2x.png": 120,
    "Icon-60@3x.png": 180,
    "Icon-76@1x.png": 76,
    "Icon-76@2x.png": 152,
    "Icon-83.5@2x.png": 167,
}


def mix(a, b, t):
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def glow(base, center, radius, color, strength):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    px = layer.load()
    cx, cy = center
    for y in range(max(0, cy - radius), min(base.height, cy + radius)):
        for x in range(max(0, cx - radius), min(base.width, cx + radius)):
            d = math.hypot(x - cx, y - cy) / radius
            if d < 1:
                alpha = int((1 - d) ** 2 * strength)
                px[x, y] = (*color, alpha)
    return Image.alpha_composite(base, layer)


def make_master():
    size = 2048
    image = Image.new("RGBA", (size, size), (4, 13, 35, 255))
    pixels = image.load()
    top = (4, 24, 58)
    bottom = (44, 14, 83)
    for y in range(size):
        for x in range(size):
            vertical = y / (size - 1)
            diagonal = (x + y) / (2 * size)
            color = mix(top, bottom, min(1, vertical * 0.82 + diagonal * 0.18))
            vignette = min(0.34, math.hypot(x - size / 2, y - size / 2) / size * 0.3)
            pixels[x, y] = tuple(max(0, round(c * (1 - vignette))) for c in color) + (255,)

    image = glow(image, (410, 350), 790, (0, 225, 255), 180)
    image = glow(image, (1640, 1640), 880, (184, 55, 255), 155)
    image = glow(image, (1550, 470), 520, (33, 102, 255), 95)

    glass_shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ds = ImageDraw.Draw(glass_shadow)
    ds.rounded_rectangle((380, 375, 1668, 1663), radius=330, fill=(0, 0, 0, 150))
    glass_shadow = glass_shadow.filter(ImageFilter.GaussianBlur(70))
    image = Image.alpha_composite(image, glass_shadow)

    glass = Image.new("RGBA", image.size, (0, 0, 0, 0))
    dg = ImageDraw.Draw(glass)
    card = (350, 345, 1698, 1693)
    dg.rounded_rectangle(card, radius=350, fill=(218, 244, 255, 37), outline=(255, 255, 255, 92), width=10)
    dg.arc((390, 385, 1658, 1653), 200, 338, fill=(105, 236, 255, 115), width=12)
    dg.arc((390, 385, 1658, 1653), 20, 158, fill=(230, 119, 255, 85), width=10)
    image = Image.alpha_composite(image, glass)

    ring = Image.new("RGBA", image.size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(ring)
    circle = (570, 565, 1478, 1473)
    dr.ellipse(circle, fill=(7, 20, 52, 118), outline=(226, 251, 255, 175), width=18)
    dr.ellipse((610, 605, 1438, 1433), outline=(73, 218, 255, 120), width=5)

    cx, cy = 1024, 1019
    for minute in range(60):
        angle = math.radians(minute * 6 - 90)
        major = minute % 5 == 0
        outer = 420
        inner = 374 if major else 394
        x1, y1 = cx + math.cos(angle) * inner, cy + math.sin(angle) * inner
        x2, y2 = cx + math.cos(angle) * outer, cy + math.sin(angle) * outer
        color = (232, 253, 255, 210 if major else 92)
        dr.line((x1, y1, x2, y2), fill=color, width=10 if major else 4)

    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    font = ImageFont.truetype(font_path, 350)
    text = "RJ"
    bbox = dr.textbbox((0, 0), text, font=font, stroke_width=2)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx, ty = cx - tw / 2, cy - th / 2 - 35
    dr.text((tx + 14, ty + 20), text, font=font, fill=(0, 0, 0, 100))
    dr.text((tx, ty), text, font=font, fill=(239, 252, 255, 245), stroke_width=2, stroke_fill=(129, 234, 255, 210))

    def hand(angle_deg, length, width, color):
        angle = math.radians(angle_deg - 90)
        end = (cx + math.cos(angle) * length, cy + math.sin(angle) * length)
        dr.line((cx, cy, *end), fill=color, width=width)
        dr.ellipse((end[0] - width / 2, end[1] - width / 2, end[0] + width / 2, end[1] + width / 2), fill=color)

    hand(308, 270, 24, (82, 231, 255, 245))
    hand(52, 335, 15, (255, 108, 210, 245))
    dr.ellipse((985, 980, 1063, 1058), fill=(252, 255, 255, 255), outline=(60, 221, 255, 255), width=12)
    image = Image.alpha_composite(image, ring)

    badge = Image.new("RGBA", image.size, (0, 0, 0, 0))
    db = ImageDraw.Draw(badge)
    db.ellipse((1390, 340, 1710, 660), fill=(255, 72, 116, 245), outline=(255, 255, 255, 205), width=12)
    db.line((1472, 507, 1530, 565, 1640, 438), fill=(255, 255, 255, 255), width=28, joint="curve")
    badge = badge.filter(ImageFilter.GaussianBlur(0.15))
    image = Image.alpha_composite(image, badge)

    return image.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)


def main():
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    master = make_master()
    for filename, size in SIZES.items():
        icon = master if size == 1024 else master.resize((size, size), Image.Resampling.LANCZOS)
        icon.save(ICON_DIR / filename, "PNG", optimize=True)
    print(f"Generated {len(SIZES)} RGB PNG icons in {ICON_DIR}")


if __name__ == "__main__":
    main()
