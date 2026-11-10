extends SceneTree
## Start-up work that used to repeat per registered item:
## - the item weight index is built once while the world starts (it was built
##   about a dozen times, 30,000 original records per pass) and equals a fresh
##   full build of the final catalog;
## - catalog name lookups extend their index when records are appended;
## - the cash-shop owner lookup equals the former whole-catalog scan.
## Real input (optional): -- --source523-pack=<installed pack folder>.
const LOOKUP = preload("res://scripts/catalog_item_lookup.gd")
const CASH = preload("res://scripts/shop/source523_cash_packages.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 20: failures.append(label)

func _linear(rows: Array, item_name: String) -> Dictionary:
	for row: Variant in rows:
		if row is Dictionary and str(row.get("name", "")) == item_name: return row
	return {}

func _scan_owner(rows: Array, item_id: int) -> Dictionary:
	for row: Dictionary in rows:
		if row.get("source") in [CASH.TAG, CASH.ITEM_TAG] or bool(row.get("source_m_native_item", false)) or str(row.get("name", "")).contains(" · 원본#"): continue
		var sid: String = str(row.get("sourceId", ""))
		if int(row.get("source_item_class_id", -1)) == item_id or int(row.get("source523_shop_item_id", -1)) == item_id or (row.get("source") == "inven" and sid == str(item_id)):
			return row
	return {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Appends extend the name index instead of rebuilding it.
	var rows: Array = []
	for index: int in 50: rows.append({"name":"item%d" % (index % 40), "n":index})
	check(LOOKUP.first_by_name(rows, "item7") == _linear(rows, "item7"), "indexed lookup")
	var builds: int = LOOKUP.index_builds
	for index: int in 30:
		rows.append({"name":"added%d" % (index % 20), "n":100 + index})
		check(LOOKUP.first_by_name(rows, "added%d" % (index % 20)) == _linear(rows, "added%d" % (index % 20)), "lookup after append %d" % index)
		check(LOOKUP.first_by_name(rows, "item%d" % index) == _linear(rows, "item%d" % index), "older record after append %d" % index)
	check(LOOKUP.index_builds == builds, "appends did not rebuild the index: %d" % (LOOKUP.index_builds - builds))
	rows[3] = {"name":"replaced", "n":-1}
	check(LOOKUP.first_by_name(rows, "item3") == _linear(rows, "item3") and LOOKUP.first_by_name(rows, "replaced") == _linear(rows, "replaced"), "a record replaced in place is still found correctly")
	rows.resize(10)
	check(LOOKUP.first_by_name(rows, "added1").is_empty() and LOOKUP.first_by_name(rows, "item9") == _linear(rows, "item9"), "a shortened list is indexed again")
	# Owner lookup on a small catalog, including appended and replaced rows.
	var catalog: Array = [{"name":"a","source_item_class_id":5}, {"name":"b","source":"inven","sourceId":"7"}, {"name":"c","source523_shop_item_id":5},
		{"name":"d · 원본#9","source_item_class_id":9}, {"name":"e","source":CASH.TAG,"source_item_class_id":11}, {"name":"f","source_m_native_item":true,"source_item_class_id":12}]
	for id: int in [5, 7, 9, 11, 12, 13, -1]: check(CASH._exact_owner(catalog, id) == _scan_owner(catalog, id), "scanned owner %d" % id)
	# The index is used only during install(); the same answers with it on.
	CASH._owner_rows = []
	CASH._owner_trusted = true
	for id: int in [5, 7, 9, 11, 12, 13, -1]: check(CASH._exact_owner(catalog, id) == _scan_owner(catalog, id), "owner %d" % id)
	catalog.append({"name":"g","source_item_class_id":13})
	catalog.append({"name":"h","source":"inven","sourceId":"5"})
	for id: int in [5, 13]: check(CASH._exact_owner(catalog, id) == _scan_owner(catalog, id), "owner after append %d" % id)
	CASH._owner_trusted = false
	catalog[0] = {"name":"a2","source_item_class_id":6}
	for id: int in [5, 6]: check(CASH._exact_owner(catalog, id) == _scan_owner(catalog, id), "owner after replace %d" % id)
	var base: String = ""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="): base = value.trim_prefix("--source523-pack=")
	if not base.is_empty():
		var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
		check(read.ok and PACK.apply(PACK.selections(base, read.descriptor, PACK.read_addons(base))).ok, "installed pack applied")
		HOST.refresh()
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(int(world.get("item_weight_index_builds")) == 1, "the start built the weight index once: %d" % int(world.get("item_weight_index_builds")))
	check(not bool(world.get("_weight_index_deferred")) and not bool(world.get("_weight_index_pending")), "nothing is left deferred")
	var started: Dictionary = (world.get("item_weight_index") as Dictionary).duplicate(true)
	world.call("_index_item_weights")
	check(world.get("item_weight_index") == started, "the one build equals a fresh full build")
	check(int(world.get("item_weight_index_builds")) == 2, "later requests build immediately")
	var items: Array = world.get("catalog_db").get("아이템", [])
	var compared: int = 0
	CASH._owner_rows = []
	CASH._owner_trusted = true
	for index: int in range(0, items.size(), maxi(1, items.size() / 400)):
		var row: Dictionary = items[index]
		for field: String in ["source_item_class_id", "source523_shop_item_id"]:
			if row.has(field):
				compared += 1
				check(CASH._exact_owner(items, int(row[field])) == _scan_owner(items, int(row[field])), "live owner %d" % int(row[field]))
	CASH._owner_trusted = false
	print("BOOT_INDEX_ONCE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not base.is_empty(),"weights":started.size(),"catalog":items.size(),"owners_compared":compared}))
	quit(0 if failures.is_empty() else 1)
