extends Node
## Separate actor art pack for the Android APK.
##
## Android cannot sign an APK over 4 GB, and the shipped actor sheets alone are
## larger than the rest of the game. The APK is therefore exported without
## res://assets/actors/, and the same files ship as twilight_actor_pack.pck,
## exported from the same commit with the "AndroidActorPack" preset. This
## autoload is first in [autoload], so the pack is mounted in _init before any
## other script or scene can load an actor resource; paths stay res://.
##
## The editor and desktop runs keep reading the project folder: the pack is
## only looked for in an exported build whose actor files are absent.

const PACK_PATH := "user://twilight_actor_pack.pck"
## Any shipped actor file proves the actors are reachable.
const SENTINEL := "res://assets/actors/eight_direction"
const COPY_CHUNK := 16 * 1024 * 1024
const STYLE = preload("res://scripts/boot/boot_style.gd")

var mounted: bool = false
var needed: bool = false
var _layer: CanvasLayer
var _status: Label
var _choose: Button
var _picker: FileDialog
var _source: FileAccess
var _target: FileAccess
var _copied: int = 0
var _total: int = 0

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("template"): return
	if FileAccess.file_exists(PACK_PATH):
		# Never replace APK files: an older pack must not override newer code.
		mounted = ProjectSettings.load_resource_pack(PACK_PATH, false)
	needed = not DirAccess.dir_exists_absolute(SENTINEL)

func _ready() -> void:
	set_process(false)
	if needed: _show_installer.call_deferred()

func _show_installer() -> void:
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)
	var box: VBoxContainer = STYLE.installer_frame(_layer)
	box.add_child(STYLE.label("그림 팩 설치", 26, STYLE.GOLD))
	_status = STYLE.label("", 20)
	_status.text = "캐릭터·몬스터 그림 팩이 없습니다.\n같은 빌드에서 받은 twilight_actor_pack.pck 를 선택하세요." if not mounted else "그림 팩이 이 APK와 맞지 않습니다.\n같은 빌드에서 받은 twilight_actor_pack.pck 를 다시 선택하세요."
	box.add_child(_status)
	_choose = STYLE.button("그림 팩(.pck) 선택")
	_choose.pressed.connect(func() -> void: _picker.popup_centered_ratio(0.8))
	box.add_child(_choose)
	_picker = FileDialog.new()
	_picker.title = "TWILIGHT 그림 팩"
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_picker.use_native_dialog = true
	_picker.filters = PackedStringArray(["*.pck;TWILIGHT 그림 팩;application/octet-stream"])
	_picker.file_selected.connect(_start_copy)
	_layer.add_child(_picker)

func _start_copy(path: String) -> void:
	_source = FileAccess.open(path, FileAccess.READ)
	if _source == null:
		_status.text = "파일을 열 수 없습니다 (%s)." % error_string(FileAccess.get_open_error())
		return
	_target = FileAccess.open(PACK_PATH + ".part", FileAccess.WRITE)
	if _target == null:
		_source = null
		_status.text = "앱 저장소에 쓸 수 없습니다 (%s)." % error_string(FileAccess.get_open_error())
		return
	_total = int(_source.get_length())
	_copied = 0
	_choose.disabled = true
	set_process(true)

func _process(_delta: float) -> void:
	if _source == null: return
	var chunk: PackedByteArray = _source.get_buffer(mini(COPY_CHUNK, _total - _copied))
	_target.store_buffer(chunk)
	_copied += chunk.size()
	_status.text = "그림 팩 복사 중 %d / %d MB" % [_copied >> 20, _total >> 20]
	if chunk.is_empty() or _copied >= _total:
		set_process(false)
		var complete: bool = _copied == _total and _target.get_error() == OK
		_source = null
		_target.close()
		_target = null
		if not complete:
			DirAccess.remove_absolute(PACK_PATH + ".part")
			_status.text = "복사에 실패했습니다. 저장 공간을 확인하고 다시 선택하세요."
			_choose.disabled = false
			return
		if FileAccess.file_exists(PACK_PATH): DirAccess.remove_absolute(PACK_PATH)
		DirAccess.rename_absolute(PACK_PATH + ".part", PACK_PATH)
		_status.text = "설치 완료. 앱을 완전히 닫고 다시 실행하세요."
		_choose.text = "앱 닫기"
		_choose.disabled = false
		for connection: Dictionary in _choose.pressed.get_connections():
			_choose.pressed.disconnect(connection.callable)
		_choose.pressed.connect(func() -> void: get_tree().quit())
