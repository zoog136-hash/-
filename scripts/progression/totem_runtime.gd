extends RefCounted
class_name TwilightTotemRuntime

# Existing file packs and the already held original archive share this parser.
# Neither input synthesizes odds or writes an installation/save.
const ORIGINAL_INPUT = preload("res://scripts/progression/current523_totem_input.gd")
const CORE_COUNTS = {"Totem":3,"TotemLevel":33,"TotemMaterial":60,"TotemBonus":94,"TotemResonance":4,"TotemResetCost":2,"TotemConstant":8}
var tables: Dictionary = {}
var state: Dictionary = {}
var pack_sha: String = ""
var last_error: String = ""
var save_blocked: bool = false
var revision: int = 0
var map_contexts: Dictionary = {}
var source_mode: String = ""
var source_identity: Dictionary = {}
var source_status: Dictionary = {}
var source_recipe_references: Array = []
const LOCAL_POLICY = "twilight_totem_v1"

func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

func configure_input() -> bool:
	# An explicit setting, including an empty value, retains file-loader failure
	# priority. Partial existing packs are not bypassed with another input.
	if OS.has_environment("TWILIGHT_TOTEM_PACK"):
		return install(OS.get_environment("TWILIGHT_TOTEM_PACK"))
	var root := "user://original_resources/totems523"
	for name: String in ["manifest.json","totem_data.json"]:
		var path := root.path_join(name)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path): return install(root)
	if available(): return true
	return load_original()

func load_original() -> bool:
	var input = ORIGINAL_INPUT.new()
	var body: Dictionary = input.build()
	if body.is_empty():
		last_error = input.problem
		source_status = {"attempt":"current523_original","problem":last_error,"deferred":input.deferred.duplicate(true)}
		return false
	var counts: Dictionary = {}
	for table: String in body.tables: counts[table] = body.tables[table].size()
	# This fingerprint identifies the actual in-memory parser payload. The ZIP
	# identity is a separate field and is never substituted for a model/file SHA.
	var payload_sha: String = JSON.stringify(body,"",true,true).sha256_text()
	if not _accept_input(body,counts,payload_sha): return false
	source_mode = "current523_original"
	source_identity = input.source_identity.duplicate(true)
	source_recipe_references = input.recipe_references.duplicate(true)
	source_status = {"mode":source_mode,"problem":"","deferred":input.deferred.duplicate(true),
		"recipe_execution":"selection_and_condition_owner_pending","text":"source_text_not_loaded"}
	return true

func install(root: String) -> bool:
	var manifest: Variant = _json(root.path_join("manifest.json"))
	var body_path := root.path_join("totem_data.json")
	if not manifest is Dictionary or int(manifest.get("schema",0)) != 1 or int(manifest.get("source_version",0)) != 523 or not manifest.get("table_counts") is Dictionary:
		last_error = "523 토템 팩 manifest가 없습니다"
		return false
	if not FileAccess.file_exists(body_path) or FileAccess.get_sha256(body_path) != str(manifest.get("sha256","")):
		last_error = "토템 팩 SHA 불일치"
		return false
	var body: Variant = _json(body_path)
	if not _accept_input(body,manifest.table_counts,str(manifest.sha256)): return false
	source_mode = "file_pack"
	source_identity = {}
	source_recipe_references = []
	source_status = {"mode":source_mode,"problem":""}
	return true

