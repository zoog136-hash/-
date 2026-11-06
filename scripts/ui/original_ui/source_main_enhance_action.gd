extends RefCounted
## Only the authored ordinary enhancement action; existing Forge owns the flow.
const Scene = preload("res://scripts/ui/original_ui/sprite_scene.gd")
const MEMBER = "UI/FloatingUi/Enchant_All.csb"
const SHA256 = "5a22899447b7b750c01e500beba49d80d081d65669bfc77c91309fe58946face"
const PARENT_MEMBER = "UI/EnchantScene.csb"
const PARENT_SHA256 = "1b44bd8b15833b44a902b0033c47969cf237ea18bc4c9f210af3505738420326"
const PROJECT = 724
const BUTTON = 15656
const NORMAL = 16276
const DISABLED = 15708
const SOURCE_OFFSETS: Array[int] = [15656,16276,16328,15708,15760]
const TARGET_TITLE=145444
const FEE_GROUP=138172
const FEE_OFFSETS: Array[int]=[139568,139232,138568,138240]
const PROBABILITY=134084
const PROBABILITY_LABEL=134136
var _parent: WeakRef
var _forge: WeakRef
var _action: WeakRef
var _scene: Node2D
var _child: Node2D
var _control: Control
var _button: Node2D
var _original_action_visible: bool
var _replaced: bool = false
var _fields: Dictionary={}
var _presented_offsets: Array[int]=[]
var _presented_target: String=""

