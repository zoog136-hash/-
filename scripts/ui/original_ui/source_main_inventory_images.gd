extends RefCounted
## UI-only bridge to the existing PR270 record/image presentation APIs.
## No ItemClass/Icon/Asset joins, exclusions, artwork or ownership rules here.
const OWNER_API="res://scripts/ui/source523_image_assets.gd"

static func resolve_owned(hud: Node, entry: Dictionary, native_context: Dictionary={}) -> Dictionary:
	if not is_instance_valid(hud):return _fail("source_inventory_image_hud_unavailable")
	var bag: Variant=hud.get("lineage_inventory_ui")
	if not is_instance_valid(bag) or not bag.has_method("_item_visual_record") or not bag.has_method("_find_item_record"):return _fail("source_inventory_existing_visual_record_api_required")
	var reference: Variant=entry.get("reference")
	if not reference is String or reference.is_empty():return _fail("source_inventory_exact_owned_image_reference_required")
	var fallback: Variant=entry.get("record")
	if not fallback is Dictionary:fallback=bag.call("_find_item_record",reference)
	if not fallback is Dictionary:return _fail("source_inventory_existing_item_record_required")
	# Exact public af2051a6 ABI. The owner retains a physical reward record
	# when appropriate; the UI never reconstructs it or substitutes an alias.
	var record: Variant=bag.call("_item_visual_record",reference,fallback)
	if not record is Dictionary:return _fail("source_inventory_existing_visual_record_invalid")
	if not ResourceLoader.exists(OWNER_API):return _fail("source_inventory_existing_image_owner_unavailable")
	var api: Script=load(OWNER_API)
	if api==null:return _fail("source_inventory_existing_image_owner_unavailable")
	var info: Dictionary=api.describe_item(record,str(entry.get("name","")))
	if info.get("reason")=="unsupported_csb":
		var native: Dictionary=preload("res://scripts/ui/original_ui/source_native_icon_scenes.gd").request(hud,info,native_context)
		if not native.get("ok",false):
			# Identity only, never an accepted image/scene. The actual inventory
			# view may prepare a hidden original receiver before requesting again.
			native["pending_native_item_scene"]=true
			native["image_owner_info"]=info.duplicate(true)
			native["current_raw_record"]=record.duplicate(true)
		return native
	# This is only normalization of the owner's successful descriptor for the
	# shared original Sprite upload path. No old image path or sample fallback.
	if info.get("route")!="source523_images" or info.get("status")!="original_linked" or info.get("original_bytes_unchanged")!=true or not info.get("texture") is Texture2D:
		return {"ok":false,"code":"source_inventory_owned_original_image_unavailable","reference":reference,"owner_result":info}
	var result: Dictionary=info.duplicate(true)
	result["ok"]=true
	result["status"]=str(info.get("source_status",""))
	return result

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
