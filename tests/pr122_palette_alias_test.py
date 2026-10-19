"""Synthetic regression tests. These are NOT original-art or Godot playback QA."""
from __future__ import annotations

import copy
import importlib.util
import json
import random
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("palette_pipeline", ROOT / "tools/pr122_palette_alias_pipeline.py")
p = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = p
spec.loader.exec_module(p)

TRES = '''[gd_resource type="SpriteFrames" load_steps=3 format=3]
[ext_resource type="Texture2D" path="res://source/atlas.png" id="1"]
[sub_resource type="AtlasTexture" id="pose"]
atlas = ExtResource("1")
region = Rect2(0, 0, 2, 2)
margin = Rect2(3, 5, 8, 10)
filter_clip = true
[resource]
animations = [{"frames": [{"duration": 2.0, "texture": SubResource("pose")}], "loop": false, "name": &"attack_7", "speed": 7.5}]
metadata/twilight_canvas_size = Vector2(10, 12)
'''


class Pixels(unittest.TestCase):
    def test_unmasked_and_alpha_are_exact(self):
        source = Image.new("RGBA", (4, 1))
        source.putdata([(200, 150, 120, 255), (90, 90, 90, 250), (0, 0, 0, 128), (45, 123, 67, 0)])
        mask = Image.new("L", (4, 1)); mask.putdata([0, 255, 0, 255])
        result, count = p.recolor_masked(source, mask, "ff0000")
        self.assertEqual(list(result.getdata()), [(200,150,120,255),(90,0,0,250),(0,0,0,128),(45,123,67,0)])
        self.assertEqual(count, 1)
        self.assertEqual(list(source.getdata())[1], (90,90,90,250))

    def test_soft_mask(self):
        source = Image.new("RGBA", (1,1), (200,200,200,77))
        result, _ = p.recolor_masked(source, Image.new("L", (1,1),128), "0000ff")
        self.assertEqual(result.getpixel((0,0)), (100,100,200,77))

    def test_random_protected_pixels_and_value(self):
        rng = random.Random(122)
        pixels = [tuple(rng.randrange(256) for _ in range(4)) for _ in range(2048)]
        source = Image.new("RGBA", (2048,1)); source.putdata(pixels)
        mask = Image.new("L", (2048,1)); mask.putdata([0 if i%2 else 255 for i in range(2048)])
        result, _ = p.recolor_masked(source, mask, "75aeff")
        for index, (before, after) in enumerate(zip(pixels, result.getdata())):
            self.assertEqual(before[3], after[3])
            if index%2 or before[3] == 0:
                self.assertEqual(before, after)
            else:
                self.assertEqual(max(before[:3]), max(after[:3]))

    def test_invalid_mask_size(self):
        with self.assertRaises(p.Hold): p.recolor_masked(Image.new("RGBA",(2,2)), Image.new("L",(1,1)), "ffffff")
    def test_invalid_source_mode(self):
        with self.assertRaises(p.Hold): p.recolor_masked(Image.new("RGB",(1,1)), Image.new("L",(1,1)), "ffffff")
    def test_ambiguous_mask_mode(self):
        with self.assertRaises(p.Hold): p.recolor_masked(Image.new("RGBA",(1,1)), Image.new("RGBA",(1,1)), "ffffff")
    def test_invalid_colors(self):
        for color in ("000000", "#ffffff", "fff", "notrgb", None):
            with self.subTest(color=color), self.assertRaises(p.Hold):
                p.recolor_masked(Image.new("RGBA",(1,1)), Image.new("L",(1,1)), color)


