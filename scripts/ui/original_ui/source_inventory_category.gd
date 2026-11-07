extends RefCounted
## Consume the native item's existing typed projection. UI grouping does not
## grant equipment/use eligibility and does not infer a category from a name.
static func describe(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true:return {"handled":false}
	var status: Variant=record.get("source_equipment_status")
	var slot: Variant=record.get("slot")
	if not status is String or not slot is String:return _unknown("native_inventory_category_projection_required")
	if status in ["mapped","unsupported_source_slot","ambiguous_source_equip_slots"]:
		return {"handled":true,"ok":true,"category":"장비","basis":"existing native projection has source equip-slot relationships","equipment_status":status,"activation_allowed_by_ui":false}
	if status!="no_source_equip_slot":return _unknown("native_inventory_equipment_status_unrecognized")
	if slot=="consumable":return {"handled":true,"ok":true,"category":"소모품","basis":"existing native projection consumable slot","activation_allowed_by_ui":false}
	if slot in ["currency","material"]:return {"handled":true,"ok":true,"category":"기타","basis":"existing native projection non-equipment/non-consumable slot","activation_allowed_by_ui":false}
	return _unknown("native_inventory_projected_slot_unrecognized")

static func _unknown(code: String) -> Dictionary:
	# The All tab still shows the owned item. Unknown source classification
	# is not silently turned into Other or hidden from the entire inventory.
	return {"handled":true,"ok":false,"code":code,"available_in_all_tab":true}
