extends RefCounted

const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const SAVE_TRIM = preload("res://scripts/loot/save_provenance_trim.gd")
const RUNE_KEY := "rune_slot2_unlocked"
const RUNE_POUCH := 146422
const RUNE_LEVEL := 88
const RUNE_SLOT_ID := 20
const CHARACTER_SEAL := 1185


static func rune_pouch(definition: Dictionary) -> bool:
	if not _self_item(definition, RUNE_POUCH, 10352, RUNE_LEVEL):
		return false
	if not _item_bonus(definition, 228452, 726522, 4722, "LimitEquipSlotID", 2):
		return false
	var rule: Dictionary = SOURCE.row("LimitEquipSlot", 2)
	return rule.get("EquipSlotID") == RUNE_SLOT_ID and rule.get("MaxLimitEquipCount") == 2 \
		and rule.get("LimitEquipSlotOpenType") == 3 and rule.get("CharacterMinLevel") == 0


static func character_seal(definition: Dictionary) -> bool:
	return _self_item(definition, CHARACTER_SEAL, 88, 0) \
		and _item_bonus(definition, 3729, 7006, 172, "SlotIncreaseAmount", 1)


static func _self_item(definition: Dictionary, id: int, category: int, min_level: int) -> bool:
	var raw: Dictionary = definition.get("original_item", {})
	return raw.get("ID") == id and raw.get("CategoryID") == category and raw.get("TestItem") == false \
		and raw.get("LevelLimitMin") == min_level and raw.get("LevelLimitMax") == 0 \
		and raw.get("MaxLevelLimitMin") == 0 and raw.get("MaxLevelLimitMax") == 0 \
		and raw.get("TargettingTypeID") == 1 and raw.get("ServiceRegionCode") == "" \
		and raw.get("CanUseWhenInvisible") == true


static func _item_bonus(definition: Dictionary, link_id: int, bonus_id: int, type_id: int, type_name: String, value: int) -> bool:
	var rows: Array = definition.get("item_bonus", [])
	if rows.size() != 1:
		return false
	var link: Dictionary = rows[0]
	var bonus: Dictionary = link.get("bonus", {})
	var kind: Dictionary = link.get("bonus_type", {})
	return link.get("ID") == link_id and link.get("IsPossession") == false and bonus.get("ID") == bonus_id \
		and bonus.get("Value") == value and kind.get("ID") == type_id and kind.get("Name") == type_name \
		and link.get("unit", {}).get("ID") == 1 and link.get("unit", {}).get("Name") == "Value" \
		and bonus.get("BonusApplicationTypeID") == 0 and bonus.get("BonusApplicationTargetID") == 0


static func exact_rune(record: Dictionary) -> bool:
	if record.get("source_m_native_item") != true or record.get("source_projection") != "current523_original_typed_game_dto_v1":
		return false
	# Owned gear on disk and catalog rows may keep this field in their exact
	# registered template. The load guard runs before full-save expansion.
	var slots: Variant = FIELDS.field_view(record, "source_equip_slot_ids", [])
	if slots is not Array:
		return false
	if not slots.is_empty():
		return slots.size() == 1 and slots[0] == RUNE_SLOT_ID
	# The account chooser can read an equipped character before Main has
	# attached a template store. Use the original relationship in that case.
	if not (FIELDS.lazy(record) or record.get(SAVE_TRIM.SAVED_TEMPLATE) == true):
		return false
	var archive: Variant = record.get("source_definition_archive", {})
	if archive is not Dictionary or archive.get("source_sha256") != SOURCE.SOURCE_SHA \
			or SOURCE.identity().get("source_sha256") != SOURCE.SOURCE_SHA:
		return false
	var item_id: int = int(record.get("source_item_class_id", 0))
	if item_id <= 0:
		return false
	var links: Array[Dictionary] = SOURCE.related("ItemEquipSlot", "ItemClassID", item_id)
	return links.size() == 1 and links[0].get("EquipSlotID") == RUNE_SLOT_ID


static func save_problem(unlocked: Variant, equipment: Variant, instances: Variant) -> String:
	if unlocked is not bool:
		return "룬 장착 칸 저장 형식 오류 · 기존 저장 보존"
	if equipment is not Dictionary:
		return ""
	var second: Variant = equipment.get("rune2", {})
	if second is not Dictionary:
		return "두 번째 룬 장착 기록 형식 오류 · 기존 저장 보존"
	if second.is_empty():
		return ""
	var uid: Variant = second.get("instance_id")
	var primary: Variant = equipment.get("rune", {})
	if not unlocked or uid is not String or uid.is_empty() or not exact_rune(second) \
			or (primary is Dictionary and primary.get("instance_id") == uid):
		return "두 번째 룬 칸 해금·장착 식별자를 확인할 수 없습니다 · 기존 저장 보존"
	if primary is Dictionary and exact_rune(primary) and primary.get("source_item_class_id") == second.get("source_item_class_id"):
		return "같은 원본 룬의 중복 장착 기록 확인 필요 · 기존 저장 보존"
	var instance: Variant = instances.get(uid) if instances is Dictionary else null
	if instance is not Dictionary or instance.get("name") != second.get("name"):
		return "두 번째 룬의 원본 실물을 확인할 수 없습니다 · 기존 저장 보존"
	var record: Variant = instance.get("record", {})
	if record is not Dictionary or not exact_rune(record) or record.get("source_item_class_id") != second.get("source_item_class_id"):
		return "두 번째 룬 원본 번호가 장착과 보유품에서 다릅니다 · 기존 저장 보존"
	return ""
