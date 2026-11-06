extends RefCounted
## Original lock controls only; the bag owns physical selection and lock writes.
const Scene = preload("res://scripts/ui/original_ui/sprite_scene.gd")
const MEMBER = "UI/ToolTip/ToolTip_HudType_Right.csb"
const SHA256 = "7aa63b5159335c1558e9bc83f8155979b1a9bf4ee37eaed24c7e2652c392c1ce"
const PARENT_MEMBER = "UI/ToolTipScene.csb"
const PARENT_SHA256 = "9304dcb5730fba9a155f73a291a6e87f96768156cee972929b003386e3904a1d"
const PROJECT = 1012
const SOURCE_OFFSETS: Array[int] = [37228,37860,37284,36120,36708,36176,44536,44160,956]
const LOCK_BUTTONS: Array[int] = [37284,36176]
const BUTTONS: Array[int] = [37284,36176,956]
var _pack: RefCounted
var _bag: WeakRef
var _parent: WeakRef
var _action: WeakRef
var _action_visible: bool
var _replaced: bool = false
var _scene: Node2D
var _child: Node2D
var _buttons: Array = []
var _controls: Array = []
var _presented_offsets: Array[int]=[]
var _reference: String=""
var _type_in_scope: bool=false
var _safe_in_scope: bool=false
var _class_in_scope: bool=false
var _storage_in_scope: bool=false
var _expiration_in_scope: bool=false
const STORAGE_ON=55344
const STORAGE_OFF=54036
const STORAGE_OFFSETS: Array[int]=[55716,55400,54796,54412,54096]
const EXPIRATION=42072
var _header_hidden: Array[Dictionary]=[]

func configure(pack: RefCounted, bag: Control) -> Dictionary:
	close()
	if not is_instance_valid(bag) or (not bag.has_method("_toggle_lock") or not bag.has_method("close_detail")): return _fail("source_inventory_lock_existing_bag_required")
	if pack == null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","") != SHA256 or pack.manifest.get("files",{}).get(PARENT_MEMBER,{}).get("sha256","") != PARENT_SHA256:
		return _fail("source_inventory_lock_original_identity_mismatch")
	var active: Dictionary = pack.scene(MEMBER)
	for offset: int in SOURCE_OFFSETS:
		if _find(active.get("nodeTree",{}),offset).is_empty(): return _fail("source_inventory_lock_nodes_not_in_active_pack_scope")
	_pack = pack
	_type_in_scope=not _find(active.get("nodeTree",{}),42456).is_empty()
	_safe_in_scope=not _find(active.get("nodeTree",{}),52788).is_empty() and not _find(active.get("nodeTree",{}),53168).is_empty()
	_class_in_scope=not _find(active.get("nodeTree",{}),40928).is_empty() and not _find(active.get("nodeTree",{}),40580).is_empty()
	_storage_in_scope=true
	for offset: int in STORAGE_OFFSETS:
		if _find(active.get("nodeTree",{}),offset).is_empty():_storage_in_scope=false
	_expiration_in_scope=not _find(active.get("nodeTree",{}),EXPIRATION).is_empty()
	_bag = weakref(bag)
	return {"ok":true,"configured":true,"member":MEMBER,"source_node_offsets":SOURCE_OFFSETS.duplicate(),"partial_source_scene":true,"complete_screen_contract":false}

