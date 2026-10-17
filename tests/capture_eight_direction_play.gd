extends SceneTree

## Production Main / input / AI / combat / loot capture, also runnable unchanged
## on main for comparison. No replacement renderer, monster or damage formula.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const ACTIONS = [["move_right"],["move_right","move_down"],["move_down"],["move_left","move_down"],
	["move_left"],["move_left","move_up"],["move_up"],["move_right","move_up"]]
const COMPASS = ["E","SE","S","SW","W","NW","N","NE"]
const SOURCE_VIEW = [4,5,6,7,0,1,2,3]

class DirectionGuide extends Node2D:
	var vector := Vector2.ZERO
	var tint := Color(0.3,1.0,1.0)
	var caption := Label.new()
	func _ready() -> void:
		z_index=100
		caption.position=Vector2(-72,12)
		caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size",11)
		caption.add_theme_color_override("font_color",tint)
		caption.add_theme_color_override("font_outline_color",Color.BLACK)
		caption.add_theme_constant_override("outline_size",3)
		add_child(caption)
	func _draw() -> void:
		if vector.length_squared()<.001: return
		var tip := vector.normalized()*40.0
		draw_line(Vector2.ZERO,tip,tint,1.5)
		draw_line(tip,tip-vector.normalized().rotated(.5)*10.0,tint,1.5)
		draw_line(tip,tip-vector.normalized().rotated(-.5)*10.0,tint,1.5)

var world: TwilightWorld
var enemy: TwilightMonster
var player_guide: DirectionGuide
var enemy_guide: DirectionGuide
var previous_enemy_position := Vector2.ZERO
var out: String
var elapsed := 0.0
var failures: Array[String] = []
var report := {"events":[],"movement":[],"player_poses":{},"monster_poses":{},"screenshots":[]}
var player_strikes := 0
var monster_strikes := 0
var killed := false
var initial_hp := 0
var lowest_hp := 0
var inventory_before: Dictionary
var transform_id := "46"
var monster_name := "해골 근위병"
var job := "기사"
var weapon := ""
var use_magic := false

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
	lowest_hp=mini(lowest_hp,world.hp)
	var sprite := world.player.transform_sprite if world.player.transform_active else world.player.class_sprite
	report.player_poses[str(sprite.animation)+":"+str(sprite.frame)] = true
	if player_guide != null:
		player_guide.vector=world.player.get_position_delta()
		player_guide.caption.text="%s | %s | src %d" % [COMPASS[world.player.facing8],sprite.animation,SOURCE_VIEW[world.player.facing8]]
		player_guide.queue_redraw()
	if is_instance_valid(enemy):
		report.monster_poses[enemy.motion.state+":"+str(enemy.motion.facing8)+":"+str(enemy.sprite.texture)] = true
		if enemy_guide != null:
			enemy_guide.vector=enemy.position-previous_enemy_position
			enemy_guide.caption.text="%s | %s | src %d" % [COMPASS[enemy.motion.facing8],enemy.motion.state,SOURCE_VIEW[enemy.motion.facing8]]
			enemy_guide.queue_redraw()
		previous_enemy_position=enemy.position
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
	for radius: float in [180.,240.,320.,400.]:
		for angle: int in range(16):
			var start := enemy.position + Vector2.from_angle(angle*TAU/16.0)*radius
			var current := start
			var valid := world.field_map.walkable(start) and world.field_map.point_clear(start) and not world.field_map.is_safe(start) and world.field_map.line_clear(start,enemy.position)
			for direction: int in range(8):
				var next := current + Vector2.from_angle(direction*PI/4.0)*stride
				if not world.field_map.point_clear(next) or world.field_map.is_safe(next) or not world.field_map.line_clear(current,next): valid=false; break
				# Test eight spokes, returning through actual movement each time.
				# A cumulative octagon unnecessarily requires a much larger clearing.
			if valid: return start
	return Vector2.INF

