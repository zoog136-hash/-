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
const WorldMap=preload("res://scripts/ui/original_ui/source_main_world_map.gd")
const InventoryView=preload("res://scripts/ui/original_ui/source_main_inventory_view.gd")
const InventoryImages=preload("res://scripts/ui/original_ui/source_main_inventory_images.gd")
const QuickslotView=preload("res://scripts/ui/original_ui/source_main_quickslot_view.gd")
const QuickslotImages=preload("res://scripts/ui/original_ui/source_main_quickslot_images.gd")
signal world_image_clicked(payload: Dictionary)
signal inventory_return_to_current_requested(reason: Dictionary)
signal inventory_closed
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
var _combat_owns_pickup: bool=false
var _world_map: Node
var _inventory_view: RefCounted
var _inventory_result: Dictionary={}
var _inventory_signature: int=0
var _quickslot_view: RefCounted
var _quickslot_result: Dictionary={}
var _legacy_quickslots: Array[Dictionary]=[]

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
	if pack.manifest.get("scenes",{}).has(QuickslotView.ROOT):
		var candidate=QuickslotView.new()
		_quickslot_result=candidate.configure(pack,hud,Callable(self,"_quickslot_original_image"))
		if _quickslot_result.get("ok",false):_quickslot_view=candidate
	if pack.manifest.get("scenes",{}).has(InventoryView.PARENT):
		var candidate=InventoryView.new()
		_inventory_result=candidate.configure(pack,hud,Callable(self,"_inventory_original_image"))
		if _inventory_result.get("ok",false):
			_inventory_view=candidate
			candidate.return_to_current_requested.connect(func(reason: Dictionary) -> void: inventory_return_to_current_requested.emit(reason))
			candidate.closed.connect(func() -> void: inventory_closed.emit())
	var pad_scope: Variant=pack.manifest.get("node_scopes",{}).get(Combat.PAD)
	var has_pickup: bool=pack.manifest.get("scenes",{}).has(Combat.PAD) and (not pad_scope is Array or pad_scope.has(Combat.PICKUP_GROUP))
	set_process(pack.manifest.get("scenes",{}).has(Target.MEMBER) or has_pickup or _inventory_view!=null)
	return {"ok":true,"source_design_size":_design_size,"game_state_written":false,"complete_screen_contract":false}

func _process(_delta: float) -> void:
	if not is_instance_valid(_coordinates):return
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return
	if inventory_is_open():
		var pointer: Variant=hud.get("pointer_transfer")
		if not is_instance_valid(pointer) or pointer.get("pointer")==-2:
			var signature: int=_inventory_model_signature()
			if signature!=_inventory_signature:
				_inventory_result=_inventory_view.refresh()
				_inventory_signature=_inventory_model_signature()
	if _combat_owns_pickup and _combat!=null and is_instance_valid(_combat_scene):_combat.refresh_pickup(_combat_scene)
	if not _pack.manifest.get("scenes",{}).has(Target.MEMBER):return
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

func _inventory_original_image(entry: Dictionary, native_context: Dictionary) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	return InventoryImages.resolve_owned(hud,entry,native_context)

func _quickslot_original_image(row: Dictionary, native_context: Dictionary) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	return QuickslotImages.resolve(hud,row,native_context)

func refresh_quickslots() -> Dictionary:
	if _quickslot_view==null:return {"ok":true,"handled":false,"code":"source_quickslot_pack_scope_unavailable"}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or not is_instance_valid(_coordinates):return _fail("source_quickslot_host_unavailable")
	var pointer: Variant=hud.get("pointer_transfer")
	if is_instance_valid(pointer) and pointer.get("pointer")!=-2:return {"ok":true,"handled":_quickslot_view.is_open(),"refresh_pending":true}
	_quickslot_result=_quickslot_view.refresh() if _quickslot_view.is_open() else _quickslot_view.open(_coordinates)
	sync_legacy_visibility()
	return _quickslot_result.duplicate(true)

func quickslot_hit_at(viewport_point: Vector2) -> Dictionary:
	return _quickslot_view.hit_at(viewport_point) if _quickslot_view!=null else {}

func quickslot_control(visible_index: int) -> Control:
	return _quickslot_view.control_for(visible_index) if _quickslot_view!=null else null

func quickslots_block_point(viewport_point: Vector2) -> bool:
	return _quickslot_view!=null and _quickslot_view.blocks_point(viewport_point)

func source_quickslot_availability() -> Array:
	var values: Array=[]
	for record: Dictionary in _legacy_quickslots:values.append(record.visible)
	return values

func try_open_inventory() -> Dictionary:
	if _inventory_view==null:return {"ok":false,"handled":false,"code":"source_inventory_original_pack_scope_unavailable"}
	if not is_instance_valid(_coordinates):return {"ok":false,"handled":false,"code":"source_main_not_configured"}
	_inventory_result=_inventory_view.open(_coordinates)
	if _inventory_result.get("handled",false):
		var presented: Dictionary=_inventory_view.presentation()
		var native_scene: Node2D=presented.get("scene")
		if is_instance_valid(native_scene):native_scene.z_index=150
		_inventory_signature=_inventory_model_signature()
	return _inventory_result.duplicate(true)

func inventory_is_open() -> bool:
	return _inventory_view!=null and _inventory_view.is_open()

func close_inventory() -> void:
	if _inventory_view!=null:_inventory_view.close()

func inventory_hit_at(viewport_point: Vector2) -> Dictionary:
	return _inventory_view.hit_at(viewport_point) if inventory_is_open() else {}

