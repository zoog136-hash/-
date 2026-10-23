#!/usr/bin/env python3
"""Reuse an actor/direction IDLE's exact guards 0/5; author action phases 1..4.

Only ATTACK/HIT drafts, excluding transform:176 (legacy reuse takes priority).
Existing source art remains HOLD; reusing it adds no approval. PNG pixels and
old AtlasTexture regions/margins are never changed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image

import preserve_generated_clip as common
import preserve_mixed_legacy_clip as mixed

ROOT = Path(__file__).resolve().parents[3]
PREFIX = Path("assets/actors/eight_direction/legendary_parallel")


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read_guards(existing_root, key, direction):
    existing_root = Path(existing_root).resolve()
    assert re.fullmatch(r"transform:[0-9]+", key) and key != "transform:176"
    assert direction in common.DIRECTIONS
    actor_id = key.split(":")[1]
    record_path = existing_root / PREFIX / f"transform_{actor_id}/draft001/{direction}-idle-record-v01.json"
    assert record_path.is_file() and not record_path.is_symlink()
    record_raw = record_path.read_bytes()
    record = json.loads(record_raw)
    assert (record["key"], record["direction"], record["role"]) == (key, direction, "idle")
    frames_path = mixed.resolve_resource(existing_root, record["output_spriteframes"])
    resource_raw = frames_path.read_bytes()
    assert sha(resource_raw) == record["output_spriteframes_sha256"]
    text = resource_raw.decode("utf-8")
    animation = f"idle_{common.DIRECTIONS.index(direction)}"
    entry = next(e for e in re.findall(mixed.ANIMATION_RE, text) if f'"name": &"{animation}"' in e)
    pose_ids = [int(x) for x in re.findall(r'SubResource\("pose_(\d+)"\)', entry)]
    assert len(pose_ids) == 6
    external = {identifier: uri for uri, identifier in re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text)}
    expected_sources = {s["path"]: s["sha256"] for s in record.get("source_files", [])}
    expected_sources.setdefault("res://" + record["source"], record["source_sha256"])
    frames, sources = [], {}
    for old_phase, action_phase in ((0, 0), (5, 5)):
        index = pose_ids[old_phase]
        block = re.search(r'\[sub_resource type="AtlasTexture" id="pose_' + str(index) + r'"\]([\s\S]*?)(?=\n\[|\Z)', text).group(1)
        uri = external[re.search(r'atlas = ExtResource\("([^"]+)"\)', block).group(1)]
        assert uri.startswith("res://" + PREFIX.as_posix() + "/")
        path = mixed.resolve_resource(existing_root, uri)
        raw = path.read_bytes()
        assert sha(raw) == expected_sources[uri]
        frame = {"idle_phase": old_phase, "action_phase": action_phase, "original_pose_id": index, "source_path": uri}
        for label in ("region", "margin"):
            frame[label] = [int(x.strip()) for x in re.search(label + r' = Rect2\(([^)]+)\)', block).group(1).split(",")]
        with Image.open(path) as image:
            check = mixed.frame_check(image, frame["region"], action_phase, "reused_idle_guard")
        original_checks = [c for c in record["automatic_checks"] if int(c["index"]) == old_phase]
        assert len(original_checks) == 1 and check["rgba_sha256"] == original_checks[0]["rgba_sha256"]
        frame["rgba_sha256"] = check["rgba_sha256"]
        sources[uri] = {"path": uri, "sha256": sha(raw), "bytes": len(raw)}
        frames.append(frame)
    return {"key": key, "direction": direction, "idle_record": "res://" + record_path.relative_to(existing_root).as_posix(),
            "idle_record_sha256": sha(record_raw), "idle_SpriteFrames": record["output_spriteframes"],
            "idle_SpriteFrames_sha256": sha(resource_raw), "source_visual_status": record["source_visual_status"],
            "reference": record["reference"], "reference_sha256": record["reference_sha256"],
            "source_files": list(sources.values()), "guards": frames,
            "reused_poses": 2, "newly_authored_poses": 4, "source_quality_approval_inherited": False}


def preserve(request_path, generated_png, existing_root):
    request_path, generated_png, existing_root = Path(request_path), Path(generated_png), Path(existing_root).resolve()
    request_raw = request_path.read_bytes()
    q = json.loads(request_raw)
    assert q["role"] in ("attack", "hit") and q["key"] != "transform:176"
    plan = read_guards(existing_root, q["key"], q["direction"])
    assert plan == q["draft_guard_reuse"], "The saved source guards changed; never substitute another draft"
    idle_record = json.loads((existing_root / plan["idle_record"].removeprefix("res://")).read_bytes())
    actor_id = q["key"].split(":")[1]
    actor = next(a for a in json.loads((ROOT / "data/catalog_v19.json").read_text())["변신"] if str(a["sourceId"]) == actor_id)
    assert actor["grade"] == q["grade"] == "전설" and actor["name"] == q["name"]
    assert sha(common.local_reference(q["reference"]).read_bytes()) == q["reference_sha256"]
    assert generated_png.is_file() and not generated_png.is_symlink()
    raw = generated_png.read_bytes()
    assert raw.startswith(b"\x89PNG\r\n\x1a\n")
    image = Image.open(generated_png)
    assert image.format == "PNG" and image.mode == "RGBA" and image.width >= 2 and image.height >= 2
    image.load()
    # Integer partitions preserve every source pixel even for odd dimensions.
    xs, ys = [0, image.width // 2, image.width], [0, image.height // 2, image.height]
    folder = ROOT / PREFIX / f"transform_{actor_id}/draft001"
    stem = q["direction"] + "-" + q["role"]
    source_path, frames_path, record_path = (folder / (stem + suffix) for suffix in ("-source-v01.png", "-SpriteFrames.tres", "-record-v01.json"))
    assert not any(p.exists() or p.is_symlink() for p in (source_path, frames_path, record_path)), "Already produced: preserve and skip, never redo"
    for p in (folder, *folder.parents):
        assert not p.is_symlink()
        if p == ROOT:
            break
    sources, indices, images, preserve_inputs = [], {}, {}, []
    for source in plan["source_files"]:
        uri = source["path"]
        old_path = mixed.resolve_resource(existing_root, uri)
        old_raw = old_path.read_bytes()
        assert sha(old_raw) == source["sha256"]
        local = ROOT / uri.removeprefix("res://")
        if local.exists():
            assert not local.is_symlink() and local.read_bytes() == old_raw
        else:
            preserve_inputs.append((local, old_raw))
        indices[uri] = len(sources)
        sources.append(dict(source, source_kind="reused_idle_guard"))
        images[uri] = Image.open(old_path)
    new_sheet = len(sources)
    new_uri = "res://" + source_path.relative_to(ROOT).as_posix()
    sources.append({"path": new_uri, "sha256": sha(raw), "bytes": len(raw), "source_kind": "new"})
    geometry, checks, sequence = {"frames": []}, [], []
    for phase in range(6):
        if phase in (0, 5):
            guard = plan["guards"][0 if phase == 0 else 1]
            frame = {"region": guard["region"], "margin": guard["margin"], "sheet": indices[guard["source_path"]]}
            check = mixed.frame_check(images[guard["source_path"]], frame["region"], phase, "reused_idle_guard")
            assert check["rgba_sha256"] == guard["rgba_sha256"]
            sequence.append({"phase": phase, "source_kind": "reused_idle_guard", **guard})
        else:
            cell = phase - 1
            c, r = cell % 2, cell // 2
            region = [xs[c], ys[r], xs[c + 1] - xs[c], ys[r + 1] - ys[r]]
            frame = {"region": region, "margin": [0, 0, 0, 0], "sheet": new_sheet}
            check = mixed.frame_check(image, region, phase, "new")
            sequence.append({"phase": phase, "source_kind": "new", "new_sheet_cell": cell, "region": region})
        geometry["frames"].append(frame)
        checks.append(check)
    assert len({c["rgba_sha256"] for c in checks}) == 6 and len({c["normalized_visible_sha256"] for c in checks}) == 6
    role, direction = q["role"], q["direction"]
    groups = [[] for _ in common.DIRECTIONS]
    groups[common.DIRECTIONS.index(direction)] = list(range(6))
    compiled = common.spriteframes([s["path"] for s in sources], geometry, {role: groups})
    animation = f"{role}_{common.DIRECTIONS.index(direction)}"
    selected = next(e for e in re.findall(mixed.ANIMATION_RE, compiled) if f'"name": &"{animation}"' in e)
    assert selected.count('SubResource("pose_') == 6 and '"loop": false' in selected
    resource = compiled.split("animations = [", 1)[0] + "animations = [\n" + selected + "\n]\n"
    resource += 'metadata/twilight_canvas_size = Vector2(256, 256)\nmetadata/twilight_detailed_completed = false\nmetadata/twilight_source_visual_status = "HOLD_NOT_REVIEWED"\n'
    resource_raw = resource.encode()
    old_heights = [c["visible_height"] for c in checks if c["source_kind"] == "reused_idle_guard"]
    basis = sum(old_heights) / len(old_heights)
    scale_hold = any(abs(c["visible_height"] / basis - 1.0) > .25 for c in checks if c["source_kind"] == "new")
    cell_match = all(f["region"][2:] == plan["guards"][0]["region"][2:] for f in geometry["frames"])
    record = dict(q)
    record.update(schema="pr122-legendary-generated-clip-v1", input_representation="mixed_draft_guard_reuse_v1",
                  status="MIXED_DRAFT_GUARD_REUSED_NOT_REVIEWED", poses=6, newly_authored_poses=4, new_poses=4, reused_poses=2,
                  reused_legacy_poses=0, reused_prior_draft_poses=2,
                  source=source_path.relative_to(ROOT).as_posix(), source_resource_path=new_uri,
                  source_sha256=sha(raw), source_bytes=len(raw), source_files=sources, source_grid=[2, 2],
                  cell_size=[image.width // 2, image.height // 2], source_pose_sequence=sequence, frame_order=list(range(6)),
                  output_spriteframes="res://" + frames_path.relative_to(ROOT).as_posix(), output_spriteframes_sha256=sha(resource_raw),
                  automatic_checks=checks, original_reused_regions_margins_rgba_unchanged=True,
                  animation=animation, loop=False, animation_duration_seconds=common.SECONDS[role],
                  attack_contact_frame=3 if role == "attack" else None,
                  source_visual_status="HOLD_NOT_REVIEWED", reused_guard_quality_status=plan["source_visual_status"],
                  reused_guard_hold_reasons=idle_record.get("hold_reasons", []),
                  hold_reasons=["Reused IDLE guards remain unapproved; attack/hit transition, source identity, camera and registration require later review"] +
                               (["New-source body scale differs; no PNG resizing performed"] if scale_hold else []) +
                               (["New cell sizes differ from preserved guard cells; keep exact PNG bytes"] if not cell_match else []) +
                               (["Visible alpha reaches a selected cell edge"] if any(c["border_alpha_pixels"] for c in checks) else []),
                  scale_comparison_hold=scale_hold, cell_size_match=cell_match,
                  clipped_cell_count=sum(c["border_alpha_pixels"] > 0 for c in checks),
                  minimal_checks={"actual_png_exists": "PASS", "six_real_mixed_frames_extractable": "PASS",
                                  "reused_idle_guards_regions_margins_rgba_exact": "PASS", "catalog_id_name_grade_match": "PASS",
                                  "original_reference_sha256": "PASS", "six_distinct_rgba_and_visible_frames": "PASS",
                                  "SpriteFrames_actual_Godot_playback": "NOT_RUN"},
                  compiler_origin=common.COMPILER_ORIGIN, request_file_sha256=sha(request_raw), generation_service="image_gen.imagegen",
                  generation_request_sha256=sha(json.dumps(q["generation_request"], ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()),
                  production_connected=False, actual_Main_Player="NOT_RUN", required_Godot_4_7_2_full_QA="NOT_RUN",
                  final_motion_approvals_added=0, actor_approvals_added=0)
    folder.mkdir(parents=True, exist_ok=True)
    for path, data in preserve_inputs + [(source_path, raw), (frames_path, resource_raw), (record_path, (json.dumps(record, ensure_ascii=False, indent=2) + "\n").encode())]:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("xb") as handle:
            handle.write(data)
    return {"key": q["key"], "direction": direction, "role": role, "poses": 6, "newly_authored_poses": 4,
            "reused_poses": 2, "record": record_path.relative_to(ROOT).as_posix(), "actor_approvals_added": 0}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("request", type=Path)
    parser.add_argument("generated_png", type=Path)
    parser.add_argument("--existing-root", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(preserve(args.request, args.generated_png, args.existing_root), ensure_ascii=False))
