"""Synthetic observations only; never current market data or private original rows."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from urllib.parse import urlencode
import zipfile

MODULE = Path(__file__).parents[1] / "tools/exchange/build_representative.py"
spec = importlib.util.spec_from_file_location("representative_builder", MODULE)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
BASE = "https://api-goats.plaync.com/lms/v2.0"


def url(path, **query):
    return BASE + path + ("?" + urlencode(query) if query else "")


def stock_row(**extra):
    value = {"itemId": 1, "itemName": "SYNTHETIC weapon", "serverId": 1,
             "enchantLevel": 0, "world": False, "salePrice": 13.0,
             "quantity": 7, "blessingLevel": 0, "grade": 1, "image": "https://example.invalid/icon"}
    value.update(extra)
    return value


def page(rows, total=None, number=1):
    return {"contents": rows, "pagination": {"page": number, "size": 10,
             "lastPage": 1, "total": len(rows) if total is None else total, "limit": 10000}}


def observe(directory, name, endpoint, data, second=0):
    directory.mkdir(parents=True, exist_ok=True)
    raw = json.dumps(data, ensure_ascii=False).encode()
    body = directory / (name + ".json");body.write_bytes(raw)
    receipt = {"url": endpoint, "http_status": 200, "valid_json": True,
               "sha256": hashlib.sha256(raw).hexdigest(), "body_file": body.name,
               "request_started_at_utc": f"2026-11-12T00:00:{second:02d}+00:00",
               "request_completed_at_utc": f"2026-11-12T00:00:{second:02d}.500000+00:00"}
    (directory / (name + ".receipt.json")).write_text(json.dumps(receipt))
    return body


class Fixture:
    def __init__(self, root, rows=None, bless=1, enchant=0):
        self.root = root;self.capture = root / "capture";self.raw = self.capture / "raw"
        self.survey_dir = root / "survey";self.survey = self.survey_dir / "survey_manifest.json"
        self.definitions = root / "private-synthetic.zip"
        with zipfile.ZipFile(self.definitions, "w") as archive:
            archive.writestr("content/ItemClass.json", json.dumps({"rows": [
                {"ID": 1, "DescID": 10, "Name": "synthetic", "TestItem": False}]}))
            archive.writestr("content/DescData_Korean.json", json.dumps({"rows": [
                {"ID": 10, "Description": "SYNTHETIC weapon"}]}))
        self.sha = hashlib.sha256(self.definitions.read_bytes()).hexdigest()
        observe(self.raw, "servers", url("/game/server"), [
            {"worldId": 10001, "worldName": "SYNTHETIC world", "servers": [
                {"serverId": 1, "serverName": "SYNTHETIC server"}]},
            {"worldId": 10002, "worldName": "SYNTHETIC world2", "servers": [
                {"serverId": 2, "serverName": "SYNTHETIC server2"}]}])
        observe(self.raw, "categories", url("/game/market/category"), [
            {"id": "1", "name": "SYNTHETIC weapons", "child": []},
            {"id": "41", "name": "SYNTHETIC consumables", "child": []},
            {"id": "51", "name": "SYNTHETIC materials", "child": []}])
        rows = [stock_row(enchantLevel=enchant, itemName=(f"+{enchant} " if enchant else "") + "SYNTHETIC weapon")] if rows is None else rows
        group = copy.deepcopy(rows[0]);group.pop("salePrice", None)
        observe(self.raw, "catalog", url("/price/search/item", serverId=1, sale="true", size=30,
                category1=1, page=1), page([group]), second=1)
        self.stock_url = url("/price/search/item/1/stock", serverId=1, enchantLevel=enchant,
                             blessedType=bless, size=10, page=1)
        self.body = observe(self.raw, "stock", self.stock_url, page(rows), second=2)
        self.capture.mkdir(exist_ok=True)
        (self.capture / "progress.json").write_text(json.dumps({
            "selection": {"selected_category1_ids": [1]}, "drift_events": [],
            "stock_receipts": []}))
        ranking = []
        for sid, wid, total, shared in [(1, 10001, 5, 2), (2, 10002, 3, 1)]:
            local_name, world_name = f"server_{sid}", f"world_{wid}"
            observe(self.survey_dir, local_name, url("/price/search/item", serverId=sid,
                    sale="true", size=30, page=1), page([], total=total))
            observe(self.survey_dir, world_name, url("/price/search/item", serverId=wid,
                    sale="true", size=30, page=1), page([], total=shared))
            ranking.append({"server_id": sid, "world_id": wid,
                "combined_catalog_group_total": total, "shared_world_catalog_group_total": shared,
                "derived_local_catalog_group_count_proxy": total-shared,
                "combined_response_body": local_name+".json", "shared_world_response_body": world_name+".json"})
        self.survey.write_text(json.dumps({"ranking": ranking}))

    def build(self, directories=None, **kwargs):
        return builder.build_snapshot(directories or [self.capture], self.survey, self.definitions,
                                      expected_definition_sha=self.sha, **kwargs)


class RepresentativeBuildTests(unittest.TestCase):
    def test_actual_values_and_identical_rows_are_preserved_without_coverage_claim(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary), [stock_row(), stock_row()])
            snapshot, report = fixture.build()
            self.assertEqual(len(snapshot["listings"]), 2)
            self.assertEqual({r["bundle_price"] for r in snapshot["listings"]}, {13})
            self.assertEqual({r["bundle_size"] for r in snapshot["listings"]}, {7})
            self.assertEqual({r["initial_bundles"] for r in snapshot["listings"]}, {1})
            self.assertEqual(len({r["listing_id"] for r in snapshot["listings"]}), 2)
            self.assertEqual(report["equal_value_rows_preserved"], 1)
            self.assertFalse(snapshot["coverage"]["complete"])
            self.assertTrue(snapshot["coverage"]["approximate"])
            self.assertFalse(snapshot["test_fixture"])
            self.assertFalse(report["distinct_listings_verified"])
            self.assertEqual(snapshot["coverage"]["server_name"], "SYNTHETIC server")

    def test_response_hash_tamper_stops_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary));fixture.body.write_text("{}")
            with self.assertRaisesRegex(builder.BuildError, "SHA-256 mismatch"):
                fixture.build()

    def test_original_archive_hash_must_match(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary))
            with self.assertRaisesRegex(builder.BuildError, "definition ZIP SHA"):
                builder.build_snapshot([fixture.capture], fixture.survey, fixture.definitions,
                                       expected_definition_sha="0"*64)

    def test_unmatched_original_label_is_omitted_and_reported(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary), [stock_row(), stock_row(itemName="unverified alias")])
            snapshot, report = fixture.build()
            self.assertEqual(len(snapshot["listings"]), 1)
            self.assertIn("unmatched", report["omitted_rows"][0]["reason"])

    def test_outside_market_is_not_added_to_representative(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary))
            other = stock_row(serverId=2)
            observe(fixture.raw, "outside", url("/price/search/item/1/stock", serverId=2,
                    enchantLevel=0, blessedType=1, size=10, page=1), page([other]), second=3)
            snapshot, report = fixture.build()
            self.assertEqual(len(snapshot["listings"]), 1)
            self.assertEqual(report["omitted_rows"][0]["reason"], "outside_selected_market")

    def test_duplicate_response_references_do_not_duplicate_observations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary);fixture = Fixture(root, [stock_row(), stock_row()])
            duplicate = root / "duplicate";shutil.copytree(fixture.capture, duplicate)
            snapshot, report = fixture.build([fixture.capture, duplicate])
            self.assertEqual(len(snapshot["listings"]), 2)
            self.assertEqual(report["duplicate_response_references"], 1)

    def test_later_version_of_same_page_does_not_fill_stock_twice(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary);fixture = Fixture(root)
            later = root / "later";later.mkdir()
            observe(later, "changed", fixture.stock_url, page([stock_row(salePrice=99)]), second=3)
            snapshot, report = fixture.build([fixture.capture, later])
            self.assertEqual(snapshot["listings"][0]["bundle_price"], 13)
            self.assertEqual(len(report["later_response_versions_ignored"]), 1)

    def test_wildcard_does_not_become_normal_and_unknown_variant_is_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary), [stock_row(blessingLevel=2, refinement={"x": 3})], bless=0)
            snapshot, _ = fixture.build()
            attrs = snapshot["listings"][0]["attributes"]
            self.assertNotIn("blessed_type", attrs)
            self.assertEqual(attrs["unverified_blessed_type_filter"], 0)
            self.assertEqual(attrs["api_blessing_level"], 2)
            self.assertEqual(attrs["unmapped_api_fields"], {"refinement": {"x": 3}})

    def test_enchant_prefix_requires_exact_observed_relation_to_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary), enchant=6)
            snapshot, _ = fixture.build()
            row = snapshot["listings"][0]
            self.assertEqual(row["item_name"], "SYNTHETIC weapon")
            self.assertEqual(row["observed_item_name"], "+6 SYNTHETIC weapon")
            self.assertEqual(row["enchant"], 6)
            self.assertEqual(row["observation"]["raw_row"]["itemName"], "+6 SYNTHETIC weapon")

    def test_unproved_category_cannot_be_invented(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary))
            (fixture.raw / "catalog.json").unlink()
            (fixture.raw / "catalog.receipt.json").unlink()
            with self.assertRaisesRegex(builder.BuildError, "No observed rows"):
                fixture.build()

    def test_requested_server_must_maximize_verified_survey_proxy(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary))
            with self.assertRaisesRegex(builder.BuildError, "not a maximum"):
                fixture.build(selected_server_id=2)

    def test_saved_http_error_does_not_discard_earlier_verified_market_rows(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary))
            observe(fixture.raw, "limited", url("/price/search/item/2/stock", serverId=1,
                    enchantLevel=0, blessedType=1, size=10, page=1), {"error": "rate limited"}, second=3)
            receipt_path = fixture.raw / "limited.receipt.json"
            receipt = json.loads(receipt_path.read_text());receipt["http_status"] = 429
            receipt_path.write_text(json.dumps(receipt))
            snapshot, report = fixture.build()
            self.assertEqual(len(snapshot["listings"]), 1)
            self.assertEqual(report["excluded_response_receipts"][0]["http_status"], 429)
            self.assertFalse(snapshot["coverage"]["complete"])

    def test_stock_page_row_count_cannot_be_forged(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary))
            observe(fixture.raw, "stock", fixture.stock_url, page([stock_row()], total=2), second=2)
            with self.assertRaisesRegex(builder.BuildError, "row count"):
                fixture.build()

    def test_fractional_price_is_never_rounded_into_a_listing(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary), [stock_row(), stock_row(salePrice=0.5)])
            snapshot, report = fixture.build()
            self.assertEqual(len(snapshot["listings"]), 1)
            self.assertEqual(snapshot["listings"][0]["bundle_price"], 13)
            self.assertEqual(report["omitted_rows"][0]["reason"], "nonpositive_or_noninteger_observed_bundle")

    def test_explicit_category_filter_is_not_expanded_by_progress_targets(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary))
            progress_path = fixture.capture / "progress.json"
            progress = json.loads(progress_path.read_text())
            progress["selection"]["selected_category1_ids"] = [1, 41]
            progress_path.write_text(json.dumps(progress))
            snapshot, _ = fixture.build(category_ids=[1])
            self.assertEqual([c["id"] for c in snapshot["coverage"]["selected_categories"]], [1])

    def test_partial_in_progress_capture_derives_drift_from_raw_pages(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Fixture(Path(temporary))
            more = [stock_row(salePrice=14)]
            data = page(more, total=11, number=2)
            data["pagination"]["lastPage"] = 2
            observe(fixture.raw, "stock_page2", url("/price/search/item/1/stock", serverId=1,
                    enchantLevel=0, blessedType=1, size=10, page=2), data, second=3)
            snapshot, report = fixture.build()
            self.assertEqual(len(snapshot["listings"]), 2)
            self.assertTrue(snapshot["coverage"]["live_drift_recorded"])
            self.assertTrue(report["observed_pagination_drift_events"])
            self.assertFalse(snapshot["coverage"]["complete"])
            self.assertIn("body_file", snapshot["listings"][0]["observation"])

    def test_output_is_exclusive_and_existing_bytes_are_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "output.json"
            builder.write_new(path, {"source": "synthetic"})
            original = path.read_bytes()
            with self.assertRaisesRegex(builder.BuildError, "overwrite"):
                builder.write_new(path, {"changed": True})
            self.assertEqual(path.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
