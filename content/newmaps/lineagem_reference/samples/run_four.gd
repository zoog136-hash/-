extends SceneTree
## PR #121 isolated 4-region 2D proof of concept.
## Opens existing Main.tscn; no alternate 3D scene or NC artwork is used.
const MAPS: Array[String] = ["domination_summit","faith_04","albino_03","escaros_01"]
const BASE: String = "res://content/newmaps/lineagem_reference/samples/evidence/"
var world: TwilightWorld
var failures: Array[String] = []
var checks: Array[String] = []
var capture: bool = false
var visual_shots: int = 0
var moved: bool = false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame

func check(valid: bool,label: String) -> void:
	checks.append(label)
	if not valid:
		failures.append(label)
		printerr("PR121_FOUR_FAIL " + label)

func shot(label: String) -> void:
	if not capture:
		return
	if DisplayServer.get_name() == "headless":
		check(false,"X11 display required for visual screenshot " + label)
		return
	if is_instance_valid(world.player.camera):
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
	if is_instance_valid(world.field_renderer):
		world.field_renderer.refresh_visible()
	await frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var save: Error = image.save_png(BASE+label+".png") if image != null else ERR_CANT_CREATE
	check(save == OK,"real Godot 2D screenshot "+label)
	if save == OK: visual_shots += 1

func find_nearby_clear(field: PlayableField,origin: Vector2) -> Vector2:
	var candidate: Vector2 = origin
	for offset: Vector2i in [Vector2i(5,0),Vector2i(0,5),Vector2i(-5,0),
			Vector2i(0,-5),Vector2i(8,0),Vector2i(0,-8)]:
		var cell: Vector2i = field.world_to_cell(origin)+offset
		var v: Vector2 = field.cell_to_world(cell)
		if field.point_clear(v,24) and field.line_clear(origin,v):
			return v
	return candidate

func _run() -> void:
	if not FileAccess.file_exists(BASE+"build_provenance.json"):
		printerr("PR121_FOUR_BLOCKED Run build_four.py to create isolated copy first")
		quit(2)
		return
	var original_definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"build_provenance.json"))
	if original_definition.get("status","") != "BUILT_NOT_GODOT_VERIFIED":
		printerr("PR121_FOUR_BLOCKED Invalid build provenance")
		quit(2)
		return
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.level = 115
	world.max_hp = 1000000
	world.hp = world.max_hp
	world.rng.seed = 12120261016
	for id: String in MAPS:
		world._on_map_selected(id)
		await frames(8)
		world.hud._close_workspace()
		check(world.active_map_id == id,"existing game enters "+id)
		check(world.field_map is AuthoredRemakeField,"authored streamed 2D field "+id)
		if not world.field_map is AuthoredRemakeField:
			continue
		var field: AuthoredRemakeField = world.field_map
		check(bool(field.data.get("sample_metadata",{}).get("preview_only",false)),
			"strict provisional label "+id)
		check(str(field.data.get("sample_metadata",{}).get("geometry_source","")) ==
			"PR121_SEPARATELY_AUTHORED_PROTOTYPE","non-reused geometry "+id)
		check(not field.navigation_cache_hit,"authored nav recalculated not stale "+id)
		check(str(field.data.get("map_id","")) == id,"map registry ID "+id)
		var entry: Array = field.data.review_points.entrance
		var boss: Array = field.data.review_points.boss
		var entrance := Vector2(float(entry[0]),float(entry[1]))
		var boss_position := Vector2(float(boss[0]),float(boss[1]))
		check(field.point_clear(entrance),"entry accessible "+id)
		check(field.point_clear(boss_position),"boss area accessible "+id)
		var route: PackedVector2Array = field.path(entrance,boss_position)
		check(route.size() >= 2,"AStar entrance-boss route "+id)
		check(field.blockers.size() > 0,"actual collision shapes "+id)
		check(is_instance_valid(field.collision_stream),"streamed Godot physics "+id)
		check(is_instance_valid(world.field_renderer),"main-game 2D renderer "+id)
		if is_instance_valid(field.collision_stream):
			field.collision_stream.refresh()
			check(field.collision_stream.active_shape_count > 0,
				"nearby collision bodies streamed "+id)
		world.portal_cooldown = 9999.0
		if capture:
			world.player.global_position = entrance
			world.player.velocity = Vector2.ZERO
			world.player.clear_click_path()
			await shot(id+"-entry")
			world.player.global_position = boss_position
			world.player.velocity = Vector2.ZERO
			world.player.clear_click_path()
			await shot(id+"-boss")
		# On the first field, test the actual Main world / Player click-follow code.
		if id == MAPS[0]:
			world.player.global_position = entrance
			world.player.velocity = Vector2.ZERO
			world.player.clear_click_path()
			var near: Vector2 = find_nearby_clear(field,entrance)
			check(near != entrance,"short connected click target")
			if near != entrance:
				world._set_click_destination(near)
				await frames(75)
				moved = world.player.global_position.distance_to(entrance)>12
				check(moved,"existing player physically moved after click")
		print("PR121_FOUR_MAP",id," route_points=",route.size()," collisions=",field.blockers.size(),
			" props=",field.data.props.size())
	check(MAPS.size()==4 and MAPS.has("faith_04") and not MAPS.has("albino_04"),
		"four intended maps and retained Faith 4F")
	if capture:
		check(visual_shots==8,"eight actual engine PNGs")
	_finish()

func _finish() -> void:
	var report: Dictionary = {
		"status":"PASS" if failures.is_empty() else "FAIL",
		"checks":checks,"failures":failures,
		"map_ids":MAPS,"main_scene":"res://Main.tscn",
		"renderer":"Godot 4.7.2 existing TWILIGHT streamed authored 2D",
		"actual_2d_captures":visual_shots,
		"capture_mode":capture,"display_server":DisplayServer.get_name(),
		"source_geometry":"new separately authored PR121 test layout",
		"original_lineagem_geometry":"NOT_RECOVERED",
		"original_boss_placement":"NOT_VERIFIED",
		"original_lineagem_graphics":"NOT_DISTRIBUTED",
		"android":"NOT_RUN","main_modified":false}
	var file: FileAccess = FileAccess.open(BASE+"runtime_results.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("PR121_FOUR_RESULTS "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
