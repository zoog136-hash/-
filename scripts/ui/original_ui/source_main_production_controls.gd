extends RefCounted
## Original production/quantity buttons use the existing current recipe owner.
## No crafting quote, material choice, transaction or save is implemented here.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const PARENT="UI/ProductionScene.csb"
const PARENT_SHA="cae6672733b914c0143fe376574e73012b0cd628113002693f0639c877f47328"
const ALL="UI/Production/Production_All.csb"
const ALL_SHA="328546745405eac58203853570d76e07d9cc95477ac4ecd701d786651e3786ec"
const MEMBER="UI/Production/Production_Tab_List.csb"
const SHA256="14c9c7ed1333e0b20a2362d9c095065716e91cc4641e1b77adefe21d03fd1afb"
const PROJECT=14392
const CONDITION_FIELDS={26204:"level_text",21148:"quota_text",20368:"period_text"}
const EMPTY_NOTICE=13448
const LIMITED_PANEL=18004
const BUTTONS={
	42160:{"kind":"craft","normal":42772,"disabled":42212,"labels":[44244,42264]},
	34356:{"kind":"reset","normal":35292,"disabled":34408,"labels":[35348,34464]},
	31860:{"kind":"add10","normal":32796,"disabled":31912,"labels":[32852,31968]},
	29364:{"kind":"add50","normal":30300,"disabled":29416,"labels":[30356,29472]}
}
const OFFSETS: Array[int]=[42160,44244,42264,34356,35680,35348,34788,34464,31860,33168,32852,32284,31968,29364,30672,30356,29788,29472]
var _pack: RefCounted
var _owner: WeakRef
var _action: WeakRef
var _action_visible: bool
var _scene: Node2D
var _child: Node2D
var _recipe: String=""
var _flags: Dictionary={}
var _attempted_recipe: String=""
var _attempted_action: WeakRef
var _condition_offsets: Array[int]=[]
var _empty_notice_available: bool=false
var _condition_model: Dictionary={}
var last_result: Dictionary={}

func configure(pack: RefCounted, owner: Control) -> Dictionary:
	for pair: Array in [[PARENT,PARENT_SHA],[ALL,ALL_SHA],[MEMBER,SHA256]]:
		if pack==null or pack.manifest.get("files",{}).get(pair[0],{}).get("sha256")!=pair[1]:return _fail("source_production_controls_original_identity_required")
	var allowed: Variant=pack.manifest.get("node_scopes",{}).get(MEMBER)
	for offset: int in OFFSETS:
		if allowed is Array and not allowed.has(offset):return _fail("source_production_controls_original_scope_required")
	var tree: Dictionary=pack.scene(MEMBER)
	_condition_offsets.clear()
	for offset: int in CONDITION_FIELDS:
		if not _node_at(tree.get("nodeTree",{}),offset).is_empty():_condition_offsets.append(offset)
	_empty_notice_available=not _node_at(tree.get("nodeTree",{}),EMPTY_NOTICE).is_empty()
	_pack=pack;_owner=weakref(owner)
	return {"ok":true,"partial_source_scene":true,"complete_screen_contract":false}

