"""Synthetic AndroidUpdatePack fixtures for release-only startup proof staging."""
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

import startup_ota as ota


def write_pack(path, members):
    base = 112
    payload = bytearray()
    entries = bytearray(ota.INT32.pack(len(members)))
    for name, value in sorted(members.items()):
        raw = name.encode()
        padded = raw + b"\0" * (-len(raw) % 4)
        entries += ota.INT32.pack(len(padded)) + padded
        entries += ota.PACK_ENTRY.pack(len(payload), len(value), hashlib.md5(value, usedforsecurity=False).digest(), 0)
        payload += value
    header = ota.PACK_HEADER.pack(b"GDPC", 4, 4, 7, 2, 2, base, base + len(payload))
    path.write_bytes(header.ljust(base, b"\0") + payload + entries)


class StartupOtaTest(unittest.TestCase):
    def setUp(self):
        temp = TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.ticket_path = self.root / "ticket.json"
        self.final = self.root / "out.pck"
        self.previous = {"version_code": 945, "version_name": "523.945", "commit": "a" * 40, "compat_key": "b" * 64}
        self.info = {**self.previous, "version_code": 946, "version_name": "523.946", "commit": "c" * 40}
        self.runtime = {
            "scripts/boot/startup_bake_pack.gdc": b"compiled script",
            "data/original.json": b"{}",
            ota.PROJECT: b"project settings",
            ota.PIN: b'{"index_sha256":"unchanged"}',
            ota.BUILD_INFO: ota.encode({"schema": "twilight-build-info-v1", **self.info}),
        }
        self.plain = self.root / "baseline.pck"
        write_pack(self.plain, self.runtime)
        self.proof = {
            "schema": ota.REUSE_SCHEMA, "source": "d" * 64,
            "engine": "4.7.2-stable (official)|" + "e" * 40,
            "index_sha256": "", "files": {
                "equipment_rules": {"previous_key": "f" * 64, "key": "1" * 64, "sha256": "2" * 64, "bytes": 61},
            },
        }
        self.ticket = {
            "schema": ota.SCHEMA, "previous": {**self.previous, "pck_sha256": "3" * 64},
            "candidate": ota.runtime_identity(ota.read_pack(self.plain)),
            "proof_sha256": ota.digest(ota.encode(self.proof)), "proof": self.proof,
        }

    def export(self, modify_selected=False):
        def exporter(root, godot, target):
            members = self.runtime.copy()
            path = root / ota.PROOF
            if path.exists():
                members[ota.PROOF] = path.read_bytes()
                if modify_selected:
                    members["data/original.json"] = b'{"changed":true}'
            write_pack(target, members)

        with patch.object(ota, "export_godot", side_effect=exporter):
            return ota.export_ota(self.root, "godot", self.final, self.ticket_path)

    def test_includes_exact_approved_json_and_preserves_members(self):
        self.ticket_path.write_bytes(ota.encode(self.ticket))
        status = self.export()
        self.assertEqual(status["status"], "included")
        self.assertEqual(status["previous_version"], "523.945")
        self.assertEqual(status["proof_sha256"], self.ticket["proof_sha256"])
        self.assertEqual(ota.read_pack(self.final).metadata[ota.PROOF], ota.encode(self.proof))
        self.assertFalse((self.root / ota.PROOF).exists())

    def test_missing_and_stale_ticket_keep_identical_plain_bytes(self):
        self.assertEqual(self.export()["status"], "omitted")
        self.assertEqual(self.final.read_bytes(), self.plain.read_bytes())
        self.ticket["candidate"]["content_sha256"] = "0" * 64
        self.ticket_path.write_bytes(ota.encode(self.ticket))
        result = self.export()
        self.assertEqual(result["status"], "rejected")
        self.assertIn("candidate PCK contents differ", result["reason"])
        self.assertEqual(self.final.read_bytes(), self.plain.read_bytes())

    def test_wrong_hash_or_changed_export_falls_back_to_plain(self):
        self.ticket["proof_sha256"] = "0" * 64
        self.ticket_path.write_bytes(ota.encode(self.ticket))
        self.assertIn("proof SHA-256 does not match", self.export()["reason"])
        self.ticket["proof_sha256"] = ota.digest(ota.encode(self.proof))
        self.ticket_path.write_bytes(ota.encode(self.ticket))
        self.assertIn("exactly the verified proof", self.export(modify_selected=True)["reason"])
        self.assertFalse((self.root / ota.PROOF).exists())
        self.assertEqual(self.final.read_bytes(), self.plain.read_bytes())

    def test_release_feed_uses_the_actual_previous_pck_version_and_hash(self):
        pck = self.root / "official.pck"
        manifest = {"schema": "twilight-build-info-v1", **self.previous}
        write_pack(pck, {**self.runtime, ota.BUILD_INFO: ota.encode(manifest)})
        feed = self.root / "update.json"
        record = {"schema": "twilight-update-feed-v1", **self.previous, "sha256": ota.sha256(pck),
                  "size": pck.stat().st_size}
        feed.write_bytes(ota.encode(record))
        self.assertEqual(ota.official_identity(feed, pck)["version_code"], 945)
        record["sha256"] = "0" * 64
        feed.write_bytes(ota.encode(record))
        with self.assertRaisesRegex(ValueError, "official feed"):
            ota.official_identity(feed, pck)
        record.update(sha256=ota.sha256(pck), version_code=944, version_name="523.944")
        feed.write_bytes(ota.encode(record))
        with self.assertRaisesRegex(ValueError, "build identity"):
            ota.official_identity(feed, pck)

    def test_changed_runtime_member_or_compat_key_invalidates_ticket(self):
        for name, value in (
            ("data/original.json", b"changed data"),
            (ota.BUILD_INFO, ota.encode({"schema": "twilight-build-info-v1", **self.info, "compat_key": "0" * 64})),
        ):
            with self.subTest(name=name):
                write_pack(self.final, {**self.runtime, name: value})
                with self.assertRaises(ValueError):
                    ota.validate_ticket(self.ticket, ota.read_pack(self.final))
        write_pack(self.final, {**self.runtime, ota.BUILD_INFO: ota.encode({
            "schema": "twilight-build-info-v1", **self.info, "version_code": 947, "version_name": "523.947",
        })})
        self.assertEqual(ota.validate_ticket(self.ticket, ota.read_pack(self.final)), ota.encode(self.proof))

    def test_corrupt_pck_fails_member_scan(self):
        data = bytearray(self.plain.read_bytes())
        data[112] ^= 1
        self.final.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "corrupt Godot PCK member"):
            ota.read_pack(self.final)


if __name__ == "__main__":
    unittest.main()
