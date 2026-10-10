extends SceneTree
const CRAFT = preload("res://scripts/crafting/local_crafting.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
var bad: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		bad.append(message)
		printerr("CRAFT_FAIL: " + message)

func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	_check(parsed is Dictionary, "actual TWILIGHT DB parses")
	if not (parsed is Dictionary):
		quit(1)
		return
	var catalog: Dictionary = LOOT.build_catalog((parsed as Dictionary).get("아이템", []))
	var by_name: Dictionary = catalog["by_name"]
	for id: String in CRAFT.RECIPES.keys():
		var recipe: Dictionary = CRAFT.RECIPES[id]
		_check(by_name.has(str(recipe["output"])), "result present in actual game item DB: " + id)
		for material: Variant in (recipe["materials"] as Dictionary).keys():
			_check(by_name.has(str(material)), "ingredient in actual game item DB: " + id)
	var weights: Dictionary = {"HP 물약":1,"강력 HP 물약":2,"축복받은 HP 물약":3}
	var inventory: Dictionary = {"HP 물약":10,"강력 HP 물약":0,"축복받은 HP 물약":0}
	var failed: Dictionary = CRAFT.quote("hp_mid",4,inventory,100000,catalog,weights,10,100)
	_check(not bool(failed.get("ok",false)), "insufficient materials reject entire 4x batch")
	_check(inventory["HP 물약"] == 10, "failed quote never consumes inventory")
	var offer: Dictionary = CRAFT.quote("hp_mid",2,inventory,500,catalog,weights,10,100)
	_check(bool(offer.get("ok")), "2x crafting quote succeeds")
	_check(int(offer.get("gold",-1)) == 240 and int(offer.get("output_count",-1)) == 2, "recipe totals exact")
	var output: Dictionary = CRAFT.execute(offer,inventory,500)
	_check(bool(output.get("ok")), "crafting transaction succeeds")
	_check(int(output.get("wallet",-1)) == 260, "no duplicated or missing Adena")
	_check(int(inventory["HP 물약"]) == 4 and int(inventory["강력 HP 물약"]) == 2, "ingredients consumed and result awarded once")
	_check(not bool(CRAFT.quote("hp_blessed",1,inventory,9999,catalog,weights,100,100).get("ok")), "missing intermediate components reject")
	_check(not bool(CRAFT.quote("hp_mid",1,inventory,119,catalog,weights,10,100).get("ok")), "insufficient Adena reject")
	var heavy_weights: Dictionary = {"HP 물약":1,"강력 HP 물약":20,"축복받은 HP 물약":30}
	_check(not bool(CRAFT.quote("hp_mid",1,inventory,9999,catalog,heavy_weights,100,100).get("ok")), "encumbrance prevents over-capacity result")
	_check(not bool(CRAFT.quote("__forged__",1,inventory,9999,catalog,weights,0,100).get("ok")), "unlisted recipe rejected")
	for amount: int in [-1,0,51,1000]:
		_check(not bool(CRAFT.quote("hp_mid",amount,inventory,99999,catalog,weights,0,9999).get("ok")), "invalid count: " + str(amount))
	var map_value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_field.json"))
	_check(map_value is Dictionary, "Aden map preserved")
	if map_value is Dictionary:
		var artisan: bool = false
		for row: Variant in (map_value as Dictionary).get("npc_spawn", []):
			if row is Dictionary:
				var npc: Dictionary = row as Dictionary
				if str(npc.get("id","")) == "craft_artisan":
					artisan = str(npc.get("role","")) == "craft"
		_check(artisan, "in-world craft artisan exists")
	if bad.is_empty():
		print("CRAFT_OK: 2 real-item recipes, costs, exact item counts, forged inputs, capacity and artisan NPC")
		quit(0)
	else:
		print("CRAFT_FAILED: %d" % bad.size())
		quit(1)
