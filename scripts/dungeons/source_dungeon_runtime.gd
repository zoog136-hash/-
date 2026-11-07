extends RefCounted
## Client declarations are inspectable; missing server handlers never grant entry/rewards.
const SOURCE_SHA256 := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const PAYLOAD_SHA256 := "4edf50302106978f1779d885866889d646b992e329ccd53bf3dbb284dfc43f73"
const PAYLOAD_BYTES := 6050456
const DEFAULT_MANIFEST := "user://dungeon523/" + PAYLOAD_SHA256 + "/manifest.json"
const MAX_MANIFEST_BYTES := 4096
const ORIGINAL_PROJECTION = preload("res://scripts/dungeons/source_dungeon_projection.gd")
const ORIGINAL_ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const ORIGINAL_BUFFS = preload("res://scripts/resources/current523_buff_data.gd")
var data: Dictionary = {}
var last_error: String = ""
var tower_by_id: Dictionary = {}
var orim_by_id: Dictionary = {}
var special_by_id: Dictionary = {}
var time_by_id: Dictionary = {}
var time_by_land: Dictionary = {}
var recharge_by_item: Dictionary = {}
const EXECUTION_SHA := "f61176042e92c2ba77c50b987f3f4932acaf7cb38b341050155ba7d2510ccc6e"
const PREVIOUS_EXECUTION_SHA := "ad0fb91d91c8301c66f383e9d7a63aeca5b7260fed2319b733971b50e9f559d3"
var orim_actor_types: Dictionary = {}
var orim_groups: Dictionary = {}
var orim_item_effects: Dictionary = {}
var orim_actor_defs: Dictionary = {}
var execution_input_identity: Dictionary = {}
var orim_speed_input_provenance: Dictionary = {}
var _speed_input_identity: Dictionary = {}

func original_orim_speed_input(buff_id: int, stat: String) -> Dictionary:
	# Only the existing three preparation buffs and two actual speed operands.
	if buff_id not in [71672,71682,71692] or stat not in ["move_speed","attack_speed"]: return {}
	var identity: Dictionary = ORIGINAL_ROWS.identity()
	if identity.get("source_sha256")!=SOURCE_SHA256 or data.get("source_sha256")!=SOURCE_SHA256: return {}
	if identity!=_speed_input_identity:
		orim_speed_input_provenance.clear()
		_speed_input_identity = identity.duplicate(true)
	var key: String = str(buff_id)+":"+stat
	if orim_speed_input_provenance.has(key): return orim_speed_input_provenance[key].duplicate(true)
	var declarations: Array[Dictionary] = ORIGINAL_ROWS.related("OrimsTrailBuff","BuffClassID",buff_id)
	if declarations.size()!=1 or declarations[0] not in data.get("declarations",{}).get("OrimsTrailBuff",[]): return {}
	var graph: Dictionary = ORIGINAL_BUFFS.describe(buff_id)
	if graph.get("source")!=identity: return {}
	if graph.get("excluded",false) or not ORIGINAL_ROWS.declared_exclusion("BuffGroup",graph.get("group",{})).is_empty() or not ORIGINAL_ROWS.declared_exclusion("OrimsTrailBuff",declarations[0]).is_empty():
		return {"ok":true,"value":0.0,"excluded":true}
	if not graph.get("ok",false): return {}
	var name_value: String = "MoveSpeedBonus" if stat=="move_speed" else "AttackSpeedBonus"
	var matched: Array = []
	for effect: Dictionary in graph.get("bonuses",[]):
		if effect.get("type",{}).get("Name")==name_value: matched.append(effect)
	if matched.size()!=1: return {}
	var effect: Dictionary = matched[0]
	var link: Dictionary = effect.get("link",{}); var bonus: Dictionary = effect.get("bonus",{})
	if effect.get("unit",{}).get("Name")!="Percentage" or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0: return {}
	for field: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
		if link.get(field)!=0: return {}
	for pair: Array in [["BuffBonus",link],["Bonus",bonus],["BonusType",effect.get("type",{})],["Unit",effect.get("unit",{})]]:
		if not ORIGINAL_ROWS.declared_exclusion(pair[0],pair[1]).is_empty(): return {"ok":true,"value":0.0,"excluded":true}
	var raw: Variant = bonus.get("Value")
	if typeof(raw) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(raw)) or float(raw)<0.0: return {}
	# Existing Percentage conversion used by the skill/equipment projections:
	# 10,000 raw units per host percentage point, not a new status formula.
	var result: Dictionary = {"ok":true,"value":float(raw)/10000.0,"source":identity,
		"declaration":declarations[0],"buff_class_id":buff_id,"stat":stat,
		"link":link,"bonus":bonus,"type":effect.type,"unit":effect.unit,"raw_per_percent":10000}
	orim_speed_input_provenance[key] = result.duplicate(true)
	return result

