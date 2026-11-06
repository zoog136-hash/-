extends RefCounted
## Original carried-inventory filters inside the actual existing sell window.
## The actual OptionButton callback retains selection, rows and every sale rule.
const MEMBER="UI/Store/Store_Inventory.csb"
const SHA="d6b4258672c3f45dee0ccfcbf28fed9c5701d43aa0ddc82cab183f374ea07115"
const PARENT="UI/Store/Store_All.csb"
const PARENT_SHA="fb2a67543f60e42caa675d8e0b9f1d3834f78c1e2a85645f424da3ef5cbf7c05"
const PROJECT=67084
const TABS={"전체":[11684,10224],"장비":[8804,7384]}
const OFFSETS: Array[int]=[11684,12084,11736,10224,10620,10276,8804,9204,8856,7384,7780,7436,13296,452]
var _pack: RefCounted
var _owner: WeakRef
var _selector: WeakRef
var _player: WeakRef
var _presented: Dictionary={}

func configure(pack: RefCounted, owner: Control) -> Dictionary:
	if not is_instance_valid(owner):return _fail("source_sell_inventory_actual_owner_required")
	for spec: Array in [[MEMBER,SHA],[PARENT,PARENT_SHA]]:
		if pack==null or pack.manifest.get("files",{}).get(spec[0],{}).get("sha256")!=spec[1]:return _fail("source_sell_inventory_original_identity_required")
	var tree: Dictionary=pack.scene(MEMBER)
	for offset: int in OFFSETS:
		if _node_at(tree.get("nodeTree",{}),offset).is_empty():return _fail("source_sell_inventory_original_scope_required")
	var parent: Dictionary=pack.layout_source(PARENT)
	var project: Dictionary=_node_at(parent.get("nodeTree",{}),PROJECT)
	if parent.get("_source_sha256")!=PARENT_SHA or project.get("classname")!="ProjectNode" or project.get("options",{}).get("fileName")!="Store/Store_Inventory.csb":return _fail("source_sell_inventory_serialized_parent_required")
	var selector: Variant=owner.get("category")
	if not selector is OptionButton or not is_instance_valid(selector):return _fail("source_sell_inventory_existing_selector_required")
	_pack=pack;_owner=weakref(owner);_selector=weakref(selector)
	return _model()

func build() -> Dictionary:
	var model: Dictionary=_model()
	if not model.get("ok",false):return model
	var bindings: Dictionary={13296:{"role":"static_source_text"},452:{"role":"source_text","text":model.count_text,"visible":not model.count_text.is_empty()}}
	for category: String in TABS:
		for index: int in range(2):
			var offset: int=TABS[category][index]
			bindings[offset]={"role":"button","activate":Callable(self,"select_filter").bind(category),"visible":(model.category==category) if index==0 else (model.category!=category),"displaystate":model.choices[category].enabled}
	_presented=model.duplicate(true)
	return {"ok":true,"project_offset":PROJECT,"member":MEMBER,"source_sha256":SHA,"source_node_offsets":OFFSETS.duplicate(),"bindings":bindings,"partial_source_scene":true,"complete_screen_contract":false}

func bind_player(player: Node2D) -> Dictionary:
	if not is_instance_valid(player) or player.get("source_member")!=MEMBER or player.get("source_pack")!=_pack or player.get("inspection_only")!=false:return _fail("source_sell_inventory_actual_original_player_required")
	for offset: int in OFFSETS:
		if not player.source_nodes.has(offset):return _fail("source_sell_inventory_presented_scope_required")
	_player=weakref(player)
	return {"ok":true,"receiver_registered":true,"game_state_written":false}

func refresh() -> Dictionary:
	var player: Node2D=_player.get_ref() if _player!=null else null
	if not is_instance_valid(player) or player.is_queued_for_deletion() or not player.is_inside_tree():return _fail("source_sell_inventory_live_receiver_required")
	var model: Dictionary=_model()
	if not model.get("ok",false):
		for category: String in TABS:
			for offset: int in TABS[category]:player.set_bound_visible(offset,false)
		player.set_bound_text(452,"");player.set_bound_visible(452,false)
		_presented.clear()
		return model
	if model==_presented:return {"ok":true,"changed":false,"category":model.category}
	for category: String in TABS:
		for index: int in range(2):
			var offset: int=TABS[category][index]
			var result: Dictionary=player.set_bound_visible(offset,(model.category==category) if index==0 else (model.category!=category))
			var button: Variant=player.source_nodes[offset].get_meta("source_button",null)
			var enabled: bool=model.choices[category].enabled
			if result.get("ok",false) and (not is_instance_valid(button) or (button.get("current_state")=="disabled")==enabled):result=player.set_bound_displaystate(offset,enabled)
			if not result.get("ok",false):return result
	var result: Dictionary=player.set_bound_text(452,model.count_text)
	if result.get("ok",false):result=player.set_bound_visible(452,not model.count_text.is_empty())
	if not result.get("ok",false):return result
	_presented=model.duplicate(true)
	return {"ok":true,"changed":true,"category":model.category,"inventory_capacity_text":model.count_text,"game_state_written":false}

