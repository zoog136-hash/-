extends RefCounted
## Optional exact-ID 523 evidence adapter. Original bytes live in a private pack.
## Distance, CastDelay, proc timing, AC and hit/damage formulae are NOT inferred.
const BINDINGS_PATH := "res://data/skills/player_skills523_bindings.json"
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const MAX_BYTES := 16 * 1024 * 1024
# Explicitly reviewed self conversions. Host learned=1 means ownership, never
# native SpellLevel=1; only the unconditional MinSpellLevel=0 value is applied.
const BASE_MP_CONVERSIONS := [349, 18304]
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
var estimated_rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/estimated_nodes523.json")).get("records", {})
var recovery_rules = preload("res://scripts/skills/recovery_rules523.gd").new()
var progression_rules = preload("res://scripts/skills/progression_rules523.gd").new()

func set_progression_setting(id: String, key: String, value: float) -> bool:
	if not progression_rules.update_setting(id,key,value):return false
	revision+=1
	return true

func set_recovery_setting(id: String, key: String, value: float) -> bool:
	if not recovery_rules.update_setting(id,key,value): return false
	revision += 1
	return true

func estimated_rule(id: String) -> Dictionary:
	var rule: Dictionary = estimated_rules.get(id, {})
	var profile: Dictionary = profiles.get(id, {})
	if rule.is_empty() or profile.is_empty(): return {}
	if int(profile.row.ID) != int(rule.spell_id) or int(profile.row.SpellCompositionNode) != int(rule.composition): return {}
	return rule

func prepare_estimate(record: Dictionary) -> void:
	var rule := estimated_rule(str(record.get("id", "")))
	if rule.is_empty(): return
	# The user explicitly authorized local estimates for these eight references.
	# Mutate the existing dictionary so roster/UI/save identities remain shared.
	record.merge(rule.runtime.duplicate(true), true)
	record["estimated523"] = {"composition":rule.composition,"kind":rule.kind,"summary":rule.summary,"fields":rule.estimated_fields.duplicate()}
	record["desc"] = str(rule.summary)
	if bool(rule.new_reference_runtime):
		var native_class := int(bindings.class_ids.get(str(record["class"]), -1))
		for limit: Dictionary in profiles[str(record.id)].learn_limits:
			if int(limit.ClassID) == native_class and not bool(limit.IsTutorialSpell): record["minimum_level"] = int(limit.CharacterMinLevel)
		record["design_provenance"] = {}
		for key: String in rule.runtime: record.design_provenance[key] = {"value":record[key],"status":"local_design","basis":"사용자 승인 · 누적523 8종 추정 구현"}
	# Feed known native costs into the existing book/material UI as well as cast.
	record.merge(apply_to(record.duplicate(true), str(record["class"]), false), true)

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
		if profile.has("components"):
			if not profile.components is Array: return reject("invalid components")
			var child_ids: Dictionary={}
			for child: Variant in scalar_values(profile,"SpellClassID","SpellClassID"):child_ids[int(child)]=true
			var seen: Dictionary={}
			if child_ids.size()!=profile.components.size():return reject("incomplete component graph")
			for component: Variant in profile.components:
				if not valid_component(component):return reject("invalid component profile")
				var child_id:=int(component.row.ID)
				if not child_ids.has(child_id) or seen.has(child_id):return reject("unexpected component identity")
				seen[child_id]=true
		if profile.has("execution_graph") and not valid_execution(id,profile):return reject("invalid reviewed execution graph")
		if not profile.get("target_kind") is Dictionary or int(profile.target_kind.get("ID", -1)) != int(row.TargetKindID):
			return reject("target kind mismatch")
		if not profile.get("targeting_type") is Dictionary or int(profile.targeting_type.get("ID", -1)) != int(row.TargettingTypeID):
			return reject("targeting type mismatch")
	for key: String in ["ui_units","buff_groups","bonus_application_types","special_resistance_types"]:
		if pack.has(key):
			if not pack[key] is Array:return reject("invalid recovery metadata")
			for row: Variant in pack[key]:
				if not row is Dictionary:return reject("invalid recovery metadata row")
	profiles = candidate.duplicate(true)
	bindings = local.duplicate(true)
	recovery_rules.configure_pack(pack)
	active_sha256 = expected_sha256
	revision += 1
	last_error = ""
	return true

