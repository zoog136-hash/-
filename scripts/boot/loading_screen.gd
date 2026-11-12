extends Control
## TWILIGHT's own loading screen (the project's main scene).
## It shows the same picture as the boot splash, draws a few frames, then
## loads and enters Main.tscn. While a pack installer is open the tree is
## paused, so the game is not loaded until the installer finishes.
const MAIN := "res://Main.tscn"
const CHARACTERS := "res://scenes/boot/Characters.tscn"
const CHARACTER_PROFILE = preload("res://scripts/characters/save_profile.gd")
const STYLE := preload("res://scripts/boot/boot_style.gd")
## Boot progress record: stage lines go to user://boot_progress.log (see there).
const BOOT_LOG := preload("res://scripts/boot/boot_progress_log.gd")
const FRAME_HITCH := preload("res://scripts/boot/frame_hitch_log.gd")
const PREBAKE := preload("res://scripts/boot/source523_prebake.gd")
const TIPS := [
	"처음 실행할 때는 원본 데이터를 기기에 맞게 정리하느라 몇 분 걸릴 수 있습니다.",
	"다음 실행부터는 정리해 둔 데이터를 바로 읽어 훨씬 빨리 시작합니다.",
	"리소스 팩은 한 번만 설치하면 됩니다. 업데이트해도 그대로 남습니다.",
]
var _status: Label
var _tip: Label
var _bar: ProgressBar
var _stage: Label
var _frames: int = 0
var _shown: float = 0.0
var _prebake: Array[Dictionary] = []
var _prebake_total: int = 0
var _announced: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var previous: String = BOOT_LOG.previous_unfinished()
	BOOT_LOG.mark("loading_screen", {"previous_unfinished": previous})
	# Keep last run's frame hitch record (frame_hitch.prev.json) before play starts.
	FRAME_HITCH.start()
	var hitch_line: String = FRAME_HITCH.previous_line()
	if not hitch_line.is_empty(): BOOT_LOG.mark("previous_frame_hitch", {"line": hitch_line})
	if DisplayServer.get_name() == "headless":
		# Automated boots keep loading Main directly and synchronously.
		set_process(false)
		for step: Dictionary in PREBAKE.pending(): PREBAKE.run(step)
		_enter.call_deferred(_load_main())
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
	# The previous run's slowest frame and what took the time (the phone's
	# own measurement; full record: frame_hitch.prev.json next to the boot log).
	if not hitch_line.is_empty():
		var hitch := STYLE.label(hitch_line + " · 기록 " + FRAME_HITCH.PREV_NAME, 15, STYLE.GOLD)
		hitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(hitch)
	_bar.custom_minimum_size = Vector2(720, 16)
	_bar.max_value = 100.0
	column.add_child(_bar)
	_tip = STYLE.label(TIPS[0], 18, STYLE.MUTED)
	column.add_child(_tip)
	# Small boot-stage line; the previous run's unfinished stage helps report
	# where a killed first start stopped (full record: boot_progress logs).
	_stage = STYLE.label("", 14, Color(STYLE.MUTED, 0.8))
	if not previous.is_empty():
		_stage.text = "지난 실행이 끝나지 않은 단계: %s · 기록 %s" % [previous, ProjectSettings.globalize_path(BOOT_LOG.previous_path())]
	column.add_child(_stage)
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
		if _stage.text.is_empty(): _stage.text = "단계: 게임 장면 불러오기 · 기록 " + ProjectSettings.globalize_path(BOOT_LOG.log_path())
	if _frames < 6: return
	if _frames == 6:
		_prebake = PREBAKE.pending()
		_prebake_total = _prebake.size()
	# One first-run verification per frame: announced on one frame (so the
	# label is drawn), run on the next.
	if not _announced.is_empty():
		PREBAKE.run(_announced)
		_announced = {}
	if not _prebake.is_empty():
		_announced = _prebake.pop_front()
		var position: int = _prebake_total - _prebake.size()
		_status.text = "원본 %s 정리 중… (%d/%d · 처음 한 번만)" % [str(_announced.label), position, _prebake_total]
		_bar.value = 30.0 + 20.0 * float(position - 1) / float(maxi(1, _prebake_total))
		return
	# Loaded on the main thread: a worker-thread load of Main failed to
	# preload shaders under the mobile (GL compatibility) renderer. The
	# screen keeps its last drawn frame during the long start.
	set_process(false)
	_enter(_load_main())

func _load_main() -> PackedScene:
	var started: int = BOOT_LOG.begin("main_scene_load")
	var target: String = MAIN if DisplayServer.get_name()=="headless" or not CHARACTER_PROFILE.allows_roster() else CHARACTERS
	var scene: PackedScene = load(target) as PackedScene
	BOOT_LOG.end("main_scene_load", started, {"ok": scene != null})
	return scene

func _enter(scene: PackedScene) -> void:
	if scene == null:
		if _status != null: _status.text = "게임 파일을 불러오지 못했습니다. 앱을 다시 설치해 주세요."
		set_process(false)
		return
	set_process(false)
	if _bar != null: _bar.value = 100.0
	# Instantiation runs here; Main's _ready follows (world_ready stages).
	var started: int = BOOT_LOG.begin("main_scene_change")
	get_tree().change_scene_to_packed(scene)
	BOOT_LOG.end("main_scene_change", started)
