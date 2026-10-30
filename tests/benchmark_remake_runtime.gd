extends SceneTree
## Copy this exact file to both checkouts. Run sequentially, with fresh user dirs
## and already-imported assets. This is a benchmark, not a device FPS guarantee.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
const SEED: int = 20261013
const POPULATION: int = 24
const WARMUP_FRAMES: int = 60
const SAMPLE_FRAMES: int = 120
const OUTPUT: String = "user://remake-runtime-benchmark"

# Production _ready randomizes its RNG before _load_data. Override only that
# test seed, retaining the real Main scene, data, geometry, art and startup flow.
class SeededWorld extends "res://scripts/world.gd":
	func _load_data() -> void:
		rng.seed = 20261013
		super._load_data()

var world: TwilightWorld
var failures: Array[String] = []
var player_releases: int = 0
var monster_releases: int = 0
var report: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("REMAKE_RUNTIME_BENCHMARK_FAIL "+label)

func drawn_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func memory_snapshot() -> Dictionary:
	var result: Dictionary = {
		"godot_static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"godot_static_peak_bytes":OS.get_static_memory_peak_usage(),
		"render_video_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))}
	# Linux process RSS includes driver/native allocations omitted by Godot's
	# allocator monitor. VmHWM is the process lifetime peak, not GPU VRAM.
	if OS.get_name() == "Linux" and FileAccess.file_exists("/proc/self/status"):
		for line: String in FileAccess.get_file_as_string("/proc/self/status").split("\n"):
			if line.begins_with("VmRSS:") or line.begins_with("VmHWM:"):
				var key: String = "process_rss_bytes" if line.begins_with("VmRSS:") else "process_peak_rss_bytes"
				result[key] = int(line.get_slice(":",1).strip_edges().get_slice(" ",0))*1024
	return result

func summary(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var middle: int = sorted.size()/2
	var median: float = (sorted[middle-1]+sorted[middle])*.5 if sorted.size()%2 == 0 else sorted[middle]
	var total: float = 0.0
	for value: float in sorted: total += value
	return {"median":median,"p95":sorted[ceili(sorted.size()*.95)-1],"max":sorted[-1],"mean":total/sorted.size()}

func freeze_setup() -> void:
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)

func measure_transform(record: Dictionary, label: String) -> Dictionary:
	var key: String = "transform:"+str(record.sourceId)
	var cached_before: bool = VISUALS._frames.has(key)
	var begin: int = Time.get_ticks_usec()
	world._equip_catalog("변신",record)
	var call_ms: float = float(Time.get_ticks_usec()-begin)/1000.0
	await drawn_frame()
	check(world.player.transform_active,label+" transform is active")
	return {"label":label,"source_id":str(record.sourceId),"name":str(record.name),
		"manifest_frames_cached_before":cached_before,"equip_call_ms":call_ms,
		"equip_to_draw_ms":float(Time.get_ticks_usec()-begin)/1000.0,"memory":memory_snapshot()}

func combat_positions(region: Dictionary) -> Array[Vector2]:
	var cells: Array = world.field_map.spawn_cells.get(str(region.id),[]).duplicate()
	var box: Array = region.rect
	var center := Vector2(float(box[0])+float(box[2])*.5,float(box[1])+float(box[3])*.5)
	cells.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:
		var da: float = world.field_map.cell_to_world(a).distance_squared_to(center)
		var db: float = world.field_map.cell_to_world(b).distance_squared_to(center)
		return da<db if not is_equal_approx(da,db) else (a.y<b.y or (a.y==b.y and a.x<b.x)))
	for candidate: int in range(mini(32,cells.size())):
		var anchor: Vector2 = world.field_map.cell_to_world(cells[candidate])
		var positions: Array[Vector2] = [anchor]
		for cell: Vector2i in cells:
			var point: Vector2 = world.field_map.cell_to_world(cell)
			var distance: float = anchor.distance_to(point)
			if distance<48.0 or distance>280.0 or not world.field_map.line_clear(anchor,point): continue
			positions.append(point)
			if positions.size()==POPULATION+1: return positions
	return []

