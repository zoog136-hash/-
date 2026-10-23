extends Control

# Presentation of an already committed option-awakening result only.
# No RNG, ownership, material consumption, save, or transaction callbacks.
# Central card / surrounding seal / gold rays / embers are reference-informed;
# all timing, geometry, palette and sounds are authored TWILIGHT choices.
signal finished
const UI = preload("res://scripts/ui/renewal_theme.gd")
const BORDER = preload("res://scripts/ui/option_awakening_border.gd")
const TOUCH_BUTTON = preload("res://scripts/ui/native_touch_button.gd")
const BACKGROUND = preload("res://assets/card_reveal/authored_background.webp")
const SUCCESS_SOUND = preload("res://assets/card_reveal/upgrade.wav")
const GOLD = Color("f5cf7b")
const PALE_GOLD = Color("fff0c6")
const REVEAL_AT: float = 1.35
const SETTLE_AT: float = 3.6
const MAX_EMBERS: int = 28
var record: Dictionary = {}
var result: Dictionary = {}
var category: String = "변신"
var succeeded: bool = false
var reduced_motion: bool = false
var low_detail: bool = false
var intensity: float = 0.85
var silent: bool = false
var clock: float = 0.0
var started: bool = false
var playing: bool = false
var revealed: bool = false
var closed: bool = false
var board: Control
var controls_layer: Control
var heading: Label
var context_label: Label
var card_label: Label
var grade_label: Label
var result_label: Label
var note: Label
var skip_button: Button
var confirm_button: Button
var border: Control
var sound: AudioStreamPlayer
var texture: Texture2D
var design: Vector2 = Vector2(1100, 760)
var center: Vector2 = Vector2(550, 318)
var card_rect: Rect2
var design_offset: Vector2 = Vector2.ZERO
var design_scale: float = 1.0

