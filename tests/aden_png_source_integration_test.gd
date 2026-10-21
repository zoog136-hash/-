extends SceneTree
## Actual Main and production actors/physics. Use isolated XDG_DATA_HOME.
## PNG survey rejection is tested separately from existing playable source art.
const QA = preload("res://tests/qa_class_selection.gd")
const ANCHOR = preload("res://scripts/maps/source_prop_anchor.gd")
const PACK = preload("res://scripts/maps/aden_png_pack.gd")
var world: TwilightWorld
var field: RemakePlayableField
var failures: Array[String] = []
var checks: int = 0
var output: String = "user://aden-png-source-test"
var capture: bool = false
var demo: bool = false
var capture_only: bool = false
var probes: Array[Dictionary] = []
var anchors: Array[Dictionary] = []
var pictures: Array[Dictionary] = []
var monster: TwilightMonster
var occlusion: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("ADEN_PNG_SOURCE_FAIL ",label)

func ticks(count: int) -> void:
	for frame: int in range(count): await physics_frame

func place(point: Vector2) -> void:
	world.player.set_touch_vector(Vector2.ZERO);world.player.clear_click_path()
	world.player.global_position = point;world.player.velocity = Vector2.ZERO
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	field.collision_stream.refresh();world.field_renderer.refresh_visible()

func picture(name: String, native_window: bool = false) -> void:
	if not capture: return
	check(DisplayServer.get_name() != "headless","capture uses an actual renderer")
	if DisplayServer.get_name() == "headless": return
	for frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	var viewport_size: Vector2i = pixels.get_size()
	if native_window:
		# Project aspect=keep renders a 1280x720 viewport inside a wide
		# mobile-shaped window. Capture the real window including its bars,
		# never relabel the logical viewport as a 1560px screenshot.
		var screen: Image = DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
		var rect := Rect2i(DisplayServer.window_get_position(),DisplayServer.window_get_size())
		print("ADEN_NATIVE_CAPTURE ",rect," screen=",screen.get_size() if screen != null else Vector2i.ZERO)
		check(screen != null and Rect2i(Vector2i.ZERO,screen.get_size()).encloses(rect),"native window fits capture display")
		if screen == null or not Rect2i(Vector2i.ZERO,screen.get_size()).encloses(rect): return
		pixels = screen.get_region(rect)
		check(pixels.get_size() == root.size,"native mobile PNG pixel dimensions")
	check(pixels.save_png(output+"/"+name+".png") == OK,"capture "+name)
	pictures.append({"file":name+".png","requested_window":[root.size.x,root.size.y],"actual_png_size":[pixels.get_width(),pixels.get_height()],"render_viewport":[viewport_size.x,viewport_size.y],"world_position":[world.player.global_position.x,world.player.global_position.y]})

func mobile_picture() -> void:
	root.size = Vector2i(1560,720)
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_position(Vector2i.ZERO)
	await ticks(8)
	await picture("giran-mobile-1560x720",true)

func edge(record: Dictionary, heading: int) -> Array[Vector2i]:
	var box: Array = record.source_box
	var target: Vector2 = ANCHOR.tree_foot(field,box,Vector2(record.position[0],record.position[1]))
	var result: Array[Vector2i] = []
	var best: float = INF
	for y: int in range(int(box[1]),int(box[1]+box[3])):
		for x: int in range(int(box[0]),int(box[0]+box[2])):
			var blocked := Vector2i(x,y)
			var opened: Vector2i = blocked-field.DIRECTIONS[heading]
			if field.value_at(blocked,true) != 0 or not field.point_clear(field.cell_to_world(opened)): continue
			var distance: float = field.cell_to_world(blocked).distance_squared_to(target)
			if distance < best: best = distance;result = [opened,blocked]
	return result

func tree_sprite(box: Array) -> Sprite2D:
	for chunk: Node in world.field_renderer.chunks.values():
		for node: Node in chunk.get_children():
			if node is Sprite2D and str(node.get_meta("placement_kind","")) == "tree" and node.get_meta("source_box",[]) == box: return node
	return null

