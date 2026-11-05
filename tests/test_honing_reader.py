"""Synthetic schema/ownership boundaries; never original-content execution proof."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import warnings
import zipfile

SPEC = importlib.util.spec_from_file_location("honing_reader", Path(__file__).parents[1] / "tools/honing/read_owner_zip.py")
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)


def fixture():
    return {
        "ItemHoningEntity": [{"ID": 9001, "HoningID": 900, "ItemClassID": 901, "MinEnchant": 2}],
        "ItemHoningCost": [
            {"ID": 9002, "HoningID": 900, "Enchant": 2, "ItemClassID": 902, "Amount": 3},
            {"ID": 9003, "HoningID": 900, "Enchant": 2, "ItemClassID": 903, "Amount": 4}],
        "ItemHoningProbability": [{"ID": 9004, "HoningID": 900, "Enchant": 2, "Probability": 17}],
        "ItemHoningEpithet": [{"ID": 9005, "HoningID": 900, "Probability": 19, "DescID": 904}],
        "ItemHoningEpithetBonus": [{"ID": 9006, "EpithetID": 9005, "BonusID": 9007}],
        "Bonus": [{"ID": 9007, "BonusTypeID": 905, "Value": 1.25,
                   "BonusApplicationTypeID": 0, "BonusApplicationTargetID": 0}],
    }


def packed(tables=None, extra=None):
    tables = fixture() if tables is None else tables
    stream = io.BytesIO()
    evidence = {}
    with zipfile.ZipFile(stream, "w", compression=zipfile.ZIP_STORED) as archive:
        for name, rows in tables.items():
            body = b"\xef\xbb\xbf" + json.dumps({"rows": rows}, indent=2).replace("\n", "\r\n").encode()
            archive.writestr(f"content/{name}.json", body)
            if name != "Bonus":
                evidence[name] = (len(rows), hashlib.sha256(body).hexdigest())
        if extra:
            archive.writestr(*extra)
    return stream.getvalue(), evidence


class HoningReaderTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="honing-synthetic-")
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "fixture.zip"

    def read_fixture(self, data=None, evidence=None):
        if data is None:
            data, evidence = packed()
        self.path.write_bytes(data)
        return reader._read_archive(self.path, len(data), hashlib.sha256(data).hexdigest(), evidence)

    def test_bom_crlf_hashes_and_typed_join(self):
        result = self.read_fixture()
        link = result["epithet_bonus_links"][0]
        self.assertEqual(link["epithet"]["ID"], 9005)
        self.assertEqual(link["bonus"]["ID"], 9007)
        self.assertEqual(link["bonus"]["Value"], 1.25)
        self.assertFalse(result["execution_enabled"])

    def test_duplicate_cost_group_preserved_without_execution(self):
        result = reader.preview(self.read_fixture(), 9001, 2)
        self.assertEqual([r["ID"] for r in result["cost_rows"]], [9002, 9003])
        self.assertEqual(result["probability_rows"][0]["Probability"], 17)
        self.assertIn("cost_relation_unverified", result["blockers"])
        self.assertIn("probability_scale_unverified", result["blockers"])
        self.assertFalse(result["execution_enabled"])

    def test_missing_rows_are_blockers_not_free_attempts(self):
        result = reader.preview(self.read_fixture(), 9001, 1)
        self.assertIn("missing_cost_rows", result["blockers"])
        self.assertIn("missing_or_ambiguous_probability", result["blockers"])
        self.assertIn("below_source_minimum", result["blockers"])

    def test_ambiguous_probability_preserved_and_blocked(self):
        tables = fixture()
        duplicate = dict(tables["ItemHoningProbability"][0], ID=9999)
        tables["ItemHoningProbability"].append(duplicate)
        result = reader.preview(reader.join_definitions(tables), 9001, 2)
        self.assertEqual(len(result["probability_rows"]), 2)
        self.assertIn("missing_or_ambiguous_probability", result["blockers"])

    def test_roundtrip_cannot_enable_or_replace_join(self):
        definitions = self.read_fixture()
        for _ in range(5):
            definitions = json.loads(json.dumps(definitions))
            definitions["execution_enabled"] = True
            definitions["epithet_bonus_links"][0]["bonus"]["Value"] = 999
            result = reader.preview(definitions, 9001, 2)
            self.assertFalse(result["execution_enabled"])
            self.assertEqual(result["epithet_bonus_links"][0]["bonus"]["Value"], 1.25)

    def test_preview_does_not_alias_or_mutate(self):
        definitions = self.read_fixture()
        before = copy.deepcopy(definitions)
        result = reader.preview(definitions, 9001, 2)
        result["cost_rows"][0]["Amount"] = 777
        result["epithet_bonus_links"][0]["bonus"]["Value"] = 888
        self.assertEqual(definitions, before)

    def test_dangling_joins(self):
        for field in ("EpithetID", "BonusID"):
            with self.subTest(field=field):
                tables = fixture()
                tables["ItemHoningEpithetBonus"][0][field] = 999999
                with self.assertRaises(reader.SourceError):
                    reader.join_definitions(tables)

    def test_invalid_integer_types(self):
        for bad in (True, "900", 900.0, -1, 0, 2**60):
            with self.subTest(value=bad):
                tables = fixture()
                tables["ItemHoningEntity"][0]["HoningID"] = bad
                with self.assertRaises(reader.SourceError):
                    reader.join_definitions(tables)

    def test_duplicate_id_and_missing_field(self):
        tables = fixture()
        tables["ItemHoningCost"][1]["ID"] = 9002
        with self.assertRaises(reader.SourceError):
            reader.join_definitions(tables)
        tables = fixture()
        del tables["ItemHoningEntity"][0]["MinEnchant"]
        with self.assertRaises(reader.SourceError):
            reader.join_definitions(tables)

    def test_duplicate_json_keys_and_nonfinite(self):
        for raw in (b'{"rows":[],"rows":[]}', b'{"rows":[NaN]}', b'{"rows":null}', b'[]'):
            with self.subTest(raw=raw), self.assertRaises(reader.SourceError):
                reader.decode_table(raw, "ItemHoningEntity")

    def test_bonus_value_limits(self):
        for bad in (True, "1.25", 10**400):
            with self.subTest(value=str(bad)[:20]):
                tables = fixture()
                tables["Bonus"][0]["Value"] = bad
                with self.assertRaises(reader.SourceError):
                    reader.join_definitions(tables)

    def test_archive_size_hash_and_production_pin(self):
        data, evidence = packed()
        self.path.write_bytes(data)
        with self.assertRaisesRegex(reader.SourceError, "size mismatch"):
            reader.read_owner_zip(self.path)
        with self.assertRaisesRegex(reader.SourceError, "SHA256 mismatch"):
            reader._read_archive(self.path, len(data), "0" * 64, evidence)

    def test_table_hash_and_count(self):
        data, evidence = packed()
        broken = copy.deepcopy(evidence)
        broken["ItemHoningEntity"] = (1, "0" * 64)
        with self.assertRaisesRegex(reader.SourceError, "table SHA256"):
            self.read_fixture(data, broken)
        broken = copy.deepcopy(evidence)
        broken["ItemHoningEntity"] = (2, evidence["ItemHoningEntity"][1])
        with self.assertRaisesRegex(reader.SourceError, "table count"):
            self.read_fixture(data, broken)

    def test_crc_checks_unrelated_members_too(self):
        data, evidence = packed(extra=("unrelated.bin", b"unique_crc_payload"))
        data = data.replace(b"unique_crc_payload", b"broken_crc_payload")
        with self.assertRaisesRegex(reader.SourceError, "CRC mismatch"):
            self.read_fixture(data, evidence)

    def test_missing_required_member(self):
        tables = fixture()
        del tables["Bonus"]
        data, evidence = packed(tables)
        with self.assertRaisesRegex(reader.SourceError, "missing ZIP member"):
            self.read_fixture(data, evidence)

    def test_unsafe_duplicate_and_symlink_members(self):
        for name in ("../escape", "/absolute", "C:/drive", "bad\\path", "a//b"):
            with self.subTest(name=name), self.assertRaisesRegex(reader.SourceError, "unsafe ZIP path"):
                self.read_fixture(*packed(extra=(name, b"x")))
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            data, evidence = packed(extra=("content/Bonus.json", b"{}"))
        with self.assertRaisesRegex(reader.SourceError, "duplicate ZIP"):
            self.read_fixture(data, evidence)
        info = zipfile.ZipInfo("symlink")
        info.create_system = 3
        info.external_attr = 0o120777 << 16
        with self.assertRaisesRegex(reader.SourceError, "ZIP symlink"):
            self.read_fixture(*packed(extra=(info, b"target")))

    def test_leaf_symlink_rejected_and_no_extraction(self):
        self.read_fixture()
        link = self.path.parent / "link.zip"
        link.symlink_to(self.path)
        with self.assertRaises(OSError):
            reader.read_owner_zip(link)
        self.assertEqual(sorted(p.name for p in self.path.parent.iterdir()), ["fixture.zip", "link.zip"])


class OfficialReferenceTest(unittest.TestCase):
    def matching(self):
        tables = fixture()
        tables["ItemHoningEntity"][0]["MinEnchant"] = 7
        tables["ItemHoningCost"] = []
        tables["ItemHoningProbability"] = []
        # Synthetic IDs and a synthetic scale, never copied original rows.
        for enchant, percent in ((7, 7), (8, 15), (9, 33)):
            tables["ItemHoningProbability"].append({"ID": enchant, "HoningID": 900,
                "Enchant": enchant, "Probability": percent * 123})
            for offset, item, amount in ((0, 902, 1), (1, 903, 2)):
                tables["ItemHoningCost"].append({"ID": enchant * 10 + offset,
                    "HoningID": 900, "Enchant": enchant, "ItemClassID": item, "Amount": amount})
        return reader.join_definitions(tables)

    def test_reference_matching_does_not_enable_execution(self):
        definitions = self.matching()
        before = copy.deepcopy(definitions)
        result = reader.official_crosscheck(definitions, 9001, {902: "태고의 구", 903: "신화 연금석"}, False)
        self.assertTrue(all(row["costs_match_official"] for row in result["stages"]))
        self.assertEqual(result["candidate_probability_denominator"], 12300)
        self.assertIn("not_source_storage_confirmation", result["denominator_evidence"])
        self.assertFalse(result["execution_enabled"])
        self.assertIn("failure_transition_unverified", result["blockers"])
        self.assertIn("source_target_class_unverified", result["blockers"])
        self.assertEqual(definitions, before)

    def test_inconsistent_scale_is_not_normalized(self):
        definitions = self.matching()
        definitions["tables"]["ItemHoningProbability"][0]["Probability"] += 1
        result = reader.official_crosscheck(definitions, 9001, {})
        self.assertIsNone(result["candidate_probability_denominator"])
        self.assertIn("no_common_probability_scale", result["blockers"])

    def test_duplicate_cost_and_ambiguous_name_bindings(self):
        definitions = self.matching()
        duplicate = dict(definitions["tables"]["ItemHoningCost"][0], ID=999)
        definitions["tables"]["ItemHoningCost"].append(duplicate)
        result = reader.official_crosscheck(definitions, 9001, {902: "태고의 구", 903: "신화 연금석"})
        self.assertEqual(len(result["stages"][0]["source_cost_rows"]), 3)
        self.assertFalse(result["stages"][0]["costs_match_official"])
        result = reader.official_crosscheck(self.matching(), 9001, {902: "태고의 구", 903: "신화 연금석", 904: "태고의 구"})
        self.assertTrue(all(not row["costs_match_official"] for row in result["stages"]))

    def test_honed_unknown_state_and_no_invented_failure_policy(self):
        for state, blocker in ((True, "already_honed"), (None, "existing_honing_state_unverified")):
            result = reader.official_crosscheck(self.matching(), 9001, {}, state)
            self.assertIn(blocker, result["blockers"])
            self.assertIn("failure_refund_unverified", result["blockers"])
            self.assertNotIn("destroy_on_failure", result)

    def test_json_roundtrip_preserves_evidence_boundary(self):
        definitions = json.loads(json.dumps(self.matching()))
        result = reader.official_crosscheck(definitions, 9001, {902: "태고의 구", 903: "신화 연금석"})
        restored = json.loads(json.dumps(result))
        self.assertFalse(restored["execution_enabled"])
        self.assertEqual([s["official_success_percent"] for s in restored["stages"]], [7, 15, 33])


if __name__ == "__main__":
    unittest.main()
