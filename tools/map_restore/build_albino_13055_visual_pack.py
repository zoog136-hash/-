#!/usr/bin/env python3
"""Build four PRIVATE, full-resolution visual crops from the user-provided 13055.png.

This is an art-only staging tool. It does not update Godot map geometry, navigation,
save data, monster spawns or portals. Never check the generated PNGs into public Git.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "data/maps/albino_13055_assignment.json"
Image.MAX_IMAGE_PIXELS = 160_000_000


def sha256(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(part)
    return result.hexdigest()


def assignment_grid(settings: dict) -> np.ndarray:
    width, height = settings["preview_grid"]
    y, x = np.mgrid[:height, :width]
    best = np.full((height, width), np.inf, dtype=np.float64)
    labels = np.zeros((height, width), dtype=np.uint8)
    for region_id, seeds in enumerate(settings["preview_seed_points"], 1):
        for seed_x, seed_y in seeds:
            distance = (x - seed_x) ** 2 + (y - seed_y) ** 2
            selected = distance < best
            best[selected] = distance[selected]
            labels[selected] = region_id
    assert set(np.unique(labels)) == {1, 2, 3, 4}
    return labels


def build(source: Path, output: Path) -> None:
    settings = json.loads(CONFIG.read_text(encoding="utf-8"))
    expected = settings["source"]
    if not source.exists():
        raise FileNotFoundError(source)
    if source.resolve() == output.resolve() or output.resolve().is_relative_to(ROOT):
        raise ValueError("Generated map art must stay outside the public repository")
    if source.stat().st_size != expected["bytes"] or sha256(source) != expected["sha256"]:
        raise ValueError("13055.png original identity differs from the verified source")
    output.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        image.load()
        if list(image.size) != expected["pixel_size"]:
            raise ValueError("Original canvas dimensions differ")
        image = image.convert("RGBA")
        width, height = image.size
        preview_width, preview_height = settings["preview_grid"]
        zones = assignment_grid(settings)
        reports = []
        for region in settings["regions"]:
            index = region["ordinal"]
            box = tuple(region["source_rect_xyxy"])
            left, top, right, bottom = box
            assert 0 <= left < right <= width and 0 <= top < bottom <= height
            asset = output / region["private_asset_filename"]
            if asset.exists():
                raise FileExistsError(f"Refusing to overwrite derived asset: {asset}")
            xcoords = np.clip(((np.arange(left, right) + 0.5) *
                               preview_width / width).astype(np.int32), 0, preview_width - 1)
            ycoords = np.clip(((np.arange(top, bottom) + 0.5) *
                               preview_height / height).astype(np.int32), 0, preview_height - 1)
            ownership = (zones[np.ix_(ycoords, xcoords)] == index).astype(np.uint8) * 255
            cut = image.crop(box)
            alpha = np.minimum(np.asarray(cut.getchannel("A"), dtype=np.uint8), ownership)
            cut.putalpha(Image.fromarray(alpha, "L"))
            cut.save(asset, "PNG", compress_level=2)
            reports.append({
                "map_id": region["map_id"],
                "visual_theme": region["visual_theme"],
                "file": asset.name,
                "source_rect_xyxy": list(box),
                "pixel_dimensions": list(cut.size),
                "sha256": sha256(asset),
                "bytes": asset.stat().st_size,
                "region_boundary_status": "DRAFT",
                "collision_navigation_status": "NOT_VALIDATED",
                "runtime_activation": "OFF"
            })
            cut.close()
            print(f"ALBINO_CROP {region['map_id']} {asset.name}")
        preview = image.resize((preview_width, preview_height), Image.Resampling.LANCZOS).convert("RGB")
        pen = ImageDraw.Draw(preview)
        for region, marker in zip(settings["regions"], [(360, 405), (715, 425),
                                                       (1030, 303), (670, 645)]):
            px, py = marker
            pen.ellipse((px - 20, py - 20, px + 20, py + 20),
                        fill=(14, 24, 28), outline=(255, 255, 255), width=3)
            pen.text((px - 5, py - 8), str(region["ordinal"]), fill="white")
        preview.save(output / "13055_assignment_review.jpg", quality=90)
    manifest = {
        "schema": 1,
        "source_sha256": expected["sha256"],
        "source_dimensions": expected["pixel_size"],
        "generation": "PRIVATE_VISUAL_REVIEW_ONLY",
        "regions": reports,
        "conditions_before_activation": settings["pending_validation"]
    }
    (output / "13055_visual_pack_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="Private original 13055.png")
    parser.add_argument("--output", type=Path, required=True, help="Private output folder outside Git")
    args = parser.parse_args()
    build(args.source, args.output)