func frame_image() -> Image:
	for frame: int in range(2): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func inspect_occlusion(record: Dictionary) -> void:
	var camera_offset: Vector2 = world.player.camera.position
	var foot: Vector2 = ANCHOR.tree_foot(field,record.source_box,Vector2(record.position[0],record.position[1]))
	var center: Vector2i = field.world_to_cell(foot)
	var directions: Dictionary = {"behind":-1.0,"front":1.0}
	world.player.set_physics_process(false)
	for state: String in directions:
		var point := Vector2.INF
		var best: float = INF
		for y: int in range(center.y-10,center.y+11):
			for x: int in range(center.x-10,center.x+11):
				var p: Vector2 = field.cell_to_world(Vector2i(x,y))
				var dy: float = (p.y-foot.y)*float(directions[state])
				if dy<20 or dy>100 or absf(p.x-foot.x)>40 or not field.point_clear(p): continue
				var score: float = absf(p.x-foot.x)*3+absf(dy-40)
				if score<best:best=score;point=p
		check(point.is_finite(),str(record.id)+" walkable occlusion approach "+state)
		if not point.is_finite(): continue
		place(point)
		world.player.camera.global_position = foot+Vector2(0,-60)
		world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		var tree: Sprite2D = tree_sprite(record.source_box)
		check(tree != null,str(record.id)+" real production tree sprite")
		if tree == null: continue
		tree.show();world.player.show()
		var both: Image = await frame_image()
		world.player.hide()
		var tree_only: Image = await frame_image()
		tree.hide()
		var neither: Image = await frame_image()
		world.player.show()
		var actor_only: Image = await frame_image()
		tree.show()
		var overlap: int = 0;var correct: int = 0;var opposite: int = 0
		var screen: Vector2 = world.get_canvas_transform()*foot
		for py: int in range(maxi(0,int(screen.y)-220),mini(root.size.y,int(screen.y)+110)):
			for px: int in range(maxi(0,int(screen.x)-110),mini(root.size.x,int(screen.x)+110)):
				var a: Color = neither.get_pixel(px,py);var t: Color = tree_only.get_pixel(px,py);var p: Color = actor_only.get_pixel(px,py);var c: Color = both.get_pixel(px,py)
				if color_distance(a,t)<.20 or color_distance(a,p)<.20 or color_distance(p,t)<.10: continue
				overlap += 1
				var expected: Color = t if state == "behind" else p
				var wrong: Color = p if state == "behind" else t
				if color_distance(c,expected)<.025: correct += 1
				if color_distance(c,wrong)<.025: opposite += 1
		check(overlap>4 and correct>4 and correct>opposite,str(record.id)+" actual occlusion pixels "+state)
		occlusion.append({"id":record.id,"state":state,"overlap_pixels":overlap,"correct_pixels":correct,"opposite_pixels":opposite,"foot_world":[point.x,point.y]})
		await picture("tree-"+state+"-occlusion")
	world.player.set_physics_process(true)
	world.player.camera.position = camera_offset

func color_distance(a: Color,b: Color) -> float:
	return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)

