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
const DEFINITIONS := preload("res://scripts/resources/current523_definition_rows.gd")
const ERROR_RECORD := preload("res://scripts/boot/error_record.gd")
const UI_SELECTION := preload("res://scripts/ui/original_ui/source_main_selection.gd")
const UI_PACK := preload("res://scripts/ui/original_ui/source_pack.gd")
const NAMED_TREE := preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const PACK_VERSION := preload("res://scripts/ui/original_ui/source_ui_pack_version.gd")
const ICON_STATUS := preload("res://scripts/ui/item_icon_resource_status.gd")
## The original 523 loading indicator (UI/CommonUi/Fx_Loading.csb, clip
## Fx_Loop). The loading background stays a plain colour: no original 523
## loading backdrop exists (user decision 2026-11-17).
const FX_LOADING := UI_PACK.LOADING_FX_MEMBER
const FX_LOADING_CLIP := "Fx_Loop"
## Fx_Loading's authored design area (its Bg ImageView is 1600x675).
const FX_LOADING_DESIGN := Vector2(1600, 675)
## Show the title picture after loading until a touch (off in headless runs).
var title_after_loading: bool = true
## Test hook: also show the title stage under the headless display server.
var title_in_headless: bool = false
var _awaiting_title: bool = false
var _title_prompt: Label
## Title-screen shortcut to the add-on/cooked pack installer, so packs can be
## installed before entering the game (2026-11-16: the game closed within
## minutes of entering the world, before the settings screen could be used).
var _title_addon: Button
var _column: VBoxContainer
var destination: String = ""
## Main.tscn loaded during the first loading so entering the world from the
## character screen does not load the game scene again.
static var _prepared_main: PackedScene
## A missing readiness response is an error state, never invented progress.
var readiness_timeout_msec: int = 60000
var _overlay: CanvasLayer
var _status: Label
var _ui_pack: Label
var _ui_pack_sha: String = ""
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
## Holder of the original Fx_Loading scene; null until the original UI pack is
## installed and its scene trees are on the device.
var _fx_loading: Node2D
## Result of the last attach attempt (diagnostics and tests).
var fx_loading_status: Dictionary = {}
signal progress_changed(snapshot: Dictionary)
signal finished(ok: bool)

## Character lobby integration: call only after select_character() succeeds.
## Keeps the account session and selected scene intact; creates no save data.
static func open(tree: SceneTree, target: String = MAIN, show_title: bool = true) -> Control:
	var existing: Node = tree.get_first_node_in_group("twilight_loading")
	if existing != null: return existing as Control
	var loader: Control = (load("res://scripts/boot/loading_screen.gd") as Script).new()
	loader.destination = target
	loader.title_after_loading = show_title
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
	var available: bool = preload("res://scripts/resources/retired_assets.gd").usable(CHARACTERS)
	return destination_for(headless, available, not headless and available and _roster_allowed())

static func destination_for(headless: bool, roster_available: bool, roster_allowed: bool) -> String:
	return CHARACTERS if not headless and roster_available and roster_allowed else MAIN

static func _roster_allowed() -> bool:
	if not preload("res://scripts/resources/retired_assets.gd").usable(CHARACTER_PROFILE_PATH): return true
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

## Every verification item runs in the first loading, also before the
## character screen (user decision 2026-11-13: loading finishes completely,
## then one touch opens the character screen). Map/tile results persist as
## device bakes; the in-memory readers are released before the roster opens.
static func plan_steps(steps: Array[Dictionary], _target: String) -> Array[Dictionary]:
	return steps.duplicate()

func _prepares_main() -> bool:
	return destination == CHARACTERS and _prepared_main == null and preload("res://scripts/resources/retired_assets.gd").usable(MAIN)

## The Main scene prepared by the first loading, if any.
static func prepared_main() -> PackedScene:
	return _prepared_main

