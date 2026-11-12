extends RefCounted
## Equipment proc spell profiles (InvokeOption type 1 Attack_Spell, Param1 =
## SpellClass) compiled from the current original 523 tables
## (SpellClass/SpellBonus/BuffClass/BuffBonus/Bonus/BonusType/Unit).
## Same acceptance as the earlier public compiler
## (tools/equipment/patch523_native_spells.py): only a pure damage spell or a
## pure stat/hold debuff whose every row the existing SkillService executor
## understands. Anything else returns {} and the enchant row stays unconnected.
## The executor and its validation (patch523_equipment_spells.gd) are unchanged.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SPELLS = preload("res://scripts/crafting/patch523_equipment_spells.gd")
const SCHEMA := "patch523-equipment-damage-spell-v1"
const DAMAGE_NAMES := ["SpellDamageBase","SpellDamageDiceNumber","SpellDamageDiceSpotCount"]
const FLAGS := ["FixedMagicDamage","IgnoreMagicResistance","IgnoreDamageReductionCalculation"]
const ZERO_RULES := ["SiegeTargetKindID","HPCost","MPCost","VPCost","SpellMaterialTypeID","SpellMaterialItemAmount","SpellCompositionNode","CopySpellClassID","IsChargeSpell","CastingWeaponType","AlignmentChangeAmount","TargetLimitCount","BackwardPathCount"]
const TARGET_NAMES := {10:"TargetNEnemy",11:"AllButMe",422:"AttackableNPC"}
static var _cache: Dictionary = {}
static var _cache_identity: Dictionary = {}