func valid_execution(id: String, profile: Dictionary) -> bool:
	var graph: Variant=profile.get("execution_graph")
	if not graph is Dictionary or not graph.get("spells") is Array or not graph.get("invokes") is Array:return false
	if progression_rules.graph_for(id,profile).is_empty():return false
	var nodes: Dictionary={int(profile.row.ID):profile}
	for node: Variant in graph.spells:
		if not valid_component(node) or nodes.has(int(node.row.ID)):return false
		nodes[int(node.row.ID)]=node
	var options: Dictionary={}
	for option: Variant in graph.invokes:
		if not option is Dictionary or not option.get("row") is Dictionary or not option.get("type") is Dictionary:return false
		if not option.row.has("ID") or not option.type.has("ID") or int(option.row.get("InvokeOptionTypeID",-1))!=int(option.type.ID) or options.has(int(option.row.ID)):return false
		options[int(option.row.ID)]=option
	var reached: Dictionary={int(profile.row.ID):true}
	for _depth: int in range(nodes.size()):
		for native_id: int in reached.keys():
			var node: Dictionary=nodes[native_id]
			var entries: Array=node.bonuses.duplicate()
			for buff: Dictionary in node.buffs:entries.append_array(buff.bonuses)
			for entry: Dictionary in entries:
				if int(entry.link.MinSpellLevel)!=0:continue
				var child_id:=0
				if str(entry.type.Name) in ["ToggleOnSpellClassID","ChangeSpecialSpellClassID","RepeatingSpellBehavior","NextSpellClassID"] and str(entry.unit.Name)=="SpellClassID" and int(entry.bonus.BonusApplicationTypeID)==0 and int(entry.bonus.BonusApplicationTargetID)==0:child_id=int(entry.bonus.Value)
				elif str(entry.type.Name)=="InvokeOption" and int(entry.bonus.BonusApplicationTypeID)==10:
					var option: Dictionary=options.get(int(entry.bonus.BonusApplicationTargetID),{})
					if not option.is_empty() and int(option.type.get("Param1Unit",0))==12:child_id=int(option.row.Param1)
				if nodes.has(child_id):reached[child_id]=true
	return reached.size()==nodes.size()

