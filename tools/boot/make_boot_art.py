#!/usr/bin/env python3
"""Draws TWILIGHT's own boot splash, loading backdrop and launcher icons.

Original artwork drawn from code (no client or third-party images), so the
files can ship in the public APK before any private resource pack exists.

    python3 tools/boot/make_boot_art.py            # writes assets/boot/*.png
"""
from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "assets/fonts/NotoSansKR.ttf"
GOLD_TOP = (255, 236, 176)
GOLD_BOTTOM = (214, 158, 74)


def font(size: int, weight: bytes = b"Bold") -> ImageFont.FreeTypeFont:
    value = ImageFont.truetype(str(FONT), size)
    value.set_variation_by_name(weight)
    return value


def sky(width: int, height: int) -> Image.Image:
    stops = [(0.0, (6, 9, 22)), (0.45, (24, 18, 48)), (0.72, (68, 30, 52)), (0.86, (122, 58, 40)), (1.0, (40, 20, 24))]
    image = Image.new("RGB", (width, height))
    pixels = image.load()
    for y in range(height):
        t = y / (height - 1)
        for index in range(len(stops) - 1):
            a, b = stops[index], stops[index + 1]
            if a[0] <= t <= b[0]:
                k = (t - a[0]) / (b[0] - a[0])
                color = tuple(round(a[1][c] + (b[1][c] - a[1][c]) * k) for c in range(3))
                break
        for x in range(width):
            pixels[x, y] = color
    return image.convert("RGBA")


def stars(image: Image.Image, count: int, limit: float, seed: int) -> None:
    rng = random.Random(seed)
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    width, height = image.size
    for _ in range(count):
        x, y = rng.uniform(0, width), rng.uniform(0, height * limit) ** 1.0
        y = (y / (height * limit)) ** 1.6 * height * limit
        r = rng.choice([0.6, 0.8, 1.0, 1.0, 1.4, 1.8])
        alpha = rng.randint(70, 230)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 246, 225, alpha))
    image.alpha_composite(layer)


def moon(image: Image.Image, center: tuple[float, float], radius: float) -> None:
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((center[0] - radius * 3, center[1] - radius * 3, center[0] + radius * 3, center[1] + radius * 3), fill=(255, 214, 150, 60))
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius * 1.2)))
    disc = Image.new("L", image.size, 0)
    ImageDraw.Draw(disc).ellipse((center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius), fill=255)
    bite = Image.new("L", image.size, 0)
    offset = radius * 0.42
    ImageDraw.Draw(bite).ellipse((center[0] - radius + offset, center[1] - radius - offset * 0.55, center[0] + radius + offset, center[1] + radius - offset * 0.55), fill=255)
    mask = Image.composite(Image.new("L", image.size, 0), disc, bite).filter(ImageFilter.GaussianBlur(0.8))
    image.alpha_composite(Image.composite(Image.new("RGBA", image.size, (250, 230, 182, 255)), Image.new("RGBA", image.size, (0, 0, 0, 0)), mask))


def ridge(image: Image.Image, base: float, amplitude: float, color: tuple, seed: int, step: int = 6) -> list[tuple[float, float]]:
    rng = random.Random(seed)
    width, height = image.size
    phases = [rng.uniform(0, math.tau) for _ in range(4)]
    points = []
    for x in range(-step, width + step * 2, step):
        y = base
        for index, phase in enumerate(phases):
            y -= amplitude / (index + 1.4) * math.sin(x / (width / (1.3 + index * 1.9)) + phase)
        points.append((x, y))
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(points + [(width + step * 2, height), (-step, height)], fill=color)
    image.alpha_composite(layer)
    return points


def castle(image: Image.Image, left: float, ground: float, scale: float, color: tuple) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    s = scale
    draw.rectangle((left, ground - 70 * s, left + 230 * s, ground + 40), fill=color)
    for index in range(12):
        x = left + index * 20 * s
        draw.rectangle((x, ground - 80 * s, x + 10 * s, ground - 70 * s), fill=color)
    for x, w, h in [(-18, 44, 150), (95, 50, 205), (205, 44, 160)]:
        tx = left + x * s
        draw.rectangle((tx, ground - h * s, tx + w * s, ground + 40), fill=color)
        draw.polygon([(tx - 6 * s, ground - h * s), (tx + w * s / 2, ground - (h + 62) * s), (tx + w * s + 6 * s, ground - h * s)], fill=color)
    lights = Image.new("RGBA", image.size, (0, 0, 0, 0))
    lit = ImageDraw.Draw(lights)
    for x, y in [(110, 150), (130, 120), (8, 108), (220, 112), (60, 40), (170, 44)]:
        lit.rectangle((left + x * s, ground - y * s, left + (x + 6) * s, ground - (y - 11) * s), fill=(255, 190, 110, 230))
    image.alpha_composite(layer)
    image.alpha_composite(lights.filter(ImageFilter.GaussianBlur(1.2)))
    image.alpha_composite(lights)


