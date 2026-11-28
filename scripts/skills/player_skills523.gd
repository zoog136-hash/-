extends RefCounted
## Optional exact-ID 523 evidence adapter. Original bytes live in a private pack.
## An optional labelled numeric distance policy preserves the existing engine.
## CastDelay = own reuse delay in ms (user decision 2026-11-12). Proc timing,
## AC and hit/damage formulae are not inferred here.
const BINDINGS_PATH := "res://data/skills/player_skills523_bindings.json"
const DISTANCE_INPUT_POLICY_PATH := "res://data/skills/current523_distance_input_policy.json"
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const MAX_BYTES := 16 * 1024 * 1024
const SOURCE_ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const PROFILE_BAKE := "player_original_profiles523"
const SOURCE_SPELLS = preload("res://scripts/resources/current523_spell_data.gd")
const SOURCE_BONUSES = preload("res://scripts/resources/current523_bonus_data.gd")
const SOURCE_BUFFS = preload("res://scripts/resources/current523_buff_data.gd")
const SOURCE_ELEMENT_CHANNELS = {"None":"physical","Fire":"fire","Water":"water","Air":"wind","Earth":"earth","Light":"holy","Dark":"dark"}
const RELIC_SOURCE_INPUT = preload("res://scripts/resources/current523_relic_spell_input.gd")
const SPELL_MOVE = preload("res://scripts/skills/spell_move523.gd")
# Exact ordered node lists from build_player_skills523.py. No composition-node
# traversal or unreviewed recursive expansion is performed by the reader.
const REVIEWED_EXECUTION_GRAPHS := {
	2:[],2312:[],332:[],29142:[],17324:[],
	98871:[99181,99231],350:[119642,120712],
	29092:[122982,122992],69581:[70961,107343,107963,71001]}
const SOURCE_RECOVERY_ROOTS := [54703,35443,69601,95662]
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
var source_mode: String = ""
var source_identity: Dictionary = {}
var source_fallback_status: Dictionary = {}
## Materials whose original item is held (e.g. TestItem=true); never spent.
var material_holds: Dictionary = {}
var relic_source_input_status: Dictionary = {}
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

## Table-direct passive contract (docs/skill523_source_hold_report.md).
## Original BuffBonus type -> [existing skill stat() key, required Unit.Name].
## Every key is a flat value already read through original_skills.stat().
const SOURCE_DIRECT_PASSIVE_STATS := {
	"DamageReduction":["damageReduction","Value"], "ArmorClassBonus":["def","Value"], "ArmorClass":["def","Value"],
	"MeleeHit":["meleeHit","Value"], "RangeHit":["rangedHit","Value"], "MeleeDamage":["meleeDamage","Value"],
	"RangeDamage":["rangedDamage","Value"], "MagicResist":["mr","Value"], "HPPlus":["hp","Value"], "MPPlus":["mp","Value"],
	"Strength":["str","Value"], "Dexterity":["dex","Value"], "Intelligence":["int","Value"]}

## A reference passive opens only when the original tables state every part:
## one unconditional BuffClass, freely overlapping buff group, no erase rule,
## and only flat stat rows with a known unit and an existing consumer. PvP-only
## rows have no PvE recipient and are kept as data. Returns {"reason":...} otherwise.
func source_direct_passive(id: String, job: String) -> Dictionary:
	var profile: Dictionary = profiles.get(id, {})
	if profile.is_empty(): return {"reason":"원본 프로필 없음"}
	var row: Dictionary = profile.row
	if int(row.SpellTypeID) != 3: return {"reason":"액티브 주문(SpellType %d)의 효과 실행 계약 없음(아래 보류 이유 참고)" % int(row.SpellTypeID)}
	if int(row.SpellCompositionNode) != 0: return {"reason":"조건 노드 %d 정의 없음" % int(row.SpellCompositionNode)}
	if not profile.costs.is_empty() or int(row.SpellMaterialItemAmount) != 0 or int(row.MPCost) != 0 or int(row.HPCost) != 0: return {"reason":"패시브에 비용 행이 있음"}
	var buff_ids: Array[int] = []
	for entry: Dictionary in profile.bonuses:
		if int(entry.link.MinSpellLevel) != 0: continue # base level only (existing policy)
		var name: String = str(entry.type.Name)
		if name != "BuffClassID" or str(entry.unit.Name) != "BuffClassID" or int(entry.bonus.BonusApplicationTypeID) != 0 or int(entry.bonus.BonusApplicationTargetID) != 0:
			return {"reason":"주문 보너스 %s의 실행 규칙이 표에 없음" % name}
		buff_ids.append(int(entry.bonus.Value))
	if buff_ids.size() != 1 or profile.buffs.size() != 1 or int(profile.buffs[0].row.ID) != buff_ids[0]: return {"reason":"버프 연결이 하나가 아님"}
	var buff: Dictionary = profile.buffs[0]
	if bool(buff.row.get("IsBuffGroup", true)):
		var group: Dictionary = SOURCE_ROWS.row("BuffGroup", int(buff.row.get("BuffGroupID", -1)))
		if group.is_empty() or group.get("IsAllowOverlap") != true: return {"reason":"버프 그룹 %d 중첩 규칙 미지원" % int(buff.row.get("BuffGroupID", -1))}
	for key: String in buff.row:
		if not key.begins_with("IsEraseOn"): continue
		var flag: Variant = buff.row[key]
		# Bools and numeric counters alike: any set erase condition is a rule.
		if (typeof(flag) == TYPE_BOOL and flag) or (typeof(flag) in [TYPE_INT,TYPE_FLOAT] and float(flag) != 0.0): return {"reason":"버프 해제 조건 %s 미지원" % key}
	var stats: Dictionary = {}
	var ignored: Array[String] = []
	var rows: Array = []
	for entry: Dictionary in buff.bonuses:
		if int(entry.link.get("MinSpellLevel", 0)) != 0: continue
		var name: String = str(entry.type.Name)
		if int(entry.link.get("CharacterLevel", 0)) != 0 or int(entry.link.get("CharacterClass", 0)) != 0: return {"reason":"%s의 캐릭터 레벨/직업 조건 해석이 표에 없음" % name}
		if int(entry.bonus.BonusApplicationTypeID) != 0 or int(entry.bonus.BonusApplicationTargetID) != 0: return {"reason":"%s의 적용 대상 조건 미지원" % name}
		if not _source_integer(entry.bonus.Value): return {"reason":"%s 값이 정수가 아님" % name}
		if name.begins_with("PVP"):
			ignored.append(name); continue
		var mapped: Array = SOURCE_DIRECT_PASSIVE_STATS.get(name, [])
		if mapped.is_empty() or str(entry.unit.Name) != str(mapped[1]): return {"reason":"%s(%s) 수신부 없음" % [name, str(entry.unit.Name)]}
		stats[str(mapped[0])] = int(stats.get(str(mapped[0]), 0)) + int(entry.bonus.Value)
		rows.append({"type":name,"value":int(entry.bonus.Value),"unit":str(entry.unit.Name),"stat":str(mapped[0])})
	if stats.is_empty(): return {"reason":"PvE에서 적용할 수치가 없음"}
	var native_class := int(bindings.class_ids.get(job, -1))
	var minimum := -1
	for limit: Dictionary in profile.learn_limits:
		if int(limit.ClassID) != native_class or bool(limit.IsTutorialSpell): continue
		if int(limit.CharacterPolymorphGradeID) != 0 or int(limit.LimitBuffCardID) != 0: return {"reason":"학습 변신 등급/카드 조건 미지원"}
		minimum = int(limit.CharacterMinLevel)
	if minimum < 0: return {"reason":"이 직업의 SpellLearnLimit 행 없음"}
	return {"stats":stats,"minimum_level":minimum,"buff_id":int(buff.row.ID),"rows":rows,"ignored_pvp":ignored}

## Load-time projection on the shared catalog record (as prepare_estimate does).
func prepare_source_direct(record: Dictionary) -> void:
	var id := str(record.get("id", ""))
	if not id.begins_with("lmref_") or not profiles.has(id) or record.has("estimated523") or bool(record.get("local_design", false)): return
	var row: Dictionary = profiles[id].row
	record["source523_cast_delay_ms"] = int(row.CastDelay)
	if not bool(record.get("runtime_blocked", false)): return
	if str(record.get("activation", "")) != "passive" and record.get("cooldown") == null and _source_integer(row.CastDelay):
		record["cooldown"] = float(row.CastDelay) / 1000.0 # shown on the hold screen
	var spec := source_direct_passive(id, str(record.get("class", "")))
	if spec.has("reason") or not spec.has("rows"):
		var approx := source_approx_passive(id, str(record.get("class", "")))
		if approx.has("reason") and int(profiles[id].row.SpellTypeID) != 3:
			var active := source_approx_active(id, str(record.get("class", "")))
			if not active.has("reason"):
				_open_approx_active(record, active)
				return
			approx = active
		if approx.has("reason"):
			record["source_direct523_hold"] = [str(spec.get("reason","원본 표 직접 실행 계약 확인 실패")), "근사 규칙: " + str(approx.reason)]
			return
		_open_approx_passive(record, approx)
		return
	var parts := PackedStringArray()
	for entry: Dictionary in spec.rows: parts.append("%s %+d" % [str(entry.type), int(entry.value)])
	var summary := "패시브 · 원본 523 기본 단계 %s (BuffClass %d)" % [" · ".join(parts), int(spec.buff_id)]
	if not spec.ignored_pvp.is_empty(): summary += " · PvP 전용 %s는 PvE 대상 없음" % ", ".join(PackedStringArray(spec.ignored_pvp))
	record.merge({"runtime_blocked":false,"activation":"passive","mode":"stats","stats":spec.stats,"mp":0,"hp":0,"items":{},
		"minimum_level":int(spec.minimum_level),"local_kind":"source_direct523","desc":summary},true)
	record["source_direct523"] = {"kind":"passive_stats","spell_id":int(row.ID),"buff_id":int(spec.buff_id),"rows":spec.rows,"ignored_pvp":spec.ignored_pvp,"basis":"원본 523 SpellBonus/BuffBonus 기본 단계 · BuffGroup 중첩 허용"}
	record.erase("source_direct523_hold")

