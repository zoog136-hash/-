extends SceneTree

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
## Regression exercise inside the production Main scene. QA changes positions,
## pauses unrelated spawn slots, and equips existing DB records; combat stats,
## actor scenes, AI, map, damage, flight, death, and pickup code are unchanged.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const LOOT_ROLL = preload("res://scripts/loot_drop.gd")
const ACTIONS = [["move_right"],["move_right","move_down"],["move_down"],["move_left","move_down"],
	["move_left"],["move_left","move_up"],["move_up"],["move_right","move_up"]]
# Independent screen-coordinate expectations, not derived from motion.face().
const VECTORS = [Vector2(1,0),Vector2(1,1),Vector2(0,1),Vector2(-1,1),
	Vector2(-1,0),Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1)]
const COMPASS = ["E","SE","S","SW","W","NW","N","NE"]
const WEAPONS = [{"job":"기사","appearance":0,"transform_id":"131","name":"훈련용 한손검","type":"한손검","style":"slash","magic":false},
	{"job":"요정","appearance":2,"transform_id":"135","name":"훈련용 활","type":"활","style":"bow","magic":false},
	{"job":"마법사","appearance":1,"transform_id":"137","name":"훈련용 지팡이","type":"지팡이","style":"magic","magic":true}]

var world: TwilightWorld
var center := Vector2.INF
var normal: TwilightMonster
var failures: Array[String] = []
var checks := 0
var ticks_elapsed := 0
var strikes: Array[Dictionary] = []
var monster_strikes: Array[Dictionary] = []
var flight_observations: Dictionary = {}
var report := {"player":[],"staff_normal":[],"monster":[],"boss":[],"lifecycle":{},"screenshots":[]}
var out: String
var captures: String
var quit_on_finish: bool = true

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("PR100_GAMEPLAY_FAIL: " + label)

func tick(count: int = 1) -> void:
	for _i: int in range(count):
		await physics_frame
		ticks_elapsed += 1

func active_sprite() -> AnimatedSprite2D:
	return world.player.transform_sprite if world.player.transform_active else world.player.class_sprite

func upright(sprite: Node2D) -> bool:
	return sprite.scale.x > 0.0 and sprite.scale.y > 0.0 and is_zero_approx(sprite.rotation) and not sprite.flip_h and not sprite.flip_v

func release_inputs() -> void:
	for actions: Array in ACTIONS:
		for action: String in actions: Input.action_release(action)
	Input.action_release("attack")

func screen_direction(direction: int) -> Vector2:
	return (VECTORS[direction] as Vector2).normalized()

func attack_track(key: String, direction: int) -> bool:
	return key.ends_with("_"+str(direction)) and (key.begins_with("attack") or key.begins_with("cast") or key.begins_with("ranged_attack") or key.begins_with("special"))

func route_clear(point: Vector2, radius: float) -> bool:
	# Fail closed if the source pack was unavailable on this platform.
	# Do not dereference a null field thousands of times on Windows.
	if world.field_map == null: return false
	if not world.field_map.walkable(point) or not world.field_map.point_clear(point) or world.field_map.is_safe(point): return false
	for direction: int in range(8):
		var spoke: Vector2 = point + screen_direction(direction) * radius
		if not world.field_map.walkable(spoke) or not world.field_map.point_clear(spoke) or world.field_map.is_safe(spoke) or not world.field_map.line_clear(point,spoke): return false
	return true

