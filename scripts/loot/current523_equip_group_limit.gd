extends RefCounted
## Original 523 per-slot duplication limits on equipping (EquipSlotConfig):
## MaxDuplicationPerItemClassID and MaxDuplicationPerEquipGroup of the item's
## source EquipSlot (ServerLimitSetID 0), against the other worn items of the
## same TWILIGHT slot family. An item's groups are its EquipGroupID ItemBonus
## rows (projected as source_equip_group_ids); two items share a group when any
## of their group IDs is equal (e.g. Ear: one item per group, Finger: two).
## Only new equips are checked; an already worn combination is not unequipped.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const FAMILIES: Dictionary = {"earring":["earring1","earring2"],"ring":["ring1","ring2"],"seal":["seal1","seal2"]}

static func _whole(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) else -1

## The single ServerLimitSetID 0 config row of the record's one source slot.
static func slot_config(record: Dictionary) -> Dictionary:
	var ids: Array = record.get("source_equip_slot_ids",[])
	if not record.get("source_m_native_item",false) or ids.size()!=1 or _whole(ids[0])<=0: return {}
	var found: Array[Dictionary] = []
	for row: Dictionary in SOURCE.related("EquipSlotConfig","EquipSlotID",_whole(ids[0])):
		if _whole(row.get("ServerLimitSetID"))==0: found.append(row)
	if found.size()!=1 or _whole(found[0].get("MaxDuplicationPerItemClassID"))<=0 or _whole(found[0].get("MaxDuplicationPerEquipGroup"))<=0: return {}
	return found[0]

static func groups(record: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for value: Variant in record.get("source_equip_group_ids",[]):
		if _whole(value)>0 and not out.has(_whole(value)): out.append(_whole(value))
	return out

## "" when equipping `record` into `target_slot` keeps the source limits;
## otherwise the refusal message. `worn` maps TWILIGHT slot -> worn record.
static func reason(record: Dictionary, target_slot: String, worn: Dictionary) -> String:
	record = FIELDS.full(record)
	var config: Dictionary = slot_config(record)
	if config.is_empty(): return ""
	var family: Array = []
	for key: String in FAMILIES:
		if target_slot in FAMILIES[key]: family = FAMILIES[key]
	if family.is_empty(): return ""
	var item_id: int = _whole(record.get("source_item_class_id"))
	var own: Array[int] = groups(record)
	var same_item: int = 1
	var same_group: int = 1
	var conflict: String = ""
	for slot: String in family:
		if slot==target_slot: continue
		var other: Variant = worn.get(slot,{})
		if not other is Dictionary or (other as Dictionary).is_empty() or not other.get("source_m_native_item",false): continue
		other = FIELDS.full(other)
		if _whole(other.get("source_item_class_id"))==item_id:
			same_item += 1; conflict = str(other.get("source_display_name",other.get("name","")))
		for group: int in groups(other):
			if own.has(group):
				same_group += 1; conflict = str(other.get("source_display_name",other.get("name",""))); break
	if same_item>_whole(config.MaxDuplicationPerItemClassID):
		return "같은 장비는 %d개까지만 착용할 수 있습니다 (원본 장착 제한 · %s)" % [_whole(config.MaxDuplicationPerItemClassID),conflict]
	if same_group>_whole(config.MaxDuplicationPerEquipGroup):
		return "같은 계열 장비는 %d개까지만 착용할 수 있습니다 (원본 장착 그룹 제한 · %s)" % [_whole(config.MaxDuplicationPerEquipGroup),conflict]
	return ""
