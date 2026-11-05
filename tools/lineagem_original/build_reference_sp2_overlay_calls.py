#!/usr/bin/env python3
"""Write private host overlay calls from the supplied normal-visual handoff.

This connects existing source relationships. It does not inspect pixels, replay
animations, validate the handoff, or promote a relationship to native dispatch.
The caller separately admits the current523 parent and pins this output.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path


def rows(path):
    with gzip.open(path, "rt", encoding="utf-8") as stream:
        for line in stream:
            if line.strip():
                yield json.loads(line)


def build(context):
    parents, held, seen = {}, [], set()
    for row in rows(context):
        for path in row.get("normal_visual_parent_source_paths", []):
            parent = path["typed_parent_action_link"]
            if parent.get("excluded_content") or parent.get("source_role") != "visual_source_reference":
                continue
            action = path["source_action_tokens"]
            target = path["completed_dependency_path"]["event_target_sprite_id"]
            child_keys = {
                address["action_key"]
                for address in row.get("completed_host_body_and_clothes_address_rows", [])
                if address.get("event_target_sprite_id") == target and address.get("layer_role") == "body"
            }
            if len(child_keys) != 1:
                held.append({"member": row["member"], "target_sprite_id": target,
                             "reason": "single_action_host_child_not_supplied"})
                continue
            child_key = next(iter(child_keys))
            child_action = int(child_key.rsplit(":A", 1)[1])
            parent_key = f"{parent['root_sprite_id']}:{action['action_id']}"
            for event in path.get("literal_event_tokens", []):
                if event["target_sprite_id"] != target:
                    continue
                identity = (parent_key, event["token_index"], target, child_action)
                if identity in seen:
                    continue
                seen.add(identity)
                call = {"target_sprite_id": target, "child_action_id": child_action,
                        "classification": "normal_visual", "source_action_key": action["action_key"],
                        "child_source_action_key": child_key,
                        "literal_reference": event["literal_reference"],
                        "event_reference_id": event["event_reference_id"],
                        "typed_reference_ids": path["selected_normal_reference_ids"],
                        "source_file": event["source_file"], "source_line": event["source_line"],
                        "source_file_sha256": event["source_file_sha256"]}
                parents.setdefault(parent_key, {}).setdefault(str(event["token_index"]), []).append(call)
    return {"schema": 1, "source_snapshot": "patch523", "parents": parents,
            "semantics": "existing_project_host_compatibility_overlay_calls",
            "native_dispatch_verified": False, "actual_game_use": None,
            "source_context": str(context), "held_calls": held}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--context", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    value = build(args.context)
    body = (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()
    args.output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with args.output.open("xb") as stream:
        stream.write(body)
    args.output.chmod(0o600)
    # Content address at serialization time for the production caller's pin;
    # there is no additional file readback or validation pass.
    print(json.dumps({"output": str(args.output), "bytes_written": len(body),
                      "sha256_at_write": hashlib.sha256(body).hexdigest(),
                      "parent_action_bindings_written": len(value["parents"]),
                      "calls_written": sum(len(calls) for parent in value["parents"].values() for calls in parent.values()),
                      "held_calls": len(value["held_calls"]), "additional_validation": False}))


if __name__ == "__main__":
    main()
