extends RefCounted
## Bounded native inventory presentation: one original normal four-slot or
## extension eight-slot row containing the entire current filtered owner model.
## Unsupported states request the existing complete bag; no grid is synthesized.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Chrome=preload("res://scripts/ui/original_ui/source_main_inventory_bindings.gd")
const Slots=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const PARENT="UI/FloatingUiScene.csb"
const PROJECT=1572
const SLOT_SET=56036
const SLOT_OFFSETS: Array[int]=[5464,5212,4972,4732]
const EXTENSION_SLOT_OFFSETS: Array[int]=[3900,3660,3420,3180,2940,2700,2460,2212]
var _native_capacity: int=4
signal return_to_current_requested(reason: Dictionary)
signal native_scene_changed(presentation: Dictionary)
signal closed
signal source_scroll_input(event: InputEvent)
var _pack: RefCounted
var _hud: WeakRef
var _bag: WeakRef
var _parent: WeakRef
var _chrome: RefCounted
var _slots: RefCounted
var _scene: Node2D
var _inventory_scene: Node2D
var _hits: Dictionary={}
var _bounds: Control
var _refreshing: bool=false

func configure(pack: RefCounted, hud: Node, image_owner_provider: Callable=Callable()) -> Dictionary:
	if not is_instance_valid(hud):return _unsupported("source_inventory_view_hud_unavailable")
	var bag: Variant=hud.get("lineage_inventory_ui")
	if not is_instance_valid(bag):return _unsupported("source_inventory_view_existing_bag_required")
	_pack=pack
	_hud=weakref(hud)
	_bag=weakref(bag)
	_chrome=Chrome.new()
	_slots=Slots.new()
	var result: Dictionary=_chrome.configure(pack,hud,Callable(self,"_on_native_closed"))
	if not result.get("ok",false):return _unsupported_result(result)
	result=_slots.configure(pack,hud,image_owner_provider)
	if not result.get("ok",false):return _unsupported_result(result)
	_chrome.model_changed.connect(_on_category_changed)
	_slots.selection_changed.connect(_on_selection_changed)
	return {"ok":true,"handled":false,"configured":true,"native_capacity":4,"supported_native_capacities":[4,8],"parent_contract":Chrome.parent_contract(PARENT),"partial_source_scene":true,"complete_screen_contract":false}

func open(parent: Node) -> Dictionary:
	if not is_instance_valid(parent):return _unsupported("source_inventory_view_existing_canvas_required")
	_parent=weakref(parent)
	return _stage(parent,true)

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion() and _scene.is_inside_tree()

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_inventory_scene=null
	_bounds=null
	_hits.clear()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	# Closing this native presentation never clears selection or owns saves.

func refresh() -> Dictionary:
	if _refreshing:return {"ok":true,"handled":is_open(),"refresh_pending":true}
	if not is_open():return _unsupported("source_inventory_view_not_open")
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if parent==null:return _fallback(_unsupported("source_inventory_view_canvas_unavailable"))
	return _stage(parent,false)

func select(reference: String) -> Dictionary:
	if not is_open():return _unsupported("source_inventory_view_not_open")
	return _slots.select_reference(reference)

func activate_selected(reference: String) -> Dictionary:
	if not is_open():return _unsupported("source_inventory_view_not_open")
	# The existing PointerTransfer/host decides double-tap or explicit use.
	return _slots.activate_existing_selection(reference)

func hit_at(viewport_point: Vector2) -> Dictionary:
	if not is_open() or not viewport_point.is_finite():return {}
	for reference: String in _hits:
		var hit: Dictionary=_hits[reference]
		var control: Control=hit.control
		if not is_instance_valid(control) or not control.is_visible_in_tree():continue
		var local: Vector2=control.get_global_transform_with_canvas().affine_inverse()*viewport_point
		if not Rect2(Vector2.ZERO,control.size).has_point(local):continue
		if is_instance_valid(_bounds):
			var bounds_point: Vector2=_bounds.get_global_transform_with_canvas().affine_inverse()*viewport_point
			if not Rect2(Vector2.ZERO,_bounds.size).has_point(bounds_point):continue
		return hit.duplicate(true)
	return {}

func blocks_point(viewport_point: Vector2) -> bool:
	var bounds: Control=gesture_bounds()
	if not is_instance_valid(bounds) or not bounds.is_visible_in_tree() or not viewport_point.is_finite():return false
	return Rect2(Vector2.ZERO,bounds.size).has_point(bounds.get_global_transform_with_canvas().affine_inverse()*viewport_point)

func gesture_bounds() -> Control:
	return _bounds if is_open() else null

func presentation() -> Dictionary:
	return {"scene":_scene,"inventory_scene":_inventory_scene,"hit_controls":_hits.duplicate(true),"gesture_bounds":gesture_bounds(),"native_capacity":_native_capacity,"partial_source_scene":true,"complete_screen_contract":false}

