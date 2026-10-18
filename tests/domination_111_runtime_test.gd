extends SceneTree
## Existing Main: legacy save migration, current gameplay, real source-111 physics.
const QA = preload("res://tests/qa_class_selection.gd")
const TRAVEL = preload("res://scripts/maps/source_travel.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
var world: TwilightWorld
var checks: int = 0
var failures: Array[String] = []
var output: String = "user://domination-111"
var results: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("DOM111_FAIL ",label)
func frames(n: int) -> void:
	for i: int in range(n): await physics_frame
func place(field: RemakePlayableField, p: Vector2) -> void:
	world.player.clear_click_path();world.player.set_touch_vector(Vector2.ZERO)
	world.player.global_position = p;world.player.velocity = Vector2.ZERO
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	field.collision_stream.refresh();world.field_renderer.refresh_visible()

func run() -> void:
	if not "--png-review" in OS.get_cmdline_user_args() and not "--seed-legacy" in OS.get_cmdline_user_args():
		print("DOM111_RUNTIME_SKIP: actual private 111 pack and isolated review session required");quit();return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	check("dom111" in OS.get_environment("XDG_DATA_HOME"),"explicit isolated test save directory")
	if not failures.is_empty(): finish();return
	world = load("res://Main.tscn").instantiate();root.add_child(world)
	QA.enter_game(world);world.save_timer = -10000
	if "--seed-legacy" in OS.get_cmdline_user_args():
		world._set_map("aden_world" if "--seed-aden" in OS.get_cmdline_user_args() else "domination_summit",false)
		check(world.active_map_id == "aden_world" if "--seed-aden" in OS.get_cmdline_user_args() else not world.field_map is RemakePlayableField,"normal legacy map retained")
		world.gold = 12345678;world._save_game(true)
		check(FileAccess.file_exists(world.SAVE_PATH),"real production legacy save written")
		finish();return
	if not world.field_map is RemakePlayableField:
		check(false,"review startup loads source Domination");finish();return
	var field: RemakePlayableField = world.field_map
	check(world.active_map_id == "domination_summit" and field.definition.source_map_id == 111,"game ID Domination, original ID 111")
	check(world.field_renderer.png_review_active,"real 111 PNG active")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.SAVE_PATH))
	var before: String = FileAccess.get_sha256(world.SAVE_PATH)
	if "--startup-only" in OS.get_cmdline_user_args():
		check(saved.map_id == "aden_world","real save starts in another map")
		check(world.gold == 12345678 and field.point_clear(world.player.global_position),"explicit PNG destination preserves progress and safe landing")
		world._save_game(true)
		check(FileAccess.get_sha256(world.SAVE_PATH) == before,"explicit destination preserves legacy save")
		finish();return
	check(saved.map_id == "domination_summit" and int(saved.map_layout_revision) == 2,"real old-coordinate save loaded")
	check(world.gold == int(saved.gold) and world.gold == 12345678,"legacy character progress preserved")
	var old := Vector2(saved.position[0],saved.position[1])
	check(world.player.global_position.distance_to(old)>1 and field.point_clear(world.player.global_position),"old pixels replaced by safe original-grid landing")
	var snapshot: Dictionary = TRAVEL.snapshot(world)
	var restored: Array = TRAVEL.restore_position(world,snapshot)
	check(restored.size() == 2 and Vector2(restored[0],restored[1]).distance_to(world.player.global_position)<.01,"precise source coordinate roundtrip")
	var legacy: Dictionary = CATALOG.apply_map(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/domination_summit.json")))
	for expected: Dictionary in legacy.monster_spawn:
		var found: Dictionary = {}
		for region: Dictionary in field.data.monster_spawn:
			if region.id == expected.id: found = region;break
		check(not found.is_empty(),"preserved monster region "+str(expected.id))
		for key: String in ["monster_types","weights","mode","boss_id","max_count","respawn_time","roaming_radius","level","variants","spawn_conditions"]:
			check(found.get(key) == expected.get(key),str(expected.id)+" preserved gameplay "+key)
	for actor: Node in world.monsters_root.get_children():
		actor.set_physics_process(false)
		check(actor.get_node("CollisionShape2D").shape is CircleShape2D and actor.get_node("CollisionShape2D").shape.radius == 4,"same actual terrain body for monster")
	var boss: TwilightMonster
	var boss_region: Dictionary
	for slot: Dictionary in world.field_population.slots:
		if slot.region.get("mode") == "boss": boss = slot.monster;boss_region = slot.region
	check(is_instance_valid(boss) and boss.monster_name == "그림 리퍼","existing Grim Reaper boss")
	if is_instance_valid(boss):
		check(not field.path(world.player.global_position,boss.global_position).is_empty(),"original path reaches boss arena")
		world.level = 100;world.max_hp = 1000000;world.hp = world.max_hp;world.portal_cooldown = 10000
		var at: Vector2 = Vector2.INF
		var c: Vector2i = field.world_to_cell(boss.global_position)
		for dy: int in range(-5,6):
			for dx: int in range(-5,6):
				var p: Vector2 = field.cell_to_world(c+Vector2i(dx,dy))
				if maxi(absi(dx),absi(dy))>world._current_attack_range_cells(): continue
				if p.distance_to(boss.global_position)>=20 and p.distance_to(boss.global_position)<65 and field.point_clear(p) and not field.is_safe(p) and field.line_clear(p,boss.global_position): at = p
		check(at.is_finite(),"ordinary combat approach")
		if at.is_finite():
			place(field,at);world.selected_monster = boss;boss.set_physics_process(true)
			var hp_before: int = boss.hp
			var player_before: int = world.hp
			for attempt: int in range(18):
				world._attack();await frames(30)
				if boss.hp<hp_before and world.hp<player_before: break
			check(boss.hp<hp_before,"ordinary player attack damages existing boss")
			check(world.hp<player_before,"existing boss AI damages player")
			results["combat"] = {"boss_hp_before":hp_before,"boss_hp_after":boss.hp,"player_hp_before":player_before,"player_hp_after":world.hp}
		boss.set_physics_process(false)
		place(field,Vector2(field.data.spawn_position[0],field.data.spawn_position[1]))
		var inventory: Dictionary = world.inventory.duplicate(true)
		boss.take_damage(999999999);await frames(2)
		check(world.inventory == inventory,"boss death retains ground-drop workflow")
		var director: TwilightBossDirector = world.field_population.boss_director
		var key: String = director.key("domination_summit",boss_region)
		check(director.states[key].phase == "cooldown" and director.states[key].ready_at>Time.get_unix_time_from_system(),"existing boss cooldown recorded")
		var copy := TwilightBossDirector.new();copy.import_state(JSON.parse_string(JSON.stringify(director.export_state())))
		check(absf(copy.states[key].ready_at-director.states[key].ready_at)<.001,"boss deadline roundtrip within one millisecond")
	var portals: Array = field.data.portal.duplicate(true)
	var transitions: Array = []
	for portal: Dictionary in portals:
		world._set_map("domination_summit",false)
		world.player.global_position = Vector2(portal.position[0],portal.position[1]);world.portal_cooldown = 0
		world._update_field_triggers();await frames(3)
		check(world.active_map_id == portal.target_map,"real existing portal "+str(portal.id))
		transitions.append({"portal":portal.id,"target":world.active_map_id})
	world._set_map("domination_summit",false)
	world._save_game(true)
	check(FileAccess.get_sha256(world.SAVE_PATH) == before,"review preserves original save byte for byte")
	results["portals"] = transitions
	finish()

func finish() -> void:
	results.merge({"checks":checks,"failures":failures,"source_map_id":111,"game_map_id":"domination_summit","png_alignment":"REVIEW_REQUIRED"})
	var file := FileAccess.open(output+"/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("DOM111_RUNTIME_RESULT ",JSON.stringify(results))
	if is_instance_valid(world):world.queue_free();await frames(2)
	quit(0 if failures.is_empty() else 1)
