extends Node
## Existing game's update_player -> original main HUD components. This node
## adds no gameplay logic or artwork. Component positions are read from the
## supplied MainScene, not from renewal_theme/reference_layout coordinates.
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const MENU_TRACE = preload("res://scripts/boot/menu_memory_trace.gd")
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Vitals=preload("res://scripts/ui/original_ui/source_main_vitals_bindings.gd")
const Combat=preload("res://scripts/ui/original_ui/source_main_combat_bindings.gd")
const MainMenu=preload("res://scripts/ui/original_ui/source_main_menu_bindings.gd")
const Wallet=preload("res://scripts/ui/original_ui/source_main_wallet_bindings.gd")
const Blessing=preload("res://scripts/ui/original_ui/source_main_blessing_bindings.gd")
const DungeonControls=preload("res://scripts/ui/original_ui/source_main_dungeon_controls.gd")
const WorkspaceControls=preload("res://scripts/ui/original_ui/source_main_workspace_controls.gd")
const MainMap=preload("res://scripts/ui/original_ui/source_main_map_bindings.gd")
const Target=preload("res://scripts/ui/original_ui/source_main_target_bindings.gd")
const WorldMap=preload("res://scripts/ui/original_ui/source_main_world_map.gd")
const InventoryView=preload("res://scripts/ui/original_ui/source_main_inventory_view.gd")
const InventoryImages=preload("res://scripts/ui/original_ui/source_main_inventory_images.gd")
const QuickslotView=preload("res://scripts/ui/original_ui/source_main_quickslot_view.gd")
const QuickslotImages=preload("res://scripts/ui/original_ui/source_main_quickslot_images.gd")
const PrimaryStats=preload("res://scripts/ui/original_ui/source_main_primary_stats.gd")
const ButtonRouter=preload("res://scripts/ui/original_ui/source_button_router.gd")
const AutoMessage=preload("res://scripts/ui/original_ui/source_main_auto_message_bindings.gd")
const CharacterView=preload("res://scripts/ui/original_ui/source_main_character_view.gd")
const NpcDialogueView=preload("res://scripts/ui/original_ui/source_main_npc_dialogue_view.gd")
const SystemMessage=preload("res://scripts/ui/original_ui/source_main_system_message_bindings.gd")
const InventoryNameView=preload("res://scripts/ui/original_ui/source_main_inventory_name_view.gd")
const EnhanceAction=preload("res://scripts/ui/original_ui/source_main_enhance_action.gd")
const QuestControls=preload("res://scripts/ui/original_ui/source_main_quest_controls.gd")
const QuestWindow=preload("res://scripts/ui/original_ui/source_main_quest_window.gd")
const ShopWindow=preload("res://scripts/ui/original_ui/source_main_shop_window.gd")
const ChangeWindow=preload("res://scripts/ui/original_ui/source_main_change_window.gd")
const InventoryLockView=preload("res://scripts/ui/original_ui/source_main_inventory_lock_view.gd")
const JoystickView=preload("res://scripts/ui/original_ui/source_main_joystick_view.gd")
const LOG_BASE_META="source_joystick_log_base"
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
var _blessing_scene: Node2D
var _blessing_result: Dictionary={}
var _blessing_model: Dictionary={}
var _blessing_mount_attempted: bool=false
var _blessing_info_in_scope: bool=false
var _legacy_blessing: Array[Dictionary]=[]
var _dungeon_controls: RefCounted
var _workspace_controls: RefCounted
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
var _icons_refresh_pending: bool=false
var _primary_stats_scene: Node2D
var _primary_stats_result: Dictionary={}
var _primary_stats_model: Dictionary={}
var _primary_stats_attempted: bool=false
var _native_buttons: RefCounted
var _auto_message: RefCounted
var _auto_message_scene: Node2D
var _auto_message_result: Dictionary={}
var _auto_message_model: Dictionary={}
var _character_view: RefCounted
var _character_result: Dictionary={}
var _npc_dialogue_view: RefCounted
var _npc_dialogue_result: Dictionary={}
var _system_message_priority: int=0
var _system_message_rendered_priority: int=0
var _system_message_routing: Dictionary={}
var _system_message_scene: Node2D
var _system_message_result: Dictionary={}
var _system_message_model: Dictionary={}
var _legacy_message: WeakRef
var _legacy_message_visible: bool=false
var _inventory_name_view: RefCounted
var _inventory_name_result: Dictionary={}
var _enhance_action: RefCounted
var _enhance_action_result: Dictionary={}
var _enhance_owner: WeakRef
var _enhance_listing: WeakRef
var _quest_controls: RefCounted
var _quest_window: RefCounted
var _shop_window: RefCounted
var _change_window: RefCounted
var _quest_controls_result: Dictionary={}
var _quest_owner: WeakRef
var _inventory_lock_view: RefCounted
var _inventory_lock_result: Dictionary={}
var _joystick_view: RefCounted
var _joystick_result: Dictionary={}
# Existing TWILIGHT chrome that an accepted original component replaces:
# {"control":WeakRef,"owner":String,"property":"visible"|"self_alpha","value":Variant}
var _legacy_chrome: Array[Dictionary]=[]

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
	var message: Variant=hud.get("message_label")
	if message is Label and is_instance_valid(message):
		_legacy_message=weakref(message)
		var previous: Variant=hud.get("original_main_ui_controller")
		_legacy_message_visible=previous.source_message_label_availability() if is_instance_valid(previous) and previous.has_method("source_message_label_availability") else message.visible
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
	_native_buttons=ButtonRouter.new()
	_open_joystick(hud)
	for spec: Dictionary in WorkspaceControls.SPECS.values():
		if pack.manifest.get("scenes",{}).has(spec.member):
			_workspace_controls=WorkspaceControls.new()
			_workspace_controls.configure(pack,hud)
			break
	if pack.manifest.get("scenes",{}).has(DungeonControls.MEMBER):
		_dungeon_controls=DungeonControls.new()
		_dungeon_controls.configure(pack,hud)
	if not get_window().focus_exited.is_connected(_cancel_native_buttons):get_window().focus_exited.connect(_cancel_native_buttons)
	if pack.manifest.get("scenes",{}).has(QuickslotView.ROOT):
		var candidate=QuickslotView.new()
		_quickslot_result=candidate.configure(pack,hud,Callable(self,"_quickslot_original_image"))
		if _quickslot_result.get("ok",false):_quickslot_view=candidate
	if pack.manifest.get("scenes",{}).has(InventoryView.PARENT):
		var candidate=InventoryView.new()
		_inventory_result=candidate.configure(pack,hud,Callable(self,"_inventory_original_image"))
		if _inventory_result.get("ok",false):
			_inventory_view=candidate
			candidate.return_to_current_requested.connect(_inventory_view_fallback)
			candidate.closed.connect(_inventory_view_closed)
	if pack.manifest.get("scenes",{}).has("UI/ToolTip/ToolTip_HudType_Right.csb"):
		var bag: Variant=hud.get("lineage_inventory_ui")
		if bag is Control and is_instance_valid(bag):
			var candidate=InventoryNameView.new()
			_inventory_name_result=candidate.configure(pack,bag)
			if _inventory_name_result.get("ok",false):_inventory_name_view=candidate
			var lock_view=InventoryLockView.new()
			_inventory_lock_result=lock_view.configure(pack,bag)
			if _inventory_lock_result.get("ok",false):_inventory_lock_view=lock_view
	if pack.manifest.get("scenes",{}).has(CharacterView.ALL):
		var candidate=CharacterView.new()
		_character_result=candidate.configure(pack,hud,Callable(self,"_equipment_original_image"))
		if _character_result.get("ok",false):
			_character_view=candidate
			candidate.closed.connect(func() -> void:
				if hud.has_method("_close_workspace"):hud.call("_close_workspace"))
			candidate.return_to_equipment_requested.connect(func() -> void:
				var side: Variant=hud.get("lineage_side_ui")
				if is_instance_valid(side):side.call("_show_equipment_page")
				hud.call("open_character"))
	if pack.manifest.get("scenes",{}).has(QuestWindow.ROOT):
		var quest_window=QuestWindow.new()
		if quest_window.configure(pack,hud).get("ok",false):
			_quest_window=quest_window
			quest_window.closed.connect(func() -> void:
				if hud.has_method("_close_workspace"):hud.call("_close_workspace"))
	if pack.manifest.get("scenes",{}).has(ShopWindow.ROOT):
		var shop_window=ShopWindow.new()
		if shop_window.configure(pack,hud).get("ok",false):
			_shop_window=shop_window
			shop_window.closed.connect(func() -> void:
				if hud.has_method("_close_workspace"):hud.call("_close_workspace"))
	if pack.manifest.get("scenes",{}).has(ChangeWindow.ROOT):
		var change_window=ChangeWindow.new()
		if change_window.configure(pack,hud).get("ok",false):
			_change_window=change_window
			change_window.closed.connect(func() -> void:
				if hud.has_method("_close_workspace"):hud.call("_close_workspace"))
	if pack.manifest.get("scenes",{}).has("UI/NpcDialogue/NpcDialogue_All.csb"):
		_npc_dialogue_view=NpcDialogueView.new()
		_npc_dialogue_view.configure(pack)
		_npc_dialogue_view.closed.connect(func() -> void:
			if hud.has_method("_close_workspace"):hud.call("_close_workspace"))
	var pad_scope: Variant=pack.manifest.get("node_scopes",{}).get(Combat.PAD)
	var has_pickup: bool=pack.manifest.get("scenes",{}).has(Combat.PAD) and (not pad_scope is Array or pad_scope.has(Combat.PICKUP_GROUP))
	set_process(pack.manifest.get("scenes",{}).has(Target.MEMBER) or has_pickup or _inventory_view!=null or pack.manifest.get("scenes",{}).has(AutoMessage.MEMBER) or pack.manifest.get("scenes",{}).has(Blessing.MEMBER) or _dungeon_controls!=null or _workspace_controls!=null or pack.manifest.get("files",{}).has(SystemMessage.PARENT_MEMBER) or _joystick_view!=null)
	return {"ok":true,"source_design_size":_design_size,"game_state_written":false,"complete_screen_contract":false}

