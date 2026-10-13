extends SceneTree

# Run unchanged on baseline and feature. This drives production Main, input,
# boss AI and loot UI. It never writes damage, boss HP, loot rolls or HUD text.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const SEED: int = 20261013
const STEP: float = 1.0 / 60.0
const DIRECTION_SECONDS: float = .35
var world: TwilightWorld
var boss: TwilightMonster
var output: String
var elapsed: float = 0.0
var failures: Array[String] = []
var captured: Dictionary = {}
var captures_pending: int = 0
var last_hp: int = 0
var initial_inventory: Dictionary = {}
var boss_died: bool = false
var saw_warning: bool = false
var saw_player_damage: bool = false
var manual_strikes: int = 0
var auto_strikes: int = 0
var phase: String = "setup"
var report: Dictionary = {"events":[], "movement":[], "screenshots":[], "qa_setup":{}, "assertions":{}, "damage_requests":[]}

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	report.assertions[label] = ok
	if not ok:
		failures.append(label)
		print("REMAKE_PLAY_FAIL: " + label)

func event(kind: String, detail: Dictionary = {}) -> void:
	var row: Dictionary = {"event":kind, "seconds":snappedf(elapsed, .001), "phase":phase}
	row.merge(detail)
	report.events.append(row)
	print("REMAKE_PLAY_EVENT " + JSON.stringify(row))

func screenshot(label: String) -> void:
	if captured.has(label) or DisplayServer.get_name() == "headless": return
	captured[label] = true
	captures_pending += 1
	_save_screenshot.call_deferred(label)

func _save_screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = output.path_join(label + ".png")
	var picture: Image = root.get_texture().get_image()
	var saved: bool = picture != null and not picture.is_empty() and picture.save_png(path) == OK
	check(saved, "screenshot " + label)
	if saved: report.screenshots.append({"file":label + ".png", "seconds":snappedf(elapsed, .001)})
	captures_pending -= 1

func step() -> void:
	await physics_frame
	elapsed += STEP
	if world.hp < last_hp:
		saw_player_damage = true
		event("player_damage", {"before":last_hp, "after":world.hp})
		screenshot("03-player-hit")
	last_hp = world.hp
	if is_instance_valid(boss) and not boss.dead and is_instance_valid(boss.species_visual):
		if boss.species_visual.warning_active and boss.species_visual.warning_progress >= .25:
			if not saw_warning:
				saw_warning = true
				event("boss_warning", {"sequence":boss.motion.sequence, "kind":str(boss.ai.special.kind),
					"center":_xy(boss.species_visual.warning_center), "aim":_xy(boss.species_visual.warning_aim),
					"progress":boss.species_visual.warning_progress})
				screenshot("02-boss-telegraph")

func wait_seconds(seconds: float) -> void:
	for tick: int in range(int(ceil(seconds / STEP))): await step()

func press(action: String) -> void:
	Input.action_press(action)
	await step()
	await step()
	Input.action_release(action)

func _xy(point: Vector2) -> Array: return [snappedf(point.x, .01), snappedf(point.y, .01)]

func _landing() -> Vector2:
	# Find a genuine open patch beside the already spawned boss. Each of the
	# eight walking segments must fit existing navigation/collision geometry.
	var stride: float = world.player.move_speed * world.player.equipment_move_speed_multiplier * world.player.skill_speed_multiplier * DIRECTION_SECONDS
	for radius: float in [310.0, 370.0, 250.0, 430.0]:
		for angle: int in range(16):
			var start: Vector2 = boss.global_position + Vector2.from_angle(float(angle) * TAU / 16.0) * radius - Vector2(35, 75)
			if not world.field_map.walkable(start) or not world.field_map.point_clear(start) or world.field_map.is_safe(start): continue
			if not world.field_map.line_clear(start, boss.global_position): continue
			var previous: Vector2 = start
			var valid: bool = true
			for direction: int in range(8):
				var next: Vector2 = previous + Vector2.from_angle(float(direction) * PI / 4.0) * stride
				if not world.field_map.walkable(next) or not world.field_map.point_clear(next) or world.field_map.is_safe(next) or not world.field_map.line_clear(previous, next):
					valid = false
					break
				previous = next
			if valid: return start
	return Vector2.INF

func _on_strike(id: int) -> void:
	if phase == "manual": manual_strikes += 1
	if phase == "auto": auto_strikes += 1
	event("player_strike", {"cycle":id, "boss_hp_before_callback":boss.hp if is_instance_valid(boss) else -1})
	if phase == "manual": screenshot("04-manual-attack")
	if phase == "auto": screenshot("05-auto-combat")

