extends RefCounted
class_name TwilightItemOptions
const CURRENT_DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
static var original_percent_input_evidence: Dictionary = {}

static func additional_original_percent(record: Dictionary, key: String) -> float:
	# Missing base equipment operands only. Existing DTO fields and mapped
	# bonuses win; enhancement overlays remain separate existing contributions.
	var names: Dictionary = {
		"source_equipment_ignore_reduction_pct":"IgnoreDamageReductionPercent",
		"source_equipment_ignore_melee_reduction_pct":"IgnoreMeleeDamageReductionPercent",
		"source_equipment_ignore_ranged_reduction_pct":"IgnoreRangeDamageReductionPercent",
		"source_equipment_ignore_magic_reduction_pct":"IgnoreMagicDamageReductionPercent",
		"castSpeed":"CastSpeedBonus","blessing_consumption_reduction_pct":"EinasadSavingPercent",
		"hpPct":"HPPlusPercent","mpPct":"MPPlusPercent",
		"strPercent":"StrengthScale","dexPercent":"DexterityScale","intPercent":"IntelligenceScale",
		"healing_magic_pct":"HPHealIncreasePercent","dot_damage_reduction_pct":"PoisonDamageReductionPercent",
		"melee_damage_reduction_pct":"MeleeDamageReductionPercent",
		"ranged_damage_reduction_pct":"RangeDamageReductionPercent",
		"magic_damage_reduction_pct":"MagicDamageReductionPercent",
		"melee_critical_resistance":"MeleeCriticalResist","ranged_critical_resistance":"RangeCriticalResist",
		"magic_critical_resistance":"MagicCriticalResist",
		"pve_damage_reduction_pct":["DamageReductionPercent","PVEDamageReductionPercent"],
		"damage_amp_pct":["PierceDamageReductionPercent","PVEPierceDamageReductionPercent"],
		"potionCooldownPct":"PotionConsumeDelayDecreasePercent",
		"equipment523_element_crit_pct":"ElementalCriticalProbability",
		"equipment523_element_crit_resist_pct":"ElementalCriticalResistance",
		"xp":"AbsoluteExperienceAdditionPercent",
		"magic_penetration_pct":"PierceMagicShieldPercent","weapon_block_pct":"WeaponBlock"}
	if not names.has(key): return 0.0
	var unit_name: String = "ValuePercent" if key in ["hpPct","mpPct","magic_penetration_pct"] else "Percentage"
	var divisor: float = 100.0 if unit_name=="ValuePercent" else 10000.0
	if key=="xp": divisor=1000000.0 # Existing xp receiver takes a ratio.
	if key=="magic_penetration_pct": divisor=1.0 # ValuePercent is already percent points.
	var selected: Variant = names[key]
	return _additional_original_operand(record,key,selected if selected is Array else [selected],unit_name,divisor)

static func additional_original_flat(record: Dictionary, key: String) -> int:
	var names: Dictionary = {
		"dg":"MeleeEvasion","er":"RangeEvasion","melee_crit":"MeleeCritical","ranged_crit":"RangeCritical","magic_crit":"MagicCritical","weightBonus":"CarryPlus",
		"equipment523_lfe":"KarmaLife","equipment523_dth":"KarmaDeath",
		"equipment523_critical_reduction":"CriticalDamageReduction","equipment523_element_reduction":"ElementalDamageReduction",
		"damage_reduction_ignore":"PierceDamageReduction",
		"melee_critical_damage":"CriticalMeleeDamage","ranged_critical_damage":"CriticalRangeDamage","magic_critical_damage":"CriticalMagicDamage",
		"pve_melee_hit":"PVEMeleeHit","pve_ranged_hit":"PVERangeHit","pve_magic_hit":"PVEMagicHit",
		"melee_damage_reduction":"MeleeDamageReduction","ranged_damage_reduction":"RangeDamageReduction",
		"magic_damage_reduction":"MagicDamageReduction","poison_damage_reduction":"PoisonDamageReduction",
		"source_undead_damage_max":"UndeadAdditionalMaxDamage"}
	if not names.has(key): return 0
	var aliases: Dictionary = {"dg":["DG","근거리 회피력"],"er":["ER","원거리 회피력"],"melee_crit":["meleeCrit","근거리 치명타"],"ranged_crit":["rangedCrit","원거리 치명타"],"magic_crit":["magicCrit","마법 치명타"]}
	aliases["damage_reduction_ignore"]=["damageReductionIgnore"]
	if not record.get("_patch523_effective_extras",false):
		for alias: String in aliases.get(key,[]):
			if record.has(alias): return 0
		if key.ends_with("_crit"):
			for alias: String in ["crit","critical_rate","치명타"]:
				if record.has(alias): return 0
	# Critical ValuePercent is already a percentage-point chance operand;
	# evasion Value is an integer rating. Neither existing receiver takes a ratio.
	# CarryPlus follows the existing enhancement capacity conversion before the
	# existing host integer-capacity consumer. It does not define item weight.
	var unit_name: String = "Weight" if key=="weightBonus" else "ValuePercent" if key.ends_with("_crit") else "Value"
	return int(_additional_original_operand(record,key,[names[key]],unit_name,100.0 if key=="weightBonus" else 1.0))

