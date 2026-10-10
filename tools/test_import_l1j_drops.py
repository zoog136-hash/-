#!/usr/bin/env python3
"""Small independent fixture: parsing and strict ID map discipline."""
from import_l1j_drops import convert
sql = b"""
INSERT INTO `droplist` VALUES ('45008','11','1','3','9000');
INSERT INTO `droplist` VALUES ('45008','40010','1','1','200000');
INSERT INTO `droplist` VALUES ('45009','11','1','1','1000');
INSERT INTO `droplist` VALUES ('45008','9999','1','1','300');
INSERT INTO `droplist` VALUES ('45008','11','0','0','10');
"""
mappings = {
    "monster_id_to_twilight": {"45008": "fixture-monster"},
    "item_id_to_twilight": {
        "11": {"name": "수정 단검", "kind": "equipment"},
        "40010": {"name": "HP 물약", "kind": "potion"}
    }
}
out, audit = convert(sql, mappings, "synthetic")
assert audit["source_rows"] == 5, audit
assert audit["live_equipment_rows"] == 1, audit
assert audit["rejected_rows_by_reason"] == {"unmapped_monster": 1, "unmapped_item": 1, "non_equipment": 1, "invalid_quantity": 1}, audit
row = out["monsters"]["fixture-monster"][0]
assert (row["item_name"], row["weight"], row["min"], row["max"]) == ("수정 단검", 9000, 1, 3), row
assert "45009" not in out["monsters"], out
print("L1J_IMPORT_OK: strict ID mappings, quantity and source chance weight")