func _original_execution_input() -> Dictionary:
	# Same selection as build_orim523_execution.py; no builder, file or new
	# execution policy. Retain complete source rows and their original order.
	var identity: Dictionary = ORIGINAL_ROWS.identity()
	if identity.get("source_sha256") != SOURCE_SHA256: return {}
	var tables: Dictionary = {}
	for name: String in ["OrimsTrailNpc","OrimsTrailNpcType","NpcClassForNpcGroup","ItemBonus","Bonus","BonusType","NpcClass","NpcAttack","DescData_Korean","OrimsTrailSpawn"]:
		var meta: Dictionary = ORIGINAL_ROWS.table_metadata(name)
		var rows: Array[Dictionary] = ORIGINAL_ROWS.rows(name)
		if meta.is_empty() or rows.size()!=int(meta.get("row_count",-1)): return {}
		tables[name] = rows
	var links: Array = []; var bonus_ids: Dictionary = {}
	for row: Dictionary in tables.ItemBonus:
		if row.ItemClassID in [231162,232352]: links.append(row); bonus_ids[int(row.BonusID)] = true
	tables.ItemBonus = links
	var bonuses: Array = []; var type_ids: Dictionary = {}
	for row: Dictionary in tables.Bonus:
		if bonus_ids.has(int(row.ID)): bonuses.append(row); type_ids[int(row.BonusTypeID)] = true
	tables.Bonus = bonuses
	var types: Array = []
	for row: Dictionary in tables.BonusType:
		if type_ids.has(int(row.ID)): types.append(row)
	tables.BonusType = types
	var groups: Dictionary = {}; var actors: Dictionary = {}
	for row: Dictionary in tables.OrimsTrailSpawn:
		if row.NpcGroupID: groups[int(row.NpcGroupID)] = true
	for row: Dictionary in tables.OrimsTrailNpc: actors[int(row.NpcClassID)] = true
	for row: Dictionary in tables.NpcClassForNpcGroup:
		if groups.has(int(row.NpcGroupID)): actors[int(row.NpcClassID)] = true
	var definitions: Array = []; var descriptions: Dictionary = {}
	for row: Dictionary in tables.NpcClass:
		if actors.has(int(row.ID)): definitions.append(row); descriptions[int(row.DescId)] = true
	tables.NpcClass = definitions
	var attacks: Array = []
	for row: Dictionary in tables.NpcAttack:
		if actors.has(int(row.NpcClassID)): attacks.append(row)
	tables.NpcAttack = attacks
	var texts: Array = []
	for row: Dictionary in tables.DescData_Korean:
		if descriptions.has(int(row.ID)): texts.append(row)
	tables.DescData_Korean = texts
	tables.erase("OrimsTrailSpawn")
	# Exclusions are never filtered to manufacture the historical model hash.
	# Hold this optional input instead of admitting dummy/test source records.
	for name: String in tables:
		for row: Dictionary in tables[name]:
			# The historical model retains all group rows for its fingerprint;
			# only groups explicitly referenced by Orim spawns can be consumed.
			if name=="NpcClassForNpcGroup" and not groups.has(int(row.NpcGroupID)): continue
			if not ORIGINAL_ROWS.declared_exclusion(name,row).is_empty() or row.get("TestNpc")==true: return {}
	for id: int in [231162,232352]:
		var item: Dictionary = ORIGINAL_ROWS.row("ItemClass",id)
		if item.is_empty() or item.get("TestItem")!=false or not ORIGINAL_ROWS.declared_exclusion("ItemClass",item).is_empty(): return {}
	var candidate: Dictionary = {"source_sha256":SOURCE_SHA256,"schema":1,"tables":tables}
	var bytes: PackedByteArray = ORIGINAL_PROJECTION.encoded(candidate)
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256)!=OK or hashing.update(bytes)!=OK: return {}
	var actual: String = hashing.finish().hex_encode()
	if actual not in [EXECUTION_SHA,PREVIOUS_EXECUTION_SHA]: return {}
	return {"data":candidate,"identity":{"kind":"held_original_in_memory","source":identity,"model_sha256":actual,"model_bytes":bytes.size()}}

