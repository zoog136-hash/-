extends Control
## Completed verification items + scene milestones. This overlay survives the
## scene change until the destination's deferred initialization has finished.
const MAIN := "res://Main.tscn"
const CHARACTERS := "res://scenes/boot/Characters.tscn"
const CHARACTER_PROFILE_PATH := "res://scripts/characters/save_profile.gd"
const STYLE := preload("res://scripts/boot/boot_style.gd")
const BOOT_LOG := preload("res://scripts/boot/boot_progress_log.gd")
const FRAME_HITCH := preload("res://scripts/boot/frame_hitch_log.gd")
const PREBAKE := preload("res://scripts/boot/source523_prebake.gd")
const HANDOFF := preload("res://scripts/boot/source523_prebake_handoff.gd")
const JOB := preload("res://scripts/boot/source523_prebake_job.gd")
const PROGRESS := preload("res://scripts/boot/loading_progress.gd")
## Show the title picture after loading until a touch (off in headless runs).
var title_after_loading: bool = true
## Test hook: also show the title stage under the headless display server.
var title_in_headless: bool = false
var _awaiting_title: bool = false
var _title_prompt: Label
var _column: VBoxContainer
var destination: String = ""
## A missing readiness response is an error state, never invented progress.
var readiness_timeout_msec: int = 60000
var _overlay: CanvasLayer
var _status: Label
var _bar: ProgressBar
var _count: Label
var _stage: Label
var _cache_warning: Label
var _cache_misses: Array[String] = []
var _retry: Button
var _dismiss: Button
var _progress = PROGRESS.new()
var _job: RefCounted
var _running: bool = false
var _owns_pause: bool = false
var _previous: String = ""
signal progress_changed(snapshot: Dictionary)
signal finished(ok: bool)

## Character lobby integration: call only after select_character() succeeds.
## Keeps the account session and selected scene intact; creates no save data.
static func open(tree: SceneTree, target: String = MAIN) -> Control:
	var existing: Node = tree.get_first_node_in_group("twilight_loading")
	if existing != null: return existing as Control
	var loader: Control = (load("res://scripts/boot/loading_screen.gd") as Script).new()
	loader.destination = target
	var layer := CanvasLayer.new()
	layer.layer = 126 # Pack installers stay above this at 127.
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	loader._overlay = layer
	tree.root.add_child(layer)
	layer.add_child(loader)
	return loader

## The profile is optional on main. When installed, its existing review and
## debug gates remain authoritative; no save namespace is selected here.
static func initial_destination() -> String:
	var headless: bool = DisplayServer.get_name() == "headless"
	var available: bool = ResourceLoader.exists(CHARACTERS)
	return destination_for(headless, available, not headless and available and _roster_allowed())

static func destination_for(headless: bool, roster_available: bool, roster_allowed: bool) -> String:
	return CHARACTERS if not headless and roster_available and roster_allowed else MAIN

static func _roster_allowed() -> bool:
	if not ResourceLoader.exists(CHARACTER_PROFILE_PATH): return true
	return _profile_allows(load(CHARACTER_PROFILE_PATH) as Script)

static func _profile_allows(profile: Script) -> bool:
	if profile == null: return false
	# Script.has_method() describes Resource methods, not this static API.
	for method: Dictionary in profile.get_script_method_list():
		if method.get("name") != "allows_roster": continue
		if (int(method.get("flags", 0)) & METHOD_FLAG_STATIC) == 0 or not method.get("args", []).is_empty(): return false
		var allowed: Variant = profile.call("allows_roster")
		return allowed is bool and allowed
	return false

## The roster uses portraits/UI but never map readers. Defer maps until the
## selected character enters Main, where the verified readers can be consumed.
static func plan_steps(steps: Array[Dictionary], target: String) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for step: Dictionary in steps:
		if target == CHARACTERS and step.get("id") in ["maps", "tiles"]: continue
		selected.append(step)
	return selected

