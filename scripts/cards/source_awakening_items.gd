extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## New, source-proven acquisition only. Never backfill legacy name-only stacks.
const IDS: Array[int]=[75184,75194,95624,118992,243043,346901]
static func recognized(record: Dictionary) -> bool:
	var id: Variant=record.get("source_item_class_id",0)
	if preload("res://scripts/cards/native_awakening_supply.gd").exact(record,int(id)):return true
	if preload("res://scripts/cards/native_relic_unlock_item.gd").exact(record):return not str(record.get("name","")).is_empty()
	if preload("res://scripts/cards/native_relic_reward_box.gd").recognized(record):return true
	if preload("res://scripts/cards/native_card_acquisition.gd").recognized(record):return true
	return (id is int or id is float) and is_finite(float(id)) and float(id)==floorf(float(id)) and int(id) in IDS and record.get("source","")=="lineagem_base508" and record.get("source_snapshot","")=="base508" and record.get("sourceId","")=="m508:item:"+str(int(id)) and not str(record.get("name","")).is_empty()
static func prepare_pickup(drop: Dictionary,instances: Dictionary,next_id: int) -> Dictionary:
	var result: Dictionary={"item_instances":instances,"next_item_instance_id":next_id,"created":0}
	var typed: Dictionary=preload("res://scripts/cards/native_awakening_supply.gd").prepare_pickup(drop,instances,next_id)
	if int(typed.created)>0:return typed
	if drop.has("physical_item") or not drop.get("item_record") is Dictionary:return result
	var record: Dictionary=drop.item_record
	if not recognized(record) or record.name!=drop.get("item_name",""):return result
	if preload("res://scripts/cards/native_card_acquisition.gd").exact(record,3252):
		return preload("res://scripts/cards/native_card_acquisition.gd").prepare_coin_pickup(drop,instances,next_id)
	var count: Variant=drop.get("quantity",0)
	if not (count is int or count is float) or not is_finite(float(count)) or float(count)!=floorf(float(count)) or int(count)<1 or int(count)>10000:return result
	var physicals: Dictionary=instances.duplicate(true)
	var candidate: int=maxi(1,next_id)
	for index: int in range(int(count)):
		while physicals.has(str(candidate)):candidate+=1
		physicals[str(candidate)]={"name":str(record.name),"level":0,"record":record.duplicate(true)}
		candidate+=1
	return {"item_instances":physicals,"next_item_instance_id":candidate,"created":int(count)}

static func stackable_book(record: Dictionary) -> bool:
	return recognized(record) and int(record.source_item_class_id) not in [346901,365748,346921,365758,3252,370562]

static func storage_allowed(item_name: String,record: Dictionary,instances: Dictionary) -> bool:
	for physical: Variant in instances.values():
		if physical is Dictionary and physical.get("name")==item_name and physical.has("source_native_stack_receipt") and NATIVE_FIELDS.full(physical.get("source_native_stack_receipt",{})).get("source_original_item",{}).get("IsStorable")!=true:return false # Metadata only; the selected whole-quantity owner still authorizes the actual move.
	if not _record_storage_allowed(record):return false
	for entry: Variant in instances.values():
		if entry is Dictionary and entry.get("name","")==item_name and entry.get("record") is Dictionary and not _record_storage_allowed(entry.record):return false
	return true

static func has_physical_item(item_name: String,instances: Dictionary) -> bool:
	for entry: Variant in instances.values():
		if entry is Dictionary and entry.get("name","")==item_name and entry.get("record") is Dictionary and (entry.has("source_native_stack_receipt") or recognized(entry.record)):return true
	return false

static func _record_storage_allowed(record: Dictionary) -> bool:
	if not recognized(record):return true
	if record.has("storable"):return record.storable!=false
	var source: Variant=record.get("source_item",{})
	return not source is Dictionary or source.get("IsStorable",true)!=false

static func install_drop_definitions(catalog: Dictionary,loot: Dictionary) -> void:
	# Add identity definitions only: no loot rate, floor spawn or ownership grant.
	if not loot.get("by_name") is Dictionary:return
	for record: Dictionary in catalog.get("아이템",[]):
		if recognized(record) and not loot.by_name.has(str(record.name)):
			loot.by_name[str(record.name)]=record