func _eligible_model() -> Dictionary:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	if bag==null:return _unsupported("source_inventory_view_existing_bag_unavailable")
	var search: Variant=bag.get("search_line")
	if is_instance_valid(search) and search is LineEdit and not search.text.is_empty():return _unsupported("source_inventory_view_search_not_supported")
	if bag.get("detail_active")==true:return _unsupported("source_inventory_view_detail_not_supported")
	var branch: Dictionary=_owner_branch(bag)
	if not branch.get("ok",false):return branch
	var model: Dictionary=_slots.entries()
	if not model.get("ok",false):return _unsupported_result(model)
	if model.current_display_rows.size()>int(branch.capacity):
		var reason: Dictionary=_unsupported("source_inventory_view_more_than_authored_capacity")
		reason["native_capacity"]=branch.capacity
		reason["filtered_row_count"]=model.current_display_rows.size()
		return reason
	model["native_capacity"]=branch.capacity
	model["expanded"]=branch.expanded
	model["slot_project_offset"]=44156 if branch.expanded else SLOT_SET
	model["authored_slot_offsets"]=EXTENSION_SLOT_OFFSETS.duplicate() if branch.expanded else SLOT_OFFSETS.duplicate()
	model["authored_variant"]="Nd_Slot_Extension" if branch.expanded else "Nd_Slot"
	return model

func _owner_branch(bag: Object) -> Dictionary:
	var capacity: int=0
	var grid: Variant=bag.get("item_grid")
	if is_instance_valid(grid) and grid is GridContainer:
		if grid.columns not in [4,8]:return _unsupported("source_inventory_view_owner_columns_not_authored")
		capacity=grid.columns
	var window: Node=bag.get_parent()
	for index: int in range(2):window=window.get_parent() if window!=null else null
	if window!=null and window.has_meta("expanded"):
		var expanded: Variant=window.get_meta("expanded")
		if not expanded is bool:return _unsupported("source_inventory_view_owner_expand_state_invalid")
		var declared_capacity: int=8 if expanded else 4
		if capacity!=0 and capacity!=declared_capacity:return _unsupported("source_inventory_view_owner_expand_state_not_synchronized")
		capacity=declared_capacity
	if capacity==0:return _unsupported("source_inventory_view_owner_expand_state_required")
	return {"ok":true,"capacity":capacity,"expanded":capacity==8,"basis":"existing owner grid.columns/window expanded metadata"}