func find_clearing() -> Vector2:
	if world.field_map == null:
		var pack_index: String = "res://data/map_remake/private/aden/index.json"
		var definition_path: String = "res://data/map_remake/private/aden/definitions/aden_world.json"
		var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack_index)) as Dictionary if FileAccess.file_exists(pack_index) else {}
		var entry: Dictionary = pack.get("maps", {}).get("aden_world", {})
		check(false, "production Aden field missing; index_exists=" + str(FileAccess.file_exists(pack_index)) +
			" definition_exists=" + str(FileAccess.file_exists(definition_path)) +
			" definition_sha_matches=" + str(FileAccess.file_exists(definition_path) and FileAccess.get_sha256(definition_path) == str(entry.get("sha256", ""))))
		return Vector2.INF
	# Populate staged native-PNG monster slots through the same bounded production
	# drain as runtime, before freezing AI for reproducible directional QA.
	# Otherwise there is no skeleton to relocate and inherited tests crash on Nil.
	# Source84 local-habitat regions (current Aden) are staged the same way.
	if not world.field_population.pending_initial_spawns.is_empty():
		while not world.field_population.pending_initial_spawns.is_empty():
			world.field_population._drain_initial_spawns()
		for spawned: Node in world.monsters_root.get_children():
			spawned.set_physics_process(false)
	# Prefer a live skeleton for the base game regression. On source-pack
	# mainland and isolated Windows fixtures its spawn may not be near an
	# unobstructed arena. Search other real actor/source cells with identical
	# collision, safe-zone and eight-way LOS requirements.
	var anchors: Array[Vector2] = []
	var existing_skeleton: TwilightMonster = null
	for slot: Dictionary in world.field_population.slots:
		var actor: Variant = slot.get("monster")
		if not is_instance_valid(actor) or actor.dead or actor.monster_name != "해골 근위병": continue
		if existing_skeleton == null: existing_skeleton = actor as TwilightMonster
		if anchors.size() < 20: anchors.append(actor.global_position)
	normal = existing_skeleton
	if world.field_map is NativePngField:
		# Active PNG spawn cells are the bounded reviewed floor candidates.
		# Retain the same 150px, eight-direction, non-safe combat clearance;
		# additionally sweep the 4px foot over the <=44.1px input stage.
		var offsets: Array = []
		for direction: int in range(8): offsets.append(screen_direction(direction) * 150.)
		var point: Vector2 = preload("res://tests/active_source_test_positions.gd").combat(world,offsets,50.0)
		return point if point.is_finite() and route_clear(point,150.) else Vector2.INF
	for slot: Dictionary in world.field_population.slots:
		var actor: Variant = slot.get("monster")
		if not is_instance_valid(actor) or actor.dead: continue
		if anchors.size() >= 68: break
		anchors.append(actor.global_position)
	anchors.append(world.player.global_position)
	if world.field_map is RemakePlayableField:
		var source: RemakePlayableField = world.field_map as RemakePlayableField
		for region_id: String in ["meadow", "forest", "dragon_valley", "ruins", "western_approach"]:
			var cells: PackedInt32Array = source.region_cells.get(region_id, PackedInt32Array())
			if cells.is_empty(): continue
			for index: int in range(0, cells.size(), maxi(1, int(cells.size() / 16))):
				var flat: int = cells[index]
				anchors.append(source.cell_to_world(Vector2i(flat % source.width, int(flat / source.width))))
	for anchor: Vector2 in anchors:
		for radius: float in [0., 80., 160., 240., 320., 400., 560., 720., 960., 1280.]:
			for direction: int in range(8):
				var point: Vector2 = anchor + screen_direction(direction) * radius
				if route_clear(point, 150.): return point
	return Vector2.INF

func record_for(name_value: String) -> Dictionary:
	for record: Dictionary in world.monster_db:
		if str(record.name) == name_value: return record
	return {}

func db_actor(name_value: String) -> TwilightMonster:
	var record := record_for(name_value)
	check(not record.is_empty(),"production DB monster " + name_value)
	if record.is_empty(): return null
	var actor: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(actor)
	actor.position = center + Vector2(40,0)
	actor.setup(record,world.player,world,world._monster_texture(record))
	# Match the real FieldPopulation spawn configuration in this same map.
	if world.field_map is NativePngField:
		preload("res://scripts/maps/source_body_profile.gd").apply(actor,true)
	actor.collision_mask = 4
	actor.died.connect(world._on_monster_died)
	actor.player_hit.connect(world._on_player_hit)
	actor.selected.connect(world._select_monster)
	actor.set_physics_process(false)
	return actor

func capture(name_value: String) -> void:
	if captures.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(captures.path_join(name_value + ".png")) == OK,"actual Main screenshot " + name_value)
	report.screenshots.append(name_value + ".png")

func player_strike(sequence: int) -> void:
	var origins: Array[String] = []
	for flight: Dictionary in world.combat_flights.flights: origins.append(str(flight.position))
	strikes.append({"id":sequence,"tick":ticks_elapsed,"elapsed":world.player.motion.attack_elapsed,
		"marker_seconds":world.player.motion.attack_duration*world.player.motion.attack_hit_ratio,
		"facing":world.player.facing8,"flights":world.combat_flights.flights.size(),"launch_origins":origins})

func trace_flights() -> void:
	# Physics may advance several ticks between rendered frames. Observe every
	# real physics tick so a short flight cannot escape validation at low FPS.
	if not is_instance_valid(world) or world.combat_flights == null: return
	for flight: Dictionary in world.combat_flights.flights:
		var target: Variant = flight.target.get_ref()
		if not is_instance_valid(target) or not target is TwilightMonster: continue
		var sequence: int = world.player.motion.sequence
		var observation: Dictionary = flight_observations.get(sequence,{"samples":0,"delta":Vector2.ZERO,"kind":flight.kind})
		observation.samples += 1
		var delta: Vector2 = flight.position-flight.previous
		if delta.length_squared() > .01:
			observation.delta = delta
			var aim: Vector2 = target.combat_hit_position()-(flight.previous as Vector2)
			check(delta.normalized().dot(aim.normalized()) > .995,"actual physics projectile travels toward target, sequence " + str(sequence))
		flight_observations[sequence] = observation