func inventory_blocks_point(viewport_point: Vector2) -> bool:
	return inventory_is_open() and _inventory_view.blocks_point(viewport_point)

func inventory_gesture_bounds() -> Control:
	return _inventory_view.gesture_bounds() if inventory_is_open() else null

func inventory_select(reference: String) -> Dictionary:
	return _inventory_view.select(reference) if inventory_is_open() else _fail("source_inventory_not_open")

func inventory_activate_selected(reference: String) -> Dictionary:
	return _inventory_view.activate_selected(reference) if inventory_is_open() else _fail("source_inventory_not_open")

func _inventory_model_signature() -> int:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var bag: Variant=hud.get("lineage_inventory_ui") if hud!=null else null
	if not is_instance_valid(bag):return 0
	var search: Variant=bag.get("search_line")
	var grid: Variant=bag.get("item_grid")
	var state: Variant=bag.get("character_state")
	return hash([bag.get("inventory_grid_dirty"),bag.get("inventory_list_rebuilds"),bag.get("category_filter"),bag.get("selected_item"),bag.get("detail_active"),search.text if search is LineEdit else "",grid.columns if grid is GridContainer else 0,state.get("gold") if state is Dictionary else null,state.get("current_weight") if state is Dictionary else null,state.get("max_weight") if state is Dictionary else null,state.get("carrying_capacity") if state is Dictionary else null,state.get("equipped_items") if state is Dictionary else null,state.get("equipped_ammo") if state is Dictionary else null,state.get("item_locks") if state is Dictionary else null])

func bind_world_map(image_adapter: RefCounted, context_provider: Callable, input_handler: Callable) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or not is_instance_valid(_coordinates):return _fail("source_main_not_configured")
	var candidate=WorldMap.new()
	var configured: Dictionary=candidate.configure(_pack,hud,_coordinates,image_adapter,context_provider,input_handler)
	if not configured.get("ok",false):
		candidate.free()
		return configured
	if is_instance_valid(_world_map):
		_world_map.close()
		_world_map.queue_free()
	_world_map=candidate
	add_child(candidate)
	candidate.world_image_clicked.connect(func(payload: Dictionary) -> void: world_image_clicked.emit(payload))
	return configured

func has_world_map_binding() -> bool:
	return is_instance_valid(_world_map)

func world_map_is_open() -> bool:
	return is_instance_valid(_world_map) and _world_map.is_open()

func toggle_world_map() -> Dictionary:
	if not is_instance_valid(_world_map):return _fail("source_world_map_not_configured")
	return _world_map.toggle()

func close_world_map() -> Dictionary:
	if not is_instance_valid(_world_map):return {"ok":true,"closed":true}
	return _world_map.close()

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
	var previous_quickslots: Array=previous.source_quickslot_availability() if is_instance_valid(previous) and previous.has_method("source_quickslot_availability") else []
	var buttons: Variant=hud.get("v20_quickslot_buttons")
	if buttons is Array:
		for index: int in range(buttons.size()):
			var button: Variant=buttons[index]
			if button is CanvasItem and is_instance_valid(button):_legacy_quickslots.append({"control":weakref(button),"visible":bool(previous_quickslots[index]) if index<previous_quickslots.size() else button.visible})
	if is_instance_valid(previous) and previous.has_method("source_control_availability"):
		_combat_availability=previous.source_control_availability()
	var controls: Dictionary={
		"attack":hud.get_node_or_null("Root/RightControls/AttackButton"),
		"auto":hud.get("v20_auto_button"),
		"target":hud.get_node_or_null("Root/V20GameplayHUD/SelectTarget"),
		"self":hud.get("v20_self_button")
	}
	var pickup: Variant=hud.get_parent().get("loot_pickup")
	if is_instance_valid(pickup):controls["pickup"]=pickup.get("pickup_button")
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
				_combat_owns_pickup=_combat_scene.get("source_nodes").has(Combat.PICKUP_BUTTON)
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

func refresh_menu_state() -> Dictionary:
	if _menu==null or not is_instance_valid(_menu_scene):return {"ok":true,"source_menu_presented":false}
	return _menu.refresh_presented(_menu_scene)

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
	for record: Dictionary in _legacy_quickslots:
		var control: Object=record.control.get_ref()
		if control!=null:control.visible=false if _quickslot_view!=null and _quickslot_view.is_open() else record.visible
	var map_label: Object=_legacy_map_name.get_ref() if _legacy_map_name!=null else null
	if map_label!=null:map_label.visible=false if is_instance_valid(_map_name_scene) else _legacy_map_name_visible
	for kind: String in _legacy_combat:
		var control: Object=_legacy_combat[kind].get_ref()
		var owned: bool=is_instance_valid(_combat_scene) and (kind!="pickup" or _combat_owns_pickup)
		if control!=null:control.visible=false if owned else bool(_combat_availability.get(kind,false))
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
	if is_instance_valid(_world_map):_world_map.close()
	close_inventory()
	if _quickslot_view!=null:_quickslot_view.close()
	var canvas: Control=_canvas.get_ref() if _canvas!=null else null
	if canvas!=null and canvas.resized.is_connected(_fit_source_coordinates):canvas.resized.disconnect(_fit_source_coordinates)
	if is_instance_valid(_coordinates):
		_coordinates.visible=false
		_coordinates.process_mode=Node.PROCESS_MODE_DISABLED
		_coordinates.queue_free()
	_coordinates=null
	if restore_legacy:
		for record: Dictionary in _legacy_quickslots:
			var control: Object=record.control.get_ref()
			if control!=null:control.visible=record.visible
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