func _stage(parent: Node, initial_open: bool) -> Dictionary:
	_refreshing=true
	var model: Dictionary=_eligible_model()
	if not model.get("ok",false):
		_refreshing=false
		return _fallback(model) if is_open() else model
	var slot_offsets: Array[int]=[]
	slot_offsets.assign(model.authored_slot_offsets)
	var slot_set: int=model.slot_project_offset
	var assignments: Dictionary={}
	var entries_by_reference: Dictionary={}
	for index: int in range(model.current_display_rows.size()):
		var row: Dictionary=model.current_display_rows[index]
		var reference: Variant=row.get("reference")
		if not reference is String or reference.is_empty():
			_refreshing=false
			return _stage_failed(_unsupported("source_inventory_view_owner_reference_missing"))
		assignments[slot_offsets[index]]=reference
		entries_by_reference[reference]=row.duplicate(true)
	var slot_contract: Dictionary=_slots.build(slot_set,assignments,{"role":"source_scroll","input":Callable(self,"_forward_scroll_input")},model.authored_variant)
	if not slot_contract.get("ok",false):
		_refreshing=false
		return _stage_failed(_unsupported_result(slot_contract))
	var chrome: Dictionary=_chrome.build({},model.expanded)
	if not chrome.get("ok",false):
		_refreshing=false
		return _stage_failed(_unsupported_result(chrome))
	var scope: Array[int]=[]
	scope.assign(chrome.source_node_offsets)
	for offset: int in slot_contract.source_node_offsets:
		if offset not in scope:scope.append(offset)
	var bindings: Dictionary=chrome.bindings.duplicate(true)
	for key: Variant in slot_contract.bindings:bindings[key]=slot_contract.bindings[key]
	var root_bindings: Dictionary={PROJECT:{"role":"project","source_node_offsets":scope,"bindings":bindings}}
	var next:=Scene.new()
	var result: Dictionary=next.configure_nodes(_pack,PARENT,[PROJECT],root_bindings)
	if not result.get("ok",false):return _reject_staged(next,result)
	var child: Dictionary=next.project_player([PROJECT])
	if not child.get("ok",false):return _reject_staged(next,child)
	var inventory_scene: Node2D=child.player
	var hits: Dictionary={}
	for offset: int in slot_offsets:
		if not assignments.has(offset):continue
		var slot_player: Dictionary=next.project_player([PROJECT,slot_set,offset])
		if not slot_player.get("ok",false):return _reject_staged(next,slot_player)
		var native_slot: Node2D=slot_player.player
		var owner_result: Dictionary=slot_contract.owner_results[offset]
		var accepted: Dictionary=native_slot.set_bound_source_visual_result(Slots.ICON,owner_result)
		if not accepted.get("ok",false) or (not accepted.get("texture_assigned",false) and not accepted.get("source_scene_assigned",false)):return _reject_staged(next,{"ok":false,"code":"source_inventory_view_owned_icon_not_consumed","reference":assignments[offset],"owner_result":owner_result,"source_asset_result":accepted})
		result=native_slot.set_bound_visible(Slots.ICON,true)
		if not result.get("ok",false):return _reject_staged(next,result)
		var button_node: Variant=native_slot.get("source_nodes").get(Slots.BUTTON)
		var button: Variant=button_node.get_meta("source_button",null) if is_instance_valid(button_node) else null
		var control: Variant=button.get("_input_area") if is_instance_valid(button) else null
		if not control is Control:return _reject_staged(next,{"ok":false,"code":"source_inventory_view_original_slot_hit_control_missing","offset":offset})
		var reference: String=assignments[offset]
		var raw: Dictionary=entries_by_reference[reference]
		hits[reference]={"from":"inventory","id":reference,"reference":reference,"entry":{"kind":"item","id":raw.get("name")},"owned_row":raw,"texture":accepted.get("texture"),"native_icon_scene":accepted.get("player"),"control":control,"button":control,"native_slot_scene":native_slot,"slot_project_offset":offset,"slot_set_project_offset":slot_set,"source_asset_evidence":accepted.get("evidence",{}),"use_on_single_click":false}
	var bounds: Control=_source_consume_control(inventory_scene,int(chrome.background_offset))
	if bounds==null:return _reject_staged(next,{"ok":false,"code":"source_inventory_view_original_gesture_bounds_missing"})
	var previous: Node2D=_scene
	var playback: Dictionary=previous.playback_status() if is_instance_valid(previous) else {}
	if initial_open or bool(playback.get("playing",false)):
		result=next.play("Inventory_All_On",false)
		if not result.get("ok",false):return _reject_staged(next,result)
		if not initial_open:next.seek_frame(float(playback.get("frame",0)))
	else:next.seek_frame(float(playback.get("frame",17)))
	if model.expanded:
		# Apply the existing source extension clip's exact end state. No new
		# geometry is authored and no source loop/autoplay policy is inferred.
		inventory_scene.seek_frame(70.0)
		var refreshed: Dictionary=_chrome.refresh(inventory_scene)
		if not refreshed.get("ok",false):return _reject_staged(next,refreshed)
	# Commit only after every owned row has its original slot, hit control and
	# existing owner texture. The complete current bag remains caller-owned.
	parent.add_child(next)
	_scene=next
	_inventory_scene=inventory_scene
	_hits=hits
	_bounds=bounds
	_native_capacity=int(model.native_capacity)
	_chrome.bind_presented(inventory_scene)
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	_refreshing=false
	var shown: Dictionary=presentation()
	shown["ok"]=true
	shown["handled"]=true
	shown["assignments"]=assignments
	shown["expanded"]=model.expanded
	shown["authored_slot_set_project"]=slot_set
	shown["authored_variant"]=model.authored_variant
	shown["parent_contract"]=Chrome.parent_contract(PARENT)
	shown["logical_open_clip_consumption"]="one_shot_Inventory_All_On_5_17"
	native_scene_changed.emit(shown.duplicate(true))
	return shown

func _reject_staged(scene: Node2D, reason: Dictionary) -> Dictionary:
	scene.free()
	_refreshing=false
	return _stage_failed(_unsupported_result(reason))

func _stage_failed(reason: Dictionary) -> Dictionary:
	return _fallback(reason) if is_open() else reason

func _fallback(reason: Dictionary) -> Dictionary:
	close()
	return_to_current_requested.emit(reason.duplicate(true))
	return reason

func _on_category_changed(_model: Dictionary) -> void:
	if is_open() and not _refreshing:refresh()

func _on_selection_changed(_reference: String) -> void:
	for reference: String in _hits:
		var result: Dictionary=_slots.refresh_slot(_hits[reference].native_slot_scene,reference)
		if not result.get("ok",false):
			_fallback(_unsupported_result(result))
			return

func _on_native_closed() -> void:
	close()
	closed.emit()

func _forward_scroll_input(event: InputEvent) -> void:
	# No native drag/page algorithm is invented. Existing host input owns it.
	source_scroll_input.emit(event)

static func _source_consume_control(scene: Node2D, offset: int) -> Control:
	var node: Variant=scene.get("source_nodes").get(offset)
	if not is_instance_valid(node):return null
	var origin: Node=node.get_node_or_null("SourceContentOrigin")
	if origin==null:return null
	for child: Node in origin.get_children():
		if child is Control and child.mouse_filter==Control.MOUSE_FILTER_STOP:return child
	return null

static func _unsupported(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code,"supported_native_capacities":[4,8],"partial_source_scene":true,"complete_screen_contract":false}

static func _unsupported_result(result: Dictionary) -> Dictionary:
	var reason: Dictionary=result.duplicate(true)
	reason["ok"]=false
	reason["handled"]=false
	reason["partial_source_scene"]=true
	reason["complete_screen_contract"]=false
	return reason
