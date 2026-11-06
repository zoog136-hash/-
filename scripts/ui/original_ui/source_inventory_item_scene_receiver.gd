extends RefCounted
## Distinct inventory host capability; never reuses a Forge owner assumption.
const SCRIPT_PATH="res://scripts/ui/original_ui/source_inventory_item_scene_receiver.gd"
const VIEW_PATH="res://scripts/ui/original_ui/source_main_inventory_view.gd"
const CONTROLLER_PATH="res://scripts/ui/original_ui/source_main_hud.gd"
const PLAYER_PATH="res://scripts/ui/original_ui/sprite_scene.gd"
const SCHEMA="twilight-inventory-item-scene-host-registration-v1"
const Content=preload("res://scripts/ui/original_ui/source_item_scene_receiver.gd")
var _hud: WeakRef
var _controller: WeakRef
var _view: WeakRef
var _player: WeakRef
var _node: WeakRef
var _record: Dictionary={}
var _target: Dictionary={}
var _assignment: Dictionary={}
var _reference: String=""
var _physical_id: String=""
var _model_seed: int=0

static func capture(hud: Node, view: RefCounted, reference: String) -> Dictionary:
	if not is_instance_valid(hud) or not is_instance_valid(view) or view.get_script()==null or view.get_script().resource_path!=VIEW_PATH:return _fail("inventory_item_scene_actual_view_required")
	# Checkpoint WIP: the actual view's two-phase receiver is not connected yet.
	# Stay inactive/fail closed rather than pretend the Forge path is inventory.
	if not view.has_method("item_scene_receiver"):return _fail("inventory_item_scene_view_receiver_pending")
	var controller: Variant=hud.get("original_main_ui_controller")
	if not controller is Node or not is_instance_valid(controller) or controller.get_script()==null or controller.get_script().resource_path!=CONTROLLER_PATH or controller.get("_inventory_view")!=view or not controller.is_inside_tree():return _fail("inventory_item_scene_registered_view_required")
	var current: Dictionary=view.item_scene_receiver(reference)
	if not current.get("ok",false):return current
	var factory: Script=load(SCRIPT_PATH)
	var receiver: RefCounted=factory.new()
	receiver._hud=weakref(hud);receiver._controller=weakref(controller);receiver._view=weakref(view)
	receiver._player=weakref(current.player);receiver._node=weakref(current.player.source_nodes[15012])
	receiver._record=current.record.duplicate(true);receiver._reference=reference;receiver._physical_id=current.physical_instance_id;receiver._model_seed=current.model_seed
	receiver._target=current.target.duplicate(true);receiver._assignment=current.assignment.duplicate(true)
	var registration: Dictionary={"schema":SCHEMA,"kind":"TWILIGHT_host_registration","space":"twilight_host_sprite_anchor","original_registration_confirmed":false,"receiver":receiver,"target":receiver._target.duplicate(true),"inventory_assignment":receiver._assignment.duplicate(true),"host_policy":"identity original item-CSB root at this actual owned visible-row Common_Slot15012 Sprite anchor; hidden atomic preparation then same live source hierarchy; no fitting/offset/playback"}
	return {"ok":true,"receiver":receiver,"registration":registration,"current_raw_record":receiver._record.duplicate(true),"reference":reference,"physical_instance_id":receiver._physical_id,"rendered":false}

func validate_descriptor(descriptor: Dictionary) -> Dictionary:
	var current: Dictionary=_current()
	if not current.get("ok",false):return current
	var registration: Variant=descriptor.get("registration")
	if not registration is Dictionary or registration.get("schema")!=SCHEMA or registration.get("kind")!="TWILIGHT_host_registration" or registration.get("space")!="twilight_host_sprite_anchor" or typeof(registration.get("original_registration_confirmed"))!=TYPE_BOOL or registration.original_registration_confirmed!=false or registration.get("receiver")!=self or registration.get("target")!=_target or registration.get("inventory_assignment")!=_assignment:return _fail("inventory_item_scene_typed_assignment_mismatch")
	var result: Dictionary=Content.validate_source_content(descriptor,current.record)
	if not result.get("ok",false):return result
	result["registration_kind"]="TWILIGHT_host_registration"
	result["original_registration_confirmed"]=false
	result["target"]=_target.duplicate(true)
	result["inventory_assignment"]=_assignment.duplicate(true)
	result["physical_instance_id"]=_physical_id
	result["lifecycle_phase"]=current.lifecycle_phase
	return result

func validate_attachment(renderer: Node2D, offset: int, descriptor: Dictionary) -> Dictionary:
	if _player==null or _player.get_ref()!=renderer or offset!=15012:return _fail("inventory_item_scene_actual_destination_changed")
	return validate_descriptor(descriptor)

func _current() -> Dictionary:
	var hud: Object=_hud.get_ref() if _hud!=null else null
	var controller: Object=_controller.get_ref() if _controller!=null else null
	var view: Object=_view.get_ref() if _view!=null else null
	var player: Object=_player.get_ref() if _player!=null else null
	var node: Object=_node.get_ref() if _node!=null else null
	if not is_instance_valid(hud) or not is_instance_valid(controller) or not is_instance_valid(view) or hud.get("original_main_ui_controller")!=controller or controller.get("_inventory_view")!=view or not controller.is_inside_tree() or controller.is_queued_for_deletion():return _fail("inventory_item_scene_actual_owner_replaced")
	if not is_instance_valid(player) or not player is Node2D or player.is_queued_for_deletion() or not player.is_inside_tree() or not is_instance_valid(node) or node.is_queued_for_deletion():return _fail("inventory_item_scene_live_source_destination_required")
	var current: Dictionary=view.item_scene_receiver(_reference)
	if not current.get("ok",false):return current
	if current.player!=player or current.record!=_record or current.physical_instance_id!=_physical_id or current.model_seed!=_model_seed or current.target!=_target or current.assignment!=_assignment or player.source_nodes.get(15012)!=node:return _fail("inventory_item_scene_row_generation_or_owner_changed")
	if player.get_script()==null or player.get_script().resource_path!=PLAYER_PATH or player.source_pack!=controller.source_role_pack() or player.source_member!=_target.member or player.source_pack.manifest_sha256!=_target.manifest_sha256 or not node.get_meta("source_asset_slot",false):return _fail("inventory_item_scene_target_pack_or_slot_changed")
	return current

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"error":code,"code":code,"runtime_rendering_verified":false}