func _ready() -> void:
	name = "OptionAwakeningReveal"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	theme = UI.make_theme()
	board = Control.new()
	board.name = "OptionAwakeningComposition"
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	heading = _label("옵션 각성", 30, UI.GOLD)
	context_label = _label("", 16, UI.MUTED)
	card_label = _label("", 23, UI.TEXT)
	card_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	grade_label = _label("", 16, UI.MUTED)
	result_label = _label("", 33, PALE_GOLD)
	note = _label("", 17, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.max_lines_visible = 3
	border = BORDER.new()
	board.add_child(border)
	border.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Keep real touch targets outside the scaled art board. On a 412px-wide
	# portrait display these remain 48px high, rather than shrinking with art.
	controls_layer = Control.new()
	controls_layer.name = "OptionAwakeningActions"
	controls_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(controls_layer)
	skip_button = _action_button("결과 바로 보기", skip_to_result)
	skip_button.name = "SkipOptionAwakening"
	controls_layer.add_child(skip_button)
	confirm_button = _action_button("확인", close_reveal)
	confirm_button.name = "ConfirmOptionAwakening"
	confirm_button.disabled = true
	controls_layer.add_child(confirm_button)
	sound = AudioStreamPlayer.new()
	sound.stream = SUCCESS_SOUND
	sound.volume_db = -15
	add_child(sound)
	resized.connect(_fit)
	_fit()
	grab_focus()

func _label(value: String, font_size: int, tint: Color) -> Label:
	var label: Label = UI.label(value, font_size, tint)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(label)
	return label

func _action_button(value: String, action: Callable) -> Button:
	var button: Button = TOUCH_BUTTON.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(action)
	return button

func present(card: Dictionary, committed_result: Dictionary, settings: Dictionary = {}) -> void:
	# Each modal displays one immutable transaction. Re-entrant calls cannot
	# restart a reveal or replace an outcome while it is being confirmed.
	if started or closed:
		return
	if not is_node_ready():
		call_deferred("present", card.duplicate(true), committed_result.duplicate(true), settings.duplicate(true))
		return
	if not committed_result.has("success") or typeof(committed_result["success"]) != TYPE_BOOL:
		push_warning("Option awakening reveal requires a committed boolean success result.")
		return
	started = true
	record = card.duplicate(true)
	result = committed_result.duplicate(true)
	category = str(result.get("category", record.get("category", "변신")))
	succeeded = bool(result["success"])
	reduced_motion = bool(settings.get("reduced_motion", false))
	low_detail = str(settings.get("effect_detail", "full")) == "low"
	intensity = clampf(float(settings.get("impact_intensity", 0.85)), 0.0, 1.0)
	var path: String = str(record.get("image_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	card_label.text = str(record.get("name", "카드"))
	grade_label.text = str(record.get("grade", ""))
	grade_label.add_theme_color_override("font_color", UI.grade(grade_label.text))
	context_label.text = category + " · 옵션 각성"
	result_label.text = "각성 결과 확인 중"
	note.text = "카드에 모인 힘을 확인합니다."
	border.configure(grade_label.text, false, settings)
	clock = 0.0
	playing = true
	_fit()
	queue_redraw()

func _fit() -> void:
	if board == null:
		return
	var portrait: bool = size.y > size.x * 1.1
	design = Vector2(480, 900) if portrait else Vector2(1100, 760)
	center = Vector2(design.x * 0.5, 342 if portrait else 318)
	design_scale = maxf(0.01, minf(size.x / design.x, size.y / design.y))
	design_offset = (size - design * design_scale) * 0.5
	board.size = design
	board.scale = Vector2.ONE * design_scale
	board.position = design_offset
	card_rect = Rect2(center - Vector2(86, 117), Vector2(172, 234))
	heading.position = Vector2(20, 27)
	heading.size = Vector2(design.x - 40, 48)
	context_label.position = Vector2(20, 79)
	context_label.size = Vector2(design.x - 40, 30)
	card_label.position = Vector2(40, center.y + 143)
	card_label.size = Vector2(design.x - 80, 38)
	grade_label.position = Vector2(40, center.y + 180)
	grade_label.size = Vector2(design.x - 80, 25)
	result_label.position = Vector2(30, 580 if portrait else 538)
	result_label.size = Vector2(design.x - 60, 48)
	note.position = Vector2(30 if portrait else 65, 642 if portrait else 592)
	note.size = Vector2(design.x - (60 if portrait else 130), 100 if portrait else 70)
	border.position = card_rect.position
	border.size = card_rect.size
	controls_layer.size = size
	var gap: float = 16.0
	var button_width: float = minf(204.0, maxf(80.0, (size.x - 32.0 - gap) * 0.5))
	var row_width: float = button_width * 2.0 + gap
	var row_left: float = (size.x - row_width) * 0.5
	var row_top: float = maxf(0.0, size.y - 68.0)
	skip_button.position = Vector2(row_left, row_top)
	confirm_button.position = Vector2(row_left + button_width + gap, row_top)
	skip_button.size = Vector2(button_width, 48)
	confirm_button.size = Vector2(button_width, 48)
	queue_redraw()

func reveal_time() -> float:
	return 0.10 if reduced_motion else REVEAL_AT

func _show_result(play_sound: bool = true) -> void:
	if revealed or not started:
		return
	revealed = true
	result_label.text = "각성 성공" if succeeded else "각성 실패"
	result_label.add_theme_color_override("font_color", PALE_GOLD if succeeded else UI.TEXT)
	var message: String = str(result.get("message", ""))
	if message.is_empty():
		message = "카드의 각성 옵션이 활성화되었습니다." if succeeded else "대상 카드는 유지됩니다."
	var bonus_lines: PackedStringArray = PackedStringArray()
	var raw_lines: Variant = result.get("bonus_lines", [])
	var remaining: int = 0
	if raw_lines is Array or raw_lines is PackedStringArray:
		for line: Variant in raw_lines:
			if bonus_lines.size() >= 2:
				break
			bonus_lines.append(str(line))
		remaining = raw_lines.size() - bonus_lines.size()
	var preview: String = " · ".join(bonus_lines)
	if remaining > 0:
		preview += " · 외 %d개" % remaining
	note.text = message + ("\n" + preview if not preview.is_empty() else "")
	border.configure(str(record.get("grade", "영웅")), succeeded, {"reduced_motion":reduced_motion, "effect_detail":"low" if low_detail else "full", "impact_intensity":intensity})
	confirm_button.disabled = false
	skip_button.disabled = true
	if succeeded and play_sound and not silent and intensity > 0.0:
		sound.play()
	queue_redraw()

func seek(time_value: float) -> void:
	if not started or closed:
		return
	clock = clampf(time_value, 0.0, SETTLE_AT)
	if clock >= reveal_time():
		_show_result(false)
	if clock >= SETTLE_AT:
		playing = false
	queue_redraw()

func skip_to_result() -> void:
	if not started or closed:
		return
	seek(SETTLE_AT)

func close_reveal() -> void:
	if closed or not started:
		return
	if not revealed:
		skip_to_result()
		return
	closed = true
	playing = false
	set_process(false)
	sound.stop()
	# The owner frees the modal layer; emitting twice would risk closing a new UI.
	finished.emit()

func _process(delta: float) -> void:
	if not playing or closed:
		return
	clock = minf(SETTLE_AT, clock + minf(maxf(delta, 0.0), 0.1))
	if clock >= reveal_time():
		_show_result()
	if clock >= SETTLE_AT:
		playing = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	_handle_key(event)

func _unhandled_key_input(event: InputEvent) -> void:
	_handle_key(event)

func _handle_key(event: InputEvent) -> void:
	if closed or not started or not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		if revealed:
			close_reveal()
		else:
			skip_to_result()
		accept_event()

func _glow(point: Vector2, radius: float, tint: Color, alpha: float) -> void:
	var layers: int = 4 if low_detail else 7
	for index: int in range(layers, 0, -1):
		var ratio: float = float(index) / float(layers)
		draw_circle(point, radius * ratio, Color(tint, alpha * (1.0 - ratio * 0.75) / float(layers)))

func _stroke(start: Vector2, end: Vector2, tint: Color, alpha: float, width: float = 1.0) -> void:
	if not low_detail:
		draw_line(start, end, Color(tint, alpha * 0.10), width * 5.0, true)
	draw_line(start, end, Color(tint, alpha), width, true)

func _draw() -> void:
	if board == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("080b12"))
	# Existing TWILIGHT-generated background, never a source-game screenshot.
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, size), false, Color(0.35, 0.31, 0.26, 0.40))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.026, 0.66))
	draw_set_transform(design_offset, 0, Vector2.ONE * design_scale)
	var age: float = maxf(0.0, clock - reveal_time())
	var charge: float = clampf(clock / reveal_time(), 0.0, 1.0)
	var is_success: bool = revealed and succeeded
	var motion: float = 0.0 if reduced_motion else clock
	var tint: Color = GOLD if not revealed or succeeded else Color("8a8796")
	var strength: float = intensity * (0.30 + charge * 0.40 if not revealed else 0.52 if succeeded else 0.16)
	var flash: float = exp(-age * 3.7) * intensity * (0.16 if reduced_motion else 0.75) if is_success else 0.0
	_glow(center, 220, tint, strength * 0.30 + flash * 0.24)
	draw_rect(Rect2(28, 16, design.x - 56, design.y - 32), Color(UI.BRONZE, 0.55), false, 1.0)
	if is_success:
		_draw_rays(age, flash)
	_draw_seal(motion, tint, strength)
	# The same intact card remains visible for both outcomes.
	draw_rect(card_rect.grow(4), Color("07090e"))
	draw_rect(card_rect, Color("12141b"))
	draw_rect(card_rect, Color(UI.BRONZE, 0.85), false, 2.0)
	if texture != null:
		var extent: Vector2 = texture.get_size()
		var available: Vector2 = card_rect.size - Vector2(18, 18)
		var fitted: Vector2 = extent * minf(available.x / maxf(extent.x, 1), available.y / maxf(extent.y, 1))
		draw_texture_rect(texture, Rect2(center - fitted * 0.5, fitted), false)
	else:
		# A missing image is visibly a neutral placeholder, not invented card art.
		var diamond := PackedVector2Array([center + Vector2(0,-40), center + Vector2(30,0), center + Vector2(0,40), center + Vector2(-30,0), center + Vector2(0,-40)])
		draw_polyline(diamond, UI.BRONZE, 2.0, true)
	if is_success:
		_glow(center, 90, PALE_GOLD, flash * 0.22)
		_draw_embers(age)
	elif not revealed and not reduced_motion:
		for index: int in range(6 if low_detail else 12):
			var phase: float = fposmod(charge + float(index) * 0.618, 1.0)
			var angle: float = float(index) * 2.399 + motion * 0.20
			var point: Vector2 = center + Vector2.from_angle(angle) * lerpf(198, 100, phase)
			draw_circle(point, 1.4, Color(GOLD, sin(phase * PI) * intensity * 0.75))
	draw_set_transform(Vector2.ZERO)