func _ready() -> void:
	add_to_group("twilight_loading")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ERROR_RECORD.install()
	_previous = BOOT_LOG.previous_unfinished()
	var end_line: String = BOOT_LOG.previous_end_line()
	var error_line: String = ERROR_RECORD.previous_line()
	BOOT_LOG.mark("loading_screen", {"previous_unfinished": _previous})
	FRAME_HITCH.start()
	preload("res://scripts/boot/performance_report_session.gd").ensure(get_tree())
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
	if not end_line.is_empty():
		var ending := STYLE.label(end_line, 15, STYLE.GOLD)
		ending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(ending)
	if not error_line.is_empty():
		var error_label := STYLE.label(error_line, 15, STYLE.GOLD)
		error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(error_label)
	_bar.custom_minimum_size = Vector2(0, 22)
	_bar.max_value = 100
	_bar.show_percentage = true
	column.add_child(_bar)
	_count = STYLE.label("완료 작업 0/0 · 작업 수 기준", 16, STYLE.GOLD)
	column.add_child(_count)
	column.add_child(STYLE.label("준비 중에는 완료한 작업만 표시합니다. 단계별 소요 시간은 다릅니다.", 16, STYLE.MUTED))
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
	# The installed UI add-on (and a reinstall notice when it is old) under
	# the version; refreshed as the boot selects the pack.
	_ui_pack = STYLE.label("", 14, Color(STYLE.MUTED, 0.75))
	_ui_pack.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_ui_pack.offset_left = -520
	_ui_pack.offset_right = -16
	_ui_pack.offset_top = 32
	_ui_pack.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui_pack.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_ui_pack)
	_refresh_ui_pack()
	_start.call_deferred()

