extends RefCounted
## Pure source diagnostics. No inventory, RNG, growth or save mutations.
const DATA=preload("res://data/cards/patch523_skill_growth_readiness.json")

static func validate_evidence() -> String:
	var evidence: Dictionary=DATA.data
	if int(evidence.get("schema",0))!=1 or evidence.get("source_snapshot","")!="patch523" or evidence.get("diagnostic_only",false)!=true:return "스킬 성장 진단 형식 오류"
	if not evidence.get("approved_material_item_class_ids") is Array or not evidence.approved_material_item_class_ids.is_empty():return "미확인 경험치 재료 승인 금지"
	var counts: Dictionary=evidence.get("evidence_counts",{})
	if int(counts.get("skill_exp_card_items",0))!=10 or int(counts.get("test_exp_card_items",0))!=20 or int(counts.get("exp_card_item_bonus_rows",-1))!=0 or int(counts.get("awakening_deck_growth_mapping_rows",-1))!=0:return "스킬 성장 원본 경계 오류"
	if int(counts.get("skill_awaken_value_type_tables",-1))!=0:return "스킬 각성 타입 정의 재검토 필요"
	return ""

static func view() -> Dictionary:
	var evidence: Dictionary=DATA.data
	var error: String=validate_evidence()
	return {"can_feed":false,"can_enhance":false,"diagnostic_only":true,"source_snapshot":"patch523","material_status":str(evidence.material_status),"probability_status":str(evidence.probability_status),"blocked_reason":str(evidence.blocked_reason) if error.is_empty() else error,"reasons":evidence.reasons.duplicate(true),"evidence_counts":evidence.evidence_counts.duplicate(true),"approved_material_item_class_ids":[],"evidence_error":error}

static func material_status(item_class_id: int) -> Dictionary:
	# Even an unknown ID remains rejected until a material conversion contract is verified.
	var result: Dictionary={"item_class_id":item_class_id,"approved":false,"status":"source_material_contract_unresolved","reasons":["material_exp_conversion_unresolved"]}
	for item: Dictionary in DATA.data.rejected_exp_card_items:
		if int(item.item_class_id)==item_class_id:
			result.status="source_test_exp_card_rejected"
			result.system=str(item.system)
			result.source_test_item=bool(item.source_item.TestItem)
			result.item_bonus_rows=int(item.item_bonus_rows)
			result.reasons=item.reasons.duplicate(true)
			break
	return result