static func additional_original_status(record: Dictionary, status: String, kind: String) -> float:
	if status not in ["stun","hold","fear","poison","silence"] or kind not in ["accuracy","resistance"]: return 0.0
	var accuracy_aliases: Dictionary = {"stun":["stunAccuracy","스턴 적중","스턴 적중률"],"hold":["holdAccuracy","홀드 적중","속박 적중"],"fear":["fearAccuracy","공포 적중","피어 적중"],"poison":["poisonAccuracy","독 적중","중독 적중"],"silence":["silenceAccuracy","침묵 적중","사일런스 적중"]}
	var resistance_aliases: Dictionary = {"stun":["stunResistance","stun_resist","스턴 내성","스턴 저항"],"hold":["holdResistance","hold_resist","홀드 내성","속박 내성"],"fear":["fearResistance","fear_resist","공포 내성","피어 내성"],"poison":["poisonResistance","poison_resist","독 내성","중독 내성"],"silence":["silenceResistance","silence_resist","침묵 내성","사일런스 내성"]}
	if not record.get("_patch523_effective_extras",false):
		for alias: String in (accuracy_aliases if kind=="accuracy" else resistance_aliases)[status]:
			if record.has(alias): return 0.0
	return _additional_original_operand(record,status+"_"+kind,["HitSpecialResistance" if kind=="accuracy" else "SpecialResistance"],"Percentage",10000.0,status)

static func additional_original_conditional(record: Dictionary, key: String) -> float:
	# The existing final-blow owner chooses self/target status and hit scope.
	# This supplies only the original operand after that caller's condition gate.
	var inputs: Dictionary = {
		"source_stun_magic_damage":["MagicDamage","Value",1.0],
		"source_final_blow_stun_chance_pct":["FinalBlowProbability","Percentage",10000.0]}
	if not inputs.has(key): return 0.0
	var input: Array = inputs[key]
	return _additional_original_operand(record,key,[input[0]],input[1],input[2],"stun")

static func additional_original_element(record: Dictionary, channel: String, kind: String, channels: Variant) -> float:
	if kind not in ["damage","resistance"] or channel not in ["fire","water","wind","earth","all"] or (channel=="all" and kind!="resistance"): return 0.0
	if not channels is Dictionary: return 0.0
	var target_id: int = -1
	var basis: String = "existing_enhancement_source_elemental_target_channels"
	if channel=="all":
		# Reuse the exact existing equipment523 set-effect contract, not a
		# fabricated ElementalResistanceType foreign table (absent in source).
		target_id=5; basis="existing_equipment523_all_element_target_5"
	else:
		for id: Variant in channels:
			if channels[id]!=channel: continue
			if not str(id).is_valid_int() or int(str(id)) not in [1,2,3,4] or target_id!=-1: return 0.0
			target_id=int(str(id))
		if target_id<0: return 0.0
	var key: String = "source_elemental_flat_"+channel if kind=="damage" else "element_resist_"+channel
	var context: Dictionary = {"target_id":target_id,"channel":channel,"basis":basis}
	return _additional_original_operand(record,key,["ElementalDamage" if kind=="damage" else "ElementalResistance"],"Value" if kind=="damage" else "Percentage",1.0 if kind=="damage" else 10000.0,"",context)

static func additional_original_reward(record: Dictionary, key: String) -> float:
	if key!="adena_drop_pct": return 0.0
	# Existing enhancement/reward contract: only source ItemClass26 is Adena.
	# ValuePercent is already percentage points for the existing drop-rate sum.
	return _additional_original_operand(record,key,["IncreaseNpcItemDropAmount"],"ValuePercent",1.0,"",{},26)

