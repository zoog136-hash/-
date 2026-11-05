extends SceneTree
const Growth=preload("res://scripts/cards/skill_growth_readiness.gd")
const Evidence=preload("res://data/cards/patch523_skill_growth_readiness.json")
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message)
func _initialize() -> void:
	check(Growth.validate_evidence().is_empty(),"source diagnostic boundary validates")
	var snapshot: Dictionary=Growth.view()
	check(not snapshot.can_feed and not snapshot.can_enhance,"unverified source rules cannot authorize either operation")
	check(snapshot.diagnostic_only and snapshot.evidence_error.is_empty(),"readiness is explicitly diagnostic")
	check(snapshot.material_status=="source_material_contract_unresolved" and snapshot.probability_status=="source_enhancement_probability_unresolved","separate stable blocker statuses")
	check(snapshot.blocked_reason.contains("경험치") and snapshot.blocked_reason.contains("실패"),"concise Korean UI blocker covers both operations")
	check(snapshot.approved_material_item_class_ids.is_empty(),"no material IDs approved")
	var counts: Dictionary=snapshot.evidence_counts
	check(int(counts.spell_deck_experience_mapping_rows)==484 and int(counts.spell_deck_level_up_mapping_rows)==468 and int(counts.awakening_deck_growth_mapping_rows)==0,"deck41 growth mappings excluded from awakening")
	check(int(counts.cast_proc_rows)==300 and int(counts.selection_rows)==77 and int(counts.placeholder_selection_rows)==5,"proc, selection and placeholders remain distinct")
	var skill_count: int=0;var option_count: int=0
	for material: Dictionary in Evidence.data.rejected_exp_card_items:
		var result: Dictionary=Growth.material_status(int(material.item_class_id))
		check(not result.approved and result.status=="source_test_exp_card_rejected" and result.source_test_item and result.item_bonus_rows==0,"source test EXP material rejected "+str(material.item_class_id))
		if result.system=="skill":skill_count+=1
		else:option_count+=1
	check(skill_count==10 and option_count==10,"all twenty source test EXP card identities checked")
	for id: int in [0,-1,75184,75194,95624,118992,243043,98454,346901,999999999]:
		check(not Growth.material_status(id).approved,"unknown and non-EXP sources cannot grant growth "+str(id))
	var boundary: Dictionary=Evidence.data.probability_boundaries
	check(boundary.enhancement_probability==null and boundary.enhancement_total_probability==null,"no invented enhancement odds or denominator")
	check(boundary.selection_use=="candidate_selection_only" and boundary.cast_use=="skill_activation_only","selection and proc odds cannot be repurposed")
	check(Evidence.data.book_acquisition_raw_summary.shared_slot_semantics=="not_inferred","recipe slot semantics preserved as unresolved")
	snapshot.reasons.clear();snapshot.evidence_counts.clear();snapshot.approved_material_item_class_ids.append(193364)
	var fresh: Dictionary=Growth.view()
	check(fresh.reasons.size()==6 and fresh.evidence_counts.size()>0 and fresh.approved_material_item_class_ids.is_empty(),"view mutation cannot alter shared source evidence")
	print("SKILL_GROWTH_READINESS ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
