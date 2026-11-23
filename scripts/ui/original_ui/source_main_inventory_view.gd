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
signal selection_refreshed
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
# One hidden bounded viewport for somebody reopening the same bag soon.
# It is never input-active, never retained across pack/controller changes,
# and is released by the HUD after this short inactivity window.
const REOPEN_WINDOW_MS: int=5000
const REOPEN_HIT_LIMIT: int=80
var _parked_until: int=0
var _resume_process_mode: int=Node.PROCESS_MODE_INHERIT
var _bound_inputs: Array=[]
var _bound_asset_key: Array=[]
var _authored_assignments: Dictionary={}
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
var _scroll_view_height: float=-1.0
var _scroll_dragging: bool=false
var _scroll_moved: float=0.0
var _row_scenes: Array[Node2D]=[]
## Virtual rows: line -> {slot offset -> reference} for every line below the
## authored one (line 1 = _lines[0]); only lines near the view are built
## (_line_scenes: line -> row scene).
var _lines: Array[Dictionary]=[]
var _line_scenes: Dictionary={}
var _line_slot_set: int=SLOT_SET
var _line_offsets: Array[int]=[]
var _line_variant: String="Nd_Slot"
## Lines built beyond each edge of the view, and freed past KEEP_LINES.
const BUILD_LINES: int=2
const KEEP_LINES: int=4
## What the built slots depend on besides counts/markers/selection (order,
## references, item records, layout); equal keys allow a rows-only refresh.
var _layout: int=0
var _marker_key: int=0
## Work counters: full stages, row scenes built, rows-only refreshes and
## slots patched by them.
var stats: Dictionary={"stages":0,"line_builds":0,"lines_freed":0,"rows_only":0,"slot_patches":0,"reopens":0}

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
	var started: int=FRAME_HITCH.now()
	var reused: Dictionary=_try_reopen(parent)
	if reused.get("ok",false):
		FRAME_HITCH.detail("ui.inventory_reopen",started)
		return reused
	if _parked_until!=0: invalidate_cache()
	return _stage(parent,true)

func is_open() -> bool:
	return _parked_until==0 and is_instance_valid(_scene) and not _scene.is_queued_for_deletion() and _scene.is_inside_tree()

func close(keep_warm: bool=true) -> void:
	close_search()
	if not keep_warm: invalidate_cache(); return
	if not is_open():return
	if _hits.size()>REOPEN_HIT_LIMIT or not is_instance_valid(_scroll_content): invalidate_cache(); return
	_parked_until=Time.get_ticks_msec()+REOPEN_WINDOW_MS
	_resume_process_mode=_scene.process_mode
	_scene.hide()
	_scene.process_mode=Node.PROCESS_MODE_DISABLED
	_scroll_dragging=false
	_scroll_moved=0.0
	# Closing this native presentation never clears selection or owns saves.

func expire_cache() -> void:
	if _parked_until!=0 and Time.get_ticks_msec()>=_parked_until:invalidate_cache()

func invalidate_parked_cache() -> void:
	if _parked_until!=0:invalidate_cache()

func invalidate_cache() -> void:
	var previous: Node2D=_scene
	_parked_until=0
	_scene=null
	_inventory_scene=null
	_bounds=null
	_scroll_content=null
	_scroll_view_height=-1.0
	_hits.clear()
	_row_scenes.clear()
	_line_scenes.clear()
	_lines.clear()
	_bound_inputs.clear()
	_bound_asset_key.clear()
	_authored_assignments.clear()
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func _source_asset_key() -> Array:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	return [str(_pack.get("manifest_sha256")) if _pack!=null else "",str(_pack.get("root")) if _pack!=null else "",bag.get("native_inventory_asset_revision") if bag!=null else null]

# These scalars are supplied by the existing owner. An unknown revision never
# takes the no-snapshot path (e.g. external legacy hosts).
func _owner_inputs() -> Array:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	if bag==null:return []
	var revision: Variant=bag.get("inventory_list_rebuilds")
	if not revision is int or bag.get("inventory_grid_dirty")!=false:return []
	var search: Variant=bag.get("search_line")
	return [revision,bag.get("category_filter"),search.text if search is LineEdit else "",bag.get("selected_item"),_marker_inputs()]

