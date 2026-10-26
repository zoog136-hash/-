extends SceneTree

const LOOKUP = preload("res://scripts/catalog_item_lookup.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("CATALOG_ITEM_LOOKUP_FAIL: ", label)

func _initialize() -> void:
	var first: Dictionary = {"name":"same", "heal":10}
	var catalog: Array = [null, first, {"name":"same", "heal":20}]
	var base: Array = [{"name":"same", "heal":30}, {"name":"base", "heal":40}]
	var physical: Dictionary = {"name":"generated", "record":{"heal":50, "buff":{"hp":1}}}
	var instances: Dictionary = {"invalid":17, "first":physical,
		"later":{"name":"generated", "record":{"heal":60}}}
	var names: Array = ["same", "base", "generated", "missing", "해독제"]
	var found: Dictionary = LOOKUP.find_many([17, catalog, base], instances, names)
	check(found.size() == 3 and found.same == first, "first catalog match precedes base and duplicates")
	check(found.base.heal == 40 and found.generated.heal == 50, "base and first physical fallback")
	found.generated.buff.hp = 99
	check(physical.record.buff.hp == 1, "physical fallback remains a deep copy")
	first.heal = 11
	check(LOOKUP.find_many([catalog, base], instances, names).same.heal == 11, "current catalog edits are visible")
	catalog.clear()
	check(LOOKUP.find_many([catalog, base], instances, names).same.heal == 30, "removed catalog records expose current base")
	check(LOOKUP.find_many([[{"name":"해독제"}]], {}, ["해독제"]).is_empty(), "removed consumables stay removed")
	check(LOOKUP.find_many([catalog, base], instances, []).is_empty(), "empty request")
	print("CATALOG_ITEM_LOOKUP_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