func player_case(spec: Dictionary, transformed: bool) -> void:
	world.player.position = center
	world.player.clear_click_path()
	var target := db_actor("데스나이트")
	if target == null: return
	var form: String = "transform:"+str(spec.transform_id) if transformed else "class:" + str(world.player.class_index)
	for direction: int in range(8):
		var prefix := "%s %s %s" % [spec.type,form,COMPASS[direction]]
		world.player.position = center
		target.position = center-screen_direction(direction)*145.
		world.player.cancel_attack()
		world.player.clear_click_path()
		var before: Vector2 = world.player.position
		for action: String in ACTIONS[direction]: Input.action_press(action)
		await tick(12)
		var moved: Vector2 = world.player.position - before
		var sprite := active_sprite()
		check(moved.length() > 10. and moved.normalized().dot(screen_direction(direction)) > .995,prefix + " actual input movement")
		check(world.player.facing8 == direction,prefix + " velocity-facing")
		# A transform that also authors RUN presents it at full movement speed.
		check(sprite.animation in ["walk_" + str(direction), "run_" + str(direction)],prefix + " native walk track")
		check(upright(sprite),prefix + " walk keeps upright original pixels")
		release_inputs()
		await tick(14)
		check(sprite.animation == "idle_" + str(direction),prefix + " native idle track after movement")
		world.player.position = center
		var attack_distance: float = 140. if bool(spec.magic) else 96. if str(spec.type) == "활" else 40.
		# 40 screen pixels can cross two native isometric grid cells in only
		# some facings. Never bypass weapon range or map line of sight.
		var legal_attack_position: bool = false
		for distance: float in [attack_distance, attack_distance * .75, attack_distance * .5, attack_distance * .25]:
			var candidate: Vector2 = center + screen_direction(direction) * distance
			target.position = candidate
			var native_range_ok: bool = (world.player.global_position.distance_to(candidate) <= attack_distance + 1.0) if bool(spec.magic) else world._target_in_current_weapon_range(target)
			if world.field_map.walkable(candidate) and world.field_map.point_clear(candidate) and not world.field_map.is_safe(candidate) and native_range_ok and world._has_line_of_sight_world(world.player.global_position, candidate):
				legal_attack_position = true
				break
		check(legal_attack_position, prefix + " real original-grid weapon reach and line of sight")
		if not legal_attack_position: continue
		target.motion.cancel_attack()
		world._select_monster(target)
		# Wait for the real cooldown; do not bypass the production cadence.
		for _wait: int in range(100):
			if world.auto_attack_timer <= 0. and not world.player.motion.presenting_attack: break
			await tick()
		var hp_before: int = target.hp
		var hits_before: int = target.damage_hit_count
		var strike_before: int = strikes.size()
		var seed_value := 1
		var probe := RandomNumberGenerator.new()
		var chance: float = world._player_magic_hit_chance(target) if bool(spec.magic) else world._normal_attack_hit_chance(target,world._current_attack_kind())
		# Choose an actual RNG seed giving a normal successful hit; damage and
		# hit formulas still run in production without substitutions.
		while true:
			probe.seed = seed_value
			if probe.randf() < chance: break
			seed_value += 1
		world.rng.seed = seed_value
		if bool(spec.magic): world.hud.combat_skill_pressed.emit("magic")
		else: world.hud.attack_pressed.emit()
		check(not world.pending_attack.is_empty(),prefix + " real command starts windup")
		if world.pending_attack.is_empty():
			print("PR100_COMMAND_REJECTED " + JSON.stringify({"case":prefix,"timer":world.auto_attack_timer,"strikes":strikes.size()-strike_before,
				"hp":world.hp,"range_ok":world._target_in_current_weapon_range(target),"line_clear":world._has_line_of_sight_world(center,target.position),
				"ammo":world.inventory.get("화살",-1),"stunned":world.player.is_stunned(),"fear":world.player.is_feared()}))
			continue
		check(world.player.facing8 == direction,prefix + " target-facing windup")
		check(world.player.motion.attack_style == str(spec.style),prefix + " weapon action style")
		var sequence: int = int(world.pending_attack.id)
		var origin: Vector2 = world.player.combat_projectile_origin()
		var anchor: Vector2 = world.player.motion.profile.projectile_origin
		check(origin.is_equal_approx(center+Vector2(0,anchor.y)+screen_direction(direction)*absf(anchor.x)),prefix + " native projectile anchor follows independent screen vector")
		var saw_attack := false
		var attack_captured := false
		var marker_pose_checked := false
		var authored_track: String = ("cast_" if bool(spec.magic) else "ranged_attack_" if str(spec.type) == "활" else "attack_") + str(direction)
		check(sprite.sprite_frames.has_animation(authored_track),prefix + " existing real weapon-specific native track")
		var saw_flight := false
		var projectile_delta := Vector2.ZERO
		for _attack_tick: int in range(150):
			await tick()
			sprite = active_sprite()
			if world.player.motion.presenting_attack and world.player.motion.attack_elapsed > 0.:
				saw_attack = true
				check(str(sprite.animation) == authored_track,prefix + " dedicated weapon track retains facing")
				check(upright(sprite),prefix + " attack never flips actor")
			if strikes.size() == strike_before:
				check(target.hp == hp_before and target.damage_hit_count == hits_before,prefix + " no hit before marker")
			elif not marker_pose_checked:
				marker_pose_checked = true
				var role: String = authored_track.trim_suffix("_"+str(direction))
				check(str(sprite.animation) == authored_track and sprite.frame == world.player.motion.profile.hit_frame_for(role),prefix + " visible weapon contact frame and damage marker share clock")
			if not attack_captured and world.player.motion.presenting_attack and world.player.motion.visual_progress >= world.player.motion.attack_hit_ratio:
				attack_captured = true
				await capture("attack-%s-%s-%s" % [spec.type,"transform" if transformed else "base",COMPASS[direction]])
			for flight: Dictionary in world.combat_flights.flights:
				if flight.target.get_ref() != target: continue
				saw_flight = true
				check(str(flight.kind) == ("magic" if bool(spec.magic) else "ranged"),prefix + " flight type")
				var delta: Vector2 = flight.position - flight.previous
				if delta.length_squared() > .01:
					projectile_delta = delta
					var aim: Vector2 = target.combat_hit_position() - (flight.previous as Vector2)
					check(delta.normalized().dot(aim.normalized()) > .995,prefix + " projectile advances toward actual target torso")
			if strikes.size() > strike_before and not world.player.motion.presenting_attack and world.combat_flights.flights.is_empty(): break
		check(saw_attack,prefix + " native attack displayed")
		check(strikes.size() == strike_before + 1 and int(strikes.back().id) == sequence,prefix + " exactly one marker")
		if strikes.size() > strike_before:
			check(float(strikes.back().elapsed) >= float(strikes.back().marker_seconds) and float(strikes.back().elapsed)-float(strikes.back().marker_seconds) < .04,prefix + " marker timing")
			if bool(spec.magic) or str(spec.type) == "활": check((strikes.back().launch_origins as Array).has(str(origin)),prefix + " production flight launches at weapon origin at marker")
		if flight_observations.has(sequence):
			saw_flight = true
			projectile_delta = flight_observations[sequence].delta
		check(target.hp < hp_before and target.damage_hit_count == hits_before + 1,prefix + " real hit exactly once")
		check(not target.dead,prefix + " original high-HP target survives directional inspection")
		if bool(spec.magic) or str(spec.type) == "활": check(saw_flight,prefix + " real projectile visible in physics lifecycle")
		await tick(14)
		check(active_sprite().animation == "idle_" + str(direction),prefix + " attack settles to same directional idle")
		report.player.append({"weapon":spec.type,"form":form,"compass":COMPASS[direction],"facing":world.player.facing8,
			"movement":str(moved),"idle":str(active_sprite().animation),"style":world.player.motion.attack_style,"authored_attack_track":authored_track,
			"attack_visible":saw_attack,"projectile_visible":saw_flight,"projectile_delta":str(projectile_delta),
			"hp_before":hp_before,"hp_after":target.hp,"hit_count":target.damage_hit_count-hits_before})
		await capture("player-%s-%s-%s" % [spec.type,"transform" if transformed else "base",COMPASS[direction]])
		print("PR100_GAMEPLAY_DIRECTION " + JSON.stringify(report.player.back()))
		if bool(spec.magic): await staff_normal_attack(target,spec,transformed,direction)
	target.queue_free()
	await tick(2)

