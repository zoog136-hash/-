#!/usr/bin/env python3
"""Read uploaded A2 split archives and validate installed source identities.

Archives are data, never programs to execute. Sprite IDs identify byte streams,
not playable classes. This checker does not edit any game catalog or save.
"""
import argparse
import collections
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import zipfile

from build_external_a2_pack import transparent_monster
from build_original_visual_bindings import verify_png


def sha(data):
    return hashlib.sha256(data).hexdigest()


def audit(root, patch, images, output):
    errors = []
    report = {"schema": 1, "archives": [], "spx": [], "images": [],
              "excluded": [], "errors": errors, "game_identity_changes": 0}
    for source in (patch, images):
        with zipfile.ZipFile(source) as archive:
            bad = archive.testzip()
            if bad:
                raise ValueError("Corrupt ZIP member: " + bad)
        report["archives"].append({"filename": source.name, "sha256": sha(source.read_bytes()), "crc_verified": True})
    with zipfile.ZipFile(patch) as outer:
        member = "connector/patch/patch_1.zip"
        with zipfile.ZipFile(io.BytesIO(outer.read(member))) as archive:
            for name in sorted(archive.namelist()):
                if not name.endswith(".spx"):
                    continue
                sequence = PurePosixPath(name).stem
                if len(sequence.split("-")) != 2 or not all(p.isdigit() for p in sequence.split("-")):
                    raise ValueError("Invalid sequence ID: " + sequence)
                digest = sha(archive.read(name))
                meta = root / "assets/l1j/candidates/spx_converted" / sequence / "frame_metadata.json"
                match = meta.is_file() and json.loads(meta.read_text())["source_sha256"] == digest
                if not match:
                    errors.append("Missing or changed restored source: " + sequence)
                report["spx"].append({"sequence_id": sequence, "source_member": member + "::" + name,
                                      "sha256": digest, "restored_source_verified": match})
    counts = collections.Counter()
    with zipfile.ZipFile(images) as archive:
        for name in sorted(archive.namelist()):
            path = PurePosixPath(name)
            kind = "item" if path.parent.as_posix() == "img/item" else "monster" if path.parent.as_posix() == "img/monster" else ""
            if not kind or path.suffix.lower() != ".png":
                continue
            graphic = path.stem.lower().removeprefix("ms")
            if not graphic.isdigit():
                report["excluded"].append({"source_member": name, "reason": "No non-negative numeric resource ID"})
                continue
            raw = archive.read(name)
            size = verify_png(raw)
            display = transparent_monster(raw) if kind == "monster" else raw
            target = root / "assets/external_l1j" / ("items" if kind == "item" else "monsters") / (graphic + ".png")
            matched = target.is_file() and sha(target.read_bytes()) == sha(display)
            if not matched:
                errors.append("Missing or changed installed original: " + kind + ":" + graphic)
            counts[kind] += 1
            report["images"].append({"kind": kind, "graphic_id": graphic, "source_member": name,
                                     "sha256": sha(raw), "display_sha256": sha(display),
                                     "dimensions": list(size), "installed_verified": matched,
                                     "alpha_derivative": kind == "monster"})
    report["counts"] = {"spx_source_sequences": len(report["spx"]), "item_images": counts["item"],
                        "monster_images": counts["monster"], "errors": len(errors), "new_actor_identities": 0}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("UPLOADED_SOURCE_PARTS_" + ("OK" if not errors else "FAIL"), json.dumps(report["counts"]), flush=True)
    for error in errors[:12]:
        print(error)
    return bool(errors)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--patch", required=True, type=Path)
    parser.add_argument("--images", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    raise SystemExit(audit(args.root, args.patch, args.images, args.output))