## ---- TWILIGHT 근사 (user policy 2026-11-16): reference passives whose
## original rows exist but whose interpretation rule is missing from the 523
## tables. Every interpretation lives in data/skills/source_approx523.json
## (sources and dates there); original row values are used unchanged.
const APPROX_PATH := "res://data/skills/source_approx523.json"
## 사용자 결정 2026-11-16 13:46: PvP 전용 스킬의 효과를 몬스터에게 적용 (TWILIGHT 근사).
const PVP_TARGET_TO_NPC := true
## TWILIGHT 근사 switch: SpellTransformID (스킬 대체) of approximated passives.
const APPROX_TRANSFORMS := true
## TWILIGHT 근사 switch: passives made of child passive SpellClassID rows.
const APPROX_CHILD_PASSIVES := true
var approx_policy: Dictionary = {}
var _spell_records: Dictionary = {}

func approx_rules() -> Dictionary:
	if approx_policy.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(APPROX_PATH)) if FileAccess.file_exists(APPROX_PATH) else null
		approx_policy = value if value is Dictionary and int(value.get("schema",0)) == 1 else {"schema":0}
	return approx_policy

## Bound record id for an original SpellClass ID ("" when not bound).
func record_for_spell(spell_id: int) -> String:
	if _spell_records.is_empty():
		for key: String in bindings.get("skills",{}): _spell_records[int(bindings.skills[key].get("spell_id",-1))] = key
	return str(_spell_records.get(spell_id, ""))

static func weapon_group_types(group_id: int) -> Array[int]:
	var result: Array[int] = []
	for entry: Dictionary in SOURCE_ROWS.related("WeaponTypeForWeaponGroup","WeaponGroupID",group_id):
		if _source_integer(entry.get("WeaponTypeID")) and int(entry.WeaponTypeID) not in result: result.append(int(entry.WeaponTypeID))
	return result

func _approx_invoke(option_id: int, chance: float, level: int) -> Dictionary:
	var policy: Dictionary = approx_rules().get("invokes",{})
	var option: Dictionary = SOURCE_ROWS.row("InvokeOption", option_id)
	if option.is_empty(): return {"reason":"InvokeOption %d 없음" % option_id}
	var type_name: String = str(SOURCE_ROWS.row("InvokeOptionType", int(option.get("InvokeOptionTypeID",-1))).get("Name",""))
	var rule: Dictionary = policy.get("types",{}).get(type_name,{})
	if rule.is_empty(): return {"reason":"발동 옵션 " + type_name}
	var kinds: Array = policy.get("attack_types",{}).get(str(int(option.get("AttackTypeID",0))),[])
	if kinds.is_empty(): return {"reason":"발동 옵션 공격 종류 %d" % int(option.get("AttackTypeID",0))}
	var result: Dictionary = {"kind":str(rule.kind),"option_id":option_id,"option_type":type_name,"chance":chance * float(policy.get("chance_scale",0.000001)),
		"level":level,"attack_kinds":kinds.duplicate(),"by_spell":bool(option.get("BySpellAttack",false)),"weapons":[]}
	if int(option.get("WeaponGroupID",0)) > 0: result.weapons = weapon_group_types(int(option.WeaponGroupID))
	match str(rule.kind):
		"amplify":
			var multiplier: float = float(option.get(str(rule.multiplier_param),0)) * float(rule.multiplier_scale)
			if multiplier <= 0.0: return {"reason":"발동 옵션 증폭율 0"}
			if multiplier < 1.0 and str(rule.get("below_one","")) == "add_one": multiplier += 1.0
			result["multiplier"] = multiplier
		"evade_heal":
			result["percent"] = float(option.get(str(rule.percent_param),0))
			result["base"] = float(option.get(str(rule.base_param),0))
			result["cooldown"] = float(option.get(str(rule.cooldown_param),0))
		"spell":
			var child := approx_child_spell(int(option.get(str(rule.spell_param),0)))
			if child.has("reason"): return {"reason":"발동 하위 주문 " + str(child.reason)}
			result["spell"] = child
			result["main_target_only"] = bool(option.get("Param4",false))
	return result

## TWILIGHT 근사: the child SpellClass an Attack_Spell invoke casts, reduced to
## one of three effects the existing runtime has: direct damage (original
## SpellDamageBase + DiceNumber d DiceSpotCount), a timed debuff on the target
## (original BuffClass rows through the existing target modifiers), or a timed
## self buff (original BuffClass rows through the passive receivers). Anything
## else (composition nodes, chained/next spells, area shapes) keeps the hold.
const EQUIPMENT_SPELLS = preload("res://scripts/crafting/patch523_equipment_spells.gd")
## TWILIGHT 근사 (4) switch: heal / cleanse / dash / control statuses (docs (4)).
const APPROX_EXTRA_EFFECTS := true
## Target rows the equipment-spell fields lack: [modifier, UnitID, scale].
## TWILIGHT 근사(근거 약함) 2026-11-17: AttackedMeleeDamageScale (Percentage, 350000 = 35 %)
## = the target takes that much more damage → the existing "taken" multiplier (fraction).
## The Range/Magic/Dark rows of the same buff are not added on top (one multiplier).
const APPROX_TARGET_FIELDS := {"ArmorClass":["ac",1,-1.0],"AttackedMeleeDamageScale":["taken",3,0.000001]}
func approx_child_spell(spell_id: int, allow_next: int = 0) -> Dictionary:
	var row: Dictionary = SOURCE_ROWS.row("SpellClass", spell_id)
	if row.is_empty() or row.get("TestSpell") != false: return {"reason":"%d 없음/테스트" % spell_id}
	if int(row.get("SpellCompositionNode",0)) != 0 or int(row.get("SpellCategoryID",0)) == 371: return {"reason":"%d 조건 노드" % spell_id}
	var rule: Dictionary = approx_rules().get("invokes",{}).get("child_spell",{})
	var detail: Dictionary = SOURCE_SPELLS.describe(spell_id)
	var values: Dictionary = {}
	var buff_id := 0
	var ignored: Array[String] = []
	for entry: Dictionary in detail.get("bonuses",[]):
		if int(entry.link.get("MinSpellLevel",0)) != 0: continue
		var name: String = str(entry.type.get("Name",""))
		if not _source_integer(entry.bonus.get("Value")): ignored.append(name); continue
		if int(entry.bonus.get("BonusApplicationTypeID",0)) != 0 or int(entry.bonus.get("BonusApplicationTargetID",0)) != 0:
			if name not in ignored: ignored.append(name)
			continue
		if name == "BuffClassID":
			if buff_id != 0: return {"reason":"%d 버프 둘 이상" % spell_id}
			buff_id = int(entry.bonus.Value)
		elif name == "SpellCastAll" and allow_next > 0: continue
		elif name == "SpellClassID" and allow_next > 0 and _source_integer(entry.bonus.Value):
			# TWILIGHT 근사 "묶음 하위 주문" (active): child spells run in table order.
			var sub := approx_child_spell(int(entry.bonus.Value), allow_next - 1)
			# TWILIGHT 근사 (5): a child whose rows have no receiver is left out (listed)
			# when another child of the bundle runs; a bundle with none still holds.
			if sub.has("reason") and APPROX_EXTRA_EFFECTS and (str(sub.reason).contains("받는 곳 없음") or str(sub.reason).ends_with("효과 없음")):
				ignored.append("하위 주문 %d 미적용(%s)" % [int(entry.bonus.Value), str(sub.reason)])
				values["_skipped_children"] = int(values.get("_skipped_children",0)) + 1
				continue
			if sub.has("reason"): return {"reason":"%d 하위 주문 %s" % [spell_id, str(sub.reason)]}
			if not values.has("_children"): values["_children"] = []
			values._children.append(sub)
		elif name == "NextSpellClassID" and allow_next > 0 and _source_integer(entry.bonus.Value):
			# TWILIGHT 근사 (active spells): the follow-up spell runs right after,
			# on the same target, when it reduces to the same three effects.
			var next := approx_child_spell(int(entry.bonus.Value), allow_next - 1)
			if next.has("reason"): return {"reason":"%d 후속 주문 %s" % [spell_id, str(next.reason)]}
			values["_next"] = next
		elif name in rule.get("blocking",[]): return {"reason":"%d %s" % [spell_id, name]}
		elif name in rule.get("read",[]): values[name] = int(entry.bonus.Value)
		elif APPROX_EXTRA_EFFECTS and name == "HPRestorationPercent":
			# Several level rows: the lowest (가장 보수적인 값).
			values["HPRestorationPercent"] = mini(int(values.get("HPRestorationPercent", int(entry.bonus.Value))), int(entry.bonus.Value))
		elif APPROX_EXTRA_EFFECTS and name == "SpellBuffGroup": values["_cleanse"] = true
		elif APPROX_EXTRA_EFFECTS and name == "SpellMoveMultiple": values["_dash"] = int(entry.bonus.Value)
		elif name not in ignored: ignored.append(name)
	values.erase("_skipped_children")
	var base: Dictionary = {"spell_id":spell_id,"name":str(row.get("Name","")),"ignored":ignored}
	if values.has("_dash"):
		# TWILIGHT 근사 "이동기": SpellMoveMultiple = a dash to the target, then the follow-up spell.
		base["dash"] = true
		values.erase("_dash")
	if values.has("_children"):
		# Chain: children in order, then the own follow-up spell (if any).
		var chain: Array = values._children.duplicate()
		values.erase("_children")
		if values.has("_next"): chain.append(values._next)
		for index: int in range(chain.size() - 2, -1, -1):
			var link: Dictionary = (chain[index] as Dictionary).duplicate(true)
			var tail: Dictionary = link
			while tail.has("next"): tail = tail.next
			tail["next"] = chain[index + 1]
			chain[index] = link
		values["_next"] = chain[0]
	if values.has("_next"):
		base["next"] = values._next
		values.erase("_next")
		if not values.has("SpellDamageBase") and not values.has("SpellDamageDiceNumber") and buff_id <= 0:
			var only: Dictionary = base.next.duplicate(true)
			only["spell_id"] = spell_id; only["name"] = str(row.get("Name",""))
			if base.get("dash",false): only["dash"] = true
			return only
	if values.has("SpellDamageBase") or values.has("SpellDamageDiceNumber"):
		var number := int(values.get("SpellDamageDiceNumber",0)); var sides := int(values.get("SpellDamageDiceSpotCount",0))
		if number < 0 or number > 100 or (number > 0 and sides < 1): return {"reason":"%d 주사위" % spell_id}
		base.merge({"effect":"damage","base":int(values.get("SpellDamageBase",0)),"number":number,"sides":sides,
			"attack_type":"melee" if int(values.get("SpellAttackType",0)) == 1 else ("ranged" if int(values.get("SpellAttackType",0)) == 2 else "magic")})
		return base
	if buff_id <= 0 and APPROX_EXTRA_EFFECTS:
		# TWILIGHT 근사 (4): self heal (HPRestorationPercent, 1/10000 %) and status
		# cleanse (SpellBuffGroup rows = the groups it removes) through the existing player.
		if values.has("HPRestorationPercent") and int(values.HPRestorationPercent) > 0:
			base.merge({"effect":"heal_pct","percent":float(values.HPRestorationPercent) / 10000.0,"cleanse":values.has("_cleanse")})
			return base
		if values.has("_cleanse"):
			base.merge({"effect":"cleanse"})
			return base
		if base.get("dash",false):
			base.merge({"effect":"dash"})
			return base
	if buff_id <= 0: return {"reason":"%d 효과 없음" % spell_id}
	var buff: Dictionary = SOURCE_BUFFS.describe(buff_id)
	if buff.get("buff_class",{}).is_empty() or buff.get("excluded") == true: return {"reason":"버프 %d 없음" % buff_id}
	if int(values.get("SpellBuffDuration",0)) > 0:
		var stats: Dictionary = {}
		var receivers: Dictionary = approx_rules().get("receivers",{})
		for entry: Dictionary in buff.get("bonuses",[]):
			var name: String = str(entry.get("type",{}).get("Name",""))
			var receiver: Dictionary = receivers.get(name,{})
			var flat: bool = int(entry.get("link",{}).get("CharacterLevel",0)) == 0 and int(entry.get("link",{}).get("MinSpellLevel",0)) == 0 and int(entry.get("bonus",{}).get("BonusApplicationTypeID",0)) == 0 and int(entry.get("bonus",{}).get("BonusApplicationTargetID",0)) == 0
			var at_value := int(entry.get("bonus",{}).get("BonusApplicationTypeID",0))
			var target_stat := ""
			# TWILIGHT 근사 (4): SpecialResistance (적용 유형 2 + 저항 종류) on a self buff, as on passives.
			if APPROX_EXTRA_EFFECTS and receiver.has("targets") and at_value == int(receiver.get("application_type",-1)) and int(entry.get("link",{}).get("CharacterLevel",0)) == 0:
				target_stat = str(receiver.targets.get(str(int(entry.get("bonus",{}).get("BonusApplicationTargetID",0))),""))
			if not target_stat.is_empty() and str(entry.get("unit",{}).get("Name","")) == str(receiver.get("unit","")) and _source_integer(entry.get("bonus",{}).get("Value")):
				stats[target_stat] = float(stats.get(target_stat,0.0)) + float(entry.bonus.Value) * float(receiver.get("scale",1))
				continue
			if receiver.is_empty() or receiver.has("targets") or receiver.has("weapon_types") or not flat or str(entry.get("unit",{}).get("Name","")) != str(receiver.get("unit","")) or not _source_integer(entry.get("bonus",{}).get("Value")):
				if name not in ignored: ignored.append(name)
				continue
			var key := "speedPct" if str(receiver.stat) == "moveSpeedPct" else str(receiver.stat)
			stats[key] = float(stats.get(key,0.0)) + float(entry.bonus.Value) * float(receiver.get("scale",1))
		if stats.is_empty(): return {"reason":"자기 버프 %d 받는 곳 없음" % buff_id}
		if stats.has("speedPct"): stats["speed"] = 1.0 + float(stats.speedPct) / 100.0; stats.erase("speedPct")
		base.merge({"effect":"self_buff","buff_id":buff_id,"duration":float(values.SpellBuffDuration),"stats":stats})
		return base
	var low := int(values.get("SpellDebuffMinDuration",0)); var high := int(values.get("SpellDebuffMaxDuration",low))
	if low <= 0 or high < low: return {"reason":"%d 지속시간 없음" % spell_id}
	var modifiers: Dictionary = {}
	var control: Dictionary = {}
	for entry: Dictionary in buff.get("bonuses",[]):
		var t: Dictionary = entry.get("type",{}); var b: Dictionary = entry.get("bonus",{}); var name: String = str(t.get("Name",""))
		var field: Array = EQUIPMENT_SPELLS.BUFF_FIELDS.get(name, APPROX_TARGET_FIELDS.get(name, []) if APPROX_EXTRA_EFFECTS else [])
		if APPROX_EXTRA_EFFECTS and name in ["CannotMove","CannotAttack","CannotCastSpell","CannotCastSkill","PoisonDamageDiceNumber","PoisonDamageDiceSpotCount"] and _source_integer(b.get("Value")):
			control[name] = int(b.Value); continue
		var flat: bool = int(entry.get("link",{}).get("CharacterLevel",0)) == 0 and int(b.get("BonusApplicationTypeID",0)) == 0 and int(b.get("BonusApplicationTargetID",0)) == 0
		if field.is_empty() or not flat or int(t.get("UnitID",-1)) != int(field[1]) or not _source_integer(b.get("Value")) or name.begins_with("PVP"):
			if name not in ignored: ignored.append(name)
			continue
		modifiers[str(field[0])] = float(modifiers.get(str(field[0]),0.0)) + float(b.Value) * float(field[2])
	# TWILIGHT 근사 (4): control rows → the existing monster statuses (근거 약함):
	# CannotMove + CannotAttack = stun (잠·기절), CannotMove = hold, CannotCastSpell/Skill = silence,
	# PoisonDamageDice = poison (tick = average die, 1 s).
	var status_kind := ""
	var tick := 0
	if control.has("CannotMove") and control.has("CannotAttack"): status_kind = "stun"
	elif control.has("CannotMove"): status_kind = "hold"
	elif control.has("CannotCastSpell") or control.has("CannotCastSkill"): status_kind = "silence"
	elif control.has("PoisonDamageDiceNumber"):
		status_kind = "poison"; tick = maxi(1, int(round(float(control.PoisonDamageDiceNumber) * (float(control.get("PoisonDamageDiceSpotCount",1)) + 1.0) / 2.0)))
	if modifiers.is_empty() and status_kind.is_empty(): return {"reason":"대상 버프 %d 받는 곳 없음" % buff_id}
	if not status_kind.is_empty(): base.merge({"status":status_kind,"tick_damage":tick})
	var chance := 1.0
	if values.has("SpellHitProbabilityBase"):
		chance = clampf(float(values.SpellHitProbabilityBase) / 1000000.0, float(values.get("SpellHitProbabilityMin",0)) / 1000000.0, float(values.get("SpellHitProbabilityMax",1000000)) / 1000000.0)
	base.merge({"effect":"debuff","buff_id":buff_id,"duration":[float(low),float(high)],"modifiers":modifiers,"hit_chance":chance})
	return base

