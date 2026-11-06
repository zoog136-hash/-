extends RefCounted
## Explicit TWILIGHT quantity-editor host policy. Source buttons/geometry are
## retained; this never moves an item, fills a cart or interprets an All button.
const MEMBER="UI/Storage/Storage_All.csb"
const SHA="eb4ddfa71dc9be978fd03948ff938c12e2366f6542ff5844509c47f110b38328"
const OWNER="res://scripts/ui/renewal_warehouse.gd"
const PRESETS={39288:{"quantity":1,"label":39340},37892:{"quantity":10,"label":37944},36496:{"quantity":100,"label":36548}}
const DIRECT=35036
const DIRECT_LABEL=35088
const OFFSETS: Array[int]=[39288,39664,39340,37892,38268,37944,36496,36872,36548,35036,35480,35088]
var _owner: WeakRef
var _quantity: WeakRef
var _listing: WeakRef
var _mode: WeakRef
var _action: WeakRef
var _scene: WeakRef
var _states: Dictionary={}

func configure(pack: RefCounted, owner: Control) -> Dictionary:
	if pack==null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256")!=SHA:return _fail("source_storage_quantity_original_identity_required")
	if not is_instance_valid(owner) or owner.get_script()==null or owner.get_script().resource_path!=OWNER:return _fail("source_storage_quantity_actual_owner_required")
	for field: String in ["quantity","listing","mode","action"]:
		var control: Variant=owner.get(field)
		if not is_instance_valid(control) or not owner.is_ancestor_of(control):return _fail("source_storage_quantity_actual_controls_required")
	var quantity: Variant=owner.get("quantity")
	var listing: Variant=owner.get("listing")
	var mode: Variant=owner.get("mode")
	var action: Variant=owner.get("action")
	if not quantity is SpinBox or not listing is ItemList or not mode is OptionButton or not action is Button or not action.pressed.is_connected(Callable(owner,"_transfer")):return _fail("source_storage_quantity_existing_editor_owner_required")
	var tree: Dictionary=pack.scene(MEMBER)
	for offset: int in OFFSETS:
		if _node_at(tree.get("nodeTree",{}),offset).is_empty():return _fail("source_storage_quantity_outside_selected_pack_scope")
	for offset: int in PRESETS:
		var button: Dictionary=_node_at(tree.nodeTree,offset)
		var text: Dictionary=_node_at(button,int(PRESETS[offset].label))
		if button.get("classname")!="Button" or text.get("classname")!="Text" or text.get("options",{}).get("text")!=str(PRESETS[offset].quantity):return _fail("source_storage_quantity_original_preset_role_required")
	var direct: Dictionary=_node_at(tree.nodeTree,DIRECT)
	if direct.get("classname")!="Button" or _node_at(direct,DIRECT_LABEL).get("options",{}).get("text")!="직접 입력":return _fail("source_storage_quantity_original_direct_input_role_required")
	_owner=weakref(owner);_quantity=weakref(quantity);_listing=weakref(listing);_mode=weakref(mode);_action=weakref(action)
	var model: Dictionary=_current()
	var bindings: Dictionary={}
	for offset: int in PRESETS:
		var enabled: bool=_preset_available(model,int(PRESETS[offset].quantity))
		bindings[offset]={"role":"button","activate":Callable(self,"set_preset").bind(int(PRESETS[offset].quantity)),"displaystate":enabled}
		bindings[int(PRESETS[offset].label)]={"role":"static_source_text"}
		_states[offset]=enabled
	bindings[DIRECT]={"role":"button","activate":Callable(self,"focus_existing_editor"),"displaystate":model.get("ok",false)}
	bindings[DIRECT_LABEL]={"role":"static_source_text"};_states[DIRECT]=model.get("ok",false)
	return {"ok":true,"source_node_offsets":OFFSETS.duplicate(),"bindings":bindings,"host_policy":"source literal quantity presets -> same live WarehouseQuantity editor; direct input focuses its actual LineEdit","original_controller_recovered":false,"all_buttons_bound":false,"transaction_requested":false}

func bind_scene(scene: Node2D) -> Dictionary:
	if not is_instance_valid(scene) or scene.source_member!=MEMBER:return _fail("source_storage_quantity_actual_scene_required")
	for offset: int in PRESETS:
		if not scene.source_nodes.has(offset):return _fail("source_storage_quantity_presented_preset_required")
	if not scene.source_nodes.has(DIRECT):return _fail("source_storage_quantity_presented_editor_control_required")
	_scene=weakref(scene)
	return {"ok":true}

