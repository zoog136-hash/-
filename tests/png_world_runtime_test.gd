extends SceneTree
## Actual Main, actual original PNGs, actual actor bodies and source navigation.
## This is a coordinate REVIEW test, not a claim that PNG obstacles all match.
const QA = preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var checks: int = 0
var failures: Array[String] = []
var maps: Array[Dictionary] = []
var output: String = "user://png-world-review"
var selected: PackedStringArray = []
var capture: bool = false
var mobile: bool = false
var transform_check: bool = false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("PNG_WORLD_FAIL ",label)
func ticks(count: int) -> void:
	for i: int in range(count): await physics_frame

func place(field: RemakePlayableField, point: Vector2) -> void:
	world.player.clear_click_path();world.player.set_touch_vector(Vector2.ZERO)
	world.player.global_position = point;world.player.velocity = Vector2.ZERO
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	field.collision_stream.refresh();world.field_renderer.refresh_visible()

func picture(id: String) -> void:
	if not capture: return
	check(DisplayServer.get_name() != "headless",id+" actual OpenGL renderer")
	if DisplayServer.get_name() == "headless": return
	await ticks(3);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+id+".png") == OK,id+" actual PNG screenshot")
	if mobile:
		root.size = Vector2i(1560,720);DisplayServer.window_set_size(root.size);DisplayServer.window_set_position(Vector2i.ZERO)
		await ticks(6);await RenderingServer.frame_post_draw
		var screen: Image = DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
		var rect := Rect2i(DisplayServer.window_get_position(),DisplayServer.window_get_size())
		check(screen != null and Rect2i(Vector2i.ZERO,screen.get_size()).encloses(rect),id+" native mobile window fits screen")
		if screen != null and Rect2i(Vector2i.ZERO,screen.get_size()).encloses(rect):
			check(screen.get_region(rect).save_png(output+"/"+id+"-mobile-1560x720.png") == OK,id+" native mobile screenshot")
		root.size = Vector2i(1280,720);DisplayServer.window_set_size(root.size);await ticks(6)