## Approximated passive contract. Returns {"reason":...} when still held.
func source_approx_passive(id: String, job: String, given_profile: Dictionary = {}, child_depth: int = 0) -> Dictionary:
	var policy: Dictionary = approx_rules()
	var profile: Dictionary = given_profile if not given_profile.is_empty() else profiles.get(id, {})
	if profile.is_empty() or int(policy.get("schema",0)) != 1: return {"reason":"근사 규칙 파일 없음"}
	var row: Dictionary = profile.row
	if int(row.SpellTypeID) != 3: return {"reason":"액티브 주문"}
	if int(row.SpellCompositionNode) != 0: return {"reason":"조건 노드 %d" % int(row.SpellCompositionNode)}
	if not profile.costs.is_empty() or int(row.SpellMaterialItemAmount) != 0 or int(row.MPCost) != 0 or int(row.HPCost) != 0: return {"reason":"패시브 비용 행"}
	var native_class := int(bindings.class_ids.get(job, -1))
	var weapons: Array[int] = []
	var requires: Array[String] = []
	var buff_ids: Array[int] = []
	var children: Array = []
	var toggled: Dictionary = {}
	for entry: Dictionary in profile.bonuses:
		if int(entry.link.MinSpellLevel) != 0: continue
		var name: String = str(entry.type.Name)
		# TWILIGHT 근사 (4, 근거 약함): a #OFF/#ON toggle passive has no toggle UI here, so
		# learning it is treated as ON — the ON spell (ChangeSpecialSpellClassID /
		# ToggleOnSpellClassID, same value) is merged like a child passive.
		if name in ["ChangeSpecialSpellClassID","ToggleOnSpellClassID"] and APPROX_EXTRA_EFFECTS and _source_integer(entry.bonus.Value):
			if toggled.has(int(entry.bonus.Value)): continue
			toggled[int(entry.bonus.Value)] = true
			name = "SpellClassID"
		if name == "SpellClassID" and APPROX_CHILD_PASSIVES and child_depth < 2 and int(entry.bonus.BonusApplicationTypeID) == 0 and _source_integer(entry.bonus.Value):
			# TWILIGHT 근사 "묶음 하위 주문": a passive made of child passives takes
			# each child's own rows (with the child's own weapon/prerequisite rows).
			var built: Dictionary = _source_profile(int(entry.bonus.Value)).get("profile",{})
			var sub: Dictionary = source_approx_passive("", job, built, child_depth + 1) if not built.is_empty() else {"reason":"하위 주문 %d 없음" % int(entry.bonus.Value)}
			if sub.has("reason"): return {"reason":"하위 주문 %d: %s" % [int(entry.bonus.Value), str(sub.reason)]}
			children.append(sub)
			continue
		if name not in policy.get("spell_bonus_allowed",[]): return {"reason":"주문 보너스 %s" % name}
		if not _source_integer(entry.bonus.Value): return {"reason":"%s 값" % name}
		match name:
			"BuffClassID": buff_ids.append(int(entry.bonus.Value))
			"RequiredSpellClassID":
				var required := record_for_spell(int(entry.bonus.Value))
				if required.is_empty(): return {"reason":"선행 주문 %d 미연결" % int(entry.bonus.Value)}
				if required not in requires: requires.append(required)
			"WeaponType": weapons.append(int(entry.bonus.Value))
			"WeaponGroup": weapons.append_array(weapon_group_types(int(entry.bonus.Value)))
	if buff_ids.is_empty() and children.is_empty(): return {"reason":"버프 연결 없음"}
	var receivers: Dictionary = policy.get("receivers",{})
	var rows: Array = []
	var invokes: Array = []
	var transforms: Array = []
	var ignored: Dictionary = {}
	var group: Dictionary = {}
	for buff: Dictionary in profile.buffs:
		if int(buff.row.ID) not in buff_ids: continue
		for key: String in buff.row:
			if not key.begins_with("IsEraseOn") or key == "IsEraseOnTimeEnd": continue
			var flag: Variant = buff.row[key]
			if (typeof(flag) == TYPE_BOOL and flag) or (typeof(flag) in [TYPE_INT,TYPE_FLOAT] and float(flag) != 0.0): return {"reason":"버프 해제 조건 %s" % key}
		if bool(buff.row.get("IsBuffGroup", false)):
			var group_row: Dictionary = SOURCE_ROWS.row("BuffGroup", int(buff.row.get("BuffGroupID",-1)))
			var candidate := {"id":int(buff.row.get("BuffGroupID",-1)),"overlap":group_row.get("IsAllowOverlap") == true,"priority":int(buff.row.get("BuffGroupPriority",0)),"buff_id":int(buff.row.ID)}
			if group.is_empty() or int(candidate.priority) > int(group.priority): group = candidate
		for entry: Dictionary in buff.bonuses:
			if int(entry.link.get("MinSpellLevel",0)) != 0: continue
			var cls := int(entry.link.get("CharacterClass",0))
			if cls != 0 and cls != native_class: continue
			var name: String = str(entry.type.Name)
			var unit: String = str(entry.unit.Name)
			var at := int(entry.bonus.BonusApplicationTypeID)
			var target := int(entry.bonus.BonusApplicationTargetID)
			var level := int(entry.link.get("CharacterLevel",0))
			if not _source_integer(entry.bonus.Value): ignored[name] = int(ignored.get(name,0)) + 1; continue
			var value := float(entry.bonus.Value)
			if name.begins_with("PVP") and not receivers.has(name): ignored[name] = int(ignored.get(name,0)) + 1; continue
			if name in ["WeaponType","WeaponGroup"] and at == 0 and target == 0:
				if name == "WeaponType": weapons.append(int(value))
				else: weapons.append_array(weapon_group_types(int(value)))
				continue
			if name == "SpellTransformID" and at == 1 and APPROX_TRANSFORMS:
				# TWILIGHT 근사: "스킬 대체" — casting the bound skill of SpellClass
				# `target` runs this SpellClass instead (when it reduces to the
				# damage / debuff / self buff effects).
				var replaced := record_for_spell(target)
				var child := approx_child_spell(int(value), 2) if not replaced.is_empty() else {"reason":"대상 주문 %d 미연결" % target}
				if child.has("reason"): ignored["스킬 대체 " + str(child.reason).split(" ")[0]] = int(ignored.get("스킬 대체 " + str(child.reason).split(" ")[0],0)) + 1
				else: transforms.append({"from_spell":target,"record":replaced,"to_spell":int(value),"level":level,"child":child})
				continue
			if name == "InvokeOption" and at == 10:
				var invoke := _approx_invoke(target, value, level)
				if invoke.has("reason"): ignored[str(invoke.reason)] = int(ignored.get(str(invoke.reason),0)) + 1
				else: invokes.append(invoke)
				continue
			var receiver: Dictionary = receivers.get(name, {})
			var stat := str(receiver.get("stat",""))
			if receiver.has("targets"):
				stat = str(receiver.targets.get(str(target),"")) if at == int(receiver.get("application_type",-1)) else ""
			elif at != 0 or target != 0: stat = ""
			if receiver.is_empty() or stat.is_empty() or unit != str(receiver.get("unit","")):
				ignored[name] = int(ignored.get(name,0)) + 1; continue
			var row_weapons: Array[int] = []
			# JSON numbers are floats; 7 in [7.0] is false in Godot 4.
			for weapon: Variant in receiver.get("weapon_types",[]): row_weapons.append(int(weapon))
			rows.append({"type":name,"stat":stat,"value":value * float(receiver.get("scale",1)),"level":level,"weapons":row_weapons})
	for sub: Dictionary in children:
		for entry: Dictionary in sub.rows:
			var merged: Dictionary = entry.duplicate(true)
			if not sub.weapons.is_empty() and merged.weapons.is_empty(): merged.weapons = sub.weapons.duplicate()
			rows.append(merged)
		for invoke: Dictionary in sub.invokes:
			var merged_invoke: Dictionary = invoke.duplicate(true)
			if not sub.weapons.is_empty() and merged_invoke.weapons.is_empty(): merged_invoke.weapons = sub.weapons.duplicate()
			invokes.append(merged_invoke)
		transforms.append_array(sub.transforms)
		for required: String in sub.requires:
			if required not in requires: requires.append(required)
		for key: String in sub.ignored: ignored[key] = int(ignored.get(key,0)) + int(sub.ignored[key])
	if rows.is_empty() and invokes.is_empty() and transforms.is_empty(): return {"reason":"받는 곳이 있는 수치 없음(" + ", ".join(PackedStringArray(ignored.keys())) + ")"}
	if child_depth > 0:
		return {"spell_id":int(row.ID),"rows":rows,"invokes":invokes,"transforms":transforms,"weapons":weapons,"requires":requires,"group":group,"minimum_level":0,"ignored":ignored}
	var minimum := -1
	var required_card := 0
	for limit: Dictionary in profile.learn_limits:
		if int(limit.ClassID) != native_class or bool(limit.IsTutorialSpell): continue
		if int(limit.CharacterPolymorphGradeID) != 0: return {"reason":"학습 변신 등급 조건"}
		# TWILIGHT 근사: LimitBuffCardID = that card owned (card_requirement523, checked by skill_catalog.owned).
		if int(limit.LimitBuffCardID) != 0: required_card = int(limit.LimitBuffCardID)
		minimum = int(limit.CharacterMinLevel)
	if minimum < 0: return {"reason":"이 직업의 SpellLearnLimit 행 없음"}
	var unique_weapons: Array[int] = []
	for weapon: int in weapons:
		if weapon not in unique_weapons: unique_weapons.append(weapon)
	return {"spell_id":int(row.ID),"rows":rows,"invokes":invokes,"transforms":transforms,"weapons":unique_weapons,"requires":requires,"group":group,"minimum_level":minimum,"ignored":ignored,"required_card":required_card}

