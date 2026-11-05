extends RefCounted
## Explicit user-authorized local estimates only while native recovery definitions
## are absent. Definition IDs remain identities, never amounts.
static func project(record: Dictionary, meta: Dictionary, settings: Dictionary) -> void:
	var candidates: Dictionary = settings.get("restoration_level_estimates", {})
	var estimate: Dictionary = candidates.get(str(int(meta.spell_id)), {})
	if estimate.is_empty() or not bool(estimate.get("enabled", false)) or record.get("mode") != "heal": return
	var proof: Dictionary = {}
	for blocker: Dictionary in meta.get("blockers", []):
		if blocker.code == "restoration_definition_missing" and int(blocker.child_spell_id) == int(estimate.get("child_spell_id", -1)) and int(blocker.base_definition_id) == int(estimate.get("base_definition_id", -1)) and int(blocker.raised_definition_id) == int(estimate.get("raised_definition_id", -1)): proof = blocker; break
	if proof.is_empty() or estimate.get("basis") != "max_hp": return
	var fraction: float = clampf(float(estimate.get("bonus_fraction", 0)), 0, .25)
	if fraction <= 0: return
	meta["estimate_declared"] = true
	meta["native_definition_pending"] = true
	meta.pending.erase("RestorationID")
	proof["message"] = "원본 회복 정의 미확인 · 조정 가능한 TWILIGHT 추정 증가분을 적용합니다."
	if not meta.active: return
	record["heal_percent"] = float(record.get("heal_percent", 0)) + fraction
	meta.applied.append({"field":"estimated_heal_percent","delta":fraction,"projection":"ESTIMATE","source_type":"RestorationID","child_spell_id":proof.child_spell_id,"base_definition_id":proof.base_definition_id,"raised_definition_id":proof.raised_definition_id,"basis":"max_hp"})
