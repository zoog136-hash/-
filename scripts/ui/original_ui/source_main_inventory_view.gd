extends RefCounted
## Native inventory presentation: the original Inventory_All window with one
## original Inventory_Slot_Set row (4 slots, or 8 extended) per line of the
## current filtered owner model. The first row is the authored instance inside
## ScrollView_Item; every further line is another instance of the same
## original Inventory_Slot_Set.csb placed one slot pitch lower, the way the
## client fills that ScrollView. Dragging scrolls the rows inside its clip.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const Chrome=preload("res://scripts/ui/original_ui/source_main_inventory_bindings.gd")
const Slots=preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const Search=preload("res://scripts/ui/original_ui/source_main_inventory_search.gd")
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
var _search: RefCounted
var search_result: Dictionary={}
## Vertical pitch between original slot rows (the authored horizontal slot
## pitch of Inventory_Slot_Set: -117, -41, 35, 111).
const ROW_PITCH: float=76.0
## Half an original slot, kept below the last row when scrolled to the end.
const ROW_TAIL: float=40.0
var _scroll_content: Node2D
var _scroll_top: float=0.0
var _scroll_bottom: float=0.0
var _scroll_dragging: bool=false
var _scroll_moved: float=0.0
var _row_scenes: Array[Node2D]=[]

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
	_chrome.search_requested.connect(_open_search)
	_slots.selection_changed.connect(_on_selection_changed)
	if pack.manifest.get("scenes",{}).has(Search.MEMBER):
		var candidate=Search.new()
		search_result=candidate.configure(pack,bag)
		if search_result.get("ok",false):_search=candidate
	return {"ok":true,"handled":false,"configured":true,"native_capacity":4,"supported_native_capacities":[4,8],"parent_contract":Chrome.parent_contract(PARENT),"partial_source_scene":true,"complete_screen_contract":false}

func open(parent: Node) -> Dictionary:
	if not is_instance_valid(parent):return _unsupported("source_inventory_view_existing_canvas_required")
	_parent=weakref(parent)
	return _stage(parent,true)

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion() and _scene.is_inside_tree()

func close() -> void:
	close_search()
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
		if not _inside_scroll_view(viewport_point):continue
		return hit.duplicate(true)
	return {}

func _inside_scroll_view(viewport_point: Vector2) -> bool:
	if not is_instance_valid(_scroll_content):return true
	var scroll: Variant=_scroll_content.get_parent()
	var area: Variant=scroll.call("input_control") if is_instance_valid(scroll) and scroll.has_method("input_control") else null
	if not area is Control or not is_instance_valid(area):return true
	return Rect2(Vector2.ZERO,area.size).has_point(area.get_global_transform_with_canvas().affine_inverse()*viewport_point)

func blocks_point(viewport_point: Vector2) -> bool:
	var bounds: Control=gesture_bounds()
	if not is_instance_valid(bounds) or not bounds.is_visible_in_tree() or not viewport_point.is_finite():return false
	return Rect2(Vector2.ZERO,bounds.size).has_point(bounds.get_global_transform_with_canvas().affine_inverse()*viewport_point)

func gesture_bounds() -> Control:
	return _bounds if is_open() else null

func name_hint_context(reference: String) -> Dictionary:
	if not is_open() or not _hits.has(reference):return {}
	var hit: Dictionary=_hits[reference]
	var control: Variant=hit.get("control")
	var scroll_offset: int=43832 if _native_capacity==8 else 55712
	var scroll_node: Variant=_inventory_scene.get("source_nodes").get(scroll_offset)
	var scroll: Variant=scroll_node.get_meta("source_scroll",null) if is_instance_valid(scroll_node) else null
	var bounds: Variant=scroll.input_control() if is_instance_valid(scroll) and scroll.has_method("input_control") else null
	if not control is Control or not is_instance_valid(control) or not bounds is Control or not is_instance_valid(bounds):return {}
	return {"ok":true,"reference":reference,"control":control,"scroll":bounds,"source_native":true}

func presentation() -> Dictionary:
	return {"scene":_scene,"inventory_scene":_inventory_scene,"hit_controls":_hits.duplicate(true),"gesture_bounds":gesture_bounds(),"native_capacity":_native_capacity,"search":search_presentation(),"partial_source_scene":true,"complete_screen_contract":false}

func search_is_open() -> bool:
	return _search!=null and _search.is_open()

func search_presentation() -> Dictionary:
	return _search.presentation() if _search!=null else {}

func close_search() -> void:
	if _search!=null:_search.close()

func focus_search_at(point: Vector2) -> bool:
	return search_is_open() and _search.focus_input_at(point)

func search_blocks_point(point: Vector2) -> bool:
	return search_is_open() and _search.blocks_point(point)

func _open_search() -> void:
	if not is_open() or _native_capacity!=8 or _search==null:return
	var parent: Object=_parent.get_ref() if _parent!=null else null
	search_result=_search.open(parent) if parent!=null else _unsupported("source_inventory_search_parent_unavailable")