static func _represented_xp(record: Dictionary, item_id: int, applied: Array) -> bool:
	# Only the exact existing ordinary-XP projection may share a key with a
	# missing absolute-XP operand. Never reinterpret a custom explicit xp field.
	var total: float = 0.0; var found: bool = false; var seen: Dictionary = {}
	for entry: Variant in applied:
		if not entry is Dictionary or entry.get("field")!="xp": continue
		var link: Dictionary = CURRENT_DEFINITIONS.row("ItemBonus",int(entry.get("item_bonus_id",-1)))
		var bonus: Dictionary = CURRENT_DEFINITIONS.row("Bonus",int(entry.get("bonus_id",-1)))
		var type: Dictionary = CURRENT_DEFINITIONS.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		var unit: Dictionary = CURRENT_DEFINITIONS.row("Unit",int(type.get("UnitID",-1)))
		if link.get("ItemClassID")!=item_id or link.get("BonusID")!=bonus.get("ID") or link.get("IsPossession")!=false or seen.has(link.get("ID")): return false
		if bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or type.get("Name")!="ExperienceAdditionPercent" or unit.get("Name")!="Percentage": return false
		var ui: Array[Dictionary] = CURRENT_DEFINITIONS.related("UIUnit","UnitID",int(unit.get("ID",-1)))
		if ui.size()!=1 or ui[0].get("Denominator")!=10000 or not CURRENT_DEFINITIONS.declared_exclusion("UIUnit",ui[0]).is_empty(): return false
		var amount: Variant = bonus.get("Value")
		if typeof(amount) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(amount)) or float(amount)!=floorf(float(amount)) or absf(float(amount))>9007199254740991.0 or entry.get("value")!=float(amount)/1000000.0: return false
		for pair: Array in [["ItemBonus",link],["Bonus",bonus],["BonusType",type],["Unit",unit]]:
			if not CURRENT_DEFINITIONS.declared_exclusion(pair[0],pair[1]).is_empty(): return false
		seen[link.ID]=true; found=true; total+=float(amount)/1000000.0
	var value: Variant = record.get("xp")
	return found and typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and is_finite(total) and float(value)==total

