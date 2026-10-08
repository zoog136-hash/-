extends RefCounted
class_name TwilightOriginalEnhancement

# Standard Lineage M additional stats, not one generic set for every item.
# Special named items may supply exact per-level enhancement table.
static func stats(kind: String, level: int, record: Dictionary = {}) -> Dictionary:
	var rank: int = maxi(0, level)
	var custom_value: Variant = record.get("enhancement_options", {})
	if custom_value is Dictionary and not (custom_value as Dictionary).is_empty():
		var custom: Dictionary = custom_value as Dictionary
		var entry_value: Variant = custom.get(str(clampi(rank, 0, 21)), {})
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
			var name_value: String = str(record.get("name", ""))
			# Only items whose original enhancement tracks are known receive
			# an enhancement bonus. Other accessories require a per-item table.
			if name_value.contains("룸티스의 보랏빛 귀걸이"):
				var mana: Array[int] = [5, 15, 20, 35, 40, 55, 60, 75, 100]
				var sp: Array[int] = [0, 0, 0, 1, 1, 2, 2, 3, 4]
				var idx: int = clampi(rank, 0, 8)
				var data: Dictionary = {"mp":mana[idx] - mana[0], "sp":sp[idx]}
				if idx >= 5: data["defense"] = idx - 3
				return data
			if name_value.contains("룸티스의 붉은빛 귀걸이"):
				var hp: Array[int] = [10, 30, 40, 50, 60, 70, 80, 90, 100]
				var i: int = clampi(rank, 0, 8)
				return {"hp":hp[i] - hp[0],"reduction":maxi(0, i - 2)}
			if str(record.get("slot", "")).begins_with("ring") or str(record.get("slot", "")) == "ring" or str(record.get("type", "")).contains("반지") or name_value.contains("반지"):
				var result: Dictionary = {"hp":rank * 10, "capacity":rank * 10}
				if rank >= 5:
					var bonus: int = rank - 4
					result.merge({"melee_damage":bonus, "ranged_damage":bonus,
						"melee_accuracy":bonus, "ranged_accuracy":bonus, "magic_accuracy":bonus, "sp":bonus})
				return result
			return {}

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
	if bonus.has("mp"): parts.append("Max MP +%d" % int(bonus["mp"]))
	if bonus.has("reduction"): parts.append("리덕션 +%d" % int(bonus["reduction"]))
	if parts.is_empty(): return "강화 추가 옵션 없음"
	return " · ".join(parts)