## UI 팩 ui46 (91e2c03b); an old pack adds the reinstall notice. The game
## is never held for it.
func _refresh_ui_pack() -> void:
	if not is_instance_valid(_ui_pack): return
	var sha: String = OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	if sha == _ui_pack_sha and not _ui_pack.text.is_empty(): return
	_ui_pack_sha = sha
	var info: Dictionary = PACK_VERSION.installed()
	_ui_pack.text = PACK_VERSION.label(info) + ("\n" + PACK_VERSION.WARNING if bool(info.outdated) else "")
	# Item icons (images section of the resource pack), checked without
	# opening the image list: only a missing one is announced here.
	var icons: Dictionary = ICON_STATUS.check(false)
	var icons_missing: bool = not bool(icons.ok) and not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty()
	if icons_missing: _ui_pack.text += "\n" + ICON_STATUS.label(icons)
	_ui_pack.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35) if bool(info.outdated) or icons_missing else Color(STYLE.MUTED, 0.75))

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
	_refresh_ui_pack()
	var value: Dictionary = snapshot()
	_bar.value = value.percent
	_status.text = value.status
	_count.text = "완료 작업 %d/%d · 작업 수 기준" % [value.completed, value.total]
	if int(value.scene_total) > 0:
		_count.text += " · 월드 준비 %d/%d" % [value.scene_completed, value.scene_total]
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
	_attach_original_loading_fx()
	while get_tree().paused and not _owns_pause:
		_status.text = "리소스 팩 설치를 기다리는 중…"
		await get_tree().process_frame
	HANDOFF.clear()
	_attach_original_loading_fx()
	var steps: Array[Dictionary] = plan_steps(PREBAKE.pending(), destination)
	var counted: Array[Dictionary] = steps.duplicate()
	# Original tables used on earlier runs whose stored form an update made
	# outdated are converted here, not one by one during play.
	var tables: PackedStringArray = DEFINITIONS.tables_to_prepare()
	if not tables.is_empty(): counted.append({"id": "definitions", "label": "원본 표"})
	if _prepares_main(): counted.append({"id": "main_prepare", "label": "게임 장면"})
	_progress.configure(counted)
	BOOT_LOG.mark("loading_plan", {"verification_items": steps.size(), "scene": destination})
	for step: Dictionary in steps:
		_progress.begin_task(str(step.id), "%s 준비 중…" % str(step.label))
		_render("현재 단계의 남은 시간은 계산할 수 없습니다.")
		await get_tree().process_frame
		_job = JOB.new()
		var result: Dictionary
		var error: Error = _job.start(step)
		if error == OK:
			while not _job.completed():
				_render("준비 단계: " + BOOT_LOG.current_stage() if preload("res://scripts/boot/build_flags.gd").developer_ui() else "준비 중…")
				await get_tree().process_frame
			result = _job.finish()
		else:
			_render("준비를 계속하는 중…")
			await get_tree().process_frame
			result = PREBAKE.run_result(step)
		_job = null
		if not result.get("ok", false):
			_fail("%s 준비 실패 · 파일과 저장 공간을 확인한 뒤 다시 시도하세요." % str(step.label))
			return
		if not result.get("baked", false):
			_cache_misses.append(str(step.label))
			_cache_warning.text = "기기 캐시 저장 실패: %s · 다음 실행에 다시 정리합니다." % ", ".join(_cache_misses)
			_cache_warning.show()
		_progress.complete_task(str(step.id))
		_attach_original_loading_fx()
		_render("준비 완료" if result.get("baked", false) else "준비 완료 · 기기 캐시 저장 실패, 다음 실행에 다시 정리합니다.")
	if not tables.is_empty():
		_progress.begin_task("definitions", "원본 표를 준비하는 중…")
		var definitions_started: int = BOOT_LOG.begin("definitions_prepare", {"tables": tables.size()})
		for index: int in tables.size():
			_render("업데이트 후 한 번만: 원본 표 %d/%d (%s)" % [index + 1, tables.size(), tables[index]])
			await get_tree().process_frame
			DEFINITIONS.prepare_table(tables[index])
		DEFINITIONS.release_caches()
		BOOT_LOG.end("definitions_prepare", definitions_started, {"tables": tables.size()})
		_progress.complete_task("definitions")
	if _prepares_main():
		# The roster does not consume map readers; their bakes are on disk.
		HANDOFF.clear()
		_progress.begin_task("main_prepare", "게임 장면을 미리 불러오는 중…")
		_render("캐릭터 선택 후 바로 접속할 수 있도록 준비합니다.")
		await get_tree().process_frame
		var prepare_started: int = BOOT_LOG.begin("main_scene_prepare", {"scene": MAIN})
		_prepared_main = load(MAIN) as PackedScene
		BOOT_LOG.end("main_scene_prepare", prepare_started, {"ok": _prepared_main != null})
		_progress.complete_task("main_prepare")
	_progress.begin_task("scene_load", "게임 장면을 불러오는 중…")
	_render("게임 장면 준비 · 세부 진행률을 측정할 수 없어 완료 작업 수를 유지합니다.")
	await get_tree().process_frame
	# Main stays on the main thread: Android GL shader preloads failed with
	# worker-thread ResourceLoader in the prior implementation.
	var started: int = BOOT_LOG.begin("main_scene_load", {"scene": destination})
	var scene: PackedScene = _prepared_main if destination == MAIN and _prepared_main != null else (load(destination) as PackedScene if preload("res://scripts/resources/retired_assets.gd").usable(destination) else null)
	if destination == MAIN: _prepared_main = null
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
	# Scene instantiation and World readiness are separate milestones. The
	# game stays paused through initialization and selected-save restoration.
	var target: Node = get_tree().current_scene
	var readiness_started: int = Time.get_ticks_msec()
	while is_instance_valid(target):
		var readiness: Dictionary = target.call("loading_readiness") if target.has_method("loading_readiness") else {"ready": target.is_node_ready(), "failed": false}
		if readiness.get("failed", false):
			_fail("게임 준비를 완료하지 못했습니다: " + str(readiness.get("reason", "원본 팩 또는 저장 파일 확인 필요")))
			return
		if readiness.get("ready", false): break
		var world_work: Variant = readiness.get("world_work")
		if world_work is Dictionary and _progress.observe_scene_work(int(world_work.completed), int(world_work.total), str(world_work.status)):
			readiness_started = Time.get_ticks_msec()
			_render("완료한 월드 준비 단계만 반영합니다.")
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
	FRAME_HITCH.arm_trail()
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
	_release_original_loading_fx()
	if is_instance_valid(_column): _column.hide()
	_title_prompt = STYLE.label("화면을 터치하세요", 24, STYLE.TEXT)
	_title_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_title_prompt.offset_top = -96
	_title_prompt.offset_bottom = -48
	_title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title_prompt)
	var pack: Node = _source_pack()
	if pack != null and pack.has_method("open_addon_installer"):
		_title_addon = STYLE.button("추가 리소스(.zip) 설치·업데이트", false, 44)
		_title_addon.name = "TitleAddonInstall"
		_title_addon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_title_addon.offset_left = -420
		_title_addon.offset_right = -24
		_title_addon.offset_top = 24
		_title_addon.offset_bottom = 76
		_title_addon.pressed.connect(func() -> void:
			if is_instance_valid(pack): pack.call("open_addon_installer"))
		add_child(_title_addon)
	_awaiting_title = true
	BOOT_LOG.mark("title_shown", {"scene": destination})

func _source_pack() -> Node:
	return get_tree().root.get_node_or_null("Source523Pack") if is_inside_tree() else null

## The install screen is open over the title.
func _title_installer_open() -> bool:
	var pack: Node = _source_pack()
	return pack != null and pack.has_method("installer_open") and bool(pack.call("installer_open"))