func _input(event: InputEvent) -> void:
	if _native_buttons==null or (not event is InputEventScreenTouch and not event is InputEventScreenDrag):return
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or not is_instance_valid(_coordinates):return
	# The map has its own original-row/scroll input controller. Existing
	# modal/keyboard guards and PointerTransfer capture retain precedence.
	var crafting_search: bool=crafting_search_is_open()
	if inventory_search_is_open() or crafting_search:
		for property: String in ["detail_window","companion_window","workspace"]:
			if crafting_search and property=="workspace":continue
			var overlay: Variant=hud.get(property)
			if overlay is Control and overlay.is_visible_in_tree() and Rect2(Vector2.ZERO,overlay.size).has_point(overlay.get_global_transform_with_canvas().affine_inverse()*event.position):
				_cancel_native_buttons()
				return
		var search: Dictionary=_workspace_controls.search_presentation() if crafting_search else _inventory_view.search_presentation()
		var editor: Variant=search.get("editor")
		var blocked: bool=not editor is Control or hud.get("class_picker_initial")==true or hud.call("blocks_keyboard_input_except_source_editor",editor)
		if blocked:
			_cancel_native_buttons()
			return
		var buttons: Array=[]
		if is_instance_valid(search.get("scene")):_collect_native_buttons(search.scene,buttons)
		var routed: Dictionary=_native_buttons.route(event,event.position,buttons)
		if not routed.get("handled",false) and event is InputEventScreenTouch and event.pressed and not event.canceled:
			if crafting_search:_workspace_controls.focus_search_at(event.position)
			else:_inventory_view.focus_search_at(event.position)
		# The source popup owns this gesture; it cannot reach a slot/world.
		get_viewport().set_input_as_handled()
		return
	# A current workspace filter may keep keyboard focus while its source
	# buttons are touched. Ignore that focus alone, retaining every real
	# death/result/modal/PointerTransfer guard, and route only these controls.
	var focused: Control=get_viewport().gui_get_focus_owner()
	if (focused is LineEdit or focused is TextEdit) and not world_map_is_open() and hud.get("class_picker_initial")!=true:
		var workspace: Variant=hud.get("workspace")
		if workspace is Control and workspace.is_visible_in_tree() and workspace.is_ancestor_of(focused) and not hud.call("blocks_keyboard_input_except_source_editor",focused):
			var obscured: bool=false
			for property: String in ["detail_window","companion_window"]:
				var overlay: Variant=hud.get(property)
				if overlay is Control and overlay.is_visible_in_tree() and Rect2(Vector2.ZERO,overlay.size).has_point(overlay.get_global_transform_with_canvas().affine_inverse()*event.position):obscured=true
			if not obscured and _route_workspace_source_actions(event,event.position):return
	if world_map_is_open() or hud.get("class_picker_initial")==true or (hud.has_method("blocks_keyboard_input") and hud.call("blocks_keyboard_input")):
		_cancel_native_buttons()
		return
	var candidates: Array=[]
	var point: Vector2=event.position
	for property: String in ["detail_window","companion_window","workspace"]:
		var overlay: Variant=hud.get(property)
		if overlay is Control and overlay.is_visible_in_tree() and Rect2(Vector2.ZERO,overlay.size).has_point(overlay.get_global_transform_with_canvas().affine_inverse()*point):
			if property=="workspace" and _route_workspace_source_actions(event,point):return
			_cancel_native_buttons()
			return
	var character_inside: bool=character_blocks_point(point)
	if npc_dialogue_is_open():
		var dialogue: Dictionary=_npc_dialogue_view.presentation()
		if is_instance_valid(dialogue.get("scene")):_collect_native_buttons(dialogue.scene,candidates)
	elif character_inside:
		var character: Dictionary=_character_view.presentation()
		if is_instance_valid(character.get("scene")):_collect_native_buttons(character.scene,candidates)
	elif inventory_is_open() and inventory_blocks_point(point):
		if _inventory_name_view!=null and _inventory_name_view.is_open():
			var name_hint: Dictionary=_inventory_name_view.presentation()
			if is_instance_valid(name_hint.get("scene")):_collect_native_buttons(name_hint.scene,candidates)
		var inventory: Dictionary=_inventory_view.presentation()
		if is_instance_valid(inventory.get("scene")):_collect_native_buttons(inventory.scene,candidates)
	else:
		_collect_native_buttons(_coordinates,candidates)
	var routed: Dictionary=_native_buttons.route(event,point,candidates)
	if routed.get("handled",false) or character_inside or npc_dialogue_is_open():get_viewport().set_input_as_handled()

