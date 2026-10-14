"""Guard exact reference identity, lossless import, and reviewed actual poses."""
import json
import copy
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import import_original_based_motion as importer
import audit_eight_direction_coverage as audit


class OriginalBasedImportTest(unittest.TestCase):
    def test_single_sheet_nonstandard_canvas_preserves_world_foot(self):
        path = ROOT / "assets/actors/eight_direction/original_based/werewolf/poses.png"
        geometry = importer.analyze(path, canvas_size=384)
        importer.require_complete_pose_regions(path, geometry)
        resource = importer.spriteframes("res://" + str(path.relative_to(ROOT)), geometry)
        self.assertTrue("metadata/twilight_canvas_size = Vector2(256, 256)" in resource,
                        "Nonstandard single-sheet canvases need runtime normalization")
        # The runtime scales the virtual canvas to 256 before applying the
        # profile's -32 world-space foot offset. Inspect every actual pose.
        for frame in geometry["frames"]:
            region = np.array(frame["region"])
            margin = np.array(frame["margin"])
            canvas = region[2:] + margin[2:]
            local_foot = margin[:2] + np.array(frame["source_anchor"]) - region[:2] - canvas / 2
            world_foot = np.array([0, -32]) + local_foot * 256 / canvas
            np.testing.assert_allclose(world_foot, [0, 0], atol=1e-9)

    def test_existing_256_single_sheet_output_is_byte_identical(self):
        for actor in ("werewolf", "ogre", "succubus", "harpy", "lycanthrope",
                      "lava_golem", "ice_golem", "cockatrice"):
            with self.subTest(actor=actor):
                folder = ROOT / "assets/actors/eight_direction/original_based" / actor
                proof = json.loads((folder / "provenance.json").read_text())
                resource = importer.spriteframes("res://" + str((folder / "poses.png").relative_to(ROOT)),
                                                 {"frames": proof["frames"]})
                self.assertEqual(resource.encode(), (folder / "SpriteFrames.tres").read_bytes())

    def test_detached_pixels_in_later_sheet_abort_before_any_output(self):
        target = next(row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]
                      if row["key"] == "monster:늑대인간")
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            (root / "data/animation_authoring_sources.json").write_text(json.dumps({"targets": [target]}))
            (root / "data/combat_animation_profiles.json").write_text(json.dumps({"profiles": {}}))
            reference = Path(target["reference"]["path"].removeprefix("res://"))
            (root / reference).parent.mkdir(parents=True)
            shutil.copyfile(ROOT / reference, root / reference)
            sheets = []
            for index, rows in enumerate((8, 5)):
                pixels = np.zeros((rows * 64, 512, 4), dtype=np.uint8)
                for row in range(rows):
                    for direction in range(8):
                        x, y = direction * 64, row * 64
                        pixels[y + 20:y + 44, x + 20:x + 36] = [30 + index * 64 + row * 8 + direction, 100, 160, 255]
                if index == 1:
                    # A distinct visible piece, outside the main body's crop.
                    pixels[30:34, 44:48] = [220, 100, 60, 255]
                path = root / f"synthetic-coverage-{index}.png"
                Image.fromarray(pixels).save(path)
                roles = {"idle": [0, 1], "walk": [2, 3, 4], "attack": [5, 6, 7]} if index == 0 else {"hit": [0, 1], "death": [2, 3, 4]}
                sheets.append({"output_path": str(path), "rows": rows, "roles": roles, "reference_rows": [0, 1]})
            candidate = {"sheets": sheets, "prompt": "Synthetic coverage guard fixture, never game art",
                         "review": {"identity_preserved": True, "eight_views": True, "motion_roles": True,
                                    "no_clipping": True, "notes": "Synthetic test of an incorrectly approved detached piece"}}
            before = {str(path.relative_to(root)): importer.sha(path) if path.is_file() else None
                      for path in root.rglob("*")}
            for apply in (False, True):
                with self.subTest(apply=apply):
                    with self.assertRaisesRegex(ValueError, "16 visible pixels outside pose regions"):
                        importer.import_sheet(root, candidate, "coverage_fixture", [target["key"]], apply)
                    after = {str(path.relative_to(root)): importer.sha(path) if path.is_file() else None
                             for path in root.rglob("*")}
                    self.assertEqual(after, before, "Rejected imports must not create or change any file or directory")

    def test_existing_family_aliases_share_only_the_same_rendered_original(self):
        targets = {row["key"]: row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        for names in [("고스트", "글루디오 던전 유령", "지옥의 고스트"), ("오우거", "기란 평원 오우거", "잊혀진 섬 고대오우거"),
                      ("아이언 골렘", "지옥의 아이언골렘"), ("글루디오 던전 구울", "불사의 구울"), ("도마뱀", "알비노 도마뱀"),
                      ("크랩맨", "에바 왕국 크랩맨"), ("아시타지오", "오만한 아시타지오"),
                      ("알비노 개구리", "알비노 뿔 개구리"), ("파이어 에그", "공포의 파이어 에그"),
                      ("혼 켈베로스", "잔혹한 혼 켈베로스"),
                      ("샤벨 타이거", "잔혹한 샤벨타이거"),
                      ("용의 계곡 본 드래곤", "불멸의 본 드래곤", "지옥의 본 드래곤")]:
            first = targets["monster:" + names[0]]
            for name in names[1:]:
                self.assertEqual(importer.sharing_identity(first), importer.sharing_identity(targets["monster:" + name]))
            other_attack_type = "melee" if first["presentation_to_preserve"]["attack_type"] == "magic" else "magic"
            for field, value in [("attack_type", other_attack_type), ("visual_height", 1234), ("animation_profile", {"floating": False})]:
                other = copy.deepcopy(first)
                other["presentation_to_preserve"][field] = value
                self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
            other = copy.deepcopy(first)
            other["reference"]["sha256"] = "different original"
            self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
            other = copy.deepcopy(first)
            other["presentation_to_preserve"]["visual"]["body"] = "different anatomy"
            self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
            other = copy.deepcopy(first)
            other["reference"]["image_size"] = [1, 2]
            self.assertNotEqual(importer.sharing_identity(first), importer.sharing_identity(other))
        atlas = next(row for row in targets.values() if row["reference"]["kind"] == "existing_project_atlas")
        other = copy.deepcopy(atlas)
        other["presentation_to_preserve"]["visual"]["variant"] = -999
        self.assertNotEqual(importer.sharing_identity(atlas), importer.sharing_identity(other))
        other = copy.deepcopy(atlas)
        other["reference"]["path"] = "res://assets/different-atlas.png"
        self.assertNotEqual(importer.sharing_identity(atlas), importer.sharing_identity(other))

    def test_byte_identical_portrait_alias_checks_each_actual_source_before_writing(self):
        plan = json.loads((ROOT / "data/animation_authoring_sources.json").read_text())
        targets = {row["key"]: row for row in plan["targets"]}
        keys = ["monster:샤벨 타이거", "monster:잔혹한 샤벨타이거"]
        references = [targets[key]["reference"] for key in keys]
        self.assertNotEqual(references[0]["path"], references[1]["path"])
        self.assertEqual(importer.sharing_identity(targets[keys[0]]), importer.sharing_identity(targets[keys[1]]))
        self.assertEqual(*(importer.sha(ROOT / ref["path"].removeprefix("res://")) for ref in references))
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            (root / "data/animation_authoring_sources.json").write_text(json.dumps(plan))
            for ref in references:
                path = root / ref["path"].removeprefix("res://")
                path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / ref["path"].removeprefix("res://"), path)
            secondary = root / references[1]["path"].removeprefix("res://")
            secondary.write_bytes(b"intentionally different secondary reference, never game art")
            with self.assertRaisesRegex(ValueError, "Original reference bytes changed"):
                importer.import_sheet(root, {}, "tiger_alias", keys, True)
            self.assertFalse((root / "assets/actors").exists())
            self.assertFalse((root / "data/combat_animation_profiles.json").exists())
            self.assertEqual(importer.sha(root / references[0]["path"].removeprefix("res://")), references[0]["sha256"])
            self.assertEqual(secondary.read_bytes(), b"intentionally different secondary reference, never game art")

    def test_all_source_references_remain_unchanged(self):
        plan = json.loads((ROOT / "data/animation_authoring_sources.json").read_text())
        self.assertEqual(len(plan["targets"]), 222)
        for target in plan["targets"]:
            reference = target["reference"]
            self.assertEqual(importer.sha(ROOT / reference["path"].removeprefix("res://")), reference["sha256"], target["key"])

    def test_actual_imports_have_separated_distinct_articulated_poses(self):
        for actor, specs in {"werewolf": [("poses.png", 13)], "ogre": [("poses.png", 13)],
                             "succubus": [("poses.png", 13)], "harpy": [("poses.png", 13)], "lycanthrope": [("poses.png", 13)],
                             "bugbear": [("poses-0.png", 8), ("poses-1.png", 5)], "sand_worm": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "reaper_male": [("poses-0.png", 7), ("poses-1.png", 5)],
                             "iron_golem": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "ghoul": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "lizard": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "crabman": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "asitagio": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "albino_frog": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "fire_egg": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "horn_cerberus": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "mummy_lord": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "seer_boss": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "salah": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "bone_dragon": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "king_bugbear": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "ettin": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "ancient_penguin": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "albino_giant_crab": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "kraken_transform": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "snowman": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "yeti": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "ice_man": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "scorpion": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "dire_wolf": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "saber_tiger": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "basilisk": [("poses-0.png", 8), ("poses-1.png", 4)],
                             "lava_golem": [("poses.png", 13)], "ice_golem": [("poses.png", 13)], "cockatrice": [("poses.png", 13)], "ghost": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "reaper_female": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "cyclops": [("poses-0.png", 8), ("poses-1.png", 5)],
                             "spear_captain": [("poses-0.png", 8), ("poses-1.png", 5)]}.items():
            folder = ROOT / "assets/actors/eight_direction/original_based" / actor
            proof = json.loads((folder / "provenance.json").read_text())
            expected_poses = 96 if actor in {"reaper_male", "asitagio", "ettin", "dire_wolf", "saber_tiger", "basilisk"} else 104
            self.assertEqual(proof["distinct_pixel_frames"], expected_poses)
            parts = []
            for index, (name, rows) in enumerate(specs):
                reference_rows = ([0, 1] if index == 0 else [1]) if len(specs) > 1 else None
                parts.append(importer.analyze(folder / name, rows, reference_rows, parts[0]["neutral_height"] if parts else None))
            self.assertEqual(sum(part["distinct_pixel_frames"] for part in parts), expected_poses)
            for atlas in {entry["path"]: entry for role in proof["tracks"].values() for entry in role["atlas_files"]}.values():
                self.assertEqual(importer.sha(ROOT / atlas["path"].removeprefix("res://")), atlas["sha256"])

    def test_runtime_tracks_keep_all_real_frames_and_non_looping_actions(self):
        for actor in ("werewolf", "ghost", "reaper_female", "ogre", "lava_golem", "ice_golem", "cockatrice", "cyclops", "spear_captain", "succubus", "harpy", "lycanthrope", "bugbear", "sand_worm", "reaper_male", "iron_golem", "ghoul", "lizard", "crabman", "asitagio", "spear_guard_green", "spear_guard", "spear_guard_red", "albino_frog", "fire_egg", "horn_cerberus", "mummy_lord", "seer_boss", "salah", "bone_dragon", "king_bugbear", "ettin", "ancient_penguin", "pan", "albino_giant_crab", "kraken_transform", "snowman", "yeti", "ice_man", "scorpion", "dire_wolf", "saber_tiger", "basilisk"):
            path = ROOT / "assets/actors/eight_direction/original_based" / actor / "SpriteFrames.tres"
            _, frames, tracks = audit.read_spriteframes(path)
            expected_poses = 96 if actor in {"reaper_male", "asitagio", "ettin", "dire_wolf", "saber_tiger", "basilisk"} else 104
            self.assertEqual(len(frames), expected_poses)
            self.assertEqual(len(tracks), 40)
            used = []
            for role, rows in importer.ROLES.items():
                for direction in range(8):
                    track = tracks[f"{role}_{direction}"]
                    reviewed_counts = {("reaper_male", "walk"): 2, ("asitagio", "death"): 2, ("ettin", "death"): 2,
                                       ("dire_wolf", "death"): 2, ("saber_tiger", "death"): 2, ("basilisk", "death"): 2}
                    self.assertEqual(len(track["frames"]), reviewed_counts.get((actor, role), len(rows)))
                    self.assertEqual(track["loop"], role in ("idle", "walk"))
                    used.extend(frame["texture"] for frame in track["frames"])
            self.assertEqual(len(set(used)), expected_poses)
            if actor == "reaper_male":
                profile = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]["transform:258"]
                self.assertAlmostEqual(profile["movement_fps"], 2 / importer.SECONDS["walk"])

    def test_tiger_alias_retains_each_original_path_with_one_native_resource(self):
        folder = ROOT / "assets/actors/eight_direction/original_based/saber_tiger"
        proof = json.loads((folder / "provenance.json").read_text())
        profiles = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]
        targets = {row["key"]: row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        keys = ["monster:샤벨 타이거", "monster:잔혹한 샤벨타이거"]
        self.assertEqual(proof["target_keys"], keys)
        self.assertEqual(proof["target_references"], {key: targets[key]["reference"] for key in keys})
        self.assertEqual(profiles[keys[0]]["frames_path"], profiles[keys[1]]["frames_path"])
        self.assertEqual(profiles[keys[0]]["pixel_scale"], profiles[keys[1]]["pixel_scale"])
        for key in keys:
            self.assertEqual(profiles[key]["authoring_reference"], targets[key]["reference"]["path"])
        _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
        self.assertEqual(len(textures), 96)
        self.assertEqual(len(tracks), 40)
        self.assertEqual(len({frame["path"] for frame in textures.values()}), 2)

    def test_pan_keeps_separate_real_spear_phases_and_original_identity(self):
        folder = ROOT / "assets/actors/eight_direction/original_based/pan"
        proof = json.loads((folder / "provenance.json").read_text())
        target = next(row for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]
                      if row["key"] == "transform:218")
        self.assertEqual(proof["reference"], target["reference"])
        self.assertEqual(proof["target_keys"], ["transform:218"])
        _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
        hashes = set()
        for index, (phases, canvas) in enumerate([(5, 320), (3, 392), (5, 240)]):
            path = folder / f"poses-{index}.png"
            result = importer.analyze(path, phases, reference_rows=[0, 1], canvas_size=canvas)
            self.assertEqual(result["distinct_pixel_frames"], phases * 8)
            hashes.update(frame["rgba_sha256"] for frame in result["frames"])
        self.assertEqual(len(hashes), 104)
        for direction in range(8):
            for role, sheet in [("idle", 0), ("walk", 0), ("attack", 1), ("hit", 2), ("death", 2)]:
                frames = [textures[slot["texture"]] for slot in tracks[f"{role}_{direction}"]["frames"]]
                self.assertTrue(all(frame["path"].endswith(f"/poses-{sheet}.png") for frame in frames))
                self.assertEqual(len(frames), 2 if role in {"idle", "hit"} else 3)

    def test_guard_attack_uses_source_direction_rows_without_transposing_pixels(self):
        folder = ROOT / "assets/actors/eight_direction/original_based/spear_guard_green"
        proof = json.loads((folder / "provenance.json").read_text())
        _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
        attack_atlas = proof["tracks"]["attack"]["atlas_files"][0]
        self.assertEqual(attack_atlas["directions_axis"], "rows")
        with self.assertRaises(ValueError):
            importer.analyze(folder / "poses-1.png", 3)
        anchors = [frame["source_anchor"] for frame in proof["frames"] if frame["sheet"] == 1]
        attack = importer.analyze(folder / "poses-1.png", 3, directions_axis="rows",
                                  canvas_size=224, source_anchors=anchors)
        self.assertEqual(attack["distinct_pixel_frames"], 24)
        previous_contact_y = -1
        for direction in range(8):
            frames = [textures[frame["texture"]] for frame in tracks[f"attack_{direction}"]["frames"]]
            self.assertTrue(all(frame["path"].endswith("/poses-1.png") for frame in frames))
            centers_x = [frame["region"][0] + frame["region"][2] / 2 for frame in frames]
            self.assertEqual(centers_x, sorted(centers_x))
            self.assertGreater(frames[1]["region"][1], previous_contact_y)
            previous_contact_y = frames[1]["region"][1]
        atlases = {a["path"]: a for track in proof["tracks"].values() for a in track["atlas_files"]}
        self.assertEqual(len(atlases), 3)
        for path, atlas in atlases.items():
            self.assertEqual(importer.sha(ROOT / path.removeprefix("res://")), atlas["sha256"])

    def test_guard_variants_keep_their_own_original_and_distinct_artwork(self):
        profiles = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]
        sources = {row["key"]: row["reference"] for row in json.loads((ROOT / "data/animation_authoring_sources.json").read_text())["targets"]}
        atlas_hashes = set()
        for actor, key, canvases in [("spear_guard_green", "transform:167", [392, 224, 480]),
                                     ("spear_guard", "transform:2", [256, 352, 264]),
                                     ("spear_guard_red", "transform:110", [384, 416, 408])]:
            folder = ROOT / "assets/actors/eight_direction/original_based" / actor
            proof = json.loads((folder / "provenance.json").read_text())
            self.assertEqual(proof["reference"], sources[key])
            self.assertEqual(proof["target_keys"], [key])
            self.assertTrue(profiles[key]["frames_path"].endswith(f"/{actor}/SpriteFrames.tres"))
            for index, phases in enumerate([5, 3, 5]):
                path = folder / f"poses-{index}.png"
                digest = importer.sha(path)
                self.assertNotIn(digest, atlas_hashes, "Distinct original palettes must not share one replacement image")
                atlas_hashes.add(digest)
                anchors = [frame["source_anchor"] for frame in proof["frames"] if frame["sheet"] == index]
                result = importer.analyze(path, phases, reference_rows=[0, 1] if index != 1 else None,
                                          directions_axis="rows" if index == 1 else "columns",
                                          canvas_size=canvases[index], source_anchors=anchors)
                self.assertEqual(result["distinct_pixel_frames"], phases * 8)

    def test_guard_attack_body_size_matches_reviewed_idle_anatomy(self):
        # Helmet-to-boot landmarks were reviewed in the source sheets and Main.
        # Include the body, excluding the much longer upright/thrust spear.
        # The former 280/336 attack canvases enlarged these bodies by >20%.
        for actor, idle_height, attack_heights in [("spear_guard", 76, (101, 99)),
                                                   ("spear_guard_red", 82, (91, 89))]:
            folder = ROOT / "assets/actors/eight_direction/original_based" / actor
            _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
            idle = textures[tracks["idle_2"]["frames"][0]["texture"]]
            idle_canvas = idle["region"][3] + idle["margin"][3]
            for direction, body_height in zip([2, 6], attack_heights):
                attack = textures[tracks[f"attack_{direction}"]["frames"][1]["texture"]]
                attack_canvas = attack["region"][3] + attack["margin"][3]
                relative_height = (body_height / attack_canvas) / (idle_height / idle_canvas)
                self.assertGreater(relative_height, .88, actor)
                self.assertLess(relative_height, 1.12, actor)

    def test_guard_first_sheet_normalization_keeps_original_display_height(self):
        folder = ROOT / "assets/actors/eight_direction/original_based/spear_guard_green"
        _, textures, tracks = audit.read_spriteframes(folder / "SpriteFrames.tres")
        profile = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]["transform:167"]
        with Image.open(folder / "poses-0.png") as image:
            pixels = np.asarray(image)
            for direction in range(8):
                for slot in tracks[f"idle_{direction}"]["frames"]:
                    frame = textures[slot["texture"]]
                    x, y, width, height = map(int, frame["region"])
                    canvas_height = height + frame["margin"][3]
                    self.assertEqual(canvas_height, 392)
                    occupied = np.nonzero(pixels[y:y + height, x:x + width, 3] > 100)[0]
                    visible = (int(occupied.max()) - int(occupied.min()) + 1) * 256 / canvas_height * profile["pixel_scale"]
                    self.assertGreater(visible, 90)
                    self.assertLess(visible, 110)

    def test_living_poses_fit_the_existing_visual_height(self):
        # Long directional bodies and casting flames must fit the existing
        # nameplate budget with one scale; independently measure real alpha.
        cases = [("lizard", "monster:도마뱀", "monster:알비노 도마뱀", .93),
                 ("albino_frog", "monster:알비노 개구리", "monster:알비노 뿔 개구리", .85),
                 ("fire_egg", "monster:파이어 에그", "monster:공포의 파이어 에그", .85),
                 ("horn_cerberus", "monster:혼 켈베로스", "monster:잔혹한 혼 켈베로스", .85)]
        for actor, primary, alias, minimum_visible_ratio in cases:
            with self.subTest(actor=actor):
                folder = ROOT / "assets/actors/eight_direction/original_based" / actor
                proof = json.loads((folder / "provenance.json").read_text())
                self.assertEqual(proof["display_height_basis"], "max_living_frame")
                profiles = json.loads((ROOT / "data/combat_animation_profiles.json").read_text())["profiles"]
                scale = profiles[primary]["pixel_scale"]
                self.assertEqual(scale, profiles[alias]["pixel_scale"])
                budget = proof["presentation_to_preserve"]["visual_height"]
                atlases = {atlas["path"]: atlas for track in proof["tracks"].values() for atlas in track["atlas_files"]}
                pixels = {}
                for path in atlases:
                    with Image.open(ROOT / path.removeprefix("res://")) as source:
                        pixels[path] = np.asarray(source).copy()
                measured = []
                for role, track in proof["tracks"].items():
                    if role == "death":
                        continue
                    atlas = track["atlas_files"][0]
                    sheet = list(atlases).index(atlas["path"])
                    for frame in proof["frames"]:
                        if frame.get("sheet", 0) != sheet or frame["row"] not in track["source_rows"]:
                            continue
                        x, y, width, height = frame["region"]
                        occupied_rows = np.nonzero(pixels[atlas["path"]][y:y + height, x:x + width, 3] > 100)[0]
                        self.assertGreater(len(occupied_rows), 0)
                        visible_height = (int(occupied_rows.max()) - int(occupied_rows.min()) + 1) * 256 / atlas["canvas_size"][1] * scale
                        self.assertLessEqual(visible_height, budget + .001, (role, frame["direction"]))
                        measured.append(visible_height)
                self.assertEqual(len(measured), 80)
                self.assertGreater(max(measured), budget * minimum_visible_ratio)

    def test_cannot_substitute_a_different_original_for_shared_output(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "data").mkdir()
            shutil.copy(ROOT / "data/animation_authoring_sources.json", root / "data")
            with self.assertRaisesRegex(ValueError, "different original"):
                importer.import_sheet(root, {}, "wrong_shared_actor", ["monster:늑대인간", "monster:고스트"], True)
            self.assertFalse((root / "assets").exists())

    def test_changed_original_cannot_be_used_or_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            plan = json.loads((ROOT / "data/animation_authoring_sources.json").read_text())
            target = next(row for row in plan["targets"] if row["key"] == "monster:늑대인간")
            path = root / target["reference"]["path"].removeprefix("res://")
            path.parent.mkdir(parents=True)
            path.write_bytes(b"intentionally invalid test reference, never game art")
            (root / "data").mkdir()
            (root / "data/animation_authoring_sources.json").write_text(json.dumps(plan))
            with self.assertRaisesRegex(ValueError, "Original reference bytes changed"):
                importer.import_sheet(root, {}, "werewolf", [target["key"]], True)
            self.assertEqual(path.read_bytes(), b"intentionally invalid test reference, never game art")


if __name__ == "__main__":
    unittest.main()