func _try_reopen(parent: Node) -> Dictionary:
	expire_cache()
	if _parked_until==0 or not is_instance_valid(_scene) or _scene.is_queued_for_deletion() or _scene.get_parent()!=parent:return {}
	if _bound_asset_key!=_source_asset_key() or not _slots._identities().get("ok",false):return {}
	var bag: Object=_bag.get_ref() if _bag!=null else null
	if bag==null or bag.get("detail_active")==true:return {}
	var branch: Dictionary=_owner_branch(bag)
	if not branch.get("ok",false) or int(branch.capacity)!=_native_capacity:return {}
	var inputs: Array=_owner_inputs()
	var model: Dictionary={}
	if inputs.is_empty() or inputs!=_bound_inputs:
		model=_eligible_model()
		if not model.get("ok",false) or _layout_key(model)!=_layout:return {}
	if not _scene.play("Inventory_All_On",false).get("ok",false):return {}
	_inventory_scene.seek_frame(70.0 if _native_capacity==8 else 86.0)
	if not _chrome.refresh_existing(_inventory_scene).get("ok",false):return {}
	if not _chrome.bind_presented(_inventory_scene).get("ok",false):return {}
	if not model.is_empty() and _patch_current_rows(model)<0:return {}
	# Match fresh-open scroll behavior; scrolling while closed is impossible.
	_scroll_content.position.y=_scroll_top
	if not _sync_lines(model).get("ok",false):return {}
	# An armed use label may have expired while the panel was hidden.
	for reference: String in _hits:
		if not _slots.refresh_action(_hits[reference].native_slot_scene,reference).get("ok",false):return {}
	_parked_until=0
	_scene.process_mode=_resume_process_mode
	_scene.show()
	_bound_inputs=_owner_inputs()
	stats.reopens+=1
	var shown: Dictionary=_open_result()
	shown["reused_scene"]=true
	native_scene_changed.emit(shown.duplicate(true))
	return shown

func refresh() -> Dictionary:
	if _refreshing:return {"ok":true,"handled":is_open(),"refresh_pending":true}
	if not is_open():return _unsupported("source_inventory_view_not_open")
	var parent: Object=_parent.get_ref() if _parent!=null else null
	if parent==null:return _fallback(_unsupported("source_inventory_view_canvas_unavailable"))
	return _stage(parent,false)

func refresh_chrome() -> Dictionary:
	# The HUD has established that all row/selection/layout inputs are unchanged.
	# Keep live slots, playback, scroll, hit controls and texture owners intact.
	if _refreshing:return {"ok":true,"handled":is_open(),"refresh_pending":true}
	if not is_open():return _unsupported("source_inventory_view_not_open")
	if _chrome==null or _slots==null or not is_instance_valid(_inventory_scene):return refresh()
	if not _slots._identities().get("ok",false):return refresh()
	var started: int=FRAME_HITCH.now()
	var result: Dictionary=_chrome.refresh_existing(_inventory_scene)
	FRAME_HITCH.detail("ui.inventory_chrome",started)
	if not result.get("ok",false):return refresh()
	var shown: Dictionary=presentation()
	shown["ok"]=true
	shown["handled"]=true
	shown["chrome_only"]=true
	return shown

