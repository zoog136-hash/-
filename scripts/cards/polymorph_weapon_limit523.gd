extends RefCounted
## Original current523 PolymorphEntityWeaponLimit: the WeaponType rows listed
## for a PolymorphEntity are the weapon types that form may use (ranged forms
## list Bow/Gauntlet/Rifle/HandCannon, melee forms list the melee types).
## Only the equipped original transform card's exact class/gender entity is
## consulted. A card/entity without rows, an ambiguous entity, an unknown
## weapon type or an absent original archive imposes no restriction: the
## table defines nothing for those cases and no local rule is invented.
## WeaponType 0 (None) rows are preserved but bare hands are never blocked.
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const BASE = preload("res://scripts/lineagem_base508.gd")
const WEAPON_BANKS = preload("res://scripts/animation/source_weapon_banks.gd")
const AMMO = preload("res://scripts/loot/patch523_ammo.gd")
const LIMIT_TABLE := "PolymorphEntityWeaponLimit"
static var _entity_cache: Dictionary = {}
static var _limit_cache: Dictionary = {}
static var _cache_key: String = ""

static func _sync_cache() -> bool:
	if DEF.identity().is_empty(): return false
	var key: String = DEF.verified_key()
	if key != _cache_key:
		_entity_cache.clear(); _limit_cache.clear(); _cache_key = key
	return true

## Allowed WeaponType IDs (sorted) for one PolymorphEntity. Empty: no rows.
static func allowed_types(entity_id: int) -> Array:
	if not _sync_cache(): return []
	if _limit_cache.has(entity_id): return (_limit_cache[entity_id] as Array).duplicate()
	var found: Dictionary = {}
	for row: Dictionary in DEF.related(LIMIT_TABLE, "PolymorphEntityID", entity_id):
		var value: Variant = row.get("WeaponTypeID")
		if DEF._integer(value) and int(value) >= 0 and DEF.declared_exclusion(LIMIT_TABLE, row).is_empty(): found[int(value)] = true
	var result: Array = found.keys()
	result.sort()
	_limit_cache[entity_id] = result
	return result.duplicate()

static func _walk_buff(buff_id: int, seen: Array, output: Dictionary) -> bool:
	if buff_id in seen or seen.size() >= 16: return false
	if DEF.row("BuffClass", buff_id).is_empty(): return false
	for link: Dictionary in DEF.related("BuffBonus", "BuffClassID", buff_id):
		var bonus: Dictionary = DEF.row("Bonus", int(link.get("BonusID", -1)))
		var kind: Dictionary = DEF.row("BonusType", int(bonus.get("BonusTypeID", -1))) if not bonus.is_empty() else {}
		if bonus.is_empty() or kind.is_empty(): return false
		var name: String = str(kind.get("Name", ""))
		if name not in ["PolymorphSetID", "SpecialPolymorphSetID", "SubSlotBuffClassID"]: continue
		# Conditional links are not admitted as the unconditional form.
		if int(link.get("CharacterLevel", 0)) != 0 or int(link.get("CharacterClass", 0)) != 0 or int(link.get("MinSpellLevel", 0)) != 0: continue
		if int(bonus.get("BonusApplicationTypeID", 0)) != 0 or int(bonus.get("BonusApplicationTargetID", 0)) != 0: continue
		if name == "SubSlotBuffClassID":
			if not _walk_buff(int(bonus.get("Value", -1)), seen + [buff_id], output): return false
		else:
			_add_set(int(bonus.get("Value", -1)), output)
	return true

static func _add_set(set_id: int, output: Dictionary) -> void:
	for join: Dictionary in DEF.related("PolymorphEntityForSet", "PolymorphSetID", set_id):
		var entity: Dictionary = DEF.row("PolymorphEntity", int(join.get("PolymorphEntityID", -1)))
		if not entity.is_empty(): output[int(entity.ID)] = entity

