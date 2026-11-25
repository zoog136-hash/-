#!/usr/bin/env python3
"""Inventory canonical 523 CSB controls without copying client content into the repo.

Includes controls in source members absent from the selected build. A matching
pack entry is evidence of an asset, not evidence that its action ran. A control
is addressed by (member, source hash, offset), since node names can repeat.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from read_source_csb import Reader


def nodes(root):
    yield root
    for child in root.get("children", []):
        yield from nodes(child)


def audit(inputs, manifest_path, output):
    index = json.loads((inputs / "source-index.json").read_bytes())
    source_files = index["source_files"]
    declared = {path for path in source_files if path.endswith(".csb")}
    expected = set((inputs / "csb-scenes.txt").read_text().splitlines())
    if expected != declared or not expected:
        raise ValueError("Input list and source index disagree")
    manifest = json.loads(manifest_path.read_bytes())
    counts = Counter(authored_callback=0)
    members = inputs / "members"
    with output.open("x", encoding="utf-8") as sink:
        for member in sorted(expected):
            path = (members / member).resolve()
            if not path.is_relative_to(members.resolve()):
                raise ValueError("Source member outside input directory")
            raw = path.read_bytes()
            digest = hashlib.sha256(raw).hexdigest()
            if digest != source_files[member]["sha256"]:
                raise ValueError(f"Source hash mismatch: {member}")
            source = Reader(raw).parse()
            installed = manifest["scenes"].get(member)
            if installed and installed["_source_sha256"] != digest:
                raise ValueError(f"Selected scene identity differs: {member}")
            counts["source_scenes"] += 1
            if installed:
                counts["selected_scenes"] += 1
            for node in nodes(source["nodeTree"]):
                kind = node["classname"]
                options = node.get("options") or {}
                widget = options.get("widgetOptions", options.get("nodeOptions", options)) or {}
                if kind not in ("Button", "CheckBox", "Slider", "TextField") and not widget.get("touchEnabled"):
                    continue
                callback = widget.get("callBackName") or ""
                row = {"member": member, "sha256": digest, "offset": node["_offset"],
                       "kind": kind, "name": widget.get("name"), "touch": bool(widget.get("touchEnabled")),
                       "callback": callback, "scene_in_selection": bool(installed)}
                print(json.dumps(row, ensure_ascii=False, separators=(",", ":")), file=sink)
                counts["controls"] += 1
                counts["type_" + kind] += 1
                if callback:
                    counts["authored_callback"] += 1
                if installed:
                    counts["selected_member_controls"] += 1
    return counts


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("private_jsonl", type=Path)
    args = parser.parse_args()
    if args.private_jsonl.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
        parser.error("Use a private output path outside the checkout")
    print(json.dumps(audit(args.inputs, args.manifest, args.private_jsonl), sort_keys=True))
