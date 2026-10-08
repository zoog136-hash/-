extends RefCounted
class_name TwilightOriginalEnhancement

# Standard Lineage M additional stats, not one generic set for every item.
# Special named items may supply exact per-level enhancement table.
static func stats(kind: String, level: int, record: Dictionary = {}) -> Dictionary:
	var rank: int = maxi(0, level)
	var custom_value: Variant = record.get("enhancement_options", {})
	if custom_value is Dictionary and not (custom_value as Dictionary).is_empty():
		var custom: Dictionary = custom_value as Dictionary
		var entry_value: Variant = custom.get(str(ranki(rank, 0, 21)), {})
		if entry_value is Dictionary:
			return (entry_value as Dictionary).duplicate(true)
	match kind:
		"weapon":
			# Standard one-handed sword (Damascus): +1..+9 = +N damage / hit.
			# +10 is +11 damage, +11 +13, ... +14 +19.
			return {"damage": rank if rank <= 9 else 9 + (rank - 9) * 2, "accuracy":rank}
		"armor":
			return {"defense":rank}
		"accessory":
			# Standard ring (Zenith's Awakening Ring): HP+20 and load+20 per
			# enchant, higher bonus tiers at 5+, varied other jewelry need
			# source-specific tables. Never fabricate old flat defense.
			var result: Dictionary = {"hp":rank * 20, "capacity":rank * 20}
			if rank >= 5:
				var bonus: int = rank - 4
				result.merge({"melee_damage":bonus,"ranged_damage":bonus,"magic_damage":bonus,
					"melee_accuracy":bonus,"ranged_accuracy":bonus,"magic_accuracy":bonus,
					"damage":bonus,"sp":bonus})
			return result
	return {}

static func summary(kind: String, level: int, record: Dictionary = {}) -> String:
	var bonus: Dictionary = stats(kind, level, record)
	var parts: PackedStringArray = []
	if bonus.has("damage"): parts.append("추가 대미지 +%d" % int(bonus["damage"]))
	if bonus.has("accuracy"): parts.append("명중 +%d" % int(bonus["accuracy"]))
	if bonus.has("defense"): parts.append("AC -%d" % int(bonus["defense"]))
	if bonus.has("hp"): parts.append("Max HP +%d" % int(bonus["hp"]))
	if bonus.has("capacity"): parts.append("무게 보너스 +%d" % int(bonus["capacity"]))
	if bonus.has("sp"): parts.append("SP +%d" % int(bonus["sp"]))
	if parts.is_empty(): return "강화 추가 옵션 없음"
	return " · ".join(parts)
