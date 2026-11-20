extends SceneTree
## Item catalog list (user screenshot 2026-11-20, 신화 tab): one row
## (생명의 단검, a static PNG icon) drew a large picture that broke the grid
## while every animated-icon (CSB) row and every legacy row whose name has
## several original rows showed only its name. Every row now has one
## same-size icon cell with its original picture (texture or CSB scene), and
## the detail panel shows the same original picture.
const QA = preload("res://tests/qa_class_selection.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const IDENTITY = preload("res://scripts/ui/source523_item_identity.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CATALOG_ITEM_ICON_CELLS_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func frames(count: int) -> void:
	for frame: int in range(count): await process_frame

## A picture is on the cell: a texture, or an attached original CSB scene.
static func pictured(view: TextureRect) -> String:
	if view.texture != null: return "texture"
	var info: Variant = view.get_meta("item_visual", {})
	if info is Dictionary and str(info.get("status", "")) in ["verified_source_scene", "source_scene_estimate"]: return "scene"
	return ""

func run() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var hud: Node = world.hud
	var native_installed: bool = not DEF.not_installed()
	evidence["native"] = native_installed
	hud.call("open_catalog", "아이템")
	await frames(4)
	if native_installed:
		hud.set("catalog_grade_filter", "신화")
		hud.call("_refresh_catalog_list", "")
	await frames(40)
	var list: ItemList = hud.get("catalog_list")
	var results: Array = hud.get("catalog_results")
	var views: Array = hud.get("catalog_icon_views")
	evidence["rows"] = results.size()
	check(list.item_count == results.size() and results.size() > 0, "the item catalog shows a page")
	var icon: Vector2 = Vector2(list.fixed_icon_size)
	check(icon.x == icon.y and icon.x <= 64.0, "item icon cells are square and small (%s)" % str(icon))
	var kinds: Dictionary = {}
	var empty: Array = []
	var scroll: float = list.get_v_scroll_bar().value
	for index: int in range(results.size()):
		check(list.get_item_icon(index) != null and Vector2(list.get_item_icon(index).get_size()) == icon, "row %d reserves the same icon slot" % index)
		if index >= views.size(): empty.append(str(results[index].get("name", ""))); continue
		var view: TextureRect = views[index]
		check(view.size == icon, "row %d icon cell has the shared size (%s)" % [index, str(view.size)])
		var center: Vector2 = view.position + view.size * 0.5
		if center.y >= 0.0 and center.y <= list.size.y:
			check(list.get_item_at_position(center, true) == index, "row %d icon cell lies on its own row" % index)
		var kind: String = pictured(view)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		if kind.is_empty(): empty.append(str(results[index].get("name", "")))
	evidence["cells"] = kinds
	evidence["no_picture"] = empty.slice(0, 12)
	evidence["scroll"] = scroll
	if native_installed:
		check(empty.is_empty(), "every 신화 row on the page has its original picture (%s)" % str(empty.slice(0, 12)))
		check(int(kinds.get("scene", 0)) > 0, "animated original icons (CSB) are drawn in their cells")
		# Detail: the selected row's original picture (texture or scene).
		for index: int in range(results.size()):
			if pictured(views[index]) != "scene": continue
			hud.call("_select_catalog_index", index)
			await frames(4)
			var preview: TextureRect = hud.get("catalog_preview")
			check(not pictured(preview).is_empty(), "the detail shows the animated original icon of %s" % str(results[index].get("name", "")))
			break
		# Legacy rows whose name has several original rows use their own publisher ID.
		var legacy: Dictionary = {"name":"앨리스(단검)", "sourceId":"263788", "source":"inven"}
		if IDENTITY.original_name(263788) == "앨리스(단검)":
			check(IDENTITY.item_class_id(legacy) == 263788, "a legacy row takes the ItemClass of its own sourceId when the original name matches")
		check(IDENTITY.item_class_id({"name":"앨리스(단검)", "sourceId":"1"}) != 1, "a mismatched sourceId is never taken")
		# Whole-catalog link rate (texture or animated scene).
		var data: Array = hud.get("catalog_data").get("아이템", [])
		var images: Dictionary = hud.get("item_image_index").get("아이템", {})
		var total: int = 0; var linked: int = 0; var reasons: Dictionary = {}
		for record: Variant in data:
			if not record is Dictionary or record.get("source_preserved_legacy_catalog", false): continue
			total += 1
			var info: Dictionary = RESOLVER.describe(record, str(record.get("name", "")), images, false)
			if info.get("texture") is Texture2D or str(info.get("reason", "")) == "unsupported_csb": linked += 1
			else: reasons[str(info.get("reason", info.get("status", "")))] = int(reasons.get(str(info.get("reason", info.get("status", ""))), 0)) + 1
		evidence["catalog"] = {"total":total, "linked":linked, "missing":reasons}
		check(total > 0 and float(linked) / float(total) >= 0.99, "at least 99%% of the item catalog has an original icon (%d/%d)" % [linked, total])
	world.queue_free()
	await frames(4)
	print("CATALOG_ITEM_ICON_CELLS_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
