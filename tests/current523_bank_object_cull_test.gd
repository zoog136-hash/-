extends SceneTree
## Map object engine tick: shared clock advanced at ANIMATION_HZ, and only
## placements meeting the camera view advance. Differential against the prior
## every-frame, every-placement path (offscreen_culling=false, step 0) with
## synthetic textures/records; the real _show layer code runs on both.
## --benchmark prints MAP_OBJECT_CULL_BENCH (synthetic headless CPU only).
const OBJECTS=preload("res://scripts/maps/current523_bank_objects.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
class Mapping extends RefCounted:
	func to_world(raw: Vector2, _wrap: bool) -> Vector2: return raw
class Fixture extends OBJECTS:
	var shows: int=0
	func _texture(layer: Dictionary) -> Texture2D: return layer.get("fixture_texture") as Texture2D
	func _show(node: Node2D, sprite: Dictionary, index: int) -> void:
		if int(node.get_meta("frame"))!=index: shows+=1
		super._show(node,sprite,index)
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("MAP_OBJECT_CULL_FAIL: "+label)
func _initialize() -> void: run.call_deferred()
func textures() -> Array[Texture2D]:
	var result: Array[Texture2D]=[]
	for seed: int in 4:
		var image:=Image.create_empty(48,96,false,Image.FORMAT_RGBA8);image.fill(Color(0.1*seed,0.5,0.7,1.0))
		result.append(ImageTexture.create_from_image(image))
	return result
func catalog(t: Array[Texture2D]) -> Dictionary:
	var frames: Array=[]
	var total: float=0.0
	for i: int in 8:
		# Off the 1/30 s grid: no update lands on a frame boundary, where the
		# summed float clocks of the two paths could round either way.
		var duration: float=0.107 if i%3!=0 else 0.053
		frames.append({"duration":duration,"presentation_duration":duration,"layers":[{"fixture_texture":t[i%4],"offset":[-24,-80]},{"fixture_texture":t[(i+1)%4],"offset":[-10,-40],"kind":"shadow"}]})
		total+=duration
	return {1:{"ok":true,"static":false,"total":total,"frames":frames},
		2:{"ok":true,"static":false,"total":0.414,"frames":[{"duration":0.207,"layers":[{"fixture_texture":t[2],"offset":[0,0]}]},{"duration":0.207,"layers":[{"fixture_texture":t[3],"offset":[0,0]}]}]},
		3:{"ok":true,"static":true,"total":0.0,"frames":[{"layers":[{"fixture_texture":t[0],"offset":[0,0]}]}]}}
func rows() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	# 1024 placements over 8000 x 4000 px, as the 25 visible chunks spread them.
	for i: int in 1024:
		result.append({"sprite_id":[1,1,2,3][i%4],"raw_x":float((i%32)*250),"raw_y":float((i/32)*125)})
	return result
func make(t: Array[Texture2D], legacy: bool) -> Fixture:
	var owner:=Fixture.new()
	owner._sprites=catalog(t);owner.coordinates=Mapping.new();owner._mode="compatible"
	if legacy: owner.offscreen_culling=false;owner.animation_step=0.0
	root.add_child(owner);owner.set_process(false)
	owner.refresh(rows())
	return owner
func view_of(owner: Node2D) -> Rect2:
	return owner._local_view()
func in_view(node: Node2D, view: Rect2) -> bool:
	var bounds: Rect2=node.get_meta("bounds")
	return view.intersects(Rect2(node.position+bounds.position,bounds.size))
func compare_visible(old: Fixture, current: Fixture, label: String) -> int:
	var view: Rect2=view_of(current)
	var compared: int=0
	for i: int in current._nodes.size():
		var node: Node2D=current._nodes[i]
		if not in_view(node,view): continue
		compared+=1
		var a: Node2D=old._nodes[i]
		var same: bool=a.get_meta("frame")==node.get_meta("frame") and a.get_child_count()==node.get_child_count()
		for c: int in mini(a.get_child_count(),node.get_child_count()):
			var x: Sprite2D=a.get_child(c);var y: Sprite2D=node.get_child(c)
			same=same and x.texture==y.texture and x.position==y.position and x.z_index==y.z_index
		if not same: check(false,"%s: on-screen placement %d differs from the every-frame path"%[label,i]);return compared
	check(compared>0,label+": some placements are on screen")
	return compared
func run() -> void:
	var t: Array[Texture2D]=textures()
	var camera:=Camera2D.new();camera.position=Vector2(4000,2000);root.add_child(camera);camera.make_current()
	await process_frame
	camera.force_update_scroll()
	var old: Fixture=make(t,true)
	var current: Fixture=make(t,false)
	check(view_of(old)==Rect2() and view_of(current).has_area(),"only the culling owner reads the camera view")
	var on_screen: int=0
	# 30 fps engine frames: the current owner updates every second frame and
	# then shows exactly the frames the every-frame path shows on screen.
	for frame: int in 90:
		old._process(1.0/30.0);current._process(1.0/30.0)
		if frame%2==1:
			check(is_equal_approx(old._clock,current._clock),"clock carried exactly at frame %d"%frame)
			on_screen=compare_visible(old,current,"frame %d"%frame)
	check(current._shown_animated.size()<current._animated_nodes.size()/4,"most animated placements are culled (%d of %d)"%[current._shown_animated.size(),current._animated_nodes.size()])
	# Camera moves: a placement entering the view shows the clock frame at once.
	for step: int in 12:
		camera.position+=Vector2(97,41);camera.force_update_scroll()
		old._process(1.0/30.0);current._process(1.0/30.0)
		old._process(1.0/30.0);current._process(1.0/30.0)
		compare_visible(old,current,"moving camera step %d"%step)
	camera.position=Vector2(250,125);camera.force_update_scroll()
	old._process(1.0/15.0);current._process(1.0/15.0)
	compare_visible(old,current,"camera jump")
	# Slow frames (8 fps) update on every frame.
	var before: int=current.shows
	for frame: int in 8:
		old._process(0.125);current._process(0.125)
		compare_visible(old,current,"8 fps frame %d"%frame)
	check(current.shows>before,"slow frames still advance on-screen placements")
	# A refresh rebuilds the cull list for the new holders.
	old.refresh(rows());current.refresh(rows())
	old._process(0.1);current._process(0.1)
	compare_visible(old,current,"after refresh")
	var bench: Dictionary={}
	if "--benchmark" in OS.get_cmdline_user_args():
		for legacy: bool in [true,false]:
			var samples: Array[int]=[]
			var shows: Array[int]=[]
			for sample: int in 5:
				var owner: Fixture=make(t,legacy)
				camera.position=Vector2(4000,2000);camera.force_update_scroll()
				owner.shows=0
				var started: int=Time.get_ticks_usec()
				for frame: int in 300:
					if frame%10==0: camera.position+=Vector2(12,6);camera.force_update_scroll()
					owner._process(1.0/30.0)
				samples.append(Time.get_ticks_usec()-started);shows.append(owner.shows)
				owner.free()
			samples.sort()
			bench["legacy" if legacy else "current"]={"median_usec_300_frames":samples[2],"samples":samples,"frame_changes":shows[2]}
		print("MAP_OBJECT_CULL_BENCH "+JSON.stringify({"synthetic_only":true,"placements":1024,"frames":300,"fps":30,"result":bench}))
	old.free();current.free();camera.free()
	print("CURRENT523_BANK_OBJECT_CULL_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true,"on_screen_compared":on_screen}))
	quit(0 if failures.is_empty() else 1)