func _on_boss_hit(_actor: TwilightMonster, damage: int, kind: String) -> void:
	report.damage_requests.append({"seconds":snappedf(elapsed, .001), "amount_before_player_defense":damage, "kind":kind, "player_hp_after_resolution":world.hp})

func _on_boss_died(actor: TwilightMonster) -> void:
	boss_died = true
	# Use the same user-facing AUTO control to leave earned floor drops visible.
	world.player.set_auto_enabled(false)
	event("boss_death", {"hp":actor.hp, "max_hp":actor.max_hp, "damage_hit_count":actor.damage_hit_count,
		"ground_count":world.ground_loot.records.size(), "life_id":actor.life_id})
	screenshot("06-boss-death-and-drops")

func _run() -> void:
	output = OS.get_environment("TWILIGHT_CAPTURE_DIR")
	if output.is_empty(): output = "user://remake-play"
	DirAccess.make_dir_recursive_absolute(output)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world), "production class confirmation")
	world.hud._hide_aux_panels()
	world.save_timer = -10000.0
	world.player.set_auto_enabled(false)
	# Isolated capture profile: clear only its prior encounter state and reload
	# the existing map with deterministic spawn RNG. Boss records are unchanged.
	world.field_population.configure(world, null)
	world.field_population.boss_director.states.clear()
	world.rng.seed = SEED
	world._set_map("aden_world", false)
	for slot: Dictionary in world.field_population.slots:
		if str(slot.region.get("mode", "")) == "boss" and is_instance_valid(slot.monster) and slot.monster.monster_name == "드레이크":
			boss = slot.monster
			break
	check(is_instance_valid(boss), "existing Drake boss slot spawned")
	if not is_instance_valid(boss): await finish(); return
	check(boss.max_hp == 520 and boss.attack_power == 42, "unchanged Drake HP and attack")
	var landing: Vector2 = _landing()
	check(landing.is_finite(), "eight-direction route on existing collision map")
	if not landing.is_finite(): await finish(); return
	world.player.global_position = landing
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	# Keep this encounter legible and deterministic while retaining production
	# boss AI, world simulation, HUD, damage, death, drop and pickup services.
	world.field_population.set_process(false)
	var paused_background: int = 0
	for actor: TwilightMonster in world.monsters_root.get_children():
		actor.set_physics_process(actor == boss)
		if actor != boss: paused_background += 1
	world.selected_monster = boss
	world._update_target_hud()
	boss.player_hit.connect(_on_boss_hit)
	boss.died.connect(_on_boss_died)
	world.player.attack_strike.connect(_on_strike)
	last_hp = world.hp
	initial_inventory = world.inventory.duplicate(true)
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.headless_probe = DisplayServer.get_name() == "headless"
	report.qa_setup = {"seed":SEED, "map":"aden_world", "job_class":world.job_class,
		"player_relocated_once":_xy(landing), "boss_existing_spawn":_xy(boss.global_position),
		"boss_home":_xy(boss.home_position), "boss_record_overrides":{}, "player_stat_overrides":{},
		"player_level":world.level, "player_hp":world.hp, "player_max_hp":world._effective_max_hp(),
		"player_attack":world.attack_power, "effective_melee_damage":world._melee_damage_stat(),
		"normal_attack_interval":world._normal_attack_interval(), "attack_speed_multiplier":world._effective_attack_speed_multiplier(),
		"boss_hp":boss.hp, "boss_ac":boss.armor_class, "boss_attack":boss.attack_power,
		"background_actors_paused":paused_background, "population_wake_paused":true,
		"save_scope":"isolated capture XDG profile; automatic saving disabled", "performance_measurement":false}
	event("encounter_ready", report.qa_setup)
	screenshot("00-encounter")
	phase = "movement"
	var actions: Array = [["move_right"], ["move_right", "move_down"], ["move_down"], ["move_left", "move_down"],
		["move_left"], ["move_left", "move_up"], ["move_up"], ["move_right", "move_up"]]
	for direction: int in range(8):
		var before: Vector2 = world.player.global_position
		for action: String in actions[direction]: Input.action_press(action)
		await wait_seconds(DIRECTION_SECONDS)
		for action: String in actions[direction]: Input.action_release(action)
		var moved: Vector2 = world.player.global_position - before
		var desired: Vector2 = Vector2.from_angle(float(direction) * PI / 4.0)
		var aligned: bool = moved.length() > 12.0 and moved.normalized().dot(desired) > .85
		check(aligned, "real movement direction " + str(direction))
		report.movement.append({"direction":direction, "start":_xy(before), "end":_xy(world.player.global_position), "distance":moved.length(), "facing8":world.player.facing8})
		if direction == 3: screenshot("01-eight-direction-movement")
		await wait_seconds(.25)
	phase = "boss_opening"
	while (not saw_warning or not saw_player_damage) and elapsed < 8.0: await step()
	check(saw_warning, "actual boss AI telegraph")
	check(saw_player_damage, "actual player HP damage")
	# Use actual path routing to enter melee range without moving the boss.
	phase = "approach"
	world.player.set_click_path(world.find_world_path(world.player.global_position, boss.global_position), boss.global_position)
	while not world._target_in_current_weapon_range(boss) and elapsed < 12.0: await step()
	world.player.clear_click_path()
	check(world._target_in_current_weapon_range(boss), "real path reached melee range")
	phase = "manual"
	for attempt: int in range(3):
		if boss_died: break
		await press("attack")
		await wait_seconds(maxf(1.60, world._normal_attack_interval() + .10))
	check(manual_strikes >= 2, "manual attack commands released cycles")
	phase = "auto"
	await press("toggle_auto")
	while not boss_died and elapsed < 27.0: await step()
	check(boss_died, "actual combat killed boss")
	check(auto_strikes >= 1, "AUTO released attack cycles")
	world.player.set_auto_enabled(false)
	world.player.clear_click_path()
	phase = "floor_loot"
	var earned: Array = world.ground_loot.snapshot()
	report.floor_drops = earned.duplicate(true)
	check(not earned.is_empty(), "boss earned actual ground loot")
	report.inventory_while_on_ground = {}
	for dropped: Dictionary in earned:
		var name_value: String = str(dropped.item_name)
		report.inventory_while_on_ground[name_value] = int(world.inventory.get(name_value, 0))
		check(int(world.inventory.get(name_value, 0)) <= int(initial_inventory.get(name_value, 0)), "floor drop not instantly granted " + name_value)
	await wait_seconds(2.0)
	screenshot("07-floor-loot-before-pickup")
	if not earned.is_empty():
		var drop: Dictionary = earned[0]
		var item: String = str(drop.item_name)
		var count_before: int = int(world.inventory.get(item, 0))
		phase = "manual_pickup"
		(world.ground_loot.views[str(drop.id)] as Button).pressed.emit()
		await wait_seconds(.8)
		screenshot("08-manual-pickup-selected")
		world.loot_pickup.pickup_button.pressed.emit()
		while world.ground_loot.records.has(str(drop.id)) and elapsed < 32.0: await step()
		var collected: bool = not world.ground_loot.records.has(str(drop.id)) and int(world.inventory.get(item, 0)) == count_before + int(drop.quantity)
		check(collected, "manual UI pickup grants only earned quantity")
		event("manual_pickup", {"item":item, "inventory_before":count_before, "inventory_after":world.inventory.get(item, 0), "quantity":drop.quantity})
		if world.ground_loot.records.size() > 0:
			phase = "auto_pickup"
			var remaining: Array = world.ground_loot.snapshot()
			await press("toggle_auto")
			while world.ground_loot.records.size() > 0 and elapsed < 35.0: await step()
			world.player.set_auto_enabled(false)
			check(world.ground_loot.records.is_empty(), "AUTO collected remaining earned drops")
			event("auto_pickup", {"drops":remaining})
		screenshot("09-pickup-complete")
		await wait_seconds(.35)
	phase = "inventory_result"
	await press("open_inventory")
	await wait_seconds(.4)
	screenshot("10-real-inventory-after-pickup")
	await wait_seconds(maxf(1.5, 20.0 - elapsed))
	await finish()

func finish() -> void:
	for action: String in ["move_right", "move_left", "move_up", "move_down", "attack", "toggle_auto"]: Input.action_release(action)
	if is_instance_valid(world):
		world.player.set_auto_enabled(false)
		world.player.clear_click_path()
	report.simulation_seconds = elapsed
	report.manual_strikes = manual_strikes
	report.auto_strikes = auto_strikes
	report.failures = failures
	while captures_pending > 0: await process_frame
	var file := FileAccess.open(output.path_join("play-evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if is_instance_valid(world): world.queue_free()
	await process_frame
	print("REMAKE_PRODUCTION_PLAY_OK" if failures.is_empty() else "REMAKE_PRODUCTION_PLAY_FAILED")
	quit(0 if failures.is_empty() else 1)
