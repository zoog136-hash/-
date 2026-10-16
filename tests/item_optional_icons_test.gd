extends SceneTree
const PACK = preload("res://scripts/ui/optional_item_icon_pack.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("OPTIONAL_ICON_FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/optional_item_icons_15.json"))
	check(raw is Dictionary, "manifest JSON")
	var rows: Array = raw.get("items", []) if raw is Dictionary else []
	check(rows.size() == 15, "exactly 15 registered icon candidates")
	var seen: Dictionary = {}
	for value: Variant in rows:
		if not (value is Dictionary):
			continue
		var row: Dictionary = value
		var name_value: String = str(row.get("name", ""))
		check(not seen.has(name_value), "unique item name: " + name_value)
		seen[name_value] = true
		var typed: Dictionary = {"name":name_value,"type":str(row.get("type","")),"slot":str(row.get("slot",""))}
		check(PACK.lookup({"name":name_value,"type":"invalid","slot":"consumable"},name_value).is_empty(), "reject wrong type: " + name_value)
		check(PACK.lookup({"name":name_value,"type":typed.type,"slot":"weapon"},name_value).is_empty(), "reject wrong slot: " + name_value)
		var with_id: Dictionary = typed.duplicate(true)
		with_id["sourceId"] = "unmatched-123"
		check(PACK.lookup(with_id,name_value).is_empty(), "reject sourceId reuse: " + name_value)
		var data: Dictionary = PACK.lookup(typed,name_value)
		# JSON numbers are floats: stringify the integral ID, not "7.0.png".
		# Keep this independent of PACK.lookup so a wrong resolver path still fails.
		var icon_id: int = int(row.get("icon_id", 0))
		check(icon_id > 0 and float(icon_id) == float(row.get("icon_id", 0)), "positive integral icon ID: " + name_value)
		var path: String = "res://assets/original_items/inventory/" + str(icon_id) + ".png"
		if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == str(row.sha256):
			check(data.get("path","") == path, "installed SHA-verified image loads: " + name_value)
			var loaded: Texture2D = RESOLVER.texture(typed,name_value)
			check(loaded != null, "installed icon decodes: " + name_value)
		else:
			check(data.is_empty(), "missing/tampered image must not be used: " + name_value)
			check(RESOLVER.texture(typed,name_value) != null, "fallback remains available: " + name_value)
	var known: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["아이템"][0]
	check(RESOLVER.describe(known,str(known.name)).path == str(known.image_path), "original catalog art is never overridden")
	if failures.is_empty():
		print("OPTIONAL_ICON_OK checks=", checks)
		quit(0)
	else:
		print("OPTIONAL_ICON_FAILED ", failures.size(), "/", checks)
		quit(1)
