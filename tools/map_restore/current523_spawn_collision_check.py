#!/usr/bin/env python3
"""Cell-level collision/movement check of current523 spawn regions.

Uses the original Aden S32 cells and the same own movement rule as
scripts/maps/current523_aden_source_field.gd (CURRENT523_S32_OWN_ALLOWLIST_V1):
a cell is walkable when both half-cell attribute words are in the allowlist
{0,4,8,12,32}, neither is 65535, and neither floor reference is 0xFFFFFFFF.
Steps are 8-directional; a diagonal needs both cardinal neighbours (can_step).

For every region from tools/map_restore/current523_spawn_preview.py it reports
- walkable cells inside the territory (0 = nothing can ever spawn there),
- the largest 8-connected walkable component inside the territory and how
  many walkable cells sit in small isolated pockets (spawns there cannot walk
  to the rest of the hunting area).

    python3 tools/map_restore/current523_spawn_collision_check.py \
      --s32-dir /private/Map/Aden --pack /private/patch523-world-links --land 4
"""
import argparse
import collections
import gzip
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import current523_s32 as codec  # noqa: E402
import current523_spawn_preview as preview  # noqa: E402

ALLOWED_WORDS = {0, 4, 8, 12, 32}
FLOOR_SENTINEL = 0xFFFFFFFF
DIRECTIONS = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
POCKET_CELLS = 24
_STEM = re.compile(r"[0-9A-Fa-f]{8}\Z")


def chunk_origin(stem):
    """Same filename placement as current523_aden_review.gd candidate_origin()."""
    if not _STEM.match(stem):
        return None
    return ((int(stem[:4], 16) - 0x7E00) * 64, (int(stem[4:], 16) - 0x7E00) * 64)


class Grid:
    def __init__(self, directory: Path):
        self.chunks = {}
        self.unplaced = []
        for path in sorted(directory.iterdir()):
            name = path.name
            if name.endswith(".s32.gz"):
                stem, data = name[:-7], gzip.decompress(path.read_bytes())
            elif name.endswith(".s32"):
                stem, data = name[:-4], path.read_bytes()
            else:
                continue
            origin = chunk_origin(stem)
            if origin is None:
                self.unplaced.append(name)
                continue
            row = codec.read_s32(data, f"Map/Aden/{stem}.s32")
            walk = bytearray(64 * 64)
            attributes, floor = row["attribute_u16le"], row["floor_u32le"]
            for y in range(64):
                for x in range(64):
                    index = y * 128 + x * 2
                    words = (int.from_bytes(attributes[index * 2:index * 2 + 2], "little"),
                             int.from_bytes(attributes[index * 2 + 2:index * 2 + 4], "little"))
                    refs = (int.from_bytes(floor[index * 4:index * 4 + 4], "little"),
                            int.from_bytes(floor[index * 4 + 4:index * 4 + 8], "little"))
                    walk[y * 64 + x] = int(all(w != 65535 and w in ALLOWED_WORDS for w in words)
                                           and FLOOR_SENTINEL not in refs)
            self.chunks[origin] = walk

    def walkable(self, x, y):
        chunk = self.chunks.get((x // 64 * 64, y // 64 * 64))
        return bool(chunk) and chunk[(y % 64) * 64 + (x % 64)] == 1

    def can_step(self, x, y, dx, dy):
        if not self.walkable(x + dx, y + dy):
            return False
        return dx == 0 or dy == 0 or (self.walkable(x + dx, y) and self.walkable(x, y + dy))


def check_region(grid, rect):
    x0, y0, width, height = rect
    cells = {(x, y) for y in range(y0, y0 + height) for x in range(x0, x0 + width) if grid.walkable(x, y)}
    components, seen = [], set()
    for start in cells:
        if start in seen:
            continue
        queue, size = collections.deque([start]), 0
        seen.add(start)
        while queue:
            x, y = queue.popleft()
            size += 1
            for dx, dy in DIRECTIONS:
                nxt = (x + dx, y + dy)
                if nxt in cells and nxt not in seen and grid.can_step(x, y, dx, dy):
                    seen.add(nxt)
                    queue.append(nxt)
        components.append(size)
    components.sort(reverse=True)
    pockets = sum(size for size in components[1:] if size < POCKET_CELLS)
    return {"area": width * height, "walkable": len(cells), "largest": components[0] if components else 0,
            "components": len(components), "pocket_cells": pockets}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--s32-dir", required=True, type=Path)
    parser.add_argument("--pack", required=True, type=Path)
    parser.add_argument("--land", type=int, default=4)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    grid = Grid(args.s32_dir)
    result = preview.preview(args.pack, args.land)
    rows, totals = [], collections.Counter()
    for region in result["rows"]:
        stats = check_region(grid, region["source_rect"])
        stats.update(key=region["key"], name=region["name"], boss=region["boss"], max_count=region["max_count"])
        rows.append(stats)
        totals["regions"] += 1
        totals["slots"] += region["max_count"]
        if stats["walkable"] == 0:
            totals["no_floor_regions"] += 1
            totals["no_floor_slots"] += region["max_count"]
        elif stats["walkable"] < region["max_count"] * 4:
            totals["crowded_regions"] += 1
        if stats["pocket_cells"]:
            totals["regions_with_pockets"] += 1
            totals["pocket_cells"] += stats["pocket_cells"]
        totals["walkable_cells"] += stats["walkable"]
    print(f"S32 chunks {len(grid.chunks)} (unplaced {len(grid.unplaced)}); Land{args.land} {result['name']}")
    print(json.dumps(dict(totals), ensure_ascii=False))
    for stats in sorted(rows, key=lambda r: (r["walkable"] > 0, r["walkable"]))[:15]:
        print(f"  walkable={stats['walkable']:>5}/{stats['area']:<6} largest={stats['largest']:>5} pockets={stats['pocket_cells']:>3} boss={int(stats['boss'])} {stats['name'][:30]}")
    if args.out:
        args.out.write_text(json.dumps({"totals": totals, "rows": rows}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
