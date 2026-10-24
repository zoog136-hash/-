extends SceneTree
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_ADEN_FAITH_PNG_PACK
## Real Main, decoded source chunks, CharacterBody2D, collision and save travel.
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var checks: int=0
var failures: Array[String]=[]
var records: Array=[]
var output: String
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("ADEN_FAITH_FAIL: "+label)
func ticks(n: int) -> void:
	for i: int in range(n): await physics_frame
func pause_population_for_routes() -> void:
	# This suite measures player physics/rendering/save routes. The separate
	# aden_faith_png_monster_spawns_test runs live AI, combat and respawns.
	if is_instance_valid(world.field_population): world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children():
		monster.set_process(false);monster.set_physics_process(false)
func inspect(mid: String, spec: Dictionary) -> void:
	world._set_map(mid,false);world.portal_cooldown=10000
	pause_population_for_routes()
	check(world.active_map_id==mid and world.field_map is NativePngField,mid+" actual PNG field")
	if not world.field_map is NativePngField: return
	var field: NativePngField=world.field_map
	var renderer: NativePngRenderer=world.field_renderer
	world.player.camera.position_smoothing_enabled=false
	check(await renderer.settle_visible(),mid+" all visible real chunks ready")
	check(field.png_manifest.source_sha256==REGISTRY.plan().sources[spec.file].sha256,mid+" actual source SHA identity")
	check(not field.data.monster_spawn.is_empty(),mid+" actual local monster encounters installed")
	check(field.data.monster_spawn.all(func(row: Dictionary) -> bool: return row.get("coordinate_evidence","")=="reviewed_png_walk_polygons_local_unverified_original_positions"),mid+" local placement provenance retained")
	check(field.walkable(world.player.global_position),mid+" entry on inspected floor")
	var walked: float=0
	for raw: Array in field.data.route_checks:
		var target:=Vector2(raw[0],raw[1])
		var path: PackedVector2Array=field.path(world.player.global_position,target)
		check(field.walkable(target) and not path.is_empty(),mid+" inspected route reachable "+str(raw))
		if path.is_empty(): continue
		var start: Vector2=world.player.global_position
		var length: float=0
		var last: Vector2=start
		for point: Vector2 in path: length+=last.distance_to(point);last=point
		world._set_click_destination(target)
		var arrived: bool=false
		for i: int in range(ceili(length/210.0*120.0)+120):
			await physics_frame
			if world.player.global_position.distance_to(target)<12: arrived=true;break
		check(arrived,mid+" actual body reaches "+str(raw))
		if not arrived: printerr("ADEN_FAITH_STUCK ",mid," at=",world.player.global_position," target=",target)
		walked+=length;world.player.clear_click_path()
	for raw: Array in field.data.blocked_probes:
		check(not field.walkable(Vector2(raw[0],raw[1])),mid+" inspected wall/water/hole solid "+str(raw))
	# Ray and actual CharacterBody collision agree at each hall boundary.
	var spawn:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
	world.player.global_position=spawn;world.player.velocity=Vector2.ZERO
	for direction: Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var cell: Vector2i=field.world_to_cell(spawn)
		var next: Vector2i=cell+direction
		while field.astar.is_in_boundsv(next) and not field.astar.is_point_solid(next): cell=next;next+=direction
		var a: Vector2=field.cell_to_world(cell);var b: Vector2=field.cell_to_world(next)
		world.player.global_position=a;await ticks(2)
		check(world.player.test_move(world.player.global_transform,b-a),mid+" body blocked by actual floor boundary "+str(direction))
		check(not world.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(a,b,4)).is_empty(),mid+" actual physics ray blocks "+str(direction))
	world.player.global_position=spawn
	for zoom: float in [.55,1.0,1.4]:
		world.player.camera.zoom=Vector2.ONE*zoom;world.player.camera.force_update_scroll()
		check(await renderer.settle_visible(),mid+" actual zoom view has no missing PNGs "+str(zoom))
		check(renderer.decoded_pixels<=renderer.MAX_VISIBLE_PIXELS,mid+" bounded live textures")
	world.player.camera.zoom=Vector2.ONE;world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	check(await renderer.settle_visible(),mid+" final actual PNG view ready")
	await ticks(3);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+mid+".png")==OK,mid+" actual Main screenshot")
	world._save_game(true)
	var before: Vector2=world.player.global_position
	var alternate: String="faith_01" if mid=="aden_world" else "aden_world"
	world._set_map(alternate,false);world._load_game(true)
	pause_population_for_routes()
	check(world.active_map_id==mid and world.field_map is NativePngField,mid+" save restores native field")
	check(world.player.global_position.distance_to(before)<16,mid+" saved source pixel coordinates restored")
	for portal: Dictionary in field.data.portal:
		check(field.walkable(Vector2(portal.position[0],portal.position[1])),mid+" portal stands on reviewed floor: "+str(portal.id))
		check(world.use_field_portal(str(portal.id)) and world.active_map_id==str(portal.target_map),mid+" actual portal loads target: "+str(portal.id))
		world._set_map(mid,false)
		pause_population_for_routes()
	# A real move into the return portal must trigger ordinary world travel.
	if mid!="aden_world":
		world.portal_cooldown=0;world.set_process(true)
		var dest: Array=spec.portals[0].position
		world._set_click_destination(Vector2(dest[0],dest[1]));await ticks(90)
		world.set_process(false)
		check(world.active_map_id=="aden_world",mid+" walking into portal returns to actual Aden")
	records.append({"map":mid,"source_sha256":field.png_manifest.source_sha256,"walked_path_pixels":walked,"full_map_collision_verified":false})
