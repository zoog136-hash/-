extends SceneTree
## Real Main/physics checks for the explicit local navigation profile, not M rules.
const QA = preload("res://tests/qa_class_selection.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const PLAY_RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const EXPECTED = "user://current523-play-qa-expected.json"
var checks: int = 0
var failures: Array[String] = []
var captures: Array[String] = []
var world: Node
var movement: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("ADEN_PLAY_FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func frames() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func capture(tag: String) -> void:
	var directory: String = OS.get_environment("ADEN523_CAPTURE_DIR")
	if directory.is_empty(): return
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), "actual Main play viewport rendered")
	if image == null or image.is_empty(): return
	var path: String = directory.path_join(tag + ".png")
	check(image.save_png(path) == OK, "actual Main play capture written")
	captures.append(path)

func protected_state() -> Dictionary:
	var out: Dictionary = {}
	for key: String in ["gold", "inventory", "item_instances", "equipped_items", "equipped_catalog", "enhancement_levels"]:
		out[key] = world.get(key)
	out["equipment_collections"] = world.equipment_collections.export_state()
	return JSON.parse_string(JSON.stringify(out))

func walk_to(point: Vector2) -> bool:
	var path: PackedVector2Array = world.find_world_path(world.player.global_position, point)
	if path.is_empty(): return false
	world.player.set_manual_click_path(path, point)
	world.player.set_physics_process(true)
	var deadline: int = Time.get_ticks_msec() + 6000
	while world.player.global_position.distance_to(point) > 7.0 and Time.get_ticks_msec() < deadline:
		await physics_frame
	world.player.set_physics_process(false)
	world.player.clear_click_path()
	world.player.velocity = Vector2.ZERO
	return world.player.global_position.distance_to(point) <= 7.0

func clear_destination() -> Vector2:
	var start: Vector2 = world.player.global_position
	for offset: Vector2 in [Vector2(96, -48), Vector2(-96, 48), Vector2(96, 48), Vector2(-96, -48), Vector2(144, 0), Vector2(-144, 0)]:
		var point: Vector2 = start + offset
		if not world.field_map.point_clear(point, 4.0) or not world.field_map.line_clear(start, point): continue
		var occupied: bool = false
		for npc: Dictionary in world.field_map.data.npc_spawn:
			if point.distance_to(Vector2(npc.position[0], npc.position[1])) < 65: occupied = true
		if not occupied and world.field_renderer.support_world_point(point): return point
	return Vector2.INF

func wall_pair() -> Dictionary:
	var field = world.field_map
	var cell: Vector2i = field.world_to_cell(world.player.global_position)
	for radius: int in range(1, 17):
		for y: int in range(-radius, radius + 1):
			for x: int in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius: continue
				var at: Vector2i = cell + Vector2i(x, y)
				var point: Vector2 = field.cell_to_world(at)
				if not field.point_clear(point, 4.0) or not field.line_clear(world.player.global_position, point) or not world.field_renderer.support_world_point(point): continue
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
					var blocked: Vector2i = at + offset
					if field.in_bounds(blocked) and not field.walkable(field.cell_to_world(blocked)):
						return {"clear":point, "blocked":field.cell_to_world(blocked), "blocked_cell":blocked}
	return {}

