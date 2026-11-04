extends RefCounted
## Optional exact-ID 523 evidence adapter. Original bytes live in a private pack.
## Distance, CastDelay, proc timing, AC and hit/damage formulae are NOT inferred.
const BINDINGS_PATH := "res://data/skills/player_skills523_bindings.json"
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const MAX_BYTES := 16 * 1024 * 1024
# Explicit existing inventory spellings, reviewed against the current catalog.
# These are host compatibility aliases, never a native/Inven numeric ID join.
const HOST_MATERIAL_ALIASES := {
	"마력의 돌":["마력의 돌 (각인)"], "정령옥":["정령옥 (각인)"],
	"흑요석":["흑요석 (각인)"], "정제석":["정제석 (각인)"],
	"인장석":["인장석 (각인)"], "번개석":["번개석 (각인)"], "신성석":["신성석 (각인)"]}
var profiles: Dictionary = {}
var bindings: Dictionary = {}
var revision: int = 0
var last_error: String = ""
var active_sha256: String = ""

func configure_arguments() -> void:
	var path := ""
	var expected := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--player-skills523-pack="): path = arg.get_slice("=", 1)
		elif arg.begins_with("--player-skills523-sha256="): expected = arg.get_slice("=", 1)
	if path.is_empty() and expected.is_empty(): return
	if not load_pack(path, expected): push_warning("Player skills523 pack rejected: " + last_error)

func reject(reason: String) -> bool:
	last_error = reason
	return false

func load_pack(path: String, expected_sha256: String) -> bool:
	# Reject before replacing the current snapshot. No live catalog/save writes.
	if path.is_empty() or expected_sha256.length() != 64: return reject("path and pinned SHA256 required")
	if not FileAccess.file_exists(path): return reject("pack unavailable")
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null or handle.get_length() > MAX_BYTES: return reject("pack unavailable or oversized")
	var bytes := handle.get_buffer(handle.get_length())
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	if hashing.finish().hex_encode() != expected_sha256: return reject("pack SHA256 mismatch")
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary: return reject("invalid pack document")
	var pack: Dictionary = value
	if pack.get("schema_version") != 1 or pack.get("patch") != 523 or pack.get("source_zip_sha256") != SOURCE_SHA:
		return reject("unsupported source/schema")
	if pack.get("bindings_sha256") != FileAccess.get_file_as_string(BINDINGS_PATH).sha256_text():
		return reject("binding revision mismatch")
	var local: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDINGS_PATH))
	if not local is Dictionary or not pack.get("profiles") is Dictionary: return reject("missing bindings/profiles")
	var candidate: Dictionary = pack.profiles
	if candidate.size() != local.skills.size(): return reject("incomplete profile set")
	for id: String in local.skills:
		var profile: Variant = candidate.get(id)
		if not profile is Dictionary: return reject("missing profile " + id)
		if not profile.get("row_json") is String or str(profile.row_json).sha256_text() != str(local.skills[id].row_sha256):
			return reject("unreviewed source row " + id)
		var row: Variant = JSON.parse_string(profile.row_json)
		if not row is Dictionary or row != profile.get("row") or int(row.get("ID", -1)) != int(local.skills[id].spell_id):
			return reject("source identity mismatch " + id)
		for key: String in ["learn_limits", "bonuses", "buffs", "costs", "cast_groups"]:
			if not profile.get(key) is Array: return reject("invalid " + key)
		for entry: Variant in profile.bonuses:
			if not valid_bonus(entry): return reject("invalid spell bonus")
		for buff: Variant in profile.buffs:
			if not buff is Dictionary or not buff.get("row") is Dictionary or not buff.get("bonuses") is Array: return reject("invalid buff")
			for entry: Variant in buff.bonuses:
				if not valid_bonus(entry): return reject("invalid buff bonus")
		if not profile.get("target_kind") is Dictionary or int(profile.target_kind.get("ID", -1)) != int(row.TargetKindID):
			return reject("target kind mismatch")
		if not profile.get("targeting_type") is Dictionary or int(profile.targeting_type.get("ID", -1)) != int(row.TargettingTypeID):
			return reject("targeting type mismatch")
	profiles = candidate.duplicate(true)
	bindings = local.duplicate(true)
	active_sha256 = expected_sha256
	revision += 1
	last_error = ""
	return true