func prepare_combat() -> Dictionary:
	world._clear_combat_actions()
	world._clear_monsters()
	world.selected_monster = null
	world.auto_target = null
	await process_frame
	var normal_names: Array[String] = []
	var anchor_region: Dictionary = {}
	for region: Dictionary in world.field_map.data.monster_spawn:
		if str(region.get("mode","normal")) != "normal": continue
		if anchor_region.is_empty(): anchor_region = region
		for name_value: String in region.monster_types:
			if not normal_names.has(name_value): normal_names.append(name_value)
	var positions: Array[Vector2] = combat_positions(anchor_region)
	check(positions.size()==POPULATION+1 and not normal_names.is_empty(),"existing room supplies clear combat positions and DB species")
	if positions.size()!=POPULATION+1 or normal_names.is_empty(): return {}
	world.player.global_position = positions[0]
	world.player.camera.zoom = Vector2.ONE
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	world.quickslots = []
	world.max_hp = 999999
	world.hp = world._effective_max_hp()
	world.mp = world._effective_max_mp()
	world.portal_cooldown = 100000
	world.auto_attack_timer = 0.0
	world.auto_repath_timer = 0.0
	world.save_timer = -100000
	world.rng.seed = SEED
	seed(SEED)
	var scenario: Dictionary = {"map":"oman_01","anchor":[positions[0].x,positions[0].y],"monsters":[],
		"controls":{"population":POPULATION,"monster_hp":999999,"monster_atk":1,"player_base_hp":999999,
			"quickslots":[],"native_respawn_disabled":true,"asset_or_attack_type_overrides":false}}
	for index: int in range(POPULATION):
		var name_value: String = normal_names[index%normal_names.size()]
		var record: Dictionary = world.field_population.records[name_value].duplicate(true)
		record.merge({"hp":999999,"atk":1},true)
		var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
		world.monsters_root.add_child(monster)
		monster.global_position = positions[index+1]
		monster.setup(record,world.player,world,world._monster_texture(record))
		monster.home_position = monster.global_position
		monster.collision_mask = 4
		monster.aggro_remaining = 999.0
		monster.repath_cooldown = float(index%11)*.025
		monster.attack_cooldown = monster.attack_interval*float(index)/POPULATION
		monster.died.connect(world._on_monster_died)
		monster.player_hit.connect(world._on_player_hit)
		monster.player_hit.connect(func(_actor: TwilightMonster,_damage: int,_kind: String) -> void: monster_releases += 1)
		monster.selected.connect(world._select_monster)
		scenario.monsters.append({"name":name_value,"position":[monster.position.x,monster.position.y],"attack_type":monster.attack_type})
	world.player.attack_strike.connect(func(_id: int) -> void: player_releases += 1)
	world._update_hud()
	world.player.set_auto_enabled(true)
	world.player.set_physics_process(true)
	world.set_process(true)
	return scenario

