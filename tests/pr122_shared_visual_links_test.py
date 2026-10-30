#!/usr/bin/env python3
"""PR122 shared visual profile assertions. No external art and no CI dispatch."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
profiles = json.loads((root/"data/combat_animation_profiles.json").read_text(encoding="utf-8"))["profiles"]
world = (root/"scripts/world.gd").read_text(encoding="utf-8")
base = profiles["transform:2"]
for key in ("transform:110", "transform:167"):
    record = profiles[key]
    assert record["frames_path"] == base["frames_path"], key
    assert record["pixel_scale"] == base["pixel_scale"], key
    assert record["sprite_offset"] == base["sprite_offset"], key
    assert record["color_tint"] != base["color_tint"], key
    assert record["shared_visual_source"] == "transform:2", key
assert profiles["transform:110"]["color_tint"] != profiles["transform:167"]["color_tint"]
for child, donor in (("138","139"),("140","141"),("179","44"),("182","44")):
    assert profiles["transform:"+child]["shared_visual_source"] == "transform:"+donor
    assert '"'+child+'":"'+donor+'"' in world
assert profiles["transform:44"]["name"] == "랜스 마스터"
assert profiles["transform:179"]["name"] == "랜스 마스터(레드)"
assert profiles["transform:182"]["name"] == "랜스 마스터(블루)"
assert profiles["transform:179"]["color_tint"] == "ff766b"
assert profiles["transform:182"]["color_tint"] == "75aeff"
for variant in ("179","182"):
    assert profiles["transform:"+variant]["shared_visual_policy"] == "same_lance_master_base_source_tinted"
print("PR122_SHARED_VISUAL_LINKS_OK guard=3 male_to_female=2 lance_base=44")
