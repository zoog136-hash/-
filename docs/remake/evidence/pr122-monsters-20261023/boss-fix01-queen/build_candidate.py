"""Stage seven corrected RUN views; preserve all prior sources and approvals.

Strict component/whole-pixel checks run twice (2048 and density-normalized).
Invisible flight ground registration changes metadata only, never image pixels.
"""
import copy
import hashlib
import json
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
FOLDER = ROOT / "assets/actors/eight_direction/monster_boss_repair/ice_queen/r001"
sys.path.insert(0, str(ROOT / "tools"))
import import_original_based_motion as core

SELECTED = {"E": "v01", "SE": "v02", "S": "v02", "SW": "v03", "W": "v02", "NW": "v02", "NE": "v02"}
ORDER = [0, 2, 4, 1, 3, 5]
REFERENCE_HEIGHT = 140.0
DISPLAY_HEIGHT = 86.0
# Manually inspected crown apex and actual contact sole points in source pixels.
# These exclude the staff orb and the high feather/wing silhouette.
# Each pair is physical source slot0 (RIGHT contact), slot1 (LEFT contact).
LANDMARKS = {
    "E": [([395, 24], [469, 409]), ([1004, 24], [1083, 409])],
    "SE": [([431, 52], [499, 373]), ([1045, 65], [1105, 379])],
    "S": [([343, 64], [341, 433]), ([909, 64], [902, 432])],
    "SW": [([321, 65], [242, 383]), ([975, 63], [905, 387])],
    "W": [([320, 35], [255, 366]), ([980, 44], [906, 364])],
    "NW": [([246, 59], [295, 413]), ([824, 70], [811, 409])],
    "NE": [([409, 64], [485, 412]), ([994, 64], [1070, 403])],
}


