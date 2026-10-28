extends SceneTree

const GRADES = preload("res://scripts/catalog_grade_policy.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("CATALOG_GRADE_FAIL: ", label)

func _initialize() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_item_grade_audit_20261026.json"))
	var gameplay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var by_id: Dictionary = {}
	var counts: Dictionary = {}
	var unmapped: int = 0
	for item: Dictionary in catalog["아이템"]:
		var id: String = str(item.sourceId)
		by_id[id] = item
		check(audit.source_quality_by_id.has(id), "source audit contains " + id)
		check(int(item.sourceQuality) == int(audit.source_quality_by_id.get(id, 0)), "original quality preserved " + id)
		var quality: String = str(int(item.sourceQuality))
		if audit.quality_map.has(quality):
			var grade: String = str(audit.quality_map[quality])
			check(item.grade == grade, "catalog uses observed source quality " + id)
			check(item.grade_evidence == "inven_item_quality", "verified grade provenance " + id)
			counts[grade] = int(counts.get(grade, 0)) + 1
		else:
			unmapped += 1
			check(item.grade_evidence == "inven_item_quality_unmapped", "unknown quality remains explicit " + id)
	check(by_id.size() == 2129 and unmapped == 217, "all original IDs retained, special quality not guessed")
	check(counts == {"일반":530,"고급":233,"희귀":391,"영웅":366,"전설":303,"신화":73,"유일":16}, "all seven source grade populations")
	check(GRADES.apply(catalog["아이템"]) == 0, "runtime must not undo verified catalog or promote special artwork")
	var verified_gameplay: int = 0
	for item: Dictionary in gameplay["아이템"]:
		if not item.has("grade_source_id"): continue
		var source: Dictionary = by_id.get(str(item.grade_source_id), {})
		check(source.get("name", "") == item.name and source.get("slot", "") == item.slot, "gameplay exact name and slot identity")
		check(source.get("grade", "") == item.grade, "drop pool uses canonical grade " + str(item.name))
		verified_gameplay += 1
	check(verified_gameplay == 76, "only verified gameplay identities synchronized")
	var misleading: Array = [
		{"name":"special", "slot":"tshirt", "grade":"일반", "sourceQuality":42, "sourceImageUrl":"https://example.invalid/hero_tshirt.png"},
		{"name":"rare", "slot":"weapon", "grade":"일반", "sourceQuality":3, "sourceImageUrl":"https://example.invalid/legend_weapon.png"},
		{"name":"future", "slot":"weapon", "grade":"고급", "sourceQuality":999, "sourceImageUrl":"https://example.invalid/hero_weapon.png"}
	]
	check(GRADES.apply(misleading) == 1, "only known source quality may correct an explicit observation")
	check(misleading[0].grade == "일반" and misleading[1].grade == "희귀" and misleading[2].grade == "고급", "quality defeats art tokens and unknown qualities stay untouched")
	_test_saved_grades(catalog["아이템"], gameplay["아이템"])
	print("CATALOG_GRADE_RESULT ", JSON.stringify({"catalog":by_id.size(),"standard":2129-unmapped,"unmapped":unmapped,"gameplay":verified_gameplay,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _test_saved_grades(catalog: Array, gameplay: Array) -> void:
	var saved: Dictionary = {"sourceId":"176582", "name":"군터의 단도", "slot":"weapon", "grade":"일반", "atk":123, "instance_id":"98", "enhance_level":9, "bless_state":"blessed"}
	var legacy: Dictionary = {"name":"군터의 단도", "slot":"weapon", "grade":"신화", "atk":55, "instance_id":"99", "enhance_level":7}
	var stored_record: Dictionary = {"sourceId":"344361", "name":"기억의 망토", "slot":"cloak", "grade":"희귀", "def":44}
	var wrong_id: Dictionary = {"sourceId":"176582", "name":"다른 아이템", "slot":"weapon", "grade":"일반"}
	var unknown_id: Dictionary = {"sourceId":"no-such-id", "name":"군터의 단도", "slot":"weapon", "grade":"일반"}
	var custom: Dictionary = {"name":"군터의 단도", "slot":"ring", "grade":"유일", "atk":91}
	var physical: Dictionary = {"98":{"name":"군터의 단도", "level":9, "element":"fire", "element_level":3, "record":saved}, "bad":{"record":wrong_id}, "unknown":{"record":unknown_id}, "custom":{"record":custom}}
	var equipped: Dictionary = {"weapon":legacy}
	var stored: Dictionary = {"100":{"name":"기억의 망토", "level":6, "element":"water", "record":stored_record}}
	var original: Dictionary = {"physical":physical.duplicate(true), "equipped":equipped.duplicate(true), "stored":stored.duplicate(true)}
	check(GRADES.synchronize_saved_grades(catalog, gameplay, physical, equipped, stored) == 3, "carried, equipped and warehouse snapshots repaired together")
	check(saved.grade == "전설" and legacy.grade == "전설" and stored_record.grade == "영웅", "existing owned items acquire canonical rarity")
	for pair: Array in [[physical["98"], original.physical["98"]], [stored["100"], original.stored["100"]]]:
		var after: Dictionary = pair[0].duplicate(true)
		var before: Dictionary = pair[1].duplicate(true)
		after.erase("record")
		before.erase("record")
		check(after == before, "physical ID, enchant and element state preserved")
	for pair: Array in [[saved, original.physical["98"].record], [legacy, original.equipped.weapon], [stored_record, original.stored["100"].record]]:
		var after: Dictionary = pair[0].duplicate(true)
		var before: Dictionary = pair[1].duplicate(true)
		for key: String in ["grade", "grade_original", "sourceQuality", "grade_evidence"]:
			after.erase(key)
			before.erase(key)
		check(after == before, "only grade metadata changes, custom stats preserved")
	check(wrong_id == original.physical.bad.record and unknown_id == original.physical.unknown.record and custom == original.physical.custom.record, "invalid identities do not fall back to a namesake")
	check(GRADES.synchronize_saved_grades(catalog, gameplay, physical, equipped, stored) == 0, "save grade repair is idempotent")