func probe(record: Dictionary, heading: int, push_frames: int) -> void:
	var cells: Array[Vector2i] = edge(record,heading)
	check(not cells.is_empty(),str(record.id)+" original approach "+str(heading))
	if cells.is_empty(): return
	var start: Vector2 = field.cell_to_world(cells[0])
	var target: Vector2 = field.cell_to_world(cells[1])
	world.player.set_physics_process(false);place(start)
	monster.global_position = start;monster.velocity = Vector2.ZERO
	await ticks(3)
	var ray := PhysicsRayQueryParameters2D.create(start,target,4)
	check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),str(record.id)+" physical edge "+str(heading))
	check(world.player.test_move(world.player.global_transform,target-start),str(record.id)+" actual player shape cast "+str(heading))
	check(monster.test_move(monster.global_transform,target-start),str(record.id)+" actual monster shape cast "+str(heading))
	world.player.set_physics_process(true)
	var direction: Vector2 = (target-start).normalized()
	world.player.set_touch_vector(direction)
	var stayed_open: bool = true
	var feet_clear: bool = true
	for frame: int in range(push_frames):
		await physics_frame
		monster.velocity = direction*210.0
		monster._move_on_map()
		stayed_open = stayed_open and field.walkable(world.player.global_position) and field.walkable(monster.global_position)
		feet_clear = feet_clear and field.point_clear(world.player.global_position) and field.point_clear(monster.global_position)
	world.player.set_touch_vector(Vector2.ZERO);monster.velocity = Vector2.ZERO
	check(stayed_open and feet_clear,str(record.id)+" player/monster push footprint "+str(heading))
	probes.append({"id":record.id,"kind":record.kind,"heading":heading,"from_cell":[cells[0].x,cells[0].y],"blocked_cell":[cells[1].x,cells[1].y],
		"player":[world.player.global_position.x,world.player.global_position.y],"monster":[monster.global_position.x,monster.global_position.y],"physics_ticks":push_frames,"stayed_open":stayed_open,"feet_clear":feet_clear})

