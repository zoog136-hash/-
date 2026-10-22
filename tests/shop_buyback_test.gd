extends SceneTree
const BUYBACK = preload("res://scripts/shop/local_buyback.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
const SHOP = preload("res://scripts/shop/shop_catalog.gd")
const STOCK = preload("res://scripts/shop/consumable_stock.gd")
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
	_check_price_bounds(records)
	_check_wallet_revalidation(records)
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

func _check_price_bounds(records: Dictionary) -> void:
	# These real DB tiers used to sell for 40/200/800. Purchases stay 50/180/450.
	for fixture: Array in [["HP 물약",50,40],["강력 HP 물약",180,180],["축복받은 HP 물약",450,450]]:
		var item_name: String = str(fixture[0])
		_check(SHOP.price_for(item_name) == int(fixture[1]), "legacy purchase price unchanged: " + item_name)
		_check(records.has(item_name), "real DB roundtrip item: " + item_name)
		for quantity: int in range(1, BUYBACK.MAX_STACK_SALE + 1):
			var inventory: Dictionary = {item_name:quantity}
			var offered: Dictionary = BUYBACK.quote(item_name,quantity,"",inventory,records,{}, {},0)
			_check(bool(offered.get("ok",false)), "legacy potion sell quote: " + item_name)
			_check(int(offered.get("payment",-1)) == int(fixture[2]) * quantity, "no legacy potion arbitrage: " + item_name)
	# All expanded stock still uses the same purchase authority. Existing
	# bound/non-tradeable restrictions remain allowed to refuse a sale.
	var stock_records: Dictionary = {}
	for record: Dictionary in STOCK.records():
		stock_records[str(record.get("name",""))] = record
	var accepted: int = 0
	for entry: Array in SHOP.GOODS:
		var item_name: String = str(entry[0])
		var offered: Dictionary = BUYBACK.quote(item_name,1,"",{item_name:1},stock_records,{}, {},0)
		if bool(offered.get("ok",false)):
			accepted += 1
			_check(int(offered["payment"]) <= SHOP.price_for(item_name), "expanded stock cannot yield a buy/sell profit: " + item_name)
	_check(accepted > 0, "stock roundtrip coverage must not silently skip every offer")
	var synthetic: Dictionary = {
		"unlisted potion":{"name":"unlisted potion","slot":"consumable","grade":"희귀"},
		"test weapon":{"name":"test weapon","slot":"weapon","grade":"영웅"}
	}
	var unlisted: Dictionary = BUYBACK.quote("unlisted potion",1,"",{"unlisted potion":1},synthetic,{}, {},0)
	_check(bool(unlisted.get("ok",false)) and int(unlisted.get("payment",0)) == 800, "unlisted consumable valuation unchanged")
	var weapon: Dictionary = BUYBACK.quote("test weapon",1,"free",{"test weapon":1},synthetic,{"free":{"name":"test weapon","level":5}}, {},0)
	_check(bool(weapon.get("ok",false)) and int(weapon.get("payment",0)) == 6750, "equipment grade/enchantment valuation unchanged")

func _check_wallet_revalidation(records: Dictionary) -> void:
	var inventory: Dictionary = {"HP 물약":2}
	var physical: Dictionary = {}
	var offered: Dictionary = BUYBACK.quote("HP 물약",1,"",inventory,records,physical,{},0)
	_check(bool(offered.get("ok",false)), "valid quote before wallet change")
	var payment: int = int(offered.get("payment",0))
	_check(payment == 40, "ordinary HP potion price preserved")
	var snapshot: Dictionary = inventory.duplicate(true)
	var rejected: Dictionary = BUYBACK.apply(offered,inventory,physical,BUYBACK.MAX_WALLET - payment + 1)
	_check(not bool(rejected.get("ok",false)) and inventory == snapshot and physical.is_empty(), "stale wallet over-limit sale rejected without mutation")
	var boundary: Dictionary = BUYBACK.apply(offered,inventory,physical,BUYBACK.MAX_WALLET - payment)
	_check(bool(boundary.get("ok",false)) and int(boundary.get("wallet",0)) == BUYBACK.MAX_WALLET, "exact wallet limit accepted")
	_check(int(inventory["HP 물약"]) == 1, "boundary sale removes one stack item")
	# The overflow rejection must also occur before destroying equipment.
	var gear_inventory: Dictionary = {"수정 단검":1}
	var gear_physical: Dictionary = {"free":{"name":"수정 단검","level":5}}
	var gear_offer: Dictionary = BUYBACK.quote("수정 단검",1,"free",gear_inventory,records,gear_physical,{},0)
	_check(bool(gear_offer.get("ok",false)), "equipment quote before wallet change")
	var gear_snapshot: Dictionary = gear_physical.duplicate(true)
	var gear_rejected: Dictionary = BUYBACK.apply(gear_offer,gear_inventory,gear_physical,BUYBACK.MAX_WALLET)
	_check(not bool(gear_rejected.get("ok",false)) and int(gear_inventory["수정 단검"]) == 1 and gear_physical == gear_snapshot, "wallet overflow cannot delete a physical equipment instance")