static func _additional_original_operand(record: Dictionary, key: String, bonus_names: Array, unit_name: String, divisor: float, status: String = "", elemental_input: Dictionary = {}, target_item: int = 0) -> float:
	if record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523" or record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1": return 0.0
	if record.get("source_equipment_status")!="mapped" or record.get("source_test_item")!=false or record.get("source_legacy_catalog_alias",false) or record.get("source_legacy_stack_variant",false): return 0.0
	var bless: Variant = record.get("source_bless_raw")
	if typeof(bless) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(bless)) or float(bless)!=floorf(float(bless)) or int(bless) not in [1,2,3]: return 0.0
	if key=="blessing_consumption_reduction_pct" and not record.get("_patch523_effective_extras",false):
		for alias: String in ["ain_consumption_reduction_pct","blessing_spend_reduction_pct"]:
			if record.has(alias): return 0.0
	var id: Variant = record.get("source_item_class_id")
	if typeof(id) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(id)) or float(id)!=floorf(float(id)) or float(id)<=0 or float(id)>9007199254740991.0: return 0.0
	if record.get("sourceId")!="m523:item:"+str(int(id)): return 0.0
	var identity: Dictionary = CURRENT_DEFINITIONS.identity()
	if identity.is_empty() or record.get("source_definition_archive")!=identity: return 0.0
	var raw: Dictionary = CURRENT_DEFINITIONS.row("ItemClass",int(id))
	if raw.is_empty() or raw!=record.get("source_original_item") or raw.get("TestItem")!=false or not CURRENT_DEFINITIONS.declared_exclusion("ItemClass",raw).is_empty(): return 0.0
	var applied: Variant = record.get("source_mapped_bonuses")
	if not applied is Array: return 0.0
	if record.has(key) and not record.get("_patch523_effective_extras",false):
		if key!="xp" or not _represented_xp(record,int(id),applied): return 0.0
	var total: float = 0.0; var evidence: Array = []
	for link: Dictionary in CURRENT_DEFINITIONS.related("ItemBonus","ItemClassID",int(id)):
		var bonus: Dictionary = CURRENT_DEFINITIONS.row("Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary = CURRENT_DEFINITIONS.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if type.get("Name") not in bonus_names: continue
		var application: Dictionary = {}; var target: Dictionary = {}
		if target_item>0:
			if bonus.get("BonusApplicationTypeID")!=5 or bonus.get("BonusApplicationTargetID")!=target_item: continue
			application = CURRENT_DEFINITIONS.row("BonusApplicationType",5)
			target = CURRENT_DEFINITIONS.row("ItemClass",target_item)
			if application.get("Name")!="ItemClass" or target.get("TestItem")!=false: return 0.0
			var category: Dictionary = CURRENT_DEFINITIONS.row("ItemCategory",int(target.get("CategoryID",-1)))
			if category.get("Name")!="Currency": return 0.0
			for pair: Array in [["BonusApplicationType",application],["ItemClass",target],["ItemCategory",category]]:
				if not CURRENT_DEFINITIONS.declared_exclusion(pair[0],pair[1]).is_empty(): return 0.0
		elif not elemental_input.is_empty():
			if bonus.get("BonusApplicationTypeID")!=3 or bonus.get("BonusApplicationTargetID")!=elemental_input.target_id: continue
			application = CURRENT_DEFINITIONS.row("BonusApplicationType",3)
			if application.get("Name")!="ElementalResistanceType" or not CURRENT_DEFINITIONS.declared_exclusion("BonusApplicationType",application).is_empty(): return 0.0
		elif status.is_empty():
			if bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0: return 0.0
		else:
			if bonus.get("BonusApplicationTypeID")!=2: continue
			application = CURRENT_DEFINITIONS.row("BonusApplicationType",2)
			if application.get("Name")!="SpecialResistanceType": return 0.0
			target = CURRENT_DEFINITIONS.row("SpecialResistanceType",int(bonus.get("BonusApplicationTargetID",-1)))
			if str(target.get("Name","")).to_lower()!=status: continue
			if not CURRENT_DEFINITIONS.declared_exclusion("BonusApplicationType",application).is_empty() or not CURRENT_DEFINITIONS.declared_exclusion("SpecialResistanceType",target).is_empty(): return 0.0
		if link.get("IsPossession")!=false: return 0.0
		var unit: Dictionary = CURRENT_DEFINITIONS.row("Unit",int(type.get("UnitID",-1)))
		if unit.get("Name")!=unit_name: return 0.0
		if key=="xp":
			var ui: Array[Dictionary] = CURRENT_DEFINITIONS.related("UIUnit","UnitID",int(unit.get("ID",-1)))
			if ui.size()!=1 or ui[0].get("Denominator")!=10000 or not CURRENT_DEFINITIONS.declared_exclusion("UIUnit",ui[0]).is_empty(): return 0.0
		for pair: Array in [["ItemBonus",link],["Bonus",bonus],["BonusType",type],["Unit",unit]]:
			if not CURRENT_DEFINITIONS.declared_exclusion(pair[0],pair[1]).is_empty(): return 0.0
		for represented: Variant in applied:
			if represented is Dictionary and represented.get("bonus_id")==bonus.get("ID"): return 0.0
		var value: Variant = bonus.get("Value")
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return 0.0
		if (unit_name in ["Value","Weight"] or key.ends_with("_crit")) and (float(value)!=floorf(float(value)) or absf(float(value))>9007199254740991.0): return 0.0
		total+=float(value)/divisor
		evidence.append({"link":link,"bonus":bonus,"type":type,"unit":unit,"application":application,"target":target,"consumer_elemental_input":elemental_input})
	if evidence.is_empty() or not is_finite(total): return 0.0
	if (divisor==1.0 or unit_name=="Weight") and absf(total)>9007199254740991.0: return 0.0
	original_percent_input_evidence[str(int(id))+":"+key] = {"source":identity,"item_class_id":id,"field":key,"effects":evidence,"source_unit":unit_name,"divisor":divisor,"value":total}
	return total

# Item option adapter: typed record fields take precedence over legacy Korean
# descriptions. This keeps preexisting catalog records and save data unchanged.
const ATTRIBUTES: Dictionary = {
	"STR": ["strFlat", "STR", "str"],
	"DEX": ["dexFlat", "DEX", "dex"],
	"CON": ["conFlat", "CON", "con"],
	"INT": ["intFlat", "INT", "int"],
	"WIS": ["wisFlat", "WIS", "wis"],
	"CHA": ["chaFlat", "CHA", "cha"]
}

static func _signed_integer(raw: String) -> int:
	var value: String = raw.strip_edges()
	var sign: int = 1
	if value.begins_with("-"):
		sign = -1
		value = value.substr(1).strip_edges()
	elif value.begins_with("+"):
		value = value.substr(1).strip_edges()
	var digits: String = ""
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1)
		if character >= "0" and character <= "9":
			digits += character
		else:
			break
	return sign * int(digits) if not digits.is_empty() else 0