func _accept_input(body: Variant, table_counts: Dictionary, payload_sha: String) -> bool:
	if not body is Dictionary or int(body.get("schema",0)) != 1 or int(body.get("source_version",0)) != 523 or not body.get("tables") is Dictionary:
		last_error = "토템 팩 형식 오류"
		return false
	var candidate: Dictionary = body.tables
	var contexts: Variant = body.get("map_contexts",{})
	if not contexts is Dictionary:
		last_error = "토템 지역 연결 형식 오류"
		return false
	for key: Variant in contexts:
		if not key is String or not contexts[key] is Array:
			last_error = "토템 지역 연결 형식 오류"
			return false
		for land: Variant in contexts[key]:
			if not land is Dictionary or not _integer(land.get("ID"),0,2147483647) or not land.get("AssetPath") is String:
				last_error = "토템 Land 연결 형식 오류"
				return false
	for table: String in CORE_COUNTS:
		if not candidate.get(table) is Array or candidate[table].size() != CORE_COUNTS[table]:
			last_error = "토템 핵심 표 누락: " + table
			return false
	for table: String in candidate:
		if not candidate[table] is Array or candidate[table].size() != int(table_counts.get(table,-1)):
			last_error = "토템 표 개수 불일치"
			return false
		for value: Variant in candidate[table]:
			if not value is Dictionary:
				last_error = "토템 행 형식 오류"
				return false
	var required := {
		"Totem":["ID","NpcGroupID","ActivationKillCount","DescID","MapBuffClassID"],
		"TotemLevel":["ID","TotemID","Level","Probability"],
		"TotemMaterial":["ID","TotemLevelID","ItemClassID","Amount","SlotIndex"],
		"TotemBonus":["ID","TotemLevelID","BonusID","SlotIndex","Probability"],
		"TotemResonance":["ID","TotalLevel","BonusID"],
		"Bonus":["ID","BonusTypeID","Value"],"BonusType":["ID","UnitID","DescID"],
		"UIUnit":["ID","UnitID","Denominator"],
		"NpcClassForNpcGroup":["NpcGroupID","NpcClassID"],
		"TotemResetCost":["ID","CurrencyID","Amount"],
		"CurrencyUnitClass":["CurrencyID","UnitID","ClassID"],
		"ItemClass":["ID","DescID"],
		"BuffBonus":["BuffClassID","BonusID"],"SpellBonus":["SpellClassID","BonusID"],
		"InvokeOption":["ID","InvokeOptionTypeID","Param1","Param2"],
		"SpellClass":["ID","CastDelay"],
		"ItemCraftView":["ItemCraftID","ItemClassID","Amount"],
		"ItemCraftInput":["ItemCraftID","ItemClassID","Amount","SlotIndex"],
		"ItemCraftOutputView":["ItemCraftID","ItemClassID","Amount"]}
	for table: String in required:
		if not candidate.get(table) is Array:
			last_error = "토템 연결 표 누락"
			return false
		for value: Dictionary in candidate[table]:
			for key: String in required[table]:
				if not _integer(value.get(key),-2147483647,2147483647):
					last_error = "토템 숫자 필드 오류"
					return false
	var old_tables := tables
	tables = candidate
	if not _valid_definition() or not check_state(export_state()).is_empty():
		tables = old_tables
		last_error = "토템 정의 또는 기존 진행도와 호환되지 않습니다"
		return false
	pack_sha = payload_sha
	map_contexts = contexts.duplicate(true)
	last_error = ""
	return true

func recipe_definition(craft_id: int) -> Dictionary:
	# Read-only handoff for the transaction/condition owner. These original
	# definitions have not been admitted to the existing Totem craft executor.
	var definitions: Array = []
	for reference: Dictionary in source_recipe_references:
		if reference.get("view",{}).get("ItemCraftID")==craft_id: definitions.append(reference.duplicate(true))
	return {"reference_only":true,"can_execute":false,"definitions":definitions,
		"blocker":"totem_recipe_selection_and_condition_owner_pending"}

func available() -> bool:
	return not tables.is_empty()

func rows(table: String) -> Array:
	return tables.get(table,[])

func source_constant(name: String) -> Variant:
	# UNVERIFIED: use the installed 523 cache without substituting host values or
	# changing source units. Missing or ambiguous names have no usable value.
	var result: Variant = null
	for value: Dictionary in rows("TotemConstant"):
		if value.get("Name") != name: continue
		if result != null or not _integer(value.get("Value"),-2147483647,2147483647): return null
		result = int(value.Value)
	return result

func row(table: String, id: int) -> Dictionary:
	for value: Dictionary in rows(table):
		if int(value.get("ID",-1)) == id: return value.duplicate(true)
	return {}

func _valid_definition() -> bool:
	var ids: Array = []
	for totem: Dictionary in rows("Totem"):
		var id := int(totem.ID)
		if ids.has(id) or int(totem.ActivationKillCount) <= 0: return false
		ids.append(id)
		for level in range(11):
			var found := 0
			for stage: Dictionary in rows("TotemLevel"):
				if int(stage.TotemID) == id and int(stage.Level) == level: found += 1
			if found != 1: return false
	var pools: Dictionary = {}
	for bonus: Dictionary in rows("TotemBonus"):
		if row("TotemLevel",int(bonus.TotemLevelID)).is_empty() or row("Bonus",int(bonus.BonusID)).is_empty() or int(bonus.Probability) < 0: return false
		var key := "%d:%d" % [int(bonus.TotemLevelID),int(bonus.SlotIndex)]
		pools[key] = int(pools.get(key,0)) + int(bonus.Probability)
	if pools.size() != 52: return false
	for sum_value: int in pools.values():
		if sum_value != 1000000: return false
	for def: Dictionary in rows("TotemLevel"):
		if not ids.has(int(def.TotemID)) or int(def.Level) < 0 or int(def.Level) > 10: return false
	for material: Dictionary in rows("TotemMaterial"):
		if row("TotemLevel",int(material.TotemLevelID)).is_empty() or row("ItemClass",int(material.ItemClassID)).is_empty() or int(material.Amount) <= 0: return false
	return true