## Counts, lock/equip markers or selection changed while the rows, their
## order, item records and layout did not: patch the built slots' amount
## text and markers in place (no icon is re-applied, the scroll and every
## scene stay). Anything else (or a failed patch) rebuilds via refresh().
func refresh_rows() -> Dictionary:
	if _refreshing:return {"ok":true,"handled":is_open(),"refresh_pending":true}
	if not is_open():return _unsupported("source_inventory_view_not_open")
	if _chrome==null or _slots==null or not is_instance_valid(_inventory_scene) or _layout==0 or _source_asset_key()!=_bound_asset_key:return refresh()
	var started: int=FRAME_HITCH.now()
	var model: Dictionary=_eligible_model()
	if not model.get("ok",false) or _layout_key(model)!=_layout:return refresh()
	var result: Dictionary=_chrome.refresh_existing(_inventory_scene)
	if not result.get("ok",false):return refresh()
	var patched: int=_patch_current_rows(model)
	if patched<0:return refresh()
	_bound_inputs=_owner_inputs()
	stats.rows_only+=1
	stats.slot_patches+=patched
	FRAME_HITCH.detail("ui.inventory_rows",started)
	var shown: Dictionary=presentation()
	shown["ok"]=true
	shown["handled"]=true
	shown["rows_only"]=true
	shown["slots_patched"]=patched
	return shown

## Shared by a live refresh and a still-hidden eligible reopen. A failed
## patch must not expose any partially refreshed slot.
func _patch_current_rows(model: Dictionary) -> int:
	var markers: int=_marker_inputs()
	var marker_changed: bool=markers!=_marker_key
	var bag: Object=_bag.get_ref() if _bag!=null else null
	var selected: Variant=bag.get("selected_item") if bag!=null else null
	var patched: int=0
	for reference: String in _hits:
		var hit: Dictionary=_hits[reference]
		var current: Variant=model.owned_by_reference.get(reference)
		if not current is Dictionary:return -1
		var was_selected: bool=bool(hit.get("shown_selected",false))
		if not marker_changed and int((hit.owned_row as Dictionary).get("amount",-1))==int(current.get("amount",-2)) and was_selected==(selected==reference):continue
		var patch: Dictionary=_slots.refresh_slot(hit.native_slot_scene,reference,model)
		if not patch.get("ok",false):return -1
		hit["owned_row"]=(current as Dictionary).duplicate(true)
		hit["shown_selected"]=selected==reference
		patched+=1
	_marker_key=markers
	return patched

func select(reference: String) -> Dictionary:
	if not is_open():return _unsupported("source_inventory_view_not_open")
	return _slots.select_reference(reference)

## The bag armed or disarmed an item (single tap / timeout / use): update
## the original Label_Center marker on every built slot.
func refresh_actions() -> Dictionary:
	if not is_open():return _unsupported("source_inventory_view_not_open")
	var shown: int=0
	for reference: String in _hits:
		var result: Dictionary=_slots.refresh_action(_hits[reference].native_slot_scene,reference)
		if not result.get("ok",false):return result
		if not _slots.action_text(reference).is_empty():shown+=1
	return {"ok":true,"shown":shown}

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
	var scroll: Variant=(scroll_node.get_meta("source_scroll") if scroll_node.has_meta("source_scroll") else null) if is_instance_valid(scroll_node) else null
	var bounds: Variant=scroll.input_control() if is_instance_valid(scroll) and scroll.has_method("input_control") else null
	if not control is Control or not is_instance_valid(control) or not bounds is Control or not is_instance_valid(bounds):return {}
	return {"ok":true,"reference":reference,"control":control,"scroll":bounds,"source_native":true}

