extends RefCounted
class_name TwilightOriginalEnhancement

# Base equipment stats are stored on the item record. These are ENCHANTMENT
# INCREMENTS relative to the unequipped +0 item's original base options.
# No universal ring/earring enhancement formula: use verified named tables.
const ROOMTIS_SOURCE: String = "https://rc-wstatic.plaync.co.kr/lineagem/guidebook/game_item_roomtis.html"
const DOPPEL_SOURCE: String = "https://lineagem.inven.co.kr/db/item/665?vtype=pc"
const ARMOR_SOURCE: String = "https://rc-wstatic.plaync.co.kr/lineagem/guidebook/game_item_enchant.html"

static func _roomtis(name_value: String, rank: int) -> Dictionary:
	var i: int = clampi(rank, 0, 8)
	if name_value.contains("룸티스의 푸른빛 귀걸이"):
		var flats: Array[int] = [2, 6, 8, 10, 12, 14, 16, 18, 20]
		var rates: Array[int] = [2, 6, 8, 10, 12, 16, 19, 22, 25]
		var armors: Array[int] = [0, 0, 0, 0, 0, 1, 2, 2, 3]
		return {"potion_heal_flat":flats[i] - flats[0], "potion_heal_pct":rates[i] - rates[0], "defense":armors[i]}
	if name_value.contains("룸티스의 검은빛 귀걸이"):
		return {"defense":i, "melee_damage":maxi(0, i - 2), "ranged_damage":maxi(0, i - 2)}
	if name_value.contains("룸티스의 붉은빛 귀걸이"):
		var hp: Array[int] = [10, 30, 40, 50, 60, 70, 80, 90, 100]
		return {"hp":hp[i] - hp[0], "reduction":maxi(0, i - 2)}
	if name_value.contains("룸티스의 보랏빛 귀걸이") or name_value.contains("룸티스의 보라빛 귀걸이"):
		var mana: Array[int] = [5, 15, 20, 35, 40, 55, 60, 75, 100]
		var sp: Array[int] = [0, 0, 0, 1, 1, 2, 2, 3, 4]
		var mp_regen: Array[int] = [0, 0, 0, 0, 1, 1, 2, 2, 3]
		var ac: Array[int] = [0, 0, 0, 0, 0, 2, 3, 4, 5]
		return {"mp":mana[i] - mana[0], "sp":sp[i], "mp_recovery":mp_regen[i], "defense":ac[i]}
	return {}

static func stats(kind: String, level: int, record: Dictionary = {}) -> Dictionary:
	var rank: int = maxi(0, level)
	var custom_value: Variant = record.get("enhancement_options", {})
	if custom_value is Dictionary and not (custom_value as Dictionary).is_empty():
		var custom: Dictionary = custom_value as Dictionary
		var entry_value: Variant = custom.get(str(clampi(rank, 0, 21)), {})
		if entry_value is Dictionary:
			return (entry_value as Dictionary).duplicate(true)
	var name_value: String = str(record.get("name", ""))
	match kind:
		"weapon":
			return {"damage":rank if rank <= 9 else 9 + (rank - 9) * 2, "accuracy":rank}
		"armor":
			var result: Dictionary = {"defense":rank}
			if name_value in ["마법 방어 투구", "마법 방어 사슬 갑옷", "마법 망토", "은색의 망토"]:
				result["mr"] = rank * 2
			elif name_value in ["거대 여왕 개미의 금빛 날개", "거대 여왕 개미의 은빛 날개", "뱀파이어의 망토"]:
				result["mr"] = rank * 3
			elif name_value == "리치 로브" and rank >= 3:
				result["sp"] = rank - 2
			return result
		"accessory":
			var roomtis: Dictionary = _roomtis(name_value, rank)
			if not roomtis.is_empty():
				return roomtis
			# Only the original item actually having this published table.
			if name_value == "도펠겡어 보스의 오른쪽 반지":
				var result: Dictionary = {"hp":rank * 10, "capacity":rank * 10}
				if rank >= 5:
					var bonus: int = rank - 4
					result.merge({"melee_damage":bonus, "ranged_damage":bonus,
						"melee_accuracy":bonus, "ranged_accuracy":bonus,
						"magic_accuracy":bonus, "sp":bonus})
				return result
			# Do not grant the Doppel ring's unique progression to other rings.
			return {}
	return {}

static func summary(kind: String, level: int, record: Dictionary = {}) -> String:
	var bonus: Dictionary = stats(kind, level, record)
	var labels: Dictionary = {"damage":"추가 대미지", "accuracy":"명중", "defense":"AC -",
		"hp":"Max HP", "mp":"Max MP", "capacity":"무게 보너스", "sp":"SP",
		"mr":"MR", "reduction":"대미지 리덕션", "melee_damage":"근거리 대미지",
		"ranged_damage":"원거리 대미지", "melee_accuracy":"근거리 명중",
		"ranged_accuracy":"원거리 명중", "magic_accuracy":"마법 명중",
		"potion_heal_flat":"물약 회복량", "potion_heal_pct":"물약 회복률",
		"mp_recovery":"MP 회복 옵션"}
	var result: PackedStringArray = []
	for key: Variant in bonus.keys():
		if int(bonus[key]) == 0:
			continue
		var label: String = str(labels.get(key, str(key)))
		if key == "defense":
			result.append("AC -%d" % int(bonus[key]))
		elif key == "potion_heal_pct":
			result.append("%s +%d%%" % [label, int(bonus[key])])
		else:
			result.append("%s +%d" % [label, int(bonus[key])])
	return " · ".join(result) if not result.is_empty() else "추가 강화 옵션 없음"
