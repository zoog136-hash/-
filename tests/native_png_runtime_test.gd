extends SceneTree
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_NATIVE_PNG_PACK
## This suite only passes with real decoded private PNGs in the actual Main.
## Real Main walking over the traced routes; unmapped gameplay stays incomplete.
const REGISTRY = preload("res://scripts/maps/native_png_registry.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var failures: Array[String] = []
var checks: int = 0
var records: Array[Dictionary] = []
var output: String
var walked_distance: float = 0.0

class DepthProbe extends Node2D:
	func _draw() -> void: draw_rect(Rect2(-12,-70,24,70),Color.MAGENTA)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("NATIVE_PNG_RUNTIME_FAIL: "+label)
func ticks(count: int) -> void:
	for i: int in range(count): await physics_frame

func traverse(field: NativePngField, mid: String) -> float:
	var distance: float=0.0
	for raw: Array in REGISTRY.plan().maps[mid].route_checks:
		var target:=Vector2(raw[0],raw[1])
		var path: PackedVector2Array=field.path(world.player.global_position,target)
		check(field.walkable(target) and not path.is_empty(),mid+" traced route reachable "+str(raw))
		if path.is_empty(): continue
		var length: float=0.0
		var last: Vector2=world.player.global_position
		for point: Vector2 in path: length+=last.distance_to(point);last=point
		world._set_click_destination(target)
		var budget: int=ceili(length/210.0*60.0)*2+120
		var arrived: bool=false
		for i: int in range(budget):
			await physics_frame
			if world.player.global_position.distance_to(target)<12: arrived=true;break
		check(arrived,mid+" actual player traversed "+str(raw))
		if not arrived:
			printerr("NATIVE_PNG_STUCK ",mid," target=",target," at=",world.player.global_position)
			break
		distance+=length
		world.player.clear_click_path()
	for raw: Array in REGISTRY.plan().maps[mid].blocked_probes:
		check(not field.walkable(Vector2(raw[0],raw[1])),mid+" inspected water/wall/object excluded "+str(raw))
	return distance

func inspect_foreground(renderer: NativePngRenderer, field: NativePngField) -> void:
	for row: Dictionary in field.png_manifest.get("foreground",[]):
		var foot:=Vector2(row.foot_image[0],row.foot_image[1])
		world.player.global_position=foot+Vector2(200,0)
		world.player.clear_click_path();world.player.velocity=Vector2.ZERO
		world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		# Staged decoding is a frame-budget policy, not missing source pixels.
		for _load_pass: int in range(32): renderer.refresh_visible()
		var probe:=DepthProbe.new();probe.position=foot-Vector2(0,10);world.add_child(probe)
		await ticks(3);await RenderingServer.frame_post_draw
		var target:=foot-Vector2(0,40)
		var screen: Vector2=world.get_global_transform_with_canvas()*target
		var behind: Color=root.get_texture().get_image().get_pixelv(Vector2i(screen))
		var original:=Image.load_from_file(field.png_root+"/"+str(row.file))
		var expected: Color=original.get_pixel(int(target.x-row.position[0]),int(target.y-row.position[1]))
		check(behind.is_equal_approx(expected),"real source foreground covers the actor behind its foot")
		probe.position=foot+Vector2(0,20)
		await ticks(3);await RenderingServer.frame_post_draw
		var front: Color=root.get_texture().get_image().get_pixelv(Vector2i(screen))
		check(front.r>.95 and front.b>.95 and front.g<.05,"actor in front covers the source foreground")
		probe.free()

func inspect(mid: String) -> void:
	world._set_map(mid,false)
	world.portal_cooldown=10000
	check(world.active_map_id==mid and world.field_map is NativePngField,mid+" actual native field selected")
	if not world.field_map is NativePngField: return
	var field: NativePngField=world.field_map
	var renderer: NativePngRenderer=world.field_renderer
	await ticks(3)
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll();renderer.refresh_visible()
	check(renderer.chunks.size()>0,mid+" real PNG textures loaded")
	check(renderer.get_node_or_null("Terrain")==null,mid+" original PNG is the sole terrain renderer")
	for sprite: Sprite2D in renderer.chunks.values():
		check(sprite.texture is ImageTexture and maxi(sprite.texture.get_width(),sprite.texture.get_height())<=1024,mid+" decoded bounded original chunk")
	var spawn: Vector2=world.player.global_position
	check(field.walkable(spawn) and field.point_clear(spawn,4),mid+" inspected ground entry")
	check(world.player.scale==Vector2.ONE and world.player.move_speed==210,mid+" actor scale, animations and movement speed retained")
	check(not field.data.monster_spawn.is_empty() and world.field_population.slots.size()>0,mid+" actual PNG encounter slots are created")
	for zone: Dictionary in field.data.monster_spawn:
		var candidates: Array=field.spawn_cells.get(str(zone.id),[])
		check(not candidates.is_empty(),mid+" has reachable encounter cells "+str(zone.id))
		if candidates.is_empty(): continue
		var candidate: Vector2=field.cell_to_world(candidates[0])
		check(field.walkable(candidate) and field.point_clear(candidate,12) and field.spawn_contains(zone,candidate),mid+" post-alpha candidate remains physically valid "+str(zone.id))
	# This suite exercises route/physics fidelity rather than combat; combat
	# remains live in the dedicated population and player test suites.
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	var target: Vector2=spawn+Vector2(32,0)
	check(field.line_clear(spawn,target),mid+" actual ground segment is walkable")
	world._set_click_destination(target)
	await ticks(24)
	check(world.player.global_position.distance_to(spawn)>16 and field.walkable(world.player.global_position),mid+" real player click movement")
	world.player.clear_click_path()
	# Probe actual static shapes at all four sides of the reviewed floor patch.
	var found: int=0
	for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var cell: Vector2i=field.world_to_cell(spawn)
		var next: Vector2i=cell+direction
		while field.astar.is_in_boundsv(next) and not field.astar.is_point_solid(next):
			cell=next;next+=direction
		var start: Vector2=field.cell_to_world(cell)
		var end: Vector2=field.cell_to_world(next)
		world.player.global_position=start;world.player.velocity=Vector2.ZERO
		await ticks(2)
		var ray:=PhysicsRayQueryParameters2D.create(start,end,4)
		check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),mid+" physical reviewed-scope boundary "+str(direction))
		check(world.player.test_move(world.player.global_transform,end-start),mid+" real body stops at reviewed-scope boundary "+str(direction))
		world.player.set_touch_vector(Vector2(direction))
		await ticks(14)
		world.player.set_touch_vector(Vector2.ZERO)
		check(field.walkable(world.player.global_position),mid+" manual input cannot escape reviewed ground "+str(direction))
		found+=1
	world.player.global_position=spawn;world.player.velocity=Vector2.ZERO
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	for zoom: float in [1.0,.6,1.4]:
		world.player.camera.zoom=Vector2.ONE*zoom
		world.player.camera.force_update_scroll();renderer.refresh_visible();await ticks(2)
		check(renderer.decoded_pixels<=renderer.MAX_VISIBLE_PIXELS,mid+" bounded live image memory at zoom "+str(zoom))
	world.player.camera.zoom=Vector2.ONE
	world.player.camera.force_update_scroll();renderer.refresh_visible()
	var previous_chunks: Array=renderer.chunks.keys()
	world.player.camera.offset=Vector2(1600,0)
	world.player.camera.force_update_scroll();renderer.refresh_visible();await ticks(2)
	check(renderer.chunks.keys()!=previous_chunks and renderer.chunks.size()>0,mid+" camera pan loads distant native chunks and releases previous textures")
	world.player.camera.offset=Vector2.ZERO
	world.player.camera.force_update_scroll();renderer.refresh_visible()
	check(DisplayServer.get_name()!="headless",mid+" actual OpenGL display")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output+"/"+mid+".png")==OK,mid+" real Main screenshot")
	world.player.pulse_attack();check(world.player.motion.active,mid+" existing attack playback")
	await ticks(55)
	var traversed: float=await traverse(field,mid)
	walked_distance+=traversed
	if not field.png_manifest.get("foreground",[]).is_empty(): await inspect_foreground(renderer,field)
	world.player.global_position=spawn;world.player.velocity=Vector2.ZERO;world.player.clear_click_path()
	var loaded_chunks: int=renderer.chunks.size()
	var peak_bytes: int=renderer.peak_decoded_pixels*4
	world._save_game(true)
	check(world.save_path()=="user://twilight_native_png_save.json",mid+" separate save path")
	world._set_map("aden_world",false)
	world._load_game(true)
	check(world.active_map_id==mid and world.field_map is NativePngField,mid+" actual save and reentry")
	check(world.player.global_position.distance_to(spawn)<16,mid+" saved pixel position restored")
	world.player.global_position=spawn;world.portal_cooldown=0;world.set_process(true)
	world._set_click_destination(spawn-Vector2(60,0))
	await ticks(45)
	world.set_process(false)
	check(world.active_map_id=="aden_world",mid+" walking into real return portal loads existing Aden")
	records.append({"map_id":mid,"png_sha256":field.png_manifest.source_sha256,"loaded_chunks":loaded_chunks,"peak_rgba_bytes":peak_bytes,"collision_sides":found,"walked_path_pixels":traversed,"route_targets":REGISTRY.plan().maps[mid].route_checks.size(),"playable_scope":"MANUALLY_TRACED_FLOORS_AND_ROUTES","full_map_verified":false,"monster_spawn":"NOT_MAPPED"})

