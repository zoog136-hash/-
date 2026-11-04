extends RefCounted
## Typed consumers preserve original units and application targets.
const FLAT_FIELDS: Dictionary={"MeleeHit":"meleeHit","RangeHit":"rangedHit","MagicHit":"magicHit","MeleeDamage":"meleeDamage","RangeDamage":"rangedDamage","ArmorClass":"def","Dexterity":"dexFlat","Intelligence":"intFlat","Strength":"strFlat","Constitution":"conFlat","RangeEvasion":"er","MeleeEvasion":"dg","HPPlus":"hpFlat","CarryPlus":"weightBonus","MeleeCritical":"meleeCrit","RangeCritical":"rangedCrit","SpellPower":"sp","DamageReduction":"damageReduction","PVEDamageReduction":"pve_damage_reduction","KarmaDeath":"dthFlat"}
const SEPARATE: Array[String]=["RegenMP","AttackSpeedBonus","MoveSpeedBonus","ExperienceAdditionPercent","DecreaseChargeStepTime"]
const ELEMENTS: Dictionary={1:"fire",2:"water",3:"wind",4:"earth"}
const STATUS: Dictionary={6:"stun",7:"hold",8:"fear"}
static func supported(effect: Dictionary) -> bool:
	var kind: String=str(effect.get("type",""));var app: int=int(effect.get("application_type",-1));var target: int=int(effect.get("target",-1))
	if kind in ["HitSpecialResistance","SpecialResistance"]:return app==2 and STATUS.has(target)
	if kind=="ElementalDamage":return app==3 and ELEMENTS.has(target)
	return app==0 and target==0 and (FLAT_FIELDS.has(kind) or kind in SEPARATE)
static func record(effects: Array) -> Dictionary:
	var out: Dictionary={"_combination_bonus":true}
	for effect: Dictionary in effects:
		if not supported(effect):continue
		var kind: String=effect.type;var value: float=float(effect.value)
		var key: String=str(FLAT_FIELDS.get(kind,""))
		if kind in ["HitSpecialResistance","SpecialResistance"]:key=str(STATUS[int(effect.target)])+("_accuracy" if kind=="HitSpecialResistance" else "_resistance")
		if not key.is_empty():out[key]=float(out.get(key,0))+value
		match kind:
			"AttackSpeedBonus":out.collection_attack_speed=value
			"MoveSpeedBonus":out.speed=1.0+value/100.0
			"ExperienceAdditionPercent":out.xp=value/100.0
	return out
static func amount(effects: Array,kind: String,target: int=0) -> float:
	var out: float=0
	for effect: Dictionary in effects:
		if effect.type==kind and int(effect.target)==target and supported(effect):out+=float(effect.value)
	return out
static func charge_step(seconds: float,effects: Array) -> float:
	return maxf(0,seconds)*(1.0-clampf(amount(effects,"DecreaseChargeStepTime"),0,100)/100.0)