func _eligible_model() -> Dictionary:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	if bag==null:return _unsupported("source_inventory_view_existing_bag_unavailable")
	if bag.get("detail_active")==true:return _unsupported("source_inventory_view_detail_not_supported")
	var branch: Dictionary=_owner_branch(bag)
	if not branch.get("ok",false):return branch
	var model: Dictionary=_slots.entries()
	if not model.get("ok",false):return _unsupported_result(model)
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
	var started: int=FRAME_HITCH.now()
	var result: Dictionary=_stage_impl(parent,initial_open)
	FRAME_HITCH.detail("ui.inventory_stage",started)
	return result

func _stage_impl(parent: Node, initial_open: bool) -> Dictionary:
	_refreshing=true
	var model: Dictionary=_eligible_model()
	if not model.get("ok",false):
		_refreshing=false
		return _fallback(model) if is_open() else model
	var slot_offsets: Array[int]=[]
	slot_offsets.assign(model.authored_slot_offsets)
	var slot_set: int=model.slot_project_offset
	var columns: int=slot_offsets.size()
	var assignments: Dictionary={}
	var extra_rows: Array[Dictionary]=[]
	var entries_by_reference: Dictionary={}
	for index: int in range(model.current_display_rows.size()):
		var row: Dictionary=model.current_display_rows[index]
		var reference: Variant=row.get("reference")
		if not reference is String or reference.is_empty():
			_refreshing=false
			return _stage_failed(_unsupported("source_inventory_view_owner_reference_missing"))
		var line: int=index/columns
		if line==0:assignments[slot_offsets[index]]=reference
		else:
			while extra_rows.size()<line:extra_rows.append({})
			extra_rows[line-1][slot_offsets[index%columns]]=reference
		entries_by_reference[reference]=row.duplicate(true)
	var slot_contract: Dictionary=_slots.build(slot_set,assignments,{"role":"source_scroll","input":Callable(self,"_forward_scroll_input")},model.authored_variant,model)
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
	var extra_scenes: Array[Node2D]=[]
	if not extra_rows.is_empty():
		var authored_row: Variant=inventory_scene.get("source_nodes").get(slot_set)
		if not authored_row is Node2D or authored_row.get_parent()==null:return _reject_staged(next,{"ok":false,"code":"source_inventory_view_original_row_missing"})
		for line: int in range(extra_rows.size()):
			var row_contract: Dictionary=_slots.build(slot_set,extra_rows[line],{"role":"source_scroll","input":Callable(self,"_forward_scroll_input")},model.authored_variant,model)
			if not row_contract.get("ok",false):return _reject_staged(next,_unsupported_result(row_contract))
			var row_binding: Dictionary=row_contract.bindings[slot_set]
			var row_scope: Array[int]=[]
			row_scope.assign(row_binding.source_node_offsets)
			var row_scene:=Scene.new()
			var row_result: Dictionary=row_scene.configure_nodes(_pack,Slots.SET_MEMBER,row_scope,row_binding.bindings)
			if not row_result.get("ok",false):
				row_scene.free()
				return _reject_staged(next,row_result)
			row_scene.position=authored_row.position+Vector2(0.0,ROW_PITCH*float(line+1))
			authored_row.get_parent().add_child(row_scene)
			extra_scenes.append(row_scene)
			for offset: int in slot_offsets:
				if not extra_rows[line].has(offset):continue
				var row_slot: Dictionary=row_scene.project_player([offset])
				if not row_slot.get("ok",false):return _reject_staged(next,row_slot)
				var row_native: Node2D=row_slot.player
				var row_owner: Dictionary=row_contract.owner_results[offset]
				var row_accepted: Dictionary=row_native.set_bound_source_visual_result(Slots.ICON,row_owner)
				if not row_accepted.get("ok",false) or (not row_accepted.get("texture_assigned",false) and not row_accepted.get("source_scene_assigned",false)):return _reject_staged(next,{"ok":false,"code":"source_inventory_view_owned_icon_not_consumed","reference":extra_rows[line][offset],"owner_result":row_owner,"source_asset_result":row_accepted})
				result=row_native.set_bound_visible(Slots.ICON,true)
				if not result.get("ok",false):return _reject_staged(next,result)
				var row_button_node: Variant=row_native.get("source_nodes").get(Slots.BUTTON)
				var row_button: Variant=row_button_node.get_meta("source_button",null) if is_instance_valid(row_button_node) else null
				var row_control: Variant=row_button.get("_input_area") if is_instance_valid(row_button) else null
				if not row_control is Control:return _reject_staged(next,{"ok":false,"code":"source_inventory_view_original_slot_hit_control_missing","offset":offset})
				var row_reference: String=extra_rows[line][offset]
				var row_raw: Dictionary=entries_by_reference[row_reference]
				hits[row_reference]={"from":"inventory","id":row_reference,"reference":row_reference,"entry":{"kind":"item","id":row_raw.get("name")},"owned_row":row_raw,"texture":row_accepted.get("texture"),"native_icon_scene":row_accepted.get("player"),"control":row_control,"button":row_control,"native_slot_scene":row_native,"slot_project_offset":offset,"slot_set_project_offset":slot_set,"row":line+1,"source_asset_evidence":row_accepted.get("evidence",{}),"use_on_single_click":false}
	for reference: String in hits:
		var hit_control: Variant=hits[reference].get("control")
		if hit_control is Control and not hit_control.gui_input.is_connected(_forward_scroll_input):hit_control.gui_input.connect(_forward_scroll_input)
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
	else:
		# The normal (4-column) bag is the end state of the source
		# Fx_Extension_Off clip (75-86): Nd_BG is authored at alpha 0 and only
		# that clip brings it to 255, so without it the frame stayed invisible.
		inventory_scene.seek_frame(86.0)
		var refreshed_normal: Dictionary=_chrome.refresh(inventory_scene)
		if not refreshed_normal.get("ok",false):return _reject_staged(next,refreshed_normal)
	# Commit only after every owned row has its original slot, hit control and
	# existing owner texture. The complete current bag remains caller-owned.
	for reference: String in hits:
		var old: Dictionary=_hits.get(reference,{})
		if old.is_empty() or not is_instance_valid(old.get("native_slot_scene")):continue
		var reused: Dictionary=hits[reference].native_slot_scene.reuse_bound_source_scene_from(Slots.ICON,old.native_slot_scene,Slots.ICON)
		if reused.get("reused",false):hits[reference]["native_icon_scene"]=reused.player
	var kept_scroll: Variant=null
	if is_instance_valid(previous):
		# A refresh (selection, count change) rebuilds the scene: keep the
		# HUD's drawing order and the rows the player had scrolled to.
		next.z_index=previous.z_index
		if is_instance_valid(_scroll_content):kept_scroll=_scroll_content.position.y
	parent.add_child(next)
	_scene=next
	_inventory_scene=inventory_scene
	_hits=hits
	_bounds=bounds
	_native_capacity=int(model.native_capacity)
	_row_scenes=extra_scenes
	_bind_scroll(inventory_scene,slot_set,extra_rows.size())
	if kept_scroll!=null and is_instance_valid(_scroll_content):_scroll_content.position.y=clampf(float(kept_scroll),_scroll_bottom,_scroll_top)
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
	if _hits.is_empty():return
	var model: Dictionary=_slots.entries()
	if not model.get("ok",false):
		_fallback(_unsupported_result(model))
		return
	for reference: String in _hits:
		var result: Dictionary=_slots.refresh_slot(_hits[reference].native_slot_scene,reference,model)
		if not result.get("ok",false):
			_fallback(_unsupported_result(result))
			return

