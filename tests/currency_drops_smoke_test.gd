extends SceneTree

const CURRENCY = preload("res://scripts/loot/currency_drops.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("CURRENCY_DROP_FAIL: " + label)

func _run() -> void:
	var items: Array = [{"name":"아데나", "slot":"currency", "grade":"일반"}]
	CURRENCY.ensure_items(items)
	CURRENCY.ensure_items(items)
	check(items.size() == 6, "five new currencies installed once")
	var by_name: Dictionary = {}
	for raw: Variant in items:
		var row: Dictionary = raw as Dictionary
		by_name[str(row.name)] = row
	check(CURRENCY.canonical_name("인형코인") == "마법인형 제작 코인", "doll alias")
	check(CURRENCY.canonical_name("성물코인") == "성물 제작 코인", "relic alias")
	var catalog: Dictionary = {"by_name":by_name, "l1j_monster_drops":{}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261103
	var saved_coin: int = 0
	for trial: int in range(100):
		var normal: Array[Dictionary] = CURRENCY.roll(["명예 코인"],"test","aden_world",catalog,rng,1.0)
		check(normal.size() == 1 and str(normal[0].item_name) == "명예 코인", "registered coin only in Aden")
		saved_coin += int(normal[0].quantity)
	check(saved_coin == 100, "one coin per explicit configured drop")
	check(CURRENCY.roll(["HP 물약"],"unknown","aden_world",catalog,rng,1.0).is_empty(), "no invented coin associations")
	check(CURRENCY.roll(["다이아"],"unknown","aden_world",catalog,rng,1.0).is_empty(), "Aden exclusion holds even if diamond listed")
	check(CURRENCY.roll(["명예 코인"],"test","",catalog,rng,0.0).is_empty(), "empty map/rate never grants")
	for trial: int in range(100):
		var result: Array[Dictionary] = CURRENCY.roll([],"nonmapped","faith_01",catalog,rng,1.0)
		check(result.size() == 1 and str(result[0].item_name) == "다이아", "non-Aden adds only diamonds")
		if result.size() == 1:
			check(int(result[0].quantity) >= 1 and int(result[0].quantity) <= 10, "diamond stack 1-10")
	var with_source: Dictionary = catalog.duplicate(false)
	with_source["l1j_monster_drops"] = {"source mob":[{"item_name":"마법인형 제작 코인","weight":3,"min":2,"max":4}]}
	for trial: int in range(50):
		var earned: Array[Dictionary] = CURRENCY.roll([],"source mob","aden_world",with_source,rng,1.0)
		check(earned.size() == 1 and str(earned[0].item_name) == "마법인형 제작 코인", "source mapping used")
		if earned.size() == 1:
			check(int(earned[0].quantity) >= 2 and int(earned[0].quantity) <= 4, "source quantity retained")
	check(CURRENCY.roll(["명예 코인"],"test","faith_01",catalog,rng,0.0).is_empty(), "zero resource rate never drops")
	check(LOOT.MATERIAL_DROP_RATE > 0 and LOOT.BOSS_MATERIAL_DROP_RATE > LOOT.MATERIAL_DROP_RATE, "current material rate controls additional roll")
	# Verify the actual LOOT_DROP integration, not just the isolated policy.
	# The existing equipment and potion rolls still run before currency.
	var full_catalog: Dictionary = LOOT.build_catalog(items)
	var aden_diamonds: int = 0
	var other_diamonds: int = 0
	for trial: int in range(200):
		for entry: Dictionary in LOOT.roll_detailed([], false, full_catalog, rng, "test", {}, "aden_world"):
			if str(entry.get("item_name", "")) == "다이아":
				aden_diamonds += 1
		for entry: Dictionary in LOOT.roll_detailed([], false, full_catalog, rng, "test", {}, "faith_01"):
			if str(entry.get("item_name", "")) == "다이아":
				other_diamonds += 1
				check(int(entry.get("quantity", 0)) in range(1, 11), "integrated diamond stack range")
	check(aden_diamonds == 0, "real loot pipeline never grants diamonds in Aden")
	check(other_diamonds > 0, "real loot pipeline grants non-Aden diamonds")
	var catalog_items: Array = [{"name":"명예 코인","slot":"currency","sourceId":"source-owned"}]
	CURRENCY.ensure_items(catalog_items)
	check(catalog_items.size() == 5 and str((catalog_items[0] as Dictionary).get("sourceId","")) == "source-owned", "source item record never overridden")
	if failures.is_empty():
		print("CURRENCY_DROP_PASS")
	quit(0 if failures.is_empty() else 1)