## Rows that apply at this level/weapon: per bonus type, only the highest
## CharacterLevel threshold at or below the level (replacement, not a sum).
static func approx_level_rows(entries: Array, level: int, weapon: int, spell_weapons: Array) -> Array:
	if not spell_weapons.is_empty() and weapon not in spell_weapons: return []
	var best: Dictionary = {}
	for entry: Dictionary in entries:
		var limit := int(entry.get("level",0))
		if limit > level: continue
		if not entry.get("weapons",[]).is_empty() and weapon not in entry.weapons: continue
		var key := "%s|%s|%s|%s" % [str(entry.get("type",entry.get("option_type",""))),str(entry.get("stat","")),str(entry.get("attack_kinds","")),str(entry.get("by_spell",""))]
		if not best.has(key) or limit > int(best[key].level): best[key] = {"level":limit,"rows":[entry]}
		elif limit == int(best[key].level): best[key].rows.append(entry)
	var result: Array = []
	for key: String in best: result.append_array(best[key].rows)
	return result

static func approx_values(spec: Dictionary, level: int, weapon: int) -> Dictionary:
	var stats: Dictionary = {}
	for entry: Dictionary in approx_level_rows(spec.get("rows",[]), level, weapon, spec.get("weapons",[])):
		stats[str(entry.stat)] = float(stats.get(str(entry.stat),0.0)) + float(entry.value)
	return stats

func _open_approx_passive(record: Dictionary, spec: Dictionary) -> void:
	var parts := PackedStringArray()
	for entry: Dictionary in approx_level_rows(spec.rows, 999, -2, []):
		parts.append("%s %s" % [str(entry.type), str(snappedf(float(entry.value),0.01))])
	for invoke: Dictionary in spec.invokes:
		parts.append("%s 발동 %.1f%%%s" % [str(invoke.option_type), float(invoke.chance)*100.0, (" ×%.2f" % float(invoke.multiplier)) if invoke.has("multiplier") else ""])
	var summary := "패시브 · 원본 523 수치 + TWILIGHT 근사 해석 · " + " · ".join(parts)
	if not spec.weapons.is_empty(): summary += " · 무기 조건(원본 WeaponType %s)" % str(spec.weapons)
	for transform: Dictionary in spec.get("transforms",[]):
		summary += " · 스킬 대체: 원본 주문 %d → %d" % [int(transform.from_spell), int(transform.to_spell)]
	if not spec.requires.is_empty(): summary += " · 선행 스킬 필요"
	if not spec.ignored.is_empty(): summary += " · 근사 미적용: " + ", ".join(PackedStringArray(spec.ignored.keys()))
	record.merge({"runtime_blocked":false,"activation":"passive","mode":"stats","stats":{},"mp":0,"hp":0,"items":{},
		"minimum_level":int(spec.minimum_level),"local_kind":"source_approx523","desc":summary},true)
	record["source_approx523"] = spec
	if int(spec.get("required_card",0)) != 0: record["approx_required_card"] = int(spec.required_card)
	record["source_direct523"] = {"kind":"passive_approx","spell_id":int(spec.spell_id),"basis":"원본 523 BuffBonus 값 + data/skills/source_approx523.json 해석(TWILIGHT 근사)"}
	record.erase("source_direct523_hold")

