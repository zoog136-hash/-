extends RefCounted

const Common = preload("res://scripts/equipment523/common.gd")
const ROOT: String = "user://equipment523"
const POINTER: String = ROOT + "/active.json"
const EFFECT_SCHEMA: String = "patch523-equipment-effects-v1"
const EFFECT_TABLES: Array[String] = ["Bonus","BonusType","Unit","BonusApplicationType","BuffClass","BuffBonus","BuffGroup","BuffStack","BuffStackBonus","InvokeOption","InvokeOptionType","SpellClass","SpellBonus","SpellCastGroup","SpellGroup","IntervalBonusCategory","IntervalBonus","SpecialResistanceType","ElementalType","StatusEffectAttr","StatusEffectGroupLink","UniversalGroupSet","AttackType","TargettingType","TargetKind","TargetKindNode","DescData_Korean"]
const ZERO_DEFINITIONS: Array[String] = ["Unit","BonusApplicationType","AttackType","ElementalType","TargetKind","InvokeOptionType","TargettingType","SpecialResistanceType"]
var pack: Dictionary = {}
var base_pack: Dictionary = {}
var effects_sha256: String = ""
var status: String = "세공·제련·연금 규칙 팩을 설치하세요."
var sha256: String = ""

func startup() -> Dictionary:
	var path: String = ""
	var digest: String = ""
	var effect_path: String = ""
	var effect_digest: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--equipment523-rules="): path = arg.trim_prefix("--equipment523-rules=")
		if arg.begins_with("--equipment523-sha256="): digest = arg.trim_prefix("--equipment523-sha256=")
		if arg.begins_with("--equipment523-effects="): effect_path = arg.trim_prefix("--equipment523-effects=")
		if arg.begins_with("--equipment523-effects-sha256="): effect_digest = arg.trim_prefix("--equipment523-effects-sha256=")
	if not path.is_empty():
		var loaded: Dictionary = load_verified(path, digest)
		if loaded.get("ok",false):
			if not effect_path.is_empty(): return load_effects_verified(effect_path,effect_digest)
			_load_installed_effects()
		return loaded
	if not FileAccess.file_exists(POINTER):
		return {"ok":false,"error":status}
	var pointer: Variant = JSON.parse_string(FileAccess.get_file_as_string(POINTER))
	if not pointer is Dictionary:
		return _error("규칙 팩 설치 기록을 읽을 수 없습니다. 저장 데이터는 보존됩니다.")
	var active_sha: String = str(pointer.get("sha256", ""))
	var loaded: Dictionary = load_verified(ROOT + "/" + active_sha + "/rules.json", active_sha)
	if loaded.get("ok",false): _load_installed_effects()
	return loaded

func load_verified(path: String, digest: String) -> Dictionary:
	if not _digest_valid(digest): return _error("팩 SHA256 64자리를 확인하세요.")
	if not FileAccess.file_exists(path): return _error("규칙 팩 파일을 찾지 못했습니다.")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 100000000: return _error("규칙 팩을 읽을 수 없거나 크기 제한을 넘었습니다.")
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var hash_context: HashingContext = HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	if hash_context.finish().hex_encode() != digest: return _error("규칙 팩 SHA256이 일치하지 않습니다.")
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary: return _error("규칙 팩 JSON이 손상되었습니다.")
	var validation: Dictionary = validate(value)
	if not bool(validation.get("ok",false)): return _error(str(validation.get("error","규칙 팩 오류")))
	pack = value
	base_pack = value.duplicate(true)
	effects_sha256 = ""
	sha256 = digest
	status = "523 규칙 팩 설치됨 · " + digest.left(12)
	return {"ok":true,"sha256":digest}

func install(path: String, digest: String) -> Dictionary:
	var candidate: Dictionary = _checked_json(path,digest)
	if not candidate.get("ok",false): return _error(str(candidate.get("error","규칙 팩 오류")))
	if candidate.value.get("schema") == EFFECT_SCHEMA: return install_effects(path,digest)
	var previous_pack: Dictionary = pack
	var previous_sha: String = sha256
	var previous_base: Dictionary = base_pack
	var previous_effects: String = effects_sha256
	var checked: Dictionary = load_verified(path,digest)
	if not bool(checked.get("ok",false)): return checked
	var folder: String = ROOT + "/" + digest
	var code: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if code != OK:
		pack = previous_pack
		sha256 = previous_sha
		base_pack = previous_base
		effects_sha256 = previous_effects
		return _error("규칙 팩 설치 폴더에 쓸 수 없습니다.")
	var destination: String = folder + "/rules.json"
	if ProjectSettings.globalize_path(path) != ProjectSettings.globalize_path(destination):
		code = DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(destination))
		if code != OK:
			pack = previous_pack
			sha256 = previous_sha
			base_pack = previous_base
			effects_sha256 = previous_effects
			return _error("규칙 팩 복사가 실패했습니다.")
	if FileAccess.get_sha256(destination) != digest:
		pack = previous_pack
		sha256 = previous_sha
		base_pack = previous_base
		effects_sha256 = previous_effects
		return _error("설치한 규칙 팩 검증이 실패했습니다.")
	var temporary: String = POINTER + ".tmp"
	var output: FileAccess = FileAccess.open(temporary,FileAccess.WRITE)
	if output == null:
		pack = previous_pack
		sha256 = previous_sha
		base_pack = previous_base
		effects_sha256 = previous_effects
		return _error("규칙 팩 설치 기록을 저장할 수 없습니다.")
	output.store_string(JSON.stringify({"schema":Common.SCHEMA,"sha256":digest}))
	output.flush()
	var written: Error = output.get_error()
	output.close()
	if written != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(POINTER)) != OK:
		pack = previous_pack
		sha256 = previous_sha
		base_pack = previous_base
		effects_sha256 = previous_effects
		return _error("규칙 팩 활성화 기록의 원자 저장이 실패했습니다.")
	status = "523 규칙 팩 설치됨 · " + digest.left(12)
	_load_installed_effects()
	return {"ok":true,"sha256":digest}

