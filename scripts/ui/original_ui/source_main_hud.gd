extends Node
## Existing game's update_player -> original main HUD components. This node
## adds no gameplay logic or artwork. Component positions are read from the
## supplied MainScene, not from renewal_theme/reference_layout coordinates.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Vitals=preload("res://scripts/ui/original_ui/source_main_vitals_bindings.gd")
const MAIN="UI/MainScene.csb"
const MAIN_SHA="80c174a87caf5cfbf910336b64616334ac560ed477f7a663aec58ada70d4285f"
const EXP_PROJECT=23080
var _pack: RefCounted
var _hud: WeakRef
var _canvas: WeakRef
var _coordinates: Node2D
var _exp_scene: Node2D
var _exp_value: int=0
var _exp_need: int=0
var _has_player_values: bool=false
var _exp_mount_attempted: bool=false
var _restore_legacy: bool=true
var _design_size: Vector2
var last_result: Dictionary={}

func configure(pack: RefCounted, hud: Node, canvas: Control) -> Dictionary:
	if pack==null or not is_instance_valid(hud) or not is_instance_valid(canvas):return _fail("source_main_host_unavailable")
	var parent: Dictionary=pack.layout_source(MAIN) if pack.has_method("layout_source") else {}
	if parent.is_empty():parent=pack.scene(MAIN)
	if pack.manifest.get("files",{}).get(MAIN,{}).get("sha256","")!=MAIN_SHA or parent.get("_source_sha256")!=MAIN_SHA:return _fail("source_main_parent_identity_mismatch")
	var root: Dictionary=parent.get("nodeTree",{}).get("options",{})
	var size_value: Variant=root.get("size")
	if not size_value is Array or size_value.size()!=2:return _fail("source_main_design_size_missing")
	_design_size=Vector2(float(size_value[0]),float(size_value[1]))
	if not _design_size.is_finite() or _design_size.x<=0 or _design_size.y<=0:return _fail("source_main_design_size_invalid")
	_pack=pack
	_hud=weakref(hud)
	_canvas=weakref(canvas)
	_coordinates=Node2D.new()
	_coordinates.name="OriginalMainSourceCoordinates"
	_coordinates.z_index=35
	canvas.add_child(_coordinates)
	canvas.resized.connect(_fit_source_coordinates)
	_fit_source_coordinates()
	return {"ok":true,"source_design_size":_design_size,"game_state_written":false,"complete_screen_contract":false}

func update_player(_level: int, _hp: int, _max_hp: int, _mp: int, _max_mp: int, experience_value: int, exp_need: int, _gold: int) -> Dictionary:
	var unchanged: bool=_has_player_values and _exp_value==experience_value and _exp_need==exp_need
	_exp_value=experience_value
	_exp_need=exp_need
	_has_player_values=true
	if not is_instance_valid(_coordinates):return _fail("source_main_not_configured")
	if not is_instance_valid(_exp_scene):
		if _exp_mount_attempted and not last_result.get("ok",false):return last_result
		return _mount_exp()
	if unchanged:return last_result
	last_result=Vitals.refresh_exp(_exp_scene,_exp_value,_exp_need)
	return last_result

func _mount_exp() -> Dictionary:
	if not _has_player_values:return _fail("source_main_player_values_pending")
	_exp_mount_attempted=true
	var contract: Dictionary=Vitals.build_exp(_pack,_exp_value,_exp_need)
	if not contract.get("ok",false):return _remember(contract)
	var scene=Scene.new()
	var configured: Dictionary=scene.configure_project(_pack,MAIN,EXP_PROJECT,contract.bindings)
	if not configured.get("ok",false):
		scene.free()
		return _remember(configured)
	_coordinates.add_child(scene)
	_exp_scene=scene
	_set_legacy_exp_visible(false)
	return _remember({"ok":true,"source":contract.member,"source_parent":MAIN,"source_project":EXP_PROJECT,"game_state_written":false,"complete_screen_contract":false})

func _fit_source_coordinates() -> void:
	var canvas: Control=_canvas.get_ref() if _canvas!=null else null
	if canvas==null or not is_instance_valid(_coordinates):return
	var factor: float=minf(canvas.size.x/_design_size.x,canvas.size.y/_design_size.y)
	if factor<=0:return
	# One outer viewport transform preserves the serialized component/node
	# positions. Centering letterboxes a different aspect ratio; no individual
	# source node is rearranged or assigned renewal layout coordinates.
	var padding: Vector2=(canvas.size-_design_size*factor)/2.0
	_coordinates.position=padding+Vector2(0,_design_size.y*factor)
	_coordinates.scale=Vector2(factor,factor)

func _set_legacy_exp_visible(value: bool) -> void:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return
	for field: String in ["exp_bar","exp_readout"]:
		var item: Variant=hud.get(field)
		if item is CanvasItem and is_instance_valid(item):item.visible=value

func _remember(result: Dictionary) -> Dictionary:
	last_result=result.duplicate(true)
	return result

func _exit_tree() -> void:
	release(_restore_legacy)

func release(restore_legacy: bool=true) -> void:
	_restore_legacy=restore_legacy
	var canvas: Control=_canvas.get_ref() if _canvas!=null else null
	if canvas!=null and canvas.resized.is_connected(_fit_source_coordinates):canvas.resized.disconnect(_fit_source_coordinates)
	if is_instance_valid(_coordinates):
		_coordinates.visible=false
		_coordinates.process_mode=Node.PROCESS_MODE_DISABLED
		_coordinates.queue_free()
	_coordinates=null
	if restore_legacy:_set_legacy_exp_visible(true)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
