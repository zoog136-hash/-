#!/usr/bin/env python3
"""TI2 inventory for build_current523_tile_pack.py from the complete 523 client.

Input: the client's Tile*.dat files and the 523 files_info.json. Each DAT is
checked against its files_info SHA-1 before any member is used; members keep
their exact bytes. Output (new private directory outside the repository):
source/Tile/<id>.ti2 (--source-dir) and tile523_inventory.json (--inventory).
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import sys
import zipfile

MEMBER = re.compile(r"^Tile/(\d+)\.ti2$")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--files-info", type=Path, required=True)
    parser.add_argument("--tile-dat-dir", type=Path, required=True, help="directory holding Tile*.dat")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[2]
    out = args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error("--output must be outside the repository")
    if out.exists():
        parser.error("--output must be a new directory")
    info = json.loads(args.files_info.read_text(encoding="utf-8-sig"))
    if int(info.get("version", 0)) != 523:
        parser.error("files_info is not version 523")
    want = {row["path"].replace("\\/", "/"): row for row in info["files"]}
    dats = sorted(p for p in want if re.fullmatch(r"Client/Data/Tile\d+\.dat", p))
    members, other = [], []
    for dat in dats:
        local = args.tile_dat_dir / PurePosixPath(dat).name
        data = local.read_bytes()
        if hashlib.sha1(data).hexdigest() != want[dat]["hash"]:
            raise SystemExit(f"{dat}: SHA-1 differs from files_info 523")
        dat_sha256 = hashlib.sha256(data).hexdigest()
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for item in archive.infolist():
                if item.is_dir():
                    continue
                if not MEMBER.match(item.filename):
                    other.append(item.filename)
                    continue
                body = archive.read(item)
                target = out / "source" / item.filename
                if target.exists():
                    raise SystemExit(f"duplicate tile member across DATs: {item.filename}")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(body)
                value = hashlib.sha256(body).hexdigest()
                members.append({"member": item.filename, "bytes": len(body), "sha256": value, "availability": "present",
                                "provenance": {"edition": "LineageM", "snapshot_version": 523, "container": dat,
                                               "selection_version": int(want[dat]["version"]),
                                               "current_selection_verified": True, "expected_member_sha256": value,
                                               "source_dat_sha256": dat_sha256, "current_selected_dat_sha256": dat_sha256,
                                               "evidence_level": "client523_files_info_sha1_verified_dat_member"}})
    members.sort(key=lambda row: int(MEMBER.match(row["member"]).group(1)))
    inventory = {"schema": 1, "edition": "LineageM", "cumulative_version": 523, "members": members}
    raw = json.dumps(inventory, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    (out / "tile523_inventory.json").write_bytes(raw)
    print(json.dumps({"tile_dats": len(dats), "tiles": len(members), "non_tile_members": len(other),
                      "inventory_sha256": hashlib.sha256(raw).hexdigest()}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
