extends RefCounted
## Permanent hidden source buffs. Each permits auto registration of one
## ItemClass. The normal potion owner still calculates healing and cooldowns.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SAVE_KEY := "eva_auto_potion_unlocks523"
const WHISPER := 146552
const VOW := 200753
const ADVANCED_POTION := 237
const GREATER_POTION := 236
const ADVANCED_BIT := 1
const GREATER_BIT := 2
const ALL_BITS := ADVANCED_BIT | GREATER_BIT
const ITEMS := {
	WHISPER: {"level":88,"buff":59812,"potion":ADVANCED_POTION},
	VOW: {"level":91,"buff":73838,"potion":GREATER_POTION},
}


static func valid_unlocks(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and value >= 0 and value <= ALL_BITS and value == floorf(value)


static func registration_bit(potion: int) -> int:
	match potion:
		ADVANCED_POTION: return ADVANCED_BIT
		GREATER_POTION: return GREATER_BIT
	return 0


static func required_item_name(potion: int) -> String:
	return "에바의 속삭임" if potion == ADVANCED_POTION else "에바의 서약"


static func potion_name(potion: int) -> String:
	return "고급 체력 회복제 (각인)" if potion == ADVANCED_POTION else "강력 체력 회복제 (각인)"


static func registration_target(item: int, definition: Dictionary) -> int:
	var rule: Dictionary = ITEMS.get(item, {})
	if rule.is_empty(): return 0
	var raw: Dictionary = definition.get("original_item", {})
	if raw.get("ID") != item or raw.get("CategoryID") != 3 or raw.get("TargettingTypeID") != 1 \
			or raw.get("TestItem") != false or raw.get("ServiceRegionCode") != "" or raw.get("CanUseWhenInvisible") != true \
			or raw.get("LevelLimitMin") != rule.level or raw.get("LevelLimitMax") != 0 \
			or raw.get("MaxLevelLimitMin") != 0 or raw.get("MaxLevelLimitMax") != 0:
		return 0
	var expected: Dictionary = {78:rule.buff, 107:751, 4962:1} # BuffClassID, consume sprite, infinite duration.
	var bonuses: Array = definition.get("item_bonus", [])
	if bonuses.size() != expected.size(): return 0
	for link: Dictionary in bonuses:
		var bonus: Dictionary = link.get("bonus", {})
		var kind: int = int(bonus.get("BonusTypeID", 0))
		if not expected.has(kind) or link.get("IsPossession") != false or bonus.get("Value") != expected[kind] \
				or bonus.get("BonusApplicationTypeID") != 0 or bonus.get("BonusApplicationTargetID") != 0:
			return 0
		expected.erase(kind)
	var buff_id: int = rule.buff
	var buff: Dictionary = SOURCE.row("BuffClass", buff_id)
	if buff.get("IsImmuneToDead") != true or buff.get("IsImmuneToCancellation") != true or buff.get("IsHide") != true \
			or SOURCE.row("BuffGroup", int(buff.get("BuffGroupID", 0))).get("IsAllowOverlap") != true:
		return 0
	var links: Array[Dictionary] = SOURCE.related("BuffBonus", "BuffClassID", buff_id)
	if links.size() != 2: return 0
	var permits_registration := false
	var saves_on_character := false
	for link: Dictionary in links:
		if link.get("CharacterLevel") != 0 or link.get("CharacterClass") != 0 or link.get("MinSpellLevel") != 0: return 0
		var bonus: Dictionary = SOURCE.row("Bonus", int(link.get("BonusID", 0)))
		if bonus.get("Value") != 1: return 0
		var application: Variant = bonus.get("BonusApplicationTypeID")
		var target: Variant = bonus.get("BonusApplicationTargetID")
		if bonus.get("BonusTypeID") == 4652 and application == 5 and target == rule.potion:
			permits_registration = true # AutoExtraHealing applies to ItemClass.
		elif bonus.get("BonusTypeID") == 4922 and application == 0 and target == 0:
			saves_on_character = true # SaveDB.
	return int(rule.potion) if permits_registration and saves_on_character else 0
