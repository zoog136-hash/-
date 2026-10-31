extends SceneTree
const RUNTIME=preload("res://scripts/maps/source_map_runtime.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const MIGRATION=preload("res://scripts/maps/source_map_save_migration.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
var world: TwilightWorld
var checks: int=0
var failures: Array[String]=[]
var mid: String="source_77"
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("MAP84_MAIN_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):mid=arg.trim_prefix("--map=")
	var child: bool="--reload-child" in OS.get_cmdline_user_args()
	world=load("res://Main.tscn").instantiate()
	world.active_map_id=mid
	root.add_child(world)
	world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world),"ordinary Main character entry")
	world.field_population.set_process(false);world.portal_cooldown=10000
	if child:
		check(world.active_map_id==mid and world.gold==123456 and not world.source_save_blocked,"fresh process restores exact local-map identity and progression")
		await finish();return
	await process_frame;await physics_frame
	check(world.active_map_id==mid and bool(world.field_map.get_meta("source_map84",false)),"ordinary world enters actual source field")
	check(world.field_renderer.get_script().resource_path=="res://scripts/maps/source_map_runtime_renderer.gd","ordinary world uses source WebP renderer")
	var ground_below_actor: bool=true
	for ground: Node2D in world.field_renderer.chunks.values():
		if ground.z_index>=world.player.z_index:ground_below_actor=false
	check(ground_below_actor,"all terrain stays behind the actual player even on maps with over thirty chunks")
	check(world.field_map.data.monster_spawn.all(func(r):return r.has("source_key") or r.get("local_habitat",false)),"new source map uses explicit reviewed habitat rows")
	var start: Vector2=world.player.global_position
	check(world.field_map.point_clear(start,4),"real Player starts at verified source point")
	var gate:=Vector2(world.field_map.data.portal[0].position[0],world.field_map.data.portal[0].position[1])
	world._spawn_ground_drop("HP 물약",gate,3)
	check(world.ground_loot.records.size()==1,"actual ground drop created")
	var drop_id: String=str(world.ground_loot.records.keys()[0]) if not world.ground_loot.records.is_empty() else ""
	var tested_door: String=""
	for id: String in world.field_map.local_doors:
		var c: Vector2i=world.field_map.local_doors[id][0]
		if world.field_map.world_to_cell(start)==c:continue
		for h: int in [0,2,4,6]:
			var neighbor: Vector2i=c-world.field_map.DIRECTIONS[h]
			if not world.field_map.source_can_step(neighbor,h):continue
			world.player.global_position=world.field_map.cell_to_world(neighbor)
			world.field_map.set_local_door(id,false)
			await physics_frame;await physics_frame
			var from: Vector2=world.player.global_position
			var to: Vector2=world.field_map.cell_to_world(c)
			check(not world.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,4)).is_empty(),"actual physics ray hits closed local door")
			world.field_map.set_local_door(id,true)
			await physics_frame;await physics_frame
			check(world.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from,to,4)).is_empty(),"actual physics ray crosses opened local door")
			world.player.global_position=start
			tested_door=id;world.field_map.set_local_door(id,false,[start]);break
		if not tested_door.is_empty():break
	world.gold=123456
	check(world._save_game(true)==OK,"actual atomic world save")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved.source_map84_layouts[mid].grid_sha256==RUNTIME.identity(mid).grid_sha256,"save records exact source grid and art identity")
	if not tested_door.is_empty():check(saved.source_map84_doors[mid][tested_door]==false,"saved local door state")
	var save_hash: String=FileAccess.get_sha256(world.save_path())
	world.gold=77;world.player.global_position=gate
	world._load_game(true)
	print("MAP84_RELOAD_DIAGNOSTIC ",JSON.stringify({"blocked":world.source_save_blocked,"gold":world.gold,"start":[start.x,start.y],"restored":[world.player.global_position.x,world.player.global_position.y],"saved_original":saved.get("original_position"),"map_identity_check":RUNTIME.validate_save(saved)}))
	check(not world.source_save_blocked and world.gold==123456 and world.player.global_position.distance_to(start)<.01,"actual save reload restores player, progression and source coordinates")
	if not tested_door.is_empty():check(world.field_map.local_door_states[tested_door]==false,"loaded local door state preserved")
	check(world.ground_loot.records.has(drop_id) and int(world.ground_loot.records[drop_id].quantity)==3,"drop UUID and quantity preserved across actual load")
	check(world.ground_loot.records.has(drop_id) and Vector2(world.ground_loot.records[drop_id].position[0],world.ground_loot.records[drop_id].position[1]).distance_to(gate)<.01,"drop coordinate restored in same verified frame")
	check(FileAccess.get_sha256(world.save_path())==save_hash,"loading alone never rewrites save bytes")
	var pack_path: String=OS.get_environment("TWILIGHT_SOURCE_MAP_PACK")
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",pack_path+"-missing")
	world.gold=88
	world._load_game(true)
	check(world.source_save_blocked and world.gold==88 and world.active_map_id==mid,"missing pack rejects before live character mutation")
	check(world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==save_hash,"missing pack cannot overwrite player save")
	OS.set_environment("TWILIGHT_SOURCE_MAP_PACK",pack_path)
	world._load_game(true)
	var wrong: Dictionary=saved.duplicate(true)
	wrong.source_map84_layouts[mid].layout_revision=1
	check(WRITER.write(world.save_path(),wrong)==OK,"isolated historical revision fixture")
	var wrong_hash: String=FileAccess.get_sha256(world.save_path())
	world.gold=99;world._load_game(true)
	check(world.source_save_blocked and world.gold==99,"unknown revision cannot partially load or erase inventory")
	check(world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==wrong_hash,"unknown revision cannot be overwritten")
	WRITER.write(world.save_path(),saved);world._load_game(true)
	world.field_population.set_process(false);world.portal_cooldown=10000
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			world.field_renderer.refresh_visible()
			await process_frame;await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))==OK,"actual Main OpenGL capture")
	var output: Array=[]
	var child_code: int=OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/source_map_final_main_test.gd","--","--map="+mid,"--reload-child"]),output,true)
	check(child_code==0,"fresh process restarts on local source map")
	for line: Variant in output:print(line)
	check(world.use_field_portal("source%d_verified_return" % int(RUNTIME.policy()[mid].source_map_id)) and world.active_map_id=="aden_world","actual return portal uses existing Aden entry")
	check(world.field_map.point_clear(world.player.global_position),"return destination passes current field collision")
	print("MAP84_MAIN_", "OK" if failures.is_empty() else "FAILED"," map=",mid," checks=",checks)
	await finish()
func finish() -> void:
	world.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