func progress(id: int) -> Dictionary:
	return state.get(str(id),{"active":false,"kills":0,"level":0,"selected":{}}).duplicate(true)

func export_state() -> Dictionary:
	return {"version":2,"policy":LOCAL_POLICY,"revision":revision,"totems":state.duplicate(true)}

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

func check_state(value: Variant) -> String:
	if value == null: return ""
	if not value is Dictionary or not value.get("totems") is Dictionary:
		return "토템 저장 형식 오류"
	if value.get("version") == 1:
		if value.size() != 2: return "토템 저장 형식 오류"
	elif value.get("version") == 2:
		if value.size() != 4 or value.get("policy") != LOCAL_POLICY or not _integer(value.get("revision"),0,2147483647): return "토템 로컬 규칙·저장 버전 오류"
	else: return "지원하지 않는 토템 저장 버전"
	for id: Variant in value.totems:
		if not id is String or not str(id).is_valid_int(): return "토템 저장 ID 오류"
		var p: Variant = value.totems[id]
		if not p is Dictionary or p.size() != 4 or not p.get("active") is bool or not _integer(p.get("kills"),0,2147483647) or not _integer(p.get("level"),0,10) or not p.get("selected") is Dictionary:
			return "토템 진행도 오류"
		if not p.active and (int(p.level) != 0 or not p.selected.is_empty()): return "미활성 토템 성장 오류"
		if available():
			var def := row("Totem",int(id))
			if def.is_empty(): return "알 수 없는 토템"
			if (int(p.kills) >= int(def.ActivationKillCount)) != bool(p.active): return "토템 활성화 상태 불일치"
		for level_key: Variant in p.selected:
			if not level_key is String or not str(level_key).is_valid_int() or int(level_key) < 1 or int(level_key) > int(p.level): return "토템 옵션 단계 오류"
			if not p.selected[level_key] is Dictionary: return "토템 옵션 슬롯 오류"
			for slot: Variant in p.selected[level_key]:
				if not slot is String or not _integer(p.selected[level_key][slot],1,2147483647): return "토템 옵션 ID 오류"
				if available() and not _candidate_exists(int(id),int(level_key),str(slot),int(p.selected[level_key][slot])): return "토템 옵션 후보 불일치"
	return ""

func accept_state(value: Variant) -> bool:
	var error := check_state(value)
	if not error.is_empty():
		save_blocked = true
		last_error = error
		return false
	state = {} if value == null else value.totems.duplicate(true)
	revision = 0 if value == null else int(value.get("revision",0))
	save_blocked = false
	return true

func record_kill(npc_class_id: int) -> bool:
	if not available() or save_blocked: return false
	var changed := false
	for totem: Dictionary in rows("Totem"):
		var matches := false
		for member: Dictionary in rows("NpcClassForNpcGroup"):
			if int(member.NpcGroupID) == int(totem.NpcGroupID) and int(member.NpcClassID) == npc_class_id: matches = true
		if not matches: continue
		var p := progress(int(totem.ID))
		if bool(p.active): continue
		p.kills = mini(int(totem.ActivationKillCount),int(p.kills)+1)
		p.active = int(p.kills) >= int(totem.ActivationKillCount)
		state[str(int(totem.ID))] = p
		changed = true
	if changed: revision += 1
	return changed

func level_definition(id: int, level: int) -> Dictionary:
	for def: Dictionary in rows("TotemLevel"):
		if int(def.TotemID) == id and int(def.Level) == level: return def.duplicate(true)
	return {}

func level_preview(id: int, level: int) -> Dictionary:
	var def := level_definition(id,level)
	if def.is_empty(): return {}
	var materials: Array = []
	var pools: Dictionary = {}
	for material: Dictionary in rows("TotemMaterial"):
		if int(material.TotemLevelID) == int(def.ID): materials.append(material.duplicate(true))
	for candidate: Dictionary in rows("TotemBonus"):
		if int(candidate.TotemLevelID) != int(def.ID): continue
		var slot := str(int(candidate.SlotIndex))
		if not pools.has(slot): pools[slot] = []
		# Value zero remains a real candidate. These weights are never success odds.
		pools[slot].append({"source":candidate.duplicate(true),"bonus":typed_bonus(int(candidate.BonusID))})
	return {"level":def,"materials":materials,"option_pools":pools,"upgrade_available":true,"success_fraction":float(def.Probability)/1000000.0,"policy":LOCAL_POLICY}