## TWILIGHT 근사 active contract (사용자 지시 2026-11-16 "근사치로 다 넣어", 13:46
## PvP 전용 대상 결정): a reference active whose own SpellClass reduces to a
## damage / target debuff / self buff (approx_child_spell, follow-up spells
## allowed) opens with the original MPCost/HPCost, CastDelay cooldown, learn
## level and weapon rows. TargetKind 52 (PC 전용) is applied to monsters
## (user decision 13:46). Area spells, material costs and SpellCost rows stay held.
func source_approx_active(id: String, job: String) -> Dictionary:
	var profile: Dictionary = profiles.get(id, {})
	if profile.is_empty() or int(approx_rules().get("schema",0)) != 1: return {"reason":"근사 규칙 파일 없음"}
	var row: Dictionary = profile.row
	if int(row.SpellTypeID) == 3: return {"reason":"패시브"}
	if int(row.SpellCompositionNode) != 0: return {"reason":"조건 노드 %d" % int(row.SpellCompositionNode)}
	if not profile.costs.is_empty(): return {"reason":"대상별 비용 행"}
	if int(row.get("VPCost",0)) != 0 or int(row.get("MPCostUnit",1)) != 1: return {"reason":"VP·비용 단위"}
	# Original material cost through the existing reviewed material bridges.
	var items: Dictionary = {}
	if int(row.SpellMaterialItemAmount) > 0:
		var material := str(int(row.SpellMaterialTypeID))
		var bridge: Dictionary = bindings.get("material_inventory_keys",{}).get(material, {})
		if bridge.is_empty(): return {"reason":"재료 %s 인벤토리 연결 없음" % material}
		if material_holds.has(material): return {"reason":"원본 재료 보류 %s" % material}
		items[str(bridge.inventory_key)] = int(row.SpellMaterialItemAmount)
	var targeting := int(row.TargettingTypeID)
	if targeting not in [1,2]: return {"reason":"대상 지정 방식 %d" % targeting}
	var radius := float(row.TargetAreaRadius)
	var child := approx_child_spell(int(row.ID), 2)
	if child.has("reason"): return {"reason":str(child.reason)}
	var effect := str(child.get("effect",""))
	# TWILIGHT 근사 (4): self heal / cleanse on oneself; an ally-targeted buff
	# (TargettingType 2) has no party here, so it is cast on oneself (근거 약함).
	if targeting == 1 and effect not in ["self_buff","heal_pct","cleanse"] and float(row.TargetAreaRadius) <= 0.0: return {"reason":"자기 대상 %s" % effect}
	if targeting == 2 and effect == "self_buff" and not APPROX_EXTRA_EFFECTS: return {"reason":"대상 지정 자기 버프"}
	if targeting == 2 and effect in ["heal_pct","cleanse"] and not APPROX_EXTRA_EFFECTS: return {"reason":"대상 지정 %s" % effect}
	var weapons: Array[int] = []
	for entry: Dictionary in profile.bonuses:
		if int(entry.link.MinSpellLevel) != 0 or int(entry.bonus.BonusApplicationTypeID) != 0: continue
		if str(entry.type.Name) == "WeaponType": weapons.append(int(entry.bonus.Value))
		elif str(entry.type.Name) == "WeaponGroup": weapons.append_array(weapon_group_types(int(entry.bonus.Value)))
	var native_class := int(bindings.class_ids.get(job, -1))
	var minimum := -1
	var required_card := 0
	for limit: Dictionary in profile.learn_limits:
		if int(limit.ClassID) != native_class or bool(limit.IsTutorialSpell): continue
		if int(limit.CharacterPolymorphGradeID) != 0: return {"reason":"학습 변신 등급 조건"}
		if int(limit.LimitBuffCardID) != 0: required_card = int(limit.LimitBuffCardID)
		minimum = int(limit.CharacterMinLevel)
	if minimum < 0: return {"reason":"이 직업의 SpellLearnLimit 행 없음"}
	if targeting == 1 and radius > 0.0 and effect == "self_buff": return {"reason":"범위 자기 버프(파티 대상)"}
	return {"spell_id":int(row.ID),"child":child,"weapons":weapons,"minimum_level":minimum,"mp":int(row.MPCost),"hp":int(row.HPCost),"items":items,
		"radius":radius * 48.0,"targets":int(row.TargetLimitCount) if int(row.TargetLimitCount) > 0 else 8,
		"cooldown":maxf(0.0,float(row.CastDelay))/1000.0,"range":maxf(64.0,float(row.CastRange)*32.0) if not bool(row.get("IsAttackRange",false)) else 240.0,
		"pvp_only_to_npc":int(row.TargetKindID) == 52,"required_card":required_card}

func _open_approx_active(record: Dictionary, spec: Dictionary) -> void:
	var child: Dictionary = spec.child
	var effect := str(child.effect)
	var parts := PackedStringArray()
	var cursor: Dictionary = child
	while not cursor.is_empty():
		match str(cursor.get("effect","")):
			"damage": parts.append("피해 %d+%dd%d" % [int(cursor.base),int(cursor.number),int(cursor.sides)])
			"debuff": parts.append("대상 약화 %s (%.0f~%.0f초)" % [str(cursor.modifiers.keys()),float(cursor.duration[0]),float(cursor.duration[1])])
			"self_buff": parts.append("자기 강화 %s (%.0f초)" % [str(cursor.stats.keys()),float(cursor.duration)])
			"heal_pct": parts.append("HP %.0f%% 회복" % float(cursor.percent))
			"cleanse": parts.append("상태 이상 해제")
			"dash": parts.append("대상에게 이동")
		cursor = cursor.get("next",{})
	var summary := "액티브 · 원본 523 수치 + TWILIGHT 근사 · " + " → ".join(parts)
	if bool(spec.pvp_only_to_npc): summary += " · 원본 PC 전용 대상 → 몬스터에 적용(사용자 결정 2026-11-16)"
	var runtime: Dictionary = {"runtime_blocked":false,"activation":"active","mp":int(spec.mp),"hp":int(spec.hp),"items":spec.get("items",{}).duplicate(),"cooldown":float(spec.cooldown),
		"minimum_level":int(spec.minimum_level),"local_kind":"source_approx523_active","desc":summary,"range":float(spec.range)}
	if effect == "self_buff":
		runtime.merge({"mode":"buff","stats":child.stats.duplicate(true),"duration":float(child.duration),"shape":"self"})
	elif effect in ["heal_pct","cleanse"] and float(spec.get("radius",0.0)) <= 0.0:
		runtime.merge({"mode":"buff","stats":{},"duration":0.1,"shape":"self","approx_self_child":child.duplicate(true)})
	else:
		var shape := "single"
		if float(spec.get("radius",0.0)) > 0.0: shape = "self_circle" if int(SOURCE_ROWS.row("SpellClass", int(spec.spell_id)).get("TargettingTypeID",2)) == 1 else "target_circle"
		runtime.merge({"mode":"attack","shape":shape,"targets":1 if shape == "single" else int(spec.get("targets",8)),"radius":float(spec.get("radius",0.0)),
			"attack_type":str(child.get("attack_type","magic")),"power":int(child.get("base",0)),"approx_child":child.duplicate(true)})
	if not spec.weapons.is_empty():
		var names: Array = []
		for weapon: int in spec.weapons:
			var local := str(SOURCE_ROWS.row("WeaponType", weapon).get("Name",""))
			if not local.is_empty(): names.append(local)
		runtime["approx_weapon_types"] = spec.weapons.duplicate()
	record.merge(runtime, true)
	record["source_approx523_active"] = spec
	if int(spec.get("required_card",0)) != 0: record["approx_required_card"] = int(spec.required_card)
	record["source_direct523"] = {"kind":"active_approx","spell_id":int(spec.spell_id),"basis":"원본 523 SpellClass·Buff 값 + data/skills/source_approx523.json 해석(TWILIGHT 근사)"}
	record.erase("source_direct523_hold")

## TWILIGHT 근사 (지시 2026-11-16, 장비 EquipSpellClassID): ItemBonus `EquipSpellClassID`
## (적용 유형 1 = SpellClass, 값 1) gives the target SpellClass while the item is worn.
## The spell is opened with the active approximation (원본 MP/HP·CastDelay·반경, 효과는
## approx_child_spell) as a skill record "eqspell523_<SpellClass ID>" any class may use
## while one of its items is equipped (skill_catalog.owned). docs/items523_remaining_missing_rules.md 10.2.
const APPROX_EQUIP_SPELLS := true
var equip_spell_items: Dictionary = {}

func equipment_spell_records(jobs: Array) -> Array:
	equip_spell_items = {}
	var out: Array = []
	if not APPROX_EQUIP_SPELLS or SOURCE_ROWS.identity().is_empty(): return out
	var type_id := -1
	for row: Dictionary in SOURCE_ROWS.rows("BonusType"):
		if str(row.get("Name","")) == "EquipSpellClassID": type_id = int(row.ID)
	if type_id < 0: return out
	var bonuses: Dictionary = {}
	var source_bonuses: Array[Dictionary] = SOURCE_ROWS.rows_matching("Bonus", "BonusTypeID", {type_id:true}) if SOURCE_ROWS.integer_field("Bonus", "BonusTypeID") else SOURCE_ROWS.rows("Bonus")
	for row: Dictionary in source_bonuses:
		if int(row.get("BonusTypeID",-1)) == type_id and int(row.get("BonusApplicationTypeID",0)) == 1 and _source_integer(row.get("Value")) and int(row.Value) == 1:
			bonuses[int(row.ID)] = int(row.BonusApplicationTargetID)
	if bonuses.is_empty(): return out
	var links: Array[Dictionary] = SOURCE_ROWS.rows_matching("ItemBonus", "BonusID", bonuses) if SOURCE_ROWS.integer_field("ItemBonus", "BonusID") else SOURCE_ROWS.rows("ItemBonus")
	for row: Dictionary in links:
		if row.get("IsPossession") == true or not bonuses.has(int(row.get("BonusID",-1))): continue
		var item: Dictionary = SOURCE_ROWS.row("ItemClass", int(row.ItemClassID))
		if item.is_empty() or item.get("TestItem") != false: continue
		var spell_id: int = int(bonuses[int(row.BonusID)])
		if not equip_spell_items.has(spell_id): equip_spell_items[spell_id] = {}
		equip_spell_items[spell_id][int(row.ItemClassID)] = true
	var ids: Array = equip_spell_items.keys(); ids.sort()
	for spell_id: int in ids:
		var spell: Dictionary = SOURCE_ROWS.row("SpellClass", spell_id)
		if spell.is_empty() or spell.get("TestSpell") != false: continue
		var child := approx_child_spell(spell_id, 2)
		if child.has("reason"): continue
		var targeting := int(spell.get("TargettingTypeID",2))
		var effect := str(child.get("effect",""))
		if targeting == 2 and effect in ["heal_pct","cleanse","self_buff"] and not APPROX_EXTRA_EFFECTS: continue
		var title := str(spell.get("Name",""))
		while title.begins_with("["): title = title.substr(title.find("]") + 1).strip_edges()
		var record: Dictionary = {"id":"eqspell523_%d" % spell_id, "name":title + " (장비)", "class":"장비", "classes":jobs.duplicate(), "stage":1, "trigger":"always",
			"equipment_spell523":spell_id, "equipment_spell_items":(equip_spell_items[spell_id] as Dictionary).keys()}
		var spec: Dictionary = {"spell_id":spell_id,"child":child,"weapons":[],"minimum_level":0,"mp":int(spell.get("MPCost",0)),"hp":int(spell.get("HPCost",0)),"items":{},
			"radius":float(spell.get("TargetAreaRadius",0)) * 48.0,"targets":int(spell.TargetLimitCount) if int(spell.get("TargetLimitCount",0)) > 0 else 8,
			"cooldown":maxf(0.0,float(spell.get("CastDelay",0)))/1000.0,"range":maxf(64.0,float(spell.get("CastRange",0))*32.0),"pvp_only_to_npc":false}
		_open_approx_active(record, spec)
		record["local_kind"] = "source_approx523_equip_spell"
		record["desc"] = "장비 착용 중 사용 · " + str(record.get("desc",""))
		out.append(record)
	return out