func measure_combat() -> Dictionary:
	var times: Array[float] = []
	var cpu: Array[float] = []
	var physics: Array[float] = []
	var draws: Array[float] = []
	var peaks: Dictionary = {"nodes":0,"flights":0,"props":0,"chunks":0}
	var previous: int = Time.get_ticks_usec()
	var began: int = 0
	for index: int in range(WARMUP_FRAMES+SAMPLE_FRAMES):
		await drawn_frame()
		var now: int = Time.get_ticks_usec()
		if index == WARMUP_FRAMES: began = previous
		if index>=WARMUP_FRAMES:
			times.append(float(now-previous)/1000.0)
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			peaks.nodes = maxi(peaks.nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			peaks.flights = maxi(peaks.flights,world.combat_flights.flights.size())
			peaks.props = maxi(peaks.props,world.field_renderer.visible_props)
			peaks.chunks = maxi(peaks.chunks,world.field_renderer.chunks.size())
		previous = now
	var landed: int = 0
	for monster: TwilightMonster in world.monsters_root.get_children(): landed += monster.damage_hit_count
	check(player_releases>0 and monster_releases>0,"real AUTO and DB monster attacks occurred")
	check(world.active_map_id=="oman_01" and world.monsters_root.get_child_count()==POPULATION,"combat workload stayed on the same map with fixed population")
	return {"warmup_frames":WARMUP_FRAMES,"sample_frames":times.size(),"elapsed_ms":float(previous-began)/1000.0,
		"frame_interval_ms":summary(times),"process_cpu_ms":summary(cpu),"physics_cpu_ms":summary(physics),"draw_calls":summary(draws),
		"peaks":peaks,"memory":memory_snapshot(),"player_released_attacks":player_releases,
		"monster_released_attacks":monster_releases,"player_landed_hits":landed,"raw_frame_ms":times}

func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("REMAKE_RUNTIME_BENCHMARK_REQUIRES_OPENGL")
		quit(2)
		return
	# Never overwrite an existing user save to make a benchmark look repeatable.
	if FileAccess.file_exists("user://twilight_v20_save.json") or FileAccess.file_exists("user://twilight_ui_settings.cfg"):
		printerr("REMAKE_RUNTIME_BENCHMARK_REQUIRES_FRESH_USER_DIR")
		quit(2)
		return
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	seed(SEED)
	var began: int = Time.get_ticks_usec()
	world = load("res://Main.tscn").instantiate()
	world.set_script(SeededWorld)
	root.add_child(world)
	var ready_at: int = Time.get_ticks_usec()
	check(CLASS_QA.enter_game(world),"production class confirmation enters playable knight")
	world.hud._close_workspace()
	world.save_timer = -100000
	freeze_setup()
	await drawn_frame()
	var playable_at: int = Time.get_ticks_usec()
	report = {"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],
		"fps_cap":Engine.max_fps,"physics_hz":Engine.physics_ticks_per_second,"time_scale":Engine.time_scale,"vsync_mode":DisplayServer.window_get_vsync_mode(),
		"seed":SEED,"fresh_user_dir":true,"script_sha256":FileAccess.get_sha256("res://tests/benchmark_remake_runtime.gd"),
		"revision_label":OS.get_environment("TWILIGHT_BENCHMARK_REVISION"),
		"runner_cache_policy":OS.get_environment("TWILIGHT_BENCHMARK_CACHE_POLICY"),
		"cache_scope":"Imported assets required; first-use/repeat refers to new-process frame caches, not cold disk/driver caches. Runner must match its external cache policy.",
		"source_note":"Existing repository art and map geometry only; no original Lineage terrain or animation delivery is claimed.",
		"scope":"Linux software OpenGL diagnostic, controlled 24-actor workload; not Windows/Android device FPS or game balance evidence.",
		"boot":{"main_load_and_ready_ms":float(ready_at-began)/1000.0,"main_load_to_playable_draw_ms":float(playable_at-began)/1000.0,
			"engine_start_to_playable_draw_ms":float(playable_at)/1000.0,"navigation_cache_hit":world.field_map.navigation_cache_hit,
			"geometry_signature":world.field_map.geometry_signature(),"memory":memory_snapshot()},"data_sha256":{}}
	print("REMAKE_RUNTIME_PLAYABLE ",JSON.stringify(report.boot))
	for path: String in ["res://data/maps/field_index.json","res://data/game_db_v17.json","res://data/monsters/monster_world_catalog.json","res://data/catalog_v19.json","res://data/visuals/runtime_manifest.json"]:
		report.data_sha256[path] = FileAccess.get_sha256(path)
	world.rng.seed = SEED
	var transition_begin: int = Time.get_ticks_usec()
	check(world.use_field_portal("oman_gate") and world.active_map_id=="oman_01","actual Aden portal enters existing Oman map")
	var transition_call_ms: float = float(Time.get_ticks_usec()-transition_begin)/1000.0
	freeze_setup()
	await drawn_frame()
	report["transition"] = {"from":"aden_world","to":world.active_map_id,"portal":"oman_gate","call_ms":transition_call_ms,
		"to_draw_ms":float(Time.get_ticks_usec()-transition_begin)/1000.0,"navigation_cache_hit":world.field_map.navigation_cache_hit,
		"geometry_signature":world.field_map.geometry_signature(),"memory":memory_snapshot()}
	var original: Dictionary = world.equipped_catalog["변신"].duplicate(true)
	var choices: Array = world.catalog_db["변신"]
	report["transforms"] = []
	for index: int in [0,1,0,1]:
		var label: String = ("first_use_" if report.transforms.size()<2 else "repeat_")+str(index)
		report.transforms.append(await measure_transform(choices[index],label))
	world._equip_catalog("변신",original)
	await drawn_frame()
	var scenario: Dictionary = await prepare_combat()
	if not scenario.is_empty():
		report["scenario"] = scenario
		report["scenario_sha256"] = JSON.stringify(scenario,"",true,true).sha256_text()
		report["combat"] = await measure_combat()
	freeze_setup()
	report["failures"] = failures
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var file := FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else: check(false,"benchmark report written")
	print("REMAKE_RUNTIME_BENCHMARK_OK " if failures.is_empty() else "REMAKE_RUNTIME_BENCHMARK_FAILED ",JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
