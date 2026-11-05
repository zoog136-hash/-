extends SceneTree
## Actual host gameplay only; no native M placement or trigger claim.
const NAV = preload("res://scripts/maps/host_portal_navigation.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("HOST_PORTAL_GAMEPLAY_FAIL: ", label)

func _initialize() -> void: call_deferred("run")

func click(control: Control) -> void:
	var at: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.position = at; event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func capture(name: String) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--patch523-capture-dir="): continue
		var output: String = arg.trim_prefix("--patch523-capture-dir=")
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(output)
		check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "rendered " + name)

func run() -> void:
	root.size = Vector2i(1280,720)
	var scene = load("res://Main.tscn") as PackedScene
	check(scene != null, "actual Main loads")
	if scene == null: quit(1); return
	var world: TwilightWorld = scene.instantiate()
	root.add_child(world)
	world.set_process(false); world.save_timer = -100000.0
	check(QA.enter_game(world), "actual class confirmation and map startup")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.original_population.set_process(false)
	world.field_population._drain_initial_spawns()
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	check(world.active_map_id == "aden_world" and world.field_map != null, "actual Aden host field")
	var portal: Dictionary = {}
	for candidate: Dictionary in world.field_map.data.get("portal", []):
		if candidate.id == "aden_hunting_entry": portal = candidate
	check(not portal.is_empty(), "existing authored hunting portal available")
	if portal.is_empty(): world.queue_free(); quit(1); return
	var center: Vector2 = NAV.point(portal.position)
	var approach: PackedVector2Array = world.find_world_path(world.player.global_position, center)
	# Start this bounded walking test at a real route waypoint outside the
	# existing trigger; no production coordinate or encounter is authored here.
	var start: Vector2 = world.player.global_position if world.player.global_position.distance_to(center) > float(portal.radius) + 20.0 else Vector2.INF
	for index: int in range(approach.size()-1, -1, -1):
		if approach[index].distance_to(center) > float(portal.radius) + 20.0:
			start = approach[index]; break
	check(start.is_finite(), "existing walk mesh supplies approach outside trigger")
	if not start.is_finite(): world.queue_free(); quit(1); return
	world.player.global_position = start
	world.player.camera.reset_smoothing()
	world.portal_cooldown = 0.0
	world.player.set_auto_enabled(false)
	check(world._save_game(true) == OK, "isolated baseline save")
	var save_sha: String = FileAccess.get_sha256(world.save_path())
	var boss_state: String = JSON.stringify(world.field_population.export_state())
	var inventory: String = JSON.stringify(world.inventory)
	var gold: int = world.gold
	var receipt: Dictionary = NAV.capture(world, portal)
	check(NAV.inspect(world, receipt).ok, "authored host portal admitted without native pack")
	for _frame: int in range(4): await process_frame
	await click(world.hud.find_child("Shortcut_map", true, false))
	for _frame: int in range(4): await process_frame
	var open_button: Control = world.hud.workspace.find_child("OpenWorldLinks", true, false)
	check(open_button != null, "map links button available")
	if open_button != null: await click(open_button)
	for _frame: int in range(4): await process_frame
	var panel: Control = world.hud.workspace.find_child("WorldLinksPanel", true, false)
	check(panel != null, "actual portal UI opened by mouse")
	if panel == null: world.queue_free(); quit(1); return
	check(not panel.links.loaded and panel.mode.is_item_disabled(1) and panel.mode.is_item_disabled(2), "host feature independent of private M definitions")
	panel.mode.select(3); panel.mode.item_selected.emit(3)
	check(panel.entries.size() == world.field_map.data.portal.size(), "UI lists exact existing host triggers")
	panel.search.text = str(portal.name); panel.search.text_changed.emit(panel.search.text)
	check(panel.rows.item_count == 1 and not panel.navigate.disabled, "authored host portal searchable and actionable")
	await capture("04-host-portal-route")
	await click(panel.navigate)
	check(world.hud.active_section != "map_links" and world.player.manual_navigation and not world.player.click_path.is_empty(), "mouse action queues actual manual walking and closes panel")
	check(world.player.global_position == start, "UI action does not teleport")
	var target: Vector2 = NAV.point(portal.target_position)
	var walked: bool = false
	world.player.set_physics_process(true)
	for _frame: int in range(600):
		await physics_frame
		var distance: float = world.player.global_position.distance_to(start)
		if distance > 1.0 and world.player.global_position.distance_to(target) > 100.0: walked = true
		world._update_field_triggers()
		await process_frame
		if world.player.global_position.distance_to(target) < 1.0: break
	world.player.set_physics_process(false)
	check(walked, "actual player physics moves toward trigger")
	check(world.player.global_position.distance_to(target) < 1.0 and world.portal_cooldown > 0.0, "existing arrival trigger performs authored portal travel")
	check(world.active_map_id == "aden_world", "same-map portal preserves active map")
	check(FileAccess.get_sha256(world.save_path()) == save_sha and JSON.stringify(world.inventory) == inventory and world.gold == gold and JSON.stringify(world.field_population.export_state()) == boss_state, "walking and travel preserve disk save, inventory, gold and boss timers")
	for _frame: int in range(240):
		await process_frame
		if not world.field_renderer.waiting_for_visible: break
	check(not world.field_renderer.waiting_for_visible and world.field_renderer.failure.is_empty(), "destination source artwork finishes streaming")
	await capture("05-host-portal-arrival")
	# Exercise a real existing normal encounter, not a manufactured NPC/pack.
	var slot: Dictionary = {}
	for candidate: Dictionary in world.field_population.slots:
		if str(candidate.region.get("mode", "normal")) != "boss" and is_instance_valid(candidate.monster) and not candidate.monster.dead:
			slot = candidate; break
	check(not slot.is_empty(), "real normal population actor available")
	if not slot.is_empty():
		var actor: TwilightMonster = slot.monster
		var life: int = actor.life_id
		var original_region: String = JSON.stringify(slot.region)
		var old_gold: int = world.gold
		var old_exp: int = world.experience
		print("HOST_LIFECYCLE_CONTEXT ", JSON.stringify({"slot": slot.slot_id, "region": slot.region.id, "actor": actor.monster_name, "position": [actor.position.x,actor.position.y], "respawn": slot.region.get("respawn_time"), "visible_policy": slot.region.get("respawn_on_screen")}))
		actor.take_damage(actor.hp + 1)
		actor.set_physics_process(false)
		check(actor.dead and slot.monster == null and float(slot.remaining) > 0.0, "actual damage and death release slot with existing respawn delay")
		var awarded_gold: int = world.gold
		var awarded_exp: int = world.experience
		check(awarded_gold >= old_gold and awarded_exp > old_exp, "existing death callback awards declared encounter rewards")
		world._on_monster_died(actor)
		check(world.gold == awarded_gold and world.experience == awarded_exp, "same life cannot award death rewards twice")
		# Advance the existing service clock only. Do not change the region,
		# spawn coordinates, count, delay or offscreen respawn policy.
		var pending: Array[Dictionary] = world.field_population.pending_initial_spawns.duplicate()
		var pending_ids: Dictionary = world.field_population.pending_spawn_ids.duplicate()
		world.field_population.pending_initial_spawns.clear()
		world.field_population.pending_spawn_ids.clear()
		world.field_population._process(float(slot.remaining) + 0.5)
		for _attempt: int in range(5):
			world.field_population._drain_initial_spawns()
			if is_instance_valid(slot.monster): break
		world.field_population.pending_initial_spawns = pending
		world.field_population.pending_spawn_ids = pending_ids
		check(is_instance_valid(slot.monster) and not slot.monster.dead and (slot.monster != actor or slot.monster.life_id != life), "existing population respawns a new live encounter after its own delay")
		check(JSON.stringify(slot.region) == original_region, "encounter placement, count and respawn rules unchanged")
		check(FileAccess.get_sha256(world.save_path()) == save_sha, "isolated cycle does not rewrite existing save")
	print("HOST_PORTAL_GAMEPLAY_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
