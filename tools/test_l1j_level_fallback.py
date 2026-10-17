#!/usr/bin/env python3
"""Validate the optional L1J nearest-level fallback without loading Godot."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / "data/monsters/l1j_level_fallback_v1.json").read_text(encoding="utf-8"))
base = json.loads((ROOT / "data/game_db_v17.json").read_text(encoding="utf-8"))["몬스터"]
catalog = json.loads((ROOT / "data/monsters/monster_world_catalog.json").read_text(encoding="utf-8"))
overrides = data["overrides"]
assert data["schema_version"] == 1
assert len(overrides) == 211
assert sum(x["role"] == "보스" for x in overrides.values()) == 33
assert sum(x["role"] == "일반" for x in overrides.values()) == 178
named_boss = {"흑장로", "이프리트", "드레이크", "거대 드레이크"}
records = {x["name"]: {**x, **catalog["overlays"].get(x["name"], {})} for x in base}
for entry in catalog["additions"]:
    if entry["name"] not in records:
        records[entry["name"]] = entry
assert len(records) == 318
assert len(set(records) - set(overrides)) == 107
allowed = {"expected_level", "previous_hp", "role", "source_id", "source_level", "scale", "hp", "atk", "ac", "mr", "melee_accuracy", "ranged_accuracy", "magic_accuracy"}
for name, change in overrides.items():
    assert name in records, name
    orig = records[name]
    assert int(orig["lv"]) == change["expected_level"], (name, "level mismatch")
    assert int(orig["hp"]) == change["previous_hp"], (name, "HP mismatch")
    if "is_boss" in orig:
        boss = bool(orig["is_boss"])
    elif "boss" in orig:
        boss = bool(orig["boss"])
    else:
        boss = ("보스" in str(orig.get("desc", "")) or name.endswith("의 지배자") or name in named_boss)
    assert boss == (change["role"] == "보스"), (name, "boss mismatch")
    assert not set(change).difference(allowed), name
    assert change["expected_level"] > 0 and change["source_level"] > 0, name
    assert abs(change["scale"] - change["expected_level"] / change["source_level"]) < 1e-7, name
    assert change["hp"] >= 30 and change["atk"] >= 3, name
    assert change["ac"] <= 0 and change["mr"] >= 0, name
    assert change["melee_accuracy"] >= 1 and change["ranged_accuracy"] >= 1, name
    assert "grade" not in change and "drop" not in change and "is_boss" not in change, name
print("L1J_NEAREST_LEVEL_FALLBACK_OK: 211 patched (33 bosses, 178 normals); 107 untouched")
