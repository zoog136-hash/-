extends RefCounted
## Outcome calculation only. The source/ownership adapter authorizes use and
## stages costs; this module neither selects items, draws RNG nor saves.
const REFERENCE: String = "https://lounge.plaync.com/feed/76773?country=KR&locale=ko-KR"
const SUCCESS_PERCENT: Dictionary = {7:7, 8:15, 9:33}
const POLICY_ID: String = "twilight.honing.failure-estimate.v1"

static func resolve(enchant: int, roll_percentile: int) -> Dictionary:
	if not SUCCESS_PERCENT.has(enchant) or roll_percentile < 0 or roll_percentile >= 100:
		return {"ok":false,"code":"unsupported_enchant_or_roll"}
	var success: bool = roll_percentile < int(SUCCESS_PERCENT[enchant])
	return {"ok":true,"success":success,"roll_percentile":roll_percentile,
		"success_percent":SUCCESS_PERCENT[enchant],"success_evidence":"official_public",
		"reference":REFERENCE,"materials_consumed_percent":100,"materials_refund_percent":0,
		"target_destroyed":false,"enchant_delta":0,
		"failure_policy":{"id":POLICY_ID,"evidence":"estimate_after_public_search",
			"destruction_percent":0,"enchant_loss":0,"materials_consumed_percent":100,
			"materials_refund_percent":0,"original_verified":false}}

static func target_candidate(target: Dictionary, source_binding: Dictionary, roll_percentile: int) -> Dictionary:
	# The caller must obtain and validate these identifiers from the private
	# original tables. Merely passing them is NOT source verification/approval.
	var record: Variant = target.get("record")
	if not record is Dictionary or target.has("honing"): return {"ok":false,"code":"invalid_or_already_honed_target"}
	for key: String in ["entity_id","honing_id","item_class_id","epithet_id"]:
		if not _positive(source_binding.get(key)): return {"ok":false,"code":"missing_source_binding"}
	if record.get("source_item_class_id") != source_binding.item_class_id:
		return {"ok":false,"code":"target_source_mismatch"}
	var bonuses: Variant = source_binding.get("bonus_ids")
	if not bonuses is Array or bonuses.is_empty(): return {"ok":false,"code":"missing_source_bonus"}
	for bonus: Variant in bonuses:
		if not _positive(bonus): return {"ok":false,"code":"invalid_source_bonus"}
	var level: Variant = target.get("level")
	if not _positive(level): return {"ok":false,"code":"invalid_enchant"}
	var outcome: Dictionary = resolve(int(level),roll_percentile)
	if not outcome.ok: return outcome
	var candidate: Dictionary = target.duplicate(true)
	if outcome.success:
		candidate.honing = {"source_binding":source_binding.duplicate(true),
			"policy_id":POLICY_ID,"outcome_evidence":outcome.duplicate(true)}
	# No display name/record stat is overwritten. The future equipment/recipe
	# adapter must resolve the original Epithet/Bonus IDs from the verified pack.
	return {"ok":true,"target":candidate,"outcome":outcome,"use_authorized":false}

static func _positive(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value > 0 and value <= 9007199254740991 and float(value) == floorf(float(value))