func presentation() -> Dictionary:
	if _parked_until!=0:return {"partial_source_scene":true,"complete_screen_contract":false}
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
		var accepted: Dictionary={}
		if slot_contract.owner_results.has(offset):
			var owner_result: Dictionary=slot_contract.owner_results[offset]
			accepted=native_slot.set_bound_source_visual_result(Slots.ICON,owner_result)
			if not accepted.get("ok",false) or (not accepted.get("texture_assigned",false) and not accepted.get("source_scene_assigned",false)):return _reject_staged(next,{"ok":false,"code":"source_inventory_view_owned_icon_not_consumed","reference":assignments[offset],"owner_result":owner_result,"source_asset_result":accepted})
			result=native_slot.set_bound_visible(Slots.ICON,true)
			if not result.get("ok",false):return _reject_staged(next,result)
		var button_node: Variant=native_slot.get("source_nodes").get(Slots.BUTTON)
		var button: Variant=(button_node.get_meta("source_button") if button_node.has_meta("source_button") else null) if is_instance_valid(button_node) else null
		var control: Variant=button.get("_input_area") if is_instance_valid(button) else null
		if not control is Control:return _reject_staged(next,{"ok":false,"code":"source_inventory_view_original_slot_hit_control_missing","offset":offset})
		var reference: String=assignments[offset]
		var raw: Dictionary=(model.owned_by_reference[reference] as Dictionary).duplicate(true)
		if not slot_contract.owner_results.has(offset): _label_missing_icon(control,raw)
		hits[reference]={"from":"inventory","id":reference,"reference":reference,"entry":{"kind":"item","id":raw.get("name")},"owned_row":raw,"texture":accepted.get("texture"),"native_icon_scene":accepted.get("player"),"control":control,"button":control,"native_slot_scene":native_slot,"slot_project_offset":offset,"slot_set_project_offset":slot_set,"source_asset_evidence":accepted.get("evidence",{}),"use_on_single_click":false,"shown_selected":model.get("selected_reference")==reference}
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
	var previous_hits: Dictionary=_hits
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
	_row_scenes.clear()
	_line_scenes.clear()
	_lines=extra_rows
	_line_slot_set=slot_set
	_line_offsets=slot_offsets
	_line_variant=str(model.authored_variant)
	_layout=_layout_key(model)
	_marker_key=_marker_inputs()
	_bound_inputs=_owner_inputs()
	_bound_asset_key=_source_asset_key()
	_authored_assignments=assignments
	_bind_scroll(inventory_scene,slot_set,extra_rows.size())
	if kept_scroll!=null and is_instance_valid(_scroll_content):_scroll_content.position.y=clampf(float(kept_scroll),_scroll_bottom,_scroll_top)
	# Rows below the authored one are built only while in (or near) view;
	# scrolling builds the rows that come in (_sync_lines).
	var lined: Dictionary=_sync_lines(model,previous_hits)
	if not lined.get("ok",false):
		_refreshing=false
		if is_instance_valid(previous) and not previous.is_queued_for_deletion():
			previous.hide()
			previous.queue_free()
		return _fallback(_unsupported_result(lined))
	stats.stages+=1
	_chrome.bind_presented(inventory_scene)
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	_refreshing=false
	var shown: Dictionary=_open_result()
	native_scene_changed.emit(shown.duplicate(true))
	return shown

func _open_result() -> Dictionary:
	var shown: Dictionary=presentation()
	shown["ok"]=true
	shown["handled"]=true
	shown["assignments"]=_authored_assignments.duplicate()
	shown["expanded"]=_native_capacity==8
	shown["authored_slot_set_project"]=_line_slot_set
	shown["authored_variant"]=_line_variant
	shown["parent_contract"]=Chrome.parent_contract(PARENT)
	shown["logical_open_clip_consumption"]="one_shot_Inventory_All_On_5_17"
	return shown

func _reject_staged(scene: Node2D, reason: Dictionary) -> Dictionary:
	scene.free()
	_refreshing=false
	return _stage_failed(_unsupported_result(reason))

func _stage_failed(reason: Dictionary) -> Dictionary:
	return _fallback(reason) if is_open() else reason

func _fallback(reason: Dictionary) -> Dictionary:
	close(false)
	return_to_current_requested.emit(reason.duplicate(true))
	return reason

func _on_category_changed(_model: Dictionary) -> void:
	if is_open() and not _refreshing:refresh()

func _on_selection_changed(_reference: String) -> void:
	if _parked_until!=0 or _hits.is_empty():return
	var model: Dictionary=_slots.entries()
	if not model.get("ok",false):
		_fallback(_unsupported_result(model))
		return
	var bag: Object=_bag.get_ref() if _bag!=null else null
	for reference: String in _hits:
		var result: Dictionary=_slots.refresh_slot(_hits[reference].native_slot_scene,reference,model)
		if not result.get("ok",false):
			_fallback(_unsupported_result(result))
			return
		_hits[reference]["shown_selected"]=bag!=null and bag.get("selected_item")==reference
	selection_refreshed.emit()

