#!/usr/bin/env python3
"""Add the client's no-action static pictures to an existing private SP2 bank.

LineageM 1.10.22.0 static analysis (auxiliary-layer report, branch
`cached_descriptor == null && primary_action <= 0`): a sprite with no action
descriptor is drawn as main `(sprite << 16) | 0`, i.e. `Sprite/<id>-0.sp2`
direction 0, picture 0, after one non-recursive header remap of the file ID;
its 101 shadow ID is requested the same way; clothes are not collected. A
missing file is simply not drawn.

This tool adds `static_pictures` and the needed raw members to a bank built by
build_reference_sp2_bank.py. Every member is taken from the bank's metadata
inventory (exact bytes and SHA-256) and its direction-0 frame 0 is parsed with
the repository SP2 parser. The previous manifest is kept as
`manifest.actions-only.json`. Nothing is played or rendered here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

import original_spr
import build_reference_sp2_bank as bank

STATIC_BRANCH = "client_static_no_action_descriptor"
EVIDENCE = ("LineageM_1.10.22.0 auxiliary-layer analysis: no-action branch draws (sprite<<16)|0 "
            "(file <remapped id>-0, direction 0, picture 0) and the 101 shadow the same way; clothes not collected")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def frame_zero(raw: bytes):
    """Return (ok, reason) for direction 0 / frame 0 of an SP2 member."""
    import original_sp2  # needs brotli/Pillow (requirements.txt); imported only when parsing
    try:
        _, mask, dirs, _ = original_sp2.parse(raw)
    except Exception as error:  # strict parser failures are recorded, not hidden
        return False, f"sp2_parse_failed: {error}"
    if not mask & 1:
        return False, "direction0_absent"
    frames, _ = dirs[0]
    if not frames:
        return False, "frame0_absent"
    _, refs = frames[0]
    if not refs:
        return False, "frame0_empty"
    return True, ""


def static_candidates(declarations):
    """Sprites whose resolved declaration has no action: the client's static branch."""
    result = {}
    for sprite_id, matches in declarations.items():
        if len(matches) != 1:
            continue
        declaration = matches[0]
        try:
            _, actions = original_spr.resolve(declarations, sprite_id)
        except ValueError:
            continue
        if actions:
            continue
        # One non-recursive header remap selects the file ID.
        file_id = declaration.alias_target if declaration.alias_target is not None else sprite_id
        shadow = None
        for reference in declaration.references:
            if reference["kind"] == "shadow" and reference["targets"]:
                shadow = reference["targets"][0]
        if shadow is not None:
            shadow_matches = declarations.get(shadow, [])
            if len(shadow_matches) == 1 and shadow_matches[0].alias_target is not None:
                shadow = shadow_matches[0].alias_target
        result[sprite_id] = {"declaration": declaration, "file_id": file_id, "shadow_file_id": shadow}
    return result


def add_static_pictures(bank_dir: Path, metadata_dir: Path, spr_root: Path, original_root: Path, link_raw: bool):
    manifest_path = bank_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    bank.require(manifest.get("kind") == "current523_reference_sp2_action_bank", "not a reference SP2 bank")
    bank.require("static_pictures" not in manifest, "bank already has static pictures")
    metadata = bank.load_metadata(metadata_dir)
    declarations = original_spr.read(sorted(spr_root.glob("list_*.spr")))
    dummy = metadata.get("dummy_declarations", {})
    members = manifest["members"]
    statics, counts = {}, {"candidates": 0, "added": 0, "body_missing": 0, "body_invalid": 0,
                            "dummy_excluded": 0, "with_shadow": 0, "shadow_missing_or_invalid": 0}
    reasons = {}

    def member_record(name):
        identity = metadata["identities"].get(name)
        if identity is None:
            return None, "absent_from_client"
        body = (original_root / name).read_bytes()
        bank.require(len(body) == identity["bytes"] and sha(body) == identity["sha256"], f"original changed: {name}")
        ok, reason = frame_zero(body)
        return (body if ok else None), reason

    for sprite_id, candidate in sorted(static_candidates(declarations).items()):
        counts["candidates"] += 1
        if sprite_id in dummy or candidate["file_id"] in dummy:
            counts["dummy_excluded"] += 1
            continue
        body_name = f"Sprite/{candidate['file_id']}-0.sp2"
        body, reason = member_record(body_name)
        if body is None:
            counts["body_missing" if reason == "absent_from_client" else "body_invalid"] += 1
            reasons[reason.split(":")[0]] = reasons.get(reason.split(":")[0], 0) + 1
            continue
        layers = [{"kind": "body", "source_sprite_id": sprite_id, "file_sprite_id": candidate["file_id"],
                   "member": body_name, "group_bit": 0, "frame_index": 0}]
        new_members = {body_name: body}
        if candidate["shadow_file_id"] is not None:
            shadow_name = f"Sprite/{candidate['shadow_file_id']}-0.sp2"
            shadow, _ = member_record(shadow_name)
            if shadow is None:
                counts["shadow_missing_or_invalid"] += 1
            else:
                counts["with_shadow"] += 1
                layers.append({"kind": "shadow", "source_sprite_id": sprite_id,
                               "file_sprite_id": candidate["shadow_file_id"],
                               "member": shadow_name, "group_bit": 0, "frame_index": 0})
                new_members[shadow_name] = shadow
        for name, body_bytes in new_members.items():
            if name in members:
                bank.require(members[name]["sha256"] == sha(body_bytes), f"bank member differs: {name}")
                continue
            identity = metadata["identities"][name]
            target = bank_dir / "raw" / name
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            if link_raw:
                os.link(original_root / name, target)
            else:
                target.write_bytes(body_bytes)
            members[name] = {"archive": identity.get("archive"), "bytes": identity["bytes"], "container": None,
                             "crc32": identity.get("crc32"), "expected_original_sha256": identity["sha256"],
                             "identity_basis": "size_crc_and_expected_sha256", "member": name,
                             "path": "raw/" + name, "sha256": identity["sha256"]}
        declaration = candidate["declaration"]
        statics["sprite:" + str(sprite_id)] = {
            "branch": STATIC_BRANCH, "layers": layers, "draw_order": ["body", "shadow"],
            "source_declaration": {"source_file": declaration.source_file, "source_line": declaration.source_line,
                                   "alias_target": declaration.alias_target}}
        counts["added"] += 1
    os.replace(manifest_path, bank_dir / "manifest.actions-only.json")
    manifest["static_pictures"] = statics
    manifest["static_picture_contract"] = {"branch": STATIC_BRANCH, "evidence": EVIDENCE,
                                           "frame": "direction0_picture0", "clothes": "not_collected"}
    body = bank.json_bytes(manifest)
    manifest_path.write_bytes(body)
    return {"counts": counts, "invalid_reasons": reasons, "manifest_sha256": sha(body),
            "static_pictures": len(statics)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--bank", type=Path, required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--spr-root", type=Path, required=True)
    parser.add_argument("--original-root", type=Path, required=True)
    parser.add_argument("--link-raw", action="store_true")
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[2]
    out = args.bank.resolve()
    if out == repo or repo in out.parents:
        parser.error("--bank must be outside the repository")
    print(json.dumps(add_static_pictures(args.bank, args.metadata, args.spr_root, args.original_root, args.link_raw),
                     ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
