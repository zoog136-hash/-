extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const Dialog = preload("res://scripts/ui/renewal_dialog.gd")
var world: TwilightWorld
var folder: String
var captures: Array = []
var failed: bool = false

func _initialize() -> void: call_deferred("_run")
func _capture(label: String) -> void:
	for frame: int in range(18): await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	var path: String = folder+"/"+label+".png"
	var result: Error = pixels.save_png(path)
	if result != OK: failed=true; push_error("Fidelity capture failed: "+label)
	captures.append({"name":label,"width":pixels.get_width(),"height":pixels.get_height(),"path":path,"save_error":result})

func _run() -> void:
	folder = ProjectSettings.globalize_path("user://ui-fidelity-review")
	DirAccess.make_dir_recursive_absolute(folder)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for i: int in range(12): await process_frame
	if not CLASS_QA.enter_game(world): push_error("Class confirmation failed"); quit(1); return
	world.save_timer = -10000
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	# Isolated real source-record equipment fixture, via existing equip/ID logic.
	var supplied: Array[String] = []
	for raw: Variant in world.catalog_db.get("아이템",[]):
		if not raw is Dictionary: continue
		var record: Dictionary = raw
		var slot: String = world._equipment_slot_base(record)
		if slot not in ["weapon","body","helmet","boots","gloves","cloak","necklace","tshirt","belt","ring"] or slot in supplied: continue
		world._equip_or_acquire_item(record,true)
		supplied.append(slot)
		if supplied.size() >= 10: break
	world._update_hud()
	var hud: Node = world.hud
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(854,480),Vector2i(720,720),Vector2i(1920,1080),Vector2i(2400,1080)]:
		root.size = extent
		DisplayServer.window_set_size(extent)
		for i: int in range(3): await process_frame
		hud.workspace.title_dragged = false
		hud._fit_hud()
		var suffix: String = "-%dx%d" % [extent.x,extent.y]
		hud._close_workspace()
		await _capture("hud"+suffix)
		hud.toggle_inventory()
		await _capture("inventory"+suffix)
		var inventory_ui: Control = hud.lineage_inventory_ui
		if not inventory_ui.slot_buttons.is_empty():
			inventory_ui._select_item(str(inventory_ui.slot_buttons.keys()[0]))
		await _capture("inventory-detail"+suffix)
		hud.open_character()
		await _capture("character"+suffix)
		hud.lineage_side_ui._show_stats_page()
		await _capture("character-stats"+suffix)
		hud.lineage_side_ui._show_equipment_page()
		hud.open_class_selection()
		await _capture("class-select"+suffix)
		hud.open_skills()
		await _capture("skills"+suffix)
		var browser: Control = hud.skills_view.cards.get_parent().get_parent()
		browser.detail_active = true
		browser.reflow()
		await _capture("skill-detail"+suffix)
		hud.toggle_map()
		await _capture("map"+suffix)
		hud.toggle_menu()
		await _capture("menu"+suffix)
		for category: String in ["아이템","변신","마법인형","성물"]:
			hud.open_catalog(category)
			await _capture("catalog-"+category+suffix)
			if not hud.catalog_results.is_empty(): hud._on_catalog_item_selected(0)
			hud._set_catalog_detail_view(true)
			await _capture("catalog-detail-"+category+suffix)
		hud.open_shop()
		await _capture("shop"+suffix)
		hud.open_quest_info()
		await _capture("quest"+suffix)
		hud._open_enhance_chooser()
		await _capture("forge"+suffix)
		hud.open_enhancement("무기 마법 주문서 (각인)",world._enhancement_candidates("weapon","normal"))
		await _capture("forge-target"+suffix)
		hud.open_macro_info()
		await _capture("auto"+suffix)
		hud.open_settings_info()
		await _capture("settings"+suffix)
		var dialog := Dialog.new()
		dialog.title_text = "저장된 게임 불러오기"
		dialog.message_text = "현재 미저장 진행도가 사라질 수 있습니다. 저장본을 불러올까요?"
		hud.get_node("Root").add_child(dialog)
		await _capture("confirmation"+suffix)
		dialog.queue_free()
		await process_frame
		hud.open_chat_info()
		await _capture("log"+suffix)
	var report := FileAccess.open(folder+"/render-results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"fixture":"isolated source-record equipment granted through existing world logic","captures":captures},"\t"))
	report.close()
	if captures.size() != 156: failed=true; push_error("Expected 156 fidelity captures; got %d" % captures.size())
	world.queue_free()
	await process_frame
	print("UI_FIDELITY_CAPTURE_OK " if not failed else "UI_FIDELITY_CAPTURE_FAILED ",captures.size()," ",folder)
	quit(1 if failed else 0)
