#!/usr/bin/env python3
"""Focused synthetic generic TI2 pack tests; never original-art evidence."""
import copy
import errno
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from PIL import Image

import build_current523_tile_pack as pack
import current523_tile_review as raw_ti2
from test_current523_tile_review import compress, decoded_fixture


def fixture_inventory(root, count=2):
    root = Path(root)
    source = root / "source"
    (source / "Tile").mkdir(parents=True)
    raw = compress(decoded_fixture(extra_header=0x80000000))
    rows = []
    for tile_id in range(count):
        member = f"Tile/{tile_id}.ti2"
        (source / member).write_bytes(raw)
        rows.append({"member": member, "bytes": len(raw), "sha256": raw_ti2.sha256(raw), "availability": "present",
            "provenance": {"edition": "LineageM", "snapshot_version": 523, "selection_version": 508,
                "container": "Client/Data/Tile1.dat", "current_selection_verified": True,
                "expected_member_sha256": raw_ti2.sha256(raw), "source_dat_sha256": "1" * 64,
                "current_selected_dat_sha256": "1" * 64, "evidence_level": "SYNTHETIC_TEST_ONLY"}})
    return source, {"schema": 1, "edition": "LineageM", "cumulative_version": 523, "members": rows}


def write_inventory(root, inventory):
    path = Path(root) / "inventory.json"
    raw = (json.dumps(inventory, indent=2) + "\n").encode()
    path.write_bytes(raw)
    return path, raw_ti2.sha256(raw)


def runtime_fixture(root, count=35, atlas_storage="png"):
    """Write a bounded test-only pack for the companion Godot runtime test."""
    root = Path(root)
    root.mkdir(parents=True)
    source, inventory = fixture_inventory(root, count)
    path, digest = write_inventory(root, inventory)
    output = root / "pack"
    pack.build_pack(source, path, output, expected_inventory_sha256=digest, atlas_storage=atlas_storage)
    return output, raw_ti2.sha256((output / pack.MANIFEST_NAME).read_bytes())


class GenericTilePackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source, self.inventory = fixture_inventory(self.root)

    def build(self, inventory=None, output=None, **options):
        path, digest = write_inventory(self.root, self.inventory if inventory is None else inventory)
        return pack.build_pack(self.source, path, output or self.root / "output", expected_inventory_sha256=digest, **options)

    def test_retained_container_requires_exact_current_member_proof(self):
        provenance = self.inventory["members"][0]["provenance"]
        provenance["source_dat_sha256"] = "2" * 64
        with self.assertRaisesRegex(ValueError, "exact-current-member proof"):
            self.build()
        provenance["current_member_identity_proof"] = {
            "kind": "EXACT_CURRENT523_MEMBER_SHA256",
            "member_sha256": provenance["expected_member_sha256"],
            "current_index_sha256": "3" * 64,
        }
        result = self.build()
        self.assertEqual(result["tiles"][0]["provenance"], provenance)
        changed = copy.deepcopy(provenance)
        changed["current_member_identity_proof"]["member_sha256"] = "4" * 64
        with self.assertRaises(ValueError):
            pack.provenance_for(changed, provenance["expected_member_sha256"])

    def test_flexible_subset_whole_inventory_identity_and_coverage_alpha(self):
        self.inventory["members"][1]["availability"] = "missing"
        manifest = self.build(tile_ids=[0])
        self.assertEqual(manifest["source_count"], 1)
        self.assertEqual(manifest["input_source_count"], 2)
        rows = pack.load_inventory(self.root / "inventory.json", manifest["input_inventory_sha256"])
        self.assertEqual(manifest["input_source_inventory_sha256"], raw_ti2.source_inventory(list(rows.values())))
        self.assertNotEqual(manifest["input_source_inventory_sha256"], manifest["source_inventory_sha256"])
        self.assertNotIn("land_id", manifest)
        self.assertNotIn("asset_path", manifest)
        tile = manifest["tiles"][0]
        self.assertEqual(tile["raw_header_u32"], 0x80001100)
        self.assertEqual(tile["provenance"]["edition"], "LineageM")
        with Image.open(self.root / "output" / tile["atlas_path"]) as image:
            self.assertEqual(image.getpixel((1, 2)), (0, 0, 0, 255))
            self.assertEqual(image.getpixel((2, 2)), (255, 255, 255, 255))
            self.assertEqual(image.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual((self.root / "output" / tile["original_path"]).read_bytes(), (self.source / tile["member"]).read_bytes())
        self.assertEqual((self.root / "output" / tile["original_path"]).stat().st_ino, (self.source / tile["member"]).stat().st_ino)

    def test_default_png_and_explicit_png_serialize_identically(self):
        default = self.build()
        explicit = self.build(output=self.root / "explicit", atlas_storage="png")
        self.assertEqual(default, explicit)
        self.assertNotIn("atlas_storage", default)
        self.assertEqual((self.root / "output" / pack.MANIFEST_NAME).read_bytes(),
                         (self.root / "explicit" / pack.MANIFEST_NAME).read_bytes())
        self.assertEqual(list(default), ["schema", "kind", "edition", "cumulative_version", "source_root",
            "source_count", "input_source_count", "input_inventory_sha256", "input_source_inventory_sha256",
            "source_inventory_sha256", "atlas_rgba_inventory_sha256", "raw_model_inventory_sha256", "status",
            "semantics", "raw_decoded_roundtrip", "tiles", "delivery_status"])

    def test_runtime_storage_contains_only_originals_manifest_and_fresh_rgba_evidence(self):
        png_manifest = self.build(output=self.root / "png")
        with mock.patch.object(pack.Image, "fromarray", side_effect=AssertionError("Runtime storage saved a PNG")):
            manifest = self.build(atlas_storage="runtime_ti2")
        self.assertEqual(manifest["atlas_storage"], "runtime_ti2")
        self.assertFalse((self.root / "output/atlases").exists())
        self.assertEqual(sorted(path.relative_to(self.root / "output").as_posix()
                                for path in (self.root / "output").rglob("*") if path.is_file()),
                         ["originals/Tile/0.ti2", "originals/Tile/1.ti2", pack.MANIFEST_NAME])
        for row, png in zip(manifest["tiles"], png_manifest["tiles"]):
            self.assertEqual(row, {key: value for key, value in png.items() if key not in pack.PNG_FIELDS})
            original = self.root / "output" / row["original_path"]
            self.assertEqual(original.stat().st_ino, (self.source / row["member"]).stat().st_ino)
            decoded = raw_ti2.strict_decompress(original.read_bytes())
            raw = raw_ti2.parse_ti2(decoded)
            self.assertEqual(raw_ti2.write_ti2(raw), decoded)
            self.assertEqual(row["atlas_rgba_sha256"], raw_ti2.sha256(raw_ti2.render_atlas(raw).tobytes()))
        expected = copy.deepcopy(png_manifest)
        expected["atlas_storage"] = "runtime_ti2"
        expected["tiles"] = manifest["tiles"]
        self.assertEqual(manifest, expected)
        self.assertEqual(pack.validate_manifest(manifest), manifest)

    def test_whole_inventory_sha_is_mandatory_and_duplicate_json_rejects(self):
        path, digest = write_inventory(self.root, self.inventory)
        for value in (None, "", "0" * 64):
            with self.subTest(pin=value), self.assertRaises(ValueError):
                pack.load_inventory(path, value)
        path.write_text('{"schema":1,"schema":1}')
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            pack.load_inventory(path, raw_ti2.sha256(path.read_bytes()))
        self.assertFalse((self.root / "output").exists())

    def test_version_edition_retention_and_exact_member_provenance_are_required(self):
        changes = [("snapshot_version", 508), ("snapshot_version", True), ("edition", "PC"),
                   ("edition", None), ("current_selection_verified", False), ("selection_version", 524),
                   ("source_dat_sha256", "2" * 64), ("expected_member_sha256", "2" * 64),
                   ("container", "Client/Data/../Tile1.dat")]
        for storage in pack.ATLAS_STORAGES:
            for key, value in changes:
                altered = copy.deepcopy(self.inventory)
                altered["members"][0]["provenance"][key] = value
                with self.subTest(storage=storage, key=key, value=value), self.assertRaises(ValueError):
                    self.build(altered, atlas_storage=storage)
        for key, value in (("edition", "PC"), ("cumulative_version", 508), ("schema", True)):
            altered = copy.deepcopy(self.inventory)
            altered[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): self.build(altered)

    def test_literal_paths_duplicate_ids_and_missing_selection_reject(self):
        for member in ("Tile/01.ti2", "Tile/../0.ti2", "Tile/0.TI2", "Tile/16777216.ti2"):
            altered = copy.deepcopy(self.inventory)
            altered["members"][0]["member"] = member
            with self.subTest(member=member), self.assertRaises(ValueError): self.build(altered)
        altered = copy.deepcopy(self.inventory)
        altered["members"].append(altered["members"][0])
        with self.assertRaisesRegex(ValueError, "Duplicate"): self.build(altered)
        self.inventory["members"][0]["availability"] = "missing"
        with self.assertRaisesRegex(ValueError, "missing"): self.build()
        self.assertFalse((self.root / "output").exists())

    def test_original_hash_and_strict_brotli_reject_before_atomic_publication(self):
        source = self.source / "Tile/0.ti2"
        encoded = source.read_bytes()
        source.write_bytes(encoded[:-1])
        with self.assertRaisesRegex(ValueError, "sized"): self.build()
        for bad in (encoded[:-1], encoded + b"tail", encoded + encoded):
            source.write_bytes(bad)
            altered = copy.deepcopy(self.inventory)
            row = altered["members"][0]
            row.update(bytes=len(bad), sha256=raw_ti2.sha256(bad))
            row["provenance"]["expected_member_sha256"] = row["sha256"]
            for storage in pack.ATLAS_STORAGES:
                with self.subTest(storage=storage, size=len(bad)), self.assertRaisesRegex(ValueError, "Brotli"):
                    self.build(altered, atlas_storage=storage)
        self.assertFalse((self.root / "output").exists())
        self.assertEqual(list(self.root.glob(".output.staging-*")), [])

    def test_symlink_and_git_output_reject_originals_preserved(self):
        source = self.source / "Tile/0.ti2"
        encoded = source.read_bytes()
        other = self.root / "elsewhere.ti2"
        other.write_bytes(encoded)
        source.unlink()
        source.symlink_to(other)
        with self.assertRaisesRegex(ValueError, "Symlink"): self.build()
        source.unlink()
        source.write_bytes(encoded)
        repo = self.root / "repository"
        (repo / ".git").mkdir(parents=True)
        (repo / ".git/HEAD").write_text("ref: refs/heads/test\n")
        with self.assertRaisesRegex(ValueError, "Git repository"): self.build(output=repo / "pack")
        with self.assertRaisesRegex(ValueError, "outside"): self.build(output=self.source / "pack")
        self.assertEqual(source.read_bytes(), encoded)

    def test_selective_reuse_checks_raw_png_rgba_and_links_only_selected_pair(self):
        baseline = self.build(output=self.root / "baseline")
        # A pinned same-semantics old review manifest supplies the reuse API.
        reuse_manifest = self.root / "baseline/tiles523.json"
        reuse_manifest.write_text(json.dumps(baseline))
        pin = raw_ti2.sha256(reuse_manifest.read_bytes())
        for row in self.inventory["members"]: (self.source / row["member"]).unlink()
        manifest = self.build(tile_ids=[1], reuse_pack=self.root / "baseline", expected_reuse_manifest_sha256=pin)
        self.assertEqual(len(manifest["tiles"]), 1)
        self.assertFalse((self.root / "output/atlases/0.png").exists())
        for path in ("atlases/1.png", "originals/Tile/1.ti2"):
            self.assertEqual((self.root / "output" / path).stat().st_ino, (self.root / "baseline" / path).stat().st_ino)
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.build(tile_ids=[1], reuse_pack=self.root / "baseline", expected_reuse_manifest_sha256=pin)

    def test_reuse_requires_caller_pin_and_fresh_rgba_match(self):
        baseline = self.build(output=self.root / "baseline")
        reuse_manifest = self.root / "baseline/tiles523.json"
        reuse_manifest.write_text(json.dumps(baseline))
        with self.assertRaises(ValueError): self.build(reuse_pack=self.root / "baseline")
        image = Image.new("RGBA", (384, 384), (255, 0, 0, 255))
        png = self.root / "baseline/atlases/0.png"
        image.save(png)
        row = baseline["tiles"][0]
        row.update(atlas_bytes=png.stat().st_size, atlas_sha256=raw_ti2.sha256(png.read_bytes()),
                   atlas_rgba_sha256=raw_ti2.sha256(image.tobytes()))
        reuse_manifest.write_text(json.dumps(baseline))
        pin = raw_ti2.sha256(reuse_manifest.read_bytes())
        for storage in pack.ATLAS_STORAGES:
            with self.subTest(storage=storage), self.assertRaisesRegex(ValueError, "fresh coverage"):
                self.build(tile_ids=[0], reuse_pack=self.root / "baseline",
                           expected_reuse_manifest_sha256=pin, atlas_storage=storage)
        self.assertFalse((self.root / "output").exists())

    def test_runtime_storage_reuses_verified_png_pack_without_linking_pngs(self):
        self.build(output=self.root / "baseline")
        baseline = self.root / "baseline"
        before = {path.relative_to(baseline).as_posix(): path.read_bytes()
                  for path in baseline.rglob("*") if path.is_file()}
        pin = raw_ti2.sha256(before[pack.MANIFEST_NAME])
        for row in self.inventory["members"]: (self.source / row["member"]).unlink()
        with mock.patch.object(pack, "_copy_verified", wraps=pack._copy_verified) as copied:
            manifest = self.build(tile_ids=[1], reuse_pack=baseline, expected_reuse_manifest_sha256=pin,
                                  reuse_manifest_name=pack.MANIFEST_NAME, atlas_storage="runtime_ti2")
        self.assertEqual(copied.call_count, 1)
        self.assertEqual(copied.call_args.args[0], baseline / "originals/Tile/1.ti2")
        self.assertFalse((self.root / "output/atlases").exists())
        self.assertEqual((self.root / "output/originals/Tile/1.ti2").stat().st_ino,
                         (baseline / "originals/Tile/1.ti2").stat().st_ino)
        self.assertEqual(manifest["source_count"], 1)
        self.assertEqual(before, {path.relative_to(baseline).as_posix(): path.read_bytes()
                                  for path in baseline.rglob("*") if path.is_file()})

    def test_runtime_storage_still_verifies_exact_reuse_png_bytes_and_decoded_rgba(self):
        baseline = self.build(output=self.root / "baseline")
        reuse_manifest = self.root / "baseline" / pack.MANIFEST_NAME
        png = self.root / "baseline/atlases/0.png"
        original_png = png.read_bytes()
        for failure in ("hash", "rgba"):
            altered = copy.deepcopy(baseline)
            row = altered["tiles"][0]
            if failure == "hash":
                row["atlas_sha256"] = "0" * 64
                message = "byte hash"
            else:
                Image.new("RGBA", (384, 384), (255, 0, 0, 255)).save(png)
                row.update(atlas_bytes=png.stat().st_size, atlas_sha256=raw_ti2.sha256(png.read_bytes()))
                message = "decoded RGBA"
            reuse_manifest.write_text(json.dumps(altered))
            pin = raw_ti2.sha256(reuse_manifest.read_bytes())
            with self.subTest(failure=failure), self.assertRaisesRegex(ValueError, message):
                self.build(tile_ids=[0], reuse_pack=self.root / "baseline", expected_reuse_manifest_sha256=pin,
                           reuse_manifest_name=pack.MANIFEST_NAME, atlas_storage="runtime_ti2")
            png.write_bytes(original_png)
            self.assertFalse((self.root / "output").exists())

    def test_runtime_pack_reuse_can_render_png_or_keep_runtime_storage(self):
        baseline = self.build(output=self.root / "baseline", atlas_storage="runtime_ti2")
        encoded = (self.root / "baseline" / pack.MANIFEST_NAME).read_bytes()
        pin = raw_ti2.sha256(encoded)
        for row in self.inventory["members"]: (self.source / row["member"]).unlink()
        for storage in pack.ATLAS_STORAGES:
            output = self.root / storage
            manifest = self.build(output=output, reuse_pack=self.root / "baseline",
                expected_reuse_manifest_sha256=pin, reuse_manifest_name=pack.MANIFEST_NAME, atlas_storage=storage)
            self.assertEqual(manifest["atlas_rgba_inventory_sha256"], baseline["atlas_rgba_inventory_sha256"])
            for row in manifest["tiles"]:
                self.assertEqual((output / row["original_path"]).stat().st_ino,
                                 (self.root / "baseline" / row["original_path"]).stat().st_ino)
                if storage == "png":
                    raw_ti2.verify_atlas_png(output / row["atlas_path"], row["atlas_sha256"], row["atlas_rgba_sha256"])
            self.assertEqual((output / "atlases").exists(), storage == "png")
        self.assertEqual((self.root / "baseline" / pack.MANIFEST_NAME).read_bytes(), encoded)

    def test_runtime_reuse_rejects_raw_or_rgba_evidence_and_can_use_source_original(self):
        baseline = self.build(output=self.root / "baseline", atlas_storage="runtime_ti2")
        reuse_manifest = self.root / "baseline" / pack.MANIFEST_NAME
        for key in ("decoded_sha256", "atlas_rgba_sha256"):
            altered = copy.deepcopy(baseline)
            altered["tiles"][0][key] = "0" * 64
            reuse_manifest.write_text(json.dumps(altered))
            pin = raw_ti2.sha256(reuse_manifest.read_bytes())
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "fresh"):
                self.build(reuse_pack=self.root / "baseline", expected_reuse_manifest_sha256=pin,
                           reuse_manifest_name=pack.MANIFEST_NAME, atlas_storage="runtime_ti2")
        reuse_manifest.write_text(json.dumps(baseline))
        pin = raw_ti2.sha256(reuse_manifest.read_bytes())
        (self.root / "baseline/originals/Tile/0.ti2").unlink()
        self.build(reuse_pack=self.root / "baseline", expected_reuse_manifest_sha256=pin,
                   reuse_manifest_name=pack.MANIFEST_NAME, atlas_storage="runtime_ti2")
        self.assertEqual((self.root / "output/originals/Tile/0.ti2").stat().st_ino,
                         (self.source / "Tile/0.ti2").stat().st_ino)

    def test_generic_pack_reuse_uses_its_exact_pinned_manifest_and_preserves_files(self):
        self.build(output=self.root / "baseline")
        encoded = (self.root / "baseline" / pack.MANIFEST_NAME).read_bytes()
        pin = raw_ti2.sha256(encoded)
        for row in self.inventory["members"]: (self.source / row["member"]).unlink()
        self.build(reuse_pack=self.root / "baseline", expected_reuse_manifest_sha256=pin,
                   reuse_manifest_name=pack.MANIFEST_NAME)
        for row in self.inventory["members"]:
            tile_id = raw_ti2.member_id(row["member"])
            for relative in ("originals/" + row["member"], f"atlases/{tile_id}.png"):
                self.assertEqual((self.root / "baseline" / relative).stat().st_ino,
                                 (self.root / "output" / relative).stat().st_ino)
        self.assertEqual((self.root / "baseline" / pack.MANIFEST_NAME).read_bytes(), encoded)
        with self.assertRaisesRegex(ValueError, "literal reuse manifest"):
            self.build(output=self.root / "unsafe", reuse_pack=self.root / "baseline",
                       expected_reuse_manifest_sha256=pin, reuse_manifest_name="../tilepack523.json")

    def test_hardlink_failure_does_not_silently_copy_or_publish(self):
        original = (self.source / "Tile/0.ti2").read_bytes()
        with mock.patch.object(pack.os, "link", side_effect=OSError(errno.EXDEV, "synthetic cross-device link")):
            with self.assertRaises(OSError): self.build()
        self.assertFalse((self.root / "output").exists())
        self.assertEqual(list(self.root.glob(".output.staging-*")), [])
        self.assertEqual((self.source / "Tile/0.ti2").read_bytes(), original)
        self.build(hardlink_reuse=False)
        self.assertNotEqual((self.root / "output/originals/Tile/0.ti2").stat().st_ino,
                            (self.source / "Tile/0.ti2").stat().st_ino)

    def test_generic_metadata_bound_and_nonfinite_json(self):
        path = self.root / "large-metadata.json"
        # Full8513 source/reuse manifests exceed the previous24MiB limit.
        path.write_bytes(b'{"proof":"' + b"x" * (24 * 1024 * 1024) + b'"}')
        value, encoded = pack._json(path)
        self.assertEqual(len(value["proof"]), 24 * 1024 * 1024)
        self.assertEqual(len(encoded), path.stat().st_size)
        self.assertEqual(pack.MAX_METADATA_BYTES, 64 * 1024 * 1024)
        for number in (b"NaN", b"Infinity", b"-Infinity", b"1e999", b"-1e999"):
            path.write_bytes(b'{"proof":' + number + b'}')
            with self.subTest(number=number), self.assertRaisesRegex(ValueError, "Non-finite"):
                pack._json(path)
        with mock.patch.object(pack, "MAX_METADATA_BYTES", 8):
            with self.assertRaisesRegex(ValueError, "bounded"): pack._json(path)

    def test_physical_partial_atlas_count_preserves_header_and_no_extra_frames(self):
        from test_current523_tile_review import decoded_fixture, compress
        blocks = [{"flags":0,"offset":(0,0),"runs":(),"pixels":b""} for _ in range(60)]
        blocks[0] = {"flags":65,"offset":(0,0),"runs":(),"pixels":bytes([3])*288}
        encoded = compress(decoded_fixture(blocks=blocks))
        original = self.source / "Tile/0.ti2"
        original.write_bytes(encoded)
        inventory = copy.deepcopy(self.inventory)
        row = inventory["members"][0]
        row["bytes"] = len(encoded)
        row["sha256"] = raw_ti2.sha256(encoded)
        row["provenance"]["expected_member_sha256"] = row["sha256"]
        (self.root / "partial").mkdir()
        path, digest = write_inventory(self.root / "partial", inventory)
        output = self.root / "partial-runtime"
        result = pack.build_pack(self.source, path, output, expected_inventory_sha256=digest, tile_ids=[0], atlas_storage="runtime_ti2")
        self.assertEqual(result["tiles"][0]["blocks"],60)
        self.assertEqual(result["tiles"][0]["raw_header_u32"] & 4095,60)
        self.assertEqual(result["tiles"][0]["raw_sections"]["flags"]["bytes"],60)
        self.assertFalse((output / "atlases").exists())
        self.assertEqual((output / "originals/Tile/0.ti2").read_bytes(),encoded)
        bad = copy.deepcopy(result)
        bad["tiles"][0]["blocks"] = 256
        with self.assertRaises(ValueError): pack.validate_manifest(bad)

    def test_manifest_raw_metadata_counts_paths_and_digests_reject(self):
        manifest = self.build()
        changes = [("source_count", True), ("source_count", 1), ("input_source_inventory_sha256", ""),
                   ("input_source_inventory_sha256", "2" * 64),
                   ("raw_decoded_roundtrip", 1), ("edition", "PC")]
        for key, value in changes:
            altered = copy.deepcopy(manifest)
            altered[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): pack.validate_manifest(altered)
        for key, value in (("atlas_bytes", 2 * 1024 * 1024 + 1), ("original_path", "../Tile/0.ti2"),
                           ("raw_header_u32", 256), ("atlas_size", [384.0, 384]), ("source_bytes", True)):
            altered = copy.deepcopy(manifest)
            altered["tiles"][0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): pack.validate_manifest(altered)
        altered = copy.deepcopy(manifest)
        altered["tiles"][0]["raw_sections"]["flags"]["offset"] += 1
        with self.assertRaisesRegex(ValueError, "contiguous"): pack.validate_manifest(altered)

    def test_storage_identity_and_runtime_png_fields_reject_in_build_manifest_and_reuse(self):
        manifest = self.build(atlas_storage="runtime_ti2")
        for storage in ("", "PNG", "ti2", None, True, [], {}):
            altered = copy.deepcopy(manifest)
            altered["atlas_storage"] = storage
            with self.subTest(storage=storage), self.assertRaisesRegex(ValueError, "storage"):
                pack.validate_manifest(altered)
            with self.subTest(build_storage=storage), self.assertRaisesRegex(ValueError, "storage"):
                self.build(output=self.root / "invalid", atlas_storage=storage)
        for key in pack.PNG_FIELDS:
            altered = copy.deepcopy(manifest)
            altered["tiles"][0][key] = None
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, "stored PNG fields"):
                pack.validate_manifest(altered)
        for storage in (None, "png"):
            altered = copy.deepcopy(manifest)
            if storage is None:
                altered.pop("atlas_storage")
            else:
                altered["atlas_storage"] = storage
            with self.subTest(storage=storage), self.assertRaisesRegex(ValueError, "PNG path"):
                pack.validate_manifest(altered)
        for key, value in (("atlas_storage", "zip"), ("atlas_storage", "png")):
            altered = copy.deepcopy(manifest)
            altered[key] = value
            path = self.root / "output" / pack.MANIFEST_NAME
            path.write_text(json.dumps(altered))
            pin = raw_ti2.sha256(path.read_bytes())
            with self.subTest(reuse_storage=value), self.assertRaises(ValueError):
                self.build(output=self.root / "invalid", reuse_pack=self.root / "output",
                           expected_reuse_manifest_sha256=pin, reuse_manifest_name=pack.MANIFEST_NAME)


if __name__ == "__main__":
    unittest.main()