func run() -> void:
	if not REGISTRY.extra_installed() or DisplayServer.get_name()=="headless":
		print("ADEN_FAITH_SKIP: real private PNG pack and OpenGL required; no PNG runtime claim");quit();return
	output=OS.get_environment("TWILIGHT_ADEN_FAITH_TEST_OUTPUT")
	if output.is_empty(): output="user://aden-faith-evidence"
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"actual Main class entry")
	world.set_process(false);world.save_timer=-100000
	var db_hash: String=FileAccess.get_sha256("res://data/game_db_v17.json")
	var historical: Dictionary={}
	for mid: String in ["faith_01","faith_02","faith_03","faith_04"]: historical[mid]=FileAccess.get_sha256("res://data/maps/"+mid+".json")
	var specs: Dictionary=REGISTRY.read_json(REGISTRY.EXTRA_PLAN_PATH).maps
	for mid: String in specs: await inspect(mid,specs[mid])
	for mid: String in historical: check(FileAccess.get_sha256("res://data/maps/"+mid+".json")==historical[mid],mid+" legacy population/portals remain byte identical")
	check(FileAccess.get_sha256("res://data/game_db_v17.json")==db_hash,"all monster/boss/reward/balance DB bytes retained")
	world._set_map("faith_02",false);world._save_game(true)
	var save_hash: String=FileAccess.get_sha256(world.save_path())
	var installed: String=OS.get_environment("TWILIGHT_ADEN_FAITH_PNG_PACK")
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",output+"/missing-pack")
	world._set_map("faith_03",false)
	check(world.active_map_id=="faith_02","missing new pack preserves current field")
	world._load_game(true);world._save_game(true)
	check(world.source_save_blocked and FileAccess.get_sha256(world.save_path())==save_hash,"missing new pack cannot overwrite character save")
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",installed)
	world._load_game(true)
	check(world.active_map_id=="faith_02" and not world.source_save_blocked,"restored explicit pack resumes saved native field")
	# The normal Android/user installation has no environment override. Once
	# entered, a corrupt/removed default pack must retain its native identity.
	if not FileAccess.file_exists(REGISTRY.BUNDLED_EXTRA_ROOT+"/index.json"):
		var default_root: String=ProjectSettings.globalize_path("user://aden_faith_png_maps")
		check(not DirAccess.dir_exists_absolute(default_root),"default-root corruption fixture is isolated from installed user data")
		DirAccess.make_dir_recursive_absolute(default_root)
		var bad:=FileAccess.open(default_root+"/index.json",FileAccess.WRITE)
		bad.store_string("corrupt negative-test index");bad.close()
		OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK","")
		world._set_map("faith_03",false)
		check(world.active_map_id=="faith_02" and world.field_map is NativePngField,"corrupt default index cannot substitute legacy geometry")
		world._load_game(true);world._save_game(true)
		check(world.source_save_blocked and FileAccess.get_sha256(world.save_path())==save_hash,"corrupt default pack preserves saved character bytes")
		DirAccess.remove_absolute(default_root+"/index.json");DirAccess.remove_absolute(default_root)
		world._set_map("faith_04",false)
		check(world.active_map_id=="faith_02","removed default directory preserves current native world")
		OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",installed);world._load_game(true)
		check(world.active_map_id=="faith_02" and not world.source_save_blocked,"reinstalled pack resumes after default-root removal")
	var report: Dictionary={"checks":checks,"failures":failures,"maps":records,"actual_main_png":true,"android_device":"NOT_RUN"}
	var file:=FileAccess.open(output+"/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ADEN_FAITH_RESULT ",JSON.stringify(report))
	world.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
