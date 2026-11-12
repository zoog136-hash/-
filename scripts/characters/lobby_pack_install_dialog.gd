extends Window
## Local pack import. Never sends source bytes to a server or changes save data.
signal installed(result: Dictionary)
const INSTALLER = preload("res://scripts/characters/lobby_pack_installer.gd")
var _worker: Thread
var _busy: bool = false
var _label: Label
var _choose: Button
var _close: Button
var _picker: FileDialog

func _ready() -> void:
	title = "원본 로비 리소스 설치"
	size = Vector2i(640, 300)
	unresizable = false
	transient = true
	exclusive = true
	close_requested.connect(_close_requested)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.text = "다운로드한 로비 ZIP 또는 분할 파일 3개(.001~.003)를 선택하세요.\n압축 해제 약 1.4GB, 분할 결합 포함 여유 공간 약 2GB가 필요합니다.\n기존 계정 저장과 게임 리소스는 변경하지 않습니다."
	column.add_child(_label)
	_choose = Button.new()
	_choose.text = "로비 팩 파일 선택"
	_choose.custom_minimum_size.y = 48
	_choose.pressed.connect(func() -> void: _picker.popup_centered_ratio(0.8))
	column.add_child(_choose)
	_close = Button.new()
	_close.text = "닫기"
	_close.custom_minimum_size.y = 48
	_close.pressed.connect(_close_requested)
	column.add_child(_close)
	_picker = FileDialog.new()
	_picker.title = "로비 ZIP 또는 분할 파일 3개 선택"
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_picker.use_native_dialog = true
	# Android providers can label split files as octet-stream; no MIME filter.
	_picker.files_selected.connect(_start)
	_picker.file_selected.connect(func(path: String) -> void: _start(PackedStringArray([path])))
	add_child(_picker)

func _start(paths: PackedStringArray) -> void:
	if _busy or paths.is_empty(): return
	_busy = true
	_choose.disabled = true
	_close.disabled = true
	_label.text = "팩 무결성 확인 중… 앱을 닫지 마세요."
	_worker = Thread.new()
	var error := _worker.start(func() -> Dictionary: return INSTALLER.install_paths(paths, _report))
	if error != OK:
		_worker = null
		_finish({"ok":false, "error":"설치 작업을 시작하지 못했습니다."})

func _report(fraction: float, stage: String) -> void:
	call_deferred("_show_progress", fraction, stage)

func _show_progress(_fraction: float, stage: String) -> void:
	if not _busy: return
	_label.text = "로비 팩 설치 중 · " + stage

func _process(_delta: float) -> void:
	if _worker != null and _worker.is_started() and not _worker.is_alive():
		var result: Variant = _worker.wait_to_finish()
		_worker = null
		_finish(result if result is Dictionary else {"ok":false,"error":"설치 결과 오류"})

func _finish(result: Dictionary) -> void:
	_busy = false
	_choose.disabled = false
	_close.disabled = false
	_label.text = "로비 팩 설치 완료. 직업·성별을 선택하면 적용됩니다." if result.get("ok",false) else "설치하지 못했습니다: %s\n파일과 여유 공간을 확인한 뒤 다시 선택하세요." % str(result.get("error","알 수 없는 오류"))
	if result.get("ok",false): installed.emit(result)

func _close_requested() -> void:
	if _busy: return
	queue_free()

func _exit_tree() -> void:
	# Do not destroy a running worker or partially activate an installation.
	if _worker != null and _worker.is_started(): _worker.wait_to_finish()
