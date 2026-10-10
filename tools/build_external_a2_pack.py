#!/usr/bin/env python3
"""Build a private Godot visual pack from user-supplied a2(1).zip and a3.zip.

Requires Pillow, NumPy and SciPy. Only approved image paths and sanitized
item/NPC ID -> graphic ID metadata enter the resulting ZIP. Never export
third-party SQL, binaries, passwords, user data, or executables.
"""
import argparse
import collections
import csv
import io
import json
import re
import zipfile
from pathlib import Path, PurePosixPath

SQL_MEMBER = "db/l1remaster.sql"
TABLES = ("weapon", "armor", "etcitem", "npc")

def rows(sql, table):
    schema = re.search(r"CREATE TABLE \x60" + table + r"\x60\s*\((.*?)\) ENGINE", sql, re.S)
    if not schema:
        return
    columns = re.findall(r"^  \x60([^\x60]+)\x60", schema.group(1), re.M)
    id_pos = columns.index("npcid" if table == "npc" else "item_id")
    name_pos = columns.index("desc_kr")
    icon_pos = columns.index("spriteId" if table == "npc" else "iconId")
    patt = re.compile(r"^INSERT INTO \x60" + table + r"\x60 VALUES \((.*)\);?$", re.M)
    for match in patt.finditer(sql):
        try:
            values = next(csv.reader([match.group(1)], delimiter=",", quotechar="'", escapechar="\\", skipinitialspace=True))
            if len(values) <= max(id_pos, name_pos, icon_pos):
                continue
            name = " ".join(re.sub(r"\\a[A-Za-z0-9]", "", values[name_pos]).split())
            graphic_id, source_id = values[icon_pos].strip(), values[id_pos].strip()
            if name and len(name) <= 120 and graphic_id.isdecimal() and source_id.isdecimal():
                yield name, graphic_id, source_id
        except (ValueError, csv.Error):
            continue

def transparent_monster(raw):
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    image = Image.open(io.BytesIO(raw)).convert("RGBA")
    pixels = np.asarray(image).copy()
    channels = pixels[:, :, :3].astype("int16")
    hi, lo = channels.max(axis=2), channels.min(axis=2)
    near_black = (hi <= 29) & ((hi - lo) <= 8)
    border = np.zeros(near_black.shape, dtype=bool)
    border[0, :] = near_black[0, :]
    border[-1, :] = near_black[-1, :]
    border[:, 0] = near_black[:, 0]
    border[:, -1] = near_black[:, -1]
    pixels[ndimage.binary_propagation(border, mask=near_black), 3] = 0
    target = io.BytesIO()
    Image.fromarray(pixels, "RGBA").save(target, "PNG", optimize=True)
    return target.getvalue()

def build(a2, a3, dest, clear_background=True):
    with zipfile.ZipFile(a2) as art, zipfile.ZipFile(a3) as metadata:
        sql = metadata.read(SQL_MEMBER).decode("utf-8", errors="replace")
        directories = {"items": "appcenter/img/item/", "monsters": "appcenter/img/monster/"}
        files = {}
        for group, prefix in directories.items():
            files[group] = {PurePosixPath(e.filename).stem.lower(): e.filename
                            for e in art.infolist()
                            if e.filename.startswith(prefix) and e.filename.lower().endswith(".png")}
        candidate = {g: collections.defaultdict(list) for g in directories}
        for table in TABLES:
            group = "monsters" if table == "npc" else "items"
            for name, graphic_id, source_id in rows(sql, table):
                key = ("ms" if group == "monsters" else "") + graphic_id
                source = files[group].get(key)
                if source:
                    candidate[group][name].append((graphic_id, source_id, table, source))
        manifest = {"schema": 1, "enabled": True,
                    "match_policy": "exact normalized Korean name and one graphic ID",
                    "source_archive": "user-provided a2(1).zip and a3.zip",
                    "items": {}, "monsters": {}, "conflicts": {}}
        images = {}
        for group in directories:
            images[group] = {}
            conflicts = 0
            for name, sources in sorted(candidate[group].items()):
                if len({r[0] for r in sources}) != 1:
                    conflicts += 1
                    continue
                graphic_id, _, table, member = sources[0]
                images[group][graphic_id] = member
                manifest[group][name] = {
                    "path": f"res://assets/external_l1j/{group}/{graphic_id}.png",
                    "graphic_id": graphic_id,
                    "source_table": table,
                    "source_ids": sorted({r[1] for r in sources})[:20],
                }
            manifest["conflicts"][group] = conflicts
        manifest["counts"] = {
            "item_names": len(manifest["items"]),
            "monster_names": len(manifest["monsters"]),
            "item_images": len(images["items"]),
            "monster_images": len(images["monsters"]),
        }
        dest.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as target:
            for group, paths in images.items():
                for graphic_id, source in sorted(paths.items(), key=lambda x: int(x[0])):
                    bytes_ = art.read(source)
                    if group == "monsters" and clear_background:
                        bytes_ = transparent_monster(bytes_)
                    target.writestr(f"assets/external_l1j/{group}/{graphic_id}.png", bytes_)
            target.writestr("data/external_l1j/a2_bridge_v1.json",
                            json.dumps(manifest, ensure_ascii=False, separators=(",", ":")))
            target.writestr("EXTERNAL_A2_README.txt",
                            "Extract this ZIP into the Godot project root. Never copy the original SQL. "
                            "These external images may have third-party copyrights; "
                            "confirm rights before redistribution or commercial use.\n")
    return manifest["counts"]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--a2", default="a2(1).zip")
    parser.add_argument("--a3", default="a3.zip")
    parser.add_argument("--output", default="twilight_external_a2_pack.zip")
    parser.add_argument("--retain-monster-backdrops", action="store_true")
    args = parser.parse_args()
    print(json.dumps(build(Path(args.a2), Path(args.a3), Path(args.output),
                           not args.retain_monster_backdrops), ensure_ascii=False, indent=2))
