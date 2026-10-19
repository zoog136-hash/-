#!/usr/bin/env python3
"""Build a private name-matched SPX skill effect pack from a2002.zip.

Accepts either the whole original archive or its numbered .part001.. files.
Only the source IDs in data/skills/external_spx_name_bindings.json are decoded.
The source archive is data, not executable code. This converter never updates
TWILIGHT skill damage, duration, learned state, or cooldowns.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import pathlib
import re
import shutil
import tempfile
import zipfile

import numpy as np
from PIL import Image

from spx_decode import decode_spx

ROOT = pathlib.Path(__file__).resolve().parents[2]
BINDINGS = ROOT / "data/skills/external_spx_name_bindings.json"
OUTPUT_PREFIX = "assets/external_spx/skills"
MAX_FRAME_PIXELS = 3_000_000
MAX_CANVAS_EDGE = 2048


@contextlib.contextmanager
def open_outer(source: pathlib.Path):
    """Open single-archive or split original without modifying any input."""
    if source.is_dir():
        parts = sorted(source.glob("a2002.zip.part*"))
    elif re.search(r"\.part\d+$", source.name):
        stem = source.name.rsplit(".part", 1)[0]
        parts = sorted(source.parent.glob(stem + ".part*"))
    else:
        parts = []
    if not parts:
        with zipfile.ZipFile(source) as archive:
            yield archive
        return
    numbers = [int(p.name.rsplit(".part", 1)[1]) for p in parts]
    if numbers != list(range(1, len(parts) + 1)):
        raise ValueError("a2002.zip parts are missing or out of sequence")
    with tempfile.SpooledTemporaryFile(max_size=16 * 1024 * 1024) as combined:
        for part in parts:
            with part.open("rb") as stream:
                shutil.copyfileobj(stream, combined)
        combined.seek(0)
        with zipfile.ZipFile(combined) as archive:
            yield archive


def nested_patch(outer: zipfile.ZipFile) -> zipfile.ZipFile:
    matches = [path for path in outer.namelist()
               if path.replace("\\", "/").lower().endswith("/patch_1.zip")]
    if len(matches) != 1:
        raise ValueError("expected connector/patch/patch_1.zip in the supplied archive")
    return zipfile.ZipFile(io.BytesIO(outer.read(matches[0])))


def member_for(archive: zipfile.ZipFile, source_id: int) -> str:
    pattern = re.compile(r"(?:^|/)" + str(source_id) + r"-0\.spx$", re.I)
    matches = [path for path in archive.namelist()
               if pattern.search(path.replace("\\", "/"))]
    if len(matches) != 1:
        raise ValueError(f"missing or ambiguous source ID {source_id}: {matches}")
    return matches[0]


def phase_frames(decoded: list[list[tuple[dict, Image.Image | None]]]) -> list[Image.Image]:
    """Composite SC/MU light layers in a stable source-offset canvas."""
    located = [(meta, picture)
               for layer in decoded for meta, picture in layer if picture is not None]
    if not located:
        raise ValueError("no image-bearing SPX frames in this phase")
    x1 = min(int(meta["xy_offset"][0]) for meta, image in located)
    y1 = min(int(meta["xy_offset"][1]) for meta, image in located)
    x2 = max(int(meta["xy_offset"][0]) + image.width for meta, image in located)
    y2 = max(int(meta["xy_offset"][1]) + image.height for meta, image in located)
    width, height = x2 - x1, y2 - y1
    if (width <= 0 or height <= 0 or
            width > MAX_CANVAS_EDGE or height > MAX_CANVAS_EDGE or
            width * height > MAX_FRAME_PIXELS):
        raise ValueError(f"effect canvas out of bounds: {width}x{height}")
    output = []
    for frame_index in range(max(map(len, decoded))):
        canvas = np.zeros((height, width, 4), dtype=np.uint8)
        for layer in decoded:
            if frame_index >= len(layer):
                continue
            meta, image = layer[frame_index]
            if image is None:
                continue
            ox, oy = map(int, meta["xy_offset"])
            x, y = ox - x1, oy - y1
            source = np.asarray(image.convert("RGBA"), dtype=np.uint8)
            section = canvas[y:y + image.height, x:x + image.width]
            rgb = section[:, :, :3].astype(np.uint16)
            incoming = source[:, :, :3].astype(np.uint16)
            opaque = (source[:, :, 3:4].astype(np.uint16) > 0)
            section[:, :, :3] = np.minimum(255, rgb + incoming * opaque).astype(np.uint8)
            section[:, :, 3] = np.maximum(section[:, :, 3], source[:, :, 3])
        output.append(Image.fromarray(canvas, "RGBA"))
    return output


def spriteframes_resource(mapping: dict[str, list[str]]) -> str:
    paths = [path for frames in mapping.values() for path in frames]
    ext = [
        f'[ext_resource type="Texture2D" path="res://{path}" id="{i}"]'
        for i, path in enumerate(paths, 1)
    ]
    ids = {path: i for i, path in enumerate(paths, 1)}
    animations = []
    for clip, frames in mapping.items():
        definitions = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("' + str(ids[path]) + '")}'
            for path in frames
        )
        animations.append(
            '{"frames": [' + definitions +
            '], "loop": false, "name": &"' + clip + '", "speed": 14.0}'
        )
    return (
        '[gd_resource type="SpriteFrames" load_steps=' + str(len(paths) + 2) +
        ' format=3]\n\n' + '\n'.join(ext) +
        '\n\n[resource]\nanimations = [\n' + ',\n'.join(animations) + '\n]\n'
    )


def build(source: pathlib.Path, output: pathlib.Path) -> dict:
    config = json.loads(BINDINGS.read_text(encoding="utf-8"))
    manifest = {
        "schema": 1, "type": "name_match_visual_only",
        "source": "a2002.zip/connector/patch/patch_1.zip",
        "third_party_private": True,
        "bindings": config["bindings"], "families": {},
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with open_outer(source) as outer:
        with nested_patch(outer) as patch:
            bad = patch.testzip()
            if bad is not None:
                raise ValueError(f"source patch CRC failure: {bad}")
            cache: dict[int, list] = {}
            with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as pack:
                for family, spec in config["families"].items():
                    mapping: dict[str, list[str]] = {}
                    physical: dict[str, dict] = {}
                    for clip, ids in spec["source_by_animation"].items():
                        layers = []
                        for source_id in ids:
                            if source_id not in cache:
                                member = member_for(patch, int(source_id))
                                blob = patch.read(member)
                                frames = decode_spx(
                                    blob, max_pixels_per_frame=MAX_FRAME_PIXELS,
                                    max_frames=64,
                                )
                                cache[source_id] = frames
                                physical[str(source_id)] = {
                                    "member": member,
                                    "sha256": hashlib.sha256(blob).hexdigest(),
                                    "frames": len(frames),
                                }
                            layers.append(cache[source_id])
                        pictures = phase_frames(layers)
                        mapping[clip] = []
                        for index, picture in enumerate(pictures):
                            relative = (f"{OUTPUT_PREFIX}/{family}/{clip}/"
                                        f"frame_{index:03d}.png")
                            with io.BytesIO() as stream:
                                picture.save(stream, format="PNG", optimize=True)
                                pack.writestr(relative, stream.getvalue())
                            mapping[clip].append(relative)
                    resource = f"{OUTPUT_PREFIX}/{family}/SpriteFrames.tres"
                    pack.writestr(resource, spriteframes_resource(mapping))
                    manifest["families"][family] = {
                        "animations": {clip: len(frames) for clip, frames in mapping.items()},
                        "sources": physical,
                        "resource": resource,
                    }
                pack.writestr(
                    "data/external_spx/skills_manifest.json",
                    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                )
                pack.writestr(
                    "PRIVATE_SPX_SKILL_README.txt",
                    "Extract assets/ and data/ into the TWILIGHT project root. "
                    "Open Godot once to import PNGs. Do not upload the source "
                    "frames to public GitHub without redistribution permission.\n",
                )
    with zipfile.ZipFile(output) as verify:
        bad = verify.testzip()
        if bad is not None:
            raise ValueError(f"generated pack failed ZIP CRC: {bad}")
    return {
        "output": str(output), "bytes": output.stat().st_size,
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "families": manifest["families"],
    }


def install(output: pathlib.Path, project: pathlib.Path) -> int:
    if not (project / "project.godot").is_file():
        raise ValueError(f"not a TWILIGHT Godot project: {project}")
    written = 0
    with zipfile.ZipFile(output) as pack:
        for member in pack.namelist():
            if not (member.startswith(OUTPUT_PREFIX + "/") or
                    member == "data/external_spx/skills_manifest.json" or
                    member == "PRIVATE_SPX_SKILL_README.txt"):
                raise ValueError(f"unexpected archive member: {member}")
            target = project / member
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(pack.read(member))
            written += 1
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=pathlib.Path, required=True,
                        help="a2002.zip, a2002.zip.part001, or containing folder")
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--install-root", type=pathlib.Path,
                        help="optional local Godot root; installs the generated pack privately")
    args = parser.parse_args()
    result = build(args.source, args.output)
    if args.install_root is not None:
        result["installed_files"] = install(args.output, args.install_root)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
