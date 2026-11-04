extends Control
## First-run gate for the external catalog component; Main and saves are unchanged.
const Store = preload("res://scripts/resources/private_catalog_motion.gd")
var _status: Label
var _choose: Button
var _picker: FileDialog
var _installer: Node
var _busy := false
var _cancel_requested := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(600, 220)
	panel.add_theme_constant_override("separation", 18)
	center.add_child(panel)
	var title := Label.new()
	title.text = "TWILIGHT 리소스 준비"
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)
	_status = Label.new()
	_status.text = "표시팩을 확인하고 있습니다."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(600, 80)
	panel.add_child(_status)
	_choose = Button.new()
	_choose.text = "다운로드한 카탈로그 표시팩 ZIP 선택"
	_choose.pressed.connect(func(): _picker.popup_centered_ratio(0.8))
	panel.add_child(_choose)
	var cancel := Button.new()
	cancel.text = "설치 취소 · 종료"
	cancel.pressed.connect(func():
		if _busy: _installer.cancelled = true; _cancel_requested = true
		else: get_tree().quit())
	panel.add_child(cancel)
	_picker = FileDialog.new()
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_picker.use_native_dialog = true
	_picker.filters = PackedStringArray(["*.zip;TWILIGHT 카탈로그 표시팩;application/zip"])
	_picker.file_selected.connect(_selected)
	add_child(_picker)
	_installer = Store.new()
	_installer.progress.connect(func(done: int, total: int): _status.text = "표시팩 설치 %d / %d" % [done, total])
	add_child(_installer)
	call_deferred("_attempt_start")

func _attempt_start() -> void:
	_busy = true
	_cancel_requested = false
	_choose.disabled = true
	var data: Dictionary = Store.index_data()
	if data.is_empty():
		_show_setup("앱의 표시팩 검증 목록이 손상됐습니다. 올바른 코드 버전으로 다시 설치하세요.")
		return
	var root: String = Store.active_root()
	if root.is_empty() and Store.embedded_complete(): root = "res://"
	if root.is_empty():
		_show_setup("비공개 Drive에서 받은 카탈로그 표시팩을 설치해 주세요.\n분할 파일은 먼저 안내 도구로 ZIP으로 복원합니다. 저장 데이터는 유지됩니다.")
		return
	var count := 0
	for relative: String in data.files:
		if _cancel_requested:
			_show_setup("표시팩 확인을 중단했습니다. 기존 팩과 저장 데이터는 유지됩니다.")
			return
		var file: String = root.path_join(relative)
		if not Store.verified_file(file, data.files[relative]):
			_show_setup("표시팩이 누락되었거나 손상됐습니다. 올바른 ZIP을 선택해 다시 설치해 주세요. 기존 저장 데이터는 유지됩니다.")
			return
		count += 1
		if count % 16 == 0:
			_status.text = "표시팩 확인 %d / 723" % count
			await get_tree().process_frame
	_status.text = "확인 완료 · 게임 시작"
	var error: Error = get_tree().change_scene_to_file("res://Main.tscn")
	if error != OK: _show_setup("게임 코드가 누락됐습니다. 올바른 앱 버전으로 다시 설치하세요.")

func _show_setup(message: String) -> void:
	_status.text = message
	_choose.disabled = false
	_busy = false

func _selected(path: String) -> void:
	if _busy: return
	_busy = true
	_choose.disabled = true
	var result: Dictionary = await _installer.install_zip(path)
	if not result.ok:
		_show_setup(str(result.error))
		return
	await _attempt_start()
