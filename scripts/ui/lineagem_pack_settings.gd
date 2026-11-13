extends VBoxContainer
const INSTALLER = preload("res://scripts/lineagem_pack_install.gd")
const CURRENT523_HOST = preload("res://scripts/maps/current523_host.gd")
const SPAWN_POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
var installer: Node
var picker: FileDialog
var choose: Button
var cancel: Button
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	installer = INSTALLER.new()
	add_child(installer)
	var title := Label.new()
	title.text = "리니지M 원본 팩"
	add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cards_problem: String = INSTALLER.active_manifest_problem()
	status.text = "변신·인형·성물: %s · 몬스터: %s" % ["연결됨" if cards_problem.is_empty() else cards_problem, monster_status()]
	add_child(status)
	choose = Button.new()
	choose.name = "InstallLineageMOfflinePack"
	choose.text = "원본 팩 · 증분 · 몬스터 ZIP 선택"
	choose.pressed.connect(func() -> void: picker.popup_centered_ratio(0.8))
	add_child(choose)
	cancel = Button.new()
	cancel.text = "설치 중단"
	cancel.visible = false
	cancel.pressed.connect(func() -> void: installer.cancelled = true)
	add_child(cancel)
	picker = FileDialog.new()
	picker.title = "받은 원본 전체팩 또는 증분 선택"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.use_native_dialog = true
	picker.filters = PackedStringArray(["*.zip;TWILIGHT 원본 설치 팩;application/zip"])
	picker.file_selected.connect(_selected)
	add_child(picker)
	installer.progress.connect(func(done: int, total: int) -> void:
		status.text = "설치 검사 중 %d / %d · 기존 팩 유지" % [done, total])
	add_child(preload("res://scripts/ui/current523_pack_settings.gd").new())

func _selected(path: String) -> void:
	choose.disabled = true
	cancel.visible = true
	status.text = "설치 파일 확인 중…"
	var result: Dictionary = await installer.install_zip(path)
	choose.disabled = false
	cancel.visible = false
	if not result.ok:
		status.text = str(result.error)
	elif INSTALLER.preview_selection(OS.get_cmdline_user_args()).specified:
		status.text = "설치 완료 · 새 팩을 쓰려면 실행 시 지정한 원본 팩 옵션을 해제하고 게임을 다시 실행하세요."
	else:
		status.text = "설치 완료 · 게임을 완전히 종료한 뒤 다시 실행하세요."

## With the 523 pack installed, monsters come from its world-links spawn
## definitions; the old base508 monster pack is not used there.
static func monster_status() -> String:
	if CURRENT523_HOST.requested():
		return "523 출현 정의 연결됨" if bool(SPAWN_POLICY.settings().get("enabled", false)) else "523 출현 정의 없음 (patch523-world-links 설치 필요)"
	return "설치됨" if FileAccess.file_exists(INSTALLER.monster_root().path_join("manifest.json")) else "미설치"
