extends SceneTree
const BUYBACK = preload("res://scripts/shop/local_buyback.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, text_value: String) -> void:
	if not ok:
		errors.append(text_value)
		printerr("BUYBACK_FAIL: " + text_value)

func _run() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	_check(source is Dictionary, "real game item database")
	if not (source is Dictionary):
		quit(1)
		return
	var catalog: Dictionary = LOOT.build_catalog((source as Dictionary).get("아이템",[]))
	var records: Dictionary = catalog["by_name"]
	var inventory: Dictionary = {"수정 단검":2,"HP 물약":5}
	var physical: Dictionary = {
		"1":{"name":"수정 단검","level":9,"element":"fire","record":{"sourceId":"alpha"}},
		"2":{"name":"수정 단검","level":5,"element":"water","record":{"sourceId":"beta"}}
	}
	var equipped: Dictionary = {"weapon":{"name":"수정 단검","instance_id":"1"}}
	_check(not bool(BUYBACK.quote("수정 단검",1,"1",inventory,records,physical,equipped,100).get("ok")), "worn +9 weapon cannot be sold")
	_check(not bool(BUYBACK.quote("수정 단검",1,"",inventory,records,physical,equipped,100).get("ok")), "no implicit equipment instance sale")
	_check(not bool(BUYBACK.quote("수정 단검",2,"2",inventory,records,physical,equipped,100).get("ok")), "equipment batch may not sell other instance")
	var offered: Dictionary = BUYBACK.quote("수정 단검",1,"2",inventory,records,physical,equipped,100)
	_check(bool(offered.get("ok")), "free +5 original physical equipment sell quote")
	_check(int(offered.get("enhancement",-1)) == 5 and int(offered.get("payment",0)) > 0, "price quotes exact enchantment")
	var sold: Dictionary = BUYBACK.apply(offered,inventory,physical,100)
	_check(bool(sold.get("ok")), "exact original instance sale completes")
	_check(int(inventory["수정 단검"]) == 1 and physical.has("1") and not physical.has("2"), "only free item removed, equipped instance preserved")
	_check(int(sold.get("wallet",-1)) == 100 + int(offered["payment"]), "sale pays exactly one transaction")
	_check(not bool(BUYBACK.apply(offered,inventory,physical,int(sold["wallet"])).get("ok")), "repeat equipment sale cannot duplicate Adena")
	var stack: Dictionary = BUYBACK.quote("HP 물약",2,"",inventory,records,physical,equipped,100)
	_check(bool(stack.get("ok")), "ordinary potion stack buyback")
	var stack_result: Dictionary = BUYBACK.apply(stack,inventory,physical,100)
	_check(bool(stack_result.get("ok")) and int(inventory["HP 물약"]) == 3, "only selected stack amount removed")
	_check(not bool(BUYBACK.quote("HP 물약",6,"",inventory,records,physical,equipped,100).get("ok")), "over-sale rejected")
	_check(not bool(BUYBACK.quote("아데나",1,"",{"아데나":10},records,physical,equipped,100).get("ok")), "currency sale forbidden")
	_check(not bool(BUYBACK.quote("무기 마법 주문서 (각인)",1,"",{"무기 마법 주문서 (각인)":2},records,physical,equipped,100).get("ok")), "bound/engraved sale forbidden")
	_check(not bool(BUYBACK.quote("nonexistent",1,"",inventory,records,physical,equipped,100).get("ok")), "forged item name rejected")
	var map_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_field.json"))
	_check(map_value is Dictionary, "Aden map parses")
	if map_value is Dictionary:
		var found: bool = false
		for row: Variant in (map_value as Dictionary).get("npc_spawn",[]):
			if row is Dictionary and str((row as Dictionary).get("id","")) == "buyback_trader":
				found = str((row as Dictionary).get("role","")) == "buyback"
		_check(found, "buyback merchant exists in real Aden field")
	if errors.is_empty():
		print("BUYBACK_OK: enchanted instance, equipped, anti-duplication, potion stack, money and merchant")
		quit(0)
	else:
		print("BUYBACK_FAILED: %d failures" % errors.size())
		quit(1)
