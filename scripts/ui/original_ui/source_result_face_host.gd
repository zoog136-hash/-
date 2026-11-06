extends RefCounted
## Actual card instance -> exact source back hierarchy, in a declared host frame.
## Source transforms are never flattened into Face.back or a fitted rectangle.
const Scene=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const Cards=preload("res://scripts/lineagem_base508.gd")
const OWNER="res://scripts/ui/card_reveal_card.gd"
const PROVIDER="res://scripts/ui/source523_result_card_images.gd"
const CHECKBOX_FIELDS=["backGroundBoxData","backGroundBoxSelectedData","frontCrossData","backGroundBoxDisabledData","frontCrossDisabledData"]
var _owner: WeakRef
var _face: WeakRef
var _rim: WeakRef
var _bridge: Node2D
var _scene: Node2D
var _sprite: Sprite2D
var _prior_rim_visible: bool=true
var _prior_face_active: bool=false
var _seed: int=0
var _cached: bool=false
var _status: Dictionary={}

func refresh(owner: Control) -> Dictionary:
	if not _actual_owner(owner):clear();return _missing("result_face_actual_live_owner_required")
	if _owner!=null and _owner.get_ref()!=owner:close()
	if _owner==null:
		_owner=weakref(owner)
		owner.tree_exiting.connect(close)
		owner.visibility_changed.connect(_visibility_changed)
	var face: Control=owner.face
	if face.size.x<=0 or face.size.y<=0 or not face.size.is_finite():clear();return _missing("result_face_actual_extent_pending")
	var phase: String="back" if owner.waiting_for_press or face.elapsed<0 else "front" if face.elapsed>=face.duration else "transition"
	if phase!="back":
		clear()
		return _missing("result_face_front_portrait_registration_pending" if phase=="front" else "result_face_transition_retains_actual_candidates")
	var seed: int=_model_seed(owner)
	if _cached and seed==_seed and (not is_instance_valid(_scene) or _scene.is_queued_for_deletion() or not _scene.is_inside_tree()):_cached=false
	if _cached and seed==_seed:
		_update_host_transform(owner,face)
		return _status.duplicate(true)
	clear()
	var canonical: Dictionary=Cards.canonical(owner.record)
	if canonical.get("source_deck_id") not in [1,2,98]:return _missing("result_face_deck_outside_current_image_scope")
	var role: Dictionary=owner.original_result_card_contract()
	if not role.get("ok",false):return _missing(str(role.get("code","result_face_source_role_unavailable")))
	if not ResourceLoader.exists(PROVIDER):return _missing("result_face_public_image_provider_dependency_pending")
	var api: Script=load(PROVIDER)
	if api==null:return _missing("result_face_public_image_provider_unavailable")
	var image: Dictionary=api.describe(owner)
	if not image.get("ok",false) or image.get("phase")!="back" or not image.get("texture") is Texture2D:return _missing(str(image.get("status","result_face_original_back_pixels_required")))
	var selected: Dictionary=role.back
	var pack: RefCounted=selected.pack
	var provenance: Dictionary=image.get("provenance",{})
	if image.get("source_id")!=role.source_id or image.get("grade_id")!=role.grade_id or image.get("operation")!=role.operation or provenance.get("manifest_sha256")!=pack.manifest_sha256 or provenance.get("member")!=selected.member or provenance.get("source_sha256")!=selected.source_sha256 or provenance.get("node_offset")!=selected.node_offset or provenance.get("reference")!=selected.fileNameData or image.get("parent_chain")!=selected.parent_chain:return _missing("result_face_exact_owner_descriptor_changed")
	var offset: int=int(selected.node_offset)
	var tree: Dictionary=pack.scene(selected.member)
	var check: int=972 if role.operation=="fusion" else 9176
	var checkbox: Dictionary=_node_at(tree.get("nodeTree",{}),check)
	if checkbox.get("classname")!="CheckBox" or checkbox.get("options",{}).get("selectedState")!=0:return _missing("result_face_original_passive_checkbox_state_required")
	# This source ancestor has no own state pixels. Disabling its input cannot
	# change any checkbox texture; actual reveal input stays with RevealCard.
	for field: String in CHECKBOX_FIELDS:
		if checkbox.options.get(field,{}).get("path")!="":return _missing("result_face_checkbox_state_pixels_require_separate_registration")
	var player:=Scene.new()
	var result: Dictionary=player.configure_nodes(pack,selected.member,[offset],{offset:{"visible":true},check:{"role":"checkbox","displaystate":false,"activate":Callable(),"selected":false}})
	if not result.get("ok",false):player.free();return _missing("result_face_source_hierarchy_rejected",result)
	player.stop() # Retain serialized authored state; do not choose a clip/frame.
	var node: Variant=player.source_nodes.get(offset)
	var sprite: Variant=node.get_meta("source_sprite",null) if is_instance_valid(node) else null
	if not sprite is Sprite2D or sprite.texture!=image.texture or _model_seed(owner)!=seed:player.free();return _missing("result_face_current_pixels_or_owner_changed")
	if face.has_meta("original_result_back_writer") and face.get_meta("original_result_back_writer")!=get_instance_id():player.free();return _missing("result_face_other_writer_owns_receiver")
	var bridge:=Node2D.new()
	bridge.name="OriginalResultBackHost"
	bridge.add_child(player)
	owner.add_child(bridge)
	# Native back replaces the Face draw pass, below the existing clipped FX,
	# labels and RevealCard input. It is outside that portrait-fit clip so the
	# complete authored back extent is not cropped to a different host ratio.
	owner.move_child(bridge,owner.get_node("CardSurfaceClip").get_index())
	_bridge=bridge;_scene=player;_sprite=sprite;_face=weakref(face)
	_prior_face_active=face.original_back_receiver_active
	face.set_meta("original_result_back_writer",get_instance_id())
	face.original_back_receiver_active=true
	face.queue_redraw()
	var rim: Node=owner.get_node_or_null("MetalRim")
	if rim is CanvasItem:
		_rim=weakref(rim);_prior_rim_visible=rim.visible;rim.hide()
	var evidence: Dictionary=image.duplicate(true);evidence.erase("texture")
	_status={"ok":true,"phase":"back","source_id":role.source_id,"grade_id":role.grade_id,"operation":role.operation,"image":evidence,"registration":{"kind":"TWILIGHT_host_registration","actual_receiver":"same card.face rectangle centre","matrix":"inverse(card.global_transform) * face.global_transform * translation(face.size/2)","original_controller_recovered":false,"source_root_and_all_ancestors_preserved":true,"source_layout_scaled_to_host":false,"original_clip_or_callback_order_inferred":false,"input_owner":"existing RevealCard button"},"source_renderer_attached":true,"pixels_assigned":true,"source_animation_started":false,"game_state_written":false,"runtime_rendering_verified":false}
	_seed=seed;_cached=true
	_update_host_transform(owner,face)
	return _status.duplicate(true)