func _load_execution(directory: String, allow_original: bool = false) -> void:
	var path := directory.path_join("orim_execution.json")
	var parsed: Variant
	var input_identity: Dictionary = {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:
		if FileAccess.get_open_error()!=ERR_FILE_NOT_FOUND or not allow_original: return
		if not orim_actor_types.is_empty() or not orim_groups.is_empty() or not orim_item_effects.is_empty() or not orim_actor_defs.is_empty(): return
		var original: Dictionary = _original_execution_input()
		if original.is_empty(): return
		parsed = original.data
		input_identity = original.identity
	else:
		file.close()
		var actual: String = FileAccess.get_sha256(path)
		if actual not in [EXECUTION_SHA,PREVIOUS_EXECUTION_SHA]: return
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		input_identity = {"kind":"installed_execution_sidecar","source_sha256":SOURCE_SHA256,"model_sha256":actual}
	if not parsed is Dictionary or parsed.get("source_sha256","") != SOURCE_SHA256: return
	orim_actor_types.clear(); orim_groups.clear();orim_item_effects.clear();orim_actor_defs.clear()
	execution_input_identity = input_identity
	var types: Dictionary = {}
	for row: Dictionary in parsed.tables.OrimsTrailNpcType: types[int(row.ID)] = str(row.Name)
	for row: Dictionary in parsed.tables.OrimsTrailNpc: orim_actor_types[int(row.NpcClassID)] = types[int(row.OrimsTrailNpcTypeID)]
	for row: Dictionary in parsed.tables.NpcClassForNpcGroup:
		var group := int(row.NpcGroupID)
		if not orim_groups.has(group): orim_groups[group] = []
		orim_groups[group].append(int(row.NpcClassID))
	var bonuses: Dictionary={};var names: Dictionary={}
	for row: Dictionary in parsed.tables.BonusType:names[int(row.ID)]=str(row.Name)
	for row: Dictionary in parsed.tables.Bonus:bonuses[int(row.ID)]=row
	for link: Dictionary in parsed.tables.ItemBonus:
		var item_id:=int(link.ItemClassID);var bonus: Dictionary=bonuses[int(link.BonusID)]
		if not orim_item_effects.has(item_id):orim_item_effects[item_id]=[]
		orim_item_effects[item_id].append({"type":names[int(bonus.BonusTypeID)],"row":bonus.duplicate(true)})
	var npc_names: Dictionary={}
	for row: Dictionary in parsed.tables.get("DescData_Korean",[]):npc_names[int(row.ID)]=str(row.Description)
	for row: Dictionary in parsed.tables.get("NpcClass",[]):orim_actor_defs[int(row.ID)]={"row":row.duplicate(true),"name":npc_names.get(int(row.DescId),str(row.Name)),"attacks":[]}
	for row: Dictionary in parsed.tables.get("NpcAttack",[]):
		if orim_actor_defs.has(int(row.NpcClassID)):orim_actor_defs[int(row.NpcClassID)].attacks.append(row.duplicate(true))

func _read_manifest(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_MANIFEST_BYTES:
		return {"ok":false,"reason":"던전 자료 안내 파일을 읽을 수 없습니다."}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok":false,"reason":"던전 자료 안내 파일이 올바르지 않습니다."}
	var manifest: Dictionary = parsed
	for key: String in ["schema","version","bytes"]:
		if not (manifest.get(key) is int or manifest.get(key) is float):
			return {"ok":false,"reason":"던전 자료 안내 파일의 형식이 다릅니다."}
	for key: String in ["source_sha256","payload","sha256"]:
		if not manifest.get(key) is String:
			return {"ok":false,"reason":"던전 자료 안내 파일의 형식이 다릅니다."}
	if int(manifest.get("schema",0)) != 1 or int(manifest.get("version",0)) != 523 \
		or str(manifest.get("source_sha256","")) != SOURCE_SHA256 \
		or str(manifest.get("payload","")) != "dungeons.json" \
		or str(manifest.get("sha256","")) != PAYLOAD_SHA256 \
		or int(manifest.get("bytes",0)) != PAYLOAD_BYTES:
		return {"ok":false,"reason":"지원하는 최신 523 던전 자료와 일치하지 않습니다."}
	var payload_path := path.get_base_dir().path_join("dungeons.json")
	var optional_execution := path.get_base_dir().path_join("orim_execution.json")
	if FileAccess.file_exists(optional_execution) and FileAccess.get_sha256(optional_execution) not in [EXECUTION_SHA,PREVIOUS_EXECUTION_SHA]:return {"ok":false,"reason":"오림 실행 부속 자료가 변경되었습니다. 기존 자료를 유지합니다."}
	file = FileAccess.open(payload_path,FileAccess.READ)
	if file == null or file.get_length() != PAYLOAD_BYTES or FileAccess.get_sha256(payload_path) != PAYLOAD_SHA256:
		return {"ok":false,"reason":"던전 자료가 누락되었거나 변경되었습니다."}
	var bytes := file.get_buffer(PAYLOAD_BYTES)
	parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok":false,"reason":"던전 자료를 해석할 수 없습니다."}
	var candidate: Dictionary = parsed
	if candidate.get("source_sha256","") != SOURCE_SHA256 or int(candidate.get("schema",0)) != 1:
		return {"ok":false,"reason":"던전 원본 식별이 다릅니다."}
	for pair: Array in [["tower",200],["orim",20],["special",22],["time_groups",176],["land_times",317],["rechargers",450]]:
		if not candidate.get(pair[0]) is Array or candidate[pair[0]].size() != int(pair[1]):
			return {"ok":false,"reason":"던전 자료의 구성 수가 다릅니다."}
	return {"ok":true,"data":candidate,"bytes":bytes,"manifest":manifest}

func load_configured() -> Dictionary:
	var path: String = OS.get_environment("TWILIGHT_DUNGEON523_PACK")
	var explicit: bool = not path.is_empty()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--dungeon523-pack="):
			path = argument.trim_prefix("--dungeon523-pack=")
			explicit = true
	# Preserve explicit selection failures and every existing/partial installed
	# input. Bootstrap is only for an absent compiled installation.
	if explicit: return load_pack(path)
	var directory: String = DEFAULT_MANIFEST.get_base_dir()
	if FileAccess.file_exists(DEFAULT_MANIFEST) or FileAccess.file_exists(directory.path_join("dungeons.json")) or FileAccess.file_exists(directory.path_join("orim_execution.json")):
		return load_pack(DEFAULT_MANIFEST)
	return _load_original_projection()

func _load_original_projection() -> Dictionary:
	# UNVERIFIED: never substitute the source archive hash for a model hash.
	# Only the actual canonical projection bytes matching the established pack
	# fingerprint may enter the existing runtime and its existing services.
	var projection = ORIGINAL_PROJECTION.new()
	var candidate: Dictionary = projection.build()
	if candidate.is_empty():
		last_error = projection.problem
		return {"ok":false,"reason":last_error}
	var bytes: PackedByteArray = ORIGINAL_PROJECTION.encoded(candidate)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	if bytes.size() != PAYLOAD_BYTES or hash.finish().hex_encode() != PAYLOAD_SHA256:
		last_error = "보유 원본의 던전 projection 바이트가 기존 팩 정체와 다릅니다 · 기존 자료 보존"
		return {"ok":false,"reason":last_error}
	_activate(candidate)
	# The same optional reader accepts the held original only on actual absence;
	# no sidecar is manufactured and its established model hash is still required.
	_load_execution(DEFAULT_MANIFEST.get_base_dir(),true)
	return {"ok":true,"tower":200,"orim":20,"special":22,"source":"existing_original_in_memory","payload_sha256":PAYLOAD_SHA256,"unverified":true}

func load_pack(path: String = DEFAULT_MANIFEST) -> Dictionary:
	var checked := _read_manifest(path)
	if not bool(checked.get("ok",false)):
		last_error = str(checked.reason)
		return {"ok":false,"reason":last_error}
	_activate(checked.data)
	_load_execution(path.get_base_dir())
	return {"ok":true,"tower":200,"orim":20,"special":22}

func install_pack(path: String) -> Dictionary:
	var checked := _read_manifest(path)
	if not bool(checked.get("ok",false)):
		last_error = str(checked.reason)
		return {"ok":false,"reason":last_error}
	# Content-addressed storage preserves any previously installed revision and saves.
	var directory := ProjectSettings.globalize_path(DEFAULT_MANIFEST.get_base_dir())
	if FileAccess.file_exists(DEFAULT_MANIFEST):
		var prior := _read_manifest(DEFAULT_MANIFEST)
		if not bool(prior.get("ok",false)):
			return {"ok":false,"reason":"기존 설치 자료가 손상되었습니다. 별도로 보존 후 복구해 주세요."}
	else:
		var staging := directory + ".pending-" + str(Time.get_ticks_usec())
		if DirAccess.make_dir_recursive_absolute(staging) != OK:
			return {"ok":false,"reason":"던전 자료를 보관할 수 없습니다."}
		var payload := FileAccess.open(staging.path_join("dungeons.json"),FileAccess.WRITE)
		if payload == null:
			DirAccess.remove_absolute(staging)
			return {"ok":false,"reason":"던전 자료를 저장할 수 없습니다."}
		payload.store_buffer(checked.bytes)
		payload.close()
		var manifest_file := FileAccess.open(staging.path_join("manifest.json"),FileAccess.WRITE)
		if manifest_file != null:
			manifest_file.store_string(JSON.stringify(checked.manifest))
			manifest_file.close()
		var installed := _read_manifest(staging.path_join("manifest.json"))
		if not bool(installed.get("ok",false)) or DirAccess.rename_absolute(staging,directory) != OK:
			DirAccess.remove_absolute(staging.path_join("dungeons.json"))
			DirAccess.remove_absolute(staging.path_join("manifest.json"))
			DirAccess.remove_absolute(staging)
			return {"ok":false,"reason":"던전 자료 설치를 완료하지 못했습니다."}
	var sidecar := path.get_base_dir().path_join("orim_execution.json")
	if FileAccess.file_exists(sidecar) and FileAccess.get_sha256(sidecar) in [EXECUTION_SHA,PREVIOUS_EXECUTION_SHA]:
		var target := directory.path_join("orim_execution.json")
		var old_sha := FileAccess.get_sha256(target) if FileAccess.file_exists(target) else ""
		if not old_sha.is_empty() and old_sha not in [EXECUTION_SHA,PREVIOUS_EXECUTION_SHA]: return {"ok":false,"reason":"기존 오림 실행 자료를 보존했습니다. 손상 자료를 별도 확인해 주세요."}
		if old_sha.is_empty() or (old_sha==PREVIOUS_EXECUTION_SHA and FileAccess.get_sha256(sidecar)==EXECUTION_SHA):
			if not old_sha.is_empty():
				var backup := target+".backup."+old_sha
				if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(target,backup)!=OK:return {"ok":false,"reason":"이전 오림 실행 자료 백업 실패"}
				if FileAccess.get_sha256(backup)!=old_sha:return {"ok":false,"reason":"이전 오림 실행 자료 백업 불일치"}
			var temp := target+".pending"
			var file := FileAccess.open(temp,FileAccess.WRITE)
			if file == null: return {"ok":false,"reason":"오림 실행 자료 저장 실패"}
			file.store_buffer(FileAccess.get_file_as_bytes(sidecar)); file.close()
			if DirAccess.rename_absolute(temp,target) != OK: return {"ok":false,"reason":"오림 실행 자료 활성화 실패"}
	_activate(checked.data)
	_load_execution(directory)
	return {"ok":true,"tower":200,"orim":20,"special":22}

func _activate(candidate: Dictionary) -> void:
	data = candidate
	tower_by_id.clear()
	orim_by_id.clear()
	special_by_id.clear()
	time_by_id.clear()
	time_by_land.clear()
	recharge_by_item.clear()
	for row: Dictionary in data.tower: tower_by_id[int(row.stage.ID)] = row
	for row: Dictionary in data.orim: orim_by_id[int(row.stage.ID)] = row
	for row: Dictionary in data.special: special_by_id[int(row.row.ID)] = row
	for row: Dictionary in data.time_groups: time_by_id[int(row.row.ID)] = row
	for row: Dictionary in data.land_times: time_by_land[int(row.LandID)] = int(row.LandTimeLimitGroupID)
	for row: Dictionary in data.rechargers: recharge_by_item[int(row.item.row.ID)] = row
	last_error = ""

func entries(kind: String, hard: bool = false) -> Array:
	var result: Array = []
	for entry: Dictionary in data.get(kind,[]):
		if kind in ["special","rechargers"] or bool(entry.stage.IsHard) == hard:
			result.append(entry.duplicate(true))
	return result

func stage(kind: String, identifier: int) -> Dictionary:
	var source: Dictionary = tower_by_id if kind == "tower" else orim_by_id if kind == "orim" else {}
	return (source.get(identifier,{}) as Dictionary).duplicate(true)

func context_for_land(land_id: int) -> Dictionary:
	# Land alone is not a difficulty or stage key (Orim shares maps across modes).
	var candidates: Array = []
	for kind: String in ["tower","orim"]:
		for row: Dictionary in data.get(kind,[]):
			if int(row.place.land.ID) == land_id:
				candidates.append({"kind":kind,"stage_id":int(row.stage.ID),"hard":bool(row.stage.IsHard)})
	var group_id := int(time_by_land.get(land_id,0))
	return {"land_id":land_id,"stage_candidates":candidates,"time_group":(time_by_id.get(group_id,{}) as Dictionary).duplicate(true)}

func waves(stage_id: int) -> Array:
	# Exact authored rows only. RelativeShape/Randomly/NpcGroup require their host handler.
	return (orim_by_id.get(stage_id,{}).get("spawns",[]) as Array).duplicate(true)

func reward_preview(kind: String, stage_id: int, immediate: bool = false) -> Array:
	var row := stage(kind,stage_id)
	if row.is_empty() or (kind == "orim" and immediate): return []
	return (row.get("immediate_rewards" if immediate else "normal_rewards",[]) as Array).duplicate(true)

func orim_sections(stage_id: int, remaining_seconds: float) -> Dictionary:
	if not is_finite(remaining_seconds) or remaining_seconds < 0.0:
		return {"ok":false,"reason":"invalid_remaining_time","candidates":[]}
	var candidates: Array = []
	var at_boundary := false
	for section: Dictionary in orim_by_id.get(stage_id,{}).get("sections",[]):
		var row: Dictionary = section.row
		if remaining_seconds >= float(row.MinRemainTimeSecond) and remaining_seconds <= float(row.MaxRemainTimeSecond):
			candidates.append(section.duplicate(true))
			at_boundary = at_boundary or remaining_seconds == float(row.MinRemainTimeSecond) or remaining_seconds == float(row.MaxRemainTimeSecond)
	return {"ok":not candidates.is_empty(),"candidates":candidates,"boundary_unresolved":at_boundary,"grantable":false}

func entry_check(kind: String, identifier: int, player_level: int) -> Dictionary:
	var entry: Dictionary = special_by_id.get(identifier,{}) if kind == "special" else stage(kind,identifier)
	if entry.is_empty(): return {"ok":false,"reasons":["던전 자료가 없습니다."]}
	var reasons: Array[String] = []
	var minimum := 0
	var maximum := 0
	if kind == "tower": minimum = int(entry.stage.MinLevel)
	elif kind == "orim":
		for attr: Dictionary in entry.place.attributes:
			if attr.type == "MinLevel": minimum = maxi(minimum,int(attr.row.Value))
	elif kind == "special":
		for requirement: Dictionary in entry.prerequisites:
			if requirement.type == "MinLevel": minimum = maxi(minimum,int(requirement.row.Value))
			if requirement.type == "MaxLevel": maximum = int(requirement.row.Value) if maximum == 0 else mini(maximum,int(requirement.row.Value))
	if player_level < minimum: reasons.append("%d레벨부터 입장할 수 있습니다." % minimum)
	if maximum > 0 and player_level > maximum: reasons.append("%d레벨까지만 입장할 수 있습니다." % maximum)
	if kind == "orim": reasons.append("현재 자료에서 오림의 흔적은 닫혀 있습니다.")
	# Static IsOpen is preserved for display, never mistaken for player progression.
	if kind == "special":
		var lands: Array[String] = []
		for target: Dictionary in entry.destinations:
			var land := str(int(target.place.land.ID))
			if not land in lands: lands.append(land)
		reasons.append("원본 Land %s의 착지·충돌·시간 풀 실행 연결이 필요합니다." % ", ".join(lands))
	else: reasons.append("입장·전투·보상 판정 연결 준비 중입니다.")
	return {"ok":false,"minimum_level":minimum,"maximum_level":maximum,"reasons":reasons}

func recharge_preview(item_id: int) -> Dictionary:
	var row: Dictionary = recharge_by_item.get(item_id,{})
	if row.is_empty(): return {}
	return {"item":row.item.duplicate(true),"group":time_by_id[int(row.group_id)].duplicate(true),
		"seconds":3600,"use_text":row.use_text,"usable":false,"reason":"충전 상한·리셋 처리 연결 준비 중입니다."}

func tower_entry_cost(hard: bool) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in data.get("declarations",{}).get("TrialTowerConstant",[]):
		if row.Name in ["BaseTryCurrencyID","BaseTryCurrencyCost","TryCurrencyID","TryCurrencyCost"]:
			result[row.Name] = int(row.HardValue if hard else row.Value)
	return result
