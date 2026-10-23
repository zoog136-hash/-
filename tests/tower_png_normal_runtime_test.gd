extends SceneTree
## Real Main, ordinary save namespace, source bodies and actual PNG textures.
const QA=preload("res://tests/qa_class_selection.gd")
const PNG=preload("res://scripts/maps/native_png_registry.gd")
const OMAN=preload("res://scripts/maps/source_png_game_registry.gd")
const CATALOG=preload("res://scripts/monsters/monster_catalog.gd")
var world: TwilightWorld
var checks: int=0
var failures: Array[String]=[]
var records: Array=[]
var selected: PackedStringArray=[]
var output: String="user://tower-png-evidence"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("TOWER_PNG_FAIL ",label)
func ticks(n: int) -> void:
	for i: int in range(n):await physics_frame
func pause() -> void:
	world.portal_cooldown=10000;world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
func place(p: Vector2) -> void:
	world.player.clear_click_path();world.player.set_touch_vector(Vector2.ZERO)
	world.player.global_position=p;world.player.velocity=Vector2.ZERO
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	if world.field_map is RemakePlayableField:world.field_map.collision_stream.refresh()
	world.field_renderer.refresh_visible()
func physics_edge(a: Vector2,b: Vector2,label: String,mob: TwilightMonster) -> void:
	place(a)
	if mob!=null:mob.global_position=a;mob.velocity=Vector2.ZERO
	await ticks(3)
	check(world.player.test_move(world.player.global_transform,b-a),label+" actual player body blocked")
	check(not world.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(a,b,4)).is_empty(),label+" actual physics ray")
	if mob!=null:check(mob.test_move(mob.global_transform,b-a),label+" actual monster body blocked")
	world.player.set_touch_vector((b-a).normalized())
	for i: int in range(15):
		await physics_frame
		if mob!=null:mob.velocity=(b-a).normalized()*210;mob._move_on_map()
	world.player.set_touch_vector(Vector2.ZERO)
	print("EDGE_END ",label," actor=",world.player.global_position," walkable=",world.field_map.walkable(world.player.global_position))
	check(world.field_map.point_clear(world.player.global_position,3.9),label+" player remains on floor")
	if mob!=null:check(world.field_map.point_clear(mob.global_position,3.9),label+" monster remains on floor")
