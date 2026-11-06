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
const SEARCH_TEXT=46132
const SEARCH_RESET=47700
const SEARCH_RESET_NORMAL=48312
const SEARCH_RESET_DISABLED=47752
const SEARCH_RESET_SCOPE: Array[int]=[47700,48312,48368,47752,47804]
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
var _pack: RefCounted
var _inventory: WeakRef
var _scene: WeakRef
var _dismiss_presenter: Callable
var _query_editor: WeakRef

static func parent_contract(parent_member: String) -> Dictionary:
	if not PARENTS.has(parent_member):return _fail("source_main_inventory_explicit_parent_required")
	return {"ok":true,"member":parent_member,"sha256":PARENTS[parent_member].sha256,"project_offset":PARENTS[parent_member].project_offset,"child_member":MEMBER,"child_sha256":SHA256,"original_clip":{"name":"Inventory_All_On","start_frame":5,"end_frame":17},"loop_declared":false,"original_design_size":[1200,675],"requires_parent_timeline":true,"complete_screen_contract":false}

func configure(pack: RefCounted, hud: Node, dismiss_presenter: Callable=Callable()) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_inventory_identity_mismatch")
	if not is_instance_valid(hud):return _fail("source_main_inventory_hud_unavailable")
	var inventory_ui: Variant=hud.get("lineage_inventory_ui")
	if not is_instance_valid(inventory_ui):return _fail("source_main_inventory_existing_bag_required")
	for method: String in ["hide_inventory","_set_category"]:
		if not inventory_ui.has_method(method):return {"ok":false,"code":"source_main_inventory_existing_bag_api_missing","method":method}
	_pack=pack
	_inventory=weakref(inventory_ui)
	_dismiss_presenter=dismiss_presenter
	var editor: Variant=inventory_ui.get("search_line")
	_query_editor=weakref(editor) if editor is LineEdit and is_instance_valid(editor) else null
	return snapshot()

func snapshot() -> Dictionary:
	var inventory_ui: Object=_live_inventory()
	if inventory_ui==null:return _fail("source_main_inventory_existing_bag_unavailable")
	var category: Variant=inventory_ui.get("category_filter")
	if not category is String or not TABS.has(category):return _fail("source_main_inventory_existing_category_unknown")
	var inventory: Variant=inventory_ui.get("inventory")
	var rows: Variant=inventory_ui.get("legacy_rows")
	if not inventory is Dictionary or not rows is Array:return _fail("source_main_inventory_existing_rows_unavailable")
	var model: Dictionary={"ok":true,"category":category,"inventory":inventory.duplicate(true),"rows":rows.duplicate(true),"selected_reference":inventory_ui.get("selected_item"),"partial_source_scene":true,"complete_screen_contract":false}
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
	var query: Dictionary=_search_display()
	if query.get("ok",false):
		model["search_query"]=query.text
		model["search_reset_enabled"]=query.enabled
	return model

