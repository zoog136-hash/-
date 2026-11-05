extends RefCounted
## Read-only variant definition lookup. Does not register or grant ownership.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")

static func missing_variant(registered: Dictionary,source_id: String,registration: Dictionary) -> Dictionary:
	# An existing explicit record, including a conflict/empty entry, wins. This
	# only resolves the qualified namespace emitted by the existing factory.
	if registered.has(source_id) or source_id.length()>96:return {}
	var parts: PackedStringArray=source_id.split(":")
	if parts.size()!=5 or parts[0]!="m523" or parts[1]!="item" or parts[3]!="bless" or parts[4] not in ["2","3"] or not parts[2].is_valid_int():return {}
	var item_id: int=int(parts[2]);var bless: int=int(parts[4])
	if item_id<=0 or str(item_id)!=parts[2]:return {}
	var admitted: Variant=registration.get("registered_definition_ids")
	var pending: Variant=registration.get("pending")
	if not admitted is Array or not pending is Dictionary:return {}
	if registration.get("mode")!="current_original_native_projection" or registration.get("source_definition_archive")!=SOURCE.identity() or not admitted.has(str(item_id)) or pending.has(str(item_id)):return {}
	var base_id: String="m523:item:"+parts[2]
	var value: Variant=registered.get(base_id)
	if not value is Dictionary:return {}
	var base: Dictionary=value
	if base.get("sourceId")!=base_id or base.get("source_item_class_id")!=item_id or base.get("source_bless_raw")!=1 or D.equipment(base):return {}
	if base.get("source_projection")!="current523_original_typed_game_dto_v1" or base.get("source_definition_archive")!=SOURCE.identity():return {}
	var definition: Dictionary=D.current_original_definition(base)
	var original: Dictionary=definition.get("original_item",{})
	if base.get("source_original_item")!=original or original.get("ID")!=item_id or original.get("TestItem")!=false or not SOURCE.declared_exclusion("ItemClass",original).is_empty():return {}
	var code: Dictionary=SOURCE.row("ItemBlessCode",bless)
	if code.get("ID")!=bless or not SOURCE.declared_exclusion("ItemBlessCode",code).is_empty():return {}
	var variant: Dictionary=D.variant_item(base,bless)
	if variant.get("sourceId")!=source_id or variant.get("source_bless_raw")!=bless or variant.get("source_original_item")!=original:return {}
	return variant
