extends RefCounted
## Read-only presentation joins. Host IDs, native class IDs and icon roles remain
## distinct; an explicitly selected source pack never falls through to host art.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const SOURCE = preload("res://scripts/skills/player_skills523.gd")
static var _bindings: Dictionary = {}
static var _bindings_sha256: String = ""

static func selected() -> bool:
	return IMAGES.selected()

static func _positive_id(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) <= 0: return -1
	return int(value)

static func _binding(host_id: String) -> Dictionary:
	if _bindings.is_empty():
		var bytes: String = FileAccess.get_file_as_string(SOURCE.BINDINGS_PATH)
		var document: Variant = JSON.parse_string(bytes)
		if not document is Dictionary or document.get("schema_version") != 1 or document.get("patch") != 523 or document.get("source_zip_sha256") != SOURCE.SOURCE_SHA or not document.get("skills") is Dictionary: return {}
		_bindings = document.skills
		_bindings_sha256 = bytes.sha256_text()
	var value: Variant = _bindings.get(host_id)
	if not value is Dictionary or _positive_id(value.get("spell_id")) < 0 or not value.get("row_sha256") is String or str(value.row_sha256).length() != 64: return {}
	return value

static func _info(kind: String, role: String, host_id: String = "") -> Dictionary:
	return {"handled":selected(),"route":"source523_images" if selected() else "", "kind":kind,
		"source_snapshot":"patch523",
		"host_skill_id":host_id,"source_field":role,"status":"original_icon_not_installed",
		"reason":"source523_image_identity_required","source_status":"source523_image_identity_required",
		"texture":null,"provenance":{},"original_bytes_unchanged":false,"actual_game_consumption_observed":false}

static func _missing(info: Dictionary, reason: String) -> Dictionary:
	info.reason = reason
	info.source_status = reason
	return info

static func _resolved(info: Dictionary, result: Dictionary) -> Dictionary:
	info.provenance = result.get("provenance",{}).duplicate(true)
	info.source_status = str(result.get("status","source523_image_unavailable"))
	info.reason = info.source_status
	if bool(result.get("ok",false)) and result.get("texture") is Texture2D and result.get("original_bytes_unchanged",false) == true:
		info.status = "original_linked"
		info.texture = result.texture
		info.original_bytes_unchanged = true
	return info

static func describe_spell_class_row(row: Dictionary, role: String = "IconID") -> Dictionary:
	return _describe_class_row(row,"SpellClass",role)

static func describe_buff_class_row(row: Dictionary, role: String = "OnIconID") -> Dictionary:
	return _describe_class_row(row,"BuffClass",role)

static func _describe_class_row(row: Dictionary, table: String, role: String) -> Dictionary:
	var info: Dictionary = _info("skill" if table == "SpellClass" else "buff",role)
	info["source_table"] = table
	if not info.handled: return info
	if table == "SpellClass" and not role in ["IconID","ActivateIconID"]:
		return _missing(info,"unsupported_skill_icon_role")
	if table == "BuffClass" and not role in ["OnIconID","OffIconID"]:
		return _missing(info,"unsupported_buff_icon_role")
	var value: Variant = row.get("ID")
	if IMAGES.PACK._integer(value) and int(value) == 0: return _missing(info,"zero_sentinel")
	var id: int = _positive_id(value)
	if id < 0: return _missing(info,"source_class_row_identity_required")
	info["source_class_id"] = id
	var reader: RefCounted = IMAGES.active()
	if reader == null: return _resolved(info,IMAGES.resolve_consumer(table,id,role))
	var identity: Dictionary = reader.source_consumer_row(table,id)
	info.provenance = identity.get("provenance",{}).duplicate(true)
	if not identity.get("ok",false):
		return _missing(info,str(identity.get("status","source_class_row_unavailable")))
	var canonical: Variant = identity.get("row")
	var provenance: Dictionary = identity.get("provenance",{})
	var expected_sha: String = str(provenance.get("source_row_canonical_sha256",""))
	var supplied_sha: String = IMAGES.PACK._canonical_row_sha(row)
	if not canonical is Dictionary or _positive_id(canonical.get("ID")) != id or provenance.get("source_table") != table or _positive_id(provenance.get("source_id")) != id:
		return _missing(info,"source_class_row_namespace_mismatch")
	if row != canonical or expected_sha.is_empty() or supplied_sha.is_empty() or supplied_sha != expected_sha or IMAGES.PACK._canonical_row_sha(canonical) != expected_sha:
		return _missing(info,"source_class_row_mismatch")
	info.provenance["identity_basis"] = "complete_canonical_source_class_row"
	if table == "SpellClass" and canonical.get("TestSpell",false) == true:
		return _missing(info,"source_test_spell_excluded")
	var result: Dictionary = IMAGES.resolve_consumer(table,id,role)
	var result_provenance: Dictionary = result.get("provenance",{})
	if result.get("ok",false) and (result_provenance.get("source_table") != table or _positive_id(result_provenance.get("source_id")) != id or result_provenance.get("source_row_canonical_sha256") != expected_sha):
		return _missing(info,"source_class_row_mismatch")
	info = _resolved(info,result)
	info.provenance.merge(provenance,false)
	info.provenance["identity_basis"] = "complete_canonical_source_class_row"
	return info

