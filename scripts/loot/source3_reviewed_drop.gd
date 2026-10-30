extends RefCounted
# One explicit source identity, adapted only inside an empty successful grade.
# No source chance evaluation, extra roll, item grant, stat or save mutation.
const PATH = "res://data/monsters/source3_reviewed_drops.json"
const IDENTITIES = "res://data/l1j/source3_item_identities.json"
const REVIEWED_SHA = "3fc97b125d7e67c271c6cea886c73b20544ae48a13180a7f2a728cb14aafdb92"
const IDENTITY_SHA = "e6f446525e50ad785fac94739a6d819a105f6097ea550f2f79dbfc74674cb112"

static func identity(record: Dictionary) -> Dictionary:
	if str(record.get("sourceId", "")) != "l1j_tw380_npc_45962": return {}
	var result: Dictionary = {}
	for key: String in ["name", "sourceId", "source_id", "source_npc_id", "source_name_original", "source_version", "source_locale", "import_enabled", "identity_approval", "local_application_authorization"]:
		result[key] = record.get(key, "")
	result["appearance_status"] = record.get("appearance_status", "")
	var raw: Dictionary = record.get("source_raw_fields", {})
	result["raw_npc_name"] = raw.get("name", "")
	result["raw_npc_nameid"] = raw.get("nameid", "")
	result["raw_npc_gfxid"] = raw.get("gfxid", "")
	result["npc_sql_row_sha256"] = record.get("identity_review_evidence", {}).get("SQL", {}).get("row_sha256", "")
	return result

static func candidate(grade: String, items: Dictionary, monster_identity: Dictionary) -> Dictionary:
	if grade != "희귀" or monster_identity.is_empty(): return {}
	if str(monster_identity.get("sourceId", "")) != "l1j_tw380_npc_45962": return {}
	if not FileAccess.file_exists(PATH) or not FileAccess.file_exists(IDENTITIES): return {}
	var proof_text: String = FileAccess.get_file_as_string(PATH)
	var identity_text: String = FileAccess.get_file_as_string(IDENTITIES)
	if proof_text.sha256_text() != REVIEWED_SHA or identity_text.sha256_text() != IDENTITY_SHA: return {}
	var parsed: Variant = JSON.parse_string(proof_text)
	var identities: Variant = JSON.parse_string(identity_text)
	if not parsed is Dictionary or not identities is Dictionary: return {}
	return validate(parsed, identities, grade, items, monster_identity)

static func validate(payload: Dictionary, identities: Dictionary, grade: String, items: Dictionary, monster_identity: Dictionary) -> Dictionary:
	if int(payload.get("schema", 0)) != 1 or payload.get("enabled") != true: return {}
	if int(identities.get("schema", 0)) != 2: return {}
	if str(payload.get("policy", "")) != "EXISTING_SUCCESSFUL_GRADE_EMPTY_POOL_ONLY": return {}
	if monster_identity != payload.get("required_monster_identity", {}): return {}
	if str(monster_identity.get("sourceId", "")) != "l1j_tw380_npc_45962" or monster_identity.get("import_enabled") != true: return {}
	if not str(monster_identity.get("appearance_status", "")).is_empty(): return {}
	if str(payload.get("item_source_key", "")) != "source3:tw380:Taiwan:weapon:11" or str(payload.get("item_game_source_id", "")) != "423": return {}
	if grade != "희귀" or str(payload.get("item_name", "")) != "수정 단검": return {}
	if int(payload.get("quantity", 0)) != 1 or int(payload.get("source_enchant", -1)) != 0: return {}
	var matches: int = 0
	for binding: Variant in identities.get("bindings", []):
		if binding is Dictionary and str(binding.get("source_item_key", "")) == payload.item_source_key and str(binding.get("game_source_id", "")) == "423" and str(binding.get("game_name", "")) == "수정 단검" and str(binding.get("source_variant", {}).get("bless_raw", "")) == "1": matches += 1
	if matches != 1: return {}
	var item: Dictionary = items.get("수정 단검", {})
	if str(item.get("name", "")) != "수정 단검" or str(item.get("grade", "")) != grade or str(item.get("type", "")) != "단검" or str(item.get("slot", "")) != "weapon": return {}
	if not item.has("sourceId") and not item.has("grade_source_id"): return {}
	for key: String in ["sourceId", "grade_source_id"]:
		if item.has(key) and str(item[key]) != "423": return {}
	return {"item_name":"수정 단검", "weight":1, "min":1, "max":1}