static func _collect_native_buttons(node: Node, found: Array) -> void:
	if node is CanvasItem and not node.is_visible_in_tree():return
	if node.is_queued_for_deletion() or node.has_meta("source_asset_scene"):return
	var identity: Variant=node.get_meta("original_ui_source",{})
	if identity is Dictionary and identity.get("scene") in ["UI/CommonUi/Common_Slot.csb","UI/MainFloating/Slot_Skill.csb"]:return
	# Reverse source child order follows the current native presentation. The
	# original item/quickslot controls remain exclusively PointerTransfer's.
	var children: Array[Node]=node.get_children()
	children.reverse()
	for child: Node in children:_collect_native_buttons(child,found)
	var button: Variant=node.get_meta("source_button",null)
	if is_instance_valid(button):found.append(button)

func _cancel_native_buttons() -> void:
	if _native_buttons!=null:_native_buttons.cancel()

func _route_workspace_source_actions(event: InputEvent, point: Vector2) -> bool:
	var buttons: Array=[]
	if _workspace_controls!=null:
		var shown: Dictionary=_workspace_controls.presentation()
		if is_instance_valid(shown.get("scene")):_collect_native_buttons(shown.scene,buttons)
	if _enhance_action!=null:
		var shown: Dictionary=_enhance_action.presentation()
		var button: Variant=shown.get("source_button")
		if is_instance_valid(button):buttons.append(button)
	if _quest_controls!=null:
		var shown: Dictionary=_quest_controls.presentation()
		if is_instance_valid(shown.get("scene")):_collect_native_buttons(shown.scene,buttons)
	if _inventory_lock_view!=null:
		var shown: Dictionary=_inventory_lock_view.presentation()
		if is_instance_valid(shown.get("scene")):_collect_native_buttons(shown.scene,buttons)
	var routed: Dictionary=_native_buttons.route(event,point,buttons)
	if routed.get("handled",false):
		get_viewport().set_input_as_handled()
		return true
	return false

func _source_input_captured(hud: Node) -> bool:
	var pointer: Variant=hud.get("pointer_transfer")
	return (_native_buttons!=null and _native_buttons.is_capturing()) or (is_instance_valid(pointer) and pointer.get("pointer")!=-2)

func _process(_delta: float) -> void:
	var hitch_started: int = FRAME_HITCH.now()
	var hitch_nested: int = FRAME_HITCH.nested()
	_process_step(_delta)
	FRAME_HITCH.add_self("hud_main", hitch_started, hitch_nested)

func _process_step(_delta: float) -> void:
	if not is_instance_valid(_coordinates):return
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return
	if _joystick_view!=null:_joystick_view.refresh()
	if _pack.manifest.get("scenes",{}).has(Blessing.MEMBER):_refresh_blessing(hud)
	if _dungeon_controls!=null:_dungeon_controls.refresh(_coordinates)
	if _workspace_controls!=null:_workspace_controls.refresh(_coordinates)
	if is_instance_valid(_char_scene):Vitals.refresh_poison(_char_scene,hud)
	if _icons_refresh_pending:refresh_quickslots()
	if _pack.manifest.get("scenes",{}).has(AutoMessage.MEMBER):_refresh_auto_message()
	if _system_message_priority!=0:refresh_system_message()
	if inventory_is_open():
		if not _source_input_captured(hud):
			var signature: int=_inventory_model_signature()
			if signature!=_inventory_signature:
				_inventory_result=_inventory_view.refresh()
				_inventory_signature=_inventory_model_signature()
	if _inventory_name_view!=null and not _source_input_captured(hud):
		if inventory_is_open():_inventory_name_result=_inventory_name_view.refresh(_coordinates)
		else:_inventory_name_view.close()
	if _inventory_lock_view!=null and not _source_input_captured(hud):
		_inventory_lock_result=_inventory_lock_view.refresh(_coordinates)
		var shown: Dictionary=_inventory_lock_view.presentation()
		var workspace: Variant=hud.get("workspace")
		var bag: Variant=hud.get("lineage_inventory_ui")
		if is_instance_valid(shown.get("scene")) and workspace is CanvasItem and bag is CanvasItem:
			shown.scene.z_as_relative=false
			shown.scene.z_index=workspace.z_index+bag.z_index+1
	if _enhance_action!=null:
		_enhance_action_result=_enhance_action.refresh()
		if not _enhance_action_result.get("ok",false):_enhance_action=null
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
	return InventoryImages.resolve_owned(hud,entry,_native_icon_context(native_context))

func _equipment_original_image(record: Dictionary, native_context: Dictionary) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	var name: String=str(record.get("name",""))
	return InventoryImages.resolve_owned(hud,{"name":name,"reference":name,"record":record},_native_icon_context(native_context))

func try_open_character_equipment() -> Dictionary:
	if _character_view==null or not is_instance_valid(_coordinates):return _fail("source_character_original_view_not_available")
	var trace: int=MENU_TRACE.begin("character")
	_cancel_native_buttons()
	_character_result=_character_view.open_equipment(_coordinates)
	MENU_TRACE.end(trace,_character_result.get("ok",false))
	return _character_result.duplicate(true)

func _quickslot_original_image(row: Dictionary, native_context: Dictionary) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	return QuickslotImages.resolve(hud,row,_native_icon_context(native_context))

func _native_icon_context(context: Dictionary) -> Dictionary:
	var result: Dictionary=context.duplicate(true)
	result["source_slot_contract"]=Scene.external_scene_slot_contract(_pack,str(context.get("member","")),int(context.get("node_offset",-1)))
	return result

func refresh_source_icons() -> Dictionary:
	_icons_refresh_pending=true
	return refresh_quickslots()

func try_open_character_stats() -> Dictionary:
	if _character_view==null or not is_instance_valid(_coordinates):return _fail("source_character_original_view_not_available")
	var trace: int=MENU_TRACE.begin("character")
	_cancel_native_buttons()
	_character_result=_character_view.open_stats(_coordinates)
	MENU_TRACE.end(trace,_character_result.get("ok",false))
	return _character_result.duplicate(true)

func character_is_open() -> bool:
	return _character_view!=null and _character_view.is_open()

func character_blocks_point(point: Vector2) -> bool:
	return character_is_open() and _character_view.blocks_point(point)

func close_character() -> void:
	_cancel_native_buttons()
	if _character_view!=null:_character_view.close()
	_character_result.clear()
	_release_menu_page_leases()

func refresh_character_stats() -> Dictionary:
	if not character_is_open():return {"ok":true,"handled":false}
	_character_result=_character_view.refresh()
	if not _character_result.get("ok",false):
		var hud: Object=_hud.get_ref() if _hud!=null else null
		if hud!=null:hud.call("open_character")
	return _character_result.duplicate(true)

func try_open_npc_dialogue(owner: Control, resolved: Dictionary) -> Dictionary:
	if _npc_dialogue_view==null or not is_instance_valid(_coordinates):return _fail("source_npc_dialogue_original_view_not_available")
	_cancel_native_buttons()
	_npc_dialogue_result=_npc_dialogue_view.open(_coordinates,owner,resolved)
	return _npc_dialogue_result.duplicate(true)