func staff_normal_attack(target: TwilightMonster, spec: Dictionary, transformed: bool, direction: int) -> void:
	var form: String = "transform:"+str(spec.transform_id) if transformed else "class:"+str(world.player.class_index)
	var prefix := "staff normal %s %s" % [form,COMPASS[direction]]
	# The normal melee swing of a staff uses *native weapon grid cells*, not
	# the 140px magic cast range. The A3 isometric basis makes a fixed 40px
	# offset two cells away in S/SW/NW/N even though east/west works.
	# Choose the farthest clear candidate that the real combat rules accept.
	var valid_reach: bool = false
	for attack_distance: float in [40.0, 30.0, 20.0, 12.0, 0.0]:
		var point: Vector2 = center + screen_direction(direction) * attack_distance
		target.position = point
		if world.field_map != null and world.field_map.walkable(point) and world.field_map.point_clear(point) and not world.field_map.is_safe(point) and world._target_in_current_weapon_range(target) and world._has_line_of_sight_world(world.player.global_position, point):
			valid_reach = true
			break
	check(valid_reach, prefix + " real source-grid melee reach with terrain and LOS")
	if not valid_reach: return
	world._select_monster(target)
	for _wait: int in range(100):
		if world.auto_attack_timer <= 0. and not world.player.motion.presenting_attack: break
		await tick()
	var hp_before: int = target.hp
	var hits_before: int = target.damage_hit_count
	var strikes_before := strikes.size()
	var probe := RandomNumberGenerator.new()
	var seed_value := 1
	while true:
		probe.seed = seed_value
		if probe.randf() < world._normal_attack_hit_chance(target,world._current_attack_kind()): break
		seed_value += 1
	world.rng.seed = seed_value
	world.hud.attack_pressed.emit()
	check(not world.pending_attack.is_empty(),prefix+" real HUD normal attack starts")
	if world.pending_attack.is_empty(): return
	var seen := false
	for _wait: int in range(100):
		await tick()
		if world.player.motion.presenting_attack and world.player.motion.attack_elapsed > 0.:
			seen = true
			check(str(active_sprite().animation) == "attack_"+str(direction),prefix+" dedicated staff attack track")
			check(upright(active_sprite()),prefix+" no flip during normal attack")
		if strikes.size() == strikes_before: check(target.hp == hp_before,prefix+" no normal damage before marker")
		if strikes.size() > strikes_before and not world.player.motion.presenting_attack: break
	check(seen and strikes.size() == strikes_before+1,prefix+" native staff swing releases once")
	check(target.hp < hp_before and target.damage_hit_count == hits_before+1,prefix+" real staff melee hit once")
	check(world.combat_flights.flights.is_empty(),prefix+" existing staff normal attack remains melee")
	await tick(14)
	check(str(active_sprite().animation) == "idle_"+str(direction),prefix+" normal attack returns to same facing idle")
	report.staff_normal.append({"form":form,"compass":COMPASS[direction],"track":"attack_"+str(direction),"visible":seen,
		"hp_before":hp_before,"hp_after":target.hp,"hits":target.damage_hit_count-hits_before})