func _ready() -> void:
	add_to_group("twilight_loading")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_previous = BOOT_LOG.previous_unfinished()
	BOOT_LOG.mark("loading_screen", {"previous_unfinished": _previous})
	FRAME_HITCH.start()
	var hitch_line: String = FRAME_HITCH.previous_line()
	if not hitch_line.is_empty(): BOOT_LOG.mark("previous_frame_hitch", {"line": hitch_line})
	if destination.is_empty(): destination = initial_destination()
	add_child(STYLE.backdrop())
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	# Scale with narrow landscape windows instead of clipping a fixed 720px bar.
	column.anchor_left = 0.1
	column.anchor_right = 0.9
	column.offset_left = 0
	column.offset_right = 0
	column.offset_top = -200
	column.offset_bottom = -24
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.add_theme_constant_override("separation", 7)
	add_child(column)
	_column = column
	_status = STYLE.label("원본 데이터 확인을 준비하는 중…", 22, STYLE.TEXT)
	column.add_child(_status)
	_bar = STYLE.progress_bar()
	if not hitch_line.is_empty():
		var hitch := STYLE.label(hitch_line + " · 기록 " + FRAME_HITCH.PREV_NAME, 15, STYLE.GOLD)
		hitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(hitch)
	_bar.custom_minimum_size = Vector2(0, 22)
	_bar.max_value = 100
	_bar.show_percentage = true
	column.add_child(_bar)
	_count = STYLE.label("완료 작업 0/0 · 작업 수 기준", 16, STYLE.GOLD)
	column.add_child(_count)
	column.add_child(STYLE.label("검증 중에는 완료한 작업만 표시합니다. 단계별 소요 시간은 다릅니다.", 16, STYLE.MUTED))
	_stage = STYLE.label("지난 실행 중단 단계: " + _previous if not _previous.is_empty() else "", 14, STYLE.MUTED)
	column.add_child(_stage)
	_cache_warning = STYLE.label("", 14, STYLE.GOLD)
	_cache_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_cache_warning)
	_retry = STYLE.button("다시 시도", true, 44)
	_retry.custom_minimum_size.x = 0
	_retry.visible = false
	_retry.pressed.connect(_boot)
	column.add_child(_retry)
	_dismiss = STYLE.button("오류 화면 보기", false, 44)
	_dismiss.custom_minimum_size.x = 0
	_dismiss.visible = false
	_dismiss.pressed.connect(_close)
	column.add_child(_dismiss)
	var version := STYLE.label(_version_text(), 15, Color(STYLE.MUTED, 0.75))
	version.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	version.offset_left = -320
	version.offset_right = -16
	version.offset_top = 10
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)
	_start.call_deferred()

func _version_text() -> String:
	var updater: Node = get_node_or_null("/root/Updater")
	var name: String = str(updater.call("version_name")) if updater != null else ""
	if name.is_empty(): name = str(ProjectSettings.get_setting("application/config/version", ""))
	return "TWILIGHT " + name if not name.is_empty() else "TWILIGHT"

func _start() -> void:
	if _overlay == null:
		# Detach the initial Loading scene so change_scene cannot free its UI.
		_overlay = CanvasLayer.new()
		_overlay.layer = 126
		_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(_overlay)
		if get_tree().current_scene == self: get_tree().current_scene = null
		reparent(_overlay)
	_boot()

func snapshot() -> Dictionary:
	return _progress.snapshot()

func _render(detail: String = "") -> void:
	var value: Dictionary = snapshot()
	_bar.value = value.percent
	_status.text = value.status
	_count.text = "완료 작업 %d/%d · 작업 수 기준" % [value.completed, value.total]
	if not detail.is_empty(): _stage.text = detail
	progress_changed.emit(value)

