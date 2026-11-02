extends "res://scripts/cards/collection_rules.gd"
## Source-only definitions. Old numeric keys are never reinterpreted as BuffCard IDs.
const NATIVE_RECORD_FIELDS: Dictionary = {
	"melee_evasion:flat":"dg",
	"magic_critical_rate:percent":"magic_crit",
	"fear_hit:percent":"fear_accuracy",
	"fear_resistance:percent":"fear_resistance",
	"hold_hit:percent":"hold_accuracy"
}
const NATIVE_CATALOG_FIELDS: Dictionary={"pve_damage_reduction_pct":"pve_damage_reduction:percent"}
static func supports_extra_code(code: String) -> bool:
	return NATIVE_RECORD_FIELDS.has(code) or NATIVE_CATALOG_FIELDS.values().has(code)

# Existing World readers consume these exact record fields. They are kept
# separate from equipment-collection policy and never flattened across scopes.
static func stat_record_additions(totals: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for code: String in NATIVE_RECORD_FIELDS:
		if totals.has(code):result[NATIVE_RECORD_FIELDS[code]]=totals[code]
	return result

const TIME_POLICY: String = "permanent_user_requested_time_override"
## Special/unknown conditions and unsupported rewards remain visible and blocked.

static func accepts_catalog(catalog: Dictionary) -> bool:
	for category: String in Cards.CATEGORIES:
		var records: Array = catalog.get(category, [])
		if records.is_empty(): return false
		for record: Dictionary in records:
			if record.get("source", "") != "lineagem_base508": return false
	return true

func configure(data: Dictionary, catalog: Dictionary) -> bool:
	definitions.clear(); availability.clear(); error = ""
	if data.get("source_snapshot", "") != "base508" or not accepts_catalog(catalog):
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
		if row.get("source", {}).get("snapshot", "") != "base508" or not row.get("source_original") is Dictionary: return _fail("원본 컬렉션 출처 누락")
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
			if str(requirement.get("category", "")) != category or not known[category].has(key): return _fail("원본 컬렉션 구성 카드 정체성 누락")
			var record: Dictionary = known[category][key]
			if int(record.get("source_card_id", -1)) != int(member.get("BuffCardID", -2)): return _fail("원본 BuffCardID 조인 불일치")
			if int(member.get("BuffCardCollectionID", -1)) != int(row.source_original.get("ID", -2)) or members.has(key): return _fail("원본 컬렉션 구성 중복/세트 불일치")
			members[key] = true
			if int(member.get("ServerLimitSetID", 0)) != 0 and not problems.has("native_server_context_required"): problems.append("native_server_context_required")
			if bool(member.get("IsAwaken", false)) and not problems.has("native_awakening_required"): problems.append("native_awakening_required")
		if row.effects.is_empty(): problems.append("native_reward_missing")
		for effect: Dictionary in row.effects:
			var code: String = effect_code(effect)
			if not bool(effect.get("native_supported", false)) or (not ExistingStats.SUPPORTED.has(code) and not EXTRA_EFFECTS.has(code) and not supports_extra_code(code)):
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
	var result: Dictionary = super.derive(card_state)
	# Native IsAwaken is distinct from TWILIGHT option-awakening. Until the
	# source awakening ledger is connected, an owned-only card cannot satisfy it.
	for row: Dictionary in result.rows:
		if not (availability[str(row.id)] as Array).has("native_awakening_required"): continue
		var met: int = 0
		for requirement: Dictionary in row.requirements:
			if bool(requirement.get("awakened", false)): requirement["met"] = false
			if bool(requirement.met): met += 1
		row["met_count"] = met
		row["conditions_met"] = met == row.requirements.size()
	return result
