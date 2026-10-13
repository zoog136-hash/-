#!/usr/bin/env python3
"""Resolve each unfinished PR100 actor to its existing, untouched image.

This is a source/authoring plan, not a completion ledger. Atlas rectangles are
part of the source identity. A project fallback is never labelled as a verified
external original or silently substituted for a different character.
"""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

from PIL import Image

import build_animation_expansion as expansion


def read(path):
    return json.loads(path.read_text())


def plan(root, unfinished):
    transforms = {"transform:" + row["sourceId"]: row for row in read(root / "data/catalog_v19.json")["변신"]}
    monsters = {"monster:" + row["name"]: row for row in expansion.monsters(root)}
    families = read(root / "data/visuals/runtime_manifest.json")["monsters"]
    verified = {row["game_name"]: row for row in read(root / "data/l1j/live_visual_bindings.json")["monsters"]}
    atlases = read(root / "data/monsters/art_atlases.json")
    presentation = read(root / "data/animation_presentation.json")["transforms"]
    targets = []
    for item in unfinished:
        key = item["key"]
        source = {}
        if key.startswith("transform:"):
            actor = transforms[key]
            source = {"path": actor["image_path"], "kind": "existing_catalog_portrait",
                      "catalog_source_id": actor["sourceId"], "source_url": actor.get("sourceImageUrl", "")}
            appearance = {"body": presentation[actor["sourceId"]]["body"], "source_options": actor.get("sourceOptions", [])}
        else:
            actor = monsters[key]
            # Keep the production monster_texture order, including the rule
            # excluding bosses from normal-monster family aliases.
            family = families.get(actor["name"], {}) if item["group"] != "boss" else {}
            original = verified.get(family.get("verified_game_name", ""), {})
            if original:
                source = {"path": original["texture"], "kind": "existing_verified_portrait", "review": original["review"]}
            elif family.get("path"):
                source = {"path": family["path"], "kind": "existing_family_portrait", "family_binding": family}
            elif actor["name"] in verified:
                original = verified[actor["name"]]
                source = {"path": original["texture"], "kind": "existing_verified_portrait", "review": original["review"]}
            else:
                visual = actor["visual"]
                plate = atlases[int(visual["atlas"])]
                source = {"path": plate["path"], "region": plate["rects"][int(visual["cell"])],
                          "kind": "existing_project_atlas", "atlas": visual["atlas"], "cell": visual["cell"],
                          "identity_limit": "Existing project artwork, not verified external original game art"}
            appearance = {"visual": actor.get("visual", {}), "animation_profile": actor.get("animation_profile", {}),
                          "attack_type": actor.get("attack_type", "melee"), "visual_height": actor.get("visual_height", 86)}
        path = source["path"]
        if not path.startswith("res://assets/") or ".." in Path(path).parts:
            raise ValueError("Unsafe original path: " + path)
        local = root / path.removeprefix("res://")
        source["sha256"] = hashlib.sha256(local.read_bytes()).hexdigest()
        with Image.open(local) as image:
            source["image_size"] = list(image.size)
            if "region" in source:
                x, y, w, h = source["region"]
                if min(x, y) < 0 or min(w, h) <= 0 or x + w > image.width or y + h > image.height:
                    raise ValueError("Original atlas region is out of bounds: " + key)
                source["region_rgba_sha256"] = hashlib.sha256(image.convert("RGBA").crop((x, y, x+w, y+h)).tobytes()).hexdigest()
        targets.append({"key": key, "name": item["name"], "group": item["group"], "reference": source,
                        "presentation_to_preserve": appearance})
    return {"schema": 1, "basis_commit": "e66e861a318c2f6f42d1ce33519ae527e12be59c",
            "scope": "Authoring inputs only; no motion completion or original asset delivery claim",
            "policy": "Keep source bytes unchanged. Author each motion from its exact reference. Preserve silhouette, palette, face, equipment and weapon. Share only where source and presentation match. Validate in production Main before counting completion.",
            "targets": targets}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--unfinished", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = plan(args.root.resolve(), read(args.unfinished)["identities"])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"targets": len(result["targets"]), "groups": dict(Counter(row["group"] for row in result["targets"])),
                      "sources": dict(Counter(row["reference"]["kind"] for row in result["targets"])),
                      "unique_images_or_regions": len({(row["reference"]["sha256"], tuple(row["reference"].get("region", []))) for row in result["targets"]})}))


if __name__ == "__main__":
    main()