func refresh(parent: Node) -> Dictionary:
	var model: Dictionary=_model()
	if not model.get("ok",false):
		close();_attempted_recipe="";_attempted_action=null
		return model
	if not is_instance_valid(parent):close();return _fail("source_production_controls_actual_mount_required")
	if is_instance_valid(_scene) and _recipe==model.recipe and _action!=null and _action.get_ref()==model.action:
		for offset: int in BUTTONS:
			var enabled: bool=model.flags[offset]
			if _flags.get(offset)==enabled:continue
			var result: Dictionary=_child.set_bound_displaystate(offset,enabled)
			if result.get("ok",false):result=_child.set_bound_visible(int(BUTTONS[offset].normal),enabled)
			if result.get("ok",false):result=_child.set_bound_visible(int(BUTTONS[offset].disabled),not enabled)
			if not result.get("ok",false):close();return result
		_flags=model.flags.duplicate()
		var fields: Dictionary=_refresh_condition_fields(model)
		if not fields.get("ok",false):close();return fields
		return last_result.duplicate(true)
	# A rejected static source construction must not be repeated every frame.
	# A genuinely different selected recipe/action can make a new attempt.
	if _attempted_recipe==model.recipe and _attempted_action!=null and _attempted_action.get_ref()==model.action:return last_result.duplicate(true)
	close()
	_attempted_recipe=model.recipe;_attempted_action=weakref(model.action)
	var bindings: Dictionary={14172:{"visible":model.selected}}
	var scope: Array[int]=OFFSETS.duplicate()
	for offset: int in _condition_offsets:
		scope.append(offset)
		var text: String=model.conditions.get(CONDITION_FIELDS[offset],"")
		bindings[offset]={"role":"source_text","text":text,"visible":not text.is_empty()}
	if 21148 in _condition_offsets or 20368 in _condition_offsets:
		bindings[LIMITED_PANEL]={"visible":not model.conditions.get("period_text","").is_empty() or not model.conditions.get("quota_text","").is_empty(),"input":Callable(self,"_consume_condition_input")}
	if _empty_notice_available:
		scope.append(EMPTY_NOTICE)
		bindings[EMPTY_NOTICE]={"role":"static_source_text","visible":not model.selected}
	for offset: int in BUTTONS:
		var spec: Dictionary=BUTTONS[offset]
		var enabled: bool=model.flags[offset]
		bindings[offset]={"role":"button","activate":Callable(self,"_activate").bind(offset,model.recipe),"displaystate":enabled}
		bindings[int(spec.normal)]={"visible":enabled}
		bindings[int(spec.disabled)]={"visible":not enabled}
		for label: int in spec.labels:bindings[label]={"role":"static_source_text"}
	var next:=Scene.new()
	var result: Dictionary=next.configure_project(_pack,PARENT,132,{PROJECT:{"role":"project","visible":true,"source_node_offsets":scope,"bindings":bindings}},[PROJECT])
	if not result.get("ok",false):next.free();last_result=result;return result
	var nested: Dictionary=next.project_player([PROJECT])
	if not nested.get("ok",false):next.free();last_result=nested;return nested
	result=next.activate_authored_component_opacity()
	if result.get("ok",false):result=nested.player.activate_authored_component_opacity()
	if not result.get("ok",false):next.free();last_result=result;return result
	# Required controls must exist before the old action is hidden.
	for offset: int in BUTTONS:
		if _button_control(nested.player,offset)==null:next.free();last_result=_fail("source_production_controls_original_input_required");return last_result.duplicate(true)
	parent.add_child(next);next.z_index=150
	_scene=next;_child=nested.player;_recipe=model.recipe;_flags=model.flags.duplicate()
	_condition_model={"selected":model.selected,"conditions":model.conditions.duplicate(true)}
	_action=weakref(model.action);_action_visible=model.action.visible
	model.action.hide()
	last_result={"ok":true,"handled":true,"recipe_id":_recipe,"source_member":MEMBER,"craft_action_connected":true,"quantity_buttons_connected":true,"partial_source_scene":true,"complete_screen_contract":false,"progress_cancel_or_result_connected":false,"condition_text_offsets":_condition_offsets.duplicate(),"empty_selection_notice_connected":_empty_notice_available,"game_state_written":false}
	return last_result.duplicate(true)

func presentation() -> Dictionary:
	return {"scene":_scene,"partial_source_scene":true}

func blocks_point(point: Vector2) -> bool:
	if not point.is_finite() or not is_instance_valid(_scene) or _scene.is_queued_for_deletion():return false
	var model: Dictionary=_model()
	if not model.get("ok",false) or model.recipe!=_recipe:return false
	if 21148 in _condition_offsets or 20368 in _condition_offsets:
		var node: Variant=_child.source_nodes.get(LIMITED_PANEL)
		var control: Variant=node.get_node_or_null("SourceContentOrigin/OriginalSourceInput") if is_instance_valid(node) else null
		if control is Control and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point):return true
	for offset: int in BUTTONS:
		var control: Control=_button_control(_child,offset)
		if control!=null and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point):return true
	return false

func close() -> void:
	var action: Object=_action.get_ref() if _action!=null else null
	if is_instance_valid(action):action.visible=_action_visible
	_action=null;_child=null;_recipe="";_flags.clear();_condition_model.clear()
	var previous: Node2D=_scene
	_scene=null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():previous.hide();previous.queue_free()

