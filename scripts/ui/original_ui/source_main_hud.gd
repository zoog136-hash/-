extends Node
## Existing game's update_player -> original main HUD components. This node
## adds no gameplay logic or artwork. Component positions are read from the
## supplied MainScene, not from renewal_theme/reference_layout coordinates.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Vitals=preload("res://scripts/ui/original_ui/source_main_vitals_bindings.gd")
const Combat=preload("res://scripts/ui/original_ui/source_main_combat_bindings.gd")
const MainMenu=preload("res://scripts/ui/original_ui/source_main_menu_bindings.gd")
const Wallet=preload("res://scripts/ui/original_ui/source_main_wallet_bindings.gd")
const MainMap=preload("res://scripts/ui/original_ui/source_main_map_bindings.gd")
const Target=preload("res://scripts/ui/original_ui/source_main_target_bindings.gd")
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
var _combat: RefCounted
var _combat_scene: Node2D
var _menu: RefCounted
var _menu_scene: Node2D
var _combat_result: Dictionary={}
var _menu_result: Dictionary={}
var _core_attempted: bool=false
var _combat_availability: Dictionary={}
var _legacy_combat: Dictionary={}
var _legacy_shortcuts: Dictionary={}
var _wallet_scene: Node2D
var _wallet_result: Dictionary={}
var _wallet_mount_attempted: bool=false
var _gold: int=0
var _balances: Dictionary={}
var _map_bindings: RefCounted
var _map_name_scene: Node2D
var _map_name_result: Dictionary={}
var _map_name_mount_attempted: bool=false
var _legacy_map_name: WeakRef
var _legacy_map_name_visible: bool=false
var _target_scene: Node2D
var _target_result: Dictionary={}
var _target_model: Dictionary={}
var _target_mount_attempted: bool=false

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
	_capture_existing_controls(hud)
	var map_label: Variant=hud.get("v20_map_name")
	if map_label is CanvasItem and is_instance_valid(map_label):
		var label_parent: Node=map_label.get_parent()
		if label_parent is CanvasItem:
			_legacy_map_name=weakref(label_parent)
			var previous: Variant=hud.get("original_main_ui_controller")
			_legacy_map_name_visible=previous.source_map_label_availability() if is_instance_valid(previous) and previous.has_method("source_map_label_availability") else label_parent.visible
	_coordinates=Node2D.new()
	_coordinates.name="OriginalMainSourceCoordinates"
	_coordinates.z_index=35
	canvas.add_child(_coordinates)
	canvas.resized.connect(_fit_source_coordinates)
	_fit_source_coordinates()
	set_process(pack.manifest.get("scenes",{}).has(Target.MEMBER))
	return {"ok":true,"source_design_size":_design_size,"game_state_written":false,"complete_screen_contract":false}

func _process(_delta: float) -> void:
	if not is_instance_valid(_coordinates):return
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return
	var model: Dictionary=Target.selected_name(hud.get_parent())
	if not model.get("ok",false):
		_target_result=model
		return
	if model==_target_model:return
	_target_model=model.duplicate(true)
	if is_instance_valid(_target_scene):
		_target_result=Target.refresh(_target_scene,model)
		return
	if _target_mount_attempted:return
	_target_mount_attempted=true
	_target_result=_mount_main_project(15688,Target.build(_pack,model))
	if _target_result.get("ok",false):
		_target_scene=_target_result.scene
		_target_result.erase("scene")

func source_map_label_availability() -> bool:
	return _legacy_map_name_visible

func update_map_name(map_name: String) -> Dictionary:
	if not is_instance_valid(_coordinates):return _fail("source_main_not_configured")
	if is_instance_valid(_map_name_scene):
		_map_name_result=_map_bindings.refresh_name(_map_name_scene,map_name)
		return _map_name_result.duplicate(true)
	if _map_name_mount_attempted:return _map_name_result.duplicate(true)
	if not _pack.manifest.get("scenes",{}).has(MainMap.MINIMAP_MEMBER):return {"ok":true,"source_map_name_presented":false}
	_map_name_mount_attempted=true
	_map_bindings=MainMap.new()
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var configured: Dictionary=_map_bindings.configure(_pack,hud)
	if not configured.get("ok",false):
		_map_name_result=configured
		return configured
	_map_name_result=_mount_main_project(21588,_map_bindings.build_name(map_name))
	if _map_name_result.get("ok",false):
		_map_name_scene=_map_name_result.scene
		_map_name_result.erase("scene")
	sync_legacy_visibility()
	return _map_name_result.duplicate(true)