func build(remaining: Dictionary={}, expanded: bool=false) -> Dictionary:
	if _pack==null or _pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","")!=SHA256:return _fail("source_main_inventory_identity_mismatch")
	var model: Dictionary=snapshot()
	if not model.get("ok",false):return model
	var tree: Dictionary=_pack.call("layout_source",MEMBER) if _pack.has_method("layout_source") else _pack.scene(MEMBER)
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
	var active: Dictionary=_pack.scene(MEMBER)
	# Old normal-only packs keep working. Extension controls are included
	# only when the permitted source scope actually contains their original.
	if bag!=null and bag.has_method("_toggle_expanded") and not _node_at(active.get("nodeTree",{}),EXTENSION_BUTTON).is_empty():
		roots.append(EXTENSION_BUTTON)
		bindings[EXTENSION_BUTTON]={"role":"button","activate":Callable(self,"toggle_expanded")}
	# This entry belongs specifically to the authored extension branch.
	if expanded and _pack.manifest.get("scenes",{}).has("UI/FloatingUi/Inventory_Popup_Keypad.csb") and not _node_at(active.get("nodeTree",{}),SEARCH_BUTTON).is_empty():
		roots.append(SEARCH_BUTTON)
		bindings[SEARCH_BUTTON]={"role":"button","activate":Callable(self,"_search_requested")}
		bindings[SEARCH_TEXT]={"role":"source_text","text":_query_caption(model,tree)}
		var reset_in_scope: bool=true
		for offset: int in SEARCH_RESET_SCOPE:
			if _node_at(active.get("nodeTree",{}),offset).is_empty():reset_in_scope=false
		if reset_in_scope:
			roots.append(SEARCH_RESET)
			var enabled: bool=model.get("search_reset_enabled",false)
			bindings[SEARCH_RESET]={"role":"button","activate":Callable(self,"reset_search_query"),"displaystate":enabled}
			bindings[SEARCH_RESET_NORMAL]={"visible":enabled}
			bindings[SEARCH_RESET_DISABLED]={"visible":not enabled}
			bindings[48368]={"role":"static_source_text"}
			bindings[47804]={"role":"static_source_text"}
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
	_collect_offsets(tree.nodeTree,roots,matches,selected,false)
	for offset: int in roots:
		if int(matches.get(offset,0))!=1:return {"ok":false,"code":"source_main_inventory_core_node_not_unique","offset":offset}
	for offset: int in selected:
		if not bindings.has(offset) and remaining.has(offset):bindings[offset]=remaining[offset].duplicate(true)
	return {"ok":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":selected,"bindings":bindings,"model":model,"expanded":expanded,"background_offset":frame.background,"branch_parent_offset":frame.parent,"original_variant_clip":{"name":"Fx_Extension_On","start_frame":40,"end_frame":70} if expanded else {},"native_parent_required":"original Inventory_All root and retained original ancestor chain","original_root_options":tree.nodeTree.get("options",{}).duplicate(true),"static_source_text_offsets":[],"partial_source_scene":true,"complete_screen_contract":false,"unresolved_fields":[{"field":"original_inventory_rows_and_slot_placement","scroll_offsets":[55712,43832],"slot_project_offsets":[56036,44156],"slot_member":"UI/FloatingUi/Inventory_Slot_Set.csb","missing":"owned row reference to original slot instance and position"},{"field":"existing_sort_action_contract","offsets":[19772,8004,4764,2864]},"original_lock_delete_move_dissolve_and_remaining_keypad_contracts"]}

func bind_presented(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or str(scene.get("source_member"))!=MEMBER:return _fail("source_main_inventory_scene_mismatch")
	_scene=weakref(scene)
	return {"ok":true}

func _search_requested() -> Dictionary:
	search_requested.emit()
	return {"ok":true,"existing_search_requested":true,"game_state_written":false}

func refresh(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or str(scene.get("source_member"))!=MEMBER:return _fail("source_main_inventory_scene_mismatch")
	if not scene.has_method("set_bound_visible") or not scene.has_method("set_bound_text"):return _fail("source_main_inventory_scene_binding_api_missing")
	var model: Dictionary=snapshot()
	if not model.get("ok",false):return model
	for category: String in TABS:
		for index: int in range(2):
			var result: Dictionary=scene.set_bound_visible(int(TABS[category][index]),(model.category==category) if index==0 else (model.category!=category))
			if not result.get("ok",false):return result
	for entry: Array in [[GOLD_TEXT,"gold_text"],[CAPACITY_TEXT,"capacity_text"]]:
		if model.has(entry[1]):
			var result: Dictionary=scene.set_bound_text(int(entry[0]),model[entry[1]])
			if not result.get("ok",false):return result
	var nodes: Variant=scene.get("source_nodes")
	if nodes is Dictionary and nodes.has(SEARCH_TEXT):
		var tree: Dictionary=_pack.layout_source(MEMBER)
		if tree.is_empty():tree=_pack.scene(MEMBER)
		var result: Dictionary=scene.set_bound_text(SEARCH_TEXT,_query_caption(model,tree))
		if not result.get("ok",false):return result
		if nodes.has(SEARCH_RESET):
			var enabled: bool=model.get("search_reset_enabled",false)
			var native: Variant=nodes[SEARCH_RESET].get_meta("source_button",null)
			if not is_instance_valid(native) or (native.get("current_state")=="disabled")==enabled:
				result=scene.set_bound_displaystate(SEARCH_RESET,enabled)
				if not result.get("ok",false):return result
			result=scene.set_bound_visible(SEARCH_RESET_NORMAL,enabled)
			if result.get("ok",false):result=scene.set_bound_visible(SEARCH_RESET_DISABLED,not enabled)
			if not result.get("ok",false):return result
	return {"ok":true,"model":model,"partial_source_scene":true,"complete_screen_contract":false}

func reset_search_query() -> Dictionary:
	var bag: Object=_live_inventory()
	var scene: Object=_scene.get_ref() if _scene!=null else null
	var query: Dictionary=_search_display()
	if bag==null or not query.get("ok",false) or not query.get("enabled",false) or not is_instance_valid(scene) or scene.is_queued_for_deletion() or not scene.is_inside_tree() or not scene.is_visible_in_tree() or scene.get("source_member")!=MEMBER:return _fail("source_inventory_reset_current_presented_query_required")
	var nodes: Variant=scene.get("source_nodes")
	var button: Variant=nodes.get(SEARCH_RESET) if nodes is Dictionary else null
	if not is_instance_valid(button) or not button.is_visible_in_tree() or not bag.has_method("_on_search_changed"):return _fail("source_inventory_reset_original_control_required")
	var editor: LineEdit=_query_editor.get_ref()
	# Clearing explicitly discards the same editor's in-progress composition;
	# an unsubmitted IME fragment must not restore a supposedly reset query.
	if editor.has_method("cancel_ime"):editor.call("cancel_ime")
	editor.clear()
	bag.call("_on_search_changed",editor.text)
	var result: Dictionary=refresh(scene)
	if result.get("ok",false):model_changed.emit(result.duplicate(true))
	result["query_reset"]=true
	result["category_reset"]=false
	result["sort_or_save_requested"]=false
	return result

func _search_display() -> Dictionary:
	var bag: Object=_live_inventory()
	var editor: Object=_query_editor.get_ref() if _query_editor!=null else null
	if bag==null or not editor is LineEdit or not is_instance_valid(editor) or editor.is_queued_for_deletion() or bag.get("search_line")!=editor:return _fail("source_inventory_actual_query_editor_required")
	var composition: bool=editor.call("has_ime_text") if editor.has_method("has_ime_text") else false
	return {"ok":true,"text":editor.text,"enabled":editor.editable and (not editor.text.is_empty() or composition),"basis":"same actual bag.search_line used by existing original input/IME adoption"}

static func _query_caption(model: Dictionary, tree: Dictionary) -> String:
	var query: Variant=model.get("search_query")
	if query is String and not query.is_empty():return query
	# Retain the exact source instruction, not a reconstructed translation.
	return str(_node_at(tree.get("nodeTree",{}),SEARCH_TEXT).get("options",{}).get("text",""))

func select_category(category: String) -> Dictionary:
	var inventory_ui: Object=_live_inventory()
	if inventory_ui==null:return _fail("source_main_inventory_existing_bag_unavailable")
	if not TABS.has(category):return _fail("source_main_inventory_native_category_unknown")
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
	bag.call("_toggle_expanded")
	var model: Dictionary=snapshot()
	if model.get("ok",false):model_changed.emit(model.duplicate(true))
	return model

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

func close() -> Dictionary:
	var inventory_ui: Object=_live_inventory()
	if inventory_ui==null:return _fail("source_main_inventory_existing_bag_unavailable")
	inventory_ui.call("hide_inventory")
	var scene: Object=_scene.get_ref() if _scene!=null else null
	_scene=null
	if is_instance_valid(scene):scene.queue_free()
	if _dismiss_presenter.is_valid():_dismiss_presenter.call()
	return {"ok":true,"closed":true,"game_state_written":false}

func _live_inventory() -> Object:
	return _inventory.get_ref() if _inventory!=null else null

static func _collect_offsets(node: Dictionary, roots: Array[int], matches: Dictionary, selected: Array[int], inside: bool) -> void:
	var offset: int=int(node.get("_offset",-1))
	if offset in roots:matches[offset]=int(matches.get(offset,0))+1
	var retain: bool=inside or offset in roots
	if retain and offset not in selected:selected.append(offset)
	for child: Dictionary in node.get("children",[]):_collect_offsets(child,roots,matches,selected,retain)

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
