"""Strict source/provenance checks for all 125 bundled fallback skill icons."""
import json
import pathlib
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
index = json.loads((ROOT / "data/skills/styled_icon_provenance.json").read_text())
master = json.loads((ROOT / "data/skills/master.json").read_text())
records = index["records"]
assert index["status"] == "PUBLIC_LICENSED_ALTERNATE_NOT_ORIGINAL"
assert index["total"] == len(records) == len(master["records"]) == 125
original = {str(s["id"]): str(s["name"]) for s in master["records"]}
names = set()
for skill in records:
    id = skill["skill_id"]
    assert id in original and skill["name"] == original[id], id
    assert id not in names and not skill["game_original"]
    names.add(id)
    filename = skill["icon"].removeprefix("res://")
    assert filename == "assets/skills/styled_icons/" + id + ".svg"
    assert skill["source"].startswith(("lorc/", "delapouite/"))
    assert skill.get("theme") in {"fire","electric","ice","earth","heal","blood","shadow","holy","arcane","nature","wind","weapon"}
    assert skill.get("visual_fidelity") == "MOTIF_THEMATIC_NO_SOURCE_PIXEL_MATCH"
    image = ROOT / filename
    assert image.is_file(), filename
    content = image.read_text(encoding="utf-8")
    assert "<svg" in content and "url(#f)" in content and "url(#b)" in content
    ET.fromstring(content)
assert len(names) == 125
print("SKILL_STYLED_ICON_125_SVG_PASS")
