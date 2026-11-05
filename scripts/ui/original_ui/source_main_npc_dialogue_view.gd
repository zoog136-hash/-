extends RefCounted
## Consume the current owner's already resolved conversation. The original
## full-screen Next is only a single next-only transition, never an action.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Bindings=preload("res://scripts/ui/original_ui/source_main_npc_dialogue_bindings.gd")
signal closed
var _pack: RefCounted
var _owner: WeakRef
var _scene: Node2D
var _model: Dictionary={}
var _next_id: String=""

func configure(pack: RefCounted) -> void:
	_pack=pack

func open(parent: Node, owner: Control, resolved: Dictionary) -> Dictionary:
	if not is_instance_valid(parent) or not is_instance_valid(owner):return _decline("source_npc_dialogue_existing_mount_and_owner_required")
	if not owner.has_method("_choice_picked") or not owner.get("source_dialogue_model") is Dictionary:return _decline("source_npc_dialogue_existing_owner_model_required")
	if owner.get("source_dialogue_model")!=resolved:return _decline("source_npc_dialogue_current_owner_model_changed")
	if not resolved.get("ok",false) or not resolved.get("choices") is Array:return _decline("source_npc_dialogue_existing_success_and_choices_required")
	for field: String in ["npc_id","node_id"]:
		if not resolved.get(field) is String or str(resolved[field]).is_empty():return _decline("source_npc_dialogue_existing_identity_required")
	if owner.get("npc_id")!=resolved.npc_id or owner.get("current_node")!=resolved.node_id:return _decline("source_npc_dialogue_current_owner_identity_changed")
	var next_id: String=""
	var choices: Array=resolved.choices
	if choices.size()>1:return _decline("source_npc_dialogue_original_choice_targets_unestablished")
	if choices.size()==1:
		var choice: Variant=choices[0]
		if not choice is Dictionary or not choice.get("next") is String or str(choice.next).is_empty() or choice.get("action")!="":return _decline("source_npc_dialogue_original_action_choice_target_unestablished")
		next_id=choice.next
	var next_callback: Callable=Callable(self,"_next_requested") if not next_id.is_empty() else Callable()
	var contract: Dictionary=Bindings.build(_pack,resolved,Callable(self,"_close_requested"),next_callback)
	if not contract.get("ok",false):close();return contract
	var next:=Scene.new()
	var scope: Array[int]=[]
	scope.assign(contract.source_node_offsets)
	var result: Dictionary=next.configure_nodes(_pack,contract.parent_member,[Bindings.PARENT_PROJECT],{Bindings.PARENT_PROJECT:{"role":"project","source_node_offsets":scope,"bindings":contract.bindings}})
	if not result.get("ok",false):next.free();close();return result
	# Open this caller with the actual source opening clip. The source loop
	# is not started or inferred. No source portrait or preview is included.
	result=next.play("Npc_On",false)
	if not result.get("ok",false):next.free();close();return result
	var previous: Node2D=_scene
	parent.add_child(next)
	next.z_index=150
	_scene=next
	_owner=weakref(owner)
	_model=resolved.duplicate(true)
	_next_id=next_id
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()
	return {"ok":true,"handled":true,"npc_id":resolved.npc_id,"node_id":resolved.node_id,"name_and_text_connected":true,"close_connected":true,"next_connected":not next_id.is_empty(),"next_basis":"exactly one existing next-only transition; no action or first-choice fallback","portrait_connected":false,"loop_policy_inferred":false,"partial_source_scene":true,"complete_screen_contract":false,"game_state_written":false}

func is_open() -> bool:
	return is_instance_valid(_scene) and not _scene.is_queued_for_deletion()

func presentation() -> Dictionary:
	return {"scene":_scene,"partial_source_scene":true}

func close() -> void:
	var previous: Node2D=_scene
	_scene=null
	_owner=null
	_model.clear()
	_next_id=""
	if is_instance_valid(previous) and not previous.is_queued_for_deletion():
		previous.hide()
		previous.queue_free()

func _next_requested() -> Dictionary:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	if owner==null or _next_id.is_empty() or owner.get("source_dialogue_model")!=_model or owner.get("current_node")!=_model.get("node_id"):return {"ok":false,"code":"source_npc_dialogue_current_transition_unavailable"}
	# This reuses the exact current owner's callback. That callback resolves
	# the next model and emits it back to the presenter; no service is copied.
	owner.call("_choice_picked",_next_id,"")
	return {"ok":true,"dispatched":true,"method":"existing dialogue owner._choice_picked","action_dispatched":false,"action_result_known":false}

func _close_requested() -> Dictionary:
	close()
	closed.emit()
	return {"ok":true,"closed":true,"game_state_written":false}

func _decline(code: String) -> Dictionary:
	close()
	return {"ok":false,"handled":false,"code":code}
