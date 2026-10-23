#!/usr/bin/env python3
"""Reuse exactly three existing 176 S attack poses; preserve only three new poses.

Usage: python3 preserve_mixed_spear_attack.py REQUEST NEW_3X1_PNG --existing-root CHECKOUT
No image pixels are redrawn, resized, mirrored or interpolated by this compiler.
Existing original AtlasTexture regions/margins remain exact; scale differences
in new artwork are recorded as HOLD for the later quality pass.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

import numpy as np
from PIL import Image

import preserve_generated_clip as common

ROOT = Path(__file__).resolve().parents[3]
SOURCE_REL = Path("assets/actors/eight_direction/original_based/spear_captain/poses-0.png")
SOURCE_SHA = "da13e98e7135e215455ab934668cd5d1d7f06d05f553076510f552da7f0f0ba4"
OLD_POSES = [42, 50, 58]
SEQUENCE = [("reused", 0), ("new", 0), ("new", 1), ("reused", 1), ("new", 2), ("reused", 2)]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def checks_for(image, region, phase, source_kind, sheet):
    x, y, w, h = region
    rgba = np.asarray(image.crop((x, y, x + w, y + h)))
    alpha = rgba[:, :, 3]
    ys, xs = np.nonzero(alpha > 0)
    assert len(xs) and int((alpha > 16).sum()) > 0, "Every real pose must have visible pixels"
    box = [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]
    visible = rgba[box[1]:box[3], box[0]:box[2]].copy()
    visible[visible[:, :, 3] == 0] = 0
    shape = f"{visible.shape[1]}x{visible.shape[0]}:".encode("ascii")
    border = np.zeros(alpha.shape, dtype=bool)
    border[:2] = True
    border[-2:] = True
    border[:, :2] = True
    border[:, -2:] = True
    return {"index": phase, "sheet": sheet, "source_kind": source_kind, "region": region,
            "rgba_sha256": sha(rgba.tobytes()), "normalized_visible_sha256": sha(shape + visible.tobytes()),
            "visible_pixels": int((alpha > 16).sum()), "alpha_bbox_in_region": box,
            "visible_height": box[3] - box[1], "visible_width": box[2] - box[0],
            "border_alpha_pixels": int(((alpha > 16) & border).sum())}


def preserve(request_path, generated_path, existing_root):
    request_path, generated_path, existing_root = Path(request_path), Path(generated_path), Path(existing_root)
    request_bytes = request_path.read_bytes()
    q = json.loads(request_bytes)
    assert (q["key"], q["direction"], q["role"]) == ("transform:176", "S", "attack")
    catalog = json.loads((ROOT / "data/catalog_v19.json").read_text())
    actors = [a for a in catalog["변신"] if str(a["sourceId"]) == "176"]
    assert len(actors) == 1 and actors[0]["grade"] == q["grade"] == "전설" and actors[0]["name"] == q["name"]
    reference = common.local_reference(q["reference"])
    assert sha(reference.read_bytes()) == q["reference_sha256"]
    assert isinstance(q["generation_request"], dict)
    original_path = existing_root / SOURCE_REL
    assert original_path.is_file() and not original_path.is_symlink()
    original_raw = original_path.read_bytes()
    assert sha(original_raw) == SOURCE_SHA, "Pin the actual existing PNG bytes before reuse"
    old_resource = original_path.parent / "SpriteFrames.tres"
    old_provenance = original_path.parent / "provenance.json"
    prov = json.loads(old_provenance.read_text())
    assert prov["target_keys"] == ["transform:176"] and prov["reference"]["sha256"] == q["reference_sha256"]
    old_text = old_resource.read_text()
    entries = re.findall(r'\{"frames": \[[\s\S]*?\], "loop": (?:true|false), "name": &"[^"]+", "speed": [^}]*\}', old_text)
    old_attack = next(x for x in entries if '"name": &"attack_2"' in x)
    assert [int(x) for x in re.findall(r'SubResource\("pose_(\d+)"\)', old_attack)] == OLD_POSES
    reused = []
    for index in OLD_POSES:
        frame = dict(prov["frames"][index])
        assert frame["sheet"] == 0 and frame["direction"] == "S"
        exact = re.search(r'\[sub_resource type="AtlasTexture" id="pose_' + str(index) + r'"\]([\s\S]*?)(?=\n\[|\Z)', old_text).group(1)
        for label in ("region", "margin"):
            actual = [int(x.strip()) for x in re.search(label + r' = Rect2\(([^)]+)\)', exact).group(1).split(",")]
            assert actual == frame[label], "Preserve exact previously connected region and margin"
        reused.append(frame)
    assert generated_path.is_file() and not generated_path.is_symlink()
    generated_raw = generated_path.read_bytes()
    assert generated_raw.startswith(b"\x89PNG\r\n\x1a\n")
    original_image = Image.open(original_path)
    new_image = Image.open(generated_path)
    assert new_image.mode == "RGBA" and new_image.format == "PNG"
    original_image.load()
    new_image.load()
    assert new_image.width % 3 == 0
    w, h = new_image.width // 3, new_image.height
    assert w > 0 and h > 0
    new_regions = [[i * w, 0, w, h] for i in range(3)]
    geometry, checks, sources = {"frames": []}, [], []
    for phase, (kind, ordinal) in enumerate(SEQUENCE):
        if kind == "reused":
            frame = {k: reused[ordinal][k] for k in ("region", "margin")}
            frame["sheet"] = 0
            check = checks_for(original_image, frame["region"], phase, kind, 0)
            assert check["rgba_sha256"] == reused[ordinal]["rgba_sha256"], "Reused rendered RGBA must remain exact"
            sources.append({"phase": phase, "source_kind": "reused", "original_pose_id": OLD_POSES[ordinal],
                            "original_region": frame["region"], "original_margin": frame["margin"],
                            "original_source_anchor": reused[ordinal]["source_anchor"],
                            "rgba_sha256": check["rgba_sha256"]})
        else:
            # Metadata extraction only. Keep the entire new cell and all its pixels.
            frame = {"region": new_regions[ordinal], "margin": [0, 0, 0, 0], "sheet": 1}
            check = checks_for(new_image, frame["region"], phase, kind, 1)
            sources.append({"phase": phase, "source_kind": "new", "new_sheet_cell": ordinal,
                            "region": frame["region"], "rgba_sha256": check["rgba_sha256"]})
        geometry["frames"].append(frame)
        checks.append(check)
    assert len({c["rgba_sha256"] for c in checks}) == 6
    assert len({c["normalized_visible_sha256"] for c in checks}) == 6, "No shifted duplicates or repeated legacy poses"
    folder = ROOT / "assets/actors/eight_direction/legendary_parallel/transform_176/draft001"
    copied = folder / "S-attack-reused-source-v01.png"
    source = folder / "S-attack-source-v01.png"
    resource_path = folder / "S-attack-SpriteFrames.tres"
    record_path = folder / "S-attack-record-v01.json"
    for path in (folder, *folder.parents):
        assert not path.is_symlink()
        if path == ROOT:
            break
    assert not any(p.exists() or p.is_symlink() for p in (copied, source, resource_path, record_path)), "Preserve existing outputs; never redo or overwrite"
    uris = ["res://" + p.relative_to(ROOT).as_posix() for p in (copied, source)]
    indices = [[] for _ in range(8)]
    indices[2] = list(range(6))
    compiled = common.spriteframes(uris, geometry, {"attack": indices})
    compiled_entries = re.findall(r'\{"frames": \[[\s\S]*?\], "loop": (?:true|false), "name": &"[^"]+", "speed": [^}]*\}', compiled)
    selected = next(e for e in compiled_entries if '"name": &"attack_2"' in e)
    assert selected.count('SubResource("pose_') == 6
    resource = compiled.split("animations = [", 1)[0] + "animations = [\n" + selected + "\n]\n"
    resource += ('metadata/twilight_canvas_size = Vector2(256, 256)\n'
                 'metadata/twilight_detailed_completed = false\n'
                 'metadata/twilight_source_visual_status = "HOLD_NOT_REVIEWED"\n'
                 'metadata/twilight_actor_key = "transform:176"\n')
    resource_raw = resource.encode()
    heights = [c["visible_height"] for c in checks if c["source_kind"] == "reused"]
    median_height = float(np.median(heights))
    scale_hold = any(abs(c["visible_height"] / median_height - 1) > .25 for c in checks if c["source_kind"] == "new")
    record = dict(q)
    record.update(schema="pr122-legendary-generated-clip-v1", status="MIXED_REUSED_AND_NEW_DRAFT_NOT_REVIEWED",
                  input_representation="mixed_reuse3_new3_v1", source_grid=[3, 1],
                  source=source.relative_to(ROOT).as_posix(), source_resource_path=uris[1],
                  source_sha256=sha(generated_raw), source_bytes=len(generated_raw),
                  source_files=[{"path": uris[0], "sha256": SOURCE_SHA, "source_kind": "reused", "bytes": len(original_raw)},
                                {"path": uris[1], "sha256": sha(generated_raw), "source_kind": "new", "bytes": len(generated_raw)}],
                  output_spriteframes="res://" + resource_path.relative_to(ROOT).as_posix(),
                  output_spriteframes_sha256=sha(resource_raw), poses=6, new_poses=3, newly_authored_poses=3, reused_poses=3,
                  source_pose_sequence=sources, automatic_checks=checks,
                  reused_source_original_path="res://" + SOURCE_REL.as_posix(), reused_source_sha256=SOURCE_SHA,
                  reused_resource_sha256=sha(old_resource.read_bytes()), reused_provenance_sha256=sha(old_provenance.read_bytes()),
                  original_reused_regions_margins_rgba_unchanged=True, cell_size=[w, h], frame_order=list(range(6)),
                  animation="attack_2", loop=False, compiler_origin=common.COMPILER_ORIGIN,
                  generation_service="image_gen.imagegen", request_file_sha256=sha(request_bytes),
                  generation_request_sha256=sha(json.dumps(q["generation_request"], ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()),
                  source_visual_status="HOLD_NOT_REVIEWED", actual_Main_Player="NOT_RUN",
                  scale_comparison_hold=scale_hold, legacy_median_body_height=median_height,
                  clipped_cell_count=sum(c["border_alpha_pixels"] > 0 for c in checks),
                  hold_reasons=["Mixed-source visual continuity, contact, footing and exact original appearance require later review"] +
                               (["New-source display scale differs from preserved legacy poses; do not approve before repair"] if scale_hold else []) +
                               (["Visible alpha reaches a selected region boundary"] if any(c["border_alpha_pixels"] for c in checks) else []),
                  minimal_checks={"actual_png_exists": "PASS", "six_real_mixed_source_frames_extractable": "PASS",
                                  "three_reused_source_regions_margins_rgba_unchanged": "PASS", "catalog_id_name_grade_match": "PASS",
                                  "original_reference_sha256": "PASS", "six_distinct_rgba_and_visible_frames": "PASS",
                                  "SpriteFrames_actual_Godot_playback": "NOT_RUN"},
                  production_connected=False, required_Godot_4_7_2_full_QA="NOT_RUN", actor_approvals_added=0,
                  final_motion_approvals_added=0)
    folder.mkdir(parents=True, exist_ok=True)
    for path, raw in ((copied, original_raw), (source, generated_raw), (resource_path, resource_raw),
                      (record_path, (json.dumps(record, ensure_ascii=False, indent=2) + "\n").encode())):
        with path.open("xb") as output:
            output.write(raw)
    assert sha(copied.read_bytes()) == SOURCE_SHA and sha(source.read_bytes()) == sha(generated_raw)
    return {"key": "transform:176", "direction": "S", "role": "attack", "poses": 6, "new_poses": 3,
            "reused_poses": 3, "record": record_path.relative_to(ROOT).as_posix(),
            "scale_hold": scale_hold, "status": "DRAFT_FINAL_APPROVAL_HOLD", "actor_approvals_added": 0}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("request", type=Path)
    parser.add_argument("generated_png", type=Path)
    parser.add_argument("--existing-root", type=Path, default=ROOT)
    args = parser.parse_args()
    print(json.dumps(preserve(args.request, args.generated_png, args.existing_root), ensure_ascii=False))