func load_effects_verified(path: String, digest: String) -> Dictionary:
	var checked: Dictionary = _checked_json(path,digest)
	if not checked.get("ok",false): return _error(str(checked.error))
	var merged: Dictionary = merge_effects(base_pack,sha256,checked.value)
	if not merged.get("ok",false): return _error(str(merged.error))
	pack = merged.pack
	effects_sha256 = digest
	status = "523 규칙 · 효과 보완 설치됨 · " + sha256.left(12) + " / " + digest.left(12)
	return {"ok":true,"sha256":sha256,"effects_sha256":digest}

func install_effects(path: String, digest: String) -> Dictionary:
	var checked: Dictionary = _checked_json(path,digest)
	if not checked.get("ok",false): return _error(str(checked.error))
	var merged: Dictionary = merge_effects(base_pack,sha256,checked.value)
	if not merged.get("ok",false): return _error(str(merged.error))
	var base_file: String = ROOT+"/"+sha256+"/rules.json"
	var active: Variant = JSON.parse_string(FileAccess.get_file_as_string(POINTER)) if FileAccess.file_exists(POINTER) else null
	if not active is Dictionary or active.get("sha256") != sha256 or not FileAccess.file_exists(base_file) or FileAccess.get_sha256(base_file) != sha256:
		return _error("현재 기본 규칙팩을 먼저 설치한 뒤 효과 보완팩을 설치하세요.")
	var directory: String = ROOT + "/" + sha256 + "/effects"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK: return _error("효과 보완 설치 폴더에 쓸 수 없습니다.")
	var destination: String = directory + "/" + digest + ".json"
	if ProjectSettings.globalize_path(path) != ProjectSettings.globalize_path(destination):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(destination)) != OK: return _error("효과 보완 파일 복사가 실패했습니다.")
	if FileAccess.get_sha256(destination) != digest: return _error("설치한 효과 보완 파일 SHA256이 일치하지 않습니다.")
	var pointer: String = ROOT + "/" + sha256 + "/effects-active.json"
	var output: FileAccess = FileAccess.open(pointer+".tmp",FileAccess.WRITE)
	if output == null: return _error("효과 보완 설치 기록을 저장할 수 없습니다.")
	output.store_string(JSON.stringify({"schema":EFFECT_SCHEMA,"base_sha256":sha256,"sha256":digest}))
	output.flush()
	var code: Error = output.get_error()
	output.close()
	if code != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(pointer+".tmp"),ProjectSettings.globalize_path(pointer)) != OK: return _error("효과 보완 활성화 기록의 원자 저장이 실패했습니다.")
	pack = merged.pack
	effects_sha256 = digest
	status = "523 규칙 · 효과 보완 설치됨 · " + sha256.left(12) + " / " + digest.left(12)
	return {"ok":true,"sha256":sha256,"effects_sha256":digest}

func _load_installed_effects() -> void:
	var pointer: String = ROOT + "/" + sha256 + "/effects-active.json"
	if not FileAccess.file_exists(pointer): return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(pointer))
	if not value is Dictionary or value.get("schema") != EFFECT_SCHEMA or value.get("base_sha256") != sha256 or not _digest_valid(str(value.get("sha256",""))):
		status += " · 효과 보완 설치 기록 오류"
		return
	load_effects_verified(ROOT+"/"+sha256+"/effects/"+str(value.sha256)+".json",str(value.sha256))

