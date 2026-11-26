extends RefCounted
## The image owner retains canonical identity, scene pack and registration.
## Native UI forwards only that owner descriptor to its existing source player.
## The same Common_Slot Sprite accepts a static image or the original animated
## icon. The provider verifies its source slot and declared clip before mounting.
static func show_item(player: Node2D, offset: int, info: Dictionary, hud: Node) -> bool:
	var owner: Dictionary
	if info.get("reason") == "unsupported_csb":
		if not is_instance_valid(hud): return false
		var slot: Dictionary = player.external_scene_slot_contract(player.source_pack, player.source_member, offset)
		owner = request(hud, info, {"source_slot_contract":slot})
	elif info.get("texture") is Texture2D:
		owner = info.duplicate()
		owner["ok"] = true
	else:
		return false
	return owner.get("ok", false) and player.set_bound_source_visual_result(offset, owner).get("ok", false) and player.set_bound_visible(offset, true).get("ok", false)

static func request(hud: Node, info: Dictionary, context: Dictionary) -> Dictionary:
	if info.get("route")!="source523_images" or info.get("reason")!="unsupported_csb":return {"ok":false,"code":"source_native_icon_scene_identity_required"}
	var slot: Variant=context.get("source_slot_contract")
	if not slot is Dictionary or not slot.get("ok",false):return {"ok":false,"code":"source_native_icon_scene_original_slot_required"}
	var provider: Variant=hud.get("_original_icon_scene_provider")
	if not provider is Callable or not provider.is_valid():return {"ok":false,"code":"source_native_icon_scene_provider_required","owner_result":info,"slot_contract":slot}
	var supplied: Variant=provider.call(info.duplicate(true),context.duplicate(true))
	if not supplied is Dictionary or not supplied.get("ok",false) or not supplied.get("descriptor") is Dictionary:return {"ok":false,"code":"source_native_icon_scene_descriptor_required","provider_result":supplied}
	var canonical: Variant=info.get("provenance")
	# Compare the image owner's complete canonical path literally. No prefix
	# guessing, numeric-ID join or new identity interpreter is added here.
	if not canonical is Dictionary or canonical.get("asset_type_id")!=101 or not canonical.get("path") is String or supplied.descriptor.get("member")!=canonical.path:return {"ok":false,"code":"source_native_icon_scene_canonical_member_mismatch"}
	return {"ok":true,"source_scene_descriptor":supplied.descriptor,"owner_result":info,"source_slot_contract":slot}