func _candidate_exists(id: int, level: int, slot: String, bonus_id: int) -> bool:
	for candidate: Dictionary in level_preview(id,level).get("option_pools",{}).get(slot,[]):
		if int(candidate.source.BonusID) == bonus_id: return true
	return false

func typed_bonus(id: int) -> Dictionary:
	var bonus := row("Bonus",id)
	var type := row("BonusType",int(bonus.get("BonusTypeID",0)))
	var ui: Dictionary = {}
	for unit: Dictionary in rows("UIUnit"):
		if int(unit.UnitID) == int(type.get("UnitID",-1)): ui = unit.duplicate(true)
	return {"bonus":bonus,"type":type,"ui_unit":ui}

func description(id: int) -> String:
	return str(row("DescData_Korean",id).get("Description",""))

func item_name(id: int) -> String:
	return description(int(row("ItemClass",id).get("DescID",0)))

func selected_bonuses() -> Array:
	var result: Array = []
	for def: Dictionary in rows("Totem"):
		var p := progress(int(def.ID))
		if not bool(p.active): continue
		for stage: Dictionary in p.selected.values():
			for id: Variant in stage.values(): result.append(typed_bonus(int(id)))
	return result

func bonus(type_name: String) -> int:
	var value := 0
	for effect: Dictionary in selected_bonuses():
		if effect.type.get("Name") == type_name and int(effect.bonus.get("BonusApplicationTypeID",0)) == 0: value += int(effect.bonus.Value)
	return value

func stat_record() -> Dictionary:
	var result := {"mr":bonus("MagicResist"),"damage_reduction":bonus("DamageReduction"),"xp":float(bonus("ExperienceAdditionPercent"))/1000000.0}
	return {} if result.mr == 0 and result.damage_reduction == 0 and result.xp == 0 else result

func map_experience_fraction(land_id: int, asset_path: String) -> float:
	var amount := 0.0
	for def: Dictionary in rows("Totem"):
		if not bool(progress(int(def.ID)).active): continue
		for land: Dictionary in map_contexts.get(str(int(def.ID)),[]):
			if int(land.ID) != land_id or str(land.AssetPath) != asset_path: continue
			for link: Dictionary in rows("BuffBonus"):
				if int(link.BuffClassID) != int(def.MapBuffClassID): continue
				var b := typed_bonus(int(link.BonusID))
				if b.type.get("Name") == "ExperienceAdditionPercent": amount = maxf(amount,float(b.bonus.Value)/1000000.0)
	return amount

func resonance() -> Dictionary:
	var total := 0
	for totem: Dictionary in rows("Totem"):
		var p := progress(int(totem.ID))
		if bool(p.active): total += int(p.level)
	var reached: Array = []
	var raw := 0
	for threshold: Dictionary in rows("TotemResonance"):
		if total < int(threshold.TotalLevel): continue
		var bonus := typed_bonus(int(threshold.BonusID))
		if str(bonus.type.get("Name","")) != "PierceDamageReductionPercent": continue
		raw += int(bonus.bonus.Value)
		reached.append(threshold.duplicate(true))
	return {"total_level":total,"reached":reached,"pierce_reduction_raw":raw,"pierce_reduction_fraction":float(raw)/1000000.0}

func recipes() -> Array:
	var result: Array = []
	for view: Dictionary in rows("ItemCraftView"):
		var recipe := {"view":view.duplicate(true),"inputs":[],"outputs":[]}
		for input: Dictionary in rows("ItemCraftInput"):
			if int(input.ItemCraftID) == int(view.ItemCraftID): recipe.inputs.append(input.duplicate(true))
		for output: Dictionary in rows("ItemCraftOutputView"):
			if int(output.ItemCraftID) == int(view.ItemCraftID): recipe.outputs.append(output.duplicate(true))
		result.append(recipe)
	return result

func snapshot() -> Dictionary:
	var totems: Array = []
	for def: Dictionary in rows("Totem"):
		var value := progress(int(def.ID))
		value["id"] = int(def.ID)
		value["definition"] = def.duplicate(true)
		value["next_level"] = level_preview(int(def.ID),mini(10,int(value.level)+1))
		totems.append(value)
	return {"available":available(),"error":last_error,"totems":totems,"resonance":resonance(),"recipes":recipes(),"pack_sha":pack_sha}