def rel(path):
    return path.relative_to(ROOT).as_posix()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def put(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        assert path.read_bytes() == data, "Immutable revision already exists: " + str(path)
    else:
        path.write_bytes(data)


def jb(obj):
    return (json.dumps(obj, ensure_ascii=False, indent=2) + "\n").encode()


tracks, checks, measurements = [], [], {}
for direction, version in SELECTED.items():
    source = OUT / "raw" / f"queen-{direction}-run6-{version}.png"
    raw_geometry = core.analyze(source, 6, [0, 1], directions_axis="phase_grid2", canvas_size=2048, directions=[direction])
    core.require_complete_pose_regions(source, raw_geometry)
    contacts = LANDMARKS[direction]
    body_heights = [sole[1] - crown[1] for crown, sole in contacts]
    body_height = statistics.median(body_heights)
    canvas = round(body_height * 256.0 / REFERENCE_HEIGHT / 8.0) * 8
    geometry = core.analyze(source, 6, [0, 1], directions_axis="phase_grid2", canvas_size=canvas, directions=[direction])
    core.require_complete_pose_regions(source, geometry)
    assert [f["rgba_sha256"] for f in geometry["frames"]] == [f["rgba_sha256"] for f in raw_geometry["frames"]]
    measurements[direction] = {
        "method": "manual_private_visual_crown_apex_to_actual_contact_boot_sole; staff/wing tips excluded",
        "landmark_uncertainty_source_pixels": 3,
        "contact_source_slots": [0, 1],
        "contacts": [{"source_slot": i, "crown_apex_xy": crown, "contact_sole_xy": sole, "crown_to_sole_height": height}
                     for i, ((crown, sole), height) in enumerate(zip(contacts, body_heights))],
        "median_crown_to_sole_height": body_height,
        "source_full_silhouette_height_for_comparison_only": raw_geometry["neutral_height"],
        "logical_canvas": [canvas, canvas],
        "target_reference_height": REFERENCE_HEIGHT,
        "expected_display_crown_to_sole_height": body_height * 256.0 / canvas * DISPLAY_HEIGHT / REFERENCE_HEIGHT,
    }
    # Both support poses keep the actual reviewed sole baseline; in the flight
    # poses register an invisible plane below the soles rather than clamping
    # every airborne foot to ground. All source rectangles remain untouched.
    registered = copy.deepcopy(geometry)
    registration = []
    for slot, frame in enumerate(registered["frames"]):
        x, y, width, height = frame["region"]
        if slot in [0, 1]:
            ground_y = contacts[slot][1][1]
            kind = "manually_reviewed_contact_sole"
        else:
            sole_y = y + height - 4  # visible alpha bound, checked against source boots
            ground_y = sole_y + (12 if slot in [4, 5] else 0)
            kind = "support_plane_from_lowest_visible_bound_estimate_NOT_anatomical_approval" if slot in [2, 3] else "invisible_flight_plane_12px_below_visible_pose_bound_NOT_anatomical_sole_proof"
        source_x = frame["source_anchor"][0]
        mx, my = canvas // 2 - (source_x - x), canvas * 5 // 8 - (ground_y - y)
        assert min(mx, my) >= 0 and mx + width <= canvas and my + height <= canvas, "Registered pose would clip"
        frame["source_anchor"] = [source_x, ground_y]
        frame["margin"] = [mx, my, canvas - width, canvas - height]
        frame["source_slot"] = slot
        frame["ground_registration"] = kind
        registration.append({"source_slot": slot, "ground_anchor_xy": frame["source_anchor"], "method": kind})
    core.require_complete_pose_regions(source, registered)
    registered["frames"] = [registered["frames"][slot] for slot in ORDER]
    for phase, frame in enumerate(registered["frames"]):
        frame["row"] = phase
    registered["registration_method"] = "metadata_only_manual_contact0_3_sole_plus_estimated_other_support_and_flight_planes; source rectangles/RGBA unchanged"
    registered["flight_plane_visual_approval"] = "HOLD_for_independent_moving_world_footplant_QA"
    texture = FOLDER / f"{direction}-run.png"
    put(texture, source.read_bytes())
    track = {"direction": direction, "role": "run", "animation": "run_" + str(core.DIRECTIONS.index(direction)),
             "source": rel(source), "source_sha256": sha(source), "texture": rel(texture), "geometry": registered,
             "source_phase_order": ORDER, "body_scale_measurement": measurements[direction],
             "visual_quality": "HOLD_final_mythic_QA; corrected_contact_exchange_observed",
             "source_anchors": registration}
    tracks.append(track)
    checks.append({"direction": direction, "source": rel(source), "source_sha256": sha(source),
                   "strict_2048": "PASS", "strict_density_normalized_canvas": "PASS",
                   "all_source_visible_pixels_covered": "PASS", "RGBA_frames_unchanged": "PASS",
                   "registered_canvas_bounds": "PASS", "logical_canvas": [canvas, canvas],
                   "distinct_pixel_frames": 6, "body_measurement": measurements[direction],
                   "raw_geometry": raw_geometry, "unregistered_normalized_geometry": geometry,
                   "visual_approval": "HOLD"})

frames = FOLDER / "SpriteFrames.tres"
lines = [f'[gd_resource type="SpriteFrames" load_steps={sum(len(t["geometry"]["frames"]) for t in tracks) + len(tracks) + 1} format=3]']
for i, track in enumerate(tracks):
    lines += ["", f'[ext_resource type="Texture2D" path="res://{track["texture"]}" id="{i+1}"]']
animations = []
for i, track in enumerate(tracks):
    for j, frame in enumerate(track["geometry"]["frames"]):
        lines += ["", f'[sub_resource type="AtlasTexture" id="pose_{i}_{j}"]', f'atlas = ExtResource("{i+1}")',
                  'region = Rect2(%s)' % ', '.join(map(str, frame["region"])),
                  'margin = Rect2(%s)' % ', '.join(map(str, frame["margin"])), 'filter_clip = true']
    poses = ',\n'.join('{"duration": 1.0, "texture": SubResource("pose_%d_%d")}' % (i,j) for j in range(6))
    animations.append('{"frames": [%s], "loop": true, "name": &"%s", "speed": 12.5}' % (poses, track["animation"]))
lines += ["", "[resource]", 'animations = [\n' + ',\n'.join(animations) + '\n]',
          'metadata/twilight_canvas_size = Vector2(256, 256)',
          'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', ""]
put(frames, '\n'.join(lines).encode())
scale = DISPLAY_HEIGHT / REFERENCE_HEIGHT
profile = FOLDER / "NativeMotionProfile.tres"
lines = ['[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', "",
         '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', "", "[resource]",
         'script = ExtResource("1")', 'profile_id = "monster:얼음 여왕"', f'frames_path = "res://{rel(frames)}"',
         'layout = "directional8"', 'movement_fps = 12.5', 'reference_speed = 210.0',
         f'pixel_scale = {scale:.12f}', f'sprite_offset = Vector2(0, {-32*scale:.12f})',
         'authored_motion_weight = 0.0', 'hit_recoil = 0.0', 'embedded_shadow = false',
         'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', ""]
put(profile, '\n'.join(lines).encode())
required = [f"{role}_{i}" for role in ["idle", "run", "attack", "hit"] for i in range(8)] + ["death_2"]
have = {t["animation"] for t in tracks}
held_sources = [
    {"source": rel(OUT/"raw/queen-NE-run6-v01.png"), "reason": "Strict geometry: a pose rectangle includes another body"},
    {"source": rel(OUT/"raw/queen-SW-run6-v02.png"), "reason": "Actual view faces right/E instead of SW; v03 supersedes without deleting"},
    {"source": rel(OUT/"raw/queen-N-run6-v02.png"), "reason": "Rear-view bare slit on viewer-left contradicts anatomical RIGHT"},
    {"source": rel(OUT/"raw/queen-N-run6-v03.png"), "reason": "Top row slit corrected but middle-row leg/slit handedness changes; not selected"},
    {"source": rel(OUT/"raw/queen-N-run6-v04.png"), "reason": "Targeted edit failed strict geometry: a pose rectangle includes another body"},
]
actor = {"kind": "boss", "quality_tier": "mythic_transform", "frames": "res://"+rel(frames), "frames_sha256": sha(frames),
         "native_profile": "res://"+rel(profile), "native_profile_sha256": sha(profile),
         "production_connected": False, "detailed_completed": False, "native_track_count": len(tracks),
         "native_pose_count": sum(len(t["geometry"]["frames"]) for t in tracks),
         "missing_required_tracks": [x for x in required if x not in have],
         "quality_review": "HOLD: final independent support/contact/camera/handedness/crown palette/game-speed QA; no approval or default activation",
         "tracks": tracks, "held_directions": [{"direction": "N", "reason": "three fresh attempts retained; handedness or strict region failure"}],
         "held_sources": held_sources,
         "sizing": {"method": "per_direction_logical_canvas_from_manual_crown_to_contact_sole_height",
                    "reference_height": REFERENCE_HEIGHT, "target_display_height": DISPLAY_HEIGHT,
                    "ONE_shared_pixel_scale": scale, "canvas256_metadata": True,
                    "no_pixel_resampling": True, "measurements": measurements}}
candidate = {"schema": "pr122-boss-repair-candidate-v1", "batch": rel(OUT), "actors": {"monster:얼음 여왕": actor},
             "new_approvals": 0, "default_catalog_switches": 0, "existing_approved_assets_preserved": True,
             "existing_RUN_48_poses_preserved": True, "new_WALK": 0, "existing_WALK_and_DEATH_preserved": True,
             "new_raw_sources": len(list((OUT/"raw").glob('*.png'))), "held_source_count": len(held_sources),
             "new_selected_clips": len(tracks), "new_selected_poses": actor["native_pose_count"]}
put(OUT/"candidate.json", jb(candidate))
put(OUT/"checks/body-scale-measurements.json", jb(measurements))
put(OUT/"checks/selected-source-checks.json", jb(checks))
print(json.dumps({"selected_RUN_clips": len(tracks), "selected_poses": actor["native_pose_count"],
                  "new_raw_sources": candidate["new_raw_sources"], "held_sources": len(held_sources),
                  "logical_canvases": {k:v['logical_canvas'][0] for k,v in measurements.items()},
                  "shared_scale": scale, "missing_required_tracks": len(actor["missing_required_tracks"]), "new_approvals": 0}))