static func describe_skill(record: Dictionary, role: String = "IconID") -> Dictionary:
	var host_id: String = str(record.get("id",""))
	var info: Dictionary = _info("skill",role,host_id)
	if not info.handled: return info
	if not role in ["IconID","ActivateIconID"]: return _missing(info,"unsupported_skill_icon_role")
	var binding: Dictionary = _binding(host_id)
	if binding.is_empty(): return _missing(info,"host_skill_binding_missing")
	var reader: RefCounted=IMAGES.active()
	if reader!=null:
		var original: Dictionary=reader.source_consumer_row("SpellClass",int(binding.spell_id))
		if original.get("ok",false) and original.get("row",{}).get("TestSpell",false)==true:
			info.provenance=original.get("provenance",{}).duplicate(true)
			return _missing(info,"source_test_spell_excluded")
	var result: Dictionary = IMAGES.resolve_consumer("SpellClass",int(binding.spell_id),role)
	var provenance: Dictionary = result.get("provenance",{})
	if provenance.has("source_row_canonical_sha256") and provenance.source_row_canonical_sha256 != binding.row_sha256:
		return _missing(info,"host_skill_binding_row_mismatch")
	if bool(result.get("ok",false)) and provenance.get("source_row_canonical_sha256","") != binding.row_sha256:
		return _missing(info,"host_skill_binding_row_unverified")
	info = _resolved(info,result)
	info.provenance["host_binding_sha256"] = _bindings_sha256
	info.provenance["host_binding_row_sha256"] = binding.row_sha256
	info.provenance["host_skill_id"] = host_id
	return info

static func describe_guardian_skill(record: Dictionary, runtime: Object, role: String = "IconID") -> Dictionary:
	var host_id: String = str(record.get("id",""))
	var info: Dictionary = _info("skill",role,host_id)
	if not info.handled: return info
	if not role in ["IconID","ActivateIconID"]: return _missing(info,"unsupported_skill_icon_role")
	if record.get("origin") != "TWILIGHT_GUARDIAN523" or not host_id.begins_with("guardian:") or host_id == "guardian:":
		return _missing(info,"guardian_source_skill_identity_required")
	if not is_instance_valid(runtime) or not runtime.has_method("guardian_rewards") or not runtime.has_method("guardian_skill_record"):
		return _missing(info,"guardian_source_skill_provider_required")
	# The existing producer defines guardian:<node> separately from host lm_*
	# bindings. Only its one current-level spell reward can supply this image.
	var rewards: Variant = runtime.call("guardian_rewards",host_id.trim_prefix("guardian:"))
	if not rewards is Array or rewards.size() != 1 or not rewards[0] is Dictionary or not rewards[0].get("spell") is Dictionary:
		return _missing(info,"guardian_single_source_spell_required")
	var canonical: Variant = runtime.call("guardian_skill_record",host_id)
	if not canonical is Dictionary or canonical.is_empty() or canonical != record:
		return _missing(info,"guardian_source_skill_record_mismatch")
	var result: Dictionary = describe_spell_class_row(rewards[0].spell,role)
	result["host_skill_id"] = host_id
	result.provenance["host_skill_id"] = host_id
	result.provenance["caller_identity_basis"] = "existing_guardian_skill_record_and_single_current_level_spell"
	return result