func npc_dialogue_is_open() -> bool:
	return _npc_dialogue_view!=null and _npc_dialogue_view.is_open()

func bind_npc_dialogue_portrait(context_provider: Callable, image_provider: Callable) -> Dictionary:
	if _npc_dialogue_view==null:return _fail("source_npc_portrait_dialogue_scope_unavailable")
	return _npc_dialogue_view.bind_portrait(context_provider,image_provider)

func bind_enhance_action(forge: Control) -> Dictionary:
	close_enhance_action()
	if _pack==null:return _fail("source_enhance_action_original_pack_unavailable")
	if not _pack.manifest.get("scenes",{}).has(EnhanceAction.MEMBER):return {"ok":true,"handled":false,"code":"source_enhance_action_pack_scope_unavailable"}
	if not is_instance_valid(forge) or not is_instance_valid(_coordinates):return _fail("source_enhance_action_existing_owner_and_mount_required")
	_enhance_owner=weakref(forge)
	var listing: Variant=forge.get("listing")
	if listing is ItemList and is_instance_valid(listing):
		_enhance_listing=weakref(listing)
		listing.item_selected.connect(_enhance_selection_changed)
	return _mount_enhance_action(forge)

func bind_quest_controls(owner: Control) -> Dictionary:
	close_quest_controls()
	if _pack==null or not _pack.manifest.get("scenes",{}).has(QuestControls.MEMBER):return {"ok":true,"handled":false,"code":"source_quest_controls_pack_scope_unavailable"}
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null or not is_instance_valid(_coordinates):return _fail("source_quest_controls_actual_host_required")
	var candidate=QuestControls.new()
	_quest_controls_result=candidate.configure(_pack,hud,owner,_coordinates)
	if _quest_controls_result.get("ok",false):
		_quest_controls=candidate
		_quest_owner=weakref(owner)
		if owner.has_signal("source_category_changed"):owner.connect("source_category_changed",_quest_category_changed)
		var shown: Dictionary=candidate.presentation()
		var workspace: Variant=hud.get("workspace")
		if is_instance_valid(shown.get("scene")) and workspace is CanvasItem:
			shown.scene.z_as_relative=false
			shown.scene.z_index=workspace.z_index+1
	return _quest_controls_result.duplicate(true)

func _quest_category_changed(_category: String) -> void:
	if _quest_controls!=null:_quest_controls_result=_quest_controls.refresh()

func try_open_quest_window(world: Node, claim: Callable) -> Dictionary:
	if _quest_window==null or not is_instance_valid(_coordinates):return _fail("source_quest_window_pack_scope_unavailable")
	_cancel_native_buttons()
	return _quest_window.open(_coordinates,world,claim)

func can_open_shop_window() -> bool:
	return _shop_window!=null and is_instance_valid(_coordinates)

func try_open_shop_window(panel: Control) -> Dictionary:
	if not can_open_shop_window():return _fail("source_shop_window_pack_scope_unavailable")
	var trace: int=MENU_TRACE.begin("shop")
	_cancel_native_buttons()
	var result: Dictionary=_shop_window.open(_coordinates,panel)
	MENU_TRACE.end(trace,result.get("ok",false))
	return result

func shop_window_is_open() -> bool:
	return _shop_window!=null and _shop_window.is_open()

func close_shop_window() -> void:
	_cancel_native_buttons()
	if _shop_window!=null:_shop_window.close()
	_release_menu_page_leases()

func try_open_change_window(category: String) -> Dictionary:
	if _change_window==null or not is_instance_valid(_coordinates):return _fail("source_change_window_pack_scope_unavailable")
	var trace: int=MENU_TRACE.begin("change")
	_cancel_native_buttons()
	var result: Dictionary=_change_window.open(_coordinates,category)
	MENU_TRACE.end(trace,result.get("ok",false))
	return result

func change_window_is_open() -> bool:
	return _change_window!=null and _change_window.is_open()

func close_change_window() -> void:
	_cancel_native_buttons()
	if _change_window!=null:_change_window.close()
	_release_menu_page_leases()

func quest_window_is_open() -> bool:
	return _quest_window!=null and _quest_window.is_open()

func refresh_quest_window() -> Dictionary:
	return _quest_window.refresh() if quest_window_is_open() else {"ok":true,"handled":false}

func close_quest_window() -> void:
	_cancel_native_buttons()
	if _quest_window!=null:_quest_window.close()
	_release_menu_page_leases()

func close_quest_controls() -> void:
	_cancel_native_buttons()
	var owner: Object=_quest_owner.get_ref() if _quest_owner!=null else null
	if is_instance_valid(owner) and owner.has_signal("source_category_changed") and owner.is_connected("source_category_changed",_quest_category_changed):owner.disconnect("source_category_changed",_quest_category_changed)
	_quest_owner=null
	if _quest_controls!=null:_quest_controls.close()
	_quest_controls=null
	_quest_controls_result.clear()
	_release_menu_page_leases()

func _mount_enhance_action(forge: Control) -> Dictionary:
	if _enhance_action!=null:_enhance_action.close()
	_enhance_action=null
	var candidate=EnhanceAction.new()
	_enhance_action_result=candidate.configure(_pack,forge,_coordinates)
	if _enhance_action_result.get("ok",false):
		_enhance_action=candidate
		set_process(true)
		var shown: Dictionary=candidate.presentation()
		var hud: Object=_hud.get_ref() if _hud!=null else null
		var workspace: Variant=hud.get("workspace") if hud!=null else null
		if is_instance_valid(shown.get("scene")) and workspace is CanvasItem:
			# Host the authored source button above this existing workspace,
			# while its existing companion/detail/modal windows retain priority.
			shown.scene.z_as_relative=false
			shown.scene.z_index=workspace.z_index+1
	return _enhance_action_result.duplicate(true)

func _enhance_selection_changed(_index: int) -> void:
	var forge: Object=_enhance_owner.get_ref() if _enhance_owner!=null else null
	if forge is Control:_mount_enhance_action(forge)

func close_enhance_action() -> void:
	_cancel_native_buttons()
	if _enhance_action!=null:_enhance_action.close()
	_enhance_action=null
	var listing: Object=_enhance_listing.get_ref() if _enhance_listing!=null else null
	if is_instance_valid(listing) and listing.item_selected.is_connected(_enhance_selection_changed):listing.item_selected.disconnect(_enhance_selection_changed)
	_enhance_listing=null
	_enhance_owner=null

func close_npc_dialogue() -> void:
	_cancel_native_buttons()
	if _npc_dialogue_view!=null:_npc_dialogue_view.close()
	_release_menu_page_leases()

func source_message_label_availability() -> bool:
	return _legacy_message_visible

func set_system_message_priority(priority: int, routing_basis: Dictionary) -> Dictionary:
	if priority not in [1,2]:return _fail("source_system_message_explicit_priority_1_or_2_required")
	if routing_basis.is_empty():return _fail("source_system_message_explicit_routing_basis_required")
	if _system_message_priority!=priority:_system_message_model.clear()
	_system_message_priority=priority
	_system_message_routing=routing_basis.duplicate(true)
	return refresh_system_message()