func refresh(parent: Node) -> Dictionary:
	var bag: Object = _bag.get_ref() if _bag != null else null
	var model: Dictionary = _model(bag)
	if _class_in_scope and model.get("ok",false):model.class_text=_fitting_class_text(model.class_text)
	if not model.get("ok",false):
		_close_scene()
		return model
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		_close_scene()
		return _fail("source_inventory_lock_actual_parent_required")
	if is_instance_valid(_scene) and not _scene.is_queued_for_deletion():
		if _parent == null or _parent.get_ref() != parent or _action == null or _action.get_ref() != model.action:
			_close_scene()
		else:
			return _apply(model)
	var bindings: Dictionary = {
		37228:{"visible":not model.locked},36120:{"visible":model.locked},
		37284:{"role":"button","activate":Callable(self,"_activate"),"displaystate":not model.disabled},
		36176:{"role":"button","activate":Callable(self,"_activate"),"displaystate":not model.disabled},
		44160:{"role":"source_text","text":model.name_text},
		956:{"role":"button","activate":Callable(self,"_close_detail"),"displaystate":true}
	}
	var staged := Scene.new()
	var scope: Array[int]=SOURCE_OFFSETS.duplicate()
	if _type_in_scope:
		scope.append(42456)
		bindings[42456]={"role":"source_text","text":model.type_text,"visible":not model.type_text.is_empty()}
	if _safe_in_scope:
		scope.append_array([53168,52788])
		bindings[52728]={"visible":model.safe.has("value")}
		bindings[53168]={"role":"static_source_text"}
		bindings[52788]={"role":"source_text","text":"+%d" % model.safe.value if model.safe.has("value") else ""}
	if _class_in_scope:
		scope.append_array([40928,40580])
		# The single authored20px row fits its269px ListView. This partial
		# read-only scope consumes touches; no row cloning/selection is added.
		bindings[39440]={"role":"source_list","row_offsets":[39492],"input":Callable(self,"_consume_class_list_input")}
		bindings[39492]={"visible":not model.class_text.is_empty()}
		bindings[40928]={"role":"static_source_text"}
		bindings[40580]={"role":"source_text","text":model.class_text}
	if _storage_in_scope:
		scope.append_array(STORAGE_OFFSETS)
		bindings[STORAGE_ON]={"visible":model.storage.get("value")==true}
		bindings[STORAGE_OFF]={"visible":model.storage.get("value")==false}
		bindings[55400]={"role":"static_source_text"}
		bindings[54096]={"role":"static_source_text"}
	if _expiration_in_scope:
		scope.append(EXPIRATION)
		bindings[EXPIRATION]={"role":"source_text","text":model.expiration_text,"visible":not model.expiration_text.is_empty()}
	var result: Dictionary = staged.configure_nodes(_pack,PARENT_MEMBER,[PROJECT],{PROJECT:{"role":"project","visible":true,"source_node_offsets":scope,"bindings":bindings}})
	if not result.get("ok",false):
		staged.free()
		return result
	var nested: Dictionary = staged.project_player([PROJECT])
	if not nested.get("ok",false):
		staged.free()
		return nested
	var child: Node2D = nested.player
	var buttons: Array = []
	var controls: Array = []
	for offset: int in BUTTONS:
		var raw: Variant = child.source_nodes.get(offset)
		var button: Variant = raw.get_meta("source_button",null) if is_instance_valid(raw) else null
		var control: Variant = button.get("_input_area") if is_instance_valid(button) else null
		if not control is Control:
			staged.free()
			return _fail("source_inventory_lock_original_control_required")
		buttons.append(button)
		controls.append(control)
	_scene = staged
	_child = child
	_buttons = buttons
	_controls = controls
	_parent = weakref(parent)
	_action = weakref(model.action)
	_action_visible = model.action.visible
	_reference=model.reference
	_presented_offsets=scope.duplicate()
	parent.add_child(staged)
	var fresh: Dictionary = _model(bag)
	if not staged.is_inside_tree() or not fresh.get("ok",false) or fresh.action != model.action:
		_close_scene()
		return _fail("source_inventory_lock_mount_or_owner_changed")
	model.action.hide()
	for control: Control in [model.name_label,model.close_button]:
		_header_hidden.append({"control":weakref(control),"visible":control.visible})
		control.hide()
	_replaced = true
	bag.visibility_changed.connect(_visibility_changed)
	bag.tree_exiting.connect(_close_scene)
	parent.tree_exiting.connect(_close_scene)
	return _apply(fresh)

func close() -> void:
	_close_scene()
	_pack = null
	_bag = null