func run() -> void:
	var phase: String = "entry"
	var raw_root: String = ""
	var tile_root: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
		if argument.begins_with("--aden523-pack="): raw_root = argument.trim_prefix("--aden523-pack=")
		if argument.begins_with("--aden523-tiles="): tile_root = argument.trim_prefix("--aden523-tiles=")
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "ordinary Main class selection completes")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	if phase == "reconnect":
		await reconnect()
		return
	if phase == "fallback":
		await fallback()
		return
	check(not OPTIONS.read().enabled and not world.current523_aden_play_active, "local navigation starts opt-in and off")
	world.gold = 523041
	check(world._save_game(true) == OK, "baseline uses the real game save writer")
	var state: Dictionary = protected_state()
	var save_path: String = world.save_path()
	var save_sha: String = FileAccess.get_sha256(save_path)
	var field = world.field_map
	var physics = world.field_physics
	var renderer = world.field_renderer
	var position: Vector2 = world.player.global_position
	var raw_sha: String = FileAccess.get_sha256(raw_root.path_join("originals/Map/Aden/800a8000.s32"))
	check(not world.open_current523_aden_play(raw_root, tile_root, {"navigation_profile":"M_RAW_U16_IS_PC_MASK"}), "unknown/native-looking passability profile rejects")
	world.hud.call("open_settings_info",true)
	await frames()
	var panel = world.hud.workspace.find_child("Current523AdenReviewSettings", true, false)
	check(panel != null and panel.play_button.disabled, "existing Settings requires explicit local navigation selection")
	if panel == null: await finish(phase); return
	panel.play_profile.select(1)
	panel.play_profile.item_selected.emit(1)
	panel.raw_path_edit.text = "/nonexistent/aden-play-originals"
	panel.tile_path_edit.text = tile_root
	panel.raw_path_edit.text_changed.emit(panel.raw_path_edit.text)
	panel.tile_path_edit.text_changed.emit(tile_root)
	panel.play_button.pressed.emit()
	check(not world.current523_aden_play_active and world.field_renderer == renderer and FileAccess.get_sha256(save_path) == save_sha, "bad source entry preserves live renderer and actual save bytes")
	check(not panel.play_status.text.is_empty(), "play entry failure is visible in Settings")
	panel.raw_path_edit.text = raw_root
	panel.raw_path_edit.text_changed.emit(raw_root)
	var scroller := panel.get_parent().get_parent() as ScrollContainer
	if scroller != null: scroller.ensure_control_visible(panel.play_button)
	await frames()
	capture("play-local-profile-settings")
	panel.play_button.pressed.emit()
	await frames()
	check(world.current523_aden_play_active, "Settings starts actual local-navigation M display")
	if not world.current523_aden_play_active:
		printerr("ADEN_PLAY_ENTRY_PROBLEM ", world.current523_aden_play_problem)
		await finish(phase)
		return
	check(world.field_map == field and world.field_physics == physics and world.field_renderer.get_script() == PLAY_RENDERER, "field/physics stay identical while renderer changes")
	check(not renderer.visible and renderer.process_mode == Node.PROCESS_MODE_DISABLED and world.process_mode != Node.PROCESS_MODE_DISABLED, "prior renderer is retained and game simulation is available")
	check(world.player.global_position == position and protected_state() == state and FileAccess.get_sha256(save_path) == save_sha, "mode entry preserves actor, progression and save bytes")
	check(not world.hud.workspace.visible and world.find_child("ReturnFromAdenPlayButton", true, false) != null, "live play has a visible safe-return control")
	var metrics: Dictionary = world.current523_aden_play_metrics()
	check(metrics.get("draw_commands", 0) > 0 and not metrics.get("M_attributes_used", true) and not metrics.get("native_M_rules_verified", true), "real M tiles draw with explicit non-native navigation provenance")
	check(metrics.get("unresolved_refs", -1) == 0 and metrics.get("budget_skips", -1) == 0, "tested live view has no unresolved or excluded commands")
	capture("play-entry")
	world.hud.workspace.show()
	panel.play_offset_y.value = 12
	panel.play_apply_button.pressed.emit()
	check(OPTIONS.read().offset_y == 12 and world.player.global_position == position, "visual correction is configurable without moving the actor")
	panel.play_offset_y.value = 0
	panel.play_apply_button.pressed.emit()
	world.hud.workspace.hide()
	var destination: Vector2 = clear_destination()
	check(destination.is_finite(), "a source-API-clear nearby route exists")
	var walked: bool = await walk_to(destination) if destination.is_finite() else false
	check(walked and world.player.global_position.distance_to(position) > 24, "actual player physics traverses the local navigation route")
	movement["start"] = [position.x, position.y]
	movement["after_walk"] = [world.player.global_position.x, world.player.global_position.y]
	var wall: Dictionary = wall_pair()
	check(not wall.is_empty(), "nearby source-blocked tile is selected through existing APIs")
	if not wall.is_empty():
		check(await walk_to(wall.clear), "actor reaches the actual approach to a blocked tile")
		world.player.touch_vector = world.player.global_position.direction_to(wall.blocked)
		world.player.set_physics_process(true)
		var entered: bool = false
		for _tick: int in range(24):
			await physics_frame
			if field.world_to_cell(world.player.global_position) == wall.blocked_cell: entered = true
		world.player.set_physics_process(false)
		world.player.touch_vector = Vector2.ZERO
		world.player.velocity = Vector2.ZERO
		check(not entered and field.world_to_cell(world.player.global_position) != wall.blocked_cell, "actual motion refuses the configured blocked tile")
		movement["blocked_cell"] = [wall.blocked_cell.x, wall.blocked_cell.y]
	var before_boundary: Vector2 = world.player.global_position
	var outside: Vector2 = field.cell_to_world(Vector2i(-3, field.world_to_cell(before_boundary).y))
	check(not field.walkable(outside) and world.find_world_path(before_boundary, outside).is_empty(), "existing navigation rejects an out-of-bounds destination")
	world._set_click_destination(outside)
	world.player.set_physics_process(true)
	for _tick: int in range(8): await physics_frame
	world.player.set_physics_process(false)
	check(world.player.global_position.distance_to(before_boundary) < 0.1, "actual out-of-bounds click leaves the actor in the safe field")
	await frames()
	capture("play-after-motion")
	var live_position: Vector2 = world.player.global_position
	var back: Button = world.find_child("ReturnFromAdenPlayButton", true, false) as Button
	back.pressed.emit()
	await frames()
	check(not world.current523_aden_play_active and world.field_renderer == renderer and renderer.visible, "live return control restores exact prior renderer")
	check(world.field_map == field and world.field_physics == physics and world.player.global_position == live_position, "return preserves field, collision object and moved actor position")
	check(not OPTIONS.read().enabled, "explicit return disables automatic experimental restoration")
	check(world._save_game(true) == OK and protected_state() == state, "saving after return preserves inventory, currency and collection state")
	check(world.open_current523_aden_play(raw_root, tile_root, OPTIONS.read()), "verified local mode can be re-entered for reconnect testing")
	check(world._save_game(true) == OK and OPTIONS.read().enabled, "normal save works in experimental play without a new save schema")
	var expected: Dictionary = {"save_path":world.save_path(), "save_sha256":FileAccess.get_sha256(world.save_path()), "position":[world.player.global_position.x, world.player.global_position.y], "state":state, "raw_sha256":raw_sha, "raw_root":raw_root}
	var saved := FileAccess.open(EXPECTED, FileAccess.WRITE)
	saved.store_string(JSON.stringify(expected))
	saved.close()
	check(FileAccess.get_sha256(raw_root.path_join("originals/Map/Aden/800a8000.s32")) == raw_sha, "M source bytes survive play, corrections, movement and save")
	await finish(phase)