func refresh_system_message() -> Dictionary:
	if _system_message_priority==0:return {"ok":true,"handled":false}
	var hud: Object=_hud.get_ref() if _hud!=null else null
	if hud==null or not is_instance_valid(_coordinates):return _fail("source_system_message_existing_host_unavailable")
	var current: Dictionary=SystemMessage.snapshot(hud)
	if not current.get("ok",false):return _system_message_failed(current)
	var model: Dictionary={"priority":_system_message_priority,"text":current.text}
	if model==_system_message_model:
		_system_message_result["priority_routing"]=_system_message_routing.duplicate(true)
		return _system_message_result.duplicate(true)
	_system_message_model=model
	var result: Dictionary
	if is_instance_valid(_system_message_scene) and _system_message_rendered_priority==_system_message_priority:
		result=SystemMessage.refresh(_system_message_scene,hud)
	else:
		var contract: Dictionary=SystemMessage.build(_pack,hud,_system_message_priority)
		if not contract.get("ok",false):return _system_message_failed(contract)
		var scope: Array[int]=[]
		scope.assign(contract.source_node_offsets)
		var next:=Scene.new()
		result=next.configure_project(_pack,contract.parent_member,contract.parent_project_offset,contract.bindings,scope)
		if not result.get("ok",false):next.free();return _system_message_failed(result)
		var previous: Node2D=_system_message_scene
		_coordinates.add_child(next)
		_system_message_scene=next
		_system_message_rendered_priority=_system_message_priority
		if is_instance_valid(previous) and not previous.is_queued_for_deletion():
			previous.hide()
			previous.queue_free()
	if not result.get("ok",false):return _system_message_failed(result)
	_system_message_scene.show()
	var label: Object=_legacy_message.get_ref() if _legacy_message!=null else null
	if label!=null:label.visible=false
	_system_message_result={"ok":true,"handled":true,"priority":_system_message_priority,"priority_routing":_system_message_routing.duplicate(true),"text":current.text,"existing_timer_retained":true,"off_animation_played":false,"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false}
	return _system_message_result.duplicate(true)

func _system_message_failed(reason: Dictionary) -> Dictionary:
	if is_instance_valid(_system_message_scene):_system_message_scene.hide()
	var label: Object=_legacy_message.get_ref() if _legacy_message!=null else null
	if label!=null:label.visible=_legacy_message_visible
	_system_message_result=reason.duplicate(true)
	_system_message_result["handled"]=false
	_system_message_result["priority_routing"]=_system_message_routing.duplicate(true)
	return _system_message_result.duplicate(true)

func refresh_quickslots() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null or not is_instance_valid(_coordinates):return _fail("source_quickslot_host_unavailable")
	if _source_input_captured(hud):return {"ok":true,"handled":_quickslot_view!=null and _quickslot_view.is_open(),"refresh_pending":true}
	if _icons_refresh_pending:
		_icons_refresh_pending=false
		if inventory_is_open():_inventory_result=_inventory_view.refresh()
		# Re-registration can replace an icon descriptor without changing its
		# entry/page. It waits for the existing active gesture to finish.
		if _quickslot_view!=null:_quickslot_view.close()
	if _quickslot_view==null:return {"ok":true,"handled":false,"code":"source_quickslot_pack_scope_unavailable"}
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

func source_blessing_control_availability() -> Array:
	var values: Array=[]
	for record: Dictionary in _legacy_blessing:values.append(record.visible)
	return values

func source_blessing_status() -> Dictionary:
	return _blessing_result.duplicate(true)

func dungeon_blocks_point(point: Vector2) -> bool:
	return _dungeon_controls!=null and _dungeon_controls.blocks_point(point)

func workspace_controls_block_point(point: Vector2) -> bool:
	return _workspace_controls!=null and _workspace_controls.blocks_point(point)

func crafting_search_is_open() -> bool:
	return _workspace_controls!=null and _workspace_controls.search_is_open()

func close_crafting_search() -> void:
	_cancel_native_buttons()
	if _workspace_controls!=null:_workspace_controls.close_search()

func try_open_inventory() -> Dictionary:
	if _inventory_view==null:return {"ok":false,"handled":false,"code":"source_inventory_original_pack_scope_unavailable"}
	if not is_instance_valid(_coordinates):return {"ok":false,"handled":false,"code":"source_main_not_configured"}
	var trace: int=MENU_TRACE.begin("inventory")
	_inventory_result=_inventory_view.open(_coordinates)
	if _inventory_result.get("handled",false):
		var presented: Dictionary=_inventory_view.presentation()
		var native_scene: Node2D=presented.get("scene")
		if is_instance_valid(native_scene):native_scene.z_index=150
		_inventory_signature=_inventory_model_signature()
	MENU_TRACE.end(trace,_inventory_result.get("ok",false))
	return _inventory_result.duplicate(true)

func inventory_is_open() -> bool:
	return _inventory_view!=null and _inventory_view.is_open()

func inventory_search_is_open() -> bool:
	return inventory_is_open() and _inventory_view.search_is_open()

func close_inventory_search() -> void:
	_cancel_native_buttons()
	if _inventory_view!=null:_inventory_view.close_search()

func close_inventory() -> void:
	var owned_open: bool=inventory_is_open()
	_cancel_native_buttons()
	if _inventory_name_view!=null:_inventory_name_view.close()
	if _inventory_view!=null:_inventory_view.close()
	_clear_inventory_presentation()
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var bag: Variant=hud.get("lineage_inventory_ui") if hud!=null else null
	if owned_open and is_instance_valid(bag) and bag.has_method("_hide_item_name"):bag.call("_hide_item_name")

func _inventory_view_closed() -> void:
	_clear_inventory_presentation()
	inventory_closed.emit()

func _inventory_view_fallback(reason: Dictionary) -> void:
	# Unsupported selection/filter states retire the native view without its
	# closed signal. Release the old successful snapshot on this path too.
	_clear_inventory_presentation()
	inventory_return_to_current_requested.emit(reason)

func _clear_inventory_presentation() -> void:
	# These are diagnostic snapshots, not inventory or save ownership. Their
	# nested owner results can keep every closed slot texture alive.
	_inventory_result.clear()
	_inventory_name_result.clear()
	_release_menu_page_leases()

func _release_menu_page_leases() -> void:
	# Active sprites/fonts own their textures. Decoded atlas pages are only
	# needed to construct new textures and can return to the bounded idle pool.
	# Another active view remains valid and a later decode re-acquires a page.
	if _pack!=null and _pack.has_method("release_cache_leases"):
		_pack.release_cache_leases()

func inventory_name_hint_context(reference: String) -> Dictionary:
	return _inventory_view.name_hint_context(reference) if inventory_is_open() and _inventory_name_view!=null else {}

func inventory_hit_at(viewport_point: Vector2) -> Dictionary:
	return _inventory_view.hit_at(viewport_point) if inventory_is_open() and not inventory_search_is_open() else {}

func inventory_blocks_point(viewport_point: Vector2) -> bool:
	return inventory_is_open() and (_inventory_view.blocks_point(viewport_point) or _inventory_view.search_blocks_point(viewport_point))

func inventory_lock_blocks_point(viewport_point: Vector2) -> bool:
	if _inventory_lock_view==null:return false
	var shown: Dictionary=_inventory_lock_view.presentation()
	for control: Variant in shown.get("controls",[]):
		if control is Control and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*viewport_point):return true
	return false

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