static func _description_bonus(record: Dictionary, label: String) -> int:
	for value: String in str(record.get("desc", "")).split("·"):
		var segment: String = value.strip_edges()
		if segment.begins_with(label + " ") or segment.begins_with(label + "+") or segment.begins_with(label + "-"):
			return _signed_integer(segment.substr(label.length()))
	return 0

static func _option(record: Dictionary, keys: Array, desc_label: String = "") -> int:
	for value: Variant in keys:
		var key: String = str(value)
		if record.has(key):
			return int(record.get(key, 0))
	if desc_label.is_empty():
		return 0
	return _description_bonus(record, desc_label)

static func attribute(record: Dictionary, stat: String) -> int:
	if not ATTRIBUTES.has(stat):
		return 0
	return _option(record, ATTRIBUTES[stat], stat)

static func accuracy(record: Dictionary, attack_kind: String) -> int:
	var physical: int = 0
	if attack_kind != "magic":
		physical = _option(record, ["hit", "accuracy", "accuracy_bonus"], "명중")
	match attack_kind:
		"ranged":
			return physical + _option(record, ["rangedHit", "ranged_hit", "ranged_accuracy"], "원거리 명중")
		"magic":
			return _option(record, ["magicHit", "magic_hit", "magic_accuracy"], "마법 명중")
		_:
			return physical + _option(record, ["meleeHit", "melee_hit", "melee_accuracy"], "근거리 명중")

static func additional_damage(record: Dictionary, attack_kind: String) -> int:
	if attack_kind == "magic":
		return _option(record, ["magicDamage", "magic_damage"], "마법 대미지")
	var shared: int = _option(record, ["additionalDamage", "additional_damage", "extraDamage", "extra_damage"], "추가 대미지")
	if attack_kind == "ranged":
		return shared + _option(record, ["rangedDamage", "ranged_damage"], "원거리 대미지")
	return shared + _option(record, ["meleeDamage", "melee_damage"], "근거리 대미지")

# The weapon's size damage is a separate 1..N roll, never a fixed part
# of the melee/ranged character sheet. Typed fields win over source-stat and
# legacy descriptions. "atk" is only a fallback for weapons with no size data;
# old catalog entries sometimes store small damage + flat bonus together in it.
static func weapon_size_damage(record: Dictionary, is_large: bool) -> int:
	if str(record.get("slot", "")) != "weapon":
		return 0
	if record.has("small_damage") and record.has("large_damage"):
		return maxi(0, int(record.get("large_damage" if is_large else "small_damage", 0)))
	var small_named: int = _description_bonus(record, "작은 대상 대미지")
	var large_named: int = _description_bonus(record, "큰 대상 대미지")
	if small_named > 0 and large_named > 0:
		return maxi(0, large_named if is_large else small_named)
	# Inven source "stat": "54 / 35"; earlier game DB "desc": "21/13 · ...".
	for pair: String in [str(record.get("stat", "")).strip_edges(), str(record.get("desc", "")).split("·")[0].strip_edges()]:
		var parts: PackedStringArray = pair.split("/")
		if parts.size() == 2:
			var small: String = parts[0].strip_edges()
			var large: String = parts[1].strip_edges()
			if small.is_valid_int() and large.is_valid_int():
				return maxi(0, int(large if is_large else small))
	return maxi(0, int(record.get("atk", 0)))

# Backward-compatible audit helper; live attacks use weapon_size_damage rolls.
static func weapon_size_adjustment(record: Dictionary, is_large: bool) -> int:
	if not is_large:
		return 0
	return weapon_size_damage(record, true) - weapon_size_damage(record, false)

static func _weight_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0.0 and float(value) <= 9007199254740991.0