func run() -> void:
	if not REGISTRY.enabled() or OS.get_environment("TWILIGHT_NATIVE_PNG_PACK").is_empty():
		print("NATIVE_PNG_RUNTIME_SKIP: real private pack and --native-png-maps required; no PNG integration claimed");quit();return
	output=OS.get_environment("TWILIGHT_NATIVE_TEST_OUTPUT")
	if output.is_empty(): output="user://native-png-evidence"
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"actual class selection")
	world.set_process(false);world.save_timer=-100000
	var baseline: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps_v18.json"))
	for row: Dictionary in baseline: check(world.maps_by_id.has(str(row.id)),"legacy persistent ID preserved: "+str(row.id))
	check(world.maps.size()==baseline.size()+3,"25 existing IDs plus continuous Escaros and two independent temples")
	check(REGISTRY.menu_entries(world.maps).size()==22,"native menu has three Albino zones, one Escaros and two temples")
	var normal_path: String="user://twilight_v20_save.json"
	var sentinel:=FileAccess.open(normal_path,FileAccess.WRITE);sentinel.store_string("normal-save-preservation-sentinel");sentinel.close()
	var normal_hash: String=FileAccess.get_sha256(normal_path)
	var db_hash: String=FileAccess.get_sha256("res://data/game_db_v17.json")
	for mid: String in REGISTRY.plan().maps: await inspect(mid)
	for alias: String in ["escaros_01","escaros_02","escaros_03","escaros_04","escaros_05"]:
		world._set_map(alias,false);check(world.active_map_id=="escaros_world",alias+" shares one continuous field")
	world._set_map("albino_04",false);check(world.active_map_id=="albino_03","legacy fourth zone has safe native-session route")
	world._set_map("albino_01",false)
	check(world.use_field_portal("next") and world.active_map_id=="albino_02","Albino first-to-second portal")
	check(world.use_field_portal("next") and world.active_map_id=="albino_03","Albino second-to-third portal")
	world._save_game(true)
	var saved_hash: String=FileAccess.get_sha256(world.save_path())
	var installed: String=OS.get_environment("TWILIGHT_NATIVE_PNG_PACK")
	OS.set_environment("TWILIGHT_NATIVE_PNG_PACK",output+"/missing-pack")
	var active: String=world.active_map_id
	world._set_map("balrog_temple",false)
	check(world.active_map_id==active,"missing original pack preserves live world")
	world._load_game(true);world._save_game(true)
	check(world.source_save_blocked and FileAccess.get_sha256(world.save_path())==saved_hash,"missing pack preserves saved pixels and progress")
	OS.set_environment("TWILIGHT_NATIVE_PNG_PACK",installed)
	check(FileAccess.get_sha256(normal_path)==normal_hash,"normal player save remains byte-identical")
	check(FileAccess.get_sha256("res://data/game_db_v17.json")==db_hash,"monster, boss, rewards and balance DB unchanged")
	var report: Dictionary={"checks":checks,"failures":failures,"maps":records,"walked_path_pixels":walked_distance,"original_png_rendered":true,"production_complete":false,"android_device":"NOT_RUN"}
	var file:=FileAccess.open(output+"/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("NATIVE_PNG_RUNTIME_RESULT ",JSON.stringify(report))
	world.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
