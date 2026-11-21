extends RefCounted
## A tap on an original reward slot (Quest_Slot_Set / Common_Slot "Btn" in
## the 퀘스트, 미션, 지배석 퀘스트 and 몬스터 도감 windows) opens the original
## item information popup (source_main_item_tooltip, ToolTip_CommonType) of
## that reward, as a bag item does. A second tap on the same reward closes it.
## Information only: nothing here changes an item or a reward.
const IDENTITY=preload("res://scripts/ui/source523_item_identity.gd")

## The catalog record of original ItemClass `item_class_id` ({} when the
## catalog has none).
static func record_of(world: Object, item_class_id: int) -> Dictionary:
	if world==null or item_class_id<=0 or not world.has_method("_catalog_item_from_source_id"):return {}
	var record: Variant=world.call("_catalog_item_from_source_id","m523:item:%d" % item_class_id)
	return record if record is Dictionary else {}

## Opens (or, for the reward already shown, closes) the popup of ItemClass
## `item_class_id` through the HUD's original controller.
static func toggle(hud: Object, item_class_id: int) -> Dictionary:
	if hud==null or item_class_id<=0:return {"ok":false,"handled":false,"code":"reward_item_unknown"}
	var controller: Variant=hud.get("original_main_ui_controller")
	if not is_instance_valid(controller) or not controller.has_method("try_open_item_tooltip"):return {"ok":false,"handled":false,"code":"reward_item_popup_unavailable"}
	var record: Dictionary=record_of(hud.get_parent(),item_class_id)
	var reference: String=str(record.get("name","")) if not record.is_empty() else "m523:item:%d" % item_class_id
	var popup: Variant=controller.call("item_tooltip") if controller.has_method("item_tooltip") else null
	if controller.has_method("item_tooltip_is_open") and controller.call("item_tooltip_is_open") and popup!=null and str(popup.get("reference"))==reference:
		controller.call("close_item_tooltip")
		return {"ok":true,"handled":true,"closed":true,"item_class_id":item_class_id}
	var title: String=IDENTITY.display_name(record,reference) if not record.is_empty() else IDENTITY.original_name(item_class_id)
	if title.is_empty():return {"ok":false,"handled":false,"code":"reward_item_name_unknown","item_class_id":item_class_id}
	var opened: Variant=controller.call("try_open_item_tooltip",reference,title,item_class_id,IDENTITY.grade_id(record,reference) if not record.is_empty() else 0,record)
	return opened if opened is Dictionary else {"ok":false,"handled":false,"code":"reward_item_popup_failed"}