func _on_native_closed() -> void:
	close()
	closed.emit()

func _forward_scroll_input(event: InputEvent) -> void:
	source_scroll_input.emit(event)
	if not is_instance_valid(_scroll_content):return
	var pressed: Variant=null
	if event is InputEventScreenTouch:pressed=event.pressed
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:pressed=event.pressed
	if pressed!=null:
		_scroll_dragging=bool(pressed)
		if _scroll_dragging:_scroll_moved=0.0
		return
	var delta: float=0.0
	if event is InputEventScreenDrag:delta=event.relative.y
	elif event is InputEventMouseMotion and _scroll_dragging:delta=event.relative.y
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		delta=ROW_PITCH*(1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)
	if delta==0.0:return
	# Screen pixels to scroll-content units (the window is scaled).
	var scale_y: float=absf(_scroll_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0 and not (event is InputEventMouseButton):delta/=scale_y
	_scroll_moved+=absf(delta)
	_scroll_content.position.y=clampf(_scroll_content.position.y+delta,_scroll_bottom,_scroll_top)

## Rows below the authored one extend the original inner container; the
## content may move from its authored top position down to the last row.
func _bind_scroll(inventory_scene: Node2D, slot_set: int, extra_lines: int) -> void:
	_scroll_content=null
	var row: Variant=inventory_scene.get("source_nodes").get(slot_set)
	if not row is Node2D:return
	var content: Node=row.get_parent()
	var row_offset: float=row.position.y
	while content!=null and content.name!="SourceOriginalScrollContent":
		if content is Node2D:row_offset+=(content as Node2D).position.y
		content=content.get_parent()
	if not content is Node2D:return
	_scroll_content=content
	_scroll_top=content.position.y
	# The scroll node's origin is the view's bottom edge (Cocos bottom-left):
	# a content-local y is visible while y+content.position.y <= 0. The
	# authored row is at row_offset (negative: above the inner bottom).
	var last_row_bottom: float=row_offset+ROW_PITCH*float(extra_lines)+ROW_TAIL
	_scroll_bottom=minf(_scroll_top,-last_row_bottom)

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
