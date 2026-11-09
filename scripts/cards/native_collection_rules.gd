extends "res://scripts/cards/collection_rules.gd"
## Source-only definitions. Old numeric keys are never reinterpreted as BuffCard IDs.
const Conditions=preload("res://scripts/cards/source_collection_conditions.gd")
var conditions=Conditions.new()

const NATIVE_RECORD_FIELDS: Dictionary = {
	"melee_evasion:flat":"dg",
	"magic_critical_rate:percent":"magic_crit",
	"fear_hit:percent":"fear_accuracy",
	"fear_resistance:percent":"fear_resistance",
	"hold_hit:percent":"hold_accuracy"
}
const NATIVE_CATALOG_FIELDS: Dictionary={"pve_damage_reduction_pct":"pve_damage_reduction:percent","damage_reduction_ignore":"damage_reduction_ignore:flat","melee_reduction_ignore":"melee_reduction_ignore:flat","ranged_reduction_ignore":"ranged_reduction_ignore:flat","magic_reduction_ignore":"magic_reduction_ignore:flat"}
const RUNTIME_EFFECT_CODES: Array[String]=["melee_evasion_ignore:flat","ranged_evasion_ignore:flat","damage_reduction_ignore:percent","melee_reduction_ignore:percent","ranged_reduction_ignore:percent","magic_reduction_ignore:percent","pve_damage_amplification:percent","melee_critical_resistance:percent","ranged_critical_resistance:percent","magic_critical_resistance:percent","elemental_critical_resistance:percent","magic_heal:percent","weapon_block:percent","absolute_mp_regeneration:flat","blessing_charge:percent","final_blow_damage:flat","final_blow_probability:percent","final_blow_amplification:percent","while_stun_damage_reduction:flat","while_fear_damage_reduction:flat","stacked_damage_reduction:percent"]
const LOCAL_POLICY_CODES: Array[String]=["life:flat","death:flat","magic_penetration:percent","reduction_efficiency:percent","physical_magic_defense:percent","final_blow_resistance:percent","ranged_burst_reduction:flat","spell_63_damage:flat","spell_37921_damage:flat","spell_77761_damage:flat","spell_120712_damage:flat","spell_17564_hit:percent"]
const TYPED_DAMAGE_CODES: Array[String]=["melee_damage_reduction:flat","ranged_damage_reduction:flat","magic_damage_reduction:flat","melee_damage_reduction:percent","ranged_damage_reduction:percent","magic_damage_reduction:percent","critical_damage_reduction:flat","poison_damage_reduction:flat","poison_damage_reduction:percent"]
static func supports_extra_code(code: String) -> bool:
	return NATIVE_RECORD_FIELDS.has(code) or NATIVE_CATALOG_FIELDS.values().has(code) or TYPED_DAMAGE_CODES.has(code) or RUNTIME_EFFECT_CODES.has(code) or LOCAL_POLICY_CODES.has(code)