func refresh() -> Dictionary:
	var scene: Object=_scene.get_ref() if _scene!=null else null
	if not is_instance_valid(scene) or scene.is_queued_for_deletion() or not scene.is_inside_tree():return _fail("source_storage_quantity_live_scene_required")
	var model: Dictionary=_current()
	for offset: int in _states:
		var enabled: bool=model.get("ok",false) if offset==DIRECT else _preset_available(model,int(PRESETS[offset].quantity))
		if enabled==_states[offset]:continue
		var result: Dictionary=scene.set_bound_displaystate(offset,enabled)
		if not result.get("ok",false):return result
		_states[offset]=enabled
	return {"ok":true,"states":_states.duplicate(),"all_buttons_bound":false,"transaction_requested":false}

func set_preset(count: int) -> Dictionary:
	if count not in [1,10,100] or not _presented():return _fail("source_storage_quantity_presented_preset_required")
	var model: Dictionary=_current()
	if not _preset_available(model,count):return _fail("source_storage_quantity_exact_count_unavailable")
	var quantity: SpinBox=_quantity.get_ref()
	var editor: LineEdit=quantity.get_line_edit()
	# Resolve/discard only this editor's unfinished input before setting the
	# exact count. Do not turn the original100 button into a clamped99 action.
	if editor.has_method("cancel_ime"):editor.call("cancel_ime")
	if editor.has_focus():editor.release_focus()
	var current: Dictionary=_current()
	if not _preset_available(current,count) or current.entry!=model.entry or current.direction!=model.direction:return _fail("source_storage_quantity_selected_owner_changed")
	quantity.value=count
	return {"ok":quantity.value==float(count),"quantity":quantity.value,"direction":model.direction,"instance_id":model.entry.get("instance_id",""),"existing_quantity_editor_changed":true,"transaction_requested":false,"game_state_written":false}

func focus_existing_editor() -> Dictionary:
	if not _presented():return _fail("source_storage_quantity_presented_editor_control_required")
	var model: Dictionary=_current()
	if not model.get("ok",false):return model
	var quantity: SpinBox=_quantity.get_ref()
	var editor: LineEdit=quantity.get_line_edit()
	editor.grab_focus();editor.select_all()
	return {"ok":true,"existing_editor_focused":true,"new_keypad_created":false,"transaction_requested":false,"game_state_written":false}

func _current() -> Dictionary:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	var quantity: Object=_quantity.get_ref() if _quantity!=null else null
	var listing: Object=_listing.get_ref() if _listing!=null else null
	var mode: Object=_mode.get_ref() if _mode!=null else null
	var action: Object=_action.get_ref() if _action!=null else null
	if not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or not owner.is_visible_in_tree():return _fail("source_storage_quantity_live_owner_required")
	for pair: Array in [["quantity",quantity],["listing",listing],["mode",mode],["action",action]]:
		if not is_instance_valid(pair[1]) or owner.get(pair[0])!=pair[1] or pair[1].is_queued_for_deletion() or not owner.is_ancestor_of(pair[1]):return _fail("source_storage_quantity_owner_control_replaced")
	if not quantity.editable or not quantity.is_visible_in_tree() or action.disabled or mode.selected not in [0,1] or mode.item_count!=2:return _fail("source_storage_quantity_existing_action_unavailable")
	var entries: Variant=owner.get("entries")
	var index: Variant=owner.get("selected_index")
	if not entries is Array or typeof(index)!=TYPE_INT or index<0 or index>=entries.size() or index>=listing.item_count or listing.get_selected_items()!=PackedInt32Array([index]):return _fail("source_storage_quantity_actual_selected_row_required")
	var entry: Variant=entries[index]
	if not entry is Dictionary or not entry.get("name") is String or not entry.get("record") is Dictionary or typeof(entry.get("count"))!=TYPE_INT or not entry.get("instance_id") is String:return _fail("source_storage_quantity_actual_entry_required")
	var editor: LineEdit=quantity.get_line_edit()
	if not is_instance_valid(editor) or not editor.editable:return _fail("source_storage_quantity_existing_line_editor_required")
	return {"ok":true,"direction":"deposit" if mode.selected==0 else "withdraw","entry":entry.duplicate(true),"min":quantity.min_value,"max":quantity.max_value,"step":quantity.step}

func _presented() -> bool:
	var scene: Object=_scene.get_ref() if _scene!=null else null
	return is_instance_valid(scene) and not scene.is_queued_for_deletion() and scene.is_inside_tree() and scene.is_visible_in_tree()

static func _preset_available(model: Dictionary, count: int) -> bool:
	return model.get("ok",false) and count<=99 and count>=model.min and count<=model.max and count<=model.entry.count and model.step==1.0

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"transaction_requested":false,"game_state_written":false}
