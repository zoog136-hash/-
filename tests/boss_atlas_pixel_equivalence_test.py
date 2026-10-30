#!/usr/bin/env python3
"""Compare every runtime frame and its metadata with the reviewed source."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

from PIL import Image

BASE = "5983f19748e09d7bade8cc2076d8f90537c8c89c"
FILES = (
    Path("assets/actors/eight_direction/monster_boss_repair/albino_unicorn/published-v02/SpriteFrames.tres"),
    Path("assets/actors/eight_direction/monster_boss_repair/zombie_lord/published-v01/SpriteFrames.tres"),
)
BLOCK = re.compile(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', re.S)
EXT = re.compile(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]')


def records(text: str) -> dict[str, tuple[Path, tuple[int, int, int, int], str]]:
    paths = {ident: Path(path.removeprefix("res://")) for path, ident in EXT.findall(text)}
    result = {}
    for ident, body in BLOCK.findall(text):
        ref = re.search(r'atlas = ExtResource\("([^"]+)"\)', body)
        region = re.search(r'region = Rect2\(([^)]*)\)', body)
        assert ref and region, ident
        box = tuple(int(float(value.strip())) for value in region.group(1).split(","))
        unchanged = re.sub(r'atlas = ExtResource\("[^"]+"\)', "atlas = IMAGE", body)
        unchanged = re.sub(r'region = Rect2\([^)]*\)', "region = RECT", unchanged)
        result[ident] = paths[ref.group(1)], box, unchanged
    return result


def animations(text: str) -> str:
    return text[text.index("[resource]"):]


def verify(path: Path) -> tuple[int, int, int]:
    before = subprocess.check_output(["git", "show", f"{BASE}:{path}"], text=True)
    after = path.read_text()
    old, new = records(before), records(after)
    assert old.keys() == new.keys(), f"{path}: frame IDs changed"
    assert animations(before) == animations(after), f"{path}: animations or frame timing changed"
    opened: dict[Path, Image.Image] = {}
    try:
        for ident in old:
            original, (ox, oy, w, h), old_meta = old[ident]
            repacked, (nx, ny, nw, nh), new_meta = new[ident]
            assert (w, h) == (nw, nh), f"{path}: size {ident}"
            assert old_meta == new_meta, f"{path}: margin/filter {ident}"
            for image_path in (original, repacked):
                if image_path not in opened:
                    opened[image_path] = Image.open(image_path)
            old_pixels = opened[original].crop((ox, oy, ox + w, oy + h)).convert("RGBA").tobytes()
            new_pixels = opened[repacked].crop((nx, ny, nx + w, ny + h)).convert("RGBA").tobytes()
            assert old_pixels == new_pixels, f"{path}: pixels {ident}"
        old_bytes = sum(image.width * image.height * 4 for image_path, image in opened.items()
                        if "runtime-atlas" not in str(image_path))
        new_bytes = sum(image.width * image.height * 4 for image_path, image in opened.items()
                        if "runtime-atlas" in str(image_path))
        return len(old), old_bytes, new_bytes
    finally:
        for image in opened.values():
            image.close()


if __name__ == "__main__":
    for sprite in FILES:
        frames, old_bytes, new_bytes = verify(sprite)
        print(f"ATLAS_PIXEL_OK {sprite.parent.parent.name}: {frames} frames, "
              f"{old_bytes / 1048576:.1f} -> {new_bytes / 1048576:.1f} MiB decoded RGBA8 pages")
