extends RefCounted
## Native inventory chrome and existing bag controller only. Physical item
## selection/use/ownership/save and source slot placement remain their owners'.
const MEMBER="UI/FloatingUi/Inventory_All.csb"
const SHA256="c2c021fbc49f0699f2002a3f1cb73f523c3dd629bd1df567192dcb7f4da22293"
const CLOSE=31020
const TABS={"전체":[41748,40288],"장비":[38868,37448],"소모품":[36028,34608],"기타":[33196,31784]}
const GOLD_TEXT=13424
const CAPACITY_TEXT=12476
const EXTENSION_BUTTON=21648
const SEARCH_BUTTON=44780
const CLEAR_SEARCH_BUTTON=47700
const HAS_EXTENSION=1
const HAS_SEARCH=2
const HAS_SORT=4
const HAS_DELETE=8
const HAS_LOCK=16
const HAS_SORT_BUTTON=32
const HAS_CLEAR_SEARCH=64
const HAS_MOVE=128
const HAS_MOVE_CANCEL=256
const SORT_BUTTON=19772
const SORT_OPTIONS=1476
const SORT_BACKGROUND=11736
const DELETE_BUTTON=24648
const LOCK_BUTTON=26528
const MOVE_BUTTON=28988
const MOVE_CANCEL=17760
const SORT_DEFAULT_DOWN={"expiry":false,"weight":true}
const SORT_KEYS={"expiry":8004,"weight":4764,"category":2864}
const SORT_LABELS: Array[int]=[10096,8780,6804,5540,3560,2968]
const SORT_ARROWS={"expiry":[[9764,8448],[9384,8116]],"weight":[[6472,5208],[6140,4876]]}
const FRAMES={
 false:{"parent":55184,"background":60672,"offsets":[60672,59888,59516,59136,58756,58376]},
 true:{"parent":43300,"background":54484,"offsets":[54484,53776,53404,53028,52648,52268,51888]}
}
# Both retained current523 parents declare this same named source clip.
# Choosing the application's parent/caller remains explicit; alpha0 is not
# evidence that the top-level source is unusable or should be replaced.
const PARENTS={
	"UI/FloatingUiScene.csb":{"sha256":"b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8","project_offset":1572},
	"UI/FloatingUi/FloatingUiScene.csb":{"sha256":"70e58e33ecce971de43b558c1464620a799dd33ac6f98558a91401cb996bc14d","project_offset":9776}
}
signal model_changed(model: Dictionary)
signal search_requested
signal move_mode_changed
var _pack: RefCounted
var _inventory: WeakRef
var _scene: WeakRef
var _dismiss_presenter: Callable
var _sort_open: bool=false
var _sort_directions: Dictionary={}
var _move_reference: String=""


static func parent_contract(parent_member: String) -> Dictionary:
	if not PARENTS.has(parent_member):return _fail("source_main_inventory_explicit_parent_required")
	return {"ok":true,"member":parent_member,"sha256":PARENTS[parent_member].sha256,"project_offset":PARENTS[parent_member].project_offset,"child_member":MEMBER,"child_sha256":SHA256,"original_clip":{"name":"Inventory_All_On","start_frame":5,"end_frame":17},"loop_declared":false,"original_design_size":[1200,675],"requires_parent_timeline":true,"complete_screen_contract":false}

func configure(pack: RefCounted, hud: Node, dismiss_presenter: Callable=Callable(), include_rows: bool=true) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_inventory_identity_mismatch")
	if not is_instance_valid(hud):return _fail("source_main_inventory_hud_unavailable")
	var inventory_ui: Variant=hud.get("lineage_inventory_ui")
	if not is_instance_valid(inventory_ui):return _fail("source_main_inventory_existing_bag_required")
	for method: String in ["hide_inventory","_set_category"]:
		if not inventory_ui.has_method(method):return {"ok":false,"code":"source_main_inventory_existing_bag_api_missing","method":method}
	_pack=pack
	_inventory=weakref(inventory_ui)
	_dismiss_presenter=dismiss_presenter
	return snapshot(include_rows)

