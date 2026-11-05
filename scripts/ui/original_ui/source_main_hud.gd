extends Node
## Existing game's update_player -> original main HUD components. This node
## adds no gameplay logic or artwork. Component positions are read from the
## supplied MainScene, not from renewal_theme/reference_layout coordinates.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Vitals=preload("res://scripts/ui/original_ui/source_main_vitals_bindings.gd")
const MAIN="UI/MainScene.csb"
const MAIN_SHA="80c174a87caf5cfbf910336b64616334ac560ed477f7a663aec58ada70d4285f"
const EXP_PROJECT=23080
const HEADER="UI/HUDScene.csb"
const HEADER_SHA="969fbd4afc2897f7f6f19dc19abafc5960fb982abb4d24c7aa5c0576e8e16b09"
const HEADER_PROJECT=1800
var _pack: RefCounted
var _hud: WeakRef
var _canvas: WeakRef
var _coordinates: Node2D
var _exp_scene: Node2D
var _char_scene: Node2D
var _exp_value: int=0
var _exp_need: int=0
var _has_player_values: bool=false
var _exp_mount_attempted: bool=false
var _restore_legacy: bool=true
var _design_size: Vector2
var last_result: Dictionary={}
var _char_values: Dictionary={}
var _char_result: Dictionary={}
var _char_mount_attempted: bool=false

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

func update_player(_level: int, hp: int, max_hp: int, mp: int, max_mp: int, experience_value: int, exp_need: int, _gold: int) -> Dictionary:
	var unchanged: bool=_has_player_values and _exp_value==experience_value and _exp_need==exp_need
	var values: Dictionary={"hp":hp,"max_hp":max_hp,"mp":mp,"max_mp":max_mp}
	var char_unchanged: bool=values==_char_values
	_char_values=values
	_exp_value=experience_value
	_exp_need=exp_need
	_has_player_values=true
	if not is_instance_valid(_coordinates):return _fail("source_main_not_configured")
	if not is_instance_valid(_exp_scene):
		if not _exp_mount_attempted or last_result.get("ok",false):_mount_exp()
	elif not unchanged:last_result=Vitals.refresh_exp(_exp_scene,_exp_value,_exp_need)
	if _pack.manifest.get("scenes",{}).has(Vitals.CHAR_MEMBER):
		if not is_instance_valid(_char_scene):
			if not _char_mount_attempted:_mount_char_info()
		elif not char_unchanged:_char_result=Vitals.refresh_char_info(_char_scene,_char_values)
	return {"ok":last_result.get("ok",false),"components":{"exp":last_result.duplicate(true),"hp_mp":_char_result.duplicate(true)},"complete_screen_contract":false,"game_state_written":false}

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

func _mount_char_info() -> Dictionary:
	_char_mount_attempted=true
	var header: Dictionary=_pack.layout_source(HEADER) if _pack.has_method("layout_source") else {}
	if header.get("_source_sha256")!=HEADER_SHA:
		_char_result=_fail("source_main_header_parent_identity_mismatch")
		return _char_result
	var size_value: Variant=header.get("nodeTree",{}).get("options",{}).get("size")
	if not size_value is Array or size_value.size()!=2 or Vector2(float(size_value[0]),float(size_value[1]))!=_design_size:
		_char_result=_fail("source_main_header_coordinate_contract_mismatch")
		return _char_result
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var contract: Dictionary=Vitals.build_char_info(_pack,hud,_char_values)
	if not contract.get("ok",false):
		_char_result=contract
		return contract
	var scene=Scene.new()
	var configured: Dictionary=scene.configure_project(_pack,HEADER,HEADER_PROJECT,contract.bindings,contract.source_node_offsets)
	if not configured.get("ok",false):
		scene.free()
		_char_result=configured
		return configured
	_coordinates.add_child(scene)
	_char_scene=scene
	_set_legacy_vitals_visible(false)
	_char_result={"ok":true,"source":contract.member,"source_parent":HEADER,"source_project":HEADER_PROJECT,"selected_source_offsets":contract.source_node_offsets.duplicate(),"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false}
	return _char_result

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

func _set_legacy_vitals_visible(value: bool) -> void:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null:return
	for field: String in ["hp_bar","mp_bar","v20_hp_text","v20_mp_text"]:
		var item: Variant=hud.get(field)
		if item is CanvasItem and is_instance_valid(item):item.visible=value

func sync_legacy_visibility() -> void:
	# Replacing a multi-component selection with a smaller one must restore
	# only the fields no longer owned by an accepted original component.
	_set_legacy_exp_visible(not is_instance_valid(_exp_scene))
	_set_legacy_vitals_visible(not is_instance_valid(_char_scene))

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
	if restore_legacy:
		_set_legacy_exp_visible(true)
		if is_instance_valid(_char_scene):_set_legacy_vitals_visible(true)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
