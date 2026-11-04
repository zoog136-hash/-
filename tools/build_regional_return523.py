#!/usr/bin/env python3
"""Compile selection policy from verified private523 tables; never copy raw rows."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"


def build(content, archive):
    archive = Path(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SOURCE_SHA:
        raise ValueError("source archive identity mismatch")
    with zipfile.ZipFile(archive) as pack:
        if pack.testzip() is not None:
            raise ValueError("source CRC failure")
        def rows(name):
            raw = pack.read("content/" + name + ".json")
            if content is not None and (Path(content) / (name + ".json")).read_bytes() != raw:
                raise ValueError("extracted table differs from verified archive: " + name)
            return json.loads(raw.decode("utf-8-sig"))["rows"]
        groups, changes = rows("QuickSlotChange"), rows("QuickSlotChangeData")
        source_ids, land_ids = {239, 282783, 295514}, {44544, 44614, 47722}
        if len(groups) != 3 or len(changes) != 9 or {r["ItemClassID"] for r in groups} != source_ids:
            raise ValueError("unexpected source group coverage")
        group_ids = {r["ID"]: r["ItemClassID"] for r in groups}
        links = {(group_ids[r["QuickSlotChangeID"]], r["LandID"], r["ItemClassID"]) for r in changes}
        if len(group_ids) != 3 or links != {(item, land, 126424) for item in source_ids for land in land_ids}:
            raise ValueError("source does not define the exact nine item/Land relations")
        if {r["ID"] for r in rows("Land") if r["ID"] in land_ids} != land_ids:
            raise ValueError("missing source Land definitions")
        descriptions = {r["ID"]: r["Description"] for r in rows("DescData_Korean")}
        items = {r["ID"]: r for r in rows("ItemClass")}
        grades = {r["ID"]: descriptions[r["DescID"]] for r in rows("Grade")}
        types = {r["ID"]: r["Name"] for r in rows("BonusType")}
        bonuses = {r["ID"]: r for r in rows("Bonus")}
        memberships = rows("ItemBonus")
        projected = {}
        for item in [239, 282783, 295514, 126424]:
            infinite = any(r["ItemClassID"] == item and types[bonuses[r["BonusID"]]["BonusTypeID"]] == "InfiniteAmount" and bonuses[r["BonusID"]]["Value"] == 1 for r in memberships)
            projected[str(item)] = {"name": descriptions[items[item]["DescID"]], "grade": grades[items[item]["GradeID"]], "aliases": ["귀환 주문서"] if item == 239 else [], "infinite": infinite}
    return {"schema": 1, "format": "compiled-selection-policy.v1", "source_snapshot": "patch523", "source_archive_sha256": SOURCE_SHA,
            "source_item_ids": sorted(source_ids), "target_item_id": 126424, "items": projected,
            "lands": {str(land): True for land in sorted(land_ids)},
            "host_bindings": {"source_70": {"land_id": 44544, "return_map": "source_70", "return_mode": "spawn", "estimated": True,
                              "basis": "TWILIGHT existing Forgotten Island; separate PC layout, no M coordinate equivalence"}}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, help="optional extracted source root; checked against archive")
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve() == args.archive.resolve() or (args.source_dir and args.output.resolve().is_relative_to(args.source_dir.resolve())):
        raise ValueError("original archive/extracted source must remain unchanged")
    result = build(args.source_dir / "content" if args.source_dir else None, args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("REGIONAL_RETURN_SELECTION_POLICY", len(result["source_item_ids"]), len(result["source_item_ids"])*len(result["lands"]), len(result["lands"]))


if __name__ == "__main__": main()