func inspect(mid: String) -> void:
	print("TOWER_STAGE ",mid)
	world._set_map(mid,false);pause()
	check(world.active_map_id==mid,mid+" ordinary map entry")
	if world.active_map_id!=mid:return
	var field: PlayableField=world.field_map
	var spawn: Vector2=world.player.global_position
	var mob: TwilightMonster
	for actor: Node in world.monsters_root.get_children():
		if actor is TwilightMonster and not actor.dead:mob=actor;break
	check(mob!=null,mid+" existing live population")
	check(world.player.scale==Vector2.ONE and world.player.move_speed==210,mid+" existing actor size and speed")
	check(world.player.get_node("CollisionShape2D").shape is CircleShape2D and world.player.get_node("CollisionShape2D").shape.radius==4,mid+" actual foot radius")
	world.player.camera.position_smoothing_enabled=false
	var edge_records: Array=[]
	if field is RemakePlayableField:
		check(field.png_game_pack!=null and field.png_game_pack.ordinary_active and not world.field_renderer.png_review_active,mid+" ordinary PNG attached without review mode")
		var meshes: int=0
		for chunk: Node in world.field_renderer.chunks.values():
			if chunk.has_meta("source_png"):meshes+=1
		check(meshes>0,mid+" actual source PNG meshes")
		for heading: int in [0,2,4,6]:
			var a:=Vector2.INF;var b:=Vector2.INF
			var focus: Vector2i=field.world_to_cell(spawn)
			for y: int in range(-18,19):
				for x: int in range(-18,19):
					var cell: Vector2i=focus+Vector2i(x,y);var p: Vector2=field.cell_to_world(cell)
					if field.point_clear(p) and not field.source_can_step(cell,heading) and (not a.is_finite() or p.distance_squared_to(spawn)<a.distance_squared_to(spawn)):
						a=p;b=field.cell_to_world(cell+field.DIRECTIONS[heading])
			check(a.is_finite(),mid+" source forbidden edge "+str(heading))
			if a.is_finite():await physics_edge(a,b,mid+" source edge "+str(heading),mob);edge_records.append([a.x,a.y,b.x,b.y])
	else:
		check(field is NativePngField and field.png_manifest.source_sha256=="f5c4549298e586d3839246d736b61b6106851af07cde8c5a21522d046ff38f87",mid+" selected 111.png, not 12862")
		check(await world.field_renderer.settle_visible(),mid+" actual chunks settled")
		var original: Dictionary=CATALOG.apply_map(PNG.read_json("res://data/maps/domination_summit.json"))
		for zone: Dictionary in field.data.monster_spawn:
			var prior: Dictionary=original.monster_spawn.filter(func(z: Dictionary)->bool:return z.id==zone.id)[0]
			for key: String in ["max_count","monster_types","variants","level","mode","respawn_time"]:
				check(zone.get(key)==prior.get(key),mid+" retains catalog "+str(zone.id)+" "+key)
			check(not field.spawn_cells.get(str(zone.id),[]).is_empty(),mid+" body-clear candidates "+str(zone.id))
		check(field.data.npc_spawn.size()==1 and field.data.portal.size()==5,mid+" guide and travel preserved")
		# The reviewed crystal foot has real solid geometry from every approach.
		var center:=Vector2(8342,3648)
		for direction: Vector2 in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			var a: Vector2=field.cell_to_world(field.nearest_cell(center+direction*88))
			check(a.distance_to(center)<160,mid+" local crystal approach")
			await physics_edge(a,center,mid+" crystal "+str(direction),mob);edge_records.append([a.x,a.y,center.x,center.y])
		for raw: Array in field.data.route_checks:check(not field.path(spawn,Vector2(raw[0],raw[1])).is_empty(),mid+" reviewed route "+str(raw))
	place(spawn);await ticks(3)
	var target: Vector2=field.cell_to_world(field.nearest_cell(spawn+Vector2(-85 if mid=="domination_summit" else 85,0)))
	world._set_click_destination(target)
	print("PATH_PROBE ",mid," start=",world.player.global_position," target=",target," path=",field.path(world.player.global_position,target)," click=",world.player.click_path)
	check(not world.player.click_path.is_empty(),mid+" production click path")
	await ticks(45)
	check(world.player.global_position.distance_to(target)<16,mid+" actual click movement arrives")
	world.player.clear_click_path();world.player.pulse_attack();check(world.player.motion.active,mid+" attack animation");await ticks(55)
	var transform: Dictionary=world._job_transform_record(world.job_class);world._apply_transform_visual(transform)
	check(world.player.transform_active and world.player.transform_sprite.visible,mid+" transformation retained")
	world.player.pulse_attack();await ticks(55);check(not world.player.motion.active,mid+" transformed attack completes")
	world._restore_equipped_visuals()
	check(world.hud.visible and world.player.camera.enabled,mid+" HUD and camera")
	place(spawn);await ticks(3)
	if world.field_renderer is NativePngRenderer:await world.field_renderer.settle_visible()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+mid+".png")==OK,mid+" actual screen capture")
	world._save_game(true);var saved: Vector2=world.player.global_position
	check(world.save_path()==world.SAVE_PATH,mid+" ordinary save namespace")
	world._set_map("aden_world",false);world._load_game(true);pause()
	check(not world.source_save_blocked and world.active_map_id==mid and world.player.global_position.distance_to(saved)<16,mid+" ordinary save reload")
	records.append({"map":mid,"edges":edge_records,"whole_map_correspondence":"REVIEW_REQUIRED"})
func run() -> void:
	if not OMAN.requested("oman_01") or not PNG.domination_installed() or DisplayServer.get_name()=="headless":
		print("TOWER_PNG_SKIP: real installed PNGs and OpenGL required; no runtime claim");quit();return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--maps="):selected=arg.trim_prefix("--maps=").split(",")
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720)
	check(not "--png-review" in OS.get_cmdline_user_args(),"ordinary launch")
	world=load("res://Main.tscn").instantiate();root.add_child(world);check(QA.enter_game(world),"real Main entry")
	world.set_process(false);world.save_timer=-100000
	if selected.is_empty():
		for floor: int in range(1,11):selected.append("oman_%02d"%floor)
		selected.append("domination_summit")
	for mid: String in selected:await inspect(mid)
	# A saved ordinary Oman map must never silently lose its PNG after restart
	# or partially mutate the live character when an installation is damaged.
	world._set_map("oman_01",false);pause();world.gold=876543;world._save_game(true)
	var saved_hash: String=FileAccess.get_sha256(world.save_path())
	var live_field: PlayableField=world.field_map
	var original_path: String=OS.get_environment("TWILIGHT_OMAN_PNG_PACK")
	OS.set_environment("TWILIGHT_OMAN_PNG_PACK",output+"/missing-pack")
	world.pending_attack={"id":999,"probe":true};var generation: int=world.combat_generation
	world._set_map("oman_02",false)
	check(world.field_map==live_field and world.active_map_id=="oman_01" and world.combat_generation==generation and world.pending_attack.get("id")==999,"damaged Oman pack preserves live map and combat")
	world._load_game(true)
	check(world.source_save_blocked and world.gold==876543 and world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==saved_hash,"missing saved Oman PNG blocks overwriting original save")
	OS.set_environment("TWILIGHT_OMAN_PNG_PACK",original_path);world._load_game(true)
	check(not world.source_save_blocked and world.active_map_id=="oman_01" and world.gold==876543,"restored Oman PNG resumes ordinary save")
	var report: Dictionary={"checks":checks,"failures":failures,"maps":records,"engine":Engine.get_version_info().string,"android_device":"NOT_RUN"}
	var file:=FileAccess.open(output+"/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TOWER_PNG_RESULT ",JSON.stringify(report));world.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
