#!/usr/bin/env python3
"""Map inventory for build_current523_source_pack.py from the complete 523 client.

Input: the client's Map*.dat files (from client523_source.py or an extracted
client), the 523 files_info.json and the 523 Land table. Each Map DAT is checked
against its files_info SHA-1 before any member is used.

Output (new private directory outside the repository):
* source/Map/<asset>/<member>  - unchanged members (the builder's --source-dir)
* map523_inventory.json        - the builder's --inventory
* map523_inventory_report.json - counts, members outside any Land AssetPath

Land scope: every Land whose AssetPath has members is selected with no content
exclusion, by the user's decision of 2026-11-09 ("implement every map"). The
decision is recorded as the policy provenance; no Land is excluded by name.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_current523_source_pack import LAND_SHA256, asset_root  # noqa: E402

POLICY_SOURCE = ("User decision 2026-11-09: implement every 523 map; no Land content is excluded. "
                 "Not derived from Land names or service activation.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--files-info", type=Path, required=True)
    parser.add_argument("--map-dat-dir", type=Path, required=True, help="directory holding Client/Data/Map*.dat")
    parser.add_argument("--land-table", type=Path, required=True, help="content/Land.json of 523")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[2]
    out = args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error("--output must be outside the repository")
    if out.exists():
        parser.error("--output must be a new directory")
    land_raw = args.land_table.read_bytes()
    if hashlib.sha256(land_raw).hexdigest() != LAND_SHA256:
        parser.error("Land table is not the pinned 523 Land")
    lands = json.loads(land_raw)["rows"]
    info = json.loads(args.files_info.read_text(encoding="utf-8-sig"))
    if int(info.get("version", 0)) != 523:
        parser.error("files_info is not version 523")
    want = {row["path"].replace("\\/", "/"): row for row in info["files"]}
    dats = sorted(path for path in want if path.startswith("Client/Data/Map") and path.endswith(".dat"))

    by_root = {}
    for row in sorted(lands, key=lambda r: (asset_root(r["AssetPath"]), r["AssetPath"])):
        by_root.setdefault(asset_root(row["AssetPath"]), row["AssetPath"])
    members, outside, used_assets = [], [], set()
    source = out / "source"
    for dat in dats:
        local = args.map_dat_dir / PurePosixPath(dat).name
        if not local.is_file():
            local = args.map_dat_dir / dat
        data = local.read_bytes()
        if hashlib.sha1(data).hexdigest() != want[dat]["hash"]:
            raise SystemExit(f"{dat}: SHA-1 differs from files_info 523")
        version = int(want[dat]["version"])
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for item in archive.infolist():
                if item.is_dir():
                    continue
                name = item.filename
                parts = name.split("/")
                root = "/".join(parts[:2]) + "/"
                if len(parts) < 3 or root not in by_root:
                    outside.append(name)
                    continue
                body = archive.read(item)  # CRC verified by zipfile
                target = source / name
                if target.exists():
                    raise SystemExit(f"duplicate map member across DATs: {name}")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(body)
                value = hashlib.sha256(body).hexdigest()
                asset = by_root[root]
                used_assets.add(asset)
                members.append({"member": name, "asset_path": asset, "bytes": len(body), "sha256": value,
                                "crc32": f"{item.CRC:08x}", "availability": "present",
                                "provenance": {"snapshot_version": 523, "container": dat,
                                               "container_sha1": want[dat]["hash"], "selection_version": version,
                                               "evidence_level": "client523_files_info_sha1_verified_dat_member",
                                               "current_selection_verified": True,
                                               "expected_member_sha256": value}})
    assets = sorted(used_assets)
    policies = [{"land_id": row["ID"], "excluded_content": [],
                 "provenance": {"source": POLICY_SOURCE, "native_land_sha256": LAND_SHA256}}
                for row in sorted(lands, key=lambda r: r["ID"]) if row["AssetPath"] in used_assets]
    inventory = {"schema": 1, "edition": "LineageM", "cumulative_version": 523,
                 "asset_paths": assets, "members": members, "land_policy": policies}
    raw = json.dumps(inventory, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    (out / "map523_inventory.json").write_bytes(raw)
    report = {"map_dats": len(dats), "members": len(members), "asset_paths": len(assets),
              "selected_lands": len(policies), "lands_total": len(lands),
              "lands_without_members": sorted({r["AssetPath"] for r in lands} - used_assets),
              "members_outside_land_asset_paths": outside,
              "inventory_sha256": hashlib.sha256(raw).hexdigest()}
    (out / "map523_inventory_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1))
    print(json.dumps({k: (len(v) if isinstance(v, list) else v) for k, v in report.items()}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