func _boot() -> void:
	if _running: return
	_running = true
	_retry.hide()
	_dismiss.hide()
	_cache_misses.clear()
	_cache_warning.hide()
	# Installers may configure the pack after this screen was constructed.
	while get_tree().paused and not _owns_pause:
		_status.text = "리소스 팩 설치를 기다리는 중…"
		await get_tree().process_frame
	HANDOFF.clear()
	var steps: Array[Dictionary] = plan_steps(PREBAKE.pending(), destination)
	_progress.configure(steps)
	BOOT_LOG.mark("loading_plan", {"verification_items": steps.size(), "scene": destination})
	for step: Dictionary in steps:
		_progress.begin_task(str(step.id), "원본 %s 검증·정리 중…" % str(step.label))
		_render("현재 단계의 남은 시간은 계산할 수 없습니다.")
		await get_tree().process_frame
		_job = JOB.new()
		var result: Dictionary
		var error: Error = _job.start(step)
		if error == OK:
			while not _job.completed():
				_render("검증 단계: " + BOOT_LOG.current_stage())
				await get_tree().process_frame
			result = _job.finish()
		else:
			_render("백그라운드 검증을 시작하지 못해 현재 단계에서 직접 검증합니다.")
			await get_tree().process_frame
			result = PREBAKE.run_result(step)
		_job = null
		if not result.get("ok", false):
			_fail("원본 %s 검증 실패 · 파일과 저장 공간을 확인한 뒤 다시 시도하세요." % str(step.label))
			return
		if not result.get("baked", false):
			_cache_misses.append(str(step.label))
			_cache_warning.text = "기기 캐시 저장 실패: %s · 다음 실행에 다시 정리합니다." % ", ".join(_cache_misses)
			_cache_warning.show()
		_progress.complete_task(str(step.id))
		_render("검증 완료" if result.get("baked", false) else "검증 완료 · 기기 캐시 저장 실패, 다음 실행에 다시 정리합니다.")
	_progress.begin_task("scene_load", "게임 장면을 불러오는 중…")
	_render("게임 장면 준비 · 세부 진행률을 측정할 수 없어 완료 작업 수를 유지합니다.")
	await get_tree().process_frame
	# Main stays on the main thread: Android GL shader preloads failed with
	# worker-thread ResourceLoader in the prior implementation.
	var started: int = BOOT_LOG.begin("main_scene_load", {"scene": destination})
	var scene: PackedScene = load(destination) as PackedScene if ResourceLoader.exists(destination) else null
	BOOT_LOG.end("main_scene_load", started, {"ok": scene != null})
	if scene == null:
		_fail("게임 파일을 불러오지 못했습니다. 파일을 확인한 뒤 다시 시도하세요.")
		return
	_progress.complete_task("scene_load")
	_progress.begin_task("scene_change", "게임과 캐릭터를 초기화하는 중…")
	_render("초기화 중 · 완료 전에는 100%로 표시하지 않습니다.")
	await get_tree().process_frame
	get_tree().paused = true
	_owns_pause = true
	started = BOOT_LOG.begin("main_scene_change")
	var change_error: Error = get_tree().change_scene_to_packed(scene)
	if change_error != OK:
		BOOT_LOG.end("main_scene_change", started, {"ok": false, "error": change_error})
		_fail("게임 장면으로 전환하지 못했습니다. 다시 시도하세요.")
		return
	await get_tree().scene_changed
	BOOT_LOG.end("main_scene_change", started, {"ok": true})
	_progress.complete_task("scene_change")
	_progress.begin_task("scene_ready", "지도와 선택 캐릭터를 준비하는 중…")
	_render("저장 위치와 지도 복원이 끝나기를 기다리는 중…")
	# scene_changed guarantees _ready, but World also queues source-map restore.
	# The explicit contract below is set after those deferred calls.
	var target: Node = get_tree().current_scene
	var readiness_started: int = Time.get_ticks_msec()
	while is_instance_valid(target):
		var readiness: Dictionary = target.call("loading_readiness") if target.has_method("loading_readiness") else {"ready": target.is_node_ready(), "failed": false}
		if readiness.get("failed", false):
			_fail("게임 준비를 완료하지 못했습니다: " + str(readiness.get("reason", "원본 팩 또는 저장 파일 확인 필요")))
			return
		if readiness.get("ready", false): break
		if Time.get_ticks_msec() - readiness_started >= readiness_timeout_msec:
			_fail("준비 완료 응답을 확인하지 못했습니다. 오류 화면을 확인하거나 다시 시도하세요.")
			return
		await get_tree().process_frame
	if not is_instance_valid(target):
		_fail("준비 중인 게임 장면이 종료되었습니다. 다시 시도하세요.")
		return
	_progress.complete_task("scene_ready")
	_render("준비 완료")
	BOOT_LOG.mark("loading_ready", {"scene": destination, "completed": snapshot().completed, "total": snapshot().total})
	_running = false
	finished.emit(true)
	# One render opportunity for the measured 100%, then reveal the ready scene.
	await get_tree().process_frame
	if title_after_loading and (title_in_headless or DisplayServer.get_name() != "headless"):
		_show_title()
		return
	_close()

## After loading, the title picture alone (no progress text) until the player
## touches the screen; the ready scene stays paused behind it. The engine boot
## splash shows only the background color, so the title appears once, here.
func _show_title() -> void:
	if is_instance_valid(_column): _column.hide()
	_title_prompt = STYLE.label("화면을 터치하세요", 24, STYLE.TEXT)
	_title_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_title_prompt.offset_top = -96
	_title_prompt.offset_bottom = -48
	_title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title_prompt)
	_awaiting_title = true
	BOOT_LOG.mark("title_shown", {"scene": destination})

func is_awaiting_title() -> bool:
	return _awaiting_title

func _process(_delta: float) -> void:
	if _awaiting_title and is_instance_valid(_title_prompt):
		_title_prompt.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 600.0))

func _input(event: InputEvent) -> void:
	if not _awaiting_title: return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed: return
	get_viewport().set_input_as_handled()
	_awaiting_title = false
	BOOT_LOG.mark("title_closed", {"scene": destination})
	_close()

func _fail(message: String) -> void:
	_progress.fail_task(message)
	_render("진행률은 유지됩니다. 실패한 작업은 완료로 계산하지 않습니다.")
	_running = false
	_retry.show()
	_dismiss.visible = get_tree().current_scene != null
	BOOT_LOG.mark("loading_failed", {"scene": destination, "completed": snapshot().completed})
	finished.emit(false)

func _close() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
	HANDOFF.clear()
	if _overlay != null: _overlay.queue_free()
	else: queue_free()

func _exit_tree() -> void:
	if _job != null: _job.finish()
	HANDOFF.clear()
	if _owns_pause and get_tree() != null: get_tree().paused = false