func is_awaiting_title() -> bool:
	return _awaiting_title

func _process(_delta: float) -> void:
	if _awaiting_title and is_instance_valid(_title_prompt):
		_title_prompt.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 600.0))
		# Closing the install screen unpauses the tree; the ready scene stays
		# paused behind the title until it is touched.
		if _owns_pause and not get_tree().paused and not _title_installer_open(): get_tree().paused = true

func _input(event: InputEvent) -> void:
	if not _awaiting_title: return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed: return
	if _title_installer_open(): return
	# A press on the installer button is the button's, not "touch to start".
	if is_instance_valid(_title_addon) and _title_addon.visible and (event is InputEventScreenTouch or event is InputEventMouseButton) and _title_addon.get_global_rect().has_point(event.position): return
	get_viewport().set_input_as_handled()
	_awaiting_title = false
	if is_instance_valid(_title_addon): _title_addon.queue_free()
	BOOT_LOG.mark("title_closed", {"scene": destination})
	_close()

## Shows the original Fx_Loading indicator when the selected original UI pack
## already holds its scene trees on the device (a fresh pack is baked by the
## "원작 UI" step first, so the 34 MB manifest is never parsed twice here).
## Without the pack nothing is drawn: no substitute spinner.
func _attach_original_loading_fx() -> void:
	if is_instance_valid(_fx_loading): return
	var root: String = OS.get_environment("TWILIGHT_SOURCE_UI")
	var sha: String = OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	if root.is_empty() or sha.length() != 64:
		fx_loading_status = {"ok": false, "reason": "original_ui_pack_not_selected"}
		return
	if not UI_PACK.baked(sha):
		fx_loading_status = {"ok": false, "reason": "original_ui_pack_not_baked"}
		return
	var built: Dictionary = _build_original_loading_fx(UI_SELECTION.selected_pack(true))
	var scoped: bool = built.get("ok", false)
	if not scoped:
		# Older packs can author the indicator with different dependencies.
		built = _build_original_loading_fx(UI_SELECTION.selected_pack())
	if not built.get("ok", false):
		fx_loading_status = {"ok": false, "reason": str(built.get("error", "fx_loading_configure_failed")), "details": built.get("details", [])}
		return
	var scene: Node2D = built.scene
	var played: Dictionary = scene.play(FX_LOADING_CLIP, true)
	var holder := Node2D.new()
	holder.name = "OriginalFxLoading"
	holder.add_child(scene)
	add_child(holder)
	move_child(holder, 1) # above the plain backdrop, below the progress text
	_fx_loading = holder
	_layout_original_loading_fx()
	if not resized.is_connected(_layout_original_loading_fx): resized.connect(_layout_original_loading_fx)
	fx_loading_status = {"ok": true, "member": FX_LOADING, "clip": FX_LOADING_CLIP, "playing": played.get("ok", false), "scoped": scoped}
	BOOT_LOG.mark("original_fx_loading", fx_loading_status)

func _build_original_loading_fx(selected: Dictionary) -> Dictionary:
	if not selected.get("ok", false) or not selected.get("selected", false):
		return {"ok": false, "error": str(selected.get("code", selected.get("error", "original_ui_pack_unavailable")))}
	var pack: RefCounted = selected.pack
	if not pack.manifest.get("scenes", {}).has(FX_LOADING):
		return {"ok": false, "error": "fx_loading_missing_in_pack"}
	# The authored Text nodes contain placeholder notices. Loading uses the
	# status labels above; the original Bg retains its input behavior.
	return NAMED_TREE.new(pack).scene_of(FX_LOADING, {"Text": {"visible": false}, "Text_Sub": {"visible": false}}, {})

## Centre of the screen, scaled so the authored 1600x675 area fits.
func _layout_original_loading_fx() -> void:
	if not is_instance_valid(_fx_loading): return
	var area: Vector2 = size if size.x > 0 and size.y > 0 else get_viewport_rect().size
	var fit: float = minf(area.x / FX_LOADING_DESIGN.x, area.y / FX_LOADING_DESIGN.y)
	_fx_loading.scale = Vector2.ONE * fit
	_fx_loading.position = area * 0.5

func _release_original_loading_fx() -> void:
	if is_instance_valid(_fx_loading):
		_fx_loading.queue_free()
		fx_loading_status["released"] = true
	_fx_loading = null

func _fail(message: String) -> void:
	_release_original_loading_fx() # keep 다시 시도 / 오류 화면 보기 reachable
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