func _on_native_closed() -> void:
	close()
	closed.emit()

func _forward_scroll_input(event: InputEvent) -> void:
	if _parked_until!=0:return
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
	var lined: Dictionary=_sync_lines()
	if not lined.get("ok",false):_fallback(_unsupported_result(lined))

## A drag that the HUD's pointer transfer captured on a slot (it consumes
## the touch so the slot never sees it): move the rows by the finger's screen
## delta like a drag on the empty list. Returns the content offset after it.
func scroll_by(screen_delta_y: float) -> Dictionary:
	if not is_open() or not is_instance_valid(_scroll_content) or not is_finite(screen_delta_y):return _unsupported("source_inventory_view_scroll_unavailable")
	var delta: float=screen_delta_y
	var scale_y: float=absf(_scroll_content.get_global_transform_with_canvas().get_scale().y)
	if scale_y>0.0:delta/=scale_y
	_scroll_moved+=absf(delta)
	_scroll_content.position.y=clampf(_scroll_content.position.y+delta,_scroll_bottom,_scroll_top)
	var lined: Dictionary=_sync_lines()
	if not lined.get("ok",false):
		_fallback(_unsupported_result(lined))
		return lined
	return {"ok":true,"position":_scroll_content.position.y,"top":_scroll_top,"bottom":_scroll_bottom}

## Rows below the authored one extend the original inner container; the
## content may move from its authored top position down to the last row.
func _bind_scroll(inventory_scene: Node2D, slot_set: int, extra_lines: int) -> void:
	_scroll_content=null
	_scroll_view_height=-1.0
	var row: Variant=inventory_scene.get("source_nodes").get(slot_set)
	if not row is Node2D:return
	var content: Node=row.get_parent()
	var row_offset: float=row.position.y
	while content!=null and content.name!="SourceOriginalScrollContent":
		if content is Node2D:row_offset+=(content as Node2D).position.y
		content=content.get_parent()
	if not content is Node2D:return
	_scroll_content=content
	_row_y=row_offset
	_scroll_top=content.position.y
	# The scroll node's origin is the view's bottom edge (Cocos bottom-left):
	# a content-local y is visible while y+content.position.y <= 0. The
	# authored row is at row_offset (negative: above the inner bottom).
	var last_row_bottom: float=row_offset+ROW_PITCH*float(extra_lines)+ROW_TAIL
	_scroll_bottom=minf(_scroll_top,-last_row_bottom)

## Lines [first, last] (1-based extra lines) within `margin` lines of the
## view at the current scroll; (1, 0) when there are none. The view is the
## original ScrollView's own height; without it every line counts.
func line_range(margin: int) -> Vector2i:
	if _lines.is_empty():return Vector2i(1,0)
	var height: float=_view_height()
	if not is_instance_valid(_scroll_content) or height<=0.0:return Vector2i(1,_lines.size())
	var position: float=_scroll_content.position.y
	# Content-local y of line L is _row_y+ROW_PITCH*L; it is in view while
	# -height <= y+position <= 0 (the scroll origin is the view's bottom).
	var first: int=ceili((-height-position-_row_y)/ROW_PITCH)-margin
	var last: int=floori((-position-_row_y)/ROW_PITCH)+margin
	return Vector2i(maxi(1,first),mini(_lines.size(),last))

var _row_y: float=0.0

func _view_height() -> float:
	if _scroll_view_height>=0.0:return _scroll_view_height
	if _pack==null:return 0.0
	var node: Dictionary=Scene._node_at_offset(_pack.scene(Slots.PARENT).get("nodeTree",{}),int(Slots.PARENTS.get(_line_slot_set,0)))
	var options: Dictionary=node.get("options",{})
	var size: Array=options.get("widgetOptions",options.get("nodeOptions",{})).get("size",[0,0])
	_scroll_view_height=float(size[1]) if size.size()>1 else 0.0
	return _scroll_view_height

