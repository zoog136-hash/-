extends RefCounted
## Explicit capability map. PvP and unverified reduction-rate effects stay blocked.
## This is not the legacy PvP-to-PvE item-description adapter.
const SUPPORTED: Array = [
	"max_hp:flat", "max_mp:flat", "melee_hit:flat", "ranged_hit:flat", "magic_hit:flat",
	"melee_damage:flat", "ranged_damage:flat", "magic_damage:flat", "damage_reduction:flat",
	"ac:flat", "mr:flat", "er:flat", "weight_bonus:flat", "sp:flat",
	"str:flat", "dex:flat", "con:flat", "int:flat", "wis:flat", "cha:flat",
	"experience_bonus:percent", "attack_speed:percent", "movement_speed:percent",
	"stun_hit:percent", "stun_resistance:percent", "hold_resistance:percent",
	"fire_resistance:percent", "earth_resistance:percent", "water_resistance:percent", "wind_resistance:percent",
	"melee_critical_rate:percent", "ranged_critical_rate:percent",
	"melee_critical_damage:flat", "ranged_critical_damage:flat", "magic_critical_damage:flat",
	"pve_melee_hit:flat", "pve_ranged_hit:flat", "pve_magic_hit:flat",
	"pve_melee_damage:flat", "pve_ranged_damage:flat", "pve_magic_damage:flat", "pve_damage_reduction:flat"
]

static func record(totals: Dictionary) -> Dictionary:
	if totals.is_empty(): return {}
	var out: Dictionary = {"_equipment_collection_bonus":true}
	var mapping: Dictionary = {
		"max_hp:flat":"hpFlat", "mr:flat":"mr", "er:flat":"er",
		"damage_reduction:flat":"damage_reduction", "stun_hit:percent":"stun_accuracy",
		"stun_resistance:percent":"stun_resistance", "hold_resistance:percent":"hold_resistance",
		"fire_resistance:percent":"element_resist_fire", "earth_resistance:percent":"element_resist_earth",
		"water_resistance:percent":"element_resist_water", "wind_resistance:percent":"element_resist_wind",
		"melee_critical_rate:percent":"melee_crit", "ranged_critical_rate:percent":"ranged_crit"
	}
	for key: String in mapping:
		out[mapping[key]] = totals.get(key,0)
	out["speed"] = 1.0 + float(totals.get("movement_speed:percent",0))/100.0
	out["xp"] = float(totals.get("experience_bonus:percent",0))/100.0
	out["collection_attack_speed"] = float(totals.get("attack_speed:percent",0))
	return out

static func catalog_bonus(totals: Dictionary, key: String) -> int:
	var mapping: Dictionary = {"mpFlat":"max_mp:flat", "sp":"sp:flat", "weightBonus":"weight_bonus:flat", "pve_damage_reduction":"pve_damage_reduction:flat"}
	return int(totals.get(str(mapping.get(key,"")),0))
