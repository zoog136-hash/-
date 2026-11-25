extends SceneTree
## Render every original ItemClass through the native Common_Slot item sprite.
## Private inputs: pinned definition ZIP, UI, image and icon selection env vars.
## Run on a rendering display, passing the ZIP and a private output JSONL path after --.
const Hub = preload("res://scripts/ui/source523_image_assets.gd")
const Pack = preload("res://scripts/ui/original_ui/source_pack.gd")
const NamedTree = preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const Icons = preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd")
const Rows = preload("res://scripts/resources/current523_definition_rows.gd")
const SLOT = "UI/CommonUi/Common_Slot.csb"
const SPRITE = 15012
const CELL = 96
const COLUMNS = 8
const BATCH = 64

class IconHUD extends Node:
	var _original_icon_scene_provider: Callable

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var zip_path := args[0] if args.size() == 2 else ""
	if args.size() != 2 or not args[1].ends_with(".jsonl") or DisplayServer.get_name() == "headless" or FileAccess.get_sha256(zip_path) != Rows.SOURCE_SHA:
		printerr("A display, pinned definition ZIP and private output path are required")
		quit(1)
		return
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		quit(2)
		return
	var rows: Array = JSON.parse_string(zip.read_file("content/ItemClass.json").get_string_from_utf8()).rows
	zip.close()
	var pack := Pack.new()
	var opened: Dictionary = pack.open(OS.get_environment("TWILIGHT_SOURCE_UI"), OS.get_environment("TWILIGHT_SOURCE_UI_SHA256"))
	if not opened.get("ok", false) or not Hub.selected() or rows.size() != 34743:
		printerr("Source selection failed ", opened.get("error"), " rows=", rows.size())
		quit(3)
		return
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	if output == null:
		quit(4)
		return
	var hud := IconHUD.new()
	hud._original_icon_scene_provider = Hub.native_original_icon_scene
	root.add_child(hud)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL * COLUMNS, CELL * (BATCH / COLUMNS))
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var tree := NamedTree.new(pack, {SLOT:[SPRITE]})
	var players: Array[Node2D] = []
	for i in BATCH:
		var cell := Control.new()
		cell.clip_contents = true
		cell.size = Vector2(CELL, CELL)
		cell.position = cell_rect(i).position
		viewport.add_child(cell)
		var built: Dictionary = tree.scene_of(SLOT, {"Sp_IconSample":{"role":"source_asset_slot","visible":false}}, {})
		if not built.get("ok", false):
			printerr("Original sprite refused ", built)
			quit(5)
			return
		var player: Node2D = built.scene
		player.position = cell.size * 0.5
		cell.add_child(player)
		players.append(player)
	var counts := {}
	var mismatches := 0
	var seen := {}
	for start in range(0, rows.size(), BATCH):
		var records: Array[Dictionary] = []
		for i in mini(BATCH, rows.size() - start):
			var row: Dictionary = rows[start + i]
			var id := int(row.ID)
			if seen.has(id):
				printerr("Duplicate ItemClass.ID ", id)
				quit(6)
				return
			seen[id] = true
			var player := players[i]
			player.set_bound_visible(SPRITE, false)
			var info := Hub.describe_item_class_row(row)
			var bound := Icons.show_item(player, SPRITE, info, hud)
			if not bound and info.get("reason") == "unsupported_csb":
				var origin: Dictionary = player.external_scene_slot_contract(pack, SLOT, SPRITE)
				var provider := Icons.request(hud, info, {"source_slot_contract":origin})
				var result: Dictionary = player.set_bound_source_visual_result(SPRITE, provider) if provider.get("ok",false) else provider
				printerr("ITEM_SCENE_FAILURE id=", id, " error=", result.get("error",result.get("code")), " details=", result.get("details",[]), " detail=",result.get("problem",{}))
			var kind := "scene" if info.get("reason") == "unsupported_csb" else "image"
			records.append({"id":id, "test":row.TestItem, "icon_id":int(row.get("IconID",0)), "kind":kind, "bound":bound, "reason":info.get("reason","")})
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		for i in records.size():
			var record := records[i]
			var used := image.get_region(cell_rect(i)).get_used_rect()
			record["pixels_visible"] = used.has_area()
			var result := "visible" if record.bound and used.has_area() else "bound_blank" if record.bound else "unbound"
			if not record.bound and used.has_area():
				printerr("Previous image leaked into slot for ", record.id)
				quit(7)
				return
			var expected: bool = not record.test and record.icon_id > 0
			if expected != (result == "visible") or result == "bound_blank":
				mismatches += 1
				printerr("Unexpected visibility for ItemClass ", record.id, " expected=", expected, " result=", result)
			counts[result] = int(counts.get(result, 0)) + 1
			output.store_line(JSON.stringify(record))
		if start % 4096 == 0:
			output.flush()
			print("ITEM_PIXEL_PROGRESS ", start + records.size(), " ", counts)
	output.close()
	viewport.queue_free()
	hud.queue_free()
	await process_frame
	for selected: RefCounted in Hub.ORIGINAL_UI_ICONS.packs_by_manifest.values():
		selected.release_cache_leases()
	pack.release_cache_leases()
	print("ITEM_PIXEL_RESULT ids=", seen.size(), " ", JSON.stringify(counts), " mismatches=", mismatches)
	quit(0 if mismatches == 0 else 8)

func cell_rect(index: int) -> Rect2i:
	@warning_ignore("integer_division")
	return Rect2i(index % COLUMNS * CELL, index / COLUMNS * CELL, CELL, CELL)
