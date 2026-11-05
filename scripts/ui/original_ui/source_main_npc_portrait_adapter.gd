extends RefCounted
## UI-owned adapter ABI: authoritative NPC context -> existing portrait owner.
## No L1J/mobile identity join, asset lookup or registration policy is inferred.
const MEMBER = "UI/NpcDialogue/NpcDialogue_All.csb"
const SHA256 = "f27872592f0f7f6b74b81308bc64f98f4bc337beff60c030f4f1ac060aed4ccf"
const TARGET = 4912
const ROLE = "NpcClass.IllustAssetID"
var _pack: RefCounted
var _context_provider: Callable
var _image_provider: Callable

func configure(pack: RefCounted, context_provider: Callable, image_provider: Callable) -> Dictionary:
	_pack = pack
	_context_provider = context_provider
	_image_provider = image_provider
	if pack == null or pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","") != SHA256:
		return _fail("source_npc_portrait_original_identity_mismatch")
	if not context_provider.is_valid(): return _fail("source_npc_portrait_authoritative_context_provider_required")
	if not image_provider.is_valid(): return _fail("source_npc_portrait_existing_image_provider_required")
	return {"ok":true,"adapter_abi":"twilight-npc-portrait-v1","original_identity_mapping_inferred":false}

func resolve(owner: Control, resolved: Dictionary) -> Dictionary:
	if not is_instance_valid(owner) or owner.is_queued_for_deletion(): return _fail("source_npc_portrait_current_dialogue_owner_required")
	if not resolved.get("ok",false): return _fail("source_npc_portrait_successful_dialogue_required")
	if _pack == null or _pack.manifest.get("files",{}).get(MEMBER,{}).get("sha256","") != SHA256:
		return _fail("source_npc_portrait_original_identity_mismatch")
	if not _context_provider.is_valid() or not _image_provider.is_valid(): return _fail("source_npc_portrait_providers_required")
	var npc_id: Variant = owner.get("npc_id")
	var node_id: Variant = owner.get("current_node")
	if not npc_id is String or npc_id.is_empty() or not node_id is String or node_id.is_empty():
		return _fail("source_npc_portrait_actual_dialogue_identity_required")
	if resolved.get("npc_id")!=npc_id or resolved.get("node_id")!=node_id or owner.get("source_dialogue_model")!=resolved:return _fail("source_npc_portrait_current_resolved_identity_mismatch")
	var context: Variant = _context_provider.call(npc_id,node_id)
	if not context is Dictionary or context.get("ok") != true: return _blocked("source_npc_portrait_authoritative_context_unavailable",context)
	if context.get("npc_id") != npc_id or context.get("node_id") != node_id:
		return _blocked("source_npc_portrait_context_identity_mismatch",context)
	if typeof(context.get("npc_class_id")) != TYPE_INT or context["npc_class_id"] <= 0:
		return _blocked("source_npc_portrait_authoritative_mobile_npc_class_id_required",context)
	if not context.get("source_basis") is Dictionary or context["source_basis"].is_empty():
		return _blocked("source_npc_portrait_authoritative_source_basis_required",context)
	var scene_api: Script = load("res://scripts/ui/original_ui/sprite_scene.gd")
	var slot: Dictionary = scene_api.external_scene_slot_contract(_pack,MEMBER,TARGET)
	if not slot.get("ok",false): return _blocked("source_npc_portrait_declared_original_slot_required",slot)
	if slot.get("source_sha256") != SHA256: return _blocked("source_npc_portrait_slot_identity_mismatch",slot)
	# The original preview sprite must also be present in the permitted runtime scope.
	var tree: Dictionary = _pack.scene(MEMBER)
	if _find(tree.get("nodeTree",{}),TARGET).is_empty(): return _fail("source_npc_portrait_target_not_in_active_scope")
	var info: Variant = _image_provider.call(context.duplicate(true),slot.duplicate(true))
	if not info is Dictionary: return _fail("source_npc_portrait_owner_result_required")
	if typeof(info.get("npc_class_id")) != TYPE_INT or info["npc_class_id"] != context["npc_class_id"] or info.get("role") != ROLE:
		return _blocked("source_npc_portrait_image_identity_and_role_echo_required",info)
	if info.get("reason") == "unsupported_csb" or info.has("source_scene_descriptor"):
		return _blocked("source_npc_portrait_csb_original_registration_pending",info)
	if info.get("route") != "source523_images" or info.get("status") != "original_linked" or info.get("original_bytes_unchanged") != true or not info.get("texture") is Texture2D:
		return _blocked("source_npc_portrait_existing_original_texture_unavailable",info)
	if info["texture"] is AnimatedTexture: return _blocked("source_npc_portrait_static_original_texture_required",info)
	if not info.get("provenance") is Dictionary or info["provenance"].is_empty():
		return _blocked("source_npc_portrait_original_provenance_required",info)
	var pixels: Dictionary = info.duplicate(true)
	pixels["ok"] = true
	pixels["status"] = str(info.get("source_status",""))
	return {"ok":true,"adapter_abi":"twilight-npc-portrait-v1","npc_id":npc_id,"node_id":node_id,"npc_class_id":context["npc_class_id"],"role":ROLE,"source_basis":context["source_basis"].duplicate(true),"owner_result":pixels,"slot_contract":slot,"member":MEMBER,"source_sha256":SHA256,"node_offset":TARGET,"original_identity_mapping_inferred":false,"texture_assigned":false}

static func _find(node: Dictionary, offset: int) -> Dictionary:
	if node.get("_offset") == offset: return node
	for child: Dictionary in node.get("children",[]):
		var found: Dictionary = _find(child,offset)
		if not found.is_empty(): return found
	return {}

static func _blocked(code: String, detail: Variant) -> Dictionary:
	if detail is Dictionary:
		detail=detail.duplicate(true)
		detail.erase("texture")
		detail.erase("owner_result")
		detail.erase("source_scene_descriptor")
	return {"ok":false,"code":code,"optional_portrait":true,"blocked_scope":"npc_portrait_only","provider_result":detail}

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"optional_portrait":true,"blocked_scope":"npc_portrait_only"}
