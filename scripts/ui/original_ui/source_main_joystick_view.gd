extends RefCounted
## Original movement pad (MainScene Set_L_Bot_ControlNewLayout) drawn over the
## existing TwilightVirtualJoystick. The existing joystick keeps every touch,
## dead zone, 8-direction snap and movement signal; this view only follows its
## value: the original knob moves, the direction arrows turn and loop. The
## original knob is display-only (never a routed source button), so no touch is
## taken from the joystick. Nothing is drawn by TWILIGHT while it is presented.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const MEMBER="UI/Main/Set_L_Bot_ControlNewLayout.csb"
const SHA256="2e5c5bba4d3407178251da775a7257b75dfd8917801699c815be6574ebd09984"
const MAIN="UI/MainScene.csb"
const MAIN_PROJECT=22200
const KNOB=2264
const PAD=140
const ARROW=1660
const ARROW_FX=200
const LOOP_CLIP="Fx_Loop"
## Knob travel as a fraction of the pad's drawn radius (display only).
const KNOB_TRAVEL=0.5
const SAVED_RECT="source_joystick_twilight_rect"
var _scene: Node2D
var _joystick: WeakRef
var _knob_base: Vector2
var _arrow_base: float
var _arrow_fx_base: float
var _value: Vector2=Vector2.INF

static func available(pack: RefCounted) -> bool:
	return pack!=null and pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")==SHA256

func open(pack: RefCounted, coordinates: Node2D, joystick: Control) -> Dictionary:
	if not available(pack):return {"ok":true,"handled":false,"code":"source_joystick_pack_scope_unavailable"}
	if not is_instance_valid(coordinates) or not is_instance_valid(joystick) or not joystick.has_method("is_held") or not "draw_visual" in joystick:return _fail("source_joystick_existing_control_required")
	var scene:=Scene.new()
	# Display-only original knob: disabledData is the same original
	# Hud_Pad_Btn image, and a disabled source button is never routed.
	var result: Dictionary=scene.configure_project(pack,MAIN,MAIN_PROJECT,{KNOB:{"role":"button","displaystate":false}})
	if not result.get("ok",false):scene.free();return result
	var nodes: Dictionary=scene.get("source_nodes")
	for offset: int in [KNOB,PAD,ARROW,ARROW_FX]:
		if not is_instance_valid(nodes.get(offset)):scene.free();return {"ok":false,"code":"source_joystick_node_missing","offset":offset}
	coordinates.add_child(scene)
	_scene=scene
	_joystick=weakref(joystick)
	_knob_base=nodes[KNOB].position
	_arrow_base=nodes[ARROW].rotation
	_arrow_fx_base=nodes[ARROW_FX].rotation
	# A replacing controller keeps the first, untouched TWILIGHT placement.
	if not joystick.has_meta(SAVED_RECT):joystick.set_meta(SAVED_RECT,{"offset_left":joystick.offset_left,"offset_top":joystick.offset_top,"offset_right":joystick.offset_right,"offset_bottom":joystick.offset_bottom})
	joystick.draw_visual=false
	joystick.queue_redraw()
	_value=Vector2.INF
	refresh()
	return {"ok":true,"handled":true,"source":MEMBER,"source_parent":MAIN,"source_project":MAIN_PROJECT,"input_owner":"existing TwilightVirtualJoystick","knob_travel_basis":"TWILIGHT display estimate","partial_source_scene":false,"complete_screen_contract":false,"game_state_written":false}

func is_open() -> bool:
	return is_instance_valid(_scene)

func refresh() -> void:
	if not is_instance_valid(_scene):return
	var joystick: Control=_joystick.get_ref() if _joystick!=null else null
	if not is_instance_valid(joystick):return
	# The pad is shown exactly when the existing control would be.
	_scene.visible=joystick.is_visible_in_tree()
	if joystick.draw_visual:
		joystick.draw_visual=false
		joystick.queue_redraw()
	_fit_input(joystick)
	var value: Vector2=joystick.get("value") if joystick.get("value") is Vector2 else Vector2.ZERO
	if value==_value:return
	_value=value
	var nodes: Dictionary=_scene.get("source_nodes")
	var pad: Node2D=nodes[PAD]
	var radius: float=_pad_radius(pad)
	nodes[KNOB].position=_knob_base+value*radius*KNOB_TRAVEL
	if value==Vector2.ZERO:
		_scene.stop()
		_scene.seek_frame(0.0)
		nodes[ARROW].rotation=_arrow_base
		nodes[ARROW_FX].rotation=_arrow_fx_base
		return
	# Original arrows are authored pointing right of the pad centre (Fx_Arrow
	# sprites at +x); turn them to the existing joystick's direction.
	nodes[ARROW].rotation=_arrow_base+value.angle()
	nodes[ARROW_FX].rotation=_arrow_fx_base+value.angle()
	if not _scene.playback_status().get("playing",false):_scene.play(LOOP_CLIP,true)

func _pad_radius(pad: Node2D) -> float:
	var size: Variant=pad.get_meta("source_size",[0,0])
	var scale: Variant=pad.get_meta("source_scale",[1,1])
	return minf(float(size[0])*float(scale[0]),float(size[1])*float(scale[1]))*0.5

func _fit_input(joystick: Control) -> void:
	# The existing control receives touches exactly where the original pad is.
	var pad: Node2D=_scene.get("source_nodes")[PAD]
	var radius: float=_pad_radius(pad)
	var centre: Vector2=pad.get_global_transform_with_canvas().origin
	var scale: Vector2=pad.get_global_transform_with_canvas().get_scale()/maxf(0.0001,absf(float(pad.get_meta("source_scale",[1,1])[0])))
	var extent: Vector2=Vector2(radius,radius)*2.0*scale
	var parent: Control=joystick.get_parent() as Control
	var to_parent: Transform2D=parent.get_global_transform_with_canvas().affine_inverse() if parent!=null else Transform2D.IDENTITY
	var local_centre: Vector2=to_parent*centre
	var local_extent: Vector2=to_parent.basis_xform(extent)/joystick.scale
	var target:=Rect2(local_centre-local_extent*joystick.scale*0.5,local_extent)
	if joystick.position.is_equal_approx(target.position) and joystick.size.is_equal_approx(target.size):return
	joystick.position=target.position
	joystick.size=target.size

func close(restore_existing: bool=true) -> void:
	var joystick: Control=_joystick.get_ref() if _joystick!=null else null
	if is_instance_valid(joystick) and restore_existing:
		joystick.draw_visual=true
		var saved: Variant=joystick.get_meta(SAVED_RECT,{})
		for key: String in saved:joystick.set(key,saved[key])
		joystick.remove_meta(SAVED_RECT)
		joystick.queue_redraw()
	if is_instance_valid(_scene):
		_scene.hide()
		_scene.queue_free()
	_scene=null
	_joystick=null

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