func run() -> void:
	# This suite asserts the immutable A3 source grid and its reviewed props.
	# Native PNG actors and physics have their own active-map acceptance suite.
	if preload("res://tests/legacy_aden_faith_fixture.gd").delegate(self,"res://tests/aden_png_source_integration_test.gd"): return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--capture": capture = true
		if arg == "--demo-only": demo = true
		if arg == "--capture-only": capture_only = true
	DirAccess.make_dir_recursive_absolute(output);root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"production class confirmation")
	world.save_timer = -100000;world.set_process(false);world.field_population.set_process(false)
	for mob: Node in world.monsters_root.get_children():
		mob.set_physics_process(false)
		if monster == null and mob is TwilightMonster and not mob.dead: monster = mob
	check(world.field_map is RemakePlayableField,"production Aden source field")
	if not world.field_map is RemakePlayableField or monster == null: finish();return
	field = world.field_map
	check(field.width == 2048 and field.height == 1536 and field.chunk_table.size() == 768,"immutable source grid and chunks")
	check(field.definition.source_map_id == 4 and field.definition.source_sha256 == PACK.GRID_SHA,"source identity")
	check(world.player.scale == Vector2.ONE,"actor scale remains one")
	check((world.player.get_node("CollisionShape2D").shape as CircleShape2D).radius == 4.0,"runtime player foot radius")
	check((monster.get_node("CollisionShape2D").shape as CircleShape2D).radius == 4.0,"runtime monster foot radius")
	check(world.y_sort_enabled and world.field_renderer.y_sort_enabled,"shared world/renderer foot Y-sort")
	var pack := PACK.new()
	check(not pack.configure("user://missing-aden-png-pack",field) and pack.regions.is_empty(),"missing pack does not replace gameplay")
	if capture_only:
		place(field.cell_to_world(Vector2i(981,740)))
		await picture("giran-1280x720")
		await mobile_picture()
		finish();return
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/aden_giran_review/layout.json"))
	var objects: Array[Dictionary] = []
	for record: Dictionary in layout.props:
		if str(record.kind) not in ["tree","building","hall"]: continue
		objects.append(record)
		if str(record.kind) != "tree": continue
		var old := Vector2(record.position[0],record.position[1])
		var resolved: Vector2 = ANCHOR.tree_foot(field,record.source_box,old)
		check(not field.walkable(resolved),str(record.id)+" visible trunk belongs to its actual blocker")
		var approach: Array[Vector2i] = edge(record,2)
		if not approach.is_empty():
			place(field.cell_to_world(approach[0]))
			var sprite: Sprite2D = tree_sprite(record.source_box)
			check(sprite != null and sprite.global_position.distance_to(resolved)<.01,str(record.id)+" production renderer uses verified trunk anchor")
		if not field.walkable(old): check(old == resolved,str(record.id)+" already aligned placement preserved")
		anchors.append({"id":record.id,"old":[old.x,old.y],"resolved":[resolved.x,resolved.y],"original_was_walkable":field.walkable(old),"delta":old.distance_to(resolved)})
	place(field.cell_to_world(Vector2i(981,740)));await ticks(3)
	await picture("giran-1280x720")
	# A real click destination goes through the production navigation service.
	var start: Vector2 = world.player.global_position
	var destination: Vector2 = start
	for heading: int in [0,2,4,6]:
		var point: Vector2 = field.cell_to_world(field.world_to_cell(start)+field.DIRECTIONS[heading]*6)
		if field.line_clear(start,point): destination = point;break
	world._set_click_destination(destination)
	check(destination != start and not world.player.click_path.is_empty(),"production destination click creates a path")
	for frame: int in range(150):
		await physics_frame
		if world.player.global_position.distance_to(destination) < 12: break
	check(world.player.global_position.distance_to(start)>20 and field.point_clear(world.player.global_position),"click path actually moves production player")
	world.player.clear_click_path()
	if not demo:
		for record: Dictionary in objects:
			if str(record.id) == "tree_1007_722": await inspect_occlusion(record);break
	if demo:
		var selected: Array[Dictionary] = []
		for kind: String in ["building","tree"]:
			for record: Dictionary in objects:
				if str(record.kind) == kind and not edge(record,2).is_empty(): selected.append(record);break
		for record: Dictionary in selected:
			await probe(record,2,120)
			await picture(str(record.kind)+"-collision")
	else:
		for record: Dictionary in objects:
			for heading: int in [0,2,4,6]: await probe(record,heading,10)
	# Exercise production attack playback, retaining the existing frame source.
	place(field.cell_to_world(Vector2i(981,740)))
	world.player.pulse_attack()
	check(world.player.motion.active,"production attack animation starts")
	await ticks(60)
	check(not world.player.motion.active,"production attack animation finishes")
	var saved: Vector2 = world.player.global_position
	world._save_game(true);world.player.global_position += Vector2(100,0);world._load_game(true)
	field = world.field_map
	check(world.active_map_id == "aden_world" and world.player.global_position.distance_to(saved)<.1,"unchanged source-coordinate save/reentry")
	world.set_process(false);world.field_population.set_process(false)
	for mob: Node in world.monsters_root.get_children():
		mob.set_physics_process(false)
		if mob is TwilightMonster and not mob.dead:
			check((mob.get_node("CollisionShape2D").shape as CircleShape2D).radius == 4.0 and mob.get_node("CollisionShape2D").position == Vector2.ZERO,"respawn/reload monster retains final source foot")
	if not demo:
		await mobile_picture()
	check(is_instance_valid(world.hud) and world.player.camera.enabled,"existing HUD and camera remain active")
	root.size = Vector2i(1280,720)
	world.field_renderer.set_visual_mode("collision")
	await picture("source-collision-1280x720")
	finish()

func finish() -> void:
	var result: Dictionary = {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,
		"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_video_adapter_name(),
		"tree_anchors":anchors,"obstacle_probes":probes,"screenshots":pictures,"demo_only":demo,"capture_only":capture_only,
		"png_playable_sample":"BLOCKED_UNVERIFIED_ALIGNMENT","original_layers":"NOT_AVAILABLE_SINGLE_COMPOSITE",
		"android_device":"NOT_RUN","android_build":"NOT_RUN","occlusion_pixels":occlusion,
		"runtime_move_speed":world.player.move_speed if is_instance_valid(world) else 0,
		"scope":"Existing TWILIGHT Main, original source physics and reviewed TWILIGHT props. These passes do not certify PNG alignment or original artwork."}
	var file := FileAccess.open(output+"/runtime.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"\t"));file.close()
	print("ADEN_PNG_SOURCE_RESULT ",JSON.stringify(result))
	if is_instance_valid(world): world.queue_free()
	quit(0 if failures.is_empty() else 1)
