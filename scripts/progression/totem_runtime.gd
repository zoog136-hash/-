extends RefCounted
class_name TwilightTotemRuntime

# Original tables live in a separately installed private pack. No synthesized odds.
const CORE_COUNTS = {"Totem":3,"TotemLevel":33,"TotemMaterial":60,"TotemBonus":94,"TotemResonance":4,"TotemResetCost":2,"TotemConstant":8}
var tables: Dictionary = {}
var state: Dictionary = {}
var pack_sha: String = ""
var last_error: String = ""
var save_blocked: bool = false

func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

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
	if not body is Dictionary or int(body.get("schema",0)) != 1 or int(body.get("source_version",0)) != 523 or not body.get("tables") is Dictionary:
		last_error = "토템 팩 형식 오류"
		return false
	var candidate: Dictionary = body.tables
	for table: String in CORE_COUNTS:
		if not candidate.get(table) is Array or candidate[table].size() != CORE_COUNTS[table]:
			last_error = "토템 핵심 표 누락: " + table
			return false
	for table: String in candidate:
		if not candidate[table] is Array or candidate[table].size() != int(manifest.get("table_counts",{}).get(table,-1)):
			last_error = "토템 표 개수 불일치"
			return false
		for value: Variant in candidate[table]:
			if not value is Dictionary:
				last_error = "토템 행 형식 오류"
				return false
	var required := {
		"Totem":["ID","NpcGroupID","ActivationKillCount","DescID"],
		"TotemLevel":["ID","TotemID","Level","Probability"],
		"TotemMaterial":["ID","TotemLevelID","ItemClassID","Amount","SlotIndex"],
		"TotemBonus":["ID","TotemLevelID","BonusID","SlotIndex","Probability"],
		"TotemResonance":["ID","TotalLevel","BonusID"],
		"Bonus":["ID","BonusTypeID","Value"],"BonusType":["ID","UnitID","DescID"],
		"UIUnit":["ID","UnitID","Denominator"],
		"NpcClassForNpcGroup":["NpcGroupID","NpcClassID"],
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
	pack_sha = str(manifest.sha256)
	last_error = ""
	return true

func available() -> bool:
	return not tables.is_empty()

func rows(table: String) -> Array:
	return tables.get(table,[])

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
	return {"version":1,"totems":state.duplicate(true)}

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

func check_state(value: Variant) -> String:
	if value == null: return ""
	if not value is Dictionary or value.size() != 2 or value.get("version") != 1 or not value.get("totems") is Dictionary:
		return "토템 저장 형식 오류"
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
	return {"level":def,"materials":materials,"option_pools":pools,"upgrade_available":false,"reason":"강화 전이·재료 대체·확률 절차 확인 대기"}

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