func _close_scene() -> void:
	var bag: Object = _bag.get_ref() if _bag != null else null
	var parent: Object = _parent.get_ref() if _parent != null else null
	if is_instance_valid(bag):
		if bag.visibility_changed.is_connected(_visibility_changed): bag.visibility_changed.disconnect(_visibility_changed)
		if bag.tree_exiting.is_connected(_close_scene): bag.tree_exiting.disconnect(_close_scene)
	if is_instance_valid(parent) and parent.tree_exiting.is_connected(_close_scene): parent.tree_exiting.disconnect(_close_scene)
	var action: Object = _action.get_ref() if _action != null else null
	if _replaced and is_instance_valid(action): action.visible = _action_visible
	for record: Dictionary in _header_hidden:
		var control: Object=record.control.get_ref()
		if is_instance_valid(control):control.visible=record.visible
	_header_hidden.clear()
	_replaced = false
	_action = null
	_parent = null
	_child = null
	_buttons.clear()
	_controls.clear()
	_presented_offsets.clear()
	_reference=""
	var previous: Node2D = _scene
	_scene = null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func presentation() -> Dictionary:
	return {"scene":_scene,"renderer":_child,"source_buttons":_buttons.duplicate(),"controls":_controls.duplicate(),"source_node_offsets":_presented_offsets.duplicate(),"parent_member":PARENT_MEMBER,"parent_sha256":PARENT_SHA256,"parent_project_offset":PROJECT,"parent_original_position":Vector2(1008,345),"parent_original_visible":false,"parent_activation_basis":"existing bag.detail_active and actual visibility","partial_source_scene":true,"complete_screen_contract":false}

func _apply(model: Dictionary) -> Dictionary:
	if _class_in_scope:model.class_text=_fitting_class_text(model.class_text)
	if model.reference!=_reference:
		_close_scene()
		return _fail("source_inventory_lock_presented_selection_changed")
	for pair: Array in [[37228,not model.locked],[36120,model.locked]]:
		var result: Dictionary = _child.set_bound_visible(pair[0],pair[1])
		if not result.get("ok",false):
			_close_scene()
			return result
	var title_result: Dictionary=_child.set_bound_text(44160,model.name_text)
	if not title_result.get("ok",false):
		_close_scene()
		return title_result
	if _type_in_scope:
		var type_result: Dictionary=_child.set_bound_text(42456,model.type_text)
		if type_result.get("ok",false):type_result=_child.set_bound_visible(42456,not model.type_text.is_empty())
		if not type_result.get("ok",false):
			_close_scene()
			return type_result
	if _safe_in_scope:
		var safe_result: Dictionary=_child.set_bound_text(52788,"+%d" % model.safe.value if model.safe.has("value") else "")
		if safe_result.get("ok",false):safe_result=_child.set_bound_visible(52728,model.safe.has("value"))
		if not safe_result.get("ok",false):
			_close_scene()
			return safe_result
	if _class_in_scope:
		var class_result: Dictionary=_child.set_bound_text(40580,model.class_text)
		if class_result.get("ok",false):class_result=_child.set_bound_visible(39492,not model.class_text.is_empty())
		if not class_result.get("ok",false):
			_close_scene()
			return class_result
	if _storage_in_scope:
		for pair: Array in [[STORAGE_ON,model.storage.get("value")==true],[STORAGE_OFF,model.storage.get("value")==false]]:
			var changed: Dictionary=_child.set_bound_visible(pair[0],pair[1])
			if not changed.get("ok",false):_close_scene();return changed
	if _expiration_in_scope:
		var changed: Dictionary=_child.set_bound_text(EXPIRATION,model.expiration_text)
		if changed.get("ok",false):changed=_child.set_bound_visible(EXPIRATION,not model.expiration_text.is_empty())
		if not changed.get("ok",false):_close_scene();return changed
	for offset: int in LOCK_BUTTONS:
		# Do not reset a current pressed state on every ordinary refresh.
		var button: Variant=_child.source_nodes[offset].get_meta("source_button",null)
		if is_instance_valid(button) and (button.current_state=="disabled")==model.disabled:continue
		var result: Dictionary = _child.set_bound_displaystate(offset,not model.disabled)
		if not result.get("ok",false):
			_close_scene()
			return result
	return {"ok":true,"handled":true,"reference":model.reference,"locked":model.locked,"member":MEMBER,"sha256":SHA256,"storage_definition_connected":_storage_in_scope and model.storage.has("value"),"expiration_calendar_connected":_expiration_in_scope and not model.expiration_text.is_empty(),"partial_source_scene":true,"complete_screen_contract":false}

func _activate() -> Dictionary:
	var bag: Object = _bag.get_ref() if _bag != null else null
	var model: Dictionary = _model(bag)
	if not model.get("ok",false):
		_close_scene()
		return model
	if model.disabled or _action == null or _action.get_ref() != model.action: return _fail("source_inventory_lock_owner_action_unavailable")
	if model.reference!=_reference:
		_close_scene()
		return _fail("source_inventory_lock_presented_selection_changed")
	bag.call("_toggle_lock")
	var fresh: Dictionary = _model(bag)
	if not fresh.get("ok",false):
		_close_scene()
		return fresh
	var result: Dictionary = _apply(fresh)
	result["owner_callback_invoked"] = true
	return result

