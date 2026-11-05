#!/usr/bin/env python3
"""Public-ready rejection tests using synthetic metadata and opaque bytes only."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "tools/images/audit_source523_image_inputs.py"
MODULE_SPEC = importlib.util.spec_from_file_location("source_image_intake", MODULE_PATH)
if MODULE_SPEC is None or MODULE_SPEC.loader is None:
    raise RuntimeError("Cannot load intake verifier")
audit = importlib.util.module_from_spec(MODULE_SPEC)
sys.modules[MODULE_SPEC.name] = audit
MODULE_SPEC.loader.exec_module(audit)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inventory_row(
    member: str = "Image/Example/sample.png",
    *,
    history: bool = False,
    encrypted_bytes: int = 32,
    plain_bytes: int = 24,
) -> dict:
    """Metadata is synthetic; no image is generated or decoded."""
    return {
        "container": "Client/Data/Image1.dat",
        "path": member,
        "encrypted_bytes": encrypted_bytes,
        "plain_bytes": plain_bytes,
        "sha256": digest(b"synthetic declared leaf identity"),
        "format": "PNG",
        "width": 4,
        "height": 3,
        "current523_alignment": "retained_container_size_sha1_identical",
        "historical_card_pack_lineage": history,
        "relative_output_path": "decoded/" + member,
        "category": "Image/Example",
    }


def inventory_totals(rows: list[dict]) -> dict:
    target = [row for row in rows if row["historical_card_pack_lineage"] is False]
    return {
        "known_files": len(rows),
        "known_encrypted_bytes": sum(row["encrypted_bytes"] for row in rows),
        "known_plain_bytes": sum(row["plain_bytes"] for row in rows),
        "target_files": len(target),
        "target_encrypted_bytes": sum(row["encrypted_bytes"] for row in target),
        "target_plain_bytes": sum(row["plain_bytes"] for row in target),
    }


class AuditCase(unittest.TestCase):
    def assert_rejected(self, call, *args, **kwargs):
        with self.assertRaises(audit.AuditError) as caught:
            call(*args, **kwargs)
        self.assertIsInstance(caught.exception.code, str)
        self.assertTrue(caught.exception.code)
        return caught.exception


class RelativePathTests(AuditCase):
    def test_relative_path_is_preserved(self):
        self.assertEqual(audit.safe_relative("folder/payload.bin"), "folder/payload.bin")

    def test_unsafe_relative_paths_are_rejected(self):
        for value in (
            "",
            ".",
            "..",
            "../payload.bin",
            "folder/../payload.bin",
            "folder/./payload.bin",
            "/payload.bin",
            "folder//payload.bin",
            "folder\\payload.bin",
            "C:/payload.bin",
            "payload\x00.bin",
        ):
            with self.subTest(value=value):
                self.assert_rejected(audit.safe_relative, value)


class ManifestTests(AuditCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.payload = b"opaque synthetic input, not an image"
        (self.root / "payload.bin").write_bytes(self.payload)
        self.entry = {
            "path": "payload.bin",
            "bytes": len(self.payload),
            "sha256": digest(self.payload),
        }

    def manifest(self, entries: list[dict]):
        (self.root / "MANIFEST.json").write_text(
            json.dumps({"files": entries}), encoding="utf-8"
        )

    def test_manifest_accepts_matching_opaque_payload(self):
        self.manifest([self.entry])
        result = audit.verify_manifest(self.root, expected_count=1)
        self.assertEqual(result["payload_files"], 1)
        self.assertEqual(result["payload_bytes"], len(self.payload))

    def test_tampered_payload_is_rejected(self):
        self.manifest([self.entry])
        (self.root / "payload.bin").write_bytes(b"different opaque source bytes")
        self.assert_rejected(audit.verify_manifest, self.root, expected_count=1)

    def test_same_size_tampered_payload_is_rejected(self):
        self.manifest([self.entry])
        altered = bytes([self.payload[0] ^ 1]) + self.payload[1:]
        (self.root / "payload.bin").write_bytes(altered)
        self.assert_rejected(audit.verify_manifest, self.root, expected_count=1)

    def test_duplicate_manifest_path_is_rejected(self):
        self.manifest([self.entry, dict(self.entry)])
        self.assert_rejected(audit.verify_manifest, self.root, expected_count=2)

    def test_manifest_traversal_is_rejected(self):
        entry = dict(self.entry, path="../payload.bin")
        self.manifest([entry])
        self.assert_rejected(audit.verify_manifest, self.root, expected_count=1)

    def test_manifest_member_symlink_is_rejected(self):
        alias = self.root / "alias.bin"
        alias.symlink_to("payload.bin")
        self.manifest([dict(self.entry, path="alias.bin")])
        self.assert_rejected(audit.verify_manifest, self.root, expected_count=1)

    def test_manifest_parent_directory_symlink_is_rejected(self):
        actual = self.root / "actual"
        actual.mkdir()
        (actual / "payload.bin").write_bytes(self.payload)
        (self.root / "alias").symlink_to("actual", target_is_directory=True)
        self.manifest([dict(self.entry, path="alias/payload.bin")])
        self.assert_rejected(audit.verify_manifest, self.root, expected_count=1)

    def test_manifest_file_symlink_is_rejected(self):
        self.manifest([self.entry])
        (self.root / "MANIFEST.json").rename(self.root / "manifest-real.json")
        (self.root / "MANIFEST.json").symlink_to("manifest-real.json")
        self.assert_rejected(audit.verify_manifest, self.root, expected_count=1)

    def test_manifest_count_mismatch_is_rejected(self):
        self.manifest([self.entry])
        self.assert_rejected(audit.verify_manifest, self.root, expected_count=2)


class InventoryTests(AuditCase):
    def test_expected_override_accepts_small_metadata_inventory(self):
        rows = [inventory_row(), inventory_row("Image/Example/history.png", history=True)]
        result = audit.validate_inventory(rows, expected=inventory_totals(rows))
        self.assertEqual(result["totals"], inventory_totals(rows))
        self.assertEqual(result["target_rows"], rows[:1])
        self.assertEqual(result["known_container_count"], 1)

    def test_default_fixed_denominator_rejects_small_inventory(self):
        self.assert_rejected(audit.validate_inventory, [inventory_row()])

    def test_duplicate_inventory_identity_is_rejected(self):
        rows = [inventory_row(), inventory_row()]
        self.assert_rejected(audit.validate_inventory, rows, expected=inventory_totals(rows))

    def test_same_path_in_different_container_is_rejected(self):
        first = inventory_row()
        second = dict(first, container="Client/Data/Image2.dat")
        rows = [first, second]
        self.assert_rejected(audit.validate_inventory, rows, expected=inventory_totals(rows))

    def test_inventory_member_traversal_is_rejected(self):
        row = inventory_row("Image/../sample.png")
        self.assert_rejected(audit.validate_inventory, [row], expected=inventory_totals([row]))

    def test_inventory_container_traversal_is_rejected(self):
        row = dict(inventory_row(), container="../Image1.dat")
        self.assert_rejected(audit.validate_inventory, [row], expected=inventory_totals([row]))

    def test_inventory_decoded_path_traversal_is_rejected(self):
        row = dict(inventory_row(), relative_output_path="decoded/../sample.png")
        self.assert_rejected(audit.validate_inventory, [row], expected=inventory_totals([row]))

    def test_non_boolean_history_flags_are_rejected(self):
        for value in (0, 1, "false", "true", None):
            with self.subTest(value=value):
                row = dict(inventory_row(), historical_card_pack_lineage=value)
                expected = inventory_totals([inventory_row()])
                self.assert_rejected(audit.validate_inventory, [row], expected=expected)

    def test_tampered_history_changes_target_denominator_and_is_rejected(self):
        row = inventory_row()
        expected = inventory_totals([row])
        row["historical_card_pack_lineage"] = True
        self.assert_rejected(audit.validate_inventory, [row], expected=expected)

    def test_tampered_inventory_byte_totals_are_rejected(self):
        row = inventory_row()
        expected = inventory_totals([row])
        row["encrypted_bytes"] += 1
        self.assert_rejected(audit.validate_inventory, [row], expected=expected)

    def test_boolean_byte_count_is_rejected(self):
        row = inventory_row()
        expected = inventory_totals([row])
        row["encrypted_bytes"] = True
        self.assert_rejected(audit.validate_inventory, [row], expected=expected)


class ContainerCopyTests(AuditCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.payload = b"opaque source container bytes"
        self.spec = {"bytes": len(self.payload), "sha256": digest(self.payload)}
        self.first = self.root / "first.dat"
        self.first.write_bytes(self.payload)

    def test_missing_container_is_reported_as_missing(self):
        self.assertIsNone(audit.verify_copies("Client/Data/Image1.dat", [], self.spec))

    def test_identical_supplied_copies_are_one_logical_result(self):
        second = self.root / "second.dat"
        second.write_bytes(self.payload)
        result = audit.verify_copies(
            "Client/Data/Image1.dat", [self.first, second, self.first], self.spec
        )
        self.assertEqual(result["container"], "Client/Data/Image1.dat")
        self.assertEqual(result["copy_count"], 2)
        self.assertEqual(len(set(result["local_paths"])), 2)
        self.assertEqual(result["bytes"], len(self.payload))
        self.assertEqual(result["sha256"], self.spec["sha256"])

    def test_conflicting_supplied_copies_are_rejected(self):
        second = self.root / "second.dat"
        second.write_bytes(b"conflicting source container")
        self.assert_rejected(
            audit.verify_copies,
            "Client/Data/Image1.dat",
            [self.first, second],
            self.spec,
        )

    def test_same_size_conflicting_supplied_copies_are_rejected(self):
        second = self.root / "second.dat"
        second.write_bytes(bytes([self.payload[0] ^ 1]) + self.payload[1:])
        self.assert_rejected(
            audit.verify_copies,
            "Client/Data/Image1.dat",
            [self.first, second],
            self.spec,
        )

    def test_container_hash_mismatch_is_rejected(self):
        spec = dict(self.spec, sha256=digest(b"another original container"))
        self.assert_rejected(
            audit.verify_copies, "Client/Data/Image1.dat", [self.first], spec
        )

    def test_container_optional_sha1_mismatch_is_rejected(self):
        spec = dict(self.spec, sha1=hashlib.sha1(b"another original container").hexdigest())
        self.assert_rejected(
            audit.verify_copies, "Client/Data/Image1.dat", [self.first], spec
        )

    def test_container_symlink_is_rejected(self):
        alias = self.root / "alias.dat"
        alias.symlink_to(self.first.name)
        self.assert_rejected(
            audit.verify_copies, "Client/Data/Image1.dat", [alias], self.spec
        )


class CompactCatalogTests(AuditCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.row = inventory_row()
        self.container_sha = digest(b"synthetic opaque container identity")
        self.verified = [{
            "container": self.row["container"],
            "entries": 1,
            "verified_images": 1,
            "errors": 0,
            "sha256": self.container_sha,
            "outer_crc_verified": True,
        }]
        self.index = {
            "containers": [{
                "container": self.row["container"],
                "bytes": 89,
                "directory_offset": 64,
                "directory_bytes": 16,
                "entries": 1,
                "outer_crc_verified": True,
                "directory_padding_verified": True,
            }],
            "entries": [{
                "container": self.row["container"],
                "path": self.row["path"],
                "offset": 0,
                "size": self.row["encrypted_bytes"],
            }],
            "errors": [],
        }

    def write_catalog(self):
        (self.root / "containers_verified.json").write_text(
            json.dumps(self.verified), encoding="utf-8"
        )
        (self.root / "index_catalog.json").write_text(
            json.dumps(self.index), encoding="utf-8"
        )

    def verify(self, base_rows=None):
        self.write_catalog()
        return audit.verify_catalog(
            self.root,
            {"rows": [self.row]},
            [dict(self.row)] if base_rows is None else base_rows,
        )

    def test_catalog_accepts_one_container_and_one_declared_leaf(self):
        result = self.verify()
        self.assertEqual(result["verified_container_rows"], 1)
        self.assertEqual(result["verified_index_members"], 1)
        self.assertEqual(result["qualified_retained_containers"], 1)
        self.assertEqual(result["specs"], {
            self.row["container"]: {"bytes": 89, "sha256": self.container_sha}
        })

    def test_catalog_encrypted_member_size_tamper_is_rejected(self):
        self.index["entries"][0]["size"] += 1
        self.assert_rejected(self.verify)

    def test_catalog_duplicate_index_member_is_rejected(self):
        self.index["entries"].append(dict(self.index["entries"][0]))
        self.assert_rejected(self.verify)

    def test_catalog_retained_and_base_leaf_hash_conflict_is_rejected(self):
        base = dict(self.row, sha256=digest(b"conflicting leaf identity"))
        self.assert_rejected(self.verify, base_rows=[base])


class OutputDirectoryTests(AuditCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_output_inside_checkout_with_git_head_is_rejected(self):
        checkout = self.root / "checkout"
        marker = checkout / ".git"
        marker.mkdir(parents=True)
        (marker / "HEAD").write_text("ref: refs/heads/main\n", encoding="utf-8")
        output = checkout / "private" / "report"
        self.assert_rejected(audit.output_directory, output)
        self.assertFalse(output.exists())

    def test_empty_git_placeholder_allows_private_output(self):
        workspace = self.root / "workspace"
        (workspace / ".git").mkdir(parents=True)
        output = workspace / "private" / "report"
        result = audit.output_directory(output)
        self.assertEqual(result, output)
        self.assertTrue(output.is_dir())

    def test_output_symlink_is_rejected(self):
        actual = self.root / "actual"
        actual.mkdir()
        output = self.root / "alias"
        output.symlink_to(actual.name, target_is_directory=True)
        self.assert_rejected(audit.output_directory, output)


if __name__ == "__main__":
    unittest.main()
