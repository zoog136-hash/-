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
var last_result: Dictionary={}

func configure(pack: RefCounted, owner: Control) -> Dictionary:
	for pair: Array in [[PARENT,PARENT_SHA],[ALL,ALL_SHA],[MEMBER,SHA256]]:
		if pack==null or pack.manifest.get("files",{}).get(pair[0],{}).get("sha256")!=pair[1]:return _fail("source_production_controls_original_identity_required")
	var allowed: Variant=pack.manifest.get("node_scopes",{}).get(MEMBER)
	for offset: int in OFFSETS:
		if allowed is Array and not allowed.has(offset):return _fail("source_production_controls_original_scope_required")
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
		return last_result.duplicate(true)
	# A rejected static source construction must not be repeated every frame.
	# A genuinely different selected recipe/action can make a new attempt.
	if _attempted_recipe==model.recipe and _attempted_action!=null and _attempted_action.get_ref()==model.action:return last_result.duplicate(true)
	close()
	_attempted_recipe=model.recipe;_attempted_action=weakref(model.action)
	var bindings: Dictionary={14172:{"visible":true}}
	for offset: int in BUTTONS:
		var spec: Dictionary=BUTTONS[offset]
		var enabled: bool=model.flags[offset]
		bindings[offset]={"role":"button","activate":Callable(self,"_activate").bind(offset,model.recipe),"displaystate":enabled}
		bindings[int(spec.normal)]={"visible":enabled}
		bindings[int(spec.disabled)]={"visible":not enabled}
		for label: int in spec.labels:bindings[label]={"role":"static_source_text"}
	var next:=Scene.new()
	var result: Dictionary=next.configure_project(_pack,PARENT,132,{PROJECT:{"role":"project","visible":true,"source_node_offsets":OFFSETS.duplicate(),"bindings":bindings}},[PROJECT])
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
	_action=weakref(model.action);_action_visible=model.action.visible
	model.action.hide()
	last_result={"ok":true,"handled":true,"recipe_id":_recipe,"source_member":MEMBER,"craft_action_connected":true,"quantity_buttons_connected":true,"partial_source_scene":true,"complete_screen_contract":false,"progress_cancel_or_result_connected":false,"game_state_written":false}
	return last_result.duplicate(true)

func presentation() -> Dictionary:
	return {"scene":_scene,"partial_source_scene":true}

func blocks_point(point: Vector2) -> bool:
	if not point.is_finite() or not is_instance_valid(_scene) or _scene.is_queued_for_deletion():return false
	var model: Dictionary=_model()
	if not model.get("ok",false) or model.recipe!=_recipe:return false
	for offset: int in BUTTONS:
		var control: Control=_button_control(_child,offset)
		if control!=null and control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point):return true
	return false

func close() -> void:
	var action: Object=_action.get_ref() if _action!=null else null
	if is_instance_valid(action):action.visible=_action_visible
	_action=null;_child=null;_recipe="";_flags.clear()
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
	if not recipe is String or recipe.is_empty() or not ids is Array or recipe not in ids:return _fail("source_production_controls_actual_recipe_selection_required")
	if not amount is SpinBox or not is_instance_valid(amount) or not action is BaseButton or not is_instance_valid(action):return _fail("source_production_controls_existing_amount_and_action_required")
	for value: float in [amount.value,amount.min_value,amount.max_value]:
		if not is_finite(value) or value!=floor(value):return _fail("source_production_controls_integer_quantity_required")
	if amount.step!=1 or amount.min_value<1 or amount.value<amount.min_value or amount.value>amount.max_value:return _fail("source_production_controls_owner_quantity_bounds_required")
	var editable: bool=amount.editable
	return {"ok":true,"recipe":recipe,"amount":amount,"action":action,"flags":{42160:not action.disabled,34356:editable and amount.value>amount.min_value,31860:editable and amount.value+10<=amount.max_value,29364:editable and amount.value+50<=amount.max_value}}

static func _button_control(scene: Node2D, offset: int) -> Control:
	if not is_instance_valid(scene):return null
	var node: Variant=scene.source_nodes.get(offset)
	var button: Variant=node.get_meta("source_button",null) if is_instance_valid(node) else null
	var control: Variant=button.get("_input_area") if is_instance_valid(button) else null
	return control as Control

func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
