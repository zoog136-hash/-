extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("TOTEM_MAIN_FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func labels(node: Node) -> String:
	var result := str(node.text)+"\n" if node is Label else ""
	for child in node.get_children(): result += labels(child)
	return result

func run() -> void:
	if OS.get_environment("TWILIGHT_TOTEM_PACK").is_empty():
		print("TOTEM_MAIN SKIP: private pack required")
		quit(0)
		return
	var scene: PackedScene = load("res://Main.tscn")
	check(scene != null,"actual Main")
	if scene == null:
		quit(1)
		return
	var world: TwilightWorld = scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual class confirmation")
	world.player.set_physics_process(false)
	check(world.totems.available(),"Main loads private Totem pack")
	check(world.field_map != null,"current field is live")
	world.hud.toggle_menu()
	var tile: Button = world.hud.workspace.find_child("MenuTile_totems",true,false)
	check(tile != null,"menu tile")
	if tile == null:
		world.queue_free()
		quit(1)
		return
	tile.pressed.emit()
	await process_frame
	check(world.hud.active_section == "totems","menu action opens Totem screen")
	var view: Control = world.hud.totem_view
	check(labels(view).contains("처치 0 / 3000"),"visible activation progress")
	var selector: OptionButton = view.get_child(1)
	selector.select(4)
	selector.item_selected.emit(4)
	check(labels(view).contains("0.00%"),"zero EXP candidate remains visible")
	check(labels(view).contains("후보 비중 50.0%"),"selection weights shown separately")
	check(labels(view).contains("제작 정보"),"craft materials visible")
	for button in view.get_child(0).get_children():
		button.pressed.emit()
		check(not labels(view).is_empty(),"all three Totem tabs")
	view.get_child(0).get_child(0).pressed.emit()
	var inventory_before := world.inventory.duplicate(true)
	var gold_before: int = world.gold
	for child in view.content.get_children():
		if child is Button: check(child.disabled,"unconfirmed upgrade action disabled")
	check(world.inventory == inventory_before and world.gold == gold_before,"browsing consumes no resources")
	world.totems.state["4"] = {"active":false,"kills":2999,"level":0,"selected":{}}
	# Exercise the existing live death adapter with an explicit source-ID probe.
	# This does not assert a native boss spawn or native combat simulation.
	var monster: TwilightMonster = world.monsters_root.get_child(0)
	monster.set_physics_process(false)
	monster.source_m_original = world.totems.row("NpcClass",47524)
	monster.dead = true
	monster.life_id += 1
	world._on_monster_died(monster)
	check(world.totems.progress(4).active and world.totems.progress(4).level == 0,"actual death adapter activates at level zero")
	check(labels(view).contains("활성 · Lv.0 · 처치 3000 / 3000"),"kill updates open screen")
	world._on_monster_died(monster)
	check(world.totems.progress(4).kills == 3000,"duplicate death does not recredit")
	check(world._save_game(true) == OK,"actual save includes Totem progress")
	var saved_path := world.save_path()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saved_path))
	check(saved.totem_state.totems["4"].active and saved.totem_state.totems["4"].level == 0,"disk state splits active and zero level")
	var saved_sha := FileAccess.get_sha256(saved_path)
	world.totems.state = {}
	world._load_game(true)
	check(world.totems.progress(4).active,"actual load restores Totem state")
	check(FileAccess.get_sha256(saved_path) == saved_sha,"load preserves original bytes")
	var live_inventory := world.inventory.duplicate(true)
	var live_totems := world.totems.export_state()
	var bad := saved.duplicate(true)
	bad.totem_state.totems["4"].level = 11
	check(WRITER.write(saved_path,bad) == OK,"isolated malformed-save probe")
	var bad_sha := FileAccess.get_sha256(saved_path)
	world._load_game(true)
	check(world.totems.save_blocked and world.inventory == live_inventory and world.totems.export_state() == live_totems,"invalid Totem load preserves live state")
	check(world._save_game(true) != OK and FileAccess.get_sha256(saved_path) == bad_sha,"invalid save cannot be overwritten")
	check(WRITER.write(saved_path,saved) == OK,"restore isolated save")
	world._load_game(true)
	check(not world.totems.save_blocked,"good reload unblocks saving")
	var legacy := saved.duplicate(true)
	legacy.erase("totem_state")
	check(WRITER.write(saved_path,legacy) == OK,"legacy save probe")
	world._load_game(true)
	check(world.totems.state.is_empty() and not world.totems.save_blocked,"legacy save starts empty")
	world.hud.open_totems()
	await process_frame
	if DisplayServer.get_name() != "headless":
		for size in [Vector2i(1280,720),Vector2i(900,640)]:
			root.size = size
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var output := "user://totem-%dx%d.png" % [size.x,size.y]
			check(root.get_texture().get_image().save_png(output) == OK,"actual OpenGL capture")
			print("TOTEM_CAPTURE ",ProjectSettings.globalize_path(output))
	world.queue_free()
	await process_frame
	print("TOTEM_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