## --- Original 523 domination stone window (source_main_domination_stone_window)
const DominationWindow=preload("res://scripts/ui/original_ui/source_main_domination_stone_window.gd")
var _domination_window: RefCounted

func _domination() -> RefCounted:
	if _domination_window!=null:return _domination_window
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if _pack==null or hud==null:return null
	var window=DominationWindow.new()
	if not window.configure(_pack,hud).get("ok",false):return null
	window.closed.connect(func() -> void:
		if hud.has_method("_close_workspace"):hud.call("_close_workspace"))
	_domination_window=window
	return window

func try_open_domination_window(world: Node) -> Dictionary:
	var window: RefCounted=_domination()
	if window==null or not is_instance_valid(_coordinates):return _fail("source_domination_window_pack_scope_unavailable")
	_cancel_native_buttons()
	return window.open(_coordinates,world)

func domination_window_is_open() -> bool:
	return _domination_window!=null and _domination_window.is_open()

func close_domination_window() -> void:
	if _domination_window!=null and _domination_window.is_open():
		_cancel_native_buttons()
		_domination_window.close()

## --- Original 523 콘텐츠 현황판 (source_main_status_board, world.routines)
const StatusBoard=preload("res://scripts/ui/original_ui/source_main_status_board.gd")
var _status_board: RefCounted

func try_open_status_board(world: Node) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if _status_board==null and _pack!=null and hud!=null:
		var board=StatusBoard.new()
		if board.configure(_pack,hud).get("ok",false):
			board.closed.connect(func() -> void:
				if hud.has_method("_close_workspace"):hud.call("_close_workspace"))
			_status_board=board
	if _status_board==null or not is_instance_valid(_coordinates):return _fail("source_status_board_pack_scope_unavailable")
	_cancel_native_buttons()
	return _status_board.open(_coordinates,world)

func status_board_is_open() -> bool:
	return _status_board!=null and _status_board.is_open()

func close_status_board() -> void:
	if status_board_is_open():
		_cancel_native_buttons()
		_status_board.close()

## --- Original 523 재료 아이템 출처 popup (source_main_acquisition_popup)
const AcquisitionPopup=preload("res://scripts/ui/original_ui/source_main_acquisition_popup.gd")
var _acquisition_popup: RefCounted

func try_open_acquisition(world: Node, item_class_id: int, item_name: String="") -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if _acquisition_popup==null and _pack!=null and hud!=null:
		var popup=AcquisitionPopup.new()
		if popup.configure(_pack,hud).get("ok",false):_acquisition_popup=popup
	if _acquisition_popup==null or not is_instance_valid(_coordinates):return _fail("source_acquisition_popup_pack_scope_unavailable")
	_cancel_native_buttons()
	return _acquisition_popup.open(_coordinates,world,item_class_id,item_name)

func acquisition_is_open() -> bool:
	return _acquisition_popup!=null and _acquisition_popup.is_open()

func close_acquisition() -> void:
	if acquisition_is_open():
		_cancel_native_buttons()
		_acquisition_popup.close()

## --- Original 523 혈맹 문장 선택 popup (source_main_emblem_window, world.emblem523)
const EmblemWindow=preload("res://scripts/ui/original_ui/source_main_emblem_window.gd")
var _emblem_window: RefCounted

func try_open_emblem_window(world: Node) -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if _emblem_window==null and _pack!=null and hud!=null:
		var window=EmblemWindow.new()
		if window.configure(_pack,hud).get("ok",false):
			window.closed.connect(func() -> void:
				if hud.has_method("_close_workspace"):hud.call("_close_workspace"))
			_emblem_window=window
	if _emblem_window==null or not is_instance_valid(_coordinates):return _fail("source_emblem_window_pack_scope_unavailable")
	_cancel_native_buttons()
	return _emblem_window.open(_coordinates,world)

func emblem_window_is_open() -> bool:
	return _emblem_window!=null and _emblem_window.is_open()

func close_emblem_window() -> void:
	if emblem_window_is_open():
		_cancel_native_buttons()
		_emblem_window.close()

## The original MainMenu_DominationStone tile, or {} without the pack scene.
func domination_menu_tile(activate: Callable) -> Dictionary:
	var window: RefCounted=_domination()
	return window.menu_tile(activate) if window!=null else _fail("source_domination_window_pack_scope_unavailable")

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

## True while an original window covers the field; overlays drawn above
## the HUD (developer tools) hide meanwhile.
func any_window_open() -> bool:
	return character_is_open() or npc_dialogue_is_open() or shop_window_is_open() or change_window_is_open() \
		or quest_window_is_open() or inventory_is_open() or domination_window_is_open() or world_map_is_open()

func world_map_is_open() -> bool:
	return is_instance_valid(_world_map) and _world_map.is_open()

func toggle_world_map() -> Dictionary:
	if not is_instance_valid(_world_map):return _fail("source_world_map_not_configured")
	_cancel_native_buttons()
	return _world_map.toggle()

func close_world_map() -> Dictionary:
	if not is_instance_valid(_world_map):return {"ok":true,"closed":true}
	var result: Dictionary=_world_map.close()
	_release_menu_page_leases()
	return result

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
	var name_contract: Dictionary=_map_bindings.build_name(map_name)
	_map_name_result=_mount_main_project(21588,name_contract)
	if not _map_name_result.get("ok",false) and name_contract.get("source_node_offsets",[]).has(MainMap.ZONE_TEXT):
		# Optional source zone text must not remove the existing complete
		# owner map-name string when its source font/scope is unavailable.
		var with_zone: Dictionary=_map_name_result.duplicate(true)
		_map_name_result=_mount_main_project(21588,_map_bindings.build_name(map_name,false))
		_map_name_result["optional_safe_label_result"]=with_zone
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
	refresh_primary_stats()
	_refresh_wallet(gold_changed)
	_sync_chrome()
	return {"ok":last_result.get("ok",false),"components":{"exp":last_result.duplicate(true),"hp_mp":_char_result.duplicate(true),"combat":_combat_result.duplicate(true),"menu":_menu_result.duplicate(true),"wallet":_wallet_result.duplicate(true),"blessing":_blessing_result.duplicate(true),"map_name":_map_name_result.duplicate(true),"selected_target_name":_target_result.duplicate(true),"primary_stats":_primary_stats_result.duplicate(true),"joystick":_joystick_result.duplicate(true)},"complete_screen_contract":false,"game_state_written":false}