## Which loaded skill evidence the buff relation is read from. A compiled skill
## pack carries its 64-hex fingerprint in active_sha256. With the original 523
## definition ZIP installed (the phone's normal case) the skill owner instead
## adopts profiles built from the verified archive ("original_bound_profiles")
## and leaves active_sha256 empty by design; its source_identity names that
## archive. Requiring active_sha256 alone left every skill buff (e.g. 실드) in
## the HUD buff row without its original BuffClass icon on such installs.
## Only skills the owner actually applied (not deferred) qualify.
static func source_evidence(source: RefCounted, host_id: String) -> Dictionary:
	if source == null or not source.has_method("evidence_for"): return {"reason":"native_buff_relation_unavailable"}
	var compiled: String = str(source.get("active_sha256"))
	if compiled.length() == 64: return {"sha256":compiled,"mode":"compiled_pack"}
	if source.get("source_mode") != "original_bound_profiles": return {"reason":"native_buff_relation_unavailable"}
	var identity: Variant = source.get("source_identity")
	if not identity is Dictionary or identity.get("kind") != "twilight.current523.original-definitions.v1" or identity.get("source_snapshot") != "patch523" or identity.get("source_sha256") != SOURCE.SOURCE_SHA:
		return {"reason":"native_buff_relation_unavailable"}
	var status: Variant = source.get("source_fallback_status")
	if not status is Dictionary or status.get("state") != "loaded" or not status.get("applied") is Array or not status.applied.has(host_id) or not status.get("deferred") is Dictionary or status.deferred.has(host_id):
		return {"reason":"native_buff_relation_unavailable"}
	return {"sha256":str(identity.source_sha256),"mode":"original_bound_profiles"}

static func _skill_buff_identity(effect: Dictionary, source: RefCounted, record: Dictionary) -> Dictionary:
	var host_id: String = str(effect.get("skill_id",""))
	var binding: Dictionary = _binding(host_id)
	if binding.is_empty(): return {"reason":"host_skill_binding_missing"}
	if not str(effect.get("summon_stage","")).is_empty() or record.get("local_design",false) == true or record.has("estimated523"):
		return {"reason":"native_buff_state_unconfirmed"}
	var loaded: Dictionary = source_evidence(source,host_id)
	if loaded.has("reason"): return loaded
	var profile: Dictionary = source.evidence_for(host_id)
	if not profile.get("row") is Dictionary or not profile.get("row_json") is String or profile.row_json.sha256_text() != binding.row_sha256 or JSON.parse_string(profile.row_json) != profile.row or _positive_id(profile.row.get("ID")) != int(binding.spell_id):
		return {"reason":"host_skill_binding_row_mismatch"}
	if not profile.get("bonuses") is Array or not profile.get("buffs") is Array: return {"reason":"native_buff_relation_unavailable"}
	# The profile contains both main and side-effect buffs. Only an unconditional
	# direct main relation proves which native buff belongs to this active row.
	var ids: Dictionary = {}
	for entry: Variant in profile.bonuses:
		if not entry is Dictionary or not entry.get("link") is Dictionary or not entry.get("bonus") is Dictionary or not entry.get("type") is Dictionary or not entry.get("unit") is Dictionary: continue
		if entry.type.get("Name") != "BuffClassID" or entry.unit.get("Name") != "BuffClassID": continue
		if entry.link.get("SpellClassID") != int(binding.spell_id) or entry.link.get("BonusID") != entry.bonus.get("ID") or entry.bonus.get("BonusTypeID") != entry.type.get("ID") or entry.type.get("UnitID") != entry.unit.get("ID"):
			return {"reason":"native_buff_relation_disconnected"}
		if entry.link.get("MinSpellLevel") != 0 or entry.bonus.get("BonusApplicationTypeID") != 0 or entry.bonus.get("BonusApplicationTargetID") != 0: continue
		var id: int = _positive_id(entry.bonus.get("Value"))
		if id < 0: return {"reason":"native_buff_relation_invalid"}
		ids[id] = true
	if ids.size() != 1: return {"reason":"native_buff_relation_ambiguous"}
	var id: int = int(ids.keys()[0])
	var matches: Array = []
	for buff: Variant in profile.buffs:
		if buff is Dictionary and buff.get("row") is Dictionary and _positive_id(buff.row.get("ID")) == id: matches.append(buff.row)
	if matches.size() != 1: return {"reason":"native_buff_relation_ambiguous"}
	return {"id":id,"identity_basis":"verified_unconditional_main_buff_relation","host_binding_sha256":_bindings_sha256,
		"host_binding_row_sha256":binding.row_sha256,"source_skill_evidence_sha256":loaded.sha256,"source_skill_evidence_mode":loaded.mode,"source_spell_class_id":int(binding.spell_id)}