func update_player(level: int, hp: int, max_hp: int, mp: int, max_mp: int, experience_value: int, exp_need: int, gold: int) -> Dictionary:
	var unchanged: bool=_has_player_values and _exp_value==experience_value and _exp_need==exp_need
	var values: Dictionary={"hp":hp,"max_hp":max_hp,"mp":mp,"max_mp":max_mp,"level":level}
	var char_unchanged: bool=values==_char_values
	_char_values=values
	_exp_value=experience_value
	_exp_need=exp_need
	var gold_changed: bool=not _has_player_values or _gold!=gold
	_gold=gold
	_has_player_values=true
	if not is_instance_valid(_coordinates):return _fail("source_main_not_configured")
	if not is_instance_valid(_exp_scene):
		if not _exp_mount_attempted or last_result.get("ok",false):_mount_exp()
	elif not unchanged:last_result=Vitals.refresh_exp(_exp_scene,_exp_value,_exp_need)
	if _pack.manifest.get("scenes",{}).has(Vitals.CHAR_MEMBER):
		if not is_instance_valid(_char_scene):
			if not _char_mount_attempted:_mount_char_info()
		elif not char_unchanged:_char_result=Vitals.refresh_char_info(_char_scene,_char_values)
	if not _core_attempted:_mount_core_controls()
	_refresh_wallet(gold_changed)
	return {"ok":last_result.get("ok",false),"components":{"exp":last_result.duplicate(true),"hp_mp":_char_result.duplicate(true),"combat":_combat_result.duplicate(true),"menu":_menu_result.duplicate(true),"wallet":_wallet_result.duplicate(true),"map_name":_map_name_result.duplicate(true),"selected_target_name":_target_result.duplicate(true)},"complete_screen_contract":false,"game_state_written":false}

func update_currency_balances(balances: Dictionary) -> Dictionary:
	var changed: bool=_balances!=balances
	_balances=balances.duplicate(true)
	_refresh_wallet(changed)
	return _wallet_result.duplicate(true)