func snapshot(include_rows: bool=true) -> Dictionary:
	var inventory_ui: Object=_live_inventory()
	if inventory_ui==null:return _fail("source_main_inventory_existing_bag_unavailable")
	var category: Variant=inventory_ui.get("category_filter")
	if not category is String or not TABS.has(category):return _fail("source_main_inventory_existing_category_unknown")
	var inventory: Variant=inventory_ui.get("inventory")
	var rows: Variant=inventory_ui.get("legacy_rows")
	if not inventory is Dictionary or not rows is Array:return _fail("source_main_inventory_existing_rows_unavailable")
	var model: Dictionary={"ok":true,"category":category,"selected_reference":inventory_ui.get("selected_item"),"partial_source_scene":true,"complete_screen_contract":false}
	if include_rows:
		model["inventory"]=inventory.duplicate(true)
		model["rows"]=rows.duplicate(true)
	# Use the existing bag's formatter/labels. No amount, capacity, stack,
	# ownership, item lookup or historical image-pack fallback is recreated.
	var state: Variant=inventory_ui.get("character_state")
	if state is Dictionary and typeof(state.get("gold"))==TYPE_INT and inventory_ui.has_method("_format_number"):
		model["gold_text"]=inventory_ui.call("_format_number",int(state.gold))
	var capacity: Variant=inventory_ui.get("capacity_label")
	if is_instance_valid(capacity) and capacity is Label:
		# Original Nd_Number/Text_Number is the 120/120 count, not a weight
		# label. Renewal's existing formatter prefixes its label with weight
		# percentage; keep only that same owner's final count/capacity part.
		var count: String=capacity.text.get_slice(" · ",capacity.text.get_slice_count(" · ")-1)
		var fields: PackedStringArray=count.split("/")
		if fields.size()==2 and fields[0].strip_edges().is_valid_int() and fields[1].strip_edges().is_valid_int():model["capacity_text"]=count
	return model

