#!/usr/bin/env python3
"""Synthetic RGBA PNG test data. Never copy original proprietary art into CI."""
import argparse
import json
import pathlib
import struct
import zlib

def png_bytes(rgba):
    def chunk(name, body):
        return struct.pack(">I", len(body)) + name + body + struct.pack(">I", zlib.crc32(name + body) & 0xffffffff)
    header = struct.pack(">IIBBBBB", 4, 4, 8, 6, 0, 0, 0)
    rows = b"".join(b"\x00" + bytes(rgba) * 4 for _ in range(4))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    root = pathlib.Path(args.root).resolve()
    records = []
    for kind, graphic, color in [
        ("item", "34", (225, 20, 75, 255)),
        ("monster", "ms852", (20, 155, 235, 255)),
    ]:
        rel = ("assets/l1j/preview/a2/items/" if kind == "item" else "assets/l1j/preview/a2/monsters/") + graphic + ".png"
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            raise SystemExit("Fixture collision: " + str(path))
        path.write_bytes(png_bytes(color))
        candidate = "ext:a2:item:" + graphic if kind == "item" else "ext:a2:monster:" + graphic
        record = {"canonical_candidate_id": candidate, "test_fixture_only": True}
        if kind == "item":
            record["inventory_texture"] = "res://" + rel
            record["ground_texture"] = "res://" + rel
        else:
            record["portrait_texture"] = "res://" + rel
        records.append(record)
    reg = root / "data/l1j/registry/a2_visuals_normalized.json"
    reg.parent.mkdir(parents=True, exist_ok=True)
    if reg.exists():
        raise SystemExit("Fixture registry collision: " + str(reg))
    reg.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("synthetic_rgba_pngs=2 registry_records=2 third_party_assets=0")

if __name__ == "__main__":
    main()
