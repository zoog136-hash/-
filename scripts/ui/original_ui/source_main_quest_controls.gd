extends RefCounted
## Partial original quest chrome. The existing owner retains rows and every rule.
const Scene = preload("res://scripts/ui/original_ui/sprite_scene.gd")
const MEMBER = "UI/Quest/Quest_All.csb"
const SHA256 = "3991dae23f1aafb97a7cea17a7eeecc554ec7e0e9eba46c6ba35806e9b6ef2a8"
const PARENT_MEMBER = "UI/QuestScene.csb"
const PARENT_SHA256 = "d11ff59b60b9e80d953358ac50b740ab2858548577deede67b5847e706cae717"
const PROJECT = 476
const SOURCE_OFFSETS: Array[int] = [26500,27408,26952,26556,25048,25428,25100,18928,19708,19380,18984,17520,17900,17572,2412]
const BUTTONS: Array[int] = [26500,25048,18928,17520,2412]
var _hud: WeakRef
var _owner: WeakRef
var _parent: WeakRef
var _scene: Node2D
var _child: Node2D
var _hidden: Array[Dictionary] = []
var _buttons: Array = []
var _controls: Array = []

func configure(pack: RefCounted, hud: Node, owner: Control, parent: Node) -> Dictionary:
	close()
	var model: Dictionary = _model(hud,owner)
	if not model.get("ok",false): return model
	if not is_instance_valid(parent) or parent.is_queued_for_deletion(): return _fail("source_quest_controls_actual_parent_required")
	if pack == null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","") != SHA256 or pack.manifest.get("files",{}).get(PARENT_MEMBER,{}).get("sha256","") != PARENT_SHA256:
		return _fail("source_quest_controls_original_identity_mismatch")
	var bindings: Dictionary = {
		26500:{"role":"button","activate":Callable(self,"_select").bind("main")},
		25048:{"role":"button","activate":Callable(self,"_select").bind("main")},
		18928:{"role":"button","activate":Callable(self,"_select").bind("achievement")},
		17520:{"role":"button","activate":Callable(self,"_select").bind("achievement")},
		2412:{"role":"button","activate":Callable(self,"_close_workspace")},
		26952:{"role":"static_source_text"},25100:{"role":"static_source_text"},
		19380:{"role":"static_source_text"},17572:{"role":"static_source_text"}
	}
	for offset: int in [26500,25048]: bindings[offset]["displaystate"] = not model.tabs.main.disabled
	for offset: int in [18928,17520]: bindings[offset]["displaystate"] = not model.tabs.achievement.disabled
	_set_variant_bindings(bindings,model.selected)
	var staged := Scene.new()
	var result: Dictionary = staged.configure_nodes(pack,PARENT_MEMBER,[PROJECT],{PROJECT:{"role":"project","source_node_offsets":SOURCE_OFFSETS.duplicate(),"bindings":bindings}})
	if not result.get("ok",false):
		staged.free()
		return result
	var nested: Dictionary = staged.project_player([PROJECT])
	if not nested.get("ok",false):
		staged.free()
		return nested
	var child: Node2D = nested.player
	var native_buttons: Array = []
	var controls: Array = []
	for offset: int in BUTTONS:
		var raw: Variant = child.source_nodes.get(offset)
		var button: Variant = (raw.get_meta("source_button") if raw.has_meta("source_button") else null) if is_instance_valid(raw) else null
		var control: Variant = button.get("_input_area") if is_instance_valid(button) else null
		if not control is Control:
			staged.free()
			return _fail("source_quest_controls_actual_source_input_required")
		native_buttons.append(button)
		controls.append(control)
	_hud = weakref(hud)
	_owner = weakref(owner)
	_parent = weakref(parent)
	_scene = staged
	_child = child
	_buttons = native_buttons
	_controls = controls
	parent.add_child(staged)
	if not staged.is_inside_tree() or not _model(hud,owner).get("ok",false):
		close()
		return _fail("source_quest_controls_mount_or_owner_changed")
	for category: String in ["main","achievement"]:
		var button: BaseButton = model.tabs[category]
		_hidden.append({"button":weakref(button),"visible":button.visible})
		button.hide()
	owner.visibility_changed.connect(_owner_visibility_changed)
	owner.tree_exiting.connect(close)
	parent.tree_exiting.connect(close)
	return {"ok":true,"handled":true,"member":MEMBER,"sha256":SHA256,"source_node_offsets":SOURCE_OFFSETS.duplicate(),"parent_member":PARENT_MEMBER,"parent_sha256":PARENT_SHA256,"parent_project_offset":PROJECT,"parent_original_position":Vector2(600,337.5),"parent_original_alpha":255,"partial_source_scene":true,"complete_screen_contract":false,"rows_rewards_claims_connected":false,"clip_metadata":[{"name":"Select_Popup_On","startIndex":5,"endIndex":15}],"playback_policy_inferred":false}

