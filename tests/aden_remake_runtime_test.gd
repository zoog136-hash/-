extends SceneTree
## Run with an isolated XDG_DATA_HOME / APPDATA. Real Main, no substitute scene.
## Requires the private Aden pack. Missing source is NOT a successful test.
const REGISTRY = preload("res://scripts/maps/remake_registry.gd")
var world: TwilightWorld
var failures: Array[String] = []
var checks: int = 0
var output: String = "user://aden-remake-validation"
var capture: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ADEN_FAIL ",label)

func run() -> void:
	if preload("res://tests/legacy_aden_faith_fixture.gd").delegate(self,"res://tests/aden_remake_runtime_test.gd"): return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--capture": capture = true
	if not REGISTRY.installed("aden_world"):
		printerr("ADEN_NOT_RUN: install the verified private Aden pack first")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.save_timer = -100000
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world._set_map("aden_world",false)
	for frame: int in range(8): await process_frame
	check(world.active_map_id == "aden_world","existing map ID")
	check(world.field_map is RemakePlayableField,"original source field, not authored fallback")
	if not world.field_map is RemakePlayableField:
		finish()
		return
	var field: RemakePlayableField = world.field_map
	check(field.width == 2048 and field.height == 1536,"full mainland dimensions")
	check(field.chunk_table.size() == 768,"all original navigation chunks")
	check(field.definition.source_map_id == 4,"A3 mainland identity")
	check(world.field_renderer is RemakeSourceRenderer,"existing Oman renderer path")
	check(field.walkable(world.player.global_position),"entry walkability")
	check(field.point_clear(world.player.global_position),"entry collision clearance")
	var source_cell: Vector2i = field.world_to_cell(world.player.global_position)
	for heading: int in range(8):
		if heading % 2 == 0 or not field.can_step(source_cell,heading): continue
		var delta: Vector2i = field.DIRECTIONS[heading]
		check(field.can_step(source_cell,2 if delta.x > 0 else 6),"diagonal horizontal corner")
		check(field.can_step(source_cell,4 if delta.y > 0 else 0),"diagonal vertical corner")
	for npc: Dictionary in field.data.npc_spawn:
		check(field.point_clear(Vector2(npc.position[0],npc.position[1])),"NPC "+str(npc.id))
	for portal: Dictionary in field.data.portal:
		check(field.point_clear(Vector2(portal.position[0],portal.position[1])),"portal "+str(portal.id))
	for region: Dictionary in field.data.monster_spawn:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4
		for sample: int in range(4):
			var point: Vector2 = field.sample_spawn(str(region.id),rng)
			check(point.is_finite() and field.walkable(point) and not field.is_safe(point),"spawn "+str(region.id))
	# Actual engine movement through the existing player's input API.
	var start: Vector2 = world.player.global_position
	var destination: Vector2 = Vector2.INF
	for heading: int in [0,2,4,6]:
		var target: Vector2 = field.cell_to_world(source_cell+field.DIRECTIONS[heading]*8)
		if field.line_clear(start,target): destination = target; break
	check(destination.is_finite(),"entry has an original walking corridor")
	if destination.is_finite():
		world.player.set_touch_vector((destination-start).normalized())
		for frame: int in range(12): await physics_frame
		world.player.set_touch_vector(Vector2.ZERO)
		check(world.player.global_position.distance_to(start) > 2.0,"real player movement")
		check(field.walkable(world.player.global_position),"movement stays on original grid")
	if capture and DisplayServer.get_name() != "headless":
		world.field_renderer.refresh_visible()
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output+"/aden-entry.png") == OK,"entry PNG")
	elif capture:
		check(false,"screenshots require a rendering display; no synthetic substitution")
	check(field.nav_cache.size() <= field.CACHE_LIMIT,"bounded navigation cache")
	finish()

func finish() -> void:
	var report: Dictionary = {"checks":checks,"failures":failures,
		"scope":"actual Main load, topology, spawn sampling and entry movement",
		"not_covered":["NPC service transactions","boss fight and respawn timers","portal transitions","save reload","Android GPU","long distance walking","original S32 art"]}
	var file := FileAccess.open(output+"/runtime.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ADEN_RUNTIME_RESULT ",JSON.stringify(report))
	if is_instance_valid(world): world.queue_free()
	quit(0 if failures.is_empty() else 1)
