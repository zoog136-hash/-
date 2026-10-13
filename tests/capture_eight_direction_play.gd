extends SceneTree

## Production Main / input / AI / combat / loot capture, also runnable unchanged
## on main for comparison. No replacement renderer, monster or damage formula.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const ACTIONS = [["move_right"],["move_right","move_down"],["move_down"],["move_left","move_down"],
	["move_left"],["move_left","move_up"],["move_up"],["move_right","move_up"]]
var world: TwilightWorld
var enemy: TwilightMonster
var out: String
var elapsed := 0.0
var failures: Array[String] = []
var report := {"events":[],"movement":[],"player_poses":{},"monster_poses":{},"screenshots":[]}
var player_strikes := 0
var monster_strikes := 0
var killed := false
var initial_hp := 0
var inventory_before: Dictionary

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); print("NATIVE_PLAY_FAIL: " + label)
func event(kind: String, values: Dictionary = {}) -> void:
	var row := {"event":kind,"seconds":snappedf(elapsed,.001)}
	row.merge(values); report.events.append(row)
	print("NATIVE_PLAY_EVENT " + JSON.stringify(row))
func tick() -> void:
	await physics_frame
	elapsed += 1.0/60.0
	var sprite := world.player.transform_sprite if world.player.transform_active else world.player.class_sprite
	report.player_poses[str(sprite.animation)+":"+str(sprite.frame)] = true
	if is_instance_valid(enemy):
		report.monster_poses[enemy.motion.state+":"+str(enemy.motion.facing8)+":"+str(enemy.sprite.texture)] = true
func seconds(value: float) -> void:
	for i: int in range(ceili(value*60.0)): await tick()
func shot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(name_value+".png")
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+name_value)
	report.screenshots.append(name_value+".png")
func press(action: String) -> void:
	Input.action_press(action); await tick(); await tick(); Input.action_release(action)

func landing() -> Vector2:
	var stride := world.player.move_speed * world.player.equipment_move_speed_multiplier * world.player.skill_speed_multiplier * .45
	for radius: float in [300.,400.,500.,220.]:
		for angle: int in range(16):
			var start := enemy.position + Vector2.from_angle(angle*TAU/16.0)*radius
			var current := start
			var valid := world.field_map.point_clear(start) and not world.field_map.is_safe(start) and world.field_map.line_clear(start,enemy.position)
			for direction: int in range(8):
				var next := current + Vector2.from_angle(direction*PI/4.0)*stride
				if not world.field_map.point_clear(next) or world.field_map.is_safe(next) or not world.field_map.line_clear(current,next): valid=false; break
				current=next
			if valid: return start
	return Vector2.INF

