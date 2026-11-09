extends RefCounted
class_name TwilightOriginalEnhancement
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")

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
	if record.get("source_m_native_item",false):
		var source: Dictionary = preload("res://scripts/loot/patch523_monster_drops.gd").native_enchant_stats(record,rank)
		var fallback: Dictionary = record.duplicate(true)
		fallback.erase("source_m_native_item")
		fallback["name"] = str(NATIVE_FIELDS.field(record,"source_display_name",record.get("name","")))
		var result: Dictionary = stats(kind,rank,fallback)
		result.merge(source,true)
		return result
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
		"mp_recovery":"MP 회복 옵션", "xp_pct":"경험치 획득량", "ain_saving_pct":"아인하사드 축복 소모량 감소",
		"potion_cooldown_pct":"물약 재사용 대기 감소", "stun_resistance":"스턴 내성"}
	var extras: Dictionary=record.get("enhancement_extra_options",{}).get(str(clampi(level,0,21)),{})
	for key: String in extras:
		bonus[key]=extras[key]
	labels.merge({"strFlat":"STR","dexFlat":"DEX","intFlat":"INT","er":"ER","dg":"DG",
		"strPercent":"STR(%)","dexPercent":"DEX(%)","intPercent":"INT(%)",
		"source_elemental_flat_fire":"불 속성 추가 피해","source_elemental_flat_water":"물 속성 추가 피해","source_elemental_flat_wind":"바람 속성 추가 피해","source_elemental_flat_earth":"땅 속성 추가 피해",
		"source_stun_magic_damage":"스턴 조건 마법 피해","source_final_blow_stun_chance_pct":"스턴 조건 결정타(%)","source_final_blow_chance_pct":"결정타(%)","source_final_blow_amp_pct":"결정타 증폭(%)",
		"source_attack_drain_hp":"공격 HP 흡수 강화량","source_attack_drain_mp":"공격 MP 흡수 강화량","source_undead_damage_max":"언데드 추가 피해 최댓값",
		"stun_accuracy":"스턴 적중(%)","fear_accuracy":"공포 적중(%)","hold_accuracy":"홀드 적중(%)","poison_accuracy":"독 적중(%)","silence_accuracy":"침묵 적중(%)",
		"hold_resistance":"홀드 내성(%)","fear_resistance":"공포 내성(%)","poison_resistance":"독 내성(%)","silence_resistance":"침묵 내성(%)",
		"healing_magic_pct":"회복 마법량(%)","castSpeed":"시전 속도(%)","dot_damage_reduction_pct":"지속 대미지 감소(%)",
		"melee_critical_resistance":"근거리 치명타 저항(%)","ranged_critical_resistance":"원거리 치명타 저항(%)",
		"melee_damage_reduction_pct":"근거리 대미지 감소(%)","ranged_damage_reduction_pct":"원거리 대미지 감소(%)","magic_damage_reduction_pct":"마법 대미지 감소(%)",
		"damage_amp_pct":"대미지 증가(%)","adena_drop_pct":"아데나 드롭량(%)",
		"mpRecoveryTick":"MP 회복","magicDamage":"마법 대미지","attackSpeed":"공격 속도(%)",
		"speedBonusPct":"이동 속도(%)","pve_damage_reduction":"PVE 리덕션","pve_damage_reduction_pct":"PVE 리덕션(%)",
		"source_pvp_flat_reduction_ignore":"PVP 리덕션 무시(싱글플레이어 추가 피해 해석)","source_pvp_status_success_level":"PVP 스킬 성공 레벨(가상 레벨 해석)","source_fear_flat_reduction_ignore":"공포8 조건 리덕션 무시(추가 피해 해석)",
		"source_melee_flat_reduction_ignore":"근거리 리덕션 무시(게임 추가 피해 해석)","source_ranged_flat_reduction_ignore":"원거리 리덕션 무시(게임 추가 피해 해석)","source_magic_flat_reduction_ignore":"마법 리덕션 무시(게임 추가 피해 해석)",
		"damage_reduction_ignore":"리덕션 무시","pve_melee_damage":"PVE 근거리 대미지","pve_ranged_damage":"PVE 원거리 대미지",
		"pve_magic_damage":"PVE 마법 대미지","melee_crit":"근거리 치명타(%)","ranged_crit":"원거리 치명타(%)","magic_crit":"마법 치명타(%)"})
	var result: PackedStringArray = []
	for key: Variant in bonus.keys():
		if is_zero_approx(float(bonus[key])):
			continue
		var label: String = str(labels.get(key, str(key)))
		if key == "defense":
			result.append("AC -%d" % int(bonus[key]))
		elif key in ["potion_heal_pct", "xp_pct", "ain_saving_pct", "potion_cooldown_pct", "stun_resistance"]:
			result.append("%s +%.2f%%" % [label, float(bonus[key])])
		else:
			result.append("%s %+.2f" % [label, float(bonus[key])])
	var text: String=" · ".join(result) if not result.is_empty() else "추가 강화 옵션 없음"
	for key: String in ["healing_magic_pct","castSpeed","dot_damage_reduction_pct","strPercent","dexPercent","intPercent","source_attack_drain_hp","source_attack_drain_mp","source_undead_damage_max","source_elemental_flat_fire","source_elemental_flat_water","source_elemental_flat_wind","source_elemental_flat_earth","source_final_blow_chance_pct","source_final_blow_stun_chance_pct","source_final_blow_amp_pct","source_stun_magic_damage"]:
		if extras.has(key):text+=" · 회복·시전·흡수·추가 피해·능력치% 처리: TWILIGHT 설정";break
	if level==21 and record.get("patch523_effect_basis",{}).get("local_level21_extrapolation",false): text+=" · +21 효과: TWILIGHT 추정 설정"
	var invoke_text: String=preload("res://scripts/crafting/patch523_equipment_combat.gd").summary(record,level)
	if not invoke_text.is_empty():text+="\n"+invoke_text
	return text