func blocks_point(point: Vector2) -> bool:
	var player: Node2D=_player.get_ref() if _player!=null else null
	if not point.is_finite() or not is_instance_valid(player) or player.is_queued_for_deletion() or not player.is_inside_tree():return false
	for category: String in TABS:
		for offset: int in TABS[category]:
			var node: Variant=player.source_nodes.get(offset)
			var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) else null
			var control: Variant=button.get("_input_area") if is_instance_valid(button) else null
			if control is Control and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point):return true
	return false

func select_filter(category: String) -> Dictionary:
	var player: Node2D=_player.get_ref() if _player!=null else null
	var model: Dictionary=_model()
	if not TABS.has(category) or not model.get("ok",false) or not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion() or not player.is_visible_in_tree():return _fail("source_sell_inventory_current_filter_receiver_required")
	if not model.choices[category].enabled:return _fail("source_sell_inventory_existing_filter_disabled")
	var selector: OptionButton=_selector.get_ref()
	var index: int=model.choices[category].index
	# Use only the existing real selector and its already connected callback.
	# That owner retains category classification and post-filter row selection.
	var changed: bool=selector.selected!=index
	if changed or selector.allow_reselect:
		selector.select(index)
		selector.item_selected.emit(index)
	var result: Dictionary=refresh()
	result["existing_filter_callback_invoked"]=changed or selector.allow_reselect
	result["transaction_requested"]=false
	return result

func _model() -> Dictionary:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	var selector: Object=_selector.get_ref() if _selector!=null else null
	if not owner is Control or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or not owner.is_visible_in_tree():return _fail("source_sell_inventory_live_owner_required")
	var script: Script=owner.get_script()
	var hud: Variant=owner.get("hud")
	var workspace: Variant=hud.get("workspace") if is_instance_valid(hud) else null
	if script==null or script.resource_path!="res://scripts/ui/renewal_sell.gd" or not workspace is Control or not workspace.is_ancestor_of(owner) or hud.get("active_section")!="sell" or hud.get_parent()!=owner.get("world"):return _fail("source_sell_inventory_actual_workspace_owner_required")
	if not selector is OptionButton or not is_instance_valid(selector) or selector.is_queued_for_deletion() or owner.get("category")!=selector or not owner.is_ancestor_of(selector) or selector.selected<0 or selector.selected>=selector.item_count or selector.get_signal_connection_list("item_selected").is_empty():return _fail("source_sell_inventory_same_current_selector_required")
	var choices: Dictionary={}
	for category: String in TABS:
		var found: Array[int]=[]
		for index: int in range(selector.item_count):
			if not selector.is_item_separator(index) and selector.get_item_text(index)==category:found.append(index)
		if found.size()!=1:return _fail("source_sell_inventory_unique_existing_choice_required")
		choices[category]={"index":found[0],"enabled":selector.is_visible_in_tree() and not selector.disabled and not selector.is_item_disabled(found[0])}
	var count_text: String=""
	var bag: Variant=hud.get("lineage_inventory_ui")
	if is_instance_valid(bag) and bag.get("inventory")==owner.world.get("inventory"):
		var capacity: Variant=bag.get("capacity_label")
		if capacity is Label and is_instance_valid(capacity):
			var raw: String=capacity.text.get_slice(" · ",capacity.text.get_slice_count(" · ")-1)
			var parts: PackedStringArray=raw.split("/")
			if parts.size()==2 and parts[0].strip_edges().is_valid_int() and parts[1].strip_edges().is_valid_int():count_text=raw
	return {"ok":true,"category":selector.get_item_text(selector.selected),"choices":choices,"count_text":count_text,"capacity_basis":"existing actual bag capacity_label final count/capacity formatter, not sale-filter row count"}

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