func build(remaining: Dictionary={}, expanded: bool=false, include_rows: bool=true) -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_inventory_identity_mismatch")
	var model: Dictionary=snapshot(include_rows)
	if not model.get("ok",false):return model
	# Scene trees are disk records on the installed pack, or detached copies
	# of an in-memory tree. Resolve the active scene at most once here.
	var layout: Dictionary=_pack.call("layout_source",MEMBER) if _pack.has_method("layout_source") else {}
	var separate_layout: bool=layout.get("nodeTree") is Dictionary
	var active: Dictionary={} if separate_layout else _pack.scene(MEMBER)
	var tree: Dictionary=layout if separate_layout else active
	if not tree.get("nodeTree") is Dictionary:return _fail("source_main_inventory_original_layout_missing")
	# Received tab/close subtrees contain only their original Sprite icons
	# and title textures; they serialize no Text/TextBMFont literal children.
	# Do not manufacture text labels or bind nearby dynamic preview strings.
	var frame: Dictionary=FRAMES[expanded]
	var roots: Array[int]=[CLOSE]
	roots.append_array(frame.offsets)
	var bindings: Dictionary={CLOSE:{"role":"button","activate":Callable(self,"close")}}
	bindings[int(frame.background)]={"role":"consume"}
	bindings[int(frame.parent)]={"visible":true}
	var bag: Object=_live_inventory()
	var wants: int=0
	if bag!=null and bag.has_method("_toggle_expanded"):wants|=HAS_EXTENSION
	if expanded and _pack.manifest.get("scenes",{}).has("UI/FloatingUi/Inventory_Popup_Keypad.csb"):wants|=HAS_SEARCH
	if (wants & HAS_SEARCH) != 0 and bag != null and bag.has_method("clear_inventory_search"):wants|=HAS_CLEAR_SEARCH
	if bag.has_method("sort_inventory_source"):wants|=HAS_SORT|HAS_SORT_BUTTON
	if bag.has_method("request_selected_delete"):wants|=HAS_DELETE
	if bag.has_method("_toggle_lock"):wants|=HAS_LOCK
	if bag.has_method("move_inventory_before"):wants|=HAS_MOVE|HAS_MOVE_CANCEL
	# Full layout geometry and the permitted, filtered active scene may differ.
	# UI affordances must be admitted by the latter, never by layout alone.
	if separate_layout and wants!=0:active=_pack.scene(MEMBER)
	var found: int=_control_presence(active.get("nodeTree",{}),wants)
	# Old normal-only packs keep working. Extension controls are included
	# only when the permitted source scope actually contains their original.
	if found & HAS_EXTENSION:
		roots.append(EXTENSION_BUTTON)
		bindings[EXTENSION_BUTTON]={"role":"button","activate":Callable(self,"toggle_expanded")}
	# This entry belongs specifically to the authored extension branch.
	if found & HAS_SEARCH:
		roots.append(SEARCH_BUTTON)
		bindings[SEARCH_BUTTON]={"role":"button","activate":Callable(self,"_search_requested")}
		bindings[46132]={"role":"static_source_text"}
	if (found & (HAS_SEARCH | HAS_CLEAR_SEARCH)) == (HAS_SEARCH | HAS_CLEAR_SEARCH):
		roots.append(CLEAR_SEARCH_BUTTON)
		bindings[CLEAR_SEARCH_BUTTON] = {"role":"button", "activate":Callable(self, "clear_search")}
		bindings[48368] = {"role":"static_source_text"} # Btn_Reset_All/Normal/Label
		bindings[47752] = {"visible":false} # The enabled control uses the Normal label.
		bindings[47804] = {"role":"static_source_text"}
	if (found & (HAS_SORT|HAS_SORT_BUTTON))==(HAS_SORT|HAS_SORT_BUTTON):
		roots.append_array([SORT_BUTTON,SORT_OPTIONS])
		bindings[SORT_BUTTON]={"role":"button","activate":Callable(self,"toggle_sort")}
		bindings[SORT_OPTIONS]={"visible":_sort_open}
		bindings[1548]={"visible":false} # authored preview highlight, not a new input
		for field: String in SORT_KEYS:
			bindings[SORT_KEYS[field]]={"role":"button","activate":Callable(self,"sort_by").bind(field)}
		for offset: int in SORT_LABELS:bindings[offset]={"role":"static_source_text"}
		for field: String in SORT_ARROWS:
			var down: bool=bool(_sort_directions.get(field,SORT_DEFAULT_DOWN[field]))
			for offset: int in SORT_ARROWS[field][0]:bindings[offset]={"visible":down}
			for offset: int in SORT_ARROWS[field][1]:bindings[offset]={"visible":not down}
	if found & HAS_DELETE:
		roots.append(DELETE_BUTTON)
		var can_delete: bool=_selected_can_delete(bag,str(model.selected_reference))
		bindings[DELETE_BUTTON]={"role":"button","activate":Callable(self,"request_delete"),"displaystate":can_delete}
		_set_button_variants(bindings,25284,24700,false,can_delete)
	if found & HAS_LOCK:
		roots.append(LOCK_BUTTON)
		bindings[LOCK_BUTTON]={"role":"button","activate":Callable(self,"toggle_lock")}
		var locked: bool=_selected_is_locked(bag,str(model.selected_reference))
		_set_button_variants(bindings,27744,26584,locked,not str(model.selected_reference).is_empty())
		bindings[27164]={"visible":locked}
	if (found & (HAS_MOVE | HAS_MOVE_CANCEL)) == (HAS_MOVE | HAS_MOVE_CANCEL):
		var moving: bool=move_pending()
		var can_move: bool=not str(model.selected_reference).is_empty()
		roots.append_array([MOVE_BUTTON,MOVE_CANCEL])
		bindings[MOVE_BUTTON]={"role":"button","activate":Callable(self,"start_move"),"displaystate":can_move,"visible":not moving}
		bindings[29620]={"visible":can_move}
		bindings[29040]={"visible":not can_move}
		bindings[MOVE_CANCEL]={"role":"button","activate":Callable(self,"cancel_move"),"visible":moving}
		bindings[18420]={"role":"static_source_text"}
		bindings[17864]={"role":"static_source_text"}
		for offset: int in [LOCK_BUTTON,DELETE_BUTTON,SORT_BUTTON]:
			if bindings.has(offset):bindings[offset]["visible"]=not moving
	for category: String in TABS:
		var variants: Array=TABS[category]
		for index: int in range(variants.size()):
			var offset: int=int(variants[index])
			roots.append(offset)
			bindings[offset]={"role":"button","activate":Callable(self,"select_category").bind(category),"visible":(model.category==category) if index==0 else (model.category!=category)}
	if model.has("gold_text"):
		roots.append(GOLD_TEXT)
		roots.append(13052)
		bindings[GOLD_TEXT]={"role":"source_text","text":model.gold_text}
	if model.has("capacity_text"):
		roots.append(CAPACITY_TEXT)
		bindings[CAPACITY_TEXT]={"role":"source_text","text":model.capacity_text}
	var selected: Array[int]=[]
	var matches: Dictionary={}
	for offset: int in roots:matches[offset]=0
	_collect_offsets(tree.nodeTree,matches,selected,{},false)
	for offset: int in roots:
		if int(matches.get(offset,0))!=1:return {"ok":false,"code":"source_main_inventory_core_node_not_unique","offset":offset}
	for offset: int in selected:
		if not bindings.has(offset) and remaining.has(offset):bindings[offset]=remaining[offset].duplicate(true)
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":selected,"bindings":bindings,"model":model,"expanded":expanded,"background_offset":frame.background,"branch_parent_offset":frame.parent,"original_variant_clip":{"name":"Fx_Extension_On","start_frame":40,"end_frame":70} if expanded else {},"native_parent_required":"original Inventory_All root and retained original ancestor chain","original_root_options":tree.nodeTree.get("options",{}).duplicate(true),"static_source_text_offsets":[],"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":[{"field":"original_inventory_rows_and_slot_placement","scroll_offsets":[55712,43832],"slot_project_offsets":[56036,44156],"slot_member":"UI/FloatingUi/Inventory_Slot_Set.csb","missing":"owned row reference to original slot instance and position"},"original_multi_delete_dissolve_mode_contracts"]}