func _close_detail() -> Dictionary:
	var bag: Object=_bag.get_ref() if _bag!=null else null
	var model: Dictionary=_model(bag)
	if not model.get("ok",false) or model.reference!=_reference:
		_close_scene()
		return _fail("source_inventory_detail_presented_selection_changed")
	bag.call("close_detail")
	_close_scene()
	return {"ok":true,"owner_close_invoked":true,"selection_cleared":false,"game_state_written":false}

func _consume_class_list_input(_event: InputEvent) -> void:
	if is_instance_valid(_scene) and _scene.is_inside_tree():_scene.get_viewport().set_input_as_handled()

func _fitting_class_text(value: String) -> String:
	var original: Dictionary=_find(_pack.scene(MEMBER).get("nodeTree",{}),40580)
	var options: Dictionary=original.get("options",{})
	if options.is_empty():return ""
	var font: FontFile=_pack.font(options.fontResource)
	if font==null:return ""
	# Never show a truncated subset as the complete permitted-class list.
	return value if font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,int(options.fontSize)).x<=float(options.widgetOptions.size[0]) else ""

func _visibility_changed() -> void:
	var bag: Object = _bag.get_ref() if _bag != null else null
	if not is_instance_valid(bag) or not bag.is_visible_in_tree(): _close_scene()

static func _model(bag: Object) -> Dictionary:
	if not is_instance_valid(bag) or not bag is Control or bag.is_queued_for_deletion() or not bag.is_inside_tree() or not bag.is_visible_in_tree() or bag.get("detail_active") != true or not bag.has_method("_toggle_lock"): return _fail("source_inventory_lock_actual_visible_detail_required")
	var reference: Variant = bag.get("selected_item")
	var state: Variant = bag.get("character_state")
	var action: Variant = bag.get("lock_button")
	if not reference is String or reference.is_empty() or not state is Dictionary or not state.get("item_locks") is Dictionary: return _fail("source_inventory_lock_actual_selection_and_lock_state_required")
	var locked: Variant = state["item_locks"].get(reference,false)
	if not locked is bool: return _fail("source_inventory_lock_actual_boolean_required")
	if not action is BaseButton or not is_instance_valid(action) or action.is_queued_for_deletion(): return _fail("source_inventory_lock_existing_button_required")
	var name_label: Variant=bag.get("detail_name")
	var close_button: Node=bag.find_child("InventoryDetailClose",true,false)
	if not bag.has_method("close_detail") or not name_label is Label or not is_instance_valid(name_label) or not close_button is BaseButton:return _fail("source_inventory_detail_existing_header_required")
	var type_value: Variant=bag.get("source_detail_type")
	var name_value: Variant=bag.get("source_detail_name")
	var name_text: String=name_label.text
	if name_value is Dictionary and name_value.get("reference")==reference and name_value.get("text") is String:name_text=name_value.text
	var type_text: String=""
	if type_value is Dictionary and type_value.get("reference")==reference and type_value.get("text") is String:type_text=type_value.text
	var safe: Variant=bag.get("source_detail_safe_enhancement")
	if not safe is Dictionary or safe.get("reference")!=reference or typeof(safe.get("value"))!=TYPE_INT or safe.value<0:safe={}
	var classes: Variant=bag.get("source_detail_classes")
	var class_text: String=""
	if classes is Dictionary and classes.get("reference")==reference and classes.get("text") is String:class_text=classes.text
	var storage: Variant=bag.get("source_detail_storage")
	if not storage is Dictionary or storage.get("reference")!=reference or typeof(storage.get("value"))!=TYPE_BOOL:storage={}
	var expiration: Variant=bag.get("source_detail_expiration")
	var expiration_text: String=""
	if expiration is Dictionary and expiration.get("reference")==reference and expiration.get("text") is String:expiration_text=expiration.text
	return {"ok":true,"reference":reference,"locked":locked,"disabled":action.disabled,"action":action,"name_label":name_label,"name_text":name_text,"close_button":close_button,"type_text":type_text,"safe":safe,"class_text":class_text,"storage":storage,"expiration_text":expiration_text}

static func _find(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset") == offset: return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary = _find(child,offset)
		if not found.is_empty(): return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