func reconnect() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	check(not expected.is_empty(), "previous actual process left reconnect evidence")
	var deadline: int = Time.get_ticks_msec() + 20000
	while not world.current523_aden_play_active and Time.get_ticks_msec() < deadline: await process_frame
	check(world.current523_aden_play_active and world.field_renderer.get_script() == PLAY_RENDERER, "new Main process restores the explicit local mode")
	check(world.active_map_id == "aden_world" and world.player.global_position.distance_to(Vector2(expected.position[0], expected.position[1])) < 0.5, "normal save reconnect restores actual moved position")
	check(protected_state() == expected.state and FileAccess.get_sha256(expected.save_path) == expected.save_sha256, "reconnect preserves progression and does not rewrite save bytes")
	check(FileAccess.get_sha256(str(expected.raw_root).path_join("originals/Map/Aden/800a8000.s32")) == expected.raw_sha256, "reconnect preserves original M file digest")
	await frames()
	capture("play-reconnect")
	world.close_current523_aden_play()
	check(not world.current523_aden_play_active and not OPTIONS.read().enabled, "reconnected session can safely return and disable the mode")
	await finish("reconnect")

func fallback() -> void:
	var options: Dictionary = OPTIONS.read()
	var renderer = world.field_renderer
	var field = world.field_map
	var position: Vector2 = world.player.global_position
	var protected: Dictionary = protected_state()
	var save_sha: String = FileAccess.get_sha256(world.save_path())
	check(world.open_current523_aden_play(options.raw_root, options.tile_root, options), "safe-return scenario enters the explicit local profile")
	if not world.current523_aden_play_active: await finish("fallback"); return
	var preferences_sha: String = FileAccess.get_sha256(OPTIONS.PATH)
	var zoom: Vector2 = world.player.camera.zoom
	world.player.camera.zoom = Vector2(0.05, 0.05)
	world.player.camera.force_update_scroll()
	var applied: bool = world.apply_current523_aden_play_options({"offset_y":12})
	check(not applied and not world.current523_aden_play_problem.is_empty(), "failed correction reports failure rather than committing a successful setting")
	check(FileAccess.get_sha256(OPTIONS.PATH) == preferences_sha, "unsupported correction preserves all prior preference bytes")
	# Restore the user's camera before reactivating the retained legacy renderer.
	world.player.camera.zoom = zoom
	world.player.camera.force_update_scroll()
	await frames()
	check(not world.current523_aden_play_active and world.field_renderer == renderer and renderer.visible, "unsupported display budget automatically returns to the retained renderer")
	check(not world.current523_aden_play_problem.is_empty(), "automatic return supplies a visible failure reason")
	check(world.field_map == field and world.player.global_position == position and protected_state() == protected, "automatic failure does not replace navigation or progression")
	check(FileAccess.get_sha256(world.save_path()) == save_sha, "safe display failure leaves actual save bytes unchanged")
	world.close_current523_aden_play()
	check(not OPTIONS.read().enabled, "user can disable restoration after automatic fallback")
	capture("play-safe-return")
	await finish("fallback")

func finish(phase: String) -> void:
	print("CURRENT523_ADEN_PLAY_MAIN_RESULT " + JSON.stringify({"phase":phase,"checks":checks,"failures":failures,"captures":captures,"movement":movement,"profile":"TWILIGHT_LOCAL_NAVIGATION_WITH_M_DISPLAY","native_M_rules_verified":false}))
	if is_instance_valid(world): world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