func configure_arguments() -> void:
	var path := ""
	var expected := ""
	var explicit_input := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--player-skills523-pack="):
			explicit_input = true; path = arg.get_slice("=", 1)
		elif arg.begins_with("--player-skills523-sha256="):
			explicit_input = true; expected = arg.get_slice("=", 1)
	if not explicit_input:
		_load_source_profiles()
		return
	if not load_pack(path, expected): push_warning("Player skills523 pack rejected: " + last_error)

static func _source_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _canonical_numbers(value: Variant) -> Variant:
	# JSON parsing represents source integers as floats. Normalize only exact
	# integers for serialization; the retained source dictionaries stay untouched.
	if typeof(value)==TYPE_FLOAT and _source_integer(value): return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _canonical_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_canonical_numbers(entry))
		return result
	return value

static func _source_row_json(row: Dictionary, expected: String = "") -> String:
	var normalized: Variant = _canonical_numbers(row)
	for input: Dictionary in [normalized, row]:
		for full_precision: bool in [true, false]:
			var candidate := JSON.stringify(input, "", true, full_precision)
			if expected.is_empty() or candidate.sha256_text() == expected: return candidate
	return ""

static func _source_evidence(detail: Dictionary) -> Dictionary:
	var result: Dictionary = {"link":detail.get("link",{}),"bonus":detail.get("bonus",{}),"type":detail.get("type",{}),"unit":detail.get("unit",{})}
	return result if valid_bonus(result) else {}

func _source_profile(spell_id: int, expected_row_sha: String = "") -> Dictionary:
	var row: Dictionary = SOURCE_ROWS.row("SpellClass",spell_id)
	if row.is_empty(): return {"reason":"source_spell_unavailable"}
	if not preload("res://scripts/quests/source_dummy523.gd").evidence("SpellClass",row).is_empty(): return {"reason":"source_explicit_dummy_declaration"}
	if row.get("TestSpell") is not bool or row.TestSpell: return {"reason":"source_TestSpell_not_false"}
	var row_json: String = _source_row_json(row,expected_row_sha)
	if row_json.is_empty(): return {"reason":"canonical_source_row_sha_mismatch"}
	var detail: Dictionary = SOURCE_SPELLS.describe(spell_id)
	if detail.get("excluded")==true: return {"reason":"source_TestSpell_true"}
	var bonuses: Array = []
	var buff_ids: Array[int] = []
	for entry: Dictionary in detail.get("bonuses",[]):
		var evidence: Dictionary = _source_evidence(entry)
		if evidence.is_empty(): return {"reason":"incomplete_spell_bonus"}
		bonuses.append(evidence)
		# Match the existing compiler's two declared buff edges exactly.
		if str(evidence.type.Name) in ["BuffClassID","SideEffectBuffClassID"]:
			if not _source_integer(evidence.bonus.Value) or int(evidence.bonus.Value)<0: return {"reason":"invalid_buff_reference"}
			var buff_id: int = int(evidence.bonus.Value)
			if buff_id not in buff_ids: buff_ids.append(buff_id)
	buff_ids.sort()
	var buffs: Array = []
	for buff_id: int in buff_ids:
		var buff: Dictionary = SOURCE_BUFFS.describe(buff_id)
		if buff.get("buff_class",{}).is_empty() or buff.get("excluded")==true: return {"reason":"source_buff_unavailable_or_excluded"}
		var buff_bonuses: Array = []
		for entry: Dictionary in buff.get("bonuses",[]):
			var evidence: Dictionary = _source_evidence(entry)
			if evidence.is_empty(): return {"reason":"incomplete_buff_bonus"}
			buff_bonuses.append(evidence)
		buffs.append({"row":buff.buff_class,"bonuses":buff_bonuses})
	return {"profile":{"row":row,"row_json":row_json,
		"learn_limits":SOURCE_ROWS.related("SpellLearnLimit","SpellClassID",spell_id),
		"bonuses":bonuses,"buffs":buffs,
		"costs":SOURCE_ROWS.related("SpellCost","SpellClassID",spell_id),
		"cast_groups":SOURCE_ROWS.related("SpellChangeCastGroup","SpellClassID",spell_id),
		"target_kind":detail.get("references",{}).get("TargetKindID",{}).get("row",{}),
		"targeting_type":detail.get("references",{}).get("TargettingTypeID",{}).get("row",{})}}

func _source_execution_graph(profile: Dictionary) -> Dictionary:
	var root_id: int = int(profile.row.ID)
	if not REVIEWED_EXECUTION_GRAPHS.has(root_id): return {"reason":"execution_graph_not_in_reviewed_compiler"}
	var nodes: Array = []
	for child_id: int in REVIEWED_EXECUTION_GRAPHS[root_id]:
		var built: Dictionary = _source_profile(child_id)
		var node: Dictionary = built.get("profile",{})
		if node.is_empty(): return {"reason":"execution_graph_child:"+str(child_id)+":"+str(built.get("reason","unavailable"))}
		nodes.append(node)
	var option_ids: Array[int] = []
	var sources: Array = [profile]
	sources.append_array(nodes)
	for node: Dictionary in sources:
		var entries: Array = node.bonuses.duplicate()
		for buff: Dictionary in node.buffs: entries.append_array(buff.bonuses)
		# The compiler collects all declared InvokeOption/application10 rows,
		# including conditional rows; it does not execute or flatten conditions.
		for entry: Dictionary in entries:
			if str(entry.type.Name)!="InvokeOption" or entry.bonus.BonusApplicationTypeID!=10: continue
			var target: Variant = entry.bonus.BonusApplicationTargetID
			if not _source_integer(target): return {"reason":"invalid_execution_invoke_reference"}
			if int(target) not in option_ids: option_ids.append(int(target))
	option_ids.sort()
	var invokes: Array = []
	for option_id: int in option_ids:
		var option: Dictionary = SOURCE_ROWS.row("InvokeOption",option_id)
		if option.is_empty(): return {"reason":"execution_invoke_unavailable:"+str(option_id)}
		if not _source_integer(option.get("InvokeOptionTypeID")): return {"reason":"invalid_execution_invoke_type:"+str(option_id)}
		var type: Dictionary = SOURCE_ROWS.row("InvokeOptionType",int(option.InvokeOptionTypeID))
		if type.is_empty(): return {"reason":"execution_invoke_type_unavailable:"+str(option_id)}
		invokes.append({"row":option,"type":type})
	return {"graph":{"root_id":root_id,"spells":nodes,"invokes":invokes}}

## Per-material proof. A malformed public bridge invalidates the whole binding
## file; an original item that is missing, marked TestItem=true or lacks the
## ItemBonus type-89 identity holds only that material (and the skills that
## spend it). Nothing is substituted for a held material.
func source_material_holds(local: Dictionary) -> Dictionary:
	var holds: Dictionary = {}
	if not local.get("material_inventory_keys") is Dictionary: return {"invalid":true,"holds":holds}
	for material: String in local.material_inventory_keys:
		var bridge: Variant = local.material_inventory_keys[material]
		if not bridge is Dictionary or not _source_integer(bridge.get("native_item_id")) or int(bridge.native_item_id)<1 or not bridge.get("inventory_key") is String: return {"invalid":true,"holds":{}}
		var held: Dictionary = {"native_item_id":int(bridge.native_item_id),"inventory_key":str(bridge.inventory_key)}
		var item: Dictionary = SOURCE_ROWS.row("ItemClass",int(bridge.native_item_id))
		if item.is_empty(): held["reason"] = "source_item_unavailable"; holds[material] = held; continue
		if item.get("TestItem") is not bool or item.TestItem:
			held["reason"] = "source_TestItem_true" if item.get("TestItem")==true else "source_TestItem_not_bool"
			holds[material] = held; continue
		var found := false
		for link: Dictionary in SOURCE_ROWS.related("ItemBonus","ItemClassID",int(item.ID)):
			var detail: Dictionary = SOURCE_BONUSES.describe(int(link.get("BonusID",-1)))
			var bonus: Dictionary = detail.get("bonus",{})
			# Same native material identity proof as build_player_skills523.py.
			if bonus.get("BonusTypeID")==89 and _source_integer(bonus.get("Value")) and str(int(bonus.Value))==material: found = true
		if not found: held["reason"] = "source_material_identity_unproven"; holds[material] = held
	return {"invalid":false,"holds":holds}

## Strict all-materials proof (kept for callers that require every bridge).
func _source_materials(local: Dictionary) -> bool:
	var checked: Dictionary = source_material_holds(local)
	return not checked.invalid and checked.holds.is_empty()

## True when the bridge(s) for this inventory key are proven in the original.
func material_ready(local: Dictionary, inventory_key: String) -> bool:
	var checked: Dictionary = source_material_holds(local)
	if checked.invalid: return false
	var matched := false
	for material: String in local.material_inventory_keys:
		if str(local.material_inventory_keys[material].inventory_key)!=inventory_key: continue
		matched = true
		if checked.holds.has(material): return false
	return matched