static func valid_bonus(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: String in ["link", "bonus", "type", "unit"]:
		if not value.get(key) is Dictionary: return false
	return value.type.get("Name") is String and value.unit.get("Name") is String and value.bonus.has("Value") and value.bonus.has("BonusApplicationTypeID") and value.bonus.has("BonusApplicationTargetID")

func evidence_for(id: String) -> Dictionary:
	return profiles.get(id, {}).duplicate(true)

static func scalar_values(profile: Dictionary, name: String, unit: String) -> Array:
	var result: Array = []
	for entry: Dictionary in profile.bonuses:
		var link: Dictionary = entry.link
		var bonus: Dictionary = entry.bonus
		if str(entry.type.Name) != name or str(entry.unit.Name) != unit: continue
		if int(link.MinSpellLevel) != 0 or int(bonus.BonusApplicationTypeID) != 0 or int(bonus.BonusApplicationTargetID) != 0: continue
		result.append(bonus.Value)
	return result

static func status_confirmed(profile: Dictionary, kind: String) -> bool:
	# Only direct main-buff flags support this narrow projection. Side effects,
	# chained spells and "cannot move" alone cannot establish a stun/hold/fear.
	var main_ids := scalar_values(profile, "BuffClassID", "BuffClassID")
	var flag: String = {"stun":"Stunned", "silence":"CannotCastSpell"}.get(kind, "")
	if flag.is_empty() or main_ids.size() != 1: return false
	for buff: Dictionary in profile.buffs:
		if int(buff.row.ID) != int(main_ids[0]): continue
		for entry: Dictionary in buff.bonuses:
			if str(entry.type.Name) == flag and int(entry.bonus.Value) == 1 and int(entry.bonus.BonusApplicationTypeID) == 0 and int(entry.bonus.BonusApplicationTargetID) == 0:
				return true
	return false

func apply_to(record: Dictionary, job: String, upgraded: bool) -> Dictionary:
	var id := str(record.get("id", ""))
	if not profiles.has(id): return record
	var profile: Dictionary = profiles[id]
	var row: Dictionary = profile.row
	record["source523"] = {"spell_id":row.ID, "target_kind":profile.target_kind.Name,
		"targeting_type":profile.targeting_type.Name, "cast_range_raw":row.CastRange,
		"min_cast_range_raw":row.MinCastRange, "area_radius_raw":row.TargetAreaRadius,
		"cast_delay_raw":row.CastDelay, "cast_group_id":row.CastGroupID,
		"hp_cost_raw":row.HPCost, "mp_cost_raw":row.MPCost,
		"distance_policy":"EXISTING_TWILIGHT", "time_policy":"EXISTING_TWILIGHT",
		"combat_formula":"EXISTING_TWILIGHT", "applied":[]}
	var buff_seconds := scalar_values(profile, "SpellBuffDuration", "Seconds")
	var status_low := scalar_values(profile, "SpellDebuffMinDuration", "Seconds")
	var status_high := scalar_values(profile, "SpellDebuffMaxDuration", "Seconds")
	if buff_seconds.size() == 1: record.source523["buff_seconds"] = buff_seconds[0]
	if status_low.size() == 1 and status_high.size() == 1: record.source523["status_seconds"] = [status_low[0], status_high[0]]
	var native_material: Dictionary = bindings.material_inventory_keys.get(str(int(row.SpellMaterialTypeID)), {})
	if int(row.SpellMaterialItemAmount) > 0:
		record.source523["material_text"] = (str(native_material.inventory_key) if not native_material.is_empty() else "분류 확인 필요") + " " + str(int(row.SpellMaterialItemAmount)) + "개"
	# Passive/effect/upgrade execution and learning/ownership stay with the host.
	# Current-reference/local-design rows gain evidence only. A client row never
	# grants a book or activates a previously blocked/new spell implementation.
	for prefix: String in bindings.get("reference_only_prefixes", []):
		if id.begins_with(prefix): return record
	if str(record.get("activation", "")) != "active" or bool(record.get("runtime_blocked", false)): return record
	var reason := ""
	if int(row.SpellTypeID) == 3: reason = "523 원본은 패시브 · 기존 액티브 연결 확인 필요"
	elif upgraded: reason = "523 상위 스킬 효과 연결 확인 필요"
	elif int(row.SpellCompositionNode) != 0 or int(row.SpellCategoryID) in [172,184,371]: reason = "523 복합 스킬 연결 확인 필요"
	elif not profile.costs.is_empty(): reason = "523 대상별 비용 조건 연결 확인 필요"
	elif int(row.MPCostUnit) != 1 or int(row.VPCost) != 0: reason = "523 비용 단위 연결 확인 필요"
	elif int(row.SpellMaterialTypeID) == 0 and int(row.SpellMaterialItemAmount) != 0: reason = "523 재료 정의 확인 필요"
	var native_class := int(bindings.class_ids.get(job, -1))
	var allowed := false
	for limit: Dictionary in profile.learn_limits:
		if int(limit.ClassID) == native_class and not bool(limit.IsTutorialSpell): allowed = true
	if not allowed: reason = "523 원본 직업 학습 대상 아님"
	var targeting := int(row.TargettingTypeID)
	var target_kind := int(row.TargetKindID)
	var mode := str(record.get("mode", ""))
	if targeting not in [1,2] or target_kind not in [1,2,3,7,10,11,422]: reason = "523 대상 유형은 현재 PvE 연결 미지원"
	elif mode in ["attack","status","turn_undead"]:
		if int(row.SpellCategoryID) not in [1,8,11]: reason = "523 공격·상태 실행 방식 연결 확인 필요"
		if target_kind == 1: reason = "523 자기 대상 효과는 적에게 적용할 수 없음"
		if targeting == 2 and float(row.TargetAreaRadius) == 0:
			record["shape"] = "single"
			record["targets"] = 1
		elif (targeting == 1 and str(record.get("shape", "")) != "self_circle") or (targeting == 2 and str(record.get("shape", "")) not in ["circle", "target_circle"]):
			reason = "523 범위 형태 연결 확인 필요"
	elif targeting != 1:
		reason = "523 외부 대상 선택 연결 확인 필요"
	if not reason.is_empty():
		record["source523_block_reason"] = reason
		return record
	record["mp"] = int(row.MPCost)
	record["hp"] = int(row.HPCost)
	var items: Dictionary = {}
	# Physical ammunition is a separate existing host rule, not a material
	# that can be erased because SpellClass.SpellMaterialTypeID happens to be 0.
	for retained: String in bindings.retained_host_items:
		if record.get("items", {}).has(retained): items[retained] = record.items[retained]
	var material := str(int(row.SpellMaterialTypeID))
	if int(row.SpellMaterialItemAmount) > 0:
		var bridge: Dictionary = bindings.material_inventory_keys.get(material, {})
		if bridge.is_empty():
			record["source523_block_reason"] = "523 재료 인벤토리 연결 확인 필요"
			return record
		items[str(bridge.inventory_key)] = int(items.get(str(bridge.inventory_key), 0)) + int(row.SpellMaterialItemAmount)
	record["items"] = items
	record.source523.applied = ["hp", "mp", "materials", "target_filter"]
	if int(row.TargetLimitCount) > 0: record["targets"] = int(row.TargetLimitCount)
	var duration := scalar_values(profile, "SpellBuffDuration", "Seconds")
	if mode in ["buff", "counter", "stealth"] and duration.size() == 1 and float(duration[0]) > 0:
		record["duration"] = float(duration[0])
		record.source523.applied.append("duration")
	var low := scalar_values(profile, "SpellDebuffMinDuration", "Seconds")
	var high := scalar_values(profile, "SpellDebuffMaxDuration", "Seconds")
	if status_confirmed(profile, str(record.get("status", ""))) and low.size() == 1 and high.size() == 1 and float(low[0]) > 0 and float(high[0]) >= float(low[0]):
		record["duration_bounds"] = [float(low[0]), float(high[0])]
		record.source523.applied.append("duration_bounds")
	return record

static func target_allowed(skill: Dictionary, target: TwilightMonster) -> bool:
	if not skill.has("source523"): return true
	if not str(skill.get("source523_block_reason", "")).is_empty(): return false
	if not is_instance_valid(target) or target.dead: return false
	var kind := str(skill.source523.target_kind)
	if kind == "Undead": return target.is_undead()
	return kind in ["All", "AllButMe", "Enemy", "TargetNEnemy", "AttackableNPC"]

static func target_text(source: Dictionary) -> String:
	var target: String = {"Me":"자신", "All":"모두", "AllButMe":"자신 제외", "Enemy":"적", "TargetNEnemy":"선택 대상과 적", "AttackableNPC":"공격 가능한 NPC", "Undead":"언데드", "PCButMe":"다른 플레이어", "PCButCompany":"아군 제외 플레이어"}.get(str(source.target_kind), "확인 필요")
	if str(source.targeting_type) == "Self": target = "자신" if float(source.area_radius_raw) == 0 else "자신 주변 · " + target
	return target

static func material_text(skill: Dictionary) -> String:
	var materials := PackedStringArray()
	for item: String in skill.get("items", {}): materials.append(item + " " + str(skill.items[item]) + "개")
	return " · ".join(materials) if not materials.is_empty() else "없음"

static func inventory_keys(skill: Dictionary, item: String) -> Array:
	var result: Array = [item]
	if skill.get("source523", {}).get("applied", []).has("materials"):
		result.append_array(HOST_MATERIAL_ALIASES.get(item, []))
	return result

static func detail_text(skill: Dictionary) -> String:
	if not skill.has("source523"): return ""
	var source: Dictionary = skill.source523
	var text := "\n\n523 원본 대상: " + target_text(source)
	if not str(skill.get("source523_block_reason", "")).is_empty(): return text + "\n" + str(skill.source523_block_reason)
	if source.applied.is_empty():
		text += "\n523 원문 HP / MP 값: %d / %d" % [int(source.hp_cost_raw),int(source.mp_cost_raw)]
		if source.has("material_text"): text += "\n원본 재료: " + str(source.material_text)
		if source.has("buff_seconds"): text += "\n원본 버프 지속: %.1f초" % float(source.buff_seconds)
		if source.has("status_seconds"): text += "\n원본 상태 지속: %.1f~%.1f초" % [float(source.status_seconds[0]),float(source.status_seconds[1])]
		return text + "\n참고 자료 · 현재 실행 상태와 게임 설정 유지"
	text += "\n시전 재료: " + material_text(skill)
	if source.applied.has("duration_bounds"):
		text += "\n상태 지속: %.1f~%.1f초 (보스 보정은 게임 설정)" % [float(skill.duration_bounds[0]), float(skill.duration_bounds[1])]
	text += "\n523 원본 비용·대상 제한 적용\n거리·시전 시간·전투 수식은 기존 게임 설정"
	return text

static func duration_text(skill: Dictionary) -> String:
	if skill.get("source523", {}).get("applied", []).has("duration_bounds"):
		return "%.1f~%.1f초" % [float(skill.duration_bounds[0]), float(skill.duration_bounds[1])]
	return "%.1f초" % float(skill.get("duration", 0))