func monster_start_distance() -> float: return 140.
func prepare_monster_direction(direction: int) -> bool:
	if not world.field_map is NativePngField: return true
	# The directional QA stage relocates an existing skeleton from its small
	# habitat to this real clearing. Keep patrol enforcement active by binding
	# only this paused slot's fixture to the clearing's actual reviewed patrol.
	var slot_id: int = int(normal.get_meta("field_slot",-1))
	# Other inherited art suites instantiate an unbound DB actor. They have no
	# population habitat to relocate and retain their existing patrol behavior.
	if slot_id<0: return true
	if slot_id>=world.field_population.slots.size(): return false
	var start: Vector2 = center-screen_direction(direction)*monster_start_distance()
	for region: Dictionary in world.field_map.data.get("monster_spawn",[]):
		var patrol: Dictionary = region.get("patrol_region",{})
		if patrol.is_empty(): continue
		if not world.field_map.REGION_GEOMETRY.contains(patrol,center) or not world.field_map.REGION_GEOMETRY.contains(patrol,start): continue
		var slot: Dictionary = world.field_population.slots[slot_id]
		var fixture: Dictionary = slot.region.duplicate(true)
		fixture["patrol_region"] = patrol.duplicate(true)
		slot.region = fixture
		report.setup["qa_patrol_relocation"] = str(region.id)
		return true
	return false

func monster_case() -> void:
	check(is_instance_valid(normal),"existing field skeleton actor")
	if not is_instance_valid(normal): return
	normal.player_hit.connect(func(actor: TwilightMonster, damage: int, kind: String) -> void:
		monster_strikes.append({"name":actor.monster_name,"damage":damage,"kind":kind,"facing":actor.motion.facing8}))
	for direction: int in range(8):
		if not prepare_monster_direction(direction):
			check(false, "real map approach for monster direction " + COMPASS[direction])
			continue
		world.player.position = center
		world.player.clear_click_path()
		normal.position = center-screen_direction(direction)*monster_start_distance()
		normal.home_position = normal.position
		normal.motion.cancel_attack()
		normal.returning_home = false
		normal.aggro_remaining = 10.
		normal.attack_cooldown = 0.
		normal.repath_cooldown = 0.
		normal.path = PackedVector2Array()
		var before := normal.position
		var count_before := monster_strikes.size()
		var saw_walk := false
		var saw_attack := false
		normal.set_physics_process(true)
		for _wait: int in range(240):
			await tick()
			if normal.motion.state in ["walk","run"]:
				saw_walk = true
				# Real A3 obstacles can steer a chasing actor onto a detour.
				# The visible walk must follow the actual steered heading;
				# net approach and attack facing are still checked below.
				check(normal.motion._resolved_key in ["walk_"+str(normal.motion.facing8),"run_"+str(normal.motion.facing8)],"existing skeleton pursuit " + COMPASS[direction])
			if normal.motion.presenting_attack:
				saw_attack = true
				check(normal.motion.facing8 == direction and normal.motion._resolved_key == "attack_"+str(direction),"existing skeleton attack " + COMPASS[direction])
			if monster_strikes.size() > count_before: break
		normal.set_physics_process(false)
		check(saw_walk and saw_attack,"actual AI pursuit and windup " + COMPASS[direction])
		check(monster_strikes.size() == count_before+1,"actual AI contact marker " + COMPASS[direction])
		check((normal.position-before).normalized().dot(screen_direction(direction)) > .98,"AI moves toward player " + COMPASS[direction])
		check(upright(normal.sprite),"monster pixels remain upright " + COMPASS[direction])
		report.monster.append({"name":normal.monster_name,"compass":COMPASS[direction],"walk":saw_walk,"attack":saw_attack,
			"movement":str(normal.position-before),"facing":normal.motion.facing8,"contacts":monster_strikes.size()-count_before})
		normal.motion.cancel_attack()
		await capture("monster-"+COMPASS[direction])
		# A prior magic projectile can leave the player in a native hit pose
		# for more than twelve physics ticks. Let it resolve before launching
		# the next-direction moving-projectile contact, with real clocks only.
		await tick(36 if normal.attack_type == "magic" else 12)

