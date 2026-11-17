extends SceneTree
## Blessed/cursed stacks of an original 523 item keep their original picture
## identity in the bag record lookup (bag, quickslot, store and storage windows
## all resolve pictures through it), and no script loads a removed repo image.
##   godot --headless --path <repo> --script res://tests/item_icon_bless_variant_test.gd
const BAG = preload("res://scripts/ui/lineage_inventory_ui.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ITEM_ICON_BLESS_VARIANT_FAIL: " + label)

func _initialize() -> void:
	var base := {"name":"체력 회복제 (각인) · 원본#233", "sourceId":"m523:item:233", "source":"lineagem_patch523",
		"source_snapshot":"patch523", "source_m_native_item":true, "source_item_class_id":233, "source_bless_raw":1,
		"slot":"consumable", "type":"소모품", "grade":"일반"}
	var foreign := {"name":"옛 물약", "sourceId":"old:1", "slot":"consumable"}
	var bag: Control = BAG.new() # not added to the tree: no UI is built
	bag.catalog_data = {"아이템":[base, foreign]}
	check(bag._find_item_record(str(base.name)) == base, "plain stack keeps its catalog row")
	for suffix: String in [" · 축복", " · 저주"]:
		var name: String = str(base.name) + suffix
		var found: Dictionary = bag._find_item_record(name)
		check(found.get("name") == name, "variant record keeps the stack name" + suffix)
		check(int(found.get("source_item_class_id", 0)) == 233, "variant keeps the ItemClass ID (same IconID)" + suffix)
		check(int(found.get("source_bless_raw", 0)) == (2 if suffix == " · 축복" else 3), "variant bless state" + suffix)
		check(str(found.get("sourceId", "")) == "m523:item:233:bless:%d" % (2 if suffix == " · 축복" else 3), "variant sourceId matches the drop owner" + suffix)
		check(IMAGES.recognized_item(found), "variant is an original 523 picture identity" + suffix)
		check(bag._item_visual_record(name, found) == found, "bag visual record uses the variant row" + suffix)
	check(bag._find_item_record("옛 물약 · 축복").get("slot") == "other", "non-523 rows get no variant")
	check(bag._find_item_record("없는 아이템 · 축복").get("slot") == "other", "unknown base keeps the bare fallback")
	check(bag._find_item_record(str(base.name) + " · 상태4").get("slot") == "other", "unknown suffix keeps the bare fallback")
	bag.free()
	_check_dead_images()
	_finish()

## A literal load of a repo image that no longer exists logs an error on the
## phone ("No loader found ... return.png"); such loads must be guarded.
func _check_dead_images() -> void:
	var regex := RegEx.new()
	regex.compile("load\\(\"(res://assets/[^\"]+\\.(png|jpg|jpeg|webp|svg))\"")
	var unguarded: Array[String] = []
	var files: PackedStringArray = []
	_collect("res://scripts", files)
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			for found: RegExMatch in regex.search_all(lines[index]):
				var target: String = found.get_string(1)
				if FileAccess.file_exists(target) or ResourceLoader.exists(target): continue
				var guard: String = "ResourceLoader.exists(\"%s\")" % target
				if lines[index].contains(guard) or (index > 0 and lines[index - 1].contains(guard)): continue
				unguarded.append("%s:%d %s" % [path, index + 1, target])
	check(unguarded.is_empty(), "no unguarded load of a removed repo image: " + ", ".join(unguarded))
	var relic: String = FileAccess.get_file_as_string("res://scripts/ui/relic_reference_view.gd")
	check(not relic.contains("res://assets/ui/return.png"), "relic summon scroll icon no longer loads the removed return.png")
	check(preload("res://scripts/skills/lightning_vfx_art.gd").make_frames({"program":"lightning"}) == null or ResourceLoader.exists(preload("res://scripts/skills/lightning_vfx_art.gd").PATH), "missing lightning sheet gives no frames instead of a load error")

func _collect(directory: String, files: PackedStringArray) -> void:
	var dir := DirAccess.open(directory)
	if dir == null: return
	for name: String in dir.get_files():
		if name.ends_with(".gd"): files.append(directory.path_join(name))
	for name: String in dir.get_directories(): _collect(directory.path_join(name), files)

func _finish() -> void:
	print("ITEM_ICON_BLESS_VARIANT_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