static func current_source_weight_input(record: Dictionary, estimate: Dictionary) -> Dictionary:
	# UNVERIFIED: only the current original-backed native DTO may use this
	# explicit TWILIGHT estimate. This does not establish a native weight unit.
	var ignored: Dictionary = {"applicable":false}
	if record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or typeof(record.get("source_m_native_item")) != TYPE_BOOL or not bool(record.source_m_native_item) or typeof(record.get("source_test_item")) != TYPE_BOOL or bool(record.source_test_item):
		return ignored
	if record.get("source_projection") != "current523_original_typed_game_dto_v1": return ignored
	var item_id: Variant = record.get("source_item_class_id")
	if not _weight_integer(item_id) or int(item_id) <= 0 or record.get("source_weight_unit") != "unverified_source_units":
		return ignored
	if record.get("source_legacy_stack_variant",false) or record.get("source_legacy_catalog_alias",false): return ignored
	var blessing: Variant = record.get("source_bless_raw")
	if not _weight_integer(blessing) or int(blessing) not in [1,2,3]: return ignored
	# Exact published patch523_monster_drops.variant_item/equipment contract:
	# equipment keeps the base ID; only non-equipment states 2/3 add a suffix.
	var is_equipment: bool
	if record.get("crafting_scroll",false):
		is_equipment = bool(record.get("drop_as_equipment",false)) and record.get("slot","") == "consumable"
	else:
		is_equipment = str(record.get("slot","")) not in ["","currency","consumable","material"]
	var expected_id: String = "m523:item:"+str(int(item_id))
	if not is_equipment and int(blessing) in [2,3]: expected_id += ":bless:"+str(int(blessing))
	if record.get("sourceId") != expected_id:
		return ignored
	var identity: Dictionary = CURRENT_DEFINITIONS.identity()
	if identity.is_empty() or record.get("source_definition_archive") != identity or not record.get("source_original_item") is Dictionary:
		return ignored
	var raw: Dictionary = record.source_original_item
	if raw.is_empty() or raw.get("ID") != int(item_id) or typeof(raw.get("TestItem")) != TYPE_BOOL or bool(raw.TestItem) or raw != CURRENT_DEFINITIONS.row("ItemClass",int(item_id)) or not _weight_integer(record.get("source_weight")) or record.get("source_weight") != raw.get("Weight"):
		return ignored
	if not CURRENT_DEFINITIONS.declared_exclusion("ItemClass",raw).is_empty():
		return {"applicable":true,"ok":false,"problem":"명시적으로 제외된 원문 아이템의 무게 입력입니다."}
	if not _weight_integer(raw.get("Weight")):
		return {"applicable":true,"ok":false,"problem":"현재 원문 무게가 비음수 정수가 아닙니다."}
	if estimate.get("mode") != "twilight_estimate" or estimate.get("rounding") != "ceil" or estimate.get("source_archive_sha256") != identity.get("source_sha256") or not _weight_integer(estimate.get("points_numerator")) or not _weight_integer(estimate.get("source_units_denominator")):
		return {"applicable":true,"ok":false,"problem":"명시적 TWILIGHT 원문 무게 추정 설정이 없거나 잘못됐습니다."}
	var numerator: int = int(estimate.points_numerator)
	var denominator: int = int(estimate.source_units_denominator)
	if numerator <= 0 or denominator <= 0:
		return {"applicable":true,"ok":false,"problem":"TWILIGHT 무게 추정 분자·분모는 양의 정수여야 합니다."}
	var original_weight: int = int(raw.Weight)
	# Check multiplication before performing integer ceil; never round the raw
	# source field or use a floating-point conversion factor.
	@warning_ignore("integer_division")
	var maximum_original: int = 9223372036854775807 / numerator
	if original_weight > maximum_original:
		return {"applicable":true,"ok":false,"problem":"TWILIGHT 무게 추정 정수 곱셈 범위를 초과합니다."}
	var product: int = original_weight * numerator
	@warning_ignore("integer_division")
	var points: int = product / denominator
	if product % denominator != 0:
		if points == 9223372036854775807:
			return {"applicable":true,"ok":false,"problem":"TWILIGHT 무게 추정 올림 범위를 초과합니다."}
		points += 1
	return {"applicable":true,"ok":true,"weight":points}

static func item_weight(record: Dictionary, type_defaults: Dictionary = {}) -> int:
	if record.has("weight"):
		return maxi(0, int(record.get("weight", 0)))
	return maxi(0, int(type_defaults.get(str(record.get("type", "")), 0)))

static func carrying_capacity(effective_con: int) -> int:
	return 2500 + maxi(0, effective_con) * 100

static func encumbrance_multiplier(weight: int, capacity: int) -> float:
	if weight >= capacity * 2:
		return 0.50
	if weight >= int(ceil(float(capacity) * 1.5)):
		return 0.65
	if weight >= capacity:
		return 0.85
	return 1.0