func inspect_map(id: String) -> void:
	world._set_map(id,false);world.portal_cooldown = 10000
	check(world.active_map_id == id and world.field_map is RemakePlayableField,id+" source field connected")
	if not world.field_map is RemakePlayableField: return
	var field: RemakePlayableField = world.field_map
	world.field_population.set_process(false)
	var mob: TwilightMonster
	for actor: Node in world.monsters_root.get_children():
		actor.set_physics_process(false)
		if mob == null and actor is TwilightMonster and not actor.dead: mob = actor
	check(world.field_renderer.png_review_active,id+" original PNG pack active")
	check(world.player.scale == Vector2.ONE and world.player.move_speed == 210,id+" existing actor scale and speed")
	check(world.player.get_node("CollisionShape2D").shape is CircleShape2D and world.player.get_node("CollisionShape2D").shape.radius == 4,id+" actual 4px foot")
	var png_count: int = 0
	for chunk: Node in world.field_renderer.chunks.values():
		if chunk.has_meta("source_png"): png_count += 1
	check(png_count > 0,id+" original PNG meshes present in production renderer")
	var spawn: Vector2 = world.player.global_position
	check(field.point_clear(spawn),id+" source spawn valid")
	await picture(id)
	print("PNG_WORLD_STAGE ",id," original_png_chunks=",png_count)
	var approaches: Array = []
	for heading: int in [0,2,4,6]:
		var start: Vector2 = Vector2.INF
		var end: Vector2 = Vector2.INF
		var focus: Vector2i = field.world_to_cell(spawn)
		for dy: int in range(-18,19):
			for dx: int in range(-18,19):
				var cell: Vector2i = focus+Vector2i(dx,dy)
				var p: Vector2 = field.cell_to_world(cell)
				if field.point_clear(p) and not field.can_step(cell,heading):
					if not start.is_finite() or spawn.distance_squared_to(p) < spawn.distance_squared_to(start):
						start = p;end = field.cell_to_world(cell+field.DIRECTIONS[heading])
		check(start.is_finite(),id+" original edge approach "+str(heading))
		if not start.is_finite(): continue
		place(field,start)
		if mob != null: mob.global_position = start;mob.velocity = Vector2.ZERO
		await ticks(3)
		var ray := PhysicsRayQueryParameters2D.create(start,end,4)
		check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),id+" actual physics ray "+str(heading))
		check(world.player.test_move(world.player.global_transform,end-start),id+" actual player body blocked "+str(heading))
		if mob != null: check(mob.test_move(mob.global_transform,end-start),id+" actual monster body blocked "+str(heading))
		world.player.set_touch_vector((end-start).normalized())
		var clear: bool = true
		for frame: int in range(16):
			await physics_frame
			if mob != null:
				mob.velocity = (end-start).normalized()*210;mob._move_on_map()
			clear = clear and field.point_clear(world.player.global_position) and (mob == null or field.point_clear(mob.global_position))
		world.player.set_touch_vector(Vector2.ZERO)
		check(clear,id+" player and monster cannot push through source edge "+str(heading))
		approaches.append({"heading":heading,"from":[start.x,start.y],"to":[end.x,end.y],"clear":clear})
	place(field,spawn)
	var destination: Vector2 = spawn
	for heading: int in [0,2,4,6]:
		var candidate: Vector2 = field.cell_to_world(field.world_to_cell(spawn)+field.DIRECTIONS[heading]*5)
		if field.point_clear(candidate) and field.line_clear(spawn,candidate): destination = candidate;break
	world._set_click_destination(destination)
	check(destination != spawn and not world.player.click_path.is_empty(),id+" production click path")
	await ticks(45)
	check(world.player.global_position.distance_to(spawn) > 20 and field.point_clear(world.player.global_position),id+" actual click movement")
	world.player.clear_click_path();world.player.pulse_attack()
	check(world.player.motion.active,id+" existing attack playback")
	await ticks(55)
	check(not world.player.motion.active,id+" attack completes")
	check(world.hud.visible and world.player.camera.enabled,id+" existing HUD camera")
	if transform_check:
		var record: Dictionary = world._job_transform_record(world.job_class)
		world._apply_transform_visual(record)
		check(not record.is_empty() and world.player.transform_active and world.player.transform_sprite.visible,id+" existing transformation sprite on original PNG")
		check(world.player.scale == Vector2.ONE and world.player.get_node("CollisionShape2D").shape.radius == 4.0,id+" transformation preserves actor scale and actual feet")
		world.player.pulse_attack();check(world.player.motion.active,id+" transformed attack playback")
		await picture(id+"-transformation")
		await ticks(55)
		check(not world.player.motion.active,id+" transformed attack completes")
		world._restore_equipped_visuals()
	maps.append({"map_id":id,"source_map_id":field.definition.source_map_id,"grid_sha256":field.definition.source_sha256,
		"png_chunks_visible":png_count,"approaches":approaches,"status":"PNG_REVIEW_GAMEPLAY_EXECUTED",
		"image_collision_correspondence":"REVIEW_REQUIRED","foreground":"INCOMPLETE"})

func run() -> void:
	if not "--png-review" in OS.get_cmdline_user_args() or OS.get_environment("TWILIGHT_MAP_PNG_PACK").is_empty():
		print("PNG_WORLD_REVIEW_SKIP actual private PNG pack and --png-review required");quit();return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--maps="): selected = arg.trim_prefix("--maps=").split(",")
		if arg == "--capture": capture = true
		if arg == "--mobile": mobile = true
		if arg == "--transform-check": transform_check = true
	DirAccess.make_dir_recursive_absolute(output);root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"production class selection")
	world.set_process(false);world.save_timer = -100000
	if selected.is_empty():
		selected.append("aden_world")
		for floor: int in range(1,11): selected.append("oman_%02d" % floor)
	for id: String in selected: await inspect_map(id)
	var before: String = FileAccess.get_file_as_string(world.SAVE_PATH) if FileAccess.file_exists(world.SAVE_PATH) else ""
	world._save_game(true)
	var after: String = FileAccess.get_file_as_string(world.SAVE_PATH) if FileAccess.file_exists(world.SAVE_PATH) else ""
	check(before == after,"review cannot overwrite normal save")
	var report: Dictionary = {"checks":checks,"failures":failures,"maps":maps,"faithful_complete":0,
		"original_png_rendered":true,"source_navigation_active":true,"normal_saves_preserved":before==after}
	var file := FileAccess.open(output+"/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("PNG_WORLD_REVIEW ",checks," checks failures=",failures.size())
	world.queue_free();await ticks(2);quit(0 if failures.is_empty() else 1)
