extends SceneTree
## Actual Main capture. Test positioning selects samples; walking uses the
## production CharacterBody/controller. No fake obstacle or duplicate actors.
const QA=preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var checks: int=0
var failures: Array[String]=[]
var observations: Array=[]
var output: String="user://png-normal-capture"
func _initialize() -> void:call_deferred("run")
func ticks(n: int) -> void:
	for i: int in range(n):await physics_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("NORMAL_SAMPLE_FAIL ",label)
func place(p: Vector2) -> void:
	world.player.clear_click_path();world.player.set_touch_vector(Vector2.ZERO)
	world.player.global_position=p;world.player.velocity=Vector2.ZERO
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll();world.field_renderer.refresh_visible()
	if world.field_map is RemakePlayableField:world.field_map.collision_stream.refresh()
	if world.field_renderer is NativePngRenderer:await world.field_renderer.settle_visible()
	await ticks(3)
func picture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,name+" actual 1280x720")
func mobile_picture(name: String) -> void:
	if "--no-mobile" in OS.get_cmdline_user_args():return
	root.size=Vector2i(1560,720);DisplayServer.window_set_size(root.size);await ticks(8);await RenderingServer.frame_post_draw
	var screen: Image=DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
	if screen!=null:
		var rectangle:=Rect2i(DisplayServer.window_get_position(),DisplayServer.window_get_size())
		check(screen.get_region(rectangle).save_png(output+"/"+name+"-mobile-1560x720.png")==OK,name+" actual mobile-size Linux window")
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size);await ticks(6)
func distance(a: Color,b: Color) -> float:return maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))
func frame() -> Image:
	await ticks(2);await RenderingServer.frame_post_draw;return root.get_texture().get_image()
func foreground(mid: String,id: String,foot: Vector2) -> void:
	var field: NativePngField=world.field_map
	var old_camera: Vector2=world.player.camera.position
	var record: Dictionary={"map":mid,"cut":id,"states":[]}
	for state: String in ["behind","front"]:
		var point:=Vector2.INF;var best: float=INF
		var center: Vector2i=field.world_to_cell(foot)
		for y: int in range(center.y-16,center.y+17):
			for x: int in range(center.x-4,center.x+5):
				var p: Vector2=field.cell_to_world(Vector2i(x,y));var dy: float=(p.y-foot.y)*(-1 if state=="behind" else 1)
				if dy<18 or dy>180 or absf(p.x-foot.x)>30 or not field.walkable(p) or not field.point_clear(p,4):continue
				var score: float=absf(p.x-foot.x)*3+dy
				if score<best:best=score;point=p
		if mid=="aden_world":point=foot+(Vector2(72,4) if state=="front" else Vector2(60,-60))
		check(point.is_finite() and field.walkable(point) and field.point_clear(point,4),mid+" walkable occlusion probe "+state)
		if not point.is_finite():continue
		await place(point);world.player.set_physics_process(false)
		world.player.camera.global_position=foot+Vector2(0,-100)
		world.player.camera.force_update_scroll();world.player.class_sprite.pause()
		var cuts: Array[Sprite2D]=[]
		for node: Node in world.field_renderer.chunks.values():
			if node is Sprite2D and str(node.get_meta("native_foreground",""))==id:cuts.append(node)
		check(not cuts.is_empty(),mid+" foreground pieces present")
		var owned: Dictionary={}
		var duplicate_pixels: int=0
		for piece: Sprite2D in cuts:
			var pixels: Image=piece.texture.get_image();var origin: Array=piece.get_meta("source_position")
			for y: int in range(pixels.get_height()):
				for x: int in range(pixels.get_width()):
					if pixels.get_pixel(x,y).a==0:continue
					var key:=Vector2i(origin[0]+x,origin[1]+y)
					if owned.has(key):duplicate_pixels+=1
					owned[key]=true
		check(duplicate_pixels==0,mid+" source pixels have exactly one foreground owner")
		if cuts.is_empty():continue
		for piece: Sprite2D in cuts:piece.show()
		world.player.show();var both: Image=await frame()
		world.player.hide();var object_only: Image=await frame()
		for piece: Sprite2D in cuts:piece.hide()
		var neither: Image=await frame()
		world.player.show();var actor_only: Image=await frame()
		for piece: Sprite2D in cuts:piece.show()
		var overlap: int=0;var correct: int=0;var wrong: int=0
		var at: Vector2=world.get_canvas_transform()*foot
		for y: int in range(maxi(0,int(at.y)-420),mini(root.size.y,int(at.y)+110)):
			for x: int in range(maxi(0,int(at.x)-180),mini(root.size.x,int(at.x)+180)):
				var bg: Color=neither.get_pixel(x,y);var o: Color=object_only.get_pixel(x,y);var a: Color=actor_only.get_pixel(x,y);var actual: Color=both.get_pixel(x,y)
				if distance(bg,o)<.15 or distance(bg,a)<.15 or distance(a,o)<.1:continue
				overlap+=1
				if distance(actual,o if state=="behind" else a)<.025:correct+=1
				if distance(actual,a if state=="behind" else o)<.025:wrong+=1
		check(overlap>4 and correct>4 and correct>wrong,mid+" actual foreground pixel order "+state)
		record.states.append({"state":state,"overlap":overlap,"correct":correct,"wrong":wrong,"position":[point.x,point.y]})
		both.save_png(output+"/"+mid+"-"+state+".png")
		world.player.set_physics_process(true)
	world.player.camera.position=old_camera;observations.append(record)