static func _int(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

## Python `raw.get(k,0)!=0` (False == 0 there).
static func _zero(value: Variant) -> bool:
	return not value if value is bool else (_int(value) and int(value)==0)

static func _rules_zero(raw: Dictionary) -> bool:
	for key: String in ZERO_RULES:
		if not _zero(raw.get(key,0)): return false
	return true

static func _effects(table: String, key: String, id: int) -> Array:
	var result: Array = []
	for link: Dictionary in SOURCE.related(table,key,id):
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if bonus.is_empty() or type.is_empty(): return []
		result.append({"link":link.duplicate(true),"bonus":bonus.duplicate(true),"type":type.duplicate(true),"unit":SOURCE.row("Unit",int(type.get("UnitID",-1))).duplicate(true)})
	return result

## The compiled profile of one SpellClass ID ({} when the executor cannot run it).
static func profile(spell_id: int) -> Dictionary:
	var identity: Dictionary = SOURCE.identity()
	if identity != _cache_identity: _cache.clear(); _cache_identity = identity.duplicate(true)
	if _cache.has(spell_id): return _cache[spell_id]
	var result: Dictionary = {}
	if not identity.is_empty() and spell_id > 0:
		var raw: Dictionary = SOURCE.row("SpellClass",spell_id)
		if not raw.is_empty() and SOURCE.declared_exclusion("SpellClass",raw).is_empty():
			var base: Dictionary = {"source_spell":raw.duplicate(true),"effects":_effects("SpellBonus","SpellClassID",spell_id)}
			result = damage_profile(base)
			if result.is_empty(): result = buff_profile(base)
			# The executor validates its own copy; keep only what it accepts.
			if not result.is_empty() and (SPELLS.buff_values(result).is_empty() if result.mode=="source_buff_modifiers" else SPELLS.values(result).is_empty()): result = {}
	_cache[spell_id] = result
	return result

static func damage_profile(base: Dictionary) -> Dictionary:
	var raw: Dictionary = base.source_spell; var values: Dictionary = {}
	if raw.get("TestSpell")!=false or not _int(raw.get("TargettingTypeID")) or int(raw.TargettingTypeID)!=2 or not _int(raw.get("TargetKindID")) or int(raw.TargetKindID)!=11 or not _zero(raw.get("TargetAreaRadius",0)): return {}
	if not _rules_zero(raw): return {}
	for effect: Dictionary in base.effects:
		var link: Dictionary = effect.link; var b: Dictionary = effect.bonus; var t: Dictionary = effect.type; var name: String = str(t.get("Name",""))
		if (name not in DAMAGE_NAMES and name not in FLAGS) or values.has(name) or not _zero(link.get("MinSpellLevel",-1)) or not _zero(b.get("BonusApplicationTypeID",-1)) or not _zero(b.get("BonusApplicationTargetID",-1)): return {}
		if not _int(t.get("UnitID")) or int(t.UnitID)!=(20 if name in ["FixedMagicDamage","IgnoreMagicResistance"] else 1): return {}
		if not _int(b.get("Value")) or int(b.Value)<0: return {}
		values[name] = int(b.Value)
	var damage: bool = false
	for name: String in DAMAGE_NAMES: damage = damage or values.has(name)
	if values.is_empty() or not damage: return {}
	var flags: int = 0
	for name: String in FLAGS:
		if values.has(name):
			flags += 1
			if int(values[name])!=1: return {}
	if flags not in [0,FLAGS.size()]: return {}
	var count: int = int(values.get("SpellDamageDiceNumber",0)); var spots: int = int(values.get("SpellDamageDiceSpotCount",0))
	if count>100 or spots>1000000 or (count>0 and spots<1) or int(values.get("SpellDamageBase",0))>1000000: return {}
	if not _int(raw.get("ElementalTypeID")) or int(raw.ElementalTypeID) not in [0,1,2,3,4]: return {}
	for key: String in ["CastRange","MinCastRange","CastDelay"]:
		if raw.get(key) is bool or not _int(raw.get(key)) or int(raw[key])<0: return {}
	if int(raw.MinCastRange)>int(raw.CastRange) or int(values.get("SpellDamageBase",0))+count*spots<=0: return {}
	var out: Dictionary = base.duplicate(true)
	out.merge({"schema":SCHEMA,"values":values,"mode":"fixed_ignore_mr_dr" if flags>0 else "source_dice_magic",
		"source_target_kind":{"ID":11,"Name":"AllButMe","RootTargetKindNodeID":41},
		"host_interpretation":"existing magic hit/element/target-flat-reduction stages; no extra skill cost/critical/drain/recursive proc"},true)
	return out

static func buff_profile(base: Dictionary) -> Dictionary:
	var raw: Dictionary = base.source_spell; var values: Dictionary = {}
	if raw.get("TestSpell")!=false or not _int(raw.get("TargettingTypeID")) or int(raw.TargettingTypeID)!=2 or not _int(raw.get("TargetKindID")) or int(raw.TargetKindID) not in [10,11,422] or not _zero(raw.get("TargetAreaRadius",0)): return {}
	if not _rules_zero(raw): return {}
	for effect: Dictionary in base.effects:
		var link: Dictionary = effect.link; var b: Dictionary = effect.bonus; var t: Dictionary = effect.type; var name: String = str(t.get("Name",""))
		if not SPELLS.BUFF_SPELL_FIELDS.has(name) or values.has(name) or not _int(t.get("UnitID")) or int(t.UnitID)!=int(SPELLS.BUFF_SPELL_FIELDS[name]) or not _zero(link.get("MinSpellLevel",-1)) or not _zero(b.get("BonusApplicationTypeID",-1)) or not _zero(b.get("BonusApplicationTargetID",-1)) or not _int(b.get("Value")): return {}
		values[name] = int(b.Value)
	for name: String in ["BuffClassID","SpellDebuffMinDuration","SpellDebuffMaxDuration"]:
		if not values.has(name): return {}
	if not (0<int(values.SpellDebuffMinDuration) and int(values.SpellDebuffMinDuration)<=int(values.SpellDebuffMaxDuration) and int(values.SpellDebuffMaxDuration)<=86400): return {}
	if values.has("SpellHitProbabilityMultiplier") and (not values.has("SpellHitProbabilityBase") or not values.has("SpellHitProbabilityMax")): return {}
	var br: Dictionary = SOURCE.row("BuffClass",int(values.BuffClassID))
	if br.is_empty() or not SOURCE.declared_exclusion("BuffClass",br).is_empty(): return {}
	if br.get("IsEraseOnTimeEnd")!=true or not _zero(br.get("MaxStackCount",0)) or not _zero(br.get("IsBuffGroup",false)) or not _zero(br.get("IsAbsoluteTimeBuff",false)): return {}
	for key: Variant in br:
		if str(key).begins_with("IsEraseOn") and str(key)!="IsEraseOnTimeEnd" and not _zero(br[key]): return {}
	var buff_effects: Array = _effects("BuffBonus","BuffClassID",int(br.ID))
	var modifiers: Dictionary = {}
	for effect: Dictionary in buff_effects:
		var link: Dictionary = effect.link; var b: Dictionary = effect.bonus; var t: Dictionary = effect.type; var name: String = str(t.get("Name",""))
		for key: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
			if not _zero(link.get(key,0)): return {}
		if not _int(b.get("Value")) or not _int(t.get("UnitID")): return {}
		var key: String; var amount: float
		if name=="SpecialResistance" and int(t.UnitID)==3 and int(b.get("BonusApplicationTypeID",-1))==2 and int(b.get("BonusApplicationTargetID",-1))==6: key="source_stun_resistance";amount=float(b.Value)*.0001
		elif SPELLS.BUFF_FIELDS.has(name) and int(t.UnitID)==int(SPELLS.BUFF_FIELDS[name][1]) and _zero(b.get("BonusApplicationTypeID",-1)) and _zero(b.get("BonusApplicationTargetID",-1)): key=str(SPELLS.BUFF_FIELDS[name][0]);amount=float(b.Value)*float(SPELLS.BUFF_FIELDS[name][2])
		elif name=="CannotMove" and int(t.UnitID)==20 and int(b.Value)==1 and _zero(b.get("BonusApplicationTypeID",-1)) and _zero(b.get("BonusApplicationTargetID",-1)): key="source_hold";amount=1
		else: return {}
		modifiers[key] = float(modifiers.get(key,0))+amount
	if modifiers.is_empty(): return {}
	var out: Dictionary = base.duplicate(true)
	out.merge({"schema":SCHEMA,"mode":"source_buff_modifiers","values":values,"buff":{"source_buff":br.duplicate(true),"effects":buff_effects},"modifiers":modifiers,
		"source_target_kind":{"ID":int(raw.TargetKindID),"Name":TARGET_NAMES[int(raw.TargetKindID)]},
		"host_interpretation":"existing life-scoped status owner; source duration/stat units, native buff-group priority; labelled configurable MR/level chance formula"},true)
	return out

## Profile lookup for the existing consumers: a legacy model's stored
## profiles keep priority; the current original model compiles on demand.
static func of(book: Object, spell_id: int) -> Dictionary:
	var stored: Variant = book.data.get("equipment_spell_profiles") if book != null else null
	if stored is Dictionary: return stored.get(str(spell_id),{})
	return profile(spell_id)

## Item restriction the executor rechecks (DeleteTime deadlines), from the
## current native record: source_delete_time_raw is the yyyymmddhhmm deadline.
static func item_constraint(book: Object, record: Dictionary, id: String) -> Dictionary:
	var stored: Variant = book.data.get("equipment_spell_item_constraints") if book != null else null
	if stored is Dictionary: return stored.get(id,{})
	var full: Dictionary = preload("res://scripts/loot/current523_native_fields.gd").full(record)
	var result: Dictionary = {"schema":"patch523-equipment-spell-item-v1","delete_times":[],"blocked_reason":""}
	if full.get("source_delete_time_unresolved",false): result.blocked_reason = "원본 DeleteTime 조건 해석 필요"
	elif _int(full.get("source_delete_time_raw")):
		var text: String = str(int(full.source_delete_time_raw))
		var stamp: int = Time.get_unix_time_from_datetime_string("%s-%s-%sT%s:%s:00" % [text.substr(0,4),text.substr(4,2),text.substr(6,2),text.substr(8,2),text.substr(10,2)])
		result.delete_times.append({"raw":int(full.source_delete_time_raw),"local_unix":stamp})
	return result