func refresh() -> Dictionary:
	var hud: Object = _hud.get_ref() if _hud != null else null
	var owner: Object = _owner.get_ref() if _owner != null else null
	var model: Dictionary = _model(hud,owner)
	if not model.get("ok",false):
		close()
		return model
	if not is_instance_valid(_scene) or _scene.is_queued_for_deletion() or not is_instance_valid(_child):
		close()
		return _fail("source_quest_controls_original_scene_unavailable")
	for item: Dictionary in _hidden:
		if not is_instance_valid(item.button.get_ref()) or item.button.get_ref() not in [model.tabs.main,model.tabs.achievement]:
			close()
			return _fail("source_quest_controls_owner_tabs_changed")
	for pair: Array in [[26500,"main"],[25048,"main"],[18928,"achievement"],[17520,"achievement"]]:
		var state_result: Dictionary = _child.set_bound_displaystate(pair[0],not model.tabs[pair[1]].disabled)
		if not state_result.get("ok",false):
			close()
			return state_result
	var variants: Dictionary = {}
	_set_variant_bindings(variants,model.selected)
	for offset: int in variants:
		var result: Dictionary = _child.set_bound_visible(offset,variants[offset].visible)
		if not result.get("ok",false):
			close()
			return result
	return {"ok":true,"handled":true,"selected":model.selected,"partial_source_scene":true,"complete_screen_contract":false}

func close() -> void:
	var owner: Object = _owner.get_ref() if _owner != null else null
	var parent: Object = _parent.get_ref() if _parent != null else null
	if is_instance_valid(owner):
		if owner.visibility_changed.is_connected(_owner_visibility_changed): owner.visibility_changed.disconnect(_owner_visibility_changed)
		if owner.tree_exiting.is_connected(close): owner.tree_exiting.disconnect(close)
	if is_instance_valid(parent) and parent.tree_exiting.is_connected(close): parent.tree_exiting.disconnect(close)
	for item: Dictionary in _hidden:
		var button: Object = item.button.get_ref()
		if is_instance_valid(button): button.visible = item.visible
	_hidden.clear()
	_buttons.clear()
	_controls.clear()
	_hud = null
	_owner = null
	_parent = null
	_child = null
	var previous: Node2D = _scene
	_scene = null
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func presentation() -> Dictionary:
	return {"scene":_scene,"renderer":_child,"source_buttons":_buttons.duplicate(),"controls":_controls.duplicate(),"member":MEMBER,"source_offsets":BUTTONS.duplicate(),"handled":is_instance_valid(_scene),"partial_source_scene":true,"complete_screen_contract":false}

func _select(category: String) -> Dictionary:
	var hud: Object = _hud.get_ref() if _hud != null else null
	var owner: Object = _owner.get_ref() if _owner != null else null
	var model: Dictionary = _model(hud,owner)
	if not model.get("ok",false):
		close()
		return model
	if category not in ["main","achievement"] or model.tabs[category].disabled: return _fail("source_quest_controls_existing_tab_unavailable")
	owner.call("_select",category)
	return refresh()

func _close_workspace() -> Dictionary:
	var hud: Object = _hud.get_ref() if _hud != null else null
	var owner: Object = _owner.get_ref() if _owner != null else null
	var model: Dictionary = _model(hud,owner)
	if not model.get("ok",false):
		close()
		return model
	hud.call("_close_workspace")
	close()
	return {"ok":true,"owner_close_invoked":true}

func _owner_visibility_changed() -> void:
	var owner: Object = _owner.get_ref() if _owner != null else null
	if not is_instance_valid(owner) or not owner.is_visible_in_tree(): close()

static func _set_variant_bindings(bindings: Dictionary, selected: String) -> void:
	for pair: Array in [[26500,"main",true],[25048,"main",false],[18928,"achievement",true],[17520,"achievement",false]]:
		var binding: Dictionary = bindings.get(pair[0],{})
		binding["visible"] = (selected == pair[1]) == pair[2]
		bindings[pair[0]] = binding

static func _model(hud: Object, owner: Object) -> Dictionary:
	if not is_instance_valid(hud) or hud.is_queued_for_deletion() or not hud.has_method("_close_workspace") or hud.get("active_section") != "quests": return _fail("source_quest_controls_current_hud_section_required")
	if not is_instance_valid(owner) or not owner is Control or owner.is_queued_for_deletion() or not owner.is_inside_tree() or not owner.is_visible_in_tree() or hud.get("quest_view") != owner or not owner.has_method("_select"): return _fail("source_quest_controls_current_visible_owner_required")
	var selected: Variant = owner.get("selected")
	var tabs: Variant = owner.get("tab_buttons")
	if not selected is String or selected not in ["main","common","achievement","other"] or not tabs is Dictionary: return _fail("source_quest_controls_actual_category_required")
	for category: String in ["main","achievement"]:
		if not tabs.get(category) is BaseButton or not is_instance_valid(tabs[category]) or tabs[category].is_queued_for_deletion(): return _fail("source_quest_controls_existing_owner_tab_required")
	return {"ok":true,"selected":selected,"tabs":tabs}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"handled":false,"code":code}
