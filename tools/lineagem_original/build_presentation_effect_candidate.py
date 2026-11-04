"""Build opt-in effect inspection candidates from exact private SP2/SPR inputs.

The existing SP2 geometry/RLE and compositor remain unverified M hypotheses.
Original SPR action IDs/ticks/FPS are retained; one-shot usage is a local choice.
"""
import argparse
import gzip
import hashlib
import json
import shutil
from pathlib import Path
import zipfile
import zlib

import original_spr
import original_sp2


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n")


def build(inventory_zip, source_roots, spr_root, settings, output):
    if output.exists():
        raise FileExistsError(output)
    if inventory_zip.suffix == ".json":
        index = json.loads(inventory_zip.read_text())
    else:
        with zipfile.ZipFile(inventory_zip) as archive:
            index = json.loads(gzip.decompress(archive.read("inventory/id_to_archive.json.gz")))
    declarations = original_spr.read(spr_root.rglob("*.spr"))
    expected = {a["name"]: a for sid in (24941, 24942, 24943, 29044, 29045)
                for a in index[str(sid)]["assets"]}
    decoded = {}
    source_proof = []
    for name, record in expected.items():
        matches = [root / name for root in source_roots if (root / name).is_file()]
        if len(matches) != 1:
            raise ValueError(f"Expected one received exact input: {name}")
        raw = matches[0].read_bytes()
        if len(raw) != record["size"] or f"{zlib.crc32(raw):08x}" != record["crc32"]:
            raise ValueError(f"Historical input CRC/size mismatch: {name}")
        decoded[name] = original_sp2.parse(raw)
        source_proof.append({"member": name, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})
    output.mkdir(parents=True)
    (output / "pixels").mkdir()
    (output / "models").mkdir()
    (output / "source_settings").mkdir()
    for name in ("OptimizedTerritoryView.json", "ClientOptimizeTerritoryConditionType.json",
                 "EffectSpriteSimplify.json", "UIFlashEffectHideList.json"):
        shutil.copy2(settings / name, output / "source_settings" / name)
    (output / "README.txt").write_text(
        "TWILIGHT PR233 presentation effect candidate v1\n\n"
        "This is the APPLY pack, not the original-source backup. Extract this ZIP to a private folder.\n"
        "Menu > Settings > source region settings: choose its source_settings folder.\n"
        "Then in the effect candidate section choose the extracted root folder.\n"
        "Preview full/small with the existing detail selection. Choose source action0 or3 explicitly.\n"
        "The optional per-effect runtime switch is OFF by default and applies only to24941/29044.\n"
        "Saving preferences is atomic; this does not change character saves or grant anything.\n\n"
        "All source ticks/FPS and declared attachments are retained. RLE geometry, alpha/blending,\n"
        "one-shot use, direction mapping and placement are TWILIGHT compatibility hypotheses.\n"
        "This is NOT certified M engine/render/trigger equivalence. Native geometry/condition\n"
        "automation and user-defined game regions remain separate. No engine/APK is included.\n",
        encoding="utf-8")
    cached = {}
    for action_id in (0, 3):
        records = {}
        for sid in (24941, 29044):
            body, actions = original_spr.resolve(declarations, sid)
            action = actions[action_id]
            if action["fps"] is None or action["errors"]:
                raise ValueError("Exact SPR timing required")
            refs = original_spr.resolve_references(declarations, sid)
            clothes = [target for ref in refs.get("clothes", []) for target in ref["targets"]]
            expected_clothes = [24942, 24943] if sid == 24941 else [29045]
            if clothes != expected_clothes:
                raise ValueError("Literal source attachment set changed")
            attrs = lambda layer: [d["body"] for d in declarations[layer][0].directives if d["code"] == 104]
            directions = []
            for direction in range(8):
                frames = []
                for group, frame, ticks in action["tokens"]:
                    chunk, bit = original_spr.frame_address(group, direction, action["declared_flag"])
                    layers = []
                    for layer in [body, *clothes]:
                        key = (layer, chunk, bit, frame)
                        if key not in cached:
                            palette, mask, slots, _ = decoded[f"Sprite/{layer}-{chunk}.sp2"]
                            bits = [i for i in range(8) if mask & (1 << i)]
                            if bit not in bits:
                                raise ValueError("Candidate source slot unavailable")
                            frames_raw, blocks = slots[bits.index(bit)]
                            image, offset = original_sp2.render(palette, frames_raw, blocks, frame)
                            relative = f"pixels/{layer}-{chunk}-{bit}-{frame}.png"
                            image.save(output / relative)
                            cached[key] = {"path": relative, "offset": list(offset), "layer_id": layer,
                                           "pixel_size": list(image.size), "source_bounds": frames_raw[frame][0],
                                           "source_attributes": attrs(layer), "blend_status": "unverified"}
                        layers.append(cached[key])
                    frames.append({"duration": ticks / action["fps"], "source_ticks": ticks,
                                   "source_group": group, "physical_group": chunk, "stored_direction_bit": bit,
                                   "source_frame": frame, "layers": layers[:1], "effect_layers": layers[1:]})
                directions.append(frames)
            model = {"source_sprite_id": sid, "body_id": body, "source_attributes": attrs(body),
                     "one_shot_overlay": True, "source_missing_attachments": [],
                     "pixel_interpretation": "candidate_existing_RLE_geometry; native_M_equivalence_unverified",
                     "local_usage": "Explicit user-selected action shown once; native trigger/loop semantics unverified",
                     "tracks": {"idle": {"fps": action["fps"], "source_action_id": action_id,
                                         "source_action": action["name"], "source_sprite_id": sid,
                                         "source_raw_body": action["raw_body"],
                                         "source_timing_provenance": action["fps_provenance"],
                                         "static_pending_timing": False, "timing_issues": [],
                                         "directions": directions, "loop": False}}}
            relative = f"models/{sid}-action{action_id}.json"
            write_json(output / relative, model)
            records[f"overlay:{sid}"] = {"manifest": relative}
        write_json(output / f"action{action_id}.json", {
            "schema": 1, "mode": "literal_body_shadow_inspection_only", "production_ready": False,
            "source_snapshot": "received_M_source_identity; current523_payload_proof_separate",
            "records": records, "M_visual_equivalence_verified": False})
    files = [{"path": str(p.relative_to(output)), "bytes": p.stat().st_size,
              "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
             for p in sorted(output.rglob("*")) if p.is_file()]
    write_json(output / "presentation_effects.json", {
        "schema": 1, "kind": "twilight-presentation-effect-candidate", "files": files,
        "actions": {"0": "action0.json", "3": "action3.json"},
        "qualification": "TWILIGHT opt-in geometry/blend/one-shot candidate; not recovered M renderer",
        "source_spr": [{"member": p.name, "bytes": p.stat().st_size,
                        "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                       for p in sorted(spr_root.rglob("*.spr"))],
        "source_inputs": source_proof, "native_M_pixel_or_trigger_certified": False})
    print(json.dumps({"candidate_models": 4, "source_SP2": len(decoded), "pixel_files": len(cached),
                      "files_hashed": len(files), "native_M_equivalence_verified": False}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--source", type=Path, action="append", required=True)
    parser.add_argument("--spr", type=Path, required=True)
    parser.add_argument("--settings", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    build(args.inventory, args.source, args.spr, args.settings, args.output)