func _activate(offset: int, expected_recipe: String) -> Dictionary:
	var model: Dictionary=_model()
	if not model.get("ok",false):return model
	if expected_recipe!=_recipe or model.recipe!=expected_recipe:return _fail("source_production_controls_current_recipe_changed")
	if not BUTTONS.has(offset) or not model.flags.get(offset,false):return _fail("source_production_controls_current_action_unavailable")
	var kind: String=BUTTONS[offset].kind
	if kind=="craft":
		# The actual button's _craft callback re-quotes and opens its existing
		# confirmation. Dispatch is not a claim of successful crafting/saving.
		model.action.emit_signal("pressed")
		return {"ok":true,"dispatched":true,"method":"existing crafting action.pressed","recipe_id":expected_recipe,"action_result_known":false}
	var amount: SpinBox=model.amount
	amount.value=amount.min_value if kind=="reset" else amount.value+(10 if kind=="add10" else 50)
	return {"ok":true,"owner_quantity_changed":true,"recipe_id":expected_recipe,"quantity":int(amount.value),"existing_value_changed_callback_used":true,"game_state_written":false}

func _model() -> Dictionary:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	if not owner is Control or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_visible_in_tree():return _fail("source_production_controls_current_owner_required")
	var script: Script=owner.get_script()
	var hud: Variant=owner.get("hud")
	var workspace: Variant=hud.get("workspace") if is_instance_valid(hud) else null
	if script==null or script.resource_path!="res://scripts/ui/renewal_crafting.gd" or not is_instance_valid(hud) or hud.get("active_section")!="crafting" or not workspace is Control or not workspace.is_ancestor_of(owner):return _fail("source_production_controls_actual_crafting_caller_required")
	var recipe: Variant=owner.get("current_id")
	var ids: Variant=owner.get("recipe_ids")
	var amount: Variant=owner.get("amount")
	var action: Variant=owner.get("action")
	if not recipe is String or not ids is Array or (not recipe.is_empty() and recipe not in ids):return _fail("source_production_controls_actual_recipe_selection_required")
	if recipe.is_empty() and not _empty_notice_available:return _fail("source_production_controls_actual_recipe_selection_required")
	if not amount is SpinBox or not is_instance_valid(amount) or not action is BaseButton or not is_instance_valid(action):return _fail("source_production_controls_existing_amount_and_action_required")
	for value: float in [amount.value,amount.min_value,amount.max_value]:
		if not is_finite(value) or value!=floor(value):return _fail("source_production_controls_integer_quantity_required")
	if amount.step!=1 or amount.min_value<1 or amount.value<amount.min_value or amount.value>amount.max_value:return _fail("source_production_controls_owner_quantity_bounds_required")
	var selected: bool=not recipe.is_empty()
	var editable: bool=selected and amount.editable
	var conditions: Dictionary={}
	var display: Variant=owner.get("source_condition_display")
	if selected and display is Dictionary and display.get("recipe_id")==recipe:
		for key: String in ["level_text","period_text","quota_text"]:
			if display.get(key) is String:conditions[key]=display[key]
	return {"ok":true,"recipe":recipe,"selected":selected,"conditions":conditions,"amount":amount,"action":action,"flags":{42160:selected and not action.disabled,34356:editable and amount.value>amount.min_value,31860:editable and amount.value+10<=amount.max_value,29364:editable and amount.value+50<=amount.max_value}}

func _refresh_condition_fields(model: Dictionary) -> Dictionary:
	var current: Dictionary={"selected":model.selected,"conditions":model.conditions}
	if current==_condition_model:return {"ok":true,"changed":false}
	var result: Dictionary=_child.set_bound_visible(14172,model.selected)
	if not result.get("ok",false):return result
	for offset: int in _condition_offsets:
		var text: String=model.conditions.get(CONDITION_FIELDS[offset],"")
		result=_child.set_bound_text(offset,text)
		if result.get("ok",false):result=_child.set_bound_visible(offset,not text.is_empty())
		if not result.get("ok",false):return result
	if 21148 in _condition_offsets or 20368 in _condition_offsets:
		result=_child.set_bound_visible(LIMITED_PANEL,not model.conditions.get("period_text","").is_empty() or not model.conditions.get("quota_text","").is_empty())
		if not result.get("ok",false):return result
	if _empty_notice_available:result=_child.set_bound_visible(EMPTY_NOTICE,not model.selected)
	if result.get("ok",false):_condition_model=current.duplicate(true)
	return result

func _consume_condition_input(_event: InputEvent) -> void:
	if is_instance_valid(_scene) and _scene.is_inside_tree():_scene.get_viewport().set_input_as_handled()

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

static func _button_control(scene: Node2D, offset: int) -> Control:
	if not is_instance_valid(scene):return null
	var node: Variant=scene.source_nodes.get(offset)
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) else null
	var control: Variant=button.get("_input_area") if is_instance_valid(button) else null
	return control as Control

func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