## Builds the lines that came near the view and frees those far from it.
## `model` (optional) is the owner snapshot to build from; `reuse` maps
## reference -> previous hit whose icon scene may be adopted.
func _sync_lines(model: Dictionary={}, reuse: Dictionary={}) -> Dictionary:
	if not is_instance_valid(_inventory_scene):return {"ok":true}
	var keep: Vector2i=line_range(KEEP_LINES)
	for line: Variant in _line_scenes.keys():
		if int(line)>=keep.x and int(line)<=keep.y:continue
		var old: Variant=_line_scenes[line]
		_line_scenes.erase(line)
		_row_scenes.erase(old)
		for reference: Variant in (_lines[int(line)-1] as Dictionary).values():_hits.erase(reference)
		if is_instance_valid(old):
			old.hide()
			old.queue_free()
		stats.lines_freed+=1
	var wanted: Vector2i=line_range(BUILD_LINES)
	for line: int in range(wanted.x,wanted.y+1):
		if _line_scenes.has(line):continue
		if model.is_empty():
			model=_eligible_model()
			if not model.get("ok",false):return model
		var built: Dictionary=_build_line(line,model,reuse)
		if not built.get("ok",false):return built
	return {"ok":true}

func _build_line(line: int, model: Dictionary, reuse: Dictionary) -> Dictionary:
	var assignments: Dictionary=_lines[line-1]
	var authored_row: Variant=_inventory_scene.get("source_nodes").get(_line_slot_set)
	if not authored_row is Node2D or authored_row.get_parent()==null:return {"ok":false,"code":"source_inventory_view_original_row_missing"}
	var row_contract: Dictionary=_slots.build(_line_slot_set,assignments,{"role":"source_scroll","input":Callable(self,"_forward_scroll_input")},_line_variant,model)
	if not row_contract.get("ok",false):return row_contract
	var row_binding: Dictionary=row_contract.bindings[_line_slot_set]
	var row_scope: Array[int]=[]
	row_scope.assign(row_binding.source_node_offsets)
	var row_scene:=Scene.new()
	var row_result: Dictionary=row_scene.configure_nodes(_pack,Slots.SET_MEMBER,row_scope,row_binding.bindings)
	if not row_result.get("ok",false):
		row_scene.free()
		return row_result
	var hits: Dictionary={}
	var bag: Object=_bag.get_ref() if _bag!=null else null
	for offset: int in _line_offsets:
		if not assignments.has(offset):continue
		var row_slot: Dictionary=row_scene.project_player([offset])
		if not row_slot.get("ok",false):
			row_scene.free()
			return row_slot
		var row_native: Node2D=row_slot.player
		var row_accepted: Dictionary={}
		var row_reference: String=assignments[offset]
		if row_contract.owner_results.has(offset):
			var row_owner: Dictionary=row_contract.owner_results[offset]
			row_accepted=row_native.set_bound_source_visual_result(Slots.ICON,row_owner)
			if not row_accepted.get("ok",false) or (not row_accepted.get("texture_assigned",false) and not row_accepted.get("source_scene_assigned",false)):
				row_scene.free()
				return {"ok":false,"code":"source_inventory_view_owned_icon_not_consumed","reference":row_reference,"owner_result":row_owner,"source_asset_result":row_accepted}
			var shown: Dictionary=row_native.set_bound_visible(Slots.ICON,true)
			if not shown.get("ok",false):
				row_scene.free()
				return shown
		var row_button_node: Variant=row_native.get("source_nodes").get(Slots.BUTTON)
		var row_button: Variant=(row_button_node.get_meta("source_button") if row_button_node.has_meta("source_button") else null) if is_instance_valid(row_button_node) else null
		var row_control: Variant=row_button.get("_input_area") if is_instance_valid(row_button) else null
		if not row_control is Control:
			row_scene.free()
			return {"ok":false,"code":"source_inventory_view_original_slot_hit_control_missing","offset":offset}
		var row_raw: Variant=model.owned_by_reference.get(row_reference)
		if not row_raw is Dictionary:
			row_scene.free()
			return {"ok":false,"code":"source_inventory_view_owner_reference_missing","reference":row_reference}
		if not row_contract.owner_results.has(offset): _label_missing_icon(row_control,row_raw)
		hits[row_reference]={"from":"inventory","id":row_reference,"reference":row_reference,"entry":{"kind":"item","id":row_raw.get("name")},"owned_row":(row_raw as Dictionary).duplicate(true),"texture":row_accepted.get("texture"),"native_icon_scene":row_accepted.get("player"),"control":row_control,"button":row_control,"native_slot_scene":row_native,"slot_project_offset":offset,"slot_set_project_offset":_line_slot_set,"row":line,"source_asset_evidence":row_accepted.get("evidence",{}),"use_on_single_click":false,"shown_selected":bag!=null and bag.get("selected_item")==row_reference}
	row_scene.position=authored_row.position+Vector2(0.0,ROW_PITCH*float(line))
	authored_row.get_parent().add_child(row_scene)
	for reference: String in hits:
		var old: Dictionary=reuse.get(reference,{})
		if not old.is_empty() and is_instance_valid(old.get("native_slot_scene")):
			var reused: Dictionary=hits[reference].native_slot_scene.reuse_bound_source_scene_from(Slots.ICON,old.native_slot_scene,Slots.ICON)
			if reused.get("reused",false):hits[reference]["native_icon_scene"]=reused.player
		var control: Control=hits[reference].control
		if not control.gui_input.is_connected(_forward_scroll_input):control.gui_input.connect(_forward_scroll_input)
		_hits[reference]=hits[reference]
	_line_scenes[line]=row_scene
	_row_scenes.append(row_scene)
	stats.line_builds+=1
	return {"ok":true,"line":line}