func boss_case() -> void:
	var boss := db_actor("그라디움")
	if boss == null: return
	check(boss.ai.has("special"),"DB boss retains existing special configuration")
	if not boss.ai.has("special"):
		boss.queue_free()
		return
	var contacts: Array[int] = []
	boss.player_hit.connect(func(_actor: TwilightMonster, damage: int, _kind: String) -> void: contacts.append(damage))
	for direction: int in range(8):
		world.player.position = center+screen_direction(direction)*80.
		world.player.clear_click_path()
		boss.position = center
		boss.home_position = center
		boss.motion.cancel_attack()
		boss.special_cooldown = 0.
		boss.aggro_remaining = 10.
		boss.sight_clock = 0.
		boss.set_physics_process(true)
		var warning := false
		var effect := false
		var warning_aim := Vector2.ZERO
		var effect_aim := Vector2.ZERO
		var special_sequence := -1
		var contacts_before: int = contacts.size()
		var player_hp_before: int = world.hp
		for _wait: int in range(180):
			await tick()
			var rig: TwilightMonsterVisual = boss.species_visual
			if rig.warning_active:
				warning = true
				warning_aim = rig.warning_aim
				check(rig.warning_center.is_equal_approx(center),"boss warning uses real world ground anchor " + COMPASS[direction])
				special_sequence = boss.special_sequence
				check(boss.motion.facing8 == direction and warning_aim.dot(screen_direction(direction)) > .995,"boss warns toward player " + COMPASS[direction])
				check(attack_track(boss.motion._resolved_key,direction),"boss skill uses directional attack art " + COMPASS[direction] + " actual=" + boss.motion._resolved_key + " state=" + boss.motion.state)
				check(boss.motion.active,"boss does not return idle during windup " + COMPASS[direction])
			if rig.effect_age >= 0.:
				effect = true
				effect_aim = rig.effect_aim
				check(rig.effect_center.is_equal_approx(center),"boss impact retains real world ground anchor " + COMPASS[direction])
				check(effect_aim == warning_aim and not rig.warning_active,"boss impact retains authoritative warning direction " + COMPASS[direction])
				check(boss.released_sequence == special_sequence,"boss effect releases at existing strike marker " + COMPASS[direction])
				break
		boss.set_physics_process(false)
		check(warning and effect,"actual boss AI warning and skill effect " + COMPASS[direction])
		check(contacts.size() == contacts_before+1,"existing boss beam contacts player in warned direction exactly once " + COMPASS[direction])
		check(upright(boss.sprite),"boss pixels remain upright " + COMPASS[direction])
		report.boss.append({"name":boss.monster_name,"kind":boss.ai.special.kind,"compass":COMPASS[direction],
			"warning":warning,"effect":effect,"warning_aim":str(warning_aim),"effect_aim":str(effect_aim),"facing":boss.motion.facing8,
			"contacts":contacts.size()-contacts_before,"player_hp_before":player_hp_before,"player_hp_after":world.hp})
		await capture("boss-"+COMPASS[direction])
		boss.motion.cancel_attack()
		boss.species_visual.reset_presentation()
		await tick(12)
	boss.queue_free()
	await tick(2)

func lifecycle_attempt_limit() -> int: return 30

