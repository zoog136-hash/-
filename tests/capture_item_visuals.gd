extends SceneTree

const UI = preload("res://scripts/ui/renewal_theme.gd")
const EFFECT = preload("res://scripts/ui/item_visual.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var world: Node
var folder: String
var captures: Array = []
var chosen: Array[Dictionary] = []
var failed: bool = false

func _initialize() -> void: call_deferred("_run")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	var result: Error = pixels.save_png(folder+"/"+label+".png")
	if result != OK: failed = true; push_error("capture failed "+label)
	captures.append({"name":label,"time_ms":Time.get_ticks_msec(),"size":[pixels.get_width(),pixels.get_height()],"save_error":result})

func settle() -> void:
	for i: int in range(12): await process_frame

func _run() -> void:
	folder = OS.get_environment("TWILIGHT_ITEM_CAPTURES")
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://item-visuals")
	DirAccess.make_dir_recursive_absolute(folder+"/sequence")
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await settle()
	if not CLASS_QA.enter_game(world): push_error("class confirmation failed"); quit(1); return
	world.save_timer = -10000
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.inventory.clear()
	world.item_instances.clear()
	world.equipped_items.clear()
	# Existing source records and world grant/equip logic, isolated user data only.
	for grade_name: String in EFFECT.GRADES:
		for record: Dictionary in world.catalog_db.get("아이템",[]):
			if record.get("grade","") != grade_name or not record.has("sourceId"): continue
			chosen.append(record)
			world._grant_playtest_catalog_variant(str(record.sourceId),1)
			break
	if chosen.size() != 7:
		push_error("Expected all seven grades; got %d" % chosen.size())
		world.queue_free()
		await process_frame
		quit(1)
		return
	world._grant_playtest_catalog_item("훈련용 활",1)
	world._grant_playtest_catalog_item("무기 마법 주문서 (각인)",10)
	world._update_hud()
	var hud: Node = world.hud
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = extent
		DisplayServer.window_set_size(extent)
		hud._fit_hud()
		var suffix: String = "-%dx%d" % [extent.x,extent.y]
		hud._close_workspace()
		hud.toggle_inventory()
		hud.lineage_inventory_ui.sort_mode = 1
		hud.lineage_inventory_ui._refresh_inventory_grid()
		await settle()
		await capture("inventory"+suffix)
		for reference: String in hud.lineage_inventory_ui.slot_buttons:
			if reference.begins_with(str(chosen[5].name)):
				hud.lineage_inventory_ui._select_item(reference)
				break
		hud.lineage_inventory_ui.open_detail()
		await settle()
		await capture("detail"+suffix)
		hud.lineage_inventory_ui.detail_active = false
		hud.lineage_inventory_ui._reflow()
		world._equip_or_acquire_item(chosen[5],true)
		world._update_hud()
		hud.show_companion_equipment()
		await settle()
		await capture("equipment"+suffix)
		hud.open_catalog("아이템")
		hud._refresh_catalog_list(str(chosen[6].sourceId))
		await settle()
		await capture("catalog"+suffix)
		hud.open_warehouse()
		await settle()
		await capture("warehouse"+suffix)
		hud.open_shop()
		await settle()
		await capture("shop"+suffix)
		hud.open_crafting()
		await settle()
		await capture("crafting"+suffix)
		hud.open_enhancement("무기 마법 주문서 (각인)",world._enhancement_candidates("weapon","normal"))
		await settle()
		await capture("forge"+suffix)
		hud._close_workspace()
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	# Explicit component review board, separate from the actual gameplay captures.
	var layer := CanvasLayer.new()
	layer.layer = 200
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,130)
	panel.size = Vector2(1248,320)
	panel.theme = UI.make_theme()
	panel.add_theme_stylebox_override("panel",UI.chrome_panel(Color("101318"),UI.BRONZE,18))
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	stack.add_child(UI.label("TWILIGHT · 아이템 공통 컴포넌트 검증",24,UI.GOLD))
	stack.add_child(UI.label("실제 카탈로그 이미지 · 등급별 독립 위상 · 테두리 / +9 / E / 수량 고정",13,UI.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	stack.add_child(row)
	for record: Dictionary in chosen:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 150
		row.add_child(column)
		column.add_child(UI.label(str(record.grade),16,UI.grade(str(record.grade))))
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(122,122)
		slot.add_theme_stylebox_override("panel",UI.item_frame(str(record.grade)))
		column.add_child(slot)
		var icon := TextureRect.new()
		icon.position = Vector2(13,13)
		icon.size = Vector2(96,96)
		slot.add_child(icon)
		UI.apply_item_visual(icon,record,record.name)
		var badge := UI.label("+9",14,UI.GOLD)
		badge.position = Vector2(6,2)
		slot.add_child(badge)
		var quantity := UI.label("E          ×1",12,UI.TEXT)
		quantity.position = Vector2(6,102)
		slot.add_child(quantity)
		var title: Label = UI.label(str(record.name),11,UI.MUTED)
		title.clip_text = true
		column.add_child(title)
	await settle()
	for frame: int in range(64):
		await capture("sequence/frame-%03d" % frame)
		await create_timer(0.125).timeout
	var report := FileAccess.open(folder+"/captures.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),
		"fixture":"isolated world grants of actual catalog records; component review board explicitly separate",
		"records":chosen.map(func(r: Dictionary) -> Dictionary: return {"sourceId":r.sourceId,"name":r.name,"grade":r.grade}),
		"captures":captures,"failed":failed},"\t"))
	report.close()
	layer.queue_free()
	world.queue_free()
	await process_frame
	print("ITEM_VISUAL_CAPTURE_OK " if not failed else "ITEM_VISUAL_CAPTURE_FAILED ",captures.size())
	quit(1 if failed else 0)
