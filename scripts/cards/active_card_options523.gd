extends RefCounted
## Equipped base-card effects. Each entry names a record field read by the
## existing character/combat owners and the exact original Unit.
## The host's single-player PVP projection matches the card collection rules.
const FLAT := {
	"ArmorClass":"def", "ArmorClassBonus":"def", "SpellPower":"sp",
	"RangeEvasion":"er", "MeleeEvasion":"dg", "KarmaLife":"equipment523_lfe", "KarmaDeath":"equipment523_dth",
	"RegenHP":"equipment523_regen_hp", "RegenMP":"equipment523_regen_mp",
	"AbsoluteRegenHP":"equipment523_regen_hp", "AbsoluteRegenMP":"equipment523_regen_mp",
	"PierceDamageReduction":"damage_reduction_ignore", "PiercePVPDamageReduction":"damage_reduction_ignore",
	"PierceMeleeEvasion":"melee_evasion_ignore", "PierceRangeEvasion":"ranged_evasion_ignore",
	"PierceMeleeDamageReduction":"melee_reduction_ignore", "PierceRangeDamageReduction":"ranged_reduction_ignore",
	"PierceMagicDamageReduction":"magic_reduction_ignore",
	"PVEDamageReduction":"pve_damage_reduction", "PVPDamageReduction":"pvp_damage_reduction",
	"PVEMeleeAdditionDamage":"pve_melee_damage", "PVPMeleeAdditionDamage":"pve_melee_damage",
	"PVERangeAdditionDamage":"pve_ranged_damage", "PVPRangeAdditionDamage":"pve_ranged_damage",
	"PVEMagicAdditionDamage":"pve_magic_damage", "PVPMagicAdditionDamage":"pve_magic_damage",
	"PVEMeleeHit":"pve_melee_hit", "PVERangeHit":"pve_ranged_hit", "PVEMagicHit":"pve_magic_hit",
	"CriticalMeleeDamage":"melee_critical_damage", "CriticalRangeDamage":"ranged_critical_damage",
	"CriticalMagicDamage":"magic_critical_damage", "HPPotionIncreaseStatic":"potionHealFlat",
	"AttackDrainHP":"source_card_attack_drain_hp", "FinalBlowAdditionalDmg":"source_card_final_blow_damage",
	"OneHandSwordDamageBonus":"weapon_bonus_한손검", "DaggerDamageBonus":"weapon_bonus_단검",
	"LargeSwordDamageBonus":"weapon_bonus_양손검", "SpearDamageBonus":"weapon_bonus_창",
	"StaffDamageBonus":"weapon_bonus_지팡이", "BowDamageBonus":"weapon_bonus_활",
	"DoubleSwordDamageBonus":"weapon_bonus_이도류", "ClawDamageBonus":"weapon_bonus_크로우",
	"RifleDamageBonus":"weapon_bonus_라이플", "HandCannonDamageBonus":"weapon_bonus_핸드캐넌",
	"ChainSwordDamageBonus":"weapon_bonus_체인소드", "AxeDamageBonus":"weapon_bonus_도끼",
	"ScytheDamageBonus":"weapon_bonus_사이드", "RuneSwordDamageBonus":"weapon_bonus_마검",
}
const PERCENT := {
	"AttackSpeedBonus":"attackSpeed", "MoveSpeedBonus":"speedBonusPct", "CastSpeedBonus":"source_card_cast_speed_pct",
	"EinasadSavingPercent":"blessing_consumption_reduction_pct",
	"DamageReductionPercent":"pve_damage_reduction_pct", "PVEDamageReductionPercent":"pve_damage_reduction_pct",
	"PVPDamageReductionPercent":"pvp_damage_reduction_pct", "HPPotionIncreasePercent":"potionHealPct",
	"IgnoreDamageReductionPercent":"damage_amp_pct", "IgnorePVPDamageReductionPercent":"damage_amp_pct",
	"PVEPierceDamageReductionPercent":"damage_amp_pct",
	"ElementalCriticalProbability":"equipment523_element_crit_pct",
	"FinalBlowProbability":"source_card_final_blow_pct", "FinalBlowAdditionalScale":"source_card_final_blow_scale",
}
const VALUE_PERCENT := {
	"MeleeCritical":"meleeCrit", "RangeCritical":"rangedCrit", "MagicCritical":"magicCrit",
	"DecreaseChargeStepTime":"source_card_charge_reduction_pct",
	"PierceMagicShieldPercent":"source_card_magic_penetration_pct",
}
const FRACTION := {"HPPlusPercent":["hpPct","ValuePercent"],"ExperienceAdditionPercent":["xp","Percentage"]}
const ELEMENTS := {"Fire":"fire","Water":"water","Air":"wind","Earth":"earth"}

static func direct_stat(kind: String, unit: String, amount: float) -> Dictionary:
	var field: String = ""
	match unit:
		"Value": field = FLAT.get(kind,"")
		"Percentage": field = PERCENT.get(kind,"")
		"ValuePercent": field = VALUE_PERCENT.get(kind,"")
		"Weight":
			if kind=="CarryPlus":field = "weightBonus"
	if FRACTION.has(kind) and unit==FRACTION[kind][1]:
		field = FRACTION[kind][0]
		amount /= 100.0
	return {} if field.is_empty() else {"field":field,"amount":amount}

static func spell_field(kind: String, unit: String) -> String:
	if unit=="Value" and kind=="SpellDamageBase":return "damage"
	if unit=="Percentage" and kind in ["SpellHitProbabilityBase","ReinforceSpellHitProbabilityBaseIncludingTransformSpell"]:return "hit"
	return ""
