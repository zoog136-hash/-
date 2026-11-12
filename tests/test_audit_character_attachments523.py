"""Synthetic parser/ledger regressions; these fixtures are not game art or native execution."""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("audit_character_attachments523", ROOT / "tools/lineagem_original/audit_character_attachments523.py")
assert SPEC and SPEC.loader
AUDIT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = AUDIT
SPEC.loader.exec_module(AUDIT)


def parse(text: str, source: str = "Client/Text/list_0.spr", encoding: str = "cp949") -> dict:
    return AUDIT.parse_spr_bytes(text.encode(encoding), source)


def project(parsed: dict, sprite: int) -> dict:
    inventory = AUDIT.build_inventory([parsed], [])
    matches = [row for row in inventory["metadata_projection"] if row["source_sprite_id"] == sprite]
    if len(matches) != 1:
        raise AssertionError(f"Expected one metadata row for {sprite}, got {matches!r}")
    return matches[0]


class AttachmentSourceAuditTest(unittest.TestCase):
    def test_inline_and_indented_headers_do_not_lose_directives(self):
        source = "#100 4 Parent 104.attr(8) 101.shadow(101)\r\n  #101 4 그림자 105.clothes(2 102 103)\r\n"
        result = parse(source)
        self.assertEqual([r["source_sprite_id"] for r in result["declarations"]], [100, 101])
        self.assertEqual([r["code"] for r in result["directives"]], [104, 101, 105])
        self.assertEqual([r["target_id"] for r in result["instances"]], [101, 102, 103])

    def test_cp949_byte_offsets_and_source_identity_are_literal(self):
        raw = "#100 4 여성 사신\r\n104.attr(8)\r\n#101 4 그림자\r\n101.shadow(102)\r\n".encode("cp949")
        result = AUDIT.parse_spr_bytes(raw, "Client/Text/list_1.spr")
        first, second = result["declarations"]
        self.assertEqual(first["source_byte_offset"], 0)
        self.assertEqual(second["source_byte_offset"], raw.index(b"#101"))
        self.assertEqual(first["source_end_byte_offset"], second["source_byte_offset"])
        self.assertEqual(second["source_end_byte_offset"], len(raw))
        self.assertEqual(second["source_line"], 3)
        for row in result["declarations"]:
            self.assertEqual(row["source_sha256"], hashlib.sha256(raw).hexdigest())
        for row in result["directives"]:
            offset = row["source_byte_offset"]
            self.assertTrue(raw[offset:].startswith(str(row["code"]).encode("ascii")))
            self.assertEqual(row["source_line"], raw[:offset].count(b"\n") + 1)

    def test_ordered_clothes_instances_preserve_duplicate_operands(self):
        result = parse("#100 4 Parent\n105.clothes(3 201 201 202)\n105.clothes(1 203)\n")
        directives = [r for r in result["directives"] if r["code"] == 105]
        first_instances = [r for r in result["instances"] if r["directive_key"] == directives[0]["directive_key"]]
        self.assertEqual([r["target_id"] for r in first_instances], [201, 201, 202])
        self.assertEqual([r["target_index"] for r in first_instances], [0, 1, 2])
        self.assertEqual(len(result["instances"]), 4)
        self.assertEqual(project(result, 100)["clothes_targets"], [201, 201, 202])

    def test_last_attr_overwrites_instead_of_bitwise_union(self):
        result = parse("#100 4 Parent\n104.attr(8)\n104.attr(128)\n")
        projection = project(result, 100)
        self.assertEqual(projection["attr_low9"], 128)
        self.assertNotEqual(projection["attr_low9"], 8 | 128)
        self.assertEqual(len([r for r in result["directives"] if r["code"] == 104]), 2)
        self.assertEqual(projection["last104directive"], result["directives"][-1]["directive_key"])

    def test_attr_low9_and_explicit_zero_are_preserved(self):
        self.assertEqual(project(parse("#100 4 Parent 104.attr(513)\n"), 100)["attr_low9"], 1)
        self.assertEqual(project(parse("#100 4 Parent 104.attr(8) 104.attr(0)\n"), 100)["attr_low9"], 0)

    def test_shadow_low15_last_write_and_zero(self):
        result = parse("#100 4 Parent\n101.shadow(32769)\n")
        self.assertEqual(result["instances"][0]["target_id"], 32769)
        self.assertEqual(project(result, 100)["shadow_id"], 1)
        cleared = parse("#100 4 Parent\n101.shadow(102)\n101.shadow(0)\n")
        self.assertEqual([r["target_id"] for r in cleared["instances"]], [102, 0])
        self.assertEqual(project(cleared, 100)["shadow_id"], 0)

    def test_first_valid_clothes_insert_remains_even_if_later_is_empty(self):
        result = parse("#100 4 Parent\n105.clothes(2 201 202)\n105.clothes(0)\n")
        projection = project(result, 100)
        self.assertEqual(projection["clothes_targets"], [201, 202])
        self.assertEqual(projection["first105directive"], result["directives"][0]["directive_key"])
        empty_first = parse("#100 4 Parent\n105.clothes(0)\n105.clothes(1 203)\n")
        self.assertEqual(project(empty_first, 100)["clothes_targets"], [])
        self.assertEqual([r["target_id"] for r in empty_first["instances"]], [203])

    def test_malformed_count_retains_original_claim_and_operands(self):
        result = parse("#100 4 Parent\n105.clothes(3 201 202)\n")
        directive = result["directives"][0]
        self.assertEqual(directive["raw_body"], "3 201 202")
        self.assertEqual(directive["integer_values"], [3, 201, 202])
        self.assertEqual(directive["target_count_declared"], 3)
        self.assertNotEqual(directive["syntax_status"], "valid")
        self.assertEqual([r["target_id"] for r in result["instances"]], [201, 202])
        self.assertTrue(result["issues"])

    def test_header_alias_does_not_inherit_parent_metadata(self):
        result = parse("#100 4 Parent\n104.attr(8)\n101.shadow(102)\n105.clothes(1 103)\n#200 4=100 Alias\n")
        self.assertEqual(result["declarations"][1]["alias_target"], 100)
        self.assertTrue(result["aliases"])
        child = project(result, 200)
        self.assertEqual(child["attr_low9"], 0)
        self.assertEqual(child["shadow_id"], 0)
        self.assertEqual(child["clothes_targets"], [])
        self.assertEqual(project(result, 100)["clothes_targets"], [103])

    def test_duplicate_sprite_headers_remain_separate_source_records(self):
        result = parse("#100 4 First 104.attr(8)\n#100 4 Second 104.attr(128)\n")
        self.assertEqual(len(result["declarations"]), 2)
        self.assertEqual(len({r["declaration_key"] for r in result["declarations"]}), 2)
        self.assertEqual(len(result["directives"]), 2)
        inventory = AUDIT.build_inventory([result], [])
        duplicates = [r for r in inventory["issues"] if r["kind"] == "duplicate_sprite_declarations"]
        self.assertEqual([r["source_sprite_id"] for r in duplicates], [100])
        self.assertEqual(len(duplicates[0]["declaration_keys"]), 2)

    def test_alias_cycles_are_visible_without_recursion_or_metadata_inheritance(self):
        result = parse("#300 4=301 First\n#301 4=300 Second\n")
        roots = [{"category":"actor_class","table":"Class","field":"MaleSpriteID","row_id":1,"source_sprite_id":300,"table_sha256":"a" * 64}]
        inventory = AUDIT.build_inventory([result], roots)
        self.assertEqual(len(result["aliases"]), 2)
        self.assertEqual([r["chain_status"] for r in inventory["aliases"]], ["cycle", "cycle"])
        self.assertEqual(len([r for r in inventory["issues"] if r["kind"] == "alias_cycle"]), 2)
        self.assertEqual(project(result, 300)["shadow_id"], 0)

    def test_inventory_is_deterministic_and_does_not_rewrite_inputs(self):
        left = parse("#100 4 Parent 105.clothes(2 201 201)\n", "Client/Text/list_0.spr")
        right = parse("#201 4 Child 104.attr(128)\n", "Client/Text/list_1.spr")
        sources = [left, right]
        roots = [{"category":"presentation_card_transform","table":"BuffCard","field":"DisplaySpriteID","row_id":4,"source_sprite_id":100,"table_sha256":"a" * 64}]
        before_sources, before_roots = copy.deepcopy(sources), copy.deepcopy(roots)
        first = AUDIT.build_inventory(sources, roots)
        self.assertEqual(first, AUDIT.build_inventory(sources, roots))
        self.assertEqual(first, AUDIT.build_inventory(list(reversed(sources)), roots))
        self.assertEqual(sources, before_sources)
        self.assertEqual(roots, before_roots)


    def test_supplied_member_absence_is_not_a_missing_declaration_or_decode_failure(self):
        result = parse("#100 4 Parent 105.clothes(2 201 202)\n#201 4 Present\n#202 4 NoPhysicalMembers\n")
        members = [{"member":"Sprite/201-0.sp2","bytes":10}, {"member":"Sprite/201-8.sp2","bytes":20}]
        inventory = AUDIT.build_inventory([result], [], members)
        first, second = inventory["instances"]
        self.assertEqual(first["physical_member_count"], 2)
        self.assertEqual(first["physical_status"], "present_in_supplied_member_universe")
        self.assertEqual(second["physical_member_count"], 0)
        self.assertEqual(second["physical_status"], "absent_from_supplied_member_universe")
        self.assertEqual(len(second["target_declaration_keys"]), 1)
        self.assertNotIn("decode", second["physical_status"])
        unavailable = AUDIT.build_inventory([result], [])
        self.assertIsNone(unavailable["instances"][0]["physical_member_count"])
        self.assertEqual(unavailable["instances"][0]["physical_status"], "not_supplied")

    def test_member_namespace_mismatch_is_rejected(self):
        result = parse("#100 4 Parent\n")
        with self.assertRaises(ValueError):
            AUDIT.build_inventory([result], [], [{"member":"Sprite/201-0.sp2","source_sprite_id":202}])
        with self.assertRaises(ValueError):
            AUDIT.build_inventory([result], [], [{"member":"icon/201.png"}])

    def test_invalid_clothes_operands_do_not_become_reachable_requests(self):
        result = parse("#100 4 Parent 105.clothes(3 201 202)\n#201 4 Child\n#202 4 Child\n")
        roots = [{"category":"actor_class","table":"Class","field":"MaleSpriteID","row_id":1,"source_sprite_id":100,"table_sha256":"a" * 64}]
        inventory = AUDIT.build_inventory([result], roots)
        scope = next(r for r in inventory["scopes"] if r["category"] == "actor_class")
        self.assertEqual(scope["reachable_source_sprite_ids"], [100])
        self.assertEqual(scope["ordered_target_instances"], 2)
        self.assertEqual(scope["distinct_attachment_target_ids"], [])
        self.assertIsNone(project(result, 100)["clothes_targets"])

    def test_numeric_source_file_order_is_distinct_from_lexicographic_order(self):
        earlier = parse("#100 4 Earlier 104.attr(128)\n", "Client/Text/list_2.spr")
        later = parse("#100 4 Later 104.attr(8)\n", "Client/Text/list_10.spr")
        inventory = AUDIT.build_inventory([later, earlier], [])
        projection = next(r for r in inventory["metadata_projection"] if r["source_sprite_id"] == 100)
        self.assertEqual(projection["attr_low9"], 8)
        self.assertTrue(projection["cross_file_directives"])
        self.assertEqual(inventory["sources"][0]["source_file"], "Client/Text/list_2.spr")


    def test_type102_literals_are_preserved_without_inventing_type_semantics(self):
        result = parse("#100 4 Parent 102.type(10) 102.type(74)\n#101 4 Child 102.type(0)\n")
        types = [row for row in result["directives"] if row["code"] == 102]
        self.assertEqual([row["raw_body"] for row in types], ["10", "74", "0"])
        self.assertEqual([row["integer_values"] for row in types], [[10], [74], [0]])
        self.assertEqual([row["kind"] for row in types], ["type", "type", "type"])
        self.assertEqual(result["instances"], [])
        inventory = AUDIT.build_inventory([result], [])
        self.assertEqual(inventory["summary"]["raw_102_values"], {"0":1, "10":1, "74":1})
        self.assertEqual(inventory["summary"]["directive_statement_counts"]["102"], 3)
        self.assertEqual(project(result, 100)["attr_low9"], 0)
        self.assertEqual(project(result, 100)["shadow_id"], 0)

    def test_direct_effect_suffix_has_separate_conditional_reachability(self):
        result = parse("#100 4 Parent\n101.shadow(102)\n147.WalkScythe(1 1,0.0:2]201]201)\n#102 4 Shadow\n#201 4 Conditional 105.clothes(1 103)\n#103 4 ConditionalCloth\n")
        roots = [{"category":"actor_class","table":"Class","field":"MaleSpriteID","row_id":1,"source_sprite_id":100,"table_sha256":"a" * 64}]
        inventory = AUDIT.build_inventory([result], roots)
        scope = next(row for row in inventory["scopes"] if row["category"] == "actor_class")
        self.assertEqual(scope["reachable_source_sprite_ids"], [100, 102])
        self.assertEqual(scope["conditionally_reachable_source_sprite_ids"], [100, 102, 103, 201])
        self.assertEqual(scope["conditional_direct_effect_instances"], 2)
        self.assertEqual([row["target_id"] for row in result["conditional_effects"]], [201, 201])
        self.assertEqual([row["action_code"] for row in result["conditional_effects"]], [147, 147])
        self.assertEqual(project(result, 100)["clothes_targets"], [])

    def test_direct_effect_signed16_wrap_token_ordinal_and_byte_offset(self):
        raw = "#100 4 여성 사신\r\n1.Attack(1 3,16.0:2<123 16.1:3]65535 16.2:4]65537)\r\n".encode("cp949")
        result = AUDIT.parse_spr_bytes(raw, "Client/Text/list_1.spr")
        effects = result["conditional_effects"]
        self.assertEqual([row["operand_raw"] for row in effects], [65535, 65537])
        self.assertEqual([row["target_id"] for row in effects], [-1, 1])
        self.assertEqual([row["literal_token_ordinal"] for row in effects], [1, 2])
        self.assertEqual([row["source_byte_offset"] for row in effects], [raw.index(b"]65535"), raw.index(b"]65537")])
        self.assertEqual([row["source_byte_length"] for row in effects], [6, 6])
        self.assertTrue(all(row["native_activation_verified"] is False for row in effects))
        roots = [{"category":"actor_class","table":"Class","field":"MaleSpriteID","row_id":1,"source_sprite_id":100,"table_sha256":"a" * 64}]
        scope = next(row for row in AUDIT.build_inventory([result], roots)["scopes"] if row["category"] == "actor_class")
        self.assertEqual(scope["reachable_source_sprite_ids"], [100])
        self.assertEqual(scope["conditionally_reachable_source_sprite_ids"], [1, 100])
        self.assertNotIn(-1, scope["conditionally_reachable_source_sprite_ids"])

    def test_other_numeric_frame_markers_do_not_become_direct_effects(self):
        result = parse("#100 4 Parent\n0.Walk(1 3,0.0:2<123 0.1:2!124 0.2:2)\n")
        self.assertEqual(result["conditional_effects"], [])
        self.assertEqual(result["instances"], [])
        self.assertEqual(result["directive_code_counts"], {"0":1})


    def test_unclosed_clothes_fragment_is_preserved_without_swallowing_next_header(self):
        raw = b"#100 4 Parent\r\n105.clothes(1 201\r\n#201 4 Child\r\n104.attr(8)\r\n"
        result = AUDIT.parse_spr_bytes(raw, "Client/Text/list_1.spr")
        self.assertEqual([row["source_sprite_id"] for row in result["declarations"]], [100, 201])
        fragment = next(row for row in result["directives"] if row["code"] == 105)
        self.assertEqual(fragment["syntax_status"], "invalid")
        self.assertEqual(fragment["syntax_error"], "unclosed_parenthesis")
        self.assertEqual(fragment["raw_body"], "1 201")
        self.assertEqual(fragment["integer_values"], [1, 201])
        offset = fragment["source_byte_offset"]
        self.assertEqual(raw[offset:offset + fragment["source_byte_length"]], b"105.clothes(1 201")
        candidate = next(row for row in result["instances"] if row["directive_key"] == fragment["directive_key"])
        self.assertEqual(candidate["target_id"], 201)
        self.assertEqual(candidate["syntax_status"], "invalid")
        roots = [{"category":"actor_class","table":"Class","field":"MaleSpriteID","row_id":1,"source_sprite_id":100,"table_sha256":"a" * 64}]
        inventory = AUDIT.build_inventory([result], roots)
        scope = next(row for row in inventory["scopes"] if row["category"] == "actor_class")
        self.assertEqual(scope["reachable_source_sprite_ids"], [100])
        self.assertIsNone(project(result, 100)["clothes_targets"])
        self.assertEqual(project(result, 201)["attr_low9"], 8)
        self.assertEqual(inventory["summary"]["invalid_attachment_statements"], 1)


    def table_archive_fixture(self):
        directory = tempfile.TemporaryDirectory(prefix="attachment-root-test-")
        self.addCleanup(directory.cleanup)
        archive = Path(directory.name) / "source-tables.zip"
        tables = {
            "Class": [{"ID":94,"MaleSpriteID":21951,"FemaleSpriteID":26213}],
            "PolymorphEntity": [{"ID":7,"SpriteID":21951,"ClassID":94,"GenderID":1}],
            "PolymorphEntityForSet": [{"PolymorphSetID":3,"PolymorphEntityID":7}],
        }
        hashes = {}
        with zipfile.ZipFile(archive, "w") as writer:
            for table, rows in tables.items():
                raw = json.dumps({"rows":rows}, sort_keys=True).encode("utf-8")
                hashes[table] = hashlib.sha256(raw).hexdigest()
                writer.writestr("content/" + table + ".json", raw)
        roots = [
            {"category":"actor_class","table":"Class","field":"MaleSpriteID","row_id":94,"row_index":0,"source_sprite_id":21951,"table_sha256":hashes["Class"]},
            {"category":"actor_card_transform_typed","table":"PolymorphEntity","field":"SpriteID","row_id":7,"row_index":0,"source_sprite_id":21951,"table_sha256":hashes["PolymorphEntity"],"provenance":{"path":[
                {"table":"PolymorphEntityForSet","row_id":None,"row_index":0,"table_sha256":hashes["PolymorphEntityForSet"]},
                {"table":"PolymorphEntity","row_id":7,"row_index":0,"table_sha256":hashes["PolymorphEntity"]},
            ]}},
        ]
        return archive, roots

    def test_root_records_verify_actual_table_rows_hashes_and_idless_chain_rows(self):
        archive, roots = self.table_archive_fixture()
        before = copy.deepcopy(roots)
        result = AUDIT.verify_root_records(roots, archive, hashlib.sha256(archive.read_bytes()).hexdigest())
        self.assertIsInstance(result, dict)
        self.assertTrue(result)
        self.assertEqual(roots, before)

    def test_root_records_reject_tampered_field_value_index_id_and_archive_hash(self):
        archive, roots = self.table_archive_fixture()
        for field, replacement in [("field","DisplaySpriteID"), ("source_sprite_id",26213), ("row_index",1), ("row_id",95), ("table_sha256","0" * 64), ("table","Missing")]:
            with self.subTest(field=field):
                altered = copy.deepcopy(roots)
                altered[0][field] = replacement
                with self.assertRaises(ValueError): AUDIT.verify_root_records(altered, archive)
        with self.assertRaises(ValueError): AUDIT.verify_root_records(roots, archive, "0" * 64)

    def test_root_records_verify_every_provenance_path_row(self):
        archive, roots = self.table_archive_fixture()
        for index, field, replacement in [(0,"table_sha256","0" * 64), (0,"row_index",1), (0,"row_id",99), (1,"row_id",8), (1,"table","Missing")]:
            with self.subTest(index=index,field=field):
                altered = copy.deepcopy(roots)
                altered[1]["provenance"]["path"][index][field] = replacement
                with self.assertRaises(ValueError): AUDIT.verify_root_records(altered, archive)


if __name__ == "__main__":
    unittest.main()