func configure(pack: RefCounted, forge: Control, parent: Node) -> Dictionary:
	close()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion(): return _fail("source_enhance_action_actual_parent_required")
	var model: Dictionary = _model(forge)
	if not model.get("ok",false): return model
	if not forge.is_inside_tree() or not forge.is_visible_in_tree(): return _fail("source_enhance_action_visible_owner_required")
	if pack == null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","") != SHA256 or pack.manifest.get("files",{}).get(PARENT_MEMBER,{}).get("sha256","") != PARENT_SHA256:
		return _fail("source_enhance_action_original_identity_mismatch")
	var bindings: Dictionary = {
		BUTTON:{"role":"button","activate":Callable(self,"_activate"),"displaystate":not model.disabled},
		NORMAL:{"visible":not model.disabled},DISABLED:{"visible":model.disabled},
		16328:{"role":"static_source_text"},15760:{"role":"static_source_text"}
	}
	var scope: Array[int]=SOURCE_OFFSETS.duplicate()
	var active: Dictionary=pack.scene(MEMBER)
	if not _node_at(active.get("nodeTree",{}),TARGET_TITLE).is_empty():
		scope.append(TARGET_TITLE)
		_fields["title"]=true
		bindings[TARGET_TITLE]={"role":"source_text","text":model.title,"visible":not model.title.is_empty()}
	var fee_available: bool=true
	for offset: int in FEE_OFFSETS:
		if _node_at(active.get("nodeTree",{}),offset).is_empty():fee_available=false
	if fee_available:
		_fields["fee"]=true
		scope.append_array(FEE_OFFSETS)
		bindings[FEE_GROUP]={"visible":model.fee.has("value")}
		bindings[138568]={"role":"source_text","text":str(model.fee.get("value",""))}
		bindings[138240]={"role":"static_source_text"}
	if not _node_at(active.get("nodeTree",{}),PROBABILITY).is_empty() and not _node_at(active.get("nodeTree",{}),PROBABILITY_LABEL).is_empty():
		_fields["probability"]=true
		scope.append_array([PROBABILITY,PROBABILITY_LABEL])
		bindings[PROBABILITY]={"role":"button","activate":Callable(self,"_show_probabilities"),"displaystate":model.info_button!=null and not model.info_button.disabled,"visible":model.info_button!=null}
		bindings[PROBABILITY_LABEL]={"role":"static_source_text"}
	var staged := Scene.new()
	var result: Dictionary = staged.configure_nodes(pack,PARENT_MEMBER,[PROJECT],{PROJECT:{"role":"project","source_node_offsets":scope,"bindings":bindings}})
	if not result.get("ok",false):
		staged.free()
		return result
	var nested: Dictionary = staged.project_player([PROJECT])
	if not nested.get("ok",false):
		staged.free()
		return nested
	var child: Node2D = nested.player
	var native_node: Variant = child.get("source_nodes").get(BUTTON)
	var native_button: Variant = native_node.get_meta("source_button",null) if is_instance_valid(native_node) else null
	var native_control: Variant = native_button.get("_input_area") if is_instance_valid(native_button) else null
	if not native_control is Control:
		staged.free()
		return _fail("source_enhance_action_original_input_control_required")
	_parent = weakref(parent)
	_forge = weakref(forge)
	_action = weakref(model.action)
	_original_action_visible = model.action.visible
	_scene = staged
	_child = child
	_control = native_control
	_button = native_button
	_presented_offsets=scope.duplicate()
	_presented_target=model.target
	parent.add_child(staged)
	if not staged.is_inside_tree() or not forge.is_visible_in_tree():
		close()
		return _fail("source_enhance_action_mount_unavailable")
	var source_display: Variant=native_node.get_meta("source_display_color",null)
	var caption: Variant=child.get("source_nodes").get(15760 if model.disabled else 16328)
	var caption_display: Variant=caption.get_meta("source_display_color",null) if is_instance_valid(caption) else null
	if not native_control.is_visible_in_tree() or not source_display is Color or source_display.a<=0 or not is_instance_valid(caption) or not caption.is_visible_in_tree() or not caption_display is Color or caption_display.a<=0:
		close()
		return _fail("source_enhance_action_original_default_visibility_unavailable")
	model.action.hide()
	_replaced = true
	forge.visibility_changed.connect(_owner_visibility_changed)
	forge.tree_exiting.connect(close)
	parent.tree_exiting.connect(close,CONNECT_ONE_SHOT)
	return {"ok":true,"handled":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":scope.duplicate(),"bound_detail_fields":_fields.keys(),"parent_member":PARENT_MEMBER,"parent_sha256":PARENT_SHA256,"parent_project_offset":PROJECT,"parent_original_position":Vector2(603,343.50750732421875),"parent_original_alpha":255,"opening_clip_inferred":false,"partial_source_scene":true,"complete_screen_contract":false,"selection_cost_confirmation_owner":"existing forge._execute"}

func refresh() -> Dictionary:
	var forge: Object = _forge.get_ref() if _forge != null else null
	var model: Dictionary = _model(forge)
	if not model.get("ok",false):
		close()
		return model
	if not forge.is_visible_in_tree() or not is_instance_valid(_scene) or _scene.is_queued_for_deletion():
		close()
		return _fail("source_enhance_action_owner_or_scene_hidden")
	var action: Object = _action.get_ref() if _action != null else null
	if action != model.action:
		close()
		return _fail("source_enhance_action_owner_control_changed")
	var result: Dictionary={"ok":true}
	# Preserve the original pressed texture while enabled; only a real owner
	# availability change resets the button's normal/disabled display state.
	if (_button.get("current_state")=="disabled")!=model.disabled:result=_child.set_bound_displaystate(BUTTON,not model.disabled)
	if result.get("ok",false): result = _child.set_bound_visible(NORMAL,not model.disabled)
	if result.get("ok",false): result = _child.set_bound_visible(DISABLED,model.disabled)
	if result.get("ok",false):result=_refresh_fields(model)
	if not result.get("ok",false): close()
	return result

func _refresh_fields(model: Dictionary) -> Dictionary:
	var result: Dictionary={"ok":true}
	if _fields.has("title"):
		result=_child.set_bound_text(TARGET_TITLE,model.title)
		if result.get("ok",false):result=_child.set_bound_visible(TARGET_TITLE,not model.title.is_empty())
		if not result.get("ok",false):return result
	if _fields.has("fee"):
		result=_child.set_bound_text(138568,str(model.fee.get("value","")))
		if result.get("ok",false):result=_child.set_bound_visible(FEE_GROUP,model.fee.has("value"))
		if not result.get("ok",false):return result
	if _fields.has("probability"):
		result=_child.set_bound_visible(PROBABILITY,model.info_button!=null)
		var enabled: bool=model.info_button!=null and not model.info_button.disabled
		var native: Variant=_child.source_nodes.get(PROBABILITY)
		var button: Variant=native.get_meta("source_button",null) if is_instance_valid(native) else null
		if result.get("ok",false) and (not is_instance_valid(button) or (button.get("current_state")=="disabled")==enabled):result=_child.set_bound_displaystate(PROBABILITY,enabled)
		if not result.get("ok",false):return result
	_presented_target=model.target
	return {"ok":true,"target_reference":_presented_target,"bound_detail_fields":_fields.keys(),"transaction_requested":false}

func _show_probabilities() -> Dictionary:
	var forge: Object=_forge.get_ref() if _forge!=null else null
	var model: Dictionary=_model(forge)
	if not model.get("ok",false) or not is_instance_valid(_scene) or _scene.is_queued_for_deletion() or not forge.is_visible_in_tree():return _fail("source_enhance_probability_live_selection_required")
	if model.target!=_presented_target:return _fail("source_enhance_probability_presented_target_changed")
	var button: Variant=model.info_button
	if not is_instance_valid(button) or button.disabled:return _fail("source_enhance_probability_existing_detail_unavailable")
	# Dispatch the already wired actual Forge Browser '강화 정보' tab.
	# It retains its probability text, responsive layout and tab state.
	button.emit_signal("pressed")
	return {"ok":true,"existing_probability_detail_requested":true,"target_reference":model.target,"transaction_requested":false,"game_state_written":false}

func close() -> void:
	var parent: Object = _parent.get_ref() if _parent != null else null
	if is_instance_valid(parent) and parent.tree_exiting.is_connected(close): parent.tree_exiting.disconnect(close)
	_parent = null
	var forge: Object = _forge.get_ref() if _forge != null else null
	if is_instance_valid(forge):
		if forge.visibility_changed.is_connected(_owner_visibility_changed): forge.visibility_changed.disconnect(_owner_visibility_changed)
		if forge.tree_exiting.is_connected(close): forge.tree_exiting.disconnect(close)
	var action: Object = _action.get_ref() if _action != null else null
	if _replaced and is_instance_valid(action): action.visible = _original_action_visible
	_replaced = false
	_forge = null
	_action = null
	_child = null
	_control = null
	_button = null
	_fields.clear()
	_presented_offsets.clear()
	_presented_target=""
	var previous: Node2D = _scene
	_scene = null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func presentation() -> Dictionary:
	return {"scene":_scene,"renderer":_child,"control":_control,"source_button":_button,"member":MEMBER,"source_offset":BUTTON,"handled":is_instance_valid(_scene),"source_node_offsets":_presented_offsets.duplicate(),"bound_detail_fields":_fields.keys(),"partial_source_scene":true,"complete_screen_contract":false}

func _activate() -> Dictionary:
	var forge: Object = _forge.get_ref() if _forge != null else null
	var model: Dictionary = _model(forge)
	if not model.get("ok",false):
		close()
		return model
	if not forge.is_visible_in_tree() or model.disabled: return _fail("source_enhance_action_existing_action_unavailable")
	if _action == null or _action.get_ref() != model.action: return _fail("source_enhance_action_owner_control_changed")
	if model.target!=_presented_target:return _fail("source_enhance_action_presented_target_changed")
	forge.call("_execute")
	return {"ok":true,"owner_callback_invoked":true,"transaction_result_claimed":false}

func _owner_visibility_changed() -> void:
	var forge: Object = _forge.get_ref() if _forge != null else null
	if not is_instance_valid(forge) or not forge.is_visible_in_tree(): close()

static func _model(forge: Object) -> Dictionary:
	if not is_instance_valid(forge) or forge.is_queued_for_deletion() or not forge is Control or not forge.has_method("_execute") or forge.get("mode") != "target": return _fail("source_enhance_action_existing_target_forge_required")
	var values: Variant = forge.get("values")
	var index: Variant = forge.get("selected_index")
	var scroll: Variant = forge.get("scroll_name")
	var action: Variant = forge.get("action")
	if not values is Array or typeof(index) != TYPE_INT or index < 0 or index >= values.size(): return _fail("source_enhance_action_actual_selection_required")
	var entry: Variant = values[index]
	if not entry is Dictionary or not entry.get("target_id") is String or entry["target_id"].is_empty(): return _fail("source_enhance_action_physical_target_reference_required")
	if not scroll is String or scroll.is_empty(): return _fail("source_enhance_action_actual_scroll_required")
	if not action is BaseButton or not is_instance_valid(action) or action.is_queued_for_deletion(): return _fail("source_enhance_action_existing_action_required")
	var title: String=""
	var title_label: Variant=forge.get("selected_name")
	if title_label is Label and is_instance_valid(title_label):title=title_label.text
	var fee: Dictionary={}
	if typeof(entry.get("cost"))==TYPE_INT and entry.cost>=0:fee={"value":entry.cost,"basis":entry.get("basis","")}
	var info_button: BaseButton
	var browser: Variant=forge.get("browser")
	var tabs: Variant=browser.get("tabs") if is_instance_valid(browser) else null
	if tabs is HBoxContainer and tabs.get_child_count()==2 and forge.is_ancestor_of(tabs):
		var candidate: Node=tabs.get_child(1)
		if candidate is Button and candidate.text=="강화 정보":info_button=candidate
	return {"ok":true,"action":action,"disabled":action.disabled,"target":entry.target_id,"title":title,"fee":fee,"info_button":info_button}

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