static func valid_bonus(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: String in ["link", "bonus", "type", "unit"]:
		if not value.get(key) is Dictionary: return false
	return value.type.get("Name") is String and value.unit.get("Name") is String and value.bonus.has("Value") and value.bonus.has("BonusApplicationTypeID") and value.bonus.has("BonusApplicationTargetID")

static func valid_component(profile: Variant) -> bool:
	if not profile is Dictionary or not profile.get("row") is Dictionary or not profile.get("row_json") is String:return false
	if JSON.parse_string(profile.row_json)!=profile.row or bool(profile.row.get("TestSpell",true)):return false
	for key: String in ["bonuses","buffs","costs"]:
		if not profile.get(key) is Array:return false
	for entry: Variant in profile.bonuses:
		if not valid_bonus(entry):return false
	for buff: Variant in profile.buffs:
		if not buff is Dictionary or not buff.get("row") is Dictionary or not buff.get("bonuses") is Array:return false
		for entry: Variant in buff.bonuses:
			if not valid_bonus(entry):return false
	return true

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
	var estimate := estimated_rule(id) if record.has("estimated523") else {}
	var recovery: Dictionary = recovery_rules.spec_for(id,profile)
	var progression: Dictionary=progression_rules.spec_for(id,profile,recovery_rules.percent_denominator)
	if not recovery.is_empty():
		record.merge(recovery.runtime.duplicate(true),true)
		record["recovery523"]=recovery.meta.duplicate(true)
	if not progression.is_empty():
		record.merge(progression.runtime.duplicate(true),true)
		record["progression523"]=progression.meta.duplicate(true)
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
	var pending_note: String = {
		54703:"복합 효과 보류: 홀드 해제·회복·PvP 전용 보너스의 별도 연결 필요",
		69601:"복합 효과 보류: 회복량 정의표 없음 · 상태 해제·충돌 무시 미연결",
		95662:"복합 효과 보류: 회복량 정의표 없음 · 자신/파티 회복·보호막·해제 미연결"
	}.get(int(row.ID), "")
	if not pending_note.is_empty() and recovery.is_empty(): record.source523["pending_note"] = pending_note
	if not recovery.is_empty():record.source523["recovery"]=recovery.meta.duplicate(true)
	if not progression.is_empty():record.source523["progression"]=progression.meta.duplicate(true)
	if not estimate.is_empty():
		record.source523["estimated"] = record.estimated523.duplicate(true)
		record.source523["distance_policy"] = "TWILIGHT_ESTIMATE"
		record.source523["time_policy"] = "TWILIGHT_ESTIMATE"
	# Passive/effect/upgrade execution and learning/ownership stay with the host.
	# Current-reference/local-design rows gain evidence only. A client row never
	# grants a book or activates a previously blocked/new spell implementation.
	for prefix: String in bindings.get("reference_only_prefixes", []):
		if id.begins_with(prefix) and estimate.is_empty(): return record
	if not progression.is_empty() and str(record.activation)=="passive":
		var class_id:=int(bindings.class_ids.get(job,-1))
		if not profile.learn_limits.any(func(limit: Dictionary) -> bool:return int(limit.ClassID)==class_id and not bool(limit.IsTutorialSpell)):
			record["source523_block_reason"]="523 원본 직업 학습 대상 아님"
		else:record.source523.applied=["native_passive"]
		return record
	if str(record.get("activation", "")) != "active" or bool(record.get("runtime_blocked", false)): return record
	var reason := ""
	if int(row.SpellTypeID) == 3: reason = "523 원본은 패시브 · 기존 액티브 연결 확인 필요"
	elif upgraded and recovery.is_empty(): reason = "523 상위 스킬 효과 연결 확인 필요"
	elif int(row.SpellCompositionNode) != 0 and estimate.is_empty() and progression.is_empty(): reason = "523 조건 노드 %d · 노드·조건 유형 정의가 없어 시전 보류" % int(row.SpellCompositionNode)
	elif int(row.SpellCategoryID) == 184 and recovery.is_empty(): reason = "523 복합 효과 · 하위 주문의 회복·해제·보너스 연결 미완료"
	elif int(row.SpellCategoryID) in [172,371] and estimate.is_empty() and progression.is_empty(): reason = "523 조건별 하위 주문 · 분기·실행 순서 연결 미완료"
	elif not profile.costs.is_empty() and recovery.get("self_cost",{}).is_empty(): reason = "523 대상별 비용 조건 연결 확인 필요"
	elif int(row.MPCostUnit) != 1 or int(row.VPCost) != 0: reason = "523 비용 단위 연결 확인 필요"
	elif int(row.SpellMaterialTypeID) == 0 and int(row.SpellMaterialItemAmount) != 0: reason = "523 재료 정의 확인 필요"
	var native_class := int(bindings.class_ids.get(job, -1))
	var allowed := false
	for limit: Dictionary in profile.learn_limits:
		if int(limit.ClassID) == native_class and not bool(limit.IsTutorialSpell): allowed = true
	if not allowed: reason = "523 원본 직업 학습 대상 아님"
	if not progression.is_empty() and str(record.mode)!="attack":
		if not allowed:record["source523_block_reason"]=reason;return record
		record.source523.applied=["native_passive" if str(record.activation)=="passive" else "native_toggle"]
		return record
	var targeting := int(row.TargettingTypeID)
	var target_kind := int(row.TargetKindID)
	var mode := str(record.get("mode", ""))
	if not estimate.is_empty() and str(estimate.kind) == "asura": record.source523["estimated_self_only"] = true
	var self_branch_allowed := (not estimate.is_empty() and (str(estimate.kind) == "asura" or str(estimate.kind) == "detection")) or bool(recovery.get("meta",{}).get("self_branch",false))
	if target_kind==52:reason="523 원본은 다른 플레이어 대상 · 상대 PC가 없는 현재 PvE에 확대하지 않음"
	elif targeting not in [1,2] or (target_kind not in [1,2,3,7,10,11,422] and not self_branch_allowed): reason = "523 대상 유형은 현재 PvE 연결 미지원"
	elif mode in ["attack","status","turn_undead"]:
		if int(row.SpellCategoryID) not in [1,8,11] and estimate.is_empty() and progression.is_empty(): reason = "523 공격·상태 실행 방식 연결 확인 필요"
		if target_kind == 1: reason = "523 자기 대상 효과는 적에게 적용할 수 없음"
		if targeting == 2 and float(row.TargetAreaRadius) == 0:
			record["shape"] = "single"
			record["targets"] = 1
		elif (targeting == 1 and str(record.get("shape", "")) != "self_circle") or (targeting == 2 and str(record.get("shape", "")) not in ["circle", "target_circle"]):
			reason = "523 범위 형태 연결 확인 필요"
	elif targeting != 1 and recovery.is_empty():
		reason = "523 외부 대상 선택 연결 확인 필요"
	if not reason.is_empty():
		record["source523_block_reason"] = reason
		return record
	var self_cost: Dictionary=recovery.get("self_cost",{})
	record["mp"] = int(self_cost.get("MPCost",row.MPCost))
	record["hp"] = int(self_cost.get("HPCost",row.HPCost))
	var items: Dictionary = {}
	# Physical ammunition is a separate existing host rule, not a material
	# that can be erased because SpellClass.SpellMaterialTypeID happens to be 0.
	for retained: String in bindings.retained_host_items:
		if record.get("items", {}).has(retained): items[retained] = record.items[retained]
	if not progression.is_empty() and str(progression.meta.kind)=="rapid":items["총알"]=int(record.hits)
	var material_costs: Array=[{"type":int(row.SpellMaterialTypeID),"amount":int(row.SpellMaterialItemAmount)}]
	if not self_cost.is_empty():
		record.source523["cost_row_id"]=int(self_cost.ID)
		material_costs.clear()
		for index: int in range(1,4):material_costs.append({"type":int(self_cost.get("SpellMaterialTypeID"+str(index),0)),"amount":int(self_cost.get("SpellMaterialItemAmount"+str(index),0))})
	for cost: Dictionary in material_costs:
		if int(cost.amount)<=0:continue
		var material := str(int(cost.type))
		var bridge: Dictionary = bindings.material_inventory_keys.get(material, {})
		if bridge.is_empty():
			record["source523_block_reason"] = "523 재료 인벤토리 연결 확인 필요"
			return record
		items[str(bridge.inventory_key)] = int(items.get(str(bridge.inventory_key), 0)) + int(cost.amount)
	record["items"] = items
	record.source523.applied = ["hp", "mp", "materials", "target_filter"]
	if not estimate.is_empty(): record.source523.applied.append("estimated_effect")
	if not recovery.is_empty():record.source523.applied.append("self_recovery")
	if not progression.is_empty():record.source523.applied.append("reviewed_execution")
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
	if mode == "convert" and int(row.ID) in BASE_MP_CONVERSIONS and targeting == 1 and target_kind in [1,2] and float(row.TargetAreaRadius) == 0:
		var mana := scalar_values(profile, "MPRestoration", "Value")
		if mana.size() != 1 or float(mana[0]) <= 0 or float(mana[0]) != floor(float(mana[0])):
			record["source523_block_reason"] = "523 기본 단계 MP 회복량을 확정할 수 없음"
			return record
		record["mana"] = int(mana[0])
		record.source523.applied.append("mana")
	for entry: Dictionary in profile.bonuses:
		if str(entry.type.Name) == "NextSpellClassID":
			record.source523["pending_chain"] = true
			break
	return record

static func target_allowed(skill: Dictionary, target: TwilightMonster) -> bool:
	if is_instance_valid(target) and target.concealed523: return false
	if not skill.has("source523"): return true
	if not str(skill.get("source523_block_reason", "")).is_empty(): return false
	if not is_instance_valid(target) or target.dead: return false
	var kind := str(skill.source523.target_kind)
	if kind == "Undead": return target.is_undead()
	return kind in ["All", "AllButMe", "Enemy", "TargetNEnemy", "AttackableNPC"]

static func target_text(source: Dictionary) -> String:
	if bool(source.get("recovery",{}).get("self_branch",false)):return "자신 (원본 허용 대상 중 자기 분기)"
	if bool(source.get("estimated_self_only", false)): return "자신 강화 (추정 분기)"
	if str(source.target_kind) == "InvisibleAndMeButCompany": return "자신과 주변 은신 대상 (아군 제외)"
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
	if source.has("recovery"):
		text+="\n원본 + TWILIGHT 설정 · 자기 기본 단계\n"+str(source.recovery.summary)
		if str(skill.id)=="lm_1fb2fb45ca7bb6e5":text+="\n파티 회복·미구현 계약 상태는 현재 싱글플레이 범위 밖"
	if source.has("progression"):text+="\n원본 실행 연결 + TWILIGHT 설정\n"+str(source.progression.summary)
	if source.has("estimated"):
		text += "\nTWILIGHT 추정 적용 · 원본 노드 복원 아님\n" + str(source.estimated.summary)
		if str(skill.get("activation", "")) == "passive": return text + "\n누적523 원문은 패시브 · 습득 후 자동 적용 · 직접 시전/재료 소비 없음"
	if source.has("pending_note"): text += "\n" + str(source.pending_note)
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
	if source.applied.has("mana"):
		text += "\nMP 회복: %d (원본 기본 단계 · 최대 MP까지)" % int(skill.mana)
	if bool(source.get("pending_chain", false)): text += "\n추가 연계 효과: 발동 조건 확인 전 적용 보류"
	text += "\n523 원본 비용 적용"
	text += "\n거리·효과·분기·재사용은 TWILIGHT 추정 · 최종 전투 수식은 기존 게임 설정" if source.has("estimated") else "·대상 제한 적용\n거리·시전 시간·전투 수식은 기존 게임 설정"
	return text

static func duration_text(skill: Dictionary) -> String:
	if skill.has("recovery523") and float(skill.get("duration",0))<=0:return "즉시"
	if skill.get("source523", {}).get("applied", []).has("duration_bounds") or (skill.has("estimated523") and str(skill.get("mode", "")) == "status"):
		var bounds: Array = skill.get("duration_bounds", [])
		if bounds.size() == 2: return "%.1f~%.1f초" % [float(bounds[0]), float(bounds[1])]
	if skill.get("estimated523", {}).get("kind", "") == "damage": return "즉시"
	return "%.1f초" % float(skill.get("duration", 0))
