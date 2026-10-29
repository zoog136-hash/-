#!/usr/bin/env python3
"""Install individually pixel-reviewed transformation bodies from the pinned input.

The package decoder is an offline data parser, never a source game executable.
Original art remains local: do not publish it without separate authorization.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import zipfile

ARCHIVE_SHA = "fcc4daa36165d5046275a1cb11f7a6bf9a9e4bac67571a3a861abdfd6f8f8d4c"
HEADINGS = [3, 4, 5, 6, 7, 0, 1, 2]  # E SE S SW W NW N NE
ACTIONS = {"idle": 3, "walk": 0, "attack": 1, "hit": 2, "death": 8, "cast": 18, "special": 30}
ALIASES = {"run": "walk", "turn": "idle", "recovery": "attack", "corpse": "death", "ranged_attack": "attack", "float": "idle", "energy": "idle", "equip": "idle", "unequip": "idle", "activate": "idle", "summon": "idle", "despawn": "death"}

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded

REVIEWS = [
    ("7", "바포메트", "PB0227", "baphomet_source2", [24,16], 86.0/69.0, "Horned goat skull, two hooves and ring staff; explicit morph definition -> body 53."),
    ("10", "켄라우헬", "PB0126", "ken_lauhel_source2", [24,16], 1.2, "Unique ken lauhel body 2419; gold shoulder plates, black/red cloak and long silver sword; soles visible beside cloak."),
    ("52", "어쌔신 마스터", "PB0156", "assassin_master_source2", [24,16], 1.3, "Unique assasin master body 2843; white head wrap, red cloak/gold trim, paired curved blades and visible boots."),
    ("74", "다크엘프 위자드", "PB0164", "darkelf_wizard_source2", [24,18], 1.3, "Unique darkelf wizard body 3376; white head and shoulder wraps, black robe and forked staff; robe contact/boots inspected."),
    ("91", "소녀 케레니스", "PB0207", "young_kelenis_source1", [24,18], 1.2, "Unique young kelenis body 8774; long blue hair, gold bodice, dark long skirt and tall staff; distinct from adult Kelenis 2468."),
    ("28", "데몬", "PB0103", "demon_source2", [24,18], 1.0, "Unique demon body 1180; red muscular torso, black/red wings, paired white horns and clawed feet; not Balrog."),
    ("77", "키위패롯", "PB0198", "kiwi_parrot_source2", [24,18], 1.5, "Unique kiwi parrot body 4147; orange crest/body, blue wings/tail and two grounded clawed feet."),
    ("81", "미들오움", "PB0182", "middle_oum_source2", [24,18], 1.8, "Unique middle oum body 3644; hunched dark ridged body, short legs and visible pale soles; no lookalike alias chosen."),
]
PENDING_REASONS = {
    "라쿤": "Quadruped paw/ground center and complete eight-view animation review pending.",
    "페이퍼 맨": "Translucent/flat paper body composition and grounded contact not established.",
    "거대 개미": "Multiple leg contact points; grounded center and complete direction review pending.",
    "서큐버스": "Winged/floating pose; ground projection and source shadow composition unverified.",
    "블레이즈": "Source lv blaze label does not establish the exact target transformation form.",
    "펌프킨": "Draped/hovering pumpkin body; anatomical ground projection unverified.",
    "다크 나이트": "Dark knight/black knight form distinction requires identity review despite one candidate fingerprint.",
    "뱀파이어": "Cloak obscures feet; stable anatomical ground center and all actions remain unverified.",
    "가드리아": "Legend_Gadria pixels inspected; airborne/one-foot poses lack a verified stable ground projection.",
}

def install(archive, package, root, review):
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == ARCHIVE_SHA, "input SHA mismatch"
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None, "ZIP CRC failure"
        for rel in ["package_reader.py", "decoder/spr_decode.py", "action_bindings.jsonl", "asset_requests.jsonl", "content_blobs.jsonl"]:
            assert z.read("transformation_source_candidates_v1/" + rel) == (package / rel).read_bytes(), rel
    from PIL import Image
    pkg = module("source_package", package / "package_reader.py").Package(package)
    decoder = module("source_spr_decoder", package / "decoder/spr_decode.py")
    target_id, name, binding_id, folder, foot_grid, scale, identity_basis = review
    binding = pkg.bindings[binding_id]
    candidate = next(c for c in pkg.candidates if c['twilight_id'] == 'transformation:inven:' + target_id)
    assert candidate['name'] == name and binding['representative_id'] in candidate['source_model_representatives']
    assert binding['matched_name_candidate']
    actions = dict(ACTIONS)
    available = {a['code'] for a in binding['actions']}
    action_fallbacks = {}
    for role, action in actions.items():
        if action not in available:
            action_fallbacks[role] = {'requested_action_code':action,'replacement_action_code':1,'reason':'Action absent; same body/source attack sequence only.'}
            actions[role] = 1
    sprites, resolved = {}, {}
    for role, action in actions.items():
        source_action = next(a for a in binding["actions"] if a["code"] == action)
        for direction, heading in enumerate(HEADINGS):
            refs = [pkg.resolve(binding_id, action, step, heading) for step in range(len(source_action["references"]))]
            for ref in refs:
                path = Path(ref["blob_path"])
                if path not in sprites:
                    data = path.read_bytes()
                    assert hashlib.sha256(data).hexdigest() == ref["blob_sha256"]
                    sprites[path] = decoder.Sprite(data)
            resolved[role, direction] = refs
    bounds = [s.metadata()["file_union_tile_bounds_original_grid"] for s in sprites.values()]
    canvas = [min(b[0] for b in bounds), min(b[1] for b in bounds), max(b[2] for b in bounds), max(b[3] for b in bounds)]
    width, height = canvas[2] - canvas[0], canvas[3] - canvas[1]
    # Reviewed anatomical ground center between the two feet in breathing
    # poses. Shared for all files/frames, never alpha-bbox recenter each frame.
    foot = [foot_grid[0] - canvas[0], foot_grid[1] - canvas[1]]
    output = root / "assets/local_source_transforms" / folder
    output.mkdir(parents=True, exist_ok=True)
    resource = "res://assets/local_source_transforms/" + folder + "/"
    ext, sub, animations, tracks = [], [], {}, []
    frame_number = 0
    for atlas_index, role in enumerate(actions, 1):
        count = len(resolved[role, 0])
        atlas = Image.new("RGBA", (width * 8, height * count))
        ext.append(f'[ext_resource type="Texture2D" path="{resource}{role}.png" id="{atlas_index}"]')
        for direction in range(8):
            frames = []
            refs = resolved[role, direction]
            for step, ref in enumerate(refs):
                sprite = sprites[Path(ref["blob_path"])]
                image, placement = sprite.render(ref["frame_index"], canvas_bounds=tuple(canvas))
                assert image.getbbox() is not None, (role, direction, step)
                atlas.paste(image, (width * direction, height * step))
                key = f"frame_{frame_number}"
                frame_number += 1
                sub.append(f'[sub_resource type="AtlasTexture" id="{key}"]\natlas = ExtResource("{atlas_index}")\nregion = Rect2({width*direction}, {height*step}, {width}, {height})\nfilter_clip = true')
                # Keep target clock/marker interpolation. Raw source durations
                # remain provenance; no unsupported tick conversion.
                frames.append('{"duration": 1.0, "texture": SubResource("' + key + '")}')
                tracks.append({**{k:v for k,v in ref.items() if k not in ["blob_path", "warning"]}, "role":role, "game_direction":direction, "placement":placement})
            animations[f"{role}_{direction}"] = (frames, role not in ["attack", "hit", "death", "cast", "special"])
        atlas.save(output / f"{role}.png")
    for alias, role in ALIASES.items():
        for direction in range(8): animations[f"{alias}_{direction}"] = animations[f"{role}_{direction}"]
    serialized = []
    for animation_name, (frames, loop) in animations.items():
        serialized.append('{"frames": [' + ', '.join(frames) + '], "loop": ' + str(loop).lower() + ', "name": &' + json.dumps(animation_name) + ', "speed": 9.0}')
    tres = f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(sub)+1} format=3]\n\n' + '\n\n'.join(ext+sub) + '\n\n[resource]\nanimations = [' + ',\n'.join(serialized) + ']\n'
    (output / "SpriteFrames.tres").write_text(tres)
    files = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.iterdir() if p.suffix in [".png", ".tres"]}
    original_profiles = json.loads((root / "data/combat_animation_profiles.json").read_text())["profiles"]
    layout = original_profiles.get("transform:" + target_id, {}).get("layout", "still")
    entry = {"name":name, "grade":candidate["grade"], "frames_path":resource+"SpriteFrames.tres", "required_layout":layout, "pixel_scale":scale, "sprite_offset":[(width/2-foot[0])*scale,(height/2-foot[1])*scale], "source_model":binding["representative_id"], "binding_id":binding_id, "body_model_prefix":binding["body_model_prefix"], "source":binding["source"], "variant":binding["variant"], "input_sha256":ARCHIVE_SHA, "identity_basis":identity_basis, "direction_review":"h1 back = N; h5 chest/front = S; h3 profile right = E; h7 profile left = W; all diagonal views checked.", "game_to_source_heading":HEADINGS, "canvas_original_grid":canvas, "foot_original_grid":foot_grid, "foot_in_canvas":foot, "foot_review":"Anatomical midpoint of two grounded feet/robe hem in breathing poses, compared against walking poses. One fixed anchor across every source file; no per-frame bbox recentering.", "original_grid_origin_in_canvas":[-canvas[0],-canvas[1]], "reference_client_origin_in_canvas":[-canvas[0]+24,-canvas[1]-36], "actions":actions, "action_fallbacks":action_fallbacks, "same_model_aliases":ALIASES, "timing_policy":"Preserve target duration, markers, movement cadence and hit clocks; source durations recorded raw only.", "attachments":binding["attachments"], "composition_limits":"Offline opaque RLE; palette/t/blend/color keys and separate shadow composition not certified. No replacement attachment added.", "files_sha256":files, "rendered_frames":frame_number}
    (output / "provenance.json").write_text(json.dumps({"entry":entry,"tracks":tracks,"spr_headers":{p.name:s.metadata() for p,s in sprites.items()}},ensure_ascii=False,indent=2))
    manifest_path = root / "data/source_transform_visuals.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"schema":1,"scope":"Local-only reviewed source visuals; original art not authorized for public push.","entries":{},"excluded_grades":["신화","유일"]}
    manifest["entries"]["transform:" + target_id] = entry
    selected = set(manifest["entries"])
    manifest["pending_candidates"] = [{"id":c["twilight_id"],"name":c["name"],"reason": PENDING_REASONS.get(c["name"], "Definition only; no original body pixels supplied." if not c["has_raw_model_payload"] else "Multiple source model fingerprints/variants require exact form selection.")} for c in pkg.candidates if "transform:"+c["twilight_id"].split(":")[-1] not in selected]
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps({"output":str(output),"canvas":canvas,"frames":frame_number,"sha256":files},ensure_ascii=False))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive",type=Path,required=True)
    parser.add_argument("--package",type=Path,required=True)
    parser.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    for review in REVIEWS:
        install(args.archive,args.package,args.root,review)