func receiver() -> Dictionary:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	if not _actual_owner(owner) or not is_instance_valid(_scene) or _scene.is_queued_for_deletion() or not is_instance_valid(_sprite):return _missing("result_face_actual_receiver_unavailable")
	if _model_seed(owner)!=_seed:clear();return _missing("result_face_owner_changed_requery_required")
	_update_host_transform(owner,owner.face)
	var result: Dictionary=_status.duplicate(true)
	result["player"]=_scene;result["source_sprite"]=_sprite;result["host_bridge"]=_bridge
	result["actual_record"]=owner.record.duplicate(true)
	result["host_transform"]=_bridge.transform
	result["actual_sprite_global_transform"]=_sprite.get_global_transform()
	return result

func _update_host_transform(owner: Control, face: Control) -> void:
	if not is_instance_valid(_bridge):return
	_bridge.transform=owner.get_global_transform().affine_inverse()*face.get_global_transform()*Transform2D(0.0,face.size*0.5)
	var rim: Object=_rim.get_ref() if _rim!=null else null
	if is_instance_valid(rim):rim.hide()

func clear() -> void:
	var face: Object=_face.get_ref() if _face!=null else null
	if is_instance_valid(face) and face.get_meta("original_result_back_writer",0)==get_instance_id():
		face.original_back_receiver_active=_prior_face_active
		face.remove_meta("original_result_back_writer");face.queue_redraw()
	var rim: Object=_rim.get_ref() if _rim!=null else null
	if is_instance_valid(rim) and not rim.visible:rim.visible=_prior_rim_visible
	_face=null;_rim=null;_sprite=null
	if is_instance_valid(_bridge) and not _bridge.is_queued_for_deletion():_bridge.hide();_bridge.queue_free()
	_bridge=null;_scene=null;_cached=false;_status.clear()

func _visibility_changed() -> void:
	var owner: Object=_owner.get_ref() if _owner!=null else null
	if _actual_owner(owner):refresh(owner)
	else:clear()

func close() -> void:
	clear()
	var owner: Object=_owner.get_ref() if _owner!=null else null
	if is_instance_valid(owner):
		if owner.tree_exiting.is_connected(close):owner.tree_exiting.disconnect(close)
		if owner.visibility_changed.is_connected(_visibility_changed):owner.visibility_changed.disconnect(_visibility_changed)
	_owner=null

static func _actual_owner(owner: Object) -> bool:
	if not owner is Control or not is_instance_valid(owner) or owner.is_queued_for_deletion() or not owner.is_inside_tree() or not owner.is_visible_in_tree():return false
	var script: Script=owner.get_script()
	var face: Variant=owner.get("face")
	return script!=null and script.resource_path==OWNER and face is Control and is_instance_valid(face) and face.get_parent()==owner.get_node_or_null("CardSurfaceClip")

static func _model_seed(owner: Control) -> int:
	var pack: RefCounted=owner.source_ui_pack
	return hash([owner.record,owner.source_result_operation,owner.waiting_for_press,owner.face.elapsed<0,owner.face.elapsed>=owner.face.duration,owner.face.get_instance_id(),pack.get_instance_id() if pack!=null else 0,pack.manifest_sha256 if pack!=null else "",ResourceLoader.exists(PROVIDER)])

static func _node_at(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset")==offset:return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary=_node_at(child,offset)
		if not found.is_empty():return found
	return {}

static func _missing(code: String, detail: Dictionary={}) -> Dictionary:
	return {"ok":false,"code":code,"detail":detail,"pixels_assigned":false,"runtime_rendering_verified":false}
