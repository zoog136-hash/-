extends RefCounted
## Prepare an actual original CSB at its owner's explicitly declared authored
## Sprite anchor. Attach/swap/detach and lifecycle belong to the calling renderer.
## This adapter adds no positioning, fitting, pixel lookup or playback policy.
const PACK_SCRIPT_PATH="res://scripts/ui/original_ui/source_pack.gd"
const RENDERER_SCRIPT_PATH="res://scripts/ui/original_ui/sprite_scene.gd"

static func prepare(descriptor: Dictionary) -> Dictionary:
	var registration: Variant=descriptor.get("registration")
	if not registration is Dictionary:return _fail("source_asset_scene_original_registration_required",["registration"])
	var host_receiver: RefCounted
	var host_proof: Dictionary={}
	if registration.get("kind")=="TWILIGHT_host_registration":
		var candidate: Variant=registration.get("receiver")
		if not candidate is RefCounted or not is_instance_valid(candidate) or candidate.get_script()==null or candidate.get_script().resource_path!="res://scripts/ui/original_ui/source_item_scene_receiver.gd":return _fail("source_asset_scene_typed_host_receiver_required")
		host_receiver=candidate
		host_proof=host_receiver.validate_descriptor(descriptor)
		if not host_proof.get("ok",false):return host_proof
	else:
		if registration.get("space")!="authored_sprite_anchor":return _fail("source_asset_scene_registration_space_unsupported",["registration.space=authored_sprite_anchor"])
		if typeof(registration.get("original_registration_confirmed"))!=TYPE_BOOL or registration.original_registration_confirmed!=true:return _fail("source_asset_scene_original_registration_pending",["registration.original_registration_confirmed=true"])
		if not registration.get("source_basis") is String or str(registration.source_basis).strip_edges().is_empty():return _fail("source_asset_scene_original_registration_basis_required",["registration.source_basis"])
	var pack: Variant=descriptor.get("pack")
	if not is_instance_valid(pack) or not pack is RefCounted:return _fail("source_asset_scene_open_source_pack_required",["pack"])
	var pack_script: Script=pack.get_script()
	if pack_script==null or pack_script.resource_path!=PACK_SCRIPT_PATH:return _fail("source_asset_scene_actual_source_pack_required")
	var manifest_pin: Variant=descriptor.get("manifest_sha256")
	var source_pin: Variant=descriptor.get("source_sha256")
	var member: Variant=descriptor.get("member")
	if not manifest_pin is String or manifest_pin.length()!=64 or pack.get("manifest_sha256")!=manifest_pin:return _fail("source_asset_scene_manifest_pin_mismatch",["manifest_sha256"])
	if not source_pin is String or source_pin.length()!=64 or not member is String or member.is_empty():return _fail("source_asset_scene_original_member_identity_required",["member","source_sha256"])
	var manifest: Variant=pack.get("manifest")
	if not manifest is Dictionary or manifest.get("files",{}).get(member,{}).get("sha256")!=source_pin:return _fail("source_asset_scene_source_pin_mismatch")
	var bindings: Variant=descriptor.get("bindings",{})
	if not bindings is Dictionary:return _fail("source_asset_scene_bindings_dictionary_required")
	var tree: Dictionary=pack.call("scene",member)
	if tree.is_empty() or tree.get("_source_sha256")!=source_pin:return _fail("source_asset_scene_loaded_original_scene_missing_or_mismatched")
	var root: Variant=tree.get("nodeTree")
	if not root is Dictionary or root.get("classname")!="Node":return _fail("source_asset_scene_original_root_contract_required",["identity Node root"])
	var options: Variant=root.get("options")
	if not options is Dictionary:return _fail("source_asset_scene_original_root_options_required")
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	if not _identity_root(widget):return _fail("source_asset_scene_nonidentity_root_additional_registration_required",["original root position0,size0,anchor0,scale1,rotation0,flipfalse"])
	var playback: Dictionary={"mode":"serialized_source_state","playing":false,"helper_seek_performed":false,"helper_play_performed":false,"repeat_inferred":false}
	if descriptor.has("playback"):
		var declared: Variant=descriptor.playback
		if not declared is Dictionary:return _fail("source_asset_scene_playback_declaration_required")
		if not declared.get("clip") is String or str(declared.clip).is_empty():return _fail("source_asset_scene_original_clip_required",["playback.clip"])
		if typeof(declared.get("repeat"))!=TYPE_BOOL:return _fail("source_asset_scene_repeat_declaration_required",["playback.repeat"])
		if typeof(declared.get("original_repeat_declared"))!=TYPE_BOOL or declared.original_repeat_declared!=true:return _fail("source_asset_scene_original_repeat_policy_pending",["playback.original_repeat_declared=true"])
		if typeof(declared.get("original_policy_confirmed"))!=TYPE_BOOL or declared.original_policy_confirmed!=true:return _fail("source_asset_scene_original_playback_policy_pending",["playback.original_policy_confirmed=true"])
		var clips: Array=[]
		for clip: Dictionary in tree.get("animationList",[]):
			if clip.get("name")==declared.clip:clips.append(clip)
		if clips.size()!=1:return _fail("source_asset_scene_original_clip_not_unique")
		playback=declared.duplicate(true)
		playback["mode"]="declared_original_clip"
		playback["source_clip"]=clips[0].duplicate(true)
		playback["helper_play_performed"]=true
		playback["repeat_inferred"]=false
	# Runtime load avoids a preload cycle when sprite_scene itself consumes
	# this adapter. It is the existing exact renderer, not another engine.
	var renderer_script: Script=load(RENDERER_SCRIPT_PATH)
	if renderer_script==null:return _fail("source_asset_scene_existing_renderer_unavailable")
	var player: Node2D=renderer_script.new() as Node2D
	if player==null:return _fail("source_asset_scene_existing_renderer_creation_failed")
	var configured: Dictionary=player.configure(pack,member,false,bindings.duplicate(true))
	if not configured.get("ok",false):
		player.free()
		return {"ok":false,"error":"source_asset_scene_strict_renderer_rejected","renderer_result":configured,"member":member}
	if not player.transform.is_equal_approx(Transform2D.IDENTITY):
		player.free()
		return _fail("source_asset_scene_renderer_wrapper_not_identity")
	if descriptor.has("playback"):
		var started: Dictionary=player.play(playback.clip,playback.repeat)
		if not started.get("ok",false):
			player.free()
			return {"ok":false,"error":"source_asset_scene_original_playback_rejected","renderer_result":started,"member":member}
		playback["playing"]=true
	else:
		# Do not seek frame zero or choose an animation when the owner has
		# supplied no policy. Existing strict loader initialization is retained.
		player.stop()
	if host_receiver!=null:
		host_proof=host_receiver.validate_descriptor(descriptor)
		if not host_proof.get("ok",false):player.free();return host_proof
	return {"ok":true,"player":player,"member":member,"host_registration_proof":host_proof,"manifest_sha256":manifest_pin,"source_sha256":source_pin,"registration":registration.duplicate(true),"playback":playback,"renderer_result":configured,"unparented":player.get_parent()==null,"wrapper_identity":true,"original_root_options":options.duplicate(true),"root_transform_modified":false,"layout_inferred":false,"runtime_rendering_verified":false}

static func _identity_root(widget: Dictionary) -> bool:
	return _vector(widget.get("position"),Vector2.ZERO) and _vector(widget.get("size"),Vector2.ZERO) and _vector(widget.get("anchorPoint"),Vector2.ZERO) and _vector(widget.get("scale"),Vector2.ONE) and _vector(widget.get("rotationSkew"),Vector2.ZERO) and widget.has("flipX") and widget.has("flipY") and not bool(widget.flipX) and not bool(widget.flipY)

static func _vector(value: Variant, expected: Vector2) -> bool:
	if not value is Array or value.size()!=2:return false
	for component: Variant in value:
		if typeof(component) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(component)):return false
	return Vector2(float(value[0]),float(value[1]))==expected

static func _fail(error: String, pending_fields: Array=[]) -> Dictionary:
	return {"ok":false,"error":error,"pending_contract_fields":pending_fields}
