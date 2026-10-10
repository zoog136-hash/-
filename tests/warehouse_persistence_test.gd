extends SceneTree

const WAREHOUSE = preload("res://scripts/warehouse/local_warehouse.gd")
var problems: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if not ok:
		problems.append(label)
		printerr("WAREHOUSE_FAIL: " + label)

func _run() -> void:
	var inventory: Dictionary = {"수정 단검":2,"HP 물약":10}
	var physical: Dictionary = {
		"1":{"name":"수정 단검","level":9,"element":"fire","element_level":3,"record":{"grade":"고급","sourceId":"a"}},
		"2":{"name":"수정 단검","level":5,"element":"water","element_level":2,"record":{"grade":"고급","sourceId":"b"}}
	}
	var equipped: Dictionary = {"weapon":{"name":"수정 단검","instance_id":"1"}}
	var storage = WAREHOUSE.new()
	var denied: Dictionary = storage.store("수정 단검",1,"1",inventory,physical,equipped,true)
	_check(not bool(denied.get("ok")), "equipped physical equipment cannot be stored")
	_check(inventory["수정 단검"] == 2 and physical.size() == 2, "failed deposit does not mutate")
	var stored: Dictionary = storage.store("수정 단검",1,"2",inventory,physical,equipped,true)
	_check(bool(stored.get("ok")), "free enchanted item deposit succeeds")
	_check(inventory["수정 단검"] == 1 and not physical.has("2"), "deposit removes exactly one available item")
	_check(storage.instances.has("2") and not storage.instances.has("1"), "exact instance moved to storage")
	_check(int(storage.instances["2"]["level"]) == 5 and str(storage.instances["2"]["element"]) == "water", "enchant and elemental data preserved")
	var invalid: Dictionary = storage.store("수정 단검",2,"2",inventory,physical,equipped,true)
	_check(not bool(invalid.get("ok")) and inventory["수정 단검"] == 1, "invalid bulk equipment request is atomic")
	_check(bool(storage.store("HP 물약",4,"",inventory,physical,equipped,false).get("ok")), "stackable consumable deposit")
	_check(inventory["HP 물약"] == 6 and storage.stacks["HP 물약"] == 4, "consumable partial deposit count")
	var snapshot: Dictionary = storage.snapshot()
	var restored = WAREHOUSE.new()
	restored.restore(snapshot)
	_check(restored.stacks == storage.stacks and restored.instances == storage.instances, "JSON-compatible warehouse snapshot roundtrip")
	_check(not bool(restored.retrieve("수정 단검",1,"2",inventory,physical,true,200,220,30).get("ok")), "withdrawal above carrying limit denied")
	_check(inventory["수정 단검"] == 1 and restored.instances.has("2"), "failed withdrawal is atomic")
	var withdrawn: Dictionary = restored.retrieve("수정 단검",1,"2",inventory,physical,true,150,220,30)
	_check(bool(withdrawn.get("ok")), "enchanted equipment withdrawal succeeds")
	_check(inventory["수정 단검"] == 2 and physical.has("2") and not restored.instances.has("2"), "item transferred back once without duplication")
	_check(int(physical["2"]["level"]) == 5 and str(physical["2"]["element"]) == "water" and int(physical["2"]["element_level"]) == 2, "exact enchantment, element and ID survive retrieval")
	_check(str(physical["2"]["record"]["sourceId"]) == "b", "original variant custom record survives")
	_check(bool(restored.retrieve("HP 물약",3,"",inventory,physical,false,0,100,3).get("ok")), "stack retrieval succeeds")
	_check(inventory["HP 물약"] == 9 and int(restored.stacks["HP 물약"]) == 1, "partial stack withdrawal count")
	_check(not bool(restored.retrieve("HP 물약",2,"",inventory,physical,false,0,100,3).get("ok")), "insufficient stored stock rejected")
	_check(not bool(restored.store("수정 단검",0,"2",inventory,physical,equipped,true).get("ok")), "zero count rejected")
	var legacy = WAREHOUSE.new()
	legacy.restore({})
	_check(legacy.stacks.is_empty() and legacy.instances.is_empty(), "old save without warehouse defaults empty")
	var map_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_field.json"))
	_check(map_value is Dictionary, "Aden map must load")
	if map_value is Dictionary:
		var found: bool = false
		for raw: Variant in (map_value as Dictionary).get("npc_spawn", []):
			if raw is Dictionary and str((raw as Dictionary).get("id","")) == "warehouse_keeper":
				found = str((raw as Dictionary).get("role","")) == "warehouse"
		_check(found, "Aden warehouse keeper must be an actual NPC")
	if problems.is_empty():
		print("WAREHOUSE_OK: exact physical IDs, enchantment, persistence, stack transfer, weight and NPC")
		quit(0)
	else:
		print("WAREHOUSE_FAILED: %d issues" % problems.size())
		quit(1)