func refresh_primary_stats() -> Dictionary:
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_primary_stats_host_unavailable")
	var model: Dictionary=PrimaryStats.snapshot(hud)
	if not model.get("ok",false):
		if is_instance_valid(_primary_stats_scene):_primary_stats_scene.hide()
		_primary_stats_result=model
		return model
	if is_instance_valid(_primary_stats_scene):
		if model!=_primary_stats_model or not _primary_stats_result.get("ok",false):_primary_stats_result=PrimaryStats.refresh(_primary_stats_scene,hud)
		_primary_stats_model=model
		_primary_stats_scene.visible=_primary_stats_result.get("ok",false)
		return _primary_stats_result.duplicate(true)
	if _primary_stats_attempted:return _primary_stats_result.duplicate(true)
	_primary_stats_attempted=true
	var contract: Dictionary=PrimaryStats.build(_pack,hud)
	if not contract.get("ok",false):
		_primary_stats_result=contract
		return contract
	if _pack.layout_source(HEADER).get("_source_sha256")!=HEADER_SHA:
		_primary_stats_result=_fail("source_main_header_parent_identity_mismatch")
		return _primary_stats_result
	var scene:=Scene.new()
	_primary_stats_result=scene.configure_project(_pack,HEADER,HEADER_PROJECT,contract.bindings,contract.source_node_offsets)
	if not _primary_stats_result.get("ok",false):scene.free();return _primary_stats_result
	_coordinates.add_child(scene)
	_primary_stats_scene=scene
	_primary_stats_model=model
	_primary_stats_result["read_only"]=true
	_primary_stats_result["unconnected_controls"]=contract.get("unconnected_controls",[])
	return _primary_stats_result.duplicate(true)

func update_currency_balances(balances: Dictionary) -> Dictionary:
	var changed: bool=_balances!=balances
	_balances=balances.duplicate(true)
	_refresh_wallet(changed)
	_sync_chrome()
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

func _refresh_blessing(hud: Node) -> void:
	var state: Dictionary=Blessing.source_state(hud)
	if not state.get("ok",false):
		if is_instance_valid(_blessing_scene):
			_blessing_scene.hide()
			_blessing_scene.queue_free()
			_blessing_mount_attempted=false
		_blessing_scene=null
		_blessing_model.clear()
		_blessing_result=state
		sync_legacy_visibility()
		return
	if is_instance_valid(_blessing_scene):
		if state==_blessing_model:return
		var result: Dictionary=Blessing.refresh(_blessing_scene,state,_blessing_info_in_scope)
		_blessing_result=result
		if result.get("ok",false):_blessing_model=state;return
		_blessing_scene.hide();_blessing_scene.queue_free();_blessing_scene=null
		sync_legacy_visibility()
		return
	if _blessing_mount_attempted:return
	_blessing_mount_attempted=true
	var contract: Dictionary=Blessing.build(_pack,hud)
	if not contract.get("ok",false):_blessing_result=contract;return
	if _pack.layout_source(HEADER).get("_source_sha256")!=HEADER_SHA:_blessing_result=_fail("source_blessing_original_header_required");return
	var scene:=Scene.new()
	var scope: Array[int]=[]
	scope.assign(contract.source_node_offsets)
	var result: Dictionary=scene.configure_project(_pack,HEADER,1540,contract.bindings,scope)
	if not result.get("ok",false):scene.free();_blessing_result=result;return
	_coordinates.add_child(scene)
	_blessing_scene=scene
	_blessing_model=state
	_blessing_info_in_scope=contract.info_in_scope
	_blessing_result={"ok":true,"amount_connected":true,"information_entry_connected":true,"rate_fields_connected":_blessing_info_in_scope,"source_parent":HEADER,"source_project":1540,"partial_source_scene":true,"complete_screen_contract":false,"icon_stage_connected":false,"game_state_written":false}
	sync_legacy_visibility()

func _capture_existing_controls(hud: Node) -> void:
	var previous: Variant=hud.get("original_main_ui_controller")
	var blessing_visibility: Array=previous.source_blessing_control_availability() if is_instance_valid(previous) and previous.has_method("source_blessing_control_availability") else []
	for index: int in range(2):
		var control: Variant=hud.get(["v20_leaf_button","v20_leaf_count"][index])
		if control is CanvasItem and is_instance_valid(control):_legacy_blessing.append({"control":weakref(control),"visible":bool(blessing_visibility[index]) if index<blessing_visibility.size() else control.visible})
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
	_capture_legacy_chrome(hud,previous)

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
	var scope: Array[int]=[]
	scope.assign(contract.source_node_offsets)
	var configured: Dictionary=scene.configure_project(_pack,MAIN,offset,contract.bindings,scope)
	if not configured.get("ok",false):
		scene.free()
		return configured
	_coordinates.add_child(scene)
	return {"ok":true,"scene":scene,"source":contract.member,"selected_source_offsets":contract.source_node_offsets.duplicate(),"partial_source_scene":true,"complete_screen_contract":false}

func refresh_combat() -> Dictionary:
	_refresh_auto_message()
	if _combat==null or not is_instance_valid(_combat_scene):return {"ok":true,"source_combat_presented":false}
	var result: Dictionary=_combat.refresh_presented(_combat_scene)
	result["auto_message"]=_auto_message_result.duplicate(true)
	return result

func _refresh_auto_message() -> Dictionary:
	if not _pack.manifest.get("scenes",{}).has(AutoMessage.MEMBER):return {"ok":true,"source_auto_message_in_pack":false}
	var hud: Node=_hud.get_ref() if _hud!=null else null
	if hud==null:return _fail("source_auto_message_host_unavailable")
	if _auto_message==null:
		var candidate=AutoMessage.new()
		_auto_message_result=candidate.configure(_pack,hud)
		if not _auto_message_result.get("ok",false):return _auto_message_result
		_auto_message=candidate
	var model: Dictionary=_auto_message.snapshot()
	if not model.get("ok",false):
		if is_instance_valid(_auto_message_scene):_auto_message_scene.hide()
		_auto_message_result=model
		return model
	if is_instance_valid(_auto_message_scene):
		if model!=_auto_message_model or not _auto_message_result.get("ok",false):_auto_message_result=_auto_message.refresh(_auto_message_scene)
		_auto_message_scene.visible=_auto_message_result.get("ok",false)
		_auto_message_model=model
		return _auto_message_result.duplicate(true)
	_auto_message_result=_mount_main_project(AutoMessage.MAIN_PROJECT,_auto_message.build())
	if _auto_message_result.get("ok",false):
		_auto_message_scene=_auto_message_result.scene
		_auto_message_result.erase("scene")
		_auto_message_model=model
	return _auto_message_result.duplicate(true)

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
	_cancel_native_buttons()
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
	for record: Dictionary in _legacy_blessing:
		var control: Object=record.control.get_ref()
		if control!=null:control.visible=false if is_instance_valid(_blessing_scene) else record.visible
	for record: Dictionary in _legacy_quickslots:
		var control: Object=record.control.get_ref()
		if control!=null:control.visible=false if _quickslot_view!=null and _quickslot_view.is_open() else record.visible
	var map_label: Object=_legacy_map_name.get_ref() if _legacy_map_name!=null else null
	if map_label!=null:map_label.visible=false if is_instance_valid(_map_name_scene) else _legacy_map_name_visible
	var message: Object=_legacy_message.get_ref() if _legacy_message!=null else null
	if message!=null:message.visible=false if is_instance_valid(_system_message_scene) and _system_message_result.get("ok",false) else _legacy_message_visible
	for kind: String in _legacy_combat:
		var control: Object=_legacy_combat[kind].get_ref()
		var owned: bool=is_instance_valid(_combat_scene) and (kind!="pickup" or _combat_owns_pickup)
		if control!=null:control.visible=false if owned else bool(_combat_availability.get(kind,false))
	for kind: String in _legacy_shortcuts:
		var control: Object=_legacy_shortcuts[kind].get_ref()
		if control!=null:control.visible=not is_instance_valid(_menu_scene)
	_sync_chrome()