func lifecycle_case() -> void:
	world._clear_drops()
	world.player.position = center
	normal.position = center+Vector2(40,0)
	if world.field_map is NativePngField:
		# The native grid uses 16px cells, so the old 40px fixture is outside a
		# one-cell sword's range. Select a legal contact without changing reach.
		var in_reach: bool = false
		for distance: float in [40.,30.,20.,10.]:
			normal.position = center+Vector2(distance,0)
			if world.field_map.walkable(normal.position) and world.field_map.point_clear(normal.position) and not world.field_map.is_safe(normal.position) and world._target_in_current_weapon_range(normal) and world._has_line_of_sight_world(center,normal.position):
				in_reach = true
				break
		check(in_reach,"existing field monster placed inside actual equipped weapon reach")
		if not in_reach: return
	normal.home_position = normal.position
	normal.motion.cancel_attack()
	world._select_monster(normal)
	var deaths: Array[int] = []
	normal.died.connect(func(actor: TwilightMonster) -> void: deaths.append(actor.life_id))
	var hp_start: int = normal.hp
	var attempts := 0
	var life_ticks := 0
	var hit_seen := false
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var attempt_limit := lifecycle_attempt_limit()
	var tick_limit: int = attempt_limit * maxi(80, ceili(world._normal_attack_interval() * 60.) + 5)
	while is_instance_valid(normal) and not normal.dead and attempts < attempt_limit and life_ticks < tick_limit:
		if world.auto_attack_timer <= 0. and world.pending_attack.is_empty():
			world.rng.seed = 1 + attempts
			world.hud.attack_pressed.emit()
			attempts += 1
		await tick()
		life_ticks += 1
		if is_instance_valid(normal) and normal.motion.hit_clock > 0. and not normal.dead:
			# Render the frozen QA actor using its existing pose clock; no AI rewrite.
			normal.motion.advance(.01,Vector2.ZERO)
			normal.motion.apply(normal.sprite,normal.animation_base_scale)
			hit_seen = hit_seen or normal.motion._resolved_key.begins_with("hit_")
	check(is_instance_valid(normal) and normal.dead,"real equipped weapon kills existing field monster")
	check(deaths.size() == 1,"monster death callback exactly once")
	check(hit_seen,"native monster hit pose displayed")
	var death_track := ""
	if is_instance_valid(normal):
		await tick(12)
		death_track = normal.motion._resolved_key
		check(death_track.begins_with("death_"),"real field corpse plays directional death")
		check(upright(normal.sprite),"authored death has no second rotation")
	var drops: Array = world.ground_loot.snapshot()
	# Production equipment (0.315%) and potion (45%) rolls are not guaranteed
	# on any one normal kill. The previous test incorrectly required a drop
	# from every death. Preserve the actual death outcome in evidence.
	report.setup.real_death_drops = drops.size()
	if drops.is_empty():
		# Exercise the exact production loot table deterministically for the
		# subsequent real ground/view/manual-pickup checks. This extra fixture
		# is NOT counted as a drop from the killed monster, and does not grant
		# inventory or modify production drop rates.
		var sample_rng := RandomNumberGenerator.new()
		var sampled: Array[Dictionary] = []
		for seed_value: int in range(1, 257):
			sample_rng.seed = seed_value
			sampled = LOOT_ROLL.roll_detailed(normal.drop_items, normal.is_boss, world.loot_catalog, sample_rng, normal.monster_name)
			if not sampled.is_empty():
				break
		check(not sampled.is_empty(),"real DB loot table produces an obtainable item")
		if not sampled.is_empty():
			var entry: Dictionary = sampled[0]
			var generated: Button = world._spawn_ground_drop(str(entry.get("item_name", "")),normal.global_position,int(entry.get("quantity", 1)))
			check(generated != null,"real ground loot manager places deterministic production-roll sample")
			drops = world.ground_loot.snapshot()
	check(not drops.is_empty(),"actual production ground loot can be spawned for manual UI pickup")
	var picked := false
	if not drops.is_empty():
		var drop: Dictionary = drops[0]
		var name_value := str(drop.item_name)
		var before: int = int(world.inventory.get(name_value,0))
		check(before == int(inventory_before.get(name_value,0)),"drop is not immediately awarded")
		# A genuine kill may leave production stun/fear/hold or weapon motion
		# active. The manual pickup controller rightly rejects these states.
		# Wait for the original live timers instead of bypassing their logic.
		var recovery_ticks: int = 0
		while recovery_ticks < 480 and (world.player.is_stunned() or world.player.is_feared()
				or world.player.is_held() or world.player.movement_locked):
			await tick()
			recovery_ticks += 1
		report.setup.pickup_recovery_ticks = recovery_ticks
		check(not world.player.is_stunned() and not world.player.is_feared()
			and not world.player.is_held() and not world.player.movement_locked,
			"real combat control and movement lock recover before manual pickup")
		(world.ground_loot.views[str(drop.id)] as Button).pressed.emit()
		world.loot_pickup.pickup_button.pressed.emit()
		for _wait: int in range(180):
			await tick()
			if not world.ground_loot.records.has(str(drop.id)): break
		picked = int(world.inventory.get(name_value,0)) == before+int(drop.quantity)
		check(picked and not world.ground_loot.records.has(str(drop.id)),
			"actual UI manual pickup awards once; mode=" + str(world.loot_pickup.mode)
			+ " target=" + str(world.loot_pickup.target_id)
			+ " stunned=" + str(world.player.is_stunned()) + " held=" + str(world.player.is_held())
			+ " feared=" + str(world.player.is_feared()) + " locked=" + str(world.player.movement_locked)
			+ " pending=" + str(world.ground_loot.records.has(str(drop.id)))
			+ " owned=" + str(world.inventory.get(name_value, 0))
			+ " expected=" + str(before + int(drop.quantity)))
	await tick(90)
	check(not is_instance_valid(normal) or not normal.is_physics_processing(),"corpse lifecycle terminates or enters dormant pool")
	report.lifecycle = {"hp_start":hp_start,"hp_end":normal.hp if is_instance_valid(normal) else 0,"weapon_attempts":attempts,"attempt_limit":attempt_limit,"hit_pose":hit_seen,"death_callbacks":deaths.size(),
		"death_track":death_track,"ground_drops":drops,"manual_pickup":picked,"player_hp":world.hp}

