#!/usr/bin/env python3
"""Verify that boss authoring preserves normal profiles and all old runtime art."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return digest(json.dumps(value, ensure_ascii=False, sort_keys=True,
                             separators=(",", ":")).encode())


def main():
    baseline = json.loads((HERE / "baseline.json").read_text())
    queue = json.loads((HERE / "queue.json").read_text())
    profiles = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())
    for key, expected in baseline["normal_profile_canonical_sha256"].items():
        assert canonical(profiles["profiles"][key]) == expected, key
    for expected in baseline["existing_runtime_assets"]:
        path = ROOT / expected["path"]
        assert path.is_file() and path.stat().st_size == expected["bytes"], expected["path"]
        assert digest(path.read_bytes()) == expected["sha256"], expected["path"]
    previous = json.loads(subprocess.check_output(
        ["git", "show", baseline["source_commit"] + ":data/combat_animation_profiles.json"],
        cwd=ROOT))
    mutable = {row["key"] for row in queue["work_queue"]}
    assert profiles.keys() == previous.keys()
    assert profiles["profiles"].keys() == previous["profiles"].keys()
    for key, row in previous["profiles"].items():
        if key not in mutable:
            assert profiles["profiles"][key] == row, key
    for path in ["docs/remake/evidence/pr122-remaining106/batch17/all498-production-status.json",
                 "data/pr122_native_production_approvals.json"]:
        old = subprocess.check_output(["git", "show", baseline["source_commit"] + ":" + path], cwd=ROOT)
        assert (ROOT / path).read_bytes() == old, path
    result = {
        "schema": "pr122-boss-repair-preservation-result-v1",
        "source_commit": baseline["source_commit"],
        "status": "PASS", "normal_profiles_preserved": 258,
        "old_runtime_assets_preserved": len(baseline["existing_runtime_assets"]),
        "other_profile_changes": 0, "original_approval_ledgers_changed": False,
        "normal_frame_review": "Previous exact-byte frame audit remains valid; no normal art quality review.",
    }
    (HERE / "preservation-result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