# Existing World readers consume these exact record fields. They are kept
# separate from equipment-collection policy and never flattened across scopes.
static func stat_record_additions(totals: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for code: String in NATIVE_RECORD_FIELDS:
		if totals.has(code):result[NATIVE_RECORD_FIELDS[code]]=totals[code]
	return result

const SourceSlots=preload("res://scripts/cards/option_slot_definitions.gd")
var native_option_bindings: Dictionary={}

const TIME_POLICY: String = "permanent_user_requested_time_override"
## Special/unknown conditions and unsupported rewards remain visible and blocked.

static func accepts_catalog(catalog: Dictionary) -> bool:
	for category: String in Cards.CATEGORIES:
		var records: Array = catalog.get(category, [])
		if records.is_empty(): return false
		for record: Dictionary in records:
			if not preload("res://scripts/lineagem_base508.gd").native(record): return false
	return true

func configure(data: Dictionary, catalog: Dictionary) -> bool:
	definitions.clear(); availability.clear(); error = ""
	native_option_bindings.clear()
	# UNVERIFIED: saved m508/m523 IDs remain the caller ABI. Original slot
	# declarations supply the current binding without requiring an old card pack.
	for category: String in Cards.CATEGORIES:
		for record: Dictionary in catalog.get(category,[]):
			var identity: String=Cards.card_id(record)
			var slot: Dictionary=SourceSlots.group_for(identity,1)
			if slot.is_empty():continue
			native_option_bindings[identity]={"group_id":int(slot.group.ID),"card_id":int(slot.card.ID),"limits":[slot.card.ServerLimitSetID,slot.group.ServerLimitsetID]}
	conditions.configure(data.get("source_server_limits",[]))
	var snapshot: String = str(data.get("source_snapshot", ""))
	if snapshot not in ["base508", "patch523"] or not accepts_catalog(catalog):
		return _fail("원본 카드 컬렉션과 카드 정체성이 일치하지 않습니다")
	var known: Dictionary = {}
	for category: String in Cards.CATEGORIES:
		known[category] = {}
		for record: Dictionary in catalog[category]: known[category][Cards.card_id(record)] = record
	var seen: Dictionary = {}
	for value: Variant in data.get("collections", []):
		if not value is Dictionary: return _fail("원본 컬렉션 정의 형식 오류")
		var row: Dictionary = value.duplicate(true)
		var identity: String = str(row.get("id", ""))
		var category: String = str(row.get("category", ""))
		if not identity.begins_with("base508:collection:") or seen.has(identity) or not known.has(category): return _fail("원본 컬렉션 ID/분류 오류")
		seen[identity] = true
		if row.get("source", {}).get("snapshot", "") != snapshot or not row.get("source_original") is Dictionary: return _fail("원본 컬렉션 출처 누락")
		if not row.get("requirements") is Array or row.requirements.is_empty() or not row.get("effects") is Array: return _fail("원본 컬렉션 조건/보상 누락")
		# User explicitly removed time limits. Preserve every original date row
		# and retain server/awakening restrictions; no save mutation is involved.
		row["time_policy"] = TIME_POLICY
		row["time_label"] = "상시"
		var problems: Array[String] = []
		if int(row.source_original.get("ServerLimitSetID", 0)) != 0: problems.append("native_server_context_required")
		var members: Dictionary = {}
		for requirement: Dictionary in row.requirements:
			var key: String = str(requirement.get("id", ""))
			var member: Dictionary = requirement.get("source_original", {})
			# Collection deck and member card deck are distinct source identities.
			# Current523 has32 members from another deck; join the member's own ID.
			var member_category: String = str(requirement.get("category", ""))
			if not known.has(member_category) or not known[member_category].has(key): return _fail("원본 컬렉션 구성 카드 정체성 누락")
			var record: Dictionary = known[member_category][key]
			var expected_deck: int = {"변신":1,"마법인형":2,"성물":98}[member_category]
			if int(record.get("source_deck_id", expected_deck)) != expected_deck:
				return _fail("원본 구성 카드 덱 불일치")
			if int(record.get("source_card_id", -1)) != int(member.get("BuffCardID", -2)): return _fail("원본 BuffCardID 조인 불일치")
			if int(member.get("BuffCardCollectionID", -1)) != int(row.source_original.get("ID", -2)) or members.has(key): return _fail("원본 컬렉션 구성 중복/세트 불일치")
			members[key] = true
			if int(member.get("ServerLimitSetID", 0)) != 0 and not problems.has("native_server_context_required"): problems.append("native_server_context_required")
			if bool(member.get("IsAwaken", false)) and not problems.has("native_awakening_required"): problems.append("native_awakening_required")
		if row.effects.is_empty(): problems.append("native_reward_missing")
		for effect: Dictionary in row.effects:
			var code: String = effect_code(effect)
			if code=="stacked_damage_reduction:percent" and not local_damp_supported(effect):problems.append("native_source_target_missing:DamageDampOption:unapproved_local_policy")
			if not interval_supported(effect) and (not bool(effect.get("native_supported", false)) or (not ExistingStats.SUPPORTED.has(code) and not EXTRA_EFFECTS.has(code) and not supports_extra_code(code))):
				var native: Dictionary = effect.get("source_original",{})
				var target: Dictionary = native.get("application_target",{})
				if target.get("resolved",true)==false:
					problems.append("native_source_target_missing:"+str(target.get("target_table",""))+":"+str(target.get("target_id","")))
				elif not (native.get("nested_intervals",[]) as Array).is_empty():
					problems.append("native_interval_runtime_required")
				else:problems.append("effect_unsupported:" + code)
			var amount: Variant = effect.get("value")
			if not (amount is int or amount is float) or not is_finite(float(amount)): return _fail("원본 보상 수치 오류")
		availability[identity] = problems
		definitions.append(row)
	return true

func derive(card_state: Dictionary) -> Dictionary:
	# Rows share their source sub-values with the definitions (view_row); this
	# only reads those and writes the row's and requirements' own keys.
	var result: Dictionary = super.derive(card_state)
	var context: Dictionary=card_state.get("source_server_context",{})
	# Only exact original SlotIndex1 option bindings can satisfy IsAwaken.
	# Numeric legacy flags, card skill awakening and aura never enter this ledger.
	var option: Dictionary=card_state.get("source_option_awakening",{})
	var bound: bool=option.get("source_snapshot","")=="base508" and option.get("kind","")=="BuffCardOptionAwakenGroup.SlotIndex1"
	for row: Dictionary in result.rows:
		if row.problems.has("native_server_context_required"):
			row.problems.erase("native_server_context_required")
			var limits: Array[int]=[]
			var parent_limit: int=int(row.source_original.get("ServerLimitSetID",0))
			if parent_limit>0:limits.append(parent_limit)
			for requirement: Dictionary in row.requirements:
				var member_limit: int=int(requirement.source_original.get("ServerLimitSetID",0))
				if member_limit>0 and not limits.has(member_limit):limits.append(member_limit)
			row["server_evaluations"]=[]
			for limit_id: int in limits:
				var evaluation: Dictionary=conditions.evaluate(limit_id,context)
				row.server_evaluations.append(evaluation)
				var code: String={"context_missing":"native_server_context_required","definition_missing":"native_server_definition_missing","ineligible":"native_server_ineligible"}.get(str(evaluation.status),"")
				if not code.is_empty() and not row.problems.has(code):row.problems.append(code)
		if row.problems.has("native_awakening_required"):
			var met: int=0
			var all_bound: bool=bound
			for requirement: Dictionary in row.requirements:
				if bool(requirement.get("awakened",false)):
					var key: String=str(requirement.id)
					var expected: Dictionary=native_option_bindings.get(key,{})
					var binding: Dictionary=option.get("bindings",{}).get(key,{})
					var matched: bool=bound and not expected.is_empty() and int(binding.get("group_id",-1))==int(expected.group_id) and int(binding.get("card_id",-1))==int(requirement.source_original.BuffCardID)
					all_bound=all_bound and matched
					var permanent: bool=card_state.get("owned",{}).get(requirement.category,{}).get(key,false)==true
					requirement["met"]=matched and permanent and option.get("earned",{}).get(requirement.category,{}).get(key,false)==true
					requirement["awakening_source"]="BuffCardOptionAwakenGroup.SlotIndex1" if matched else "unconnected"
					var allowed: bool=bool(binding.get("eligible",false))
					for raw_limit: Variant in expected.get("limits",[]):
						if conditions.evaluate(int(raw_limit),context).status not in ["unrestricted","eligible"]:allowed=false
					if matched and not allowed and not row.problems.has("native_option_condition_required"):row.problems.append("native_option_condition_required")
				if bool(requirement.met):met+=1
			if all_bound:row.problems.erase("native_awakening_required")
			row["met_count"]=met
			row["conditions_met"]=met==row.requirements.size()
		row["available"]=row.problems.is_empty()
		row["completed"]=row.available and row.conditions_met
	# One collection contributes each source reward once. A server change must
	# remove prior conditional totals rather than accumulating another award.
	result.totals={};result.completed={}
	for row: Dictionary in result.rows:
		if not row.completed:continue
		result.completed[str(row.id)]=true
		for effect: Dictionary in row.effects:
			if interval_supported(effect):continue
			var code: String=effect_code(effect)
			result.totals[code]=float(result.totals.get(code,0))+float(effect.value)
	return result

# TWILIGHT compatibility policy, not a recovered client formula: ceil the
# clamped living HP percentage, inclusive integer source bounds, no dead bonus.
# Each eligible collection contributes one matching branch; gaps stay zero.
const HP_POLICY: String = "twilight_ceil_living_hp_percent_inclusive_v1"
static func interval_supported(effect: Dictionary) -> bool:
	var raw: Dictionary=effect.get("source_original",{})
	if raw.get("bonus_type",{}).get("Name","")!="HPIntervalBonus" or raw.get("unit",{}).get("Name","")!="IntervalBonusCategoryID":return false
	var branches: Array=raw.get("nested_intervals",[])
	if branches.is_empty():return false
	var occupied: Dictionary={}
	for branch: Dictionary in branches:
		var low: int=int(branch.get("Low",-1));var high: int=int(branch.get("High",101))
		if low<0 or high>100 or low>high or int(branch.get("IntervalBonusCategory",-1))!=int(raw.bonus.Value):return false
		if branch.get("bonus_type",{}).get("Name","")!="SpecialResistance" or branch.get("application_type",{}).get("Name","")!="SpecialResistanceType":return false
		if branch.get("application_target",{}).get("Name","") not in ["Stun","Fear"] or branch.get("unit",{}).get("Name","")!="Percentage":return false
		var target: Dictionary=branch.application_target
		if int(branch.bonus.BonusApplicationTypeID)!=int(branch.application_type.ID) or int(branch.bonus.BonusApplicationTargetID)!=int(target.ID) or int(branch.bonus.BonusTypeID)!=int(branch.bonus_type.ID) or int(branch.bonus_type.UnitID)!=int(branch.unit.ID):return false
		if float(branch.get("ui_unit",{}).get("Denominator",0))<=0 or not is_finite(float(branch.bonus.get("Value",NAN))):return false
		for percent: int in range(low,high+1):
			if occupied.has(percent):return false
			occupied[percent]=true
	return true

static func interval_effects(effect: Dictionary, hp: int, maximum: int, round_up: bool=true) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not interval_supported(effect) or maximum<=0 or hp<=0:return result
	var ratio: float=100.0*clampi(hp,0,maximum)/maximum
	var percent: int=int(ceil(ratio) if round_up else floor(ratio))
	for branch: Dictionary in effect.source_original.nested_intervals:
		if percent<int(branch.Low) or percent>int(branch.High):continue
		var key: String=str(branch.application_target.Name).to_lower()+"_resistance"
		var amount: float=float(branch.bonus.Value)/float(branch.ui_unit.Denominator)
		result.append({"key":key,"unit":"percent","value":amount,"label":"HP 구간 · "+("스턴" if key=="stun_resistance" else "공포")+" 내성 +"+str(amount)+"%","source_interval_id":int(branch.ID),"hp_policy":HP_POLICY if round_up else HP_POLICY.replace("ceil","floor")})
	return result

static func local_damp_supported(effect: Dictionary) -> bool:
	var raw: Dictionary=effect.get("source_original",{})
	return effect.get("runtime_policy","")=="twilight_target13_stacked_reduction_v1" and raw.get("bonus_type",{}).get("Name","")=="DamageDampOption" and raw.get("application_type",{}).get("Name","")=="DamageDampOption" and int(raw.get("bonus",{}).get("BonusApplicationTargetID",0))==13 and raw.get("unit",{}).get("Name","")=="Percentage"