func obstacle(mid: String,name: String,center: Vector2,radius: float) -> void:
	var field: PlayableField=world.field_map
	for direction: Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
		var start:=Vector2.INF
		for gap: float in [8.,16.,24.,32.,48.,64.,96.,128.,160.,208.,256.]:
			var p: Vector2=center+direction*(radius+gap)
			if field.line_clear(p,p):start=p;break
		check(start.is_finite(),mid+" "+name+" clear approach "+str(direction))
		if not start.is_finite():continue
		await place(start);world.hud.show_message(name+" · 실제 충돌 검수")
		check(world.player.test_move(world.player.global_transform,center-start),mid+" "+name+" real body cast "+str(direction))
		world.player.set_touch_vector((center-start).normalized());await ticks(180 if "--video-slow" in OS.get_cmdline_user_args() else 75);world.player.set_touch_vector(Vector2.ZERO)
		print("OBSTACLE_END ",mid," ",name," ",direction," at=",world.player.global_position," clear=",[field.point_clear(world.player.global_position,0),field.point_clear(world.player.global_position,3),field.point_clear(world.player.global_position,3.5),field.point_clear(world.player.global_position,3.9)]," radius=",world.player.get_node("CollisionShape2D").shape.radius)
		# Allow only 0.1px floating-point contact tolerance for the 4px foot.
		check(field.point_clear(world.player.global_position,3.9),mid+" "+name+" cannot push through "+str(direction))
		await picture(mid+"-"+name+"-"+str(direction))
func enter(mid: String) -> void:
	world._set_map(mid,false);world.portal_cooldown=10000;world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false)
	check(world.active_map_id==mid,mid+" normal entry")
	world.player.camera.position_smoothing_enabled=false
func run() -> void:
	if DisplayServer.get_name()=="headless":print("NORMAL_SAMPLE_SKIP: real OpenGL required");quit();return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720);DisplayServer.window_set_position(Vector2i.ZERO)
	world=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000
	enter("aden_world");await place(world._spawn_position());await picture("aden-world");await mobile_picture("aden-world")
	world._set_click_destination(world._spawn_position()+Vector2(-120,-60));await ticks(60)
	await obstacle("aden_world","palace_fountain",Vector2(11762,2921)*6,84)
	await obstacle("aden_world","east_tree",Vector2(11140,2350)*6,24)
	await foreground("aden_world","east_tree_crown",Vector2(11140,2350)*6)
	enter("oman_01");await ticks(6);await picture("oman-01");await mobile_picture("oman-01")
	await place(Vector2(2736,3108));world.player.set_touch_vector(Vector2(-24,-12).normalized());await ticks(180 if "--video-slow" in OS.get_cmdline_user_args() else 75);world.player.set_touch_vector(Vector2.ZERO)
	check(world.field_map.point_clear(world.player.global_position),"Oman source wall blocks actual walking")
	enter("oman_10");await ticks(6);await picture("oman-10")
	enter("domination_summit");await place(world._spawn_position());await picture("domination-111")
	await obstacle("domination_summit","crystal",Vector2(8342,3648),26)
	await foreground("domination_summit","central_crystal_column",Vector2(8342,3650))
	await mobile_picture("domination")
	var result: Dictionary={"checks":checks,"failures":failures,"occlusion":observations,"android_device":"NOT_RUN","whole_map_complete":false}
	var file:=FileAccess.open(output+"/capture.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print("NORMAL_SAMPLE_RESULT ",JSON.stringify(result))
	world.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