## Exact PolymorphEntity IDs of a transform card for this class/gender.
static func entities_for_card(card_id: int, class_id: int, gender_id: int, option_id: int = 0) -> Dictionary:
	if not _sync_cache(): return {"ok":false, "reason":"original523_definitions_unavailable", "entities":[]}
	var key: String = "%d:%d:%d:%d" % [card_id, class_id, gender_id, option_id]
	if _entity_cache.has(key): return (_entity_cache[key] as Dictionary).duplicate(true)
	var result: Dictionary = {"ok":false, "reason":"", "entities":[]}
	var card: Dictionary = DEF.row("BuffCard", card_id)
	var candidates: Dictionary = {}
	if card.is_empty() or int(card.get("BuffCardDeckID", -1)) != 1:
		result.reason = "not_original_polymorph_card"
	elif option_id > 0:
		var option: Dictionary = DEF.row("BuffCardSpriteCustomizingOption", option_id)
		var unit: Dictionary = DEF.row("Unit", int(option.get("UnitID", -1))) if not option.is_empty() else {}
		if int(option.get("BuffCardID", -1)) != card_id or unit.get("Name", "") != "PolymorphSetID": result.reason = "active_option_not_declared_for_card"
		else: _add_set(int(option.get("Value", -1)), candidates)
	elif not _walk_buff(int(card.get("BuffClassID", -1)), [], candidates):
		result.reason = "card_entity_chain_incomplete"
	if result.reason.is_empty():
		var entities: Array = []
		for id: int in candidates:
			var entity: Dictionary = candidates[id]
			var entity_class: int = int(entity.get("ClassID", 0))
			var entity_gender: int = int(entity.get("GenderID", 0))
			if entity_class > 0 and entity_class != class_id: continue
			if entity_gender > 0 and entity_gender != gender_id: continue
			entities.append(id)
		entities.sort()
		result.entities = entities
		result.ok = not entities.is_empty()
		if entities.is_empty(): result.reason = "no_entity_for_class_gender"
	_entity_cache[key] = result
	return result.duplicate(true)

## Original WeaponType ID of a weapon record: native WeaponType bonus first,
## then the existing reviewed local-type mapping. -1: not determinable.
static func weapon_type_id(record: Dictionary) -> int:
	if record.is_empty(): return 0
	var native: Dictionary = AMMO.weapon_type(record)
	if not native.is_empty() and DEF._integer(native.get("ID")): return int(native.ID)
	return WEAPON_BANKS.local_type(str(record.get("type", "")))

## The equipped transform's resolved weapon rule. "active" false: no rule.
static func status(world: Node) -> Dictionary:
	var result: Dictionary = {"active":false, "reason":"", "allowed":[], "entities":[]}
	var value: Variant = world.get("equipped_catalog").get("변신", {}) if world.get("equipped_catalog") is Dictionary else {}
	var record: Dictionary = value if value is Dictionary else {}
	if record.is_empty(): result.reason = "no_transform"; return result
	if not BASE.native(record): result.reason = "not_original_card"; return result
	# The equipped record carries its original card ID; the card row itself is
	# re-read below (deck 1 only), so no catalog rebuild runs per attack.
	var canonical: Dictionary = record if DEF._integer(record.get("source_card_id")) else BASE.canonical(record)
	var card_id: int = int(canonical.get("source_card_id", -1))
	result["transform_name"] = str(record.get("name", ""))
	result["card_id"] = card_id
	var context: Dictionary = world._source_visual_context() if world.has_method("_source_visual_context") else {}
	var options: Dictionary = context.get("active_card_options", {})
	var option_id: int = int(options.get(str(canonical.get("sourceId", "")), record.get("source_active_custom_option_id", 0)))
	var resolved: Dictionary = entities_for_card(card_id, int(context.get("class_id", 0)), int(context.get("gender_id", 0)), option_id)
	result.entities = resolved.entities
	if not resolved.ok: result.reason = str(resolved.reason); return result
	var allowed: Array = []
	for entity_id: int in resolved.entities:
		var types: Array = allowed_types(int(entity_id))
		if types.is_empty(): result.reason = "entity_has_no_weapon_limit_rows"; return result
		if not allowed.is_empty() and allowed != types: result.reason = "entities_differ_in_weapon_limit"; return result
		allowed = types
	result.allowed = allowed
	result.active = true
	result["entity_id"] = int(resolved.entities[0])
	return result

static func _type_label(type_id: int) -> String:
	var row: Dictionary = DEF.row("WeaponType", type_id)
	var desc: Dictionary = DEF.row("DescData_Korean", int(row.get("DescID", 0))) if not row.is_empty() else {}
	var text: String = str(desc.get("Description", ""))
	return text if not text.is_empty() else str(row.get("Name", type_id))

## Rejection text for a weapon under the current transform, or "".
static func reason_for_weapon(world: Node, weapon: Dictionary) -> String:
	if weapon.is_empty(): return ""
	var type_id: int = weapon_type_id(weapon)
	if type_id <= 0: return ""
	var rule: Dictionary = status(world)
	if not bool(rule.active) or (rule.allowed as Array).has(type_id): return ""
	return "%s 변신 상태에서는 %s 무기를 사용할 수 없습니다" % [str(rule.get("transform_name", "현재")), _type_label(type_id)]

static func equip_reason(world: Node, record: Dictionary) -> String:
	return reason_for_weapon(world, record) if str(record.get("slot", "")) == "weapon" else ""

static func attack_reason(world: Node) -> String:
	return reason_for_weapon(world, world._equipped_weapon_record()) if world.has_method("_equipped_weapon_record") else ""
