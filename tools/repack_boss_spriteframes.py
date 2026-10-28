#!/usr/bin/env python3
"""Repack the exact referenced boss pixels; original PNGs stay untouched.

The source SpriteFrames resources are read from the reviewed main commit so
this remains reproducible after the runtime .tres files point at packed pages.
Requires Pillow. Run from the repository root.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

from PIL import Image

BASE = "5983f19748e09d7bade8cc2076d8f90537c8c89c"
SPRITES = (
    Path("assets/actors/eight_direction/monster_boss_repair/albino_unicorn/published-v02/SpriteFrames.tres"),
    Path("assets/actors/eight_direction/monster_boss_repair/zombie_lord/published-v01/SpriteFrames.tres"),
)
PAGE = 2048
PAD = 2
BLOCK = re.compile(r'(\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n.*?)(?=\n\[|\Z)', re.S)
EXT = re.compile(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]\n\n')


def rects(source: str) -> tuple[dict[str, Path], list[dict]]:
    files = {ident: Path(path.removeprefix("res://")) for path, ident in EXT.findall(source)}
    items = []
    for block, ident in BLOCK.findall(source):
        atlas = re.search(r'atlas = ExtResource\("([^"]+)"\)', block)
        region = re.search(r'region = Rect2\(([^)]*)\)', block)
        if not atlas or not region:
            raise ValueError(f"Unrecognized AtlasTexture {ident}")
        x, y, w, h = (int(float(part.strip())) for part in region.group(1).split(","))
        items.append(dict(ident=ident, source=files[atlas.group(1)], rect=(x, y, w, h),
                          width=w + PAD * 2, height=h + PAD * 2))
    return files, items


def pack(items: list[dict]) -> list[tuple[int, int, int]]:
    """Unrotated best short-side fit with free-rectangle splitting."""
    pages: list[list[tuple[int, int, int, int]]] = []
    positions: dict[str, tuple[int, int, int]] = {}
    for item in sorted(items, key=lambda v: (-v["width"] * v["height"], v["ident"])):
        w, h = item["width"], item["height"]
        if w > PAGE or h > PAGE:
            raise ValueError(f"Frame exceeds {PAGE}: {item['ident']}")
        best = None
        for page, free in enumerate(pages):
            for x, y, fw, fh in free:
                if w <= fw and h <= fh:
                    score = (min(fw - w, fh - h), fw * fh - w * h, page, y, x)
                    if best is None or score < best[0]:
                        best = (score, page, x, y)
        if best is None:
            pages.append([(0, 0, PAGE, PAGE)])
            best = ((0, 0, len(pages) - 1, 0, 0), len(pages) - 1, 0, 0)
        _, page, x, y = best
        positions[item["ident"]] = (page, x, y)
        free = []
        for fx, fy, fw, fh in pages[page]:
            if x >= fx + fw or x + w <= fx or y >= fy + fh or y + h <= fy:
                free.append((fx, fy, fw, fh))
                continue
            if x > fx:
                free.append((fx, fy, x - fx, fh))
            if x + w < fx + fw:
                free.append((x + w, fy, fx + fw - x - w, fh))
            if y > fy:
                free.append((fx, fy, fw, y - fy))
            if y + h < fy + fh:
                free.append((fx, y + h, fw, fy + fh - y - h))
        pages[page] = [a for a in free if not any(
            a != b and a[0] >= b[0] and a[1] >= b[1] and
            a[0] + a[2] <= b[0] + b[2] and a[1] + a[3] <= b[1] + b[3]
            for b in free)]
    return [positions[item["ident"]] for item in items]


def extruded(source: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    x, y, w, h = box
    tile = source.crop((x, y, x + w, y + h)).convert("RGBA")
    out = Image.new("RGBA", (w + 2 * PAD, h + 2 * PAD))
    out.paste(tile, (PAD, PAD))
    out.paste(tile.crop((0, 0, w, 1)).resize((w, PAD)), (PAD, 0))
    out.paste(tile.crop((0, h - 1, w, h)).resize((w, PAD)), (PAD, h + PAD))
    out.paste(tile.crop((0, 0, 1, h)).resize((PAD, h)), (0, PAD))
    out.paste(tile.crop((w - 1, 0, w, h)).resize((PAD, h)), (w + PAD, PAD))
    for sx, sy, dx, dy in ((0, 0, 0, 0), (w - 1, 0, w + PAD, 0),
                           (0, h - 1, 0, h + PAD), (w - 1, h - 1, w + PAD, h + PAD)):
        out.paste(tile.getpixel((sx, sy)), (dx, dy, dx + PAD, dy + PAD))
    return out


def build(path: Path) -> None:
    source = subprocess.check_output(["git", "show", f"{BASE}:{path}"], text=True)
    _, items = rects(source)
    positions = pack(items)
    page_count = max(page for page, _, _ in positions) + 1
    pages = [Image.new("RGBA", (PAGE, PAGE)) for _ in range(page_count)]
    bounds = [[0, 0] for _ in pages]
    opened: dict[Path, Image.Image] = {}
    try:
        for item, (page, x, y) in zip(items, positions):
            file = item["source"]
            if file not in opened:
                opened[file] = Image.open(file)
            pages[page].paste(extruded(opened[file], item["rect"]), (x, y))
            bounds[page][0] = max(bounds[page][0], x + item["width"])
            bounds[page][1] = max(bounds[page][1], y + item["height"])
    finally:
        for image in opened.values():
            image.close()
    directory = path.parent / "runtime-atlas"
    directory.mkdir(exist_ok=True)
    for page, image in enumerate(pages):
        w, h = ((value + 3) // 4 * 4 for value in bounds[page])
        image.crop((0, 0, w, h)).save(directory / f"page-{page:02d}.png")

    records = dict(zip((item["ident"] for item in items), zip(items, positions)))

    def replace_block(match: re.Match[str]) -> str:
        block, ident = match.groups()
        item, (page, x, y) = records[ident]
        _, _, w, h = item["rect"]
        block = re.sub(r'atlas = ExtResource\("[^"]+"\)', f'atlas = ExtResource("runtime_{page}")', block)
        block = re.sub(r'region = Rect2\([^)]*\)', f'region = Rect2({x + PAD}, {y + PAD}, {w}, {h})', block)
        return block

    result = EXT.sub("", source)
    result = BLOCK.sub(replace_block, result)
    result = re.sub(r"load_steps=\d+", f"load_steps={page_count + len(items) + 1}", result, count=1)
    prefix = "".join(
        f'[ext_resource type="Texture2D" path="res://{directory}/page-{page:02d}.png" id="runtime_{page}"]\n\n'
        for page in range(page_count)
    )
    result = result.replace("\n\n", "\n\n" + prefix, 1)
    path.write_text(result)
    print(f"{path}: {len(items)} frames, {page_count} pages, "
          f"{sum(w * h * 4 for w, h in bounds) / 1048576:.1f} MiB RGBA8 used rectangles")


if __name__ == "__main__":
    for sprite in SPRITES:
        build(sprite)