func bind_presented(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or str(scene.get("source_member"))!=MEMBER:return _fail("source_main_inventory_scene_mismatch")
	_scene=weakref(scene)
	return {"ok":true}

func _search_requested() -> Dictionary:
	search_requested.emit()
	return {"ok":true,"existing_search_requested":true,"game_state_written":false}

func clear_search() -> Dictionary:
	var bag: Object = _live_inventory()
	if bag == null or not bag.has_method("clear_inventory_search"):
		return _fail("source_inventory_search_existing_owner_unavailable")
	bag.call("clear_inventory_search")
	return {"ok":true}

func refresh_existing(scene: Node2D) -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_inventory_identity_mismatch")
	# Header-only updates must not silently retain a field that disappeared,
	# or introduce text outside the originally constructed source scope.
	if not is_instance_valid(scene) or str(scene.get("source_member"))!=MEMBER:return _fail("source_main_inventory_scene_mismatch")
	var model: Dictionary=snapshot(false)
	if not model.get("ok",false):return model
	var nodes: Variant=scene.get("source_nodes")
	if not nodes is Dictionary:return _fail("source_main_inventory_existing_scope_unavailable")
	for entry: Array in [[GOLD_TEXT,"gold_text"],[CAPACITY_TEXT,"capacity_text"]]:
		if nodes.has(entry[0])!=model.has(entry[1]):return _fail("source_main_inventory_header_scope_changed")
	return _refresh_model(scene,model)

func refresh(scene: Node2D, include_rows: bool=true) -> Dictionary:
	if not is_instance_valid(scene) or str(scene.get("source_member"))!=MEMBER:return _fail("source_main_inventory_scene_mismatch")
	if not scene.has_method("set_bound_visible") or not scene.has_method("set_bound_text"):return _fail("source_main_inventory_scene_binding_api_missing")
	var model: Dictionary=snapshot(include_rows)
	if not model.get("ok",false):return model
	return _refresh_model(scene,model)

func _refresh_model(scene: Node2D, model: Dictionary) -> Dictionary:
	if not scene.has_method("set_bound_visible") or not scene.has_method("set_bound_text"):return _fail("source_main_inventory_scene_binding_api_missing")
	for category: String in TABS:
		for index: int in range(2):
			var result: Dictionary=scene.set_bound_visible(int(TABS[category][index]),(model.category==category) if index==0 else (model.category!=category))
			if not result.get("ok",false):return result
	for entry: Array in [[GOLD_TEXT,"gold_text"],[CAPACITY_TEXT,"capacity_text"]]:
		if model.has(entry[1]):
			var result: Dictionary=scene.set_bound_text(int(entry[0]),model[entry[1]])
			if not result.get("ok",false):return result
	return {"ok":true,"model":model,"partial_source_scene":true,"complete_screen_contract":false}

static func _selected_is_locked(bag: Object, reference: String) -> bool:
	var state: Dictionary=bag.get("character_state") if bag.get("character_state") is Dictionary else {}
	return bool(state.get("item_locks",{}).get(reference,false))

static func _selected_can_delete(bag: Object, reference: String) -> bool:
	return not reference.is_empty() and (not bag.has_method("selected_can_delete_native") or bag.call("selected_can_delete_native"))

static func _set_button_variants(bindings: Dictionary, normal: int, inactive: int, locked: bool, selected: bool) -> void:
	bindings[normal]={"visible":selected and not locked}
	bindings[inactive]={"visible":not selected}

func refresh_selected_controls(scene: Node2D) -> void:
	var bag: Object=_live_inventory()
	if bag==null or not is_instance_valid(scene):return
	var reference: String=str(bag.get("selected_item"))
	var selected: bool=not reference.is_empty()
	var locked: bool=_selected_is_locked(bag,reference)
	var can_delete: bool=_selected_can_delete(bag,reference)
	if scene.source_nodes.has(DELETE_BUTTON):scene.set_bound_displaystate(DELETE_BUTTON,can_delete)
	if scene.source_nodes.has(MOVE_BUTTON):scene.set_bound_displaystate(MOVE_BUTTON,selected)
	for entry: Array in [[25284,can_delete],[24700,not can_delete],[27744,selected and not locked],[26584,not selected],[27164,selected and locked],[29620,selected],[29040,not selected]]:
		if scene.source_nodes.has(entry[0]):scene.set_bound_visible(entry[0],entry[1])

func move_pending() -> bool:
	return not _move_reference.is_empty()

func start_move() -> Dictionary:
	var bag: Object=_live_inventory()
	var scene: Node2D=_scene.get_ref() if _scene!=null else null
	if bag==null or not is_instance_valid(scene) or not scene.source_nodes.has(MOVE_CANCEL):return _fail("source_inventory_move_unavailable")
	var reference: String=str(bag.get("selected_item"))
	if reference.is_empty() or not bag.get("sorted_references").has(reference):return _fail("source_inventory_existing_selection_required")
	close_sort()
	bag.call("close_item_info")
	bag.call("disarm_item_action")
	_move_reference=reference
	_refresh_move_controls(scene)
	move_mode_changed.emit()
	return {"ok":true,"moving":true}

func cancel_move() -> Dictionary:
	if move_pending():
		_move_reference=""
		_refresh_move_controls(_scene.get_ref() if _scene!=null else null)
		move_mode_changed.emit()
	return {"ok":true,"moving":false}

func move_to(reference: String) -> Dictionary:
	if not move_pending():return _fail("source_inventory_move_unavailable")
	if _move_reference==reference:return {"ok":true,"moving":true}
	var source: String=_move_reference
	var bag: Object=_live_inventory()
	cancel_move()
	var changed: bool=bag!=null and bag.call("move_inventory_before",source,reference)
	if changed:model_changed.emit({"ok":true,"moved":source})
	return {"ok":true,"changed":changed}

func _refresh_move_controls(scene: Node2D) -> void:
	if not is_instance_valid(scene):return
	if scene.source_nodes.has(MOVE_CANCEL):scene.set_bound_visible(MOVE_CANCEL,move_pending())
	for offset: int in [MOVE_BUTTON,LOCK_BUTTON,DELETE_BUTTON,SORT_BUTTON]:
		if scene.source_nodes.has(offset):scene.set_bound_visible(offset,not move_pending())

func _sort_scene() -> Node2D:
	var scene: Variant=_scene.get_ref() if _scene!=null else null
	return scene if scene is Node2D and is_instance_valid(scene) and scene.source_nodes.has(SORT_OPTIONS) else null

func toggle_sort() -> Dictionary:
	var scene: Node2D=_sort_scene()
	if scene==null:return _fail("source_inventory_original_sort_unavailable")
	var bag: Object=_live_inventory()
	if bag!=null and bag.has_method("disarm_item_action"):bag.call("disarm_item_action")
	_sort_open=not _sort_open
	return scene.set_bound_visible(SORT_OPTIONS,_sort_open)

func close_sort() -> void:
	_sort_open=false
	var scene: Node2D=_sort_scene()
	if scene!=null:scene.set_bound_visible(SORT_OPTIONS,false)

func sort_blocks_point(point: Vector2) -> bool:
	if not _sort_open:return false
	var scene: Node2D=_sort_scene()
	if scene==null:return false
	var background: Node2D=scene.source_nodes.get(SORT_BACKGROUND)
	var origin: Node2D=background.get_node_or_null("SourceContentOrigin") if is_instance_valid(background) else null
	if origin==null or not origin.is_visible_in_tree():return false
	var extent: Array=background.get_meta("source_size",[0,0])
	return Rect2(Vector2(0,-float(extent[1])),Vector2(float(extent[0]),float(extent[1]))).has_point(origin.get_global_transform_with_canvas().affine_inverse()*point)

func sort_by(field: String) -> Dictionary:
	var bag: Object=_live_inventory()
	if not _sort_open or bag==null or not SORT_KEYS.has(field):return _fail("source_inventory_original_sort_unavailable")
	var descending: bool=not bool(_sort_directions[field]) if _sort_directions.has(field) else bool(SORT_DEFAULT_DOWN.get(field,false))
	if not bag.call("sort_inventory_source",field,descending):return _fail("source_inventory_existing_sort_failed")
	if SORT_ARROWS.has(field):_sort_directions[field]=descending
	# The legacy grid is parked; the exact owner order still has to be
	# projected into the mounted native slot assignments.
	model_changed.emit({"ok":true,"field":field,"descending":descending})
	return {"ok":true,"field":field,"descending":descending}

func request_delete() -> Dictionary:
	var bag: Object=_live_inventory()
	return bag.call("request_selected_delete") if bag!=null else _fail("source_inventory_existing_bag_unavailable")

func toggle_lock() -> Dictionary:
	var bag: Object=_live_inventory()
	if bag==null or str(bag.get("selected_item")).is_empty():return _fail("source_inventory_existing_selection_required")
	bag.call("_toggle_lock")
	refresh_selected_controls(_scene.get_ref() if _scene!=null else null)
	return {"ok":true}

func select_category(category: String) -> Dictionary:
	var inventory_ui: Object=_live_inventory()
	if inventory_ui==null:return _fail("source_main_inventory_existing_bag_unavailable")
	if not TABS.has(category):return _fail("source_main_inventory_native_category_unknown")
	cancel_move()
	# This is the same handler used by the current bag's own category buttons.
	inventory_ui.call("_set_category",category)
	var scene: Object=_scene.get_ref() if _scene!=null else null
	var model: Dictionary=refresh(scene) if is_instance_valid(scene) else snapshot()
	if model.get("ok",false):model_changed.emit(model.duplicate(true))
	return model

func toggle_expanded() -> Dictionary:
	var bag: Object=_live_inventory()
	if bag==null or not bag.has_method("_toggle_expanded"):return _fail("source_main_inventory_existing_expand_api_missing")
	# Same exact host-window relationship used by renewal_inventory. No
	# native width, capacity cost, slot purchase or resize rule is recreated.
	var window: Node=bag.get_parent()
	for index: int in range(2):
		window=window.get_parent() if window!=null else null
	if window==null or not window.has_method("fit_viewport"):return _fail("source_main_inventory_existing_expand_window_unavailable")
	cancel_move()
	bag.call("_toggle_expanded")
	var model: Dictionary=snapshot()
	if model.get("ok",false):model_changed.emit(model.duplicate(true))
	return model

## Find each requested exact source control in the allowed scene in one pass.
static func _control_presence(node: Dictionary, wanted: int) -> int:
	if wanted==0:return 0
	var offset: Variant=node.get("_offset")
	var found: int=0
	if offset==EXTENSION_BUTTON:found|=HAS_EXTENSION
	elif offset==SEARCH_BUTTON:found|=HAS_SEARCH
	elif offset==CLEAR_SEARCH_BUTTON:found|=HAS_CLEAR_SEARCH
	elif offset==SORT_OPTIONS and _has_sort_children(node):found|=HAS_SORT
	elif offset==SORT_BUTTON:found|=HAS_SORT_BUTTON
	elif offset==DELETE_BUTTON:found|=HAS_DELETE
	elif offset==LOCK_BUTTON:found|=HAS_LOCK
	elif offset==MOVE_BUTTON:found|=HAS_MOVE
	elif offset==MOVE_CANCEL:found|=HAS_MOVE_CANCEL
	for child: Dictionary in node.get("children",[]):
		var pending: int=wanted & ~found
		if pending==0:break
		found|=_control_presence(child,pending)
	return found & wanted

static func _has_sort_children(node: Dictionary) -> bool:
	var present: Dictionary={}
	for child: Dictionary in node.get("children",[]):present[int(child.get("_offset",0))]=true
	for offset: int in SORT_KEYS.values():
		if not present.has(offset):return false
	return true

func close() -> Dictionary:
	var inventory_ui: Object=_live_inventory()
	if inventory_ui==null:return _fail("source_main_inventory_existing_bag_unavailable")
	inventory_ui.call("hide_inventory")
	var scene: Object=_scene.get_ref() if _scene!=null else null
	_scene=null
	if _dismiss_presenter.is_valid():_dismiss_presenter.call()
	elif is_instance_valid(scene):scene.queue_free()
	return {"ok":true,"closed":true,"game_state_written":false}

func _live_inventory() -> Object:
	return _inventory.get_ref() if _inventory!=null else null

static func _collect_offsets(node: Dictionary, matches: Dictionary, selected: Array[int], seen: Dictionary, inside: bool) -> void:
	var offset: int=int(node.get("_offset",-1))
	var root: bool=matches.has(offset)
	if root:matches[offset]+=1
	var retain: bool=inside or root
	if retain and not seen.has(offset):
		seen[offset]=true
		selected.append(offset)
	for child: Dictionary in node.get("children",[]):_collect_offsets(child,matches,selected,seen,retain)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