func _draw_seal(motion: float, tint: Color, strength: float) -> void:
	var orbit: float = motion * 0.16
	for radius: float in [175.0, 192.0, 199.0]:
		draw_arc(center, radius, 0, TAU, 48 if low_detail else 96, Color(tint, strength * (0.55 if radius == 192.0 else 0.28)), 1.1, true)
	for index: int in range(24):
		var angle: float = float(index) * TAU / 24.0 + orbit
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var point: Vector2 = center + direction * 184.0
		_stroke(point - direction * 4, point + direction * 4, tint, strength * 0.75)
		if index % 2 == 0:
			_stroke(point - tangent * 3, point + tangent * 3 + direction * 3, tint, strength * 0.65)
		if index % 3 == 0:
			_stroke(point + direction * 3, point + direction * 6 + tangent * 3, tint, strength * 0.65)

func _draw_rays(age: float, flash: float) -> void:
	var amount: float = (0.08 + exp(-age * 1.8) * 0.33) * intensity
	var count: int = 8 if low_detail else 16
	if reduced_motion:
		count = 6
		amount *= 0.30
	for index: int in range(count):
		var angle: float = float(index) * TAU / float(count) + 0.11
		var direction := Vector2.from_angle(angle)
		var reach: float = 225.0 + sin(float(index) * 9.3) * 28.0 + (0.0 if reduced_motion else minf(age, 0.8) * 38.0)
		_stroke(center + direction * 125, center + direction * reach, GOLD, amount, 2.0)
	_stroke(center + Vector2(-240, 0), center + Vector2(240, 0), PALE_GOLD, flash * 0.55, 1.5)

func _draw_embers(age: float) -> void:
	if reduced_motion or age > 2.25:
		return
	var count: int = 10 if low_detail else MAX_EMBERS
	for index: int in range(count):
		var angle: float = float(index) * 2.39996
		var speed: float = 44.0 + fposmod(float(index) * 47.3, 88.0)
		var point: Vector2 = center + Vector2.from_angle(angle) * (95.0 + age * speed) + Vector2(0, -age * age * 24)
		var alpha: float = pow(maxf(0.0, 1.0 - age / 2.25), 1.6) * intensity
		if not low_detail:
			_glow(point, 5.5, GOLD, alpha * 0.26)
		draw_circle(point, 1.0 + fposmod(float(index) * 0.7, 1.2), Color(PALE_GOLD, alpha * 0.85))