func _sync_chrome() -> void:
	for record: Dictionary in _legacy_chrome:_apply_legacy_chrome(record,_chrome_owned(str(record.owner)))

func _remember(result: Dictionary) -> Dictionary:
	last_result=result.duplicate(true)
	return result

func _exit_tree() -> void:
	release(_restore_legacy)

func _notification(what: int) -> void:
	if not is_inside_tree() or _pack==null:return
	match what:
		NOTIFICATION_APPLICATION_PAUSED:MENU_TRACE.lifecycle("paused")
		NOTIFICATION_APPLICATION_RESUMED:MENU_TRACE.lifecycle("resumed")
		NOTIFICATION_APPLICATION_FOCUS_IN:MENU_TRACE.lifecycle("focus_in")
		NOTIFICATION_APPLICATION_FOCUS_OUT:MENU_TRACE.lifecycle("focus_out")
		NOTIFICATION_WM_CLOSE_REQUEST:MENU_TRACE.lifecycle("close_request")

func release(restore_legacy: bool=true) -> void:
	_restore_legacy=restore_legacy
	set_process(false)
	_cancel_native_buttons()
	if is_inside_tree() and get_window().focus_exited.is_connected(_cancel_native_buttons):get_window().focus_exited.disconnect(_cancel_native_buttons)
	if is_instance_valid(_world_map):_world_map.close()
	close_character()
	close_npc_dialogue()
	if _dungeon_controls!=null:_dungeon_controls.close()
	if _workspace_controls!=null:_workspace_controls.close()
	close_enhance_action()
	close_quest_controls()
	close_quest_window()
	close_shop_window()
	close_change_window()
	if _inventory_lock_view!=null:_inventory_lock_view.close()
	close_inventory()
	if _quickslot_view!=null:_quickslot_view.close()
	if _joystick_view!=null:
		_joystick_view.close(restore_legacy)
		if restore_legacy:_restore_log_position(_hud.get_ref() if _hud!=null else null)
	var canvas: Control=_canvas.get_ref() if _canvas!=null else null
	if canvas!=null and canvas.resized.is_connected(_fit_source_coordinates):canvas.resized.disconnect(_fit_source_coordinates)
	if is_instance_valid(_coordinates):
		_coordinates.visible=false
		_coordinates.process_mode=Node.PROCESS_MODE_DISABLED
		_coordinates.queue_free()
	_coordinates=null
	if restore_legacy:
		for record: Dictionary in _legacy_blessing:
			var control: Object=record.control.get_ref()
			if control!=null:control.visible=record.visible
		var message: Object=_legacy_message.get_ref() if _legacy_message!=null else null
		if message!=null:message.visible=_legacy_message_visible
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
		for record: Dictionary in _legacy_chrome:_apply_legacy_chrome(record,false)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}

func _open_joystick(hud: Node) -> void:
	if not JoystickView.available(_pack):return
	var joystick: Variant=hud.get("joystick")
	if not joystick is Control or not is_instance_valid(joystick):
		_joystick_result=_fail("source_joystick_existing_control_required")
		return
	var candidate=JoystickView.new()
	_joystick_result=candidate.open(_pack,_coordinates,joystick)
	if not _joystick_result.get("handled",false):return
	_joystick_view=candidate
	# The original pad is wider than the TWILIGHT stick: start the existing
	# combat log right of it (its own layout keeps every other field).
	var combat_log: Variant=hud.get("log_label")
	var layer: Variant=hud.get("v20_layer")
	if not combat_log is Control or not layer is CanvasItem or not combat_log.has_meta("renewal_base_position") or not hud.has_method("_fit_hud"):return
	if not combat_log.has_meta(LOG_BASE_META):combat_log.set_meta(LOG_BASE_META,combat_log.get_meta("renewal_base_position"))
	var base: Vector2=combat_log.get_meta(LOG_BASE_META)
	var pad_right: float=(layer.get_global_transform().affine_inverse()*joystick.get_global_rect().end).x
	combat_log.set_meta("renewal_base_position",Vector2(maxf(base.x,ceilf(pad_right)+6.0),base.y))
	hud.call("_fit_hud")

func _restore_log_position(hud: Object) -> void:
	if not is_instance_valid(hud):return
	var combat_log: Variant=hud.get("log_label")
	if not combat_log is Control or not combat_log.has_meta(LOG_BASE_META):return
	combat_log.set_meta("renewal_base_position",combat_log.get_meta(LOG_BASE_META))
	combat_log.remove_meta(LOG_BASE_META)
	if hud.has_method("_fit_hud"):hud.call("_fit_hud")

func joystick_status() -> Dictionary:
	return _joystick_result.duplicate(true)

func source_chrome_availability() -> Dictionary:
	var values: Dictionary={}
	for record: Dictionary in _legacy_chrome:values[record.key]=record.value
	return values

func _capture_legacy_chrome(hud: Node, previous: Variant) -> void:
	# A replaced controller already hid these; take its recorded values.
	var prior: Dictionary=previous.source_chrome_availability() if is_instance_valid(previous) and previous.has_method("source_chrome_availability") else {}
	var layer: Variant=hud.get("v20_layer")
	var status: Node=layer.get_node_or_null("StatusPanel") if layer is Node else null
	var specs: Array=[
		# Hud_CharInfo shows the level in its class badge and opens the character
		# window from Btn_Status; the original HUD has no name or panel backdrop.
		["status_panel",status,"char","self_alpha"],
		["level_badge",hud.get("v20_level_badge"),"char","visible"],
		["status_name",hud.get("v20_status_name"),"char","visible"],
		["character_shortcut",status.find_child("CharacterShortcut",true,false) if status!=null else null,"char","visible"],
		# Hud_CharInfo Btn_Attack/Btn_Defense icons and values (primary stats).
		["stat_text",hud.get("v20_stat_text"),"stats","visible"],
		# Hud_PayLayout diamond/adena.
		["currency",hud.get("currency_readout"),"wallet","visible"],
		# Hud_TopMenu store/bag/skill/quest/all. The world map stays reachable
		# from the original Btn_All menu (its 월드맵 tile).
		["main_shortcuts",layer.get_node_or_null("MainShortcuts") if layer is Node else null,"menu","visible"]
	]
	for spec: Array in specs:
		var control: Variant=spec[1]
		if not control is CanvasItem or not is_instance_valid(control):continue
		var property: String=spec[3]
		var value: Variant=prior.get(spec[0],control.visible if property=="visible" else control.self_modulate.a)
		_legacy_chrome.append({"key":spec[0],"control":weakref(control),"owner":spec[2],"property":property,"value":value})

func _chrome_owned(owner: String) -> bool:
	match owner:
		"char":return is_instance_valid(_char_scene)
		"stats":return is_instance_valid(_primary_stats_scene) and _primary_stats_scene.visible
		"wallet":return is_instance_valid(_wallet_scene)
		"menu":return is_instance_valid(_menu_scene)
	return false

static func _apply_legacy_chrome(record: Dictionary, owned: bool) -> void:
	var control: Object=record.control.get_ref()
	if control==null:return
	if record.property=="visible":control.visible=false if owned else bool(record.value)
	else:control.self_modulate.a=0.0 if owned else float(record.value)
