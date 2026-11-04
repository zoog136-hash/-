extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
var checks: int = 0
var failures: Array[String] = []
var captures: String = ""
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("RELIC_LEVEL_UI_FAIL ", message)
func _initialize() -> void: call_deferred("run")
func frames(count: int = 4) -> void:
	for _index: int in range(count): await process_frame
func tap(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * .5)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.pressed = down
		root.push_input(event, true)
func run() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-zip="): path = arg.trim_prefix("--source-zip=")
		if arg.begins_with("--captures="): captures = arg.trim_prefix("--captures=")
	if path.is_empty(): printerr("Explicit authorized source ZIP required"); quit(2); return
	root.size = Vector2i(1280, 720)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world); await frames(8)
	check(QA.enter_game(world), "actual Main class confirmation")
	world.set_process(false); world.save_timer = -100000.0
	world.player.set_physics_process(false); world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	var hud: Node = world.hud
	var record: Dictionary = {}
	for row: Dictionary in world.catalog_db["성물"]:
		if int(row.get("source_card_id", 0)) == 21428: record = row; break
	check(not record.is_empty(), "actual canonical hero relic")
	var identity: String = CARDS.card_id(record)
	world.card_draw_fusion.owned["성물"][identity] = true
	world._update_hud()
	check(world._save_game(true) == OK, "durable initial progression fixture")
	var save_hash: String = FileAccess.get_sha256(world.save_path())
	var inventory: Dictionary = world.inventory.duplicate(true)
	var gold: int = world.gold
	var cards: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
	hud.open_catalog("성물"); await frames(6)
	hud.catalog_search.text = str(record.name); hud.catalog_search.text_changed.emit(str(record.name)); await frames(4)
	var selected_index: int = -1
	for index: int in range(hud.catalog_results.size()):
		if CARDS.card_id(hud.catalog_results[index]) == identity: selected_index = index; break
	check(selected_index >= 0, "search retains exact selected source identity")
	if selected_index >= 0: hud._on_catalog_item_selected(selected_index)
	await frames(4)
	var panel: Control = hud.relic_reference_view.spell_level_panel
	check(panel.is_visible_in_tree() and panel.import_button.is_visible_in_tree(), "ordinary relic screen exposes rule import")
	check(not panel.snapshot.ok and not panel.status.text.is_empty(), "missing source clearly displayed")
	hud.relic_reference_view.right_scroll.ensure_control_visible(panel.import_button); await frames()
	tap(panel.import_button); await frames()
	check(panel.picker.visible and panel.picker.file_mode == FileDialog.FILE_MODE_OPEN_FILE, "real source file picker opens")
	panel.picker.hide(); panel.picker.canceled.emit()
	check(FileAccess.get_sha256(world.save_path()) == save_hash, "cancel import preserves exact save")
	tap(panel.import_button); await frames()
	check(panel.picker.visible, "pointer reopens real source picker")
	panel.picker.file_selected.emit(path); await frames(6)
	check(panel.snapshot.ok and panel.snapshot.code == "not_equipped" and panel.values.text.contains("일반 스킬 레벨 +1"), "source selection displays original bonus before summon")
	check(FileAccess.get_sha256(world.save_path()) == save_hash, "source installation preserves exact progression save")
	hud.catalog_equip_button.pressed.emit(); await frames()
	var modal: Control = hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	check(modal != null, "existing summon confirmation remains wired")
	if modal != null: modal.confirm_button.pressed.emit()
	await frames(6)
	check(CARDS.card_id(world.equipped_catalog["성물"]) == identity, "existing summon flow applies exact card")
	check(panel.snapshot.active and panel.status.text.contains("현재 소환"), "live result reflects actual equipped card")
	check(hud.relic_reference_view.status.text.contains(str(record.name)), "existing current-summon label refreshes with the new bonus panel")
	check(world.source_relic_spell_level(1, 0).effective_level == 1 and world.source_relic_spell_level(4, 0).effective_level == 0, "actual Main grade-specific level modifier")
	check(not world.source_relic_spell_level(1, 0).combat_values_connected and panel.status.text.contains("전투 수치"), "unmapped combat values are explicitly pending")
	for extent: Vector2i in [Vector2i(1280,720), Vector2i(854,480)]:
		root.size = extent; DisplayServer.window_set_size(extent); await frames(8)
		hud._set_catalog_detail_view(true); await frames(4)
		var scroll: ScrollContainer = hud.relic_reference_view.right_scroll
		scroll.ensure_control_visible(panel.import_button); await frames(4)
		var canvas_rect: Rect2 = panel.import_button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, panel.import_button.size)
		var clip_rect: Rect2 = scroll.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, scroll.size)
		var physical_rect: Rect2 = root.get_final_transform() * canvas_rect
		check(panel.is_visible_in_tree() and clip_rect.grow(1).encloses(canvas_rect) and Rect2(Vector2.ZERO, Vector2(extent)).grow(1).encloses(physical_rect), "source controls fit the scroll and physical window " + str(extent))
		if not captures.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(captures)
			check(root.get_texture().get_image().save_png(captures.path_join("relic-level-" + str(extent.x) + ".png")) == OK, "actual OpenGL capture " + str(extent))
	hud.catalog_clear_button.pressed.emit(); await frames(6)
	var clear_modal: Control = hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	if clear_modal != null: clear_modal.confirm_button.pressed.emit(); await frames(4)
	check(world.equipped_catalog["성물"].is_empty() and world.source_relic_spell_level(1, 0).bonus == 0, "existing release flow removes modifier")
	check(not panel.snapshot.active and hud.relic_reference_view.status.text.contains("없음"), "release updates both result labels without manual refresh")
	check(world.inventory == inventory and world.gold == gold and world.card_draw_fusion.export_state() == cards, "passive actions spend no inventory gold or awakening materials")
	check(FileAccess.get_sha256(world.save_path()) == save_hash, "UI import summon preview and release do not force unrelated saves")
	hud.open_catalog("변신"); await frames(4)
	check(not panel.is_visible_in_tree(), "relic-only controls hide after navigation")
	print("RELIC_SPELL_LEVEL_MAIN_UI_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "renderer":DisplayServer.get_name()}))
	world.queue_free(); await frames(2); quit(0 if failures.is_empty() else 1)