static func describe_buff(effect: Dictionary, role: String, source: RefCounted = null, record: Dictionary = {}) -> Dictionary:
	var info: Dictionary = _info("buff",role,str(effect.get("skill_id","")))
	if not info.handled: return info
	# Active HUD rows deliberately request ON. OFF is supported only when a
	# caller explicitly supplies that source intent; zero/missing never swaps it.
	if not role in ["OnIconID","OffIconID"]: return _missing(info,"unsupported_buff_icon_role")
	var identity: Dictionary
	if effect.has("source_buff_class"):
		if effect.get("source_snapshot") != "patch523" or not effect.source_buff_class is Dictionary or _positive_id(effect.source_buff_class.get("ID")) < 0:
			return _missing(info,"native_buff_identity_unconfirmed")
		identity = {"id":int(effect.source_buff_class.ID),"identity_basis":"preserved_native_buff_class","source_snapshot":"patch523"}
	else:
		identity = _skill_buff_identity(effect,source,record)
	if identity.has("reason"): return _missing(info,str(identity.reason))
	info = _resolved(info,IMAGES.resolve_consumer("BuffClass",int(identity.id),role))
	info.provenance.merge(identity,true)
	return info

static func missing_label(info: Dictionary) -> String:
	if str(info.get("reason","")).begins_with("unsupported_"): return "미지원"
	if info.get("reason","") in ["host_skill_binding_missing","native_buff_identity_unconfirmed","native_buff_relation_unavailable","native_buff_relation_ambiguous","native_buff_state_unconfirmed"]: return "미확인"
	return "미설치"

static func clear(view: TextureRect) -> void:
	if not is_instance_valid(view): return
	IMAGES.ORIGINAL_UI_ICONS.detach(view)
	for key: String in ["source523_skill_image","source523_buff_image"]:
		if view.has_meta(key): view.remove_meta(key)

static func apply(view: TextureRect, info: Dictionary, usage: String = "skill_icon") -> Dictionary:
	var shown: Dictionary=info.duplicate(true)
	if not shown.get("handled",false):
		clear(view)
		return shown
	view.texture=shown.get("texture") as Texture2D
	if shown.get("reason")=="unsupported_csb":
		var scene: Dictionary=IMAGES.attach_original_icon(view,shown,{},
			{"usage":usage,"trigger":"existing_skill_buff_view_bind"})
		shown["scene_result"]=scene
		shown["source_status"]=str(scene.get("status","unavailable"))
		if scene.get("ok",false):
			shown["status"]="source_scene_estimate" if scene.get("origin")=="estimated_single_pass_icon_host" else "original_scene_linked"
			shown["playback_policy_origin"]=str(scene.get("origin",""))
			shown["original_policy_confirmed"]=scene.get("original_policy_confirmed",false)
			shown["reason"]=""
		else:
			shown["reason"]=str(scene.get("error","source_scene_unavailable"))
	else:
		IMAGES.ORIGINAL_UI_ICONS.detach(view)
	var key: String="source523_buff_image" if shown.get("kind")=="buff" else "source523_skill_image"
	view.set_meta(key,evidence(shown))
	return shown

static func evidence(info: Dictionary) -> Dictionary:
	var value: Dictionary = info.duplicate(true)
	value.erase("texture")
	return value
