extends Control
## TWILIGHT's own loading screen (the project's main scene).
## It shows the same picture as the boot splash, draws a few frames, then
## loads and enters Main.tscn. While a pack installer is open the tree is
## paused, so the game is not loaded until the installer finishes.
const MAIN := "res://Main.tscn"
const STYLE := preload("res://scripts/boot/boot_style.gd")
const TIPS := [
	"처음 실행할 때는 원본 데이터를 기기에 맞게 정리하느라 몇 분 걸릴 수 있습니다.",
	"다음 실행부터는 정리해 둔 데이터를 바로 읽어 훨씬 빨리 시작합니다.",
	"리소스 팩은 한 번만 설치하면 됩니다. 업데이트해도 그대로 남습니다.",
]
var _status: Label
var _tip: Label
var _bar: ProgressBar
var _frames: int = 0
var _shown: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if DisplayServer.get_name() == "headless":
		# Automated boots keep loading Main directly and synchronously.
		set_process(false)
		_enter.call_deferred(load(MAIN) as PackedScene)
		return
	add_child(STYLE.backdrop())
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	column.offset_left = -360
	column.offset_right = 360
	column.offset_top = -150
	column.offset_bottom = -34
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	_status = STYLE.label("게임을 불러오는 중…", 24, STYLE.TEXT)
	column.add_child(_status)
	_bar = STYLE.progress_bar()
	_bar.custom_minimum_size = Vector2(720, 16)
	_bar.max_value = 100.0
	column.add_child(_bar)
	_tip = STYLE.label(TIPS[0], 18, STYLE.MUTED)
	column.add_child(_tip)
	var version := STYLE.label(_version_text(), 15, Color(STYLE.MUTED, 0.75))
	version.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	version.offset_left = -320
	version.offset_right = -16
	version.offset_top = 10
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)

func _version_text() -> String:
	# A mounted update pack is newer than the APK's own version setting.
	var updater: Node = get_node_or_null("/root/Updater")
	var name: String = str(updater.call("version_name")) if updater != null else ""
	if name.is_empty(): name = str(ProjectSettings.get_setting("application/config/version", ""))
	return "TWILIGHT " + name if not name.is_empty() else "TWILIGHT"

func _process(delta: float) -> void:
	_shown += delta
	_tip.text = TIPS[int(_shown / 6.0) % TIPS.size()]
	_frames += 1
	_bar.value = minf(30.0, _frames * 6.0)
	if _frames == 4:
		_status.text = "세계를 준비하는 중… (처음 실행은 몇 분 걸릴 수 있습니다)"
	if _frames < 6: return
	# Loaded on the main thread: a worker-thread load of Main failed to
	# preload shaders under the mobile (GL compatibility) renderer. The
	# screen keeps its last drawn frame during the long start.
	set_process(false)
	_enter(load(MAIN) as PackedScene)

func _enter(scene: PackedScene) -> void:
	if scene == null:
		if _status != null: _status.text = "게임 파일을 불러오지 못했습니다. 앱을 다시 설치해 주세요."
		set_process(false)
		return
	set_process(false)
	if _bar != null: _bar.value = 100.0
	get_tree().change_scene_to_packed(scene)