func run() -> void:
	out = OS.get_environment("TWILIGHT_PR100_REPORT")
	if out.is_empty(): out = "user://pr100-direction-gameplay.json"
	captures = OS.get_environment("TWILIGHT_PR100_CAPTURE_DIR")
	if not captures.is_empty():
		check(DisplayServer.get_name() != "headless","screenshots require an actual rendered Main viewport")
		if DisplayServer.get_name() == "headless": captures = ""
		else: DirAccess.make_dir_recursive_absolute(captures)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world,"기사"),"production UI initial class selection")
	world.hud._hide_aux_panels()
	world.save_timer = -10000.
	world.rng.seed = 20261013
	world._set_map("aden_world",false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	center = find_clearing()
	check(center.is_finite(),"existing Aden field has a valid eight-direction movement and combat clearing")
	if not center.is_finite(): await finish(); return
	world.player.set_auto_enabled(false)
	world.player.camera.zoom = Vector2(1.8,1.8)
	world.player.camera.position = Vector2(0,-32)
	world.player.attack_strike.connect(player_strike)
	physics_frame.connect(trace_flights)
	report.scope = "full"
	report.setup = {"scene":"Main.tscn","map":"aden_world","clearing":str(center),"normal":"해골 근위병",
		"attack_target":"데스나이트","boss":"그라디움","stats_overridden":false,"qa_positioning":true,
		"background_spawn_slots_paused":true,"normal_is_existing_population_actor":true}
	var section := OS.get_environment("TWILIGHT_PR100_SECTION")
	if section == "boss":
		# Same production scene and boss AI as the full regression, for short
		# real-game skill recordings without rerunning weapon/corpse sequences.
		report.scope = "boss_only"
		world.player.position = center
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		await boss_case()
		await finish()
		return
	check(section.is_empty(),"only the documented optional boss section may narrow this test")
	for spec: Dictionary in WEAPONS:
		var transform: Dictionary = {}
		for record: Dictionary in world.catalog_db["변신"]:
			if str(record.get("sourceId","")) == str(spec.transform_id): transform = record; break
		check(not transform.is_empty(),"existing weapon-compatible transformation " + str(spec.transform_id))
		check(CLASS_QA.enter_game(world,str(spec.job)),"production class UI " + str(spec.job))
		# Job and appearance have separate existing HUD signals; explicitly cover
		# the archer and mage sprites instead of accidentally reusing warrior.
		world.hud.class_selected.emit(int(spec.appearance))
		check(world.player.class_index == int(spec.appearance),"production appearance selection " + str(spec.job))
		world.hud._hide_aux_panels()
		var weapon: Dictionary = world._find_catalog_item_record(str(spec.name))
		check(not weapon.is_empty(),"existing DB weapon " + str(spec.name))
		world._equip_or_acquire_item(weapon,true)
		check(world._current_weapon_type() == str(spec.type),"real equipment handler " + str(spec.type))
		world._equip_catalog("변신",{})
		await tick(14)
		await player_case(spec,false)
		world._equip_catalog("변신",transform)
		await tick(14)
		check(world.player.motion.profile.profile_id == "transform:"+str(spec.transform_id),"production transform equipment updates profile")
		var interval: float = world._normal_attack_interval()
		await player_case(spec,true)
		world._equip_catalog("변신",{})
		await tick(14)
		check(not world.player.transform_active,"transform removal restores base class")
		world._equip_catalog("변신",transform)
		await tick(14)
		check(world.player.transform_active and world.player.motion.profile.profile_id == "transform:"+str(spec.transform_id) and is_equal_approx(interval,world._normal_attack_interval()),"transform roundtrip retains motion and attack cadence " + str(spec.type))
	# Knight and its existing DB sword are used for incoming combat / lifecycle.
	check(CLASS_QA.enter_game(world,"기사"),"return to production knight class")
	world.hud.class_selected.emit(0)
	world.hud._hide_aux_panels()
	world._equip_or_acquire_item(world._find_catalog_item_record("훈련용 한손검"),true)
	for record: Dictionary in world.catalog_db["변신"]:
		if str(record.get("sourceId","")) == "131": world._equip_catalog("변신",record); break
	await monster_case()
	await boss_case()
	await lifecycle_case()
	await finish()

func finish() -> void:
	release_inputs()
	report.checks = checks
	report.failures = failures
	report.physics_ticks = ticks_elapsed
	report.player_strikes = strikes
	report.monster_contacts = monster_strikes
	report.flight_physics_observations = flight_observations
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var file := FileAccess.open(out,FileAccess.WRITE)
	check(file != null,"JSON evidence path writable")
	if file != null: file.store_string(JSON.stringify(report,"\t"))
	if is_instance_valid(world): world.queue_free()
	await process_frame
	print("PR100_DIRECTION_GAMEPLAY_RESULT " + JSON.stringify({"scope":report.get("scope","full"),"checks":checks,"failures":failures,"player_rows":report.player.size(),"staff_normal_rows":report.staff_normal.size(),"monster_rows":report.monster.size(),"boss_rows":report.boss.size(),"report":out}))
	if failures.is_empty(): print("PR100_BOSS_GAMEPLAY_OK" if report.get("scope", "full") == "boss_only" else "PR100_DIRECTION_GAMEPLAY_OK")
	if quit_on_finish: quit(0 if failures.is_empty() else 1)