## Material type IDs a profile can spend: SpellClass, SpellCost rows, recovery
## components, reviewed execution-graph spells and their InvokeOption rows.
static func profile_material_types(profile: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var nodes: Array = [profile]
	nodes.append_array(profile.get("components",[]))
	nodes.append_array(profile.get("execution_graph",{}).get("spells",[]))
	var pairs: Array = []
	for node: Dictionary in nodes:
		var row: Dictionary = node.get("row",{})
		pairs.append([row.get("SpellMaterialTypeID",0),row.get("SpellMaterialItemAmount",0)])
		for cost: Dictionary in node.get("costs",[]):
			for index: int in range(1,4): pairs.append([cost.get("SpellMaterialTypeID"+str(index),0),cost.get("SpellMaterialItemAmount"+str(index),0)])
	for invoke: Dictionary in profile.get("execution_graph",{}).get("invokes",[]):
		pairs.append([invoke.get("row",{}).get("MaterialTypeID",0),invoke.get("row",{}).get("MaterialAmount",0)])
	for pair: Array in pairs:
		if not _source_integer(pair[0]) or not _source_integer(pair[1]) or int(pair[0])<=0 or int(pair[1])<=0: continue
		var key := str(int(pair[0]))
		if key not in result: result.append(key)
	return result

func _load_source_profiles() -> void:
	# Re-entry never replaces a supported compiled or already installed snapshot.
	if not profiles.is_empty(): return
	var identity: Dictionary = SOURCE_ROWS.identity()
	if identity.is_empty():
		source_fallback_status = {"state":"unavailable","reason":SOURCE_ROWS.problem()}
		return
	var binding_bytes := FileAccess.get_file_as_bytes(BINDINGS_PATH)
	var local: Variant = JSON.parse_string(binding_bytes.get_string_from_utf8())
	if not local is Dictionary or local.get("schema_version")!=1 or local.get("patch")!=523 or local.get("source_zip_sha256")!=SOURCE_SHA or not local.get("skills") is Dictionary or not local.get("material_inventory_keys") is Dictionary:
		source_fallback_status = {"state":"deferred","reason":"unsupported_public_bindings"}
		return
	var original := SOURCE_ROWS.verified_key()
	var code := BAKE.global_code_key()
	var key := BAKE.key([PROFILE_BAKE, original, code, BAKE.engine_key(), str(SOURCE_ROWS.approximate_test_items)]) if not (original.is_empty() or code.is_empty()) else ""
	var stored: Variant = BAKE.read(PROFILE_BAKE, key) if not key.is_empty() else null
	if stored is Dictionary and stored.get("identity") == identity and stored.get("profiles") is Dictionary and not stored.profiles.is_empty() and stored.get("metadata") is Dictionary and stored.get("status") is Dictionary and stored.status.get("state") == "loaded" and stored.status.get("applied") == stored.profiles.keys() and stored.status.get("material_holds") is Dictionary:
		_adopt_original_profiles(stored, local)
		return
	var material_check: Dictionary = source_material_holds(local)
	if material_check.invalid:
		source_fallback_status = {"state":"deferred","reason":"native_material_binding_unconfirmed"}
		return
	var held_materials: Dictionary = material_check.holds
	var candidate: Dictionary = {}
	var deferred: Dictionary = {}
	for id: String in local.skills:
		var binding: Dictionary = local.skills[id]
		if not _source_integer(binding.get("spell_id")) or not binding.get("row_sha256") is String:
			deferred[id] = "invalid_public_binding"; continue
		var spell_id: int = int(binding.spell_id)
		var built: Dictionary = _source_profile(spell_id,str(binding.row_sha256))
		var profile: Dictionary = built.get("profile",{})
		if profile.is_empty(): deferred[id] = built.get("reason","source_profile_unavailable"); continue
		if profile.learn_limits.is_empty() or not profile.learn_limits.any(func(limit: Dictionary) -> bool: return limit.get("IsTutorialSpell") == false):
			deferred[id] = "missing_ordinary_source_learn_limit"; continue
		if spell_id in SOURCE_RECOVERY_ROOTS:
			var components: Array = []
			var seen: Dictionary = {}
			for child: Variant in scalar_values(profile,"SpellClassID","SpellClassID"):
				if not _source_integer(child) or int(child)<1:
					deferred[id] = "invalid_recovery_component"; break
				if seen.has(int(child)): continue
				seen[int(child)] = true
				var component: Dictionary = _source_profile(int(child)).get("profile",{})
				if component.is_empty(): deferred[id] = "recovery_component_unavailable"; break
				components.append(component)
			if deferred.has(id): continue
			profile["components"] = components
		if REVIEWED_EXECUTION_GRAPHS.has(spell_id):
			var graph: Dictionary = _source_execution_graph(profile)
			if not graph.has("graph"):
				deferred[id] = graph.get("reason","reviewed_execution_graph_unavailable"); continue
			profile["execution_graph"] = graph.graph
		var issue: String = _profile_problem(id,profile,binding)
		if not issue.is_empty(): deferred[id] = issue; continue
		var spends_held: Array[String] = []
		for material: String in profile_material_types(profile):
			if held_materials.has(material): spends_held.append(material)
		if not spends_held.is_empty(): deferred[id] = "held_source_material:"+",".join(spends_held); continue
		candidate[id] = profile
	source_fallback_status = {"state":"loaded" if not candidate.is_empty() else "deferred","applied":candidate.keys(),"deferred":deferred,"material_holds":held_materials.duplicate(true)}
	if candidate.is_empty(): return
	var metadata: Dictionary = {"classes":SOURCE_ROWS.rows("Class"),"ui_units":SOURCE_ROWS.rows("UIUnit"),
		"buff_groups":SOURCE_ROWS.rows("BuffGroup"),"bonus_application_types":SOURCE_ROWS.rows("BonusApplicationType"),
		"special_resistance_types":SOURCE_ROWS.rows("SpecialResistanceType")}
	var built := {"identity":identity, "profiles":candidate, "metadata":metadata, "status":source_fallback_status}
	if not key.is_empty(): BAKE.write(PROFILE_BAKE, key, built)
	_adopt_original_profiles(built, local)

func _adopt_original_profiles(snapshot: Dictionary, local: Dictionary) -> void:
	source_fallback_status = snapshot.status
	material_holds = snapshot.status.material_holds.duplicate(true)
	profiles = snapshot.profiles.duplicate(true)
	bindings = local.duplicate(true)
	recovery_rules.configure_pack(snapshot.metadata)
	# active_sha256 remains the compiled-pack fingerprint, never the archive SHA.
	source_mode = "original_bound_profiles"
	source_identity = snapshot.identity.duplicate(true)
	revision += 1
	last_error = ""
	# Optional PR269 reader only after this original-profile snapshot is adopted.
	# Its callback status never replaces the active profile/compiled-pack identity.
	relic_source_input_status = RELIC_SOURCE_INPUT.adopt(source_identity)

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
	# This pin has always covered decoded text. Reuse that exact UTF-8
	# string for parsing rather than reopening the bundled bindings file.
	var binding_text: String = FileAccess.get_file_as_string(BINDINGS_PATH)
	if pack.get("bindings_sha256") != binding_text.sha256_text():
		return reject("binding revision mismatch")
	var local: Variant = JSON.parse_string(binding_text)
	if not local is Dictionary or not pack.get("profiles") is Dictionary: return reject("missing bindings/profiles")
	var candidate: Dictionary = pack.profiles
	if candidate.size() != local.skills.size(): return reject("incomplete profile set")
	for id: String in local.skills:
		var issue: String = _profile_problem(id,candidate.get(id),local.skills[id])
		if not issue.is_empty(): return reject(issue)
	for key: String in ["ui_units","buff_groups","bonus_application_types","special_resistance_types"]:
		if pack.has(key):
			if not pack[key] is Array:return reject("invalid recovery metadata")
			for row: Variant in pack[key]:
				if not row is Dictionary:return reject("invalid recovery metadata row")
	profiles = candidate.duplicate(true)
	bindings = local.duplicate(true)
	recovery_rules.configure_pack(pack)
	active_sha256 = expected_sha256
	source_mode = "compiled_pack"
	source_identity = {"source_snapshot":"patch523","source_sha256":SOURCE_SHA}
	source_fallback_status = {}
	material_holds = {}
	revision += 1
	last_error = ""
	return true

func _profile_problem(id: String, profile: Variant, binding: Dictionary) -> String:
	# Both input paths retain the original compiled profile validation contract.
	if not profile is Dictionary: return "missing profile " + id
	if not profile.get("row_json") is String or str(profile.row_json).sha256_text() != str(binding.row_sha256):
		return "unreviewed source row " + id
	var row: Variant = JSON.parse_string(profile.row_json)
	if not row is Dictionary or row != profile.get("row") or int(row.get("ID", -1)) != int(binding.spell_id):
		return "source identity mismatch " + id
	for key: String in ["learn_limits", "bonuses", "buffs", "costs", "cast_groups"]:
		if not profile.get(key) is Array: return "invalid " + key
	for entry: Variant in profile.bonuses:
		if not valid_bonus(entry): return "invalid spell bonus"
	for buff: Variant in profile.buffs:
		if not buff is Dictionary or not buff.get("row") is Dictionary or not buff.get("bonuses") is Array: return "invalid buff"
		for entry: Variant in buff.bonuses:
			if not valid_bonus(entry): return "invalid buff bonus"
	if profile.has("components"):
		if not profile.components is Array: return "invalid components"
		var child_ids: Dictionary = {}
		for child: Variant in scalar_values(profile,"SpellClassID","SpellClassID"): child_ids[int(child)] = true
		var seen: Dictionary = {}
		if child_ids.size()!=profile.components.size(): return "incomplete component graph"
		for component: Variant in profile.components:
			if not valid_component(component): return "invalid component profile"
			var child_id: int = int(component.row.ID)
			if not child_ids.has(child_id) or seen.has(child_id): return "unexpected component identity"
			seen[child_id] = true
	if profile.has("execution_graph") and not valid_execution(id,profile): return "invalid reviewed execution graph"
	if not profile.get("target_kind") is Dictionary or int(profile.target_kind.get("ID", -1)) != int(row.TargetKindID):
		return "target kind mismatch"
	if not profile.get("targeting_type") is Dictionary or int(profile.targeting_type.get("ID", -1)) != int(row.TargettingTypeID):
		return "targeting type mismatch"
	return ""

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

## The reviewed progression adapter can turn a base record into a stats passive.
## Treat every reviewed rule as a candidate until its validated profile is resolved.
func may_project_static_stats(id: String) -> bool:
	return profiles.has(id) and progression_rules.rules.has(id)

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
	if not pending_note.is_empty() and recovery.is_empty() and not bool(record.get("reference_approx523", false)):
		record.source523["pending_note"] = pending_note
	if not recovery.is_empty():record.source523["recovery"]=recovery.meta.duplicate(true)
	if not progression.is_empty():record.source523["progression"]=progression.meta.duplicate(true)
	if not estimate.is_empty():
		record.source523["estimated"] = record.estimated523.duplicate(true)
		record.source523["distance_policy"] = "TWILIGHT_ESTIMATE"
		record.source523["time_policy"] = "TWILIGHT_ESTIMATE"
	# Passive/effect/upgrade execution and learning/ownership stay with the host.
	# Current-reference/local-design rows gain evidence only. A client row never
	# grants a book or activates a previously blocked/new spell implementation.
	# Original SpellMove rows: the plan is attached as evidence for every bound
	# spell. It only executes for a record that is otherwise castable.
	var spell_move: Dictionary = SPELL_MOVE.plan(int(row.ID))
	if not spell_move.is_empty():
		record.source523["spell_move"] = spell_move.duplicate(true)
		record["spell_move523"] = spell_move
	if bool(record.get("reference_approx523", false)):
		record.source523["distance_policy"] = "TWILIGHT_ESTIMATE"
		record.source523["time_policy"] = "TWILIGHT_ESTIMATE"
		if record.has("reference_native_material"): record.source523.applied.append("materials")
		if int(row.TargetKindID) == 52 and PVP_TARGET_TO_NPC:
			record.source523["original_target_kind"] = str(record.source523.target_kind)
			record.source523["target_kind"] = "AllButMe"
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
	# 사용자 결정 2026-11-16 13:46 + TWILIGHT 근사: PC 전용 대상(TargetKind 52)은 몬스터에게 적용.
	var pvp_to_npc: bool = target_kind == 52 and PVP_TARGET_TO_NPC
	if pvp_to_npc:
		record.source523["target_kind"] = "AllButMe"
		record.source523["original_target_kind"] = str(profile.target_kind.Name)
		record.source523["pvp_only_to_npc"] = true
	if target_kind==52 and not pvp_to_npc:reason="523 원본은 다른 플레이어 대상 · 상대 PC가 없는 현재 PvE에 확대하지 않음"
	elif targeting not in [1,2] or (target_kind not in [1,2,3,7,10,11,422] and not self_branch_allowed and not pvp_to_npc): reason = "523 대상 유형은 현재 PvE 연결 미지원"
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
		if material_holds.has(material):
			record["source523_block_reason"] = "523 원본 재료 보류: %s(원본#%d)" % [str(bridge.inventory_key),int(bridge.native_item_id)]
			return record
		items[str(bridge.inventory_key)] = int(items.get(str(bridge.inventory_key), 0)) + int(cost.amount)
	record["items"] = items
	record.source523.applied = ["hp", "mp", "materials", "target_filter"]
	if not estimate.is_empty(): record.source523.applied.append("estimated_effect")
	if not recovery.is_empty():record.source523.applied.append("self_recovery")
	if not progression.is_empty():record.source523.applied.append("reviewed_execution")
	# User decision 2026-11-12: SpellClass.CastDelay is the skill's own reuse
	# delay in milliseconds. The existing cooldown factor (skillCooldownPct from
	# SpellCastDelayDecreasePercent, cast speed) still multiplies it at cast time.
	var delay: Variant = row.get("CastDelay")
	if _source_integer(delay) and float(delay) >= 0.0:
		record.source523["host_cooldown_before"] = record.get("cooldown")
		record["cooldown"] = float(delay) / 1000.0
		record.source523["time_policy"] = "SOURCE523_CASTDELAY_MS"
		record.source523.applied.append("cooldown")
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
	record = _apply_numeric_distance_input(record,profile)
	return _apply_original_element_input(record,profile)

func _apply_original_element_input(record: Dictionary, profile: Dictionary) -> Dictionary:
	# The existing NPC hit adapter already uses this exact ElementalType.Name
	# vocabulary. Supply only a direct original attack's existing element input;
	# composition/child element precedence remains with its execution owner.
	if str(record.get("activation",""))!="active" or str(record.get("mode",""))!="attack" or bool(record.get("runtime_blocked",false)) or not str(record.get("source523_block_reason","")).is_empty(): return record
	if not record.get("source523",{}).get("applied",[]).has("target_filter"): return record
	var row: Dictionary = profile.get("row",{})
	var binding: Dictionary = bindings.get("skills",{}).get(str(record.get("id","")),{})
	if binding.is_empty() or not _source_integer(row.get("ID")) or row.ID!=binding.get("spell_id") or not _source_integer(row.get("SpellCompositionNode")) or int(row.SpellCompositionNode)!=0: return record
	var bound_sha: Variant = binding.get("row_sha256")
	if not bound_sha is String or bound_sha.length()!=64 or _source_row_json(row,bound_sha).is_empty(): return record
	var identity: Dictionary = SOURCE_ROWS.identity()
	if identity.is_empty() or identity.get("source_sha256")!=SOURCE_SHA: return record
	var original: Dictionary = SOURCE_ROWS.row("SpellClass",int(row.ID))
	if original.is_empty() or original!=row or original.get("TestSpell") is not bool or original.TestSpell or not SOURCE_ROWS.declared_exclusion("SpellClass",original).is_empty(): return record
	var element_id: Variant = row.get("ElementalTypeID")
	if not _source_integer(element_id) or int(element_id)<0: return record
	var definitions: Array[Dictionary] = SOURCE_ROWS.related("ElementalType","ID",int(element_id))
	if definitions.size()!=1 or not SOURCE_ROWS.declared_exclusion("ElementalType",definitions[0]).is_empty(): return record
	var element: Dictionary = definitions[0]
	if not SOURCE_ELEMENT_CHANNELS.has(element.get("Name")): return record
	var selected: String = SOURCE_ELEMENT_CHANNELS[element.Name]
	var prior: Variant = record.get("element")
	record["element"] = selected
	record.source523.applied.append("element")
	record.source523["element_input"] = {"source":identity,"spell_id":row.ID,"bound_row_sha256":bound_sha,
		"source_field":"SpellClass.ElementalTypeID","elemental_type":element,
		"prior_host_element":prior,"host_element_input":selected,
		"mapping":"existing_World.resolve_patch523_npc_hit_channel_names",
		"scope":"direct_existing_attack_only_no_composition_child_precedence"}
	return record

func _apply_numeric_distance_input(record: Dictionary, profile: Dictionary) -> Dictionary:
	# Only the successful active apply_to path calls this helper. It cannot
	# admit a reference-only/new/blocked spell or alter a shape/target contract.
	if str(record.get("activation",""))!="active" or bool(record.get("runtime_blocked",false)) or not str(record.get("source523_block_reason","")).is_empty(): return record
	if str(record.get("mode","")) not in ["attack","status","turn_undead"] or not record.get("source523",{}).get("applied",[]).has("target_filter"): return record
	var row: Dictionary = profile.get("row",{})
	var binding: Dictionary = bindings.get("skills",{}).get(str(record.get("id","")),{})
	if binding.is_empty() or not _source_integer(row.get("ID")) or row.ID!=binding.get("spell_id"): return record
	var bound_sha: Variant = binding.get("row_sha256")
	if not bound_sha is String or bound_sha.length()!=64 or _source_row_json(row,bound_sha).is_empty(): return record
	var identity: Dictionary = SOURCE_ROWS.identity()
	if identity.is_empty() or identity.get("source_sha256")!=SOURCE_SHA: return record
	var original: Dictionary = SOURCE_ROWS.row("SpellClass",int(row.ID))
	if original.is_empty() or original!=row or not SOURCE_ROWS.declared_exclusion("SpellClass",original).is_empty(): return record
	if original.get("TestSpell") is bool and original.TestSpell: return record
	# The host has no minimum-distance or original weapon-relative range
	# receiver. Do not turn a numeric scale into those missing context rules.
	if original.get("IsAttackRange") is not bool or original.IsAttackRange or not _source_integer(original.get("MinCastRange")) or int(original.MinCastRange)!=0: return record
	var file := FileAccess.open(DISTANCE_INPUT_POLICY_PATH,FileAccess.READ)
	if file==null: return record
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary: return record
	var policy: Dictionary = parser.data
	if policy.get("schema")!="twilight.current523.distance-input-policy.v1" or policy.get("source_snapshot")!="patch523" or policy.get("source_sha256")!=SOURCE_SHA: return record
	if not policy.get("enabled") is bool or not policy.enabled or policy.get("origin")!="twilight_adjustable_numeric_estimate": return record
	if policy.get("source_raw_distance_unit_scale")!="unconfirmed" or policy.get("native_grid_scale_recovered")!=false or policy.get("host_geometry")!="existing_host_distance_engine_retained": return record
	var scales: Dictionary = {}
	for field: String in ["cast_range_to_host_length","area_radius_to_host_length"]:
		var scale: Variant = policy.get(field)
		if typeof(scale) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(scale)) or float(scale)<=0.0: return record
		scales[field] = float(scale)
	# Validate both original scalars and stage all selected values before
	# replacing any host input. Zero/negative sentinels never become geometry.
	for field: String in ["CastRange","TargetAreaRadius"]:
		var value: Variant = row.get(field)
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0.0: return record
	var targeting: int = int(row.TargettingTypeID)
	var shape: String = str(record.get("shape",""))
	var projected: Dictionary = {}
	var provenance: Dictionary = {}
	if targeting==2 and shape in ["single","circle","target_circle"] and float(row.CastRange)>0.0:
		var length: float = float(row.CastRange)*scales.cast_range_to_host_length
		if not is_finite(length) or length<=0.0: return record
		projected["range"] = length
		provenance["range"] = {"source_field":"CastRange","raw_value":row.CastRange,"multiplier":scales.cast_range_to_host_length,"prior_host_value":record.get("range"),"host_length_input":length}
	var matching_area: bool = (targeting==1 and shape=="self_circle") or (targeting==2 and shape in ["circle","target_circle"])
	if matching_area and float(row.TargetAreaRadius)>0.0:
		var length: float = float(row.TargetAreaRadius)*scales.area_radius_to_host_length
		if not is_finite(length) or length<=0.0: return record
		projected["radius"] = length
		provenance["radius"] = {"source_field":"TargetAreaRadius","raw_value":row.TargetAreaRadius,"multiplier":scales.area_radius_to_host_length,"prior_host_value":record.get("radius"),"host_length_input":length}
	if projected.is_empty(): return record
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var policy_sha: String = hashing.finish().hex_encode()
	for field: String in projected:
		record[field] = projected[field]
		record.source523.applied.append(field)
	record.source523["distance_policy"] = "TWILIGHT_NUMERIC_INPUT_ESTIMATE"
	record.source523["distance_numeric_input"] = {"origin":"twilight_adjustable_numeric_estimate",
		"policy_path":DISTANCE_INPUT_POLICY_PATH,"policy_schema":policy.schema,"policy_sha256":policy_sha,
		"source":identity,"spell_id":row.ID,"bound_row_sha256":bound_sha,"source_raw_distance_unit_scale":"unconfirmed",
		"native_grid_scale_recovered":false,"host_geometry":"existing_host_distance_engine_retained","fields":provenance,
		"min_cast_range_status":"raw_only_no_existing_recipient"}
	return record

static func target_allowed(skill: Dictionary, target: TwilightMonster) -> bool:
	if is_instance_valid(target) and target.concealed523: return false
	if bool(skill.get("reference_approx523", false)):
		# The public PvE profile defines which casts require a live hostile
		# target. Bound source evidence keeps the original ID and target label.
		# Preserve the explicit undead-only classification.
		return is_instance_valid(target) and not target.dead and (str(skill.get("source523", {}).get("target_kind", "")) != "Undead" or target.is_undead())
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
	var local_key: String = preload("res://scripts/skills/reference_profiles523.gd").local_item_name(skill,item)
	var result: Array = [local_key]
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