func _refresh_wallet(changed: bool) -> void:
	if not _has_player_values or not _balances.has("다이아") or not is_instance_valid(_coordinates):return
	if not _pack.manifest.get("scenes",{}).has(Wallet.MEMBER):return
	if is_instance_valid(_wallet_scene):
		if changed:_wallet_result=Wallet.refresh(_wallet_scene,_gold,_balances)
		return
	if _wallet_mount_attempted:return
	_wallet_mount_attempted=true
	var header: Dictionary=_pack.layout_source(HEADER)
	if header.get("_source_sha256")!=HEADER_SHA:
		_wallet_result=_fail("source_main_header_parent_identity_mismatch")
		return
	var contract: Dictionary=Wallet.build(_pack,_gold,_balances)
	if not contract.get("ok",false):
		_wallet_result=contract
		return
	var scene=Scene.new()
	var configured: Dictionary=scene.configure_project(_pack,HEADER,1540,contract.bindings,contract.source_node_offsets)
	if not configured.get("ok",false):
		scene.free()
		_wallet_result=configured
		return
	_coordinates.add_child(scene)
	_wallet_scene=scene
	_wallet_result={"ok":true,"source":Wallet.MEMBER,"source_parent":HEADER,"source_project":1540,"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false}

func _capture_existing_controls(hud: Node) -> void:
	var previous: Variant=hud.get("original_main_ui_controller")
	if is_instance_valid(previous) and previous.has_method("source_control_availability"):
		_combat_availability=previous.source_control_availability()
	var controls: Dictionary={
		"attack":hud.get_node_or_null("Root/RightControls/AttackButton"),
		"auto":hud.get("v20_auto_button"),
		"target":hud.get_node_or_null("Root/V20GameplayHUD/SelectTarget"),
		"self":hud.get("v20_self_button")
	}
	for kind: String in controls:
		var control: Variant=controls[kind]
		if control is CanvasItem and is_instance_valid(control):_legacy_combat[kind]=weakref(control)
		if not _combat_availability.has(kind):_combat_availability[kind]=control is CanvasItem and is_instance_valid(control) and control.visible
	for kind: String in ["inventory","skills","shop","menu"]:
		var control: Node=hud.get_node("Root").find_child("Shortcut_"+kind,true,false)
		if control is CanvasItem:_legacy_shortcuts[kind]=weakref(control)

func source_control_availability() -> Dictionary:
	return _combat_availability.duplicate(true)

func _mount_core_controls() -> void:
	_core_attempted=true
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return
	var world: Node=hud.get_parent()
	if _pack.manifest.get("scenes",{}).has(Combat.PAD):
		_combat=Combat.new()
		var configured: Dictionary=_combat.configure(_pack,hud,world)
		if configured.get("ok",false):
			var contract: Dictionary=_combat.build_core(_combat_availability)
			_combat_result=_mount_main_project(19912,contract)
			if _combat_result.get("ok",false):
				_combat_scene=_combat_result.scene
				_combat_result.erase("scene")
		else:
			_combat_result=configured
			if configured.get("code")=="source_main_combat_state_unavailable":_core_attempted=false
	if _pack.manifest.get("scenes",{}).has(MainMenu.MEMBER) and not is_instance_valid(_menu_scene):
		_menu=MainMenu.new()
		var configured: Dictionary=_menu.configure(_pack,hud)
		if configured.get("ok",false):
			_menu_result=_mount_main_project(13420,_menu.build_core())
			if _menu_result.get("ok",false):
				_menu_scene=_menu_result.scene
				_menu_result.erase("scene")
		else:_menu_result=configured
	sync_legacy_visibility()

func _mount_main_project(offset: int, contract: Dictionary) -> Dictionary:
	if not contract.get("ok",false):return contract
	var scene=Scene.new()
	var configured: Dictionary=scene.configure_project(_pack,MAIN,offset,contract.bindings,contract.source_node_offsets)
	if not configured.get("ok",false):
		scene.free()
		return configured
	_coordinates.add_child(scene)
	return {"ok":true,"scene":scene,"source":contract.member,"selected_source_offsets":contract.source_node_offsets.duplicate(),"partial_source_scene":true,"complete_screen_contract":false}

func refresh_combat() -> Dictionary:
	if _combat==null or not is_instance_valid(_combat_scene):return {"ok":true,"source_combat_presented":false}
	return _combat.refresh_presented(_combat_scene)

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
	var map_label: Object=_legacy_map_name.get_ref() if _legacy_map_name!=null else null
	if map_label!=null:map_label.visible=false if is_instance_valid(_map_name_scene) else _legacy_map_name_visible
	for kind: String in _legacy_combat:
		var control: Object=_legacy_combat[kind].get_ref()
		if control!=null:control.visible=false if is_instance_valid(_combat_scene) else bool(_combat_availability.get(kind,false))
	for kind: String in _legacy_shortcuts:
		var control: Object=_legacy_shortcuts[kind].get_ref()
		if control!=null:control.visible=not is_instance_valid(_menu_scene)

func _remember(result: Dictionary) -> Dictionary:
	last_result=result.duplicate(true)
	return result

func _exit_tree() -> void:
	release(_restore_legacy)

func release(restore_legacy: bool=true) -> void:
	_restore_legacy=restore_legacy
	set_process(false)
	var canvas: Control=_canvas.get_ref() if _canvas!=null else null
	if canvas!=null and canvas.resized.is_connected(_fit_source_coordinates):canvas.resized.disconnect(_fit_source_coordinates)
	if is_instance_valid(_coordinates):
		_coordinates.visible=false
		_coordinates.process_mode=Node.PROCESS_MODE_DISABLED
		_coordinates.queue_free()
	_coordinates=null
	if restore_legacy:
		var map_label: Object=_legacy_map_name.get_ref() if _legacy_map_name!=null else null
		if map_label!=null:map_label.visible=_legacy_map_name_visible
		_set_legacy_exp_visible(true)
		if is_instance_valid(_char_scene):_set_legacy_vitals_visible(true)
		for kind: String in _legacy_combat:
			var control: Object=_legacy_combat[kind].get_ref()
			if control!=null:control.visible=bool(_combat_availability.get(kind,false))
		for kind: String in _legacy_shortcuts:
			var control: Object=_legacy_shortcuts[kind].get_ref()
			if control!=null:control.visible=true

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