static func _checked_json(path: String, digest: String) -> Dictionary:
	if not _digest_valid(digest) or not FileAccess.file_exists(path): return {"ok":false,"error":"팩 파일과 SHA256 64자리를 확인하세요."}
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 100000000: return {"ok":false,"error":"팩을 읽을 수 없거나 크기 제한을 넘었습니다."}
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	if hash_context.finish().hex_encode() != digest: return {"ok":false,"error":"팩 SHA256이 일치하지 않습니다."}
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary: return {"ok":false,"error":"팩 JSON이 손상되었습니다."}
	return {"ok":true,"value":value}

static func merge_effects(base: Dictionary, base_sha: String, extension: Dictionary) -> Dictionary:
	if base.is_empty() or not _digest_valid(base_sha): return {"ok":false,"error":"기존 523 규칙 팩을 먼저 설치하세요."}
	if extension.get("schema") != EFFECT_SCHEMA or extension.get("source_sha256") != Common.SOURCE_SHA or extension.get("base_sha256") != base_sha:
		return {"ok":false,"error":"효과 보완의 원본·기존 팩 SHA256이 일치하지 않습니다."}
	if not extension.get("tables") is Dictionary or not extension.get("bonuses") is Dictionary or not extension.get("audit") is Dictionary: return {"ok":false,"error":"효과 보완 필수 정보가 없습니다."}
	var merged: Dictionary = base.duplicate(true)
	merged.erase("_indexes")
	for table: Variant in extension.tables:
		if table not in EFFECT_TABLES or not extension.tables[table] is Array: return {"ok":false,"error":"효과 보완 표 범위를 확인하세요: "+str(table)}
		var existing: Dictionary = {}
		for row: Dictionary in merged.tables.get(table,[]): existing[str(int(row.get("ID",0)))] = row
		var seen: Dictionary = {}
		for value: Variant in extension.tables[table]:
			if not value is Dictionary or not _row_id(value.get("ID"),str(table) in ZERO_DEFINITIONS): return {"ok":false,"error":"효과 보완 행 ID가 잘못되었습니다."}
			var key: String = str(int(value.ID))
			if seen.has(key): return {"ok":false,"error":"효과 보완 행 ID가 중복되었습니다."}
			seen[key] = true
			if existing.has(key):
				if not _same_source(existing[key],value): return {"ok":false,"error":"기존 원본 행을 덮어쓰는 효과 보완은 거부합니다."}
			else:
				if not merged.tables.has(table): merged.tables[table] = []
				merged.tables[table].append(value.duplicate(true))
	for key: Variant in extension.bonuses:
		var value: Variant = extension.bonuses[key]
		if not value is Dictionary or not value.get("raw") is Dictionary or not value.get("type") is Dictionary or str(int(value.raw.get("ID",0))) != str(key): return {"ok":false,"error":"효과 보완 Bonus namespace가 잘못되었습니다."}
		if merged.bonuses.has(key) and not _same_source(merged.bonuses[key],value): return {"ok":false,"error":"기존 원본 Bonus를 덮어쓰는 효과 보완은 거부합니다."}
		merged.bonuses[key] = value.duplicate(true)
	merged["equipment523_effect_audit"] = extension.audit.duplicate(true)
	return {"ok":true,"pack":merged}

static func _row_id(value: Variant, allow_zero: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floorf(float(value)) and value >= (0 if allow_zero else 1) and value <= 9007199254740991

static func _same_source(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_finite(float(a)) and is_finite(float(b)) and a == b
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same_source(a[key],b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not _same_source(a[index],b[index]): return false
		return true
	return a == b

static func validate(value: Dictionary) -> Dictionary:
	if value.get("schema") != Common.SCHEMA or value.get("source_sha256") != Common.SOURCE_SHA:
		return {"ok":false,"error":"검증된 523 원본 규칙 팩이 아닙니다."}
	for name: String in ["tables","bonuses","items","bindings","audit"]:
		if not value.get(name) is Dictionary: return {"ok":false,"error":"규칙 팩 필수 정보가 없습니다: " + name}
	var expected: Dictionary = {"ElementalSmith":114,"ElementalSmithProbability":456,"ElementalSmithBonus":98,"ItemBlessReinforcement":94,"ItemBlessReinforcementBonus":1980,"ItemSmelt":12,"ItemSmeltBonus":311,"ItemSpiritSmeltEntity":16,"AlchemyItem":1152,"AlchemyResult":7246,"ItemSet":47,"ItemForItemSet":219,"ItemSetBonus":228,"ItemInvokeReplacement":18,"ItemInvokeReplacementEntityView":330,"ItemInvokeReplacementBonus":974}
	for name: String in expected:
		if not value.tables.get(name) is Array or value.tables[name].size() != int(expected[name]):
			return {"ok":false,"error":"523 원본 표 범위가 일치하지 않습니다: " + name}
	return {"ok":true}

static func _digest_valid(value: String) -> bool:
	if value.length() != 64: return false
	for index: int in range(value.length()):
		if not value.substr(index,1) in "0123456789abcdef": return false
	return true

func _error(message: String) -> Dictionary:
	status = message
	return {"ok":false,"error":message}
