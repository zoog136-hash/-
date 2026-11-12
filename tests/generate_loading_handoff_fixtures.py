#!/usr/bin/env python3
"""Create bounded synthetic fixtures outside Git for loading handoff checks.

No original resource or rendered-art evidence. The existing authored fixture
builders are reused; the runtime Land proof fields are test-only sentinels so
this metadata exercises the production validator, never a claimed native Land.
"""
import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "tests"), str(ROOT / "tools/map_restore")]
from test_current523_source_pack import GenericSourcePackTest, PACK, minimal, fixture_inventory
from test_current523_tile_pack import runtime_fixture


def generate(output, count=256):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    source_root = output / "maps"
    source_root.mkdir()
    fixture = GenericSourcePackTest()
    source, land, inventory_path, _ = fixture.make_fixture(source_root)
    members = [("Map/0/80008000.s32", "0/", minimal()),
               ("Map/13341/800f7ff3e.s32", "13341", minimal(b"opaque"))]
    for index in range(count - 2):
        name = "Map/0/%08x.s32" % (0x81008100 + index)
        data = minimal()
        (source / name).write_bytes(data)
        members.append((name, "0/", data))
    inventory_path.write_text(json.dumps(fixture_inventory(members)))
    manifest = fixture.prepare(source, land, inventory_path)
    # Explicit synthetic metadata, not evidence that a native table was read.
    manifest["native_land_table"].update(
        sha256="8778d18d8c23a0ccb0a555f495e056987796232c616dec805dfb4c4d633b0ef9",
        bytes=326356, evidence="SYNTHETIC_HANDOFF_TEST_ONLY")
    map_output = output / "map-pack"
    PACK.publish(manifest, source, map_output)
    tile_output, tile_sha = runtime_fixture(output / "tiles", count=35, atlas_storage="runtime_ti2")
    options = {"raw_root": str(map_output),
               "source_manifest_sha256": PACK.sha((map_output / PACK.MANIFEST_NAME).read_bytes()),
               "tile_root": str(tile_output), "tile_manifest_sha256": tile_sha,
               "synthetic_only": True, "source_members": count, "tiles": 35}
    (output / "options.json").write_text(json.dumps(options, indent=2) + "\n")
    print(json.dumps(options))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--members", type=int, default=256)
    args = parser.parse_args()
    if not 2 <= args.members <= 2000:
        parser.error("--members must be in 2..2000")
    generate(args.output, args.members)
