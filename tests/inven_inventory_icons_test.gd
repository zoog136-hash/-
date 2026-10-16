extends SceneTree
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const INVENTORY = preload("res://scripts/ui/inven_inventory_icons.gd")
const UNRESOLVED: Array[String] = []
var checks: int = 0
var failures: Array[String] = []
var counts: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("INVEN_INVENTORY_FAIL " + message)

func inspect(record: Dictionary, group: String) -> void:
	var original: String = JSON.stringify(record)
	var item_name: String = str(record.get("name", ""))
	var info: Dictionary = RESOLVER.describe(record, item_name)
	var texture: Texture2D = RESOLVER.texture(record, item_name)
	if item_name in UNRESOLVED and str(record.get("sourceId", "")).is_empty():
		check(texture != null and info.status == "self_authored_substitute", "honest unresolved source:" + item_name)
	else:
		check(texture != null and not texture.has_meta("item_family"), group + ":real picture:" + item_name)
		check(not str(info.path).is_empty() and info.status in ["original_linked", "inven_exact_name", "inven_visual_alias"], group + ":audited path:" + item_name)
	if texture != null and not str(info.path).is_empty():
		var expected: Texture2D = load(info.path) as Texture2D
		check(expected != null and texture.get_image().get_data() == expected.get_image().get_data(), group + ":unaltered pixels:" + item_name)
	if group == "catalog":
		check(info.path == record.get("image_path", ""), "catalog path unchanged:" + item_name)
	var ground: Dictionary = RESOLVER.describe(record, item_name, {}, true)
	var before_ground: Dictionary = RESOLVER._describe_original(record, item_name, {}, true)
	if before_ground.route in ["reviewed_ground", "l1j_dedicated_ground_candidate"]:
		check(JSON.stringify(ground) == JSON.stringify(before_ground), "dedicated ground unchanged:" + item_name)
	else:
		check(ground.get("route", "") == "ground_category" and ground.get("name", "") == item_name, "independent ground category preserves item name:" + item_name)
	check(JSON.stringify(record) == original, "gameplay record unchanged:" + item_name)
	if group == "runtime": counts[info.status] = int(counts.get(info.status, 0)) + 1

func _run() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	for record: Dictionary in catalog["아이템"]: inspect(record, "catalog")
	for record: Dictionary in legacy["아이템"]: inspect(record, "legacy")
	for record: Dictionary in world.catalog_db.get("아이템", []): inspect(record, "runtime")
	var sample: Dictionary = {"name":"훈련용 활", "type":"활", "slot":"weapon"}
	check(not INVENTORY.lookup(sample, sample.name).is_empty(), "custom bow explicitly bound")
	var rejected: Dictionary = sample.duplicate(true)
	rejected.sourceId = "unrelated-source"
	check(INVENTORY.lookup(rejected, rejected.name).is_empty(), "cannot override source ID")
	rejected = sample.duplicate(true)
	rejected.type = "지팡이"
	check(INVENTORY.lookup(rejected, rejected.name).is_empty(), "wrong equipment kind rejected")
	rejected = sample.duplicate(true)
	rejected.slot = "consumable"
	check(INVENTORY.lookup(rejected, rejected.name).is_empty(), "wrong slot rejected")
	check(INVENTORY.lookup(sample, "천상의 활").is_empty(), "wrong item name rejected")
	check(INVENTORY.lookup({"name":"훈련용 활"}, "훈련용 활").is_empty(), "incomplete identity cannot borrow art")
	check(RESOLVER.cache_size() <= 256, "texture cache remains bounded")
	# Explicit visual aliases are inventory-only. These three names remain distinct gameplay items.
	for variant: Dictionary in [
		{"name":"정제된 목재", "type":"제작재료", "slot":"consumable"},
		{"name":"약초", "type":"제작재료", "slot":"consumable"},
		{"name":"드래곤의 용옥", "type":"축복버프", "slot":"consumable"}
	]:
		var alias: Dictionary = INVENTORY.lookup(variant, str(variant["name"]))
		check(not alias.is_empty() and str(alias.get("match_kind", "")) == "visual_alias", "reviewed visual alias: " + str(variant["name"]))
		var shown: Dictionary = RESOLVER.describe(variant, str(variant["name"]))
		check(shown.get("status", "") == "inven_visual_alias", "inventory shows substitute art: " + str(variant["name"]))
		check(shown.get("path", "") == alias.get("path", ""), "correct substitute image path: " + str(variant["name"]))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY.MANIFEST))
	check(manifest.items.size() == int(counts.get("inven_exact_name", 0)) + int(counts.get("inven_visual_alias", 0)), "all explicit inventory bindings exercised")
	var report: Dictionary = {"checks":checks,"runtime_rows":world.catalog_db.get("아이템", []).size(),"states":counts,"unresolved":UNRESOLVED,"failures":failures}
	print("INVEN_INVENTORY_RESULT ", JSON.stringify(report))
	var report_path: String = OS.get_environment("TWILIGHT_INVEN_REPORT")
	if not report_path.is_empty():
		var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t"))
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("INVEN_INVENTORY_OK")
	quit(0 if failures.is_empty() else 1)
