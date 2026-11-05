extends RefCounted
## Reuse PR270's actual item/skill image APIs. Native UI owns no identity join.
const ITEM_API="res://scripts/ui/source523_image_assets.gd"
const SKILL_API="res://scripts/ui/source523_skill_buff_images.gd"

static func resolve(hud: Node, row: Dictionary, _context: Dictionary={}) -> Dictionary:
	if not is_instance_valid(hud):return _fail("source_quickslot_image_hud_unavailable")
	var world: Node=hud.get_parent()
	var entry: Variant=row.get("entry")
	if world==null or not entry is Dictionary or entry.is_empty():return _fail("source_quickslot_existing_entry_required")
	var id: String=str(entry.get("id",""))
	var info: Dictionary
	if entry.get("kind")=="item":
		var bag: Variant=hud.get("lineage_inventory_ui")
		if not is_instance_valid(bag) or not bag.has_method("_find_item_record") or not ResourceLoader.exists(ITEM_API):return _fail("source_quickslot_item_image_owner_required")
		var record: Variant=bag.call("_find_item_record",id)
		if not record is Dictionary or record.is_empty():return _fail("source_quickslot_existing_item_record_required")
		var api: Script=load(ITEM_API)
		info=api.describe_item(record,id)
	elif entry.get("kind")=="skill":
		if not world.has_method("_skill_record") or not ResourceLoader.exists(SKILL_API):return _fail("source_quickslot_skill_image_owner_required")
		var record: Variant=world.call("_skill_record",str(entry.get("skill_id",id)))
		if not record is Dictionary or record.is_empty():return _fail("source_quickslot_existing_skill_record_required")
		var api: Script=load(SKILL_API)
		# Public 46921c04: the existing producer owns guardian identity and the
		# single current-level spell relation. Never pass it through host lm_*.
		if record.get("origin")=="TWILIGHT_GUARDIAN523":
			info=api.describe_guardian_skill(record,world.get("growth"),"IconID")
		else:info=api.describe_skill(record,"IconID")
	else:return _fail("source_quickslot_entry_kind_not_connected")
	if info.get("route")!="source523_images" or info.get("status")!="original_linked" or info.get("original_bytes_unchanged")!=true or not info.get("texture") is Texture2D:
		return {"ok":false,"code":"source_quickslot_original_image_unavailable","owner_result":info,"visible_index":row.get("visible_index")}
	var result: Dictionary=info.duplicate(true)
	result["ok"]=true
	result["status"]=str(info.get("source_status",""))
	return result

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
