extends RefCounted
const RULES = preload("res://scripts/crafting/patch523_rules.gd")
const INDEX: String = "user://patch523-equipment-active.json"
static var problem: String = ""

static func valid_sha(value: String) -> bool:
	if value.length() != 64: return false
	for ch: String in value:
		if not ch in "0123456789abcdef": return false
	return true

static func rules_path(sha: String) -> String:
	return "user://patch523-equipment/" + sha + "/rules.json" if valid_sha(sha) else ""

static func active() -> Dictionary:
	if not FileAccess.file_exists(INDEX): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(INDEX)) != OK: return {}
	var value: Variant = parser.data
	if not value is Dictionary or value.get("schema", "") != "patch523-equipment-install-v1": return {}
	var sha: String = str(value.get("sha256", ""))
	return {"path":rules_path(sha),"sha256":sha} if valid_sha(sha) else {}

static func install(path: String, expected: String) -> Dictionary:
	problem = ""
	if not valid_sha(expected):
		problem = "제공된 SHA256 64자리를 입력하세요"
		return {}
	var candidate = RULES.new()
	if not candidate.load_file(path, expected):
		problem = candidate.problem
		return {}
	var target: String = rules_path(expected)
	var absolute: String = ProjectSettings.globalize_path(target)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		problem = "규칙 팩 보관 폴더를 만들 수 없습니다"
		return {}
	if FileAccess.file_exists(target):
		if FileAccess.get_sha256(target) != expected:
			problem = "기존 보관 규칙 팩이 손상되어 교체를 중단했습니다"
			return {}
	else:
		var temporary: String = absolute + ".part-" + str(Time.get_ticks_usec())
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), temporary) != OK or FileAccess.get_sha256(temporary) != expected:
			problem = "규칙 팩 복사·해시 검증 실패 · 기존 설치 보존"
			return {}
		if DirAccess.rename_absolute(temporary, absolute) != OK:
			problem = "규칙 팩 보관 실패 · 기존 설치 보존"
			return {}
	var index_temp: String = INDEX + ".part-" + str(Time.get_ticks_usec())
	var file: FileAccess = FileAccess.open(index_temp, FileAccess.WRITE)
	if file == null:
		problem = "규칙 팩 선택 기록을 저장하지 못했습니다"
		return {}
	file.store_string(JSON.stringify({"schema":"patch523-equipment-install-v1","sha256":expected}))
	file.flush()
	var written: Error = file.get_error()
	file.close()
	if written != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(index_temp), ProjectSettings.globalize_path(INDEX)) != OK:
		problem = "규칙 팩 선택 기록 저장 실패 · 기존 설치 보존"
		return {}
	return {"path":target,"sha256":expected}
