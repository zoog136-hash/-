extends RefCounted

const Common = preload("res://scripts/equipment523/common.gd")
const ROOT: String = "user://equipment523"
const POINTER: String = ROOT + "/active.json"
var pack: Dictionary = {}
var status: String = "세공·제련·연금 규칙 팩을 설치하세요."
var sha256: String = ""

func startup() -> Dictionary:
	var path: String = ""
	var digest: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--equipment523-rules="): path = arg.trim_prefix("--equipment523-rules=")
		if arg.begins_with("--equipment523-sha256="): digest = arg.trim_prefix("--equipment523-sha256=")
	if not path.is_empty():
		return load_verified(path, digest)
	if not FileAccess.file_exists(POINTER):
		return {"ok":false,"error":status}
	var pointer: Variant = JSON.parse_string(FileAccess.get_file_as_string(POINTER))
	if not pointer is Dictionary:
		return _error("규칙 팩 설치 기록을 읽을 수 없습니다. 저장 데이터는 보존됩니다.")
	var active_sha: String = str(pointer.get("sha256", ""))
	return load_verified(ROOT + "/" + active_sha + "/rules.json", active_sha)

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
	sha256 = digest
	status = "523 규칙 팩 설치됨 · " + digest.left(12)
	return {"ok":true,"sha256":digest}

func install(path: String, digest: String) -> Dictionary:
	var previous_pack: Dictionary = pack
	var previous_sha: String = sha256
	var checked: Dictionary = load_verified(path,digest)
	if not bool(checked.get("ok",false)): return checked
	var folder: String = ROOT + "/" + digest
	var code: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if code != OK:
		pack = previous_pack
		sha256 = previous_sha
		return _error("규칙 팩 설치 폴더에 쓸 수 없습니다.")
	var destination: String = folder + "/rules.json"
	if ProjectSettings.globalize_path(path) != ProjectSettings.globalize_path(destination):
		code = DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(destination))
		if code != OK:
			pack = previous_pack
			sha256 = previous_sha
			return _error("규칙 팩 복사가 실패했습니다.")
	if FileAccess.get_sha256(destination) != digest:
		pack = previous_pack
		sha256 = previous_sha
		return _error("설치한 규칙 팩 검증이 실패했습니다.")
	var temporary: String = POINTER + ".tmp"
	var output: FileAccess = FileAccess.open(temporary,FileAccess.WRITE)
	if output == null:
		pack = previous_pack
		sha256 = previous_sha
		return _error("규칙 팩 설치 기록을 저장할 수 없습니다.")
	output.store_string(JSON.stringify({"schema":Common.SCHEMA,"sha256":digest}))
	output.flush()
	var written: Error = output.get_error()
	output.close()
	if written != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(POINTER)) != OK:
		pack = previous_pack
		sha256 = previous_sha
		return _error("규칙 팩 활성화 기록의 원자 저장이 실패했습니다.")
	status = "523 규칙 팩 설치됨 · " + digest.left(12)
	return {"ok":true,"sha256":digest}

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