class Staging(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name); (self.root / "source").mkdir()
        self.frames = self.root / "source/SpriteFrames.tres"
        self.frames.write_text(TRES, encoding="utf-8")
        Image.new("RGBA", (2,2), (120,120,120,203)).save(self.root / "source/atlas.png")
        Image.new("L", (2,2), 255).save(self.root / "source/mask.png")
        self.profiles = {"transform:9001": {"name":"Synthetic source", "frames_path":"res://source/SpriteFrames.tres"},
                         "transform:9002": {"name":"Synthetic alias", "frames_path":"res://source/SpriteFrames.tres", "attack_hit_frame":1}}
        self.recipe = {"slug":"fixture", "target":"transform:9002", "source":"transform:9001", "kind":"masked_palette",
            "identity_verified":True, "identity_evidence":"SYNTHETIC_FIXTURE_ONLY", "source_motion_reviewed":True,
            "mask_reviewed":True, "color":"75aeff", "frames_path":"res://source/SpriteFrames.tres",
            "frames_sha256":p.digest(self.frames.read_bytes()),
            "target_record_sha256":p.record_hash(self.profiles["transform:9002"]),
            "source_record_sha256":p.record_hash(self.profiles["transform:9001"]),
            "textures":{"res://source/atlas.png":{"sha256":p.digest((self.root/"source/atlas.png").read_bytes()),
                "mask_path":"res://source/mask.png", "mask_sha256":p.digest((self.root/"source/mask.png").read_bytes())}}}

    def build(self): return p.build(self.root, self.recipe, self.profiles)
    def test_palette_output_and_metadata_preservation(self):
        before = copy.deepcopy(self.profiles)
        result = self.build(); folder = self.root / p.OUTPUT / "fixture"
        rewritten = (folder/"SpriteFrames.tres").read_text()
        new_uri = "res://"+(p.OUTPUT/"fixture/atlas_000.png").as_posix()
        self.assertEqual(rewritten.replace(new_uri,"res://source/atlas.png"), TRES)
        self.assertEqual(self.frames.read_text(), TRES)
        self.assertEqual(self.profiles, before)
        self.assertEqual(result["changed_pixels"], 4)
        self.assertEqual(result["main_integration"], "NOT_APPLIED")
        self.assertEqual(result["godot_playback"], "NOT_RUN")
        self.assertTrue((folder/"integration_patch.json").is_file())
        self.assertIn("color_tint", result["set_visual_fields"])
        self.assertEqual(Image.open(folder/"atlas_000.png").getpixel((0,0))[3],203)

    def test_name_alias_does_not_copy_art(self):
        self.recipe["kind"] = "name_alias"
        result=self.build(); folder=self.root/p.OUTPUT/"fixture"
        self.assertEqual(result["set_visual_fields"]["frames_path"], "res://source/SpriteFrames.tres")
        self.assertEqual(sorted(x.name for x in folder.iterdir()), ["integration_patch.json"])
        self.assertEqual(result["changed_pixels"],0)

    def test_identity_hold(self):
        self.recipe["identity_verified"]=False
        with self.assertRaises(p.Hold): self.build()
    def test_missing_identity_evidence(self):
        self.recipe["identity_evidence"]=""
        with self.assertRaises(p.Hold): self.build()
    def test_motion_hold(self):
        self.recipe["source_motion_reviewed"]=False
        with self.assertRaises(p.Hold): self.build()
    def test_mask_review_hold(self):
        self.recipe["mask_reviewed"]=False
        with self.assertRaises(p.Hold): self.build()
    def test_stale_target_record(self):
        self.profiles["transform:9002"]["attack_hit_frame"]=2
        with self.assertRaises(p.Hold): self.build()
    def test_stale_source_record(self):
        self.profiles["transform:9001"]["name"]="Changed"
        with self.assertRaises(p.Hold): self.build()
    def test_stale_texture(self):
        (self.root/"source/atlas.png").write_bytes(b"Changed")
        with self.assertRaises(p.Hold): self.build()
    def test_stale_frames(self):
        self.frames.write_text(TRES+"\n")
        with self.assertRaises(p.Hold): self.build()
    def test_noop_is_not_a_finished_palette(self):
        Image.new("L",(2,2),0).save(self.root/"source/mask.png")
        self.recipe["textures"]["res://source/atlas.png"]["mask_sha256"]=p.digest((self.root/"source/mask.png").read_bytes())
        with self.assertRaises(p.Hold): self.build()
        self.assertFalse((self.root/p.OUTPUT/"fixture").exists())
    def test_existing_output_never_overwritten(self):
        self.build()
        marker=self.root/p.OUTPUT/"fixture/keep.txt"; marker.write_text("Another worker")
        with self.assertRaises(p.Hold): self.build()
        self.assertEqual(marker.read_text(),"Another worker")
    def test_protected_target(self):
        with self.assertRaises(p.Hold): p.build(self.root,self.recipe,self.profiles,{"transform:9002"})
    def test_protected_donor(self):
        with self.assertRaises(p.Hold): p.build(self.root,self.recipe,self.profiles,{"transform:9001"})
    def test_traversal_and_symlink(self):
        for path in ("res://../outside", "res:///tmp/outside", "user://data", "res://", "res://x\\y"):
            with self.subTest(path=path), self.assertRaises(p.Hold): p.local_path(self.root,path)
        (self.root/"escape").symlink_to(self.root.parent, target_is_directory=True)
        with self.assertRaises(p.Hold): p.local_path(self.root,"res://escape/outside")
    def test_invalid_slug(self):
        self.recipe["slug"]="../other-worker"
        with self.assertRaises(p.Hold): self.build()
    def test_missing_texture_lock(self):
        self.recipe["textures"]={}
        with self.assertRaises(p.Hold): self.build()
    def test_name_alias_cannot_erase_tint(self):
        self.recipe["kind"]="name_alias"; self.profiles["transform:9002"]["color_tint"]="ff0000"
        self.recipe["target_record_sha256"]=p.record_hash(self.profiles["transform:9002"])
        with self.assertRaises(p.Hold): self.build()
    def test_uid_cannot_silently_resolve_old_art(self):
        self.frames.write_text(TRES.replace('id="1"','uid="uid://old" id="1"'))
        self.recipe["frames_sha256"]=p.digest(self.frames.read_bytes())
        with self.assertRaises(p.Hold): self.build()
    def test_protected_transitive_donor(self):
        self.profiles["transform:9001"]["shared_visual_source"]="transform:176"
        with self.assertRaises(p.Hold): self.build()
    def test_cyclic_donor_chain(self):
        self.profiles["transform:9001"]["shared_visual_source"]="transform:9001"
        with self.assertRaises(p.Hold): self.build()
    def test_preview_is_not_counted_as_new_production(self):
        index = json.loads((ROOT/"data/pr122_palette_alias_parallel/preview_targets.json").read_text())
        self.assertEqual(index["new_motion_poses"],0)
        self.assertEqual(index["new_game_connections"],0)
        self.assertEqual({x["target"] for x in index["entries"]},{"transform:179","transform:182"})
        for entry in index["entries"]:
            self.assertFalse(entry["production_ready"])
            self.assertFalse(entry["identity_verified"])
            scene=ROOT/entry["preview_scene"][6:]
            self.assertIn(entry["target"],scene.read_text())
    def test_every_named_native_followup_is_reserved(self):
        self.assertTrue({"transform:393","transform:267","transform:176","transform:2"} <= p.PROTECTED)


if __name__ == "__main__":
    unittest.main(verbosity=1)