func _label_missing_icon(control: Control, entry: Dictionary) -> void:
	# Keep the owned slot identifiable when its original image is missing.
	# The label leaves the quantity, gesture target and original asset alone.
	var bag: Object=_bag.get_ref() if _bag!=null else null
	var name_value: String=str(entry.get("name",""))
	var record: Dictionary=bag.call("_find_item_record",str(entry.reference)) if bag!=null and bag.has_method("_find_item_record") else {}
	var title: String=preload("res://scripts/ui/source523_item_identity.gd").display_name(record,name_value)
	if title.is_empty(): return
	var label:=Label.new()
	label.name="MissingIconItemName"
	label.text=title
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size",11)
	control.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left=2.0
	label.offset_right=-2.0
	label.offset_top=4.0
	label.offset_bottom=maxf(18.0,control.size.y*0.62)
	control.tooltip_text=title

## Everything the built slots take from the owner besides amounts, markers
## and selection: layout, the displayed order of references, each row
## (without its amount) and the physical item record behind it (without
## its stack quantity), and enhancement levels.
func _layout_key(model: Dictionary) -> int:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	var state: Variant=bag.get("character_state") if bag!=null else null
	var instances: Variant=state.get("item_instances",{}) if state is Dictionary else {}
	var parts: Array=[model.get("expanded"),model.get("native_capacity"),state.get("enhancement_levels") if state is Dictionary else null]
	for row: Dictionary in model.get("current_display_rows",[]):
		var shown: Dictionary=row.duplicate()
		shown.erase("amount")
		var reference: String=str(row.get("reference",""))
		var physical: Variant=null
		if "@@@" in reference and instances is Dictionary:
			physical=(instances as Dictionary).get(reference.get_slice("@@@",1))
			if physical is Dictionary:
				physical=(physical as Dictionary).duplicate()
				for quantity: String in QUANTITY_FIELDS:(physical as Dictionary).erase(quantity)
		parts.append([shown,physical])
	return hash(parts)

## Stack counts of a physical item (lineage_inventory_ui._inventory_entries).
const QUANTITY_FIELDS: Array[String]=["source_native_stack_quantity","source_reward_quantity","source_awakening_quantity","source_card_currency_quantity"]

func _marker_inputs() -> int:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	var state: Variant=bag.get("character_state") if bag!=null else null
	if not state is Dictionary:return 0
	return hash([state.get("equipped_items"),state.get("equipped_ammo"),state.get("item_locks")])

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