def gold_text(image: Image.Image, text: str, center: tuple[float, float], face: ImageFont.FreeTypeFont, spacing: int = 0) -> None:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).text(center, text, font=face, anchor="mm", fill=255, spacing=spacing)
    box = mask.getbbox()
    if box is None:
        return
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow.putalpha(mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(6)).point(lambda v: v * 0.85))
    image.alpha_composite(shadow)
    outline = Image.new("RGBA", image.size, (52, 26, 10, 255))
    image.alpha_composite(Image.composite(outline, Image.new("RGBA", image.size, (0, 0, 0, 0)), mask.filter(ImageFilter.MaxFilter(5))))
    fill = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pixels = fill.load()
    top, bottom = box[1], max(box[3] - 1, box[1] + 1)
    for y in range(box[1], box[3]):
        k = (y - top) / (bottom - top)
        color = tuple(round(GOLD_TOP[c] + (GOLD_BOTTOM[c] - GOLD_TOP[c]) * k) for c in range(3)) + (255,)
        for x in range(box[0], box[2]):
            pixels[x, y] = color
    image.alpha_composite(Image.composite(fill, Image.new("RGBA", image.size, (0, 0, 0, 0)), mask))


def backdrop(width: int = 1280, height: int = 720, title: bool = True) -> Image.Image:
    image = sky(width, height)
    stars(image, 260, 0.62, 7)
    moon(image, (width * 0.79, height * 0.2), height * 0.075)
    mist = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(mist).ellipse((-width * 0.2, height * 0.62, width * 1.2, height * 1.05), fill=(170, 80, 60, 70))
    image.alpha_composite(mist.filter(ImageFilter.GaussianBlur(60)))
    ridge(image, height * 0.74, height * 0.06, (44, 28, 52, 255), 3)
    points = ridge(image, height * 0.83, height * 0.045, (20, 13, 26, 255), 11)
    ground = min(y for x, y in points if width * 0.12 <= x <= width * 0.3)
    castle(image, width * 0.13, ground + 6, height / 720 * 0.95, (14, 9, 20, 255))
    ridge(image, height * 0.93, height * 0.02, (9, 6, 13, 255), 19)
    if title:
        gold_text(image, "황혼의 기사", (width / 2, height * 0.36), font(round(height * 0.15), b"Black"))
        sub = Image.new("RGBA", image.size, (0, 0, 0, 0))
        ImageDraw.Draw(sub).text((width / 2, height * 0.49), "T  W  I  L  I  G  H  T", font=font(round(height * 0.04), b"SemiBold"), anchor="mm", fill=(236, 214, 160, 225))
        image.alpha_composite(sub)
    return image.convert("RGB")


def icon(size: int, background: bool = True) -> Image.Image:
    scale = 4
    big = size * scale
    image = sky(big, big) if background else Image.new("RGBA", (big, big), (0, 0, 0, 0))
    if background: stars(image, 40, 0.6, 5)
    moon(image, (big * 0.5, big * 0.42), big * 0.25)
    blade = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(blade)
    cx = big * 0.5
    draw.polygon([(cx, big * 0.16), (cx + big * 0.038, big * 0.26), (cx + big * 0.03, big * 0.7), (cx - big * 0.03, big * 0.7), (cx - big * 0.038, big * 0.26)], fill=(238, 240, 248, 255))
    draw.line([(cx, big * 0.22), (cx, big * 0.68)], fill=(170, 176, 196, 255), width=max(2, big // 160))
    draw.rounded_rectangle((cx - big * 0.17, big * 0.69, cx + big * 0.17, big * 0.74), radius=big * 0.02, fill=GOLD_BOTTOM + (255,))
    draw.rectangle((cx - big * 0.026, big * 0.74, cx + big * 0.026, big * 0.86), fill=(92, 52, 28, 255))
    draw.ellipse((cx - big * 0.045, big * 0.85, cx + big * 0.045, big * 0.94), fill=GOLD_TOP + (255,))
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow.putalpha(blade.getchannel("A").filter(ImageFilter.GaussianBlur(big // 60)).point(lambda v: v * 0.8))
    image.alpha_composite(shadow)
    image.alpha_composite(blade)
    return image.resize((size, size), Image.LANCZOS).convert("RGBA")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default=str(ROOT / "assets/boot"))
    out = Path(parser.parse_args().output)
    out.mkdir(parents=True, exist_ok=True)
    backdrop().save(out / "twilight_loading.png", optimize=True)
    icon(512).save(out / "twilight_icon.png", optimize=True)
    icon(192).save(out / "twilight_icon_192.png", optimize=True)
    foreground = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    foreground.alpha_composite(icon(288, False), (72, 72))
    foreground.save(out / "twilight_icon_foreground.png", optimize=True)
    icon(432).save(out / "twilight_icon_background.png", optimize=True)


if __name__ == "__main__":
    main()
