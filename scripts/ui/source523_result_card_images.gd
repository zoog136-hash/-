extends RefCounted
## Exact selected result/phase pixels. Does not invent a source-to-Face transform.
const CARDS = preload("res://scripts/lineagem_base508.gd")
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const OWNER_PATH = "res://scripts/ui/card_reveal_card.gd"

static func _missing(reason: String) -> Dictionary:
	return {"ok":false,"status":reason,"texture":null,"pixels_assigned":false,
		"runtime_target_registered":false,"actual_game_consumption_observed":false}

static func describe(owner: Object) -> Dictionary:
	if not is_instance_valid(owner) or not owner.has_method("original_result_card_contract"):return _missing("source_result_ui_owner_contract_required")
	var script: Variant = owner.get_script()
	if not script is Script or script.resource_path!=OWNER_PATH:return _missing("source_result_actual_card_owner_required")
	var record: Variant = owner.get("record")
	if not record is Dictionary or not CARDS.native(record):return _missing("source_result_actual_current_card_required")
	var canonical: Dictionary = CARDS.canonical(record)
	var raw: Variant = canonical.get("source_original_card")
	if canonical.get("source_snapshot")!="patch523" or canonical.get("sourceId")!=record.get("sourceId") or not raw is Dictionary or raw.get("ID")!=canonical.get("source_card_id") or raw.get("GradeID")!=canonical.get("source_grade_id"):return _missing("source_result_actual_current_card_required")
	var value: Variant = owner.call("original_result_card_contract")
	if not value is Dictionary or not value.get("ok",false):
		var missing: Dictionary = _missing(str(value.get("code","source_result_owner_contract_unavailable")) if value is Dictionary else "source_result_owner_contract_unavailable")
		return missing
	var contract: Dictionary = value
	if contract.get("schema")!="twilight-original-result-card-roles-v1" or contract.get("source_id")!=canonical.sourceId or contract.get("grade_id")!=canonical.source_grade_id or contract.get("operation") not in ["draw","fusion"]:return _missing("source_result_card_phase_identity_changed")
	var phase: String = str(contract.get("phase",""))
	if phase=="transition":return _missing("source_result_transition_retains_existing_candidates")
	if phase not in ["front","back"]:return _missing("source_result_actual_phase_required")
	var selected: Variant = contract.get(phase)
	if not selected is Dictionary or not selected.get("ok",false):return _missing("source_result_exact_phase_node_required")
	var pack: Variant = selected.get("pack")
	if not pack is RefCounted or not pack.get_script() is Script or pack.get_script().resource_path!=PACK.resource_path:return _missing("source_result_original_pack_required")
	var member: String = str(selected.get("member",""))
	if selected.get("manifest_sha256")!=pack.manifest_sha256 or selected.get("source_sha256")!=pack.manifest.get("files",{}).get(member,{}).get("sha256"):return _missing("source_result_original_pack_identity_changed")
	var ref: Variant = selected.get("fileNameData")
	if selected.get("node_type")!="Sprite" or not ref is Dictionary or ref.get("plistFile")!="" or ref.get("resourceType")!=0 or not selected.get("authored_widget") is Dictionary or not selected.get("parent_chain") is Array:return _missing("source_result_exact_static_sprite_contract_required")
	# Source-owned texture decoding retains the exact literal, case and PMA policy.
	var texture: Texture2D = pack.texture(ref,true)
	if texture==null:return _missing("source_result_original_pixels_unavailable")
	var path: String = "UI/"+str(ref.get("path",""))
	var file: Dictionary = pack.manifest.get("files",{}).get(path,{})
	if file.is_empty():return _missing("source_result_original_file_identity_required")
	return {"ok":true,"status":"original_phase_pixels_resolved","texture":texture,
		"source_id":canonical.sourceId,"grade_id":canonical.source_grade_id,"operation":contract.operation,"phase":phase,
		"authored_widget":selected.authored_widget.duplicate(true),"parent_chain":selected.parent_chain.duplicate(true),
		"provenance":{"manifest_sha256":pack.manifest_sha256,"member":member,"source_sha256":selected.source_sha256,
			"node_offset":selected.get("node_offset"),"node_name":selected.get("node_name"),"source_field":"fileNameData",
			"reference":ref.duplicate(true),"original_file":file.duplicate(true),"phase_basis":contract.get("phase_basis")},
		"source_clips":contract.get("source_clips",[]).duplicate(true),"source_action_duration":contract.get("source_action_duration"),
		"runtime_target_registered":false,"missing_registration":"exact original source-parent coordinates to existing Face; current fit/stretch is not that registration",
		"pixels_assigned":false,"source_animation_started":false,"actual_game_consumption_observed":false}