func run() -> void:
	out=OS.get_environment("TWILIGHT_CAPTURE_DIR")
	if out.is_empty(): out="user://eight-direction-play"
	DirAccess.make_dir_recursive_absolute(out)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	check(CLASS_QA.enter_game(world),"class selection")
	world.hud._hide_aux_panels()
	world.save_timer=-10000
	world.rng.seed=20261013
	world._set_map("aden_world",false)
	for record: Dictionary in world.catalog_db["변신"]:
		if str(record.get("sourceId",""))=="46": world._equip_catalog("변신",record); break
	check(world.player.motion.profile.profile_id=="transform:46","actual black knight ID")
	for slot: Dictionary in world.field_population.slots:
		if is_instance_valid(slot.monster) and slot.monster.monster_name=="해골 근위병": enemy=slot.monster;break
	check(is_instance_valid(enemy),"existing normal skeleton spawn")
	if not is_instance_valid(enemy): finish(); return
	var start := landing()
	check(start.is_finite(),"existing field has a clear eight-direction route")
	if not start.is_finite(): finish();return
	world.field_population.set_process(false)
	var paused := 0
	for mob: Node in world.monsters_root.get_children(): mob.set_physics_process(false);paused+=1
	world.player.position=start
	world.player.camera.zoom=Vector2(1.8,1.8) # actual game camera, makes foot/weapon inspection readable
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	world.player.set_auto_enabled(false)
	initial_hp=world.hp;inventory_before=world.inventory.duplicate(true)
	world.player.attack_strike.connect(func(id: int) -> void:
		player_strikes+=1;event("player_strike",{"cycle":id,"enemy_hp_before_callback":enemy.hp if is_instance_valid(enemy) else -1}))
	enemy.player_hit.connect(func(_mob: TwilightMonster,_damage: int,_kind: String) -> void: monster_strikes+=1;event("monster_strike"))
	enemy.died.connect(func(_mob: TwilightMonster) -> void: killed=true;world.player.set_auto_enabled(false);event("death",{"floor_drops":world.ground_loot.records.size()}))
	report.setup={"map":"aden_world","transform":"46","monster":"해골 근위병","max_hp":enemy.max_hp,
		"attack":enemy.attack_power,"background_paused":paused-1,"stats_overridden":false,"camera_zoom":1.8,"performance_test":false}
	await seconds(.4);await shot("00-before-movement")
	for direction: int in range(8):
		var before := world.player.position
		for action: String in ACTIONS[direction]: Input.action_press(action)
		await seconds(.45)
		for action: String in ACTIONS[direction]: Input.action_release(action)
		var moved := world.player.position-before
		check(moved.length()>12 and moved.normalized().dot(Vector2.from_angle(direction*PI/4.0))>.85,"movement "+str(direction))
		report.movement.append({"direction":direction,"distance":moved.length(),"facing":world.player.facing8})
		await shot("walk-"+str(direction));await seconds(.22)
	event("eight_directions_done")
	enemy.set_physics_process(true)
	world._select_monster(enemy)
	# Existing AI pursues the player; wait for a genuine incoming attack.
	while monster_strikes==0 and elapsed<18.: await tick()
	check(monster_strikes>0,"monster AI pursuit and attack")
	await shot("09-monster-attack")
	while not killed and elapsed<42.:
		await press("attack")
		await seconds(maxf(.4,world._normal_attack_interval()+.1))
		if player_strikes==2: await shot("10-continuous-combat")
	check(killed,"real weapon attacks killed normal monster")
	check(player_strikes>=2,"consecutive attack cycles")
	check(world.hp<initial_hp,"actual player hit")
	await shot("11-death-floor-drop")
	await seconds(1.1)
	var drops: Array = world.ground_loot.snapshot()
	report.floor_drops=drops
	check(not drops.is_empty(),"normal monster drops on ground")
	if not drops.is_empty():
		var drop: Dictionary=drops[0]
		var item: String=str(drop.item_name)
		var before: int=int(world.inventory.get(item,0))
		check(before<=int(inventory_before.get(item,0)),"loot was not granted immediately")
		(world.ground_loot.views[str(drop.id)] as Button).pressed.emit()
		await seconds(.2)
		world.loot_pickup.pickup_button.pressed.emit()
		while world.ground_loot.records.has(str(drop.id)) and elapsed<48.: await tick()
		check(int(world.inventory.get(item,0))==before+int(drop.quantity),"existing manual pickup")
		await shot("12-pickup")
	# Verify switching away and back through the real equipment path.
	var black: Dictionary=world.equipped_catalog["변신"].duplicate(true)
	var speed := world._normal_attack_interval()
	world._equip_catalog("변신",world.catalog_db["변신"][0]);await seconds(.4)
	world._equip_catalog("변신",black);await seconds(.4)
	check(world.player.motion.profile.profile_id=="transform:46" and is_equal_approx(speed,world._normal_attack_interval()),"transform roundtrip preserves ID and speed")
	await shot("13-transform-restored")
	await finish()

func finish() -> void:
	for actions: Array in ACTIONS:
		for action: String in actions: Input.action_release(action)
	Input.action_release("attack")
	report.failures=failures;report.seconds=elapsed
	report.player_strikes=player_strikes;report.monster_strikes=monster_strikes
	FileAccess.open(out.path_join("play-evidence.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if is_instance_valid(world):world.queue_free()
	await process_frame
	print("NATIVE_PRODUCTION_PLAY_OK" if failures.is_empty() else "NATIVE_PRODUCTION_PLAY_FAILED")
	quit(0 if failures.is_empty() else 1)
