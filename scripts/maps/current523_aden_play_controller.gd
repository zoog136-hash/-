extends RefCounted
## Changes presentation only. Existing field/navigation/body/combat stay owned by Main.
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
var active: bool = false
var problem: String = ""
var settings: Dictionary = {}
var _world_ref: WeakRef
var _prior: FieldRenderer
var _prior_visible: bool = false
var _prior_mode: int = Node.PROCESS_MODE_INHERIT
var _renderer: FieldRenderer
var _notice: CanvasLayer

func configure(world: Node) -> void:
	_world_ref = weakref(world)

func _world() -> Node:
	return _world_ref.get_ref() as Node if _world_ref != null else null

func open(value: Dictionary) -> bool:
	problem = ""
	if active: problem = "아덴 실험 플레이가 이미 실행 중입니다."; return false
	var world: Node = _world()
	problem = OPTIONS.qualify(world)
	if not problem.is_empty(): return false
	if bool(world.get("current523_aden_review_active")): problem = "원문 검토를 닫은 뒤 실험 플레이를 시작해 주세요."; return false
	var options: Dictionary = OPTIONS.validate(value)
	if options.is_empty() or not options.enabled or options.navigation_profile != OPTIONS.LEGACY:
		problem = "기존 TWILIGHT 통행(자체 설정)을 선택해 주세요."; return false
	var prior: Variant = world.get("field_renderer")
	if not is_instance_valid(prior) or not prior is FieldRenderer:
		problem = "복귀할 기존 지도 표시가 없습니다."; return false
	var candidate = RENDERER.new()
	candidate.name = "Current523AdenPlayRenderer"
	candidate.process_mode = Node.PROCESS_MODE_DISABLED
	candidate.hide()
	world.add_child(candidate)
	if not candidate.try_configure(world.get("field_map"), world.get("player"), options.raw_root, options.tile_root, Vector2(options.offset_x, options.offset_y)):
		problem = candidate.problem
		candidate.queue_free()
		return false
	if OPTIONS.write(options) != OK:
		problem = "실험 플레이 설정을 저장하지 못했습니다. 기존 지도를 유지합니다."
		candidate.queue_free()
		return false
	_prior = prior
	_prior_visible = _prior.visible
	_prior_mode = _prior.process_mode
	_prior.hide()
	_prior.process_mode = Node.PROCESS_MODE_DISABLED
	_renderer = candidate
	world.set("field_renderer", candidate)
	settings = options
	active = true
	candidate.safe_return_requested.connect(_renderer_problem.bind(candidate))
	candidate.process_mode = Node.PROCESS_MODE_INHERIT
	candidate.show()
	_build_notice(world)
	return true

func close(remember_disabled: bool = true) -> bool:
	var saved: bool = true
	if remember_disabled:
		var options: Dictionary = OPTIONS.read()
		options.enabled = false
		saved = OPTIONS.write(options) == OK
	var world: Node = _world()
	if is_instance_valid(world) and is_instance_valid(_prior): world.set("field_renderer", _prior)
	if is_instance_valid(_renderer):
		_renderer.hide()
		_renderer.process_mode = Node.PROCESS_MODE_DISABLED
		_renderer.queue_free()
	if is_instance_valid(_prior):
		_prior.visible = _prior_visible
		_prior.process_mode = _prior_mode
	if is_instance_valid(_notice): _notice.queue_free()
	_renderer = null; _prior = null; _notice = null
	active = false
	return saved

func apply_options(value: Dictionary) -> bool:
	problem = ""
	var options: Dictionary = OPTIONS.validate(value)
	if not active or options.is_empty() or not options.enabled or options.navigation_profile != OPTIONS.LEGACY:
		problem = "실행 중인 자체 통행 설정이 아닙니다."; return false
	# Changing resource roots requires a new validated entry, not an in-place swap.
	if options.raw_root != settings.raw_root or options.tile_root != settings.tile_root:
		problem = "원본 팩을 바꾸려면 실험 플레이를 종료해 주세요."; return false
	var previous_delta := Vector2(settings.offset_x, settings.offset_y)
	if not bool(_renderer.call("set_visual_delta", Vector2(options.offset_x, options.offset_y))):
		problem = str(_renderer.get("problem"))
		if problem.is_empty(): problem = "현재 영역에 표시 보정을 적용할 수 없습니다."
		return false
	if OPTIONS.write(options) != OK:
		_renderer.call("set_visual_delta", previous_delta)
		problem = "표시 보정을 저장하지 못했습니다. 이전 보정을 유지합니다."
		return false
	settings = options
	return true

func metrics() -> Dictionary:
	return _renderer.call("frame_metrics") if active and is_instance_valid(_renderer) else {}

func _renderer_problem(message: String, sender: FieldRenderer) -> void:
	_deferred_return.call_deferred(message, sender.get_instance_id())

func _deferred_return(message: String, sender_id: int) -> void:
	var world: Node = _world()
	if active and is_instance_valid(_renderer) and sender_id == _renderer.get_instance_id() and is_instance_valid(world): world.call("close_current523_aden_play", false, message)

func _build_notice(world: Node) -> void:
	_notice = CanvasLayer.new()
	_notice.name = "Current523AdenPlayNotice"
	_notice.layer = 18
	world.add_child(_notice)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 106)
	_notice.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var label: Label = UI.label("아덴 M 타일 실험 플레이\n통행: 기존 TWILIGHT 자체 설정 · M 좌표/발/충돌 미확정", 14, UI.TEXT)
	row.add_child(label)
	var button: Button = UI.button("기존 지도로 복귀", _return_pressed, Vector2(150, 42))
	button.name = "ReturnFromAdenPlayButton"
	row.add_child(button)

func _return_pressed() -> void:
	var world: Node = _world()
	if is_instance_valid(world): world.call("close_current523_aden_play")