func run() -> void:
	if not OS.get_environment("TWILIGHT_CAPTURE_TRANSFORM").is_empty(): transform_id=OS.get_environment("TWILIGHT_CAPTURE_TRANSFORM")
	if not OS.get_environment("TWILIGHT_CAPTURE_MONSTER").is_empty(): monster_name=OS.get_environment("TWILIGHT_CAPTURE_MONSTER")
	if not OS.get_environment("TWILIGHT_CAPTURE_JOB").is_empty(): job=OS.get_environment("TWILIGHT_CAPTURE_JOB")
	weapon=OS.get_environment("TWILIGHT_CAPTURE_WEAPON")
	use_magic=OS.get_environment("TWILIGHT_CAPTURE_USE_MAGIC")=="1"
	out=OS.get_environment("TWILIGHT_CAPTURE_DIR")
	if out.is_empty(): out="user://eight-direction-play"
	DirAccess.make_dir_recursive_absolute(out)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	check(CLASS_QA.enter_game(world,job),"actual UI class selection")
	if not weapon.is_empty():
		var record: Dictionary=world._find_catalog_item_record(weapon)
		check(not record.is_empty(),"QA weapon is an existing DB item")
		if not record.is_empty(): world._equip_or_acquire_item(record,true)
	world.hud._hide_aux_panels()
	world.save_timer=-10000
	world.rng.seed=20261013
	world._set_map("aden_world",false)
	for record: Dictionary in world.catalog_db["변신"]:
		if str(record.get("sourceId",""))==transform_id: world._equip_catalog("변신",record); break
	check(world.player.motion.profile.profile_id=="transform:"+transform_id,"actual selected transformation ID")
	if OS.get_environment("TWILIGHT_CAPTURE_PREFLIGHT")=="1":
		report.preflight_only=true
		report.setup={"job":world.job_class,"weapon_type":world._current_weapon_type(),"transform":world.player.motion.profile.profile_id}
		check(weapon.is_empty() or not world._equipped_weapon_record().is_empty(),"real weapon equipped through existing item handler")
		await finish();return
	var start := Vector2.INF
	for slot: Dictionary in world.field_population.slots:
		if is_instance_valid(slot.monster) and slot.monster.monster_name==monster_name:
			enemy=slot.monster
			start=landing()
			if start.is_finite(): break
	check(is_instance_valid(enemy),"selected monster exists in the actual map population")
	if not is_instance_valid(enemy): finish(); return
	event("route_setup",{"enemy_position":str(enemy.position),"stride":world.player.move_speed*world.player.equipment_move_speed_multiplier*world.player.skill_speed_multiplier*.45,"landing":str(start)})
	check(start.is_finite(),"existing field has a clear eight-direction route")
	if not start.is_finite(): finish();return
	world.field_population.set_process(false)
	var paused := 0
	for mob: Node in world.monsters_root.get_children(): mob.set_physics_process(false);paused+=1
	world.player.position=start
	world.player.camera.zoom=Vector2(1.8,1.8) # actual game camera, makes foot/weapon inspection readable
	world.player.camera.position=Vector2(0,-32)
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	if OS.get_environment("TWILIGHT_DIRECTION_GUIDE")=="1":
		player_guide=DirectionGuide.new();world.player.add_child(player_guide)
		enemy_guide=DirectionGuide.new();enemy_guide.tint=Color(1.0,.85,.3);enemy.add_child(enemy_guide)
		previous_enemy_position=enemy.position
		report.direction_guides="QA only: arrows show actual position changes; captions identify selected runtime track and reviewed source index"
	world.player.set_auto_enabled(false)
	initial_hp=world.hp;lowest_hp=initial_hp;inventory_before=world.inventory.duplicate(true)
	world.player.attack_strike.connect(func(id: int) -> void:
		player_strikes+=1;event("player_strike",{"cycle":id,"enemy_hp_before_callback":enemy.hp if is_instance_valid(enemy) else -1}))
	enemy.player_hit.connect(func(_mob: TwilightMonster,_damage: int,_kind: String) -> void: monster_strikes+=1;event("monster_strike"))
	enemy.died.connect(func(_mob: TwilightMonster) -> void: killed=true;world.player.set_auto_enabled(false);event("death",{"floor_drops":world.ground_loot.records.size()}))
	report.setup={"map":"aden_world","transform":transform_id,"monster":monster_name,"max_hp":enemy.max_hp,
		"attack":enemy.attack_power,"background_paused":paused-1,"stats_overridden":false,"camera_zoom":1.8,"performance_test":false}
	report.setup.job=job;report.setup.qa_db_weapon=weapon;report.setup.existing_magic_action=use_magic
	await seconds(.4);await shot("00-before-movement")
	for direction: int in range(8):
		var before := world.player.position
		for action: String in ACTIONS[direction]: Input.action_press(action)
		await seconds(.25)
		if player_guide != null: await shot("moving-"+str(direction))
		await seconds(.20)
		for action: String in ACTIONS[direction]: Input.action_release(action)
		var moved := world.player.position-before
		check(moved.length()>12 and moved.normalized().dot(Vector2.from_angle(direction*PI/4.0))>.85,"movement "+str(direction))
		report.movement.append({"direction":direction,"compass":COMPASS[direction],"distance":moved.length(),"facing":world.player.facing8,"source_view":SOURCE_VIEW[world.player.facing8]})
		await shot("walk-"+str(direction));await seconds(.22)
		for action: String in ACTIONS[(direction+4)%8]: Input.action_press(action)
		await seconds(.45)
		for action: String in ACTIONS[(direction+4)%8]: Input.action_release(action)
		await seconds(.12)
	event("eight_directions_done")
	enemy.set_physics_process(true)
	world._select_monster(enemy)
	# Existing AI pursues the player; wait for a genuine incoming attack.
	while monster_strikes==0 and elapsed<18.: await tick()
	check(monster_strikes>0,"monster AI pursuit and attack")
	await shot("09-monster-attack")
	# A ranged boss stops farther away than a melee monster. Approach through
	# real movement input rather than assuming its attack range matches ours.
	while not world._target_in_current_weapon_range(enemy) and elapsed<24.:
		var direction: int=posmod(roundi((enemy.position-world.player.position).angle()/(PI/4.0)),8)
		for action: String in ACTIONS[direction]: Input.action_press(action)
		await tick()
		for action: String in ACTIONS[direction]: Input.action_release(action)
	event("weapon_range_reached",{"cells":world._weapon_cell_distance(enemy),"allowed_cells":world._current_attack_range_cells()})
	while not killed and elapsed<42.:
		if use_magic:
			world.hud.combat_skill_pressed.emit("magic")
		else:
			await press("attack")
		await seconds(maxf(.4,world._normal_attack_interval()+.1))
		if player_strikes==2: await shot("10-continuous-combat")
	check(killed,"real weapon attacks killed selected DB monster")
	check(player_strikes>=2,"consecutive attack cycles")
	check(lowest_hp<initial_hp,"actual player hit before existing recovery or potion healing")
	await shot("11-death-floor-drop")
	await seconds(1.1)
	var drops: Array = world.ground_loot.snapshot()
	report.floor_drops=drops
	check(not drops.is_empty(),"selected DB monster drops on ground")
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
	check(world.player.motion.profile.profile_id=="transform:"+transform_id and is_equal_approx(speed,world._normal_attack_interval()),"transform roundtrip preserves ID and speed")
	await shot("13-transform-restored")
	await finish()

func finish() -> void:
	for actions: Array in ACTIONS:
		for action: String in actions: Input.action_release(action)
	Input.action_release("attack")
	report.failures=failures;report.seconds=elapsed
	report.player_strikes=player_strikes;report.monster_strikes=monster_strikes
	report.initial_hp=initial_hp;report.lowest_hp=lowest_hp
	FileAccess.open(out.path_join("play-evidence.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if is_instance_valid(world):world.queue_free()
	await process_frame
	print("NATIVE_PRODUCTION_PLAY_OK" if failures.is_empty() else "NATIVE_PRODUCTION_PLAY_FAILED")
	quit(0 if failures.is_empty() else 1)
