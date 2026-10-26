extends Control

# Presentation only. Awards are committed and saved before this screen opens.
# Closing, skipping, pausing or replaying cannot grant or roll a card.
signal finished
const CARD = preload("res://scripts/ui/card_reveal_card.gd")
const PROFILES = preload("res://scripts/ui/card_reveal_profiles.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const NativeTouchButton=preload("res://scripts/ui/native_touch_button.gd")
const BACKGROUND = preload("res://assets/card_reveal/authored_background.webp")
const IMPACT = preload("res://assets/card_reveal/impact.wav")
const UPGRADE = preload("res://assets/card_reveal/upgrade.wav")
@export var showcase_on_ready: bool = false
var cards: Array[Control] = []
var results: Array[Dictionary] = []
var category: String = "변신"
var fusion: bool = false
var upgrade: bool = false
var showcase: bool = false
var clock: float = 0.0
var duration: float = 8.0
var playing: bool = true
var reduced_motion: bool = false
var detail_scale: float = 1.0
var intensity_scale: float = 1.0
var board: Control
var title_label: Label
var result_note: Label
var pause_button: Button
var sound_player: AudioStreamPlayer
var sound_played: Dictionary = {}
var silent: bool = false
var closing: bool = false
var emitted: bool = false

func _ready() -> void:
	name = "CardRevealStage"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	theme = UI.make_theme()
	board = Control.new()
	board.name = "RevealComposition"
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	title_label = UI.label("등급별 카드 공개",32,UI.GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(title_label)
	result_note = UI.label("",18,UI.TEXT)
	result_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.add_child(result_note)
	pause_button = UI.button("일시정지",func() -> void: playing = not playing; _refresh_transport(),Vector2(144,46))
	pause_button.name = "PauseReveal"
	pause_button.set_script(NativeTouchButton)
	board.add_child(pause_button)
	var skip := UI.button("모두 확인",skip_to_result,Vector2(144,46))
	skip.name = "SkipReveal"
	skip.set_script(NativeTouchButton)
	board.add_child(skip)
	var confirm := UI.button("확인",close_reveal,Vector2(144,46))
	confirm.name = "ConfirmReveal"
	confirm.set_script(NativeTouchButton)
	board.add_child(confirm)
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -13
	add_child(sound_player)
	resized.connect(_fit)
	_fit()
	if showcase_on_ready:
		present_showcase()

func present(value: Array[Dictionary], candidate_textures: Array[Texture2D], card_category: String, is_fusion: bool = false, succeeded: bool = false) -> void:
	results = value.duplicate(true)
	category = card_category
	fusion = is_fusion
	upgrade = succeeded
	clock = 0.0
	playing = true
	sound_played.clear()
	for card: Control in cards:
		card.queue_free()
	cards.clear()
	for i: int in range(results.size()):
		var card: Control = CARD.new()
		card.reduced_motion = reduced_motion
		card.detail_scale = detail_scale
		card.intensity_scale = intensity_scale
		card.show_grade_heading = showcase
		var grade: String = str(results[i].get("grade","일반"))
		var high: bool = int(PROFILES.profile(grade).get("tier",0)) >= 1
		card.open_at = 0.65 if showcase or fusion or results.size() == 1 else 0.45+i*0.16
		card.reel_seconds = 3.0 if high else 0.65
		board.add_child(card)
		card.configure(results[i],candidate_textures,category)
		cards.append(card)
	duration = (6.8 if fusion else 8.0)+CARD.CONFIRM_DELAY_SECONDS-CARD.LIGHTNING_EARLY_SECONDS
	title_label.text = "5개 등급 연출 비교" if showcase else category+(" 합성 결과" if fusion else " 뽑기 결과")
	_fit()
	seek(0.0)

func present_showcase() -> void:
	showcase = true
	var values: Array[Dictionary] = []
	for grade: String in PROFILES.SHOWCASE:
		values.append({"name":"황혼의 기사", "grade":grade})
	var textures: Array[Texture2D] = []
	for i: int in range(8):
		textures.append(CARD.authored_art(i))
	present(values,textures,"변신")

func layout_for(design: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var portrait: bool = design.y > design.x
	for i: int in range(results.size()):
		if showcase:
			var c: Vector2 = Vector2(235+(i%2)*430,370+(i/2)*380) if portrait else Vector2(154+i*243,345)
			if portrait and i == 4:
				c.x = 450
			var s := Vector2(180,225) if portrait else Vector2(160,200)
			rects.append(Rect2(c-s*0.5,s))
		elif results.size() <= 2:
			var c := Vector2(design.x*0.5,design.y*0.48)
			if results.size() == 2:
				c.x += (-1 if i == 0 else 1)*design.x*0.2
			var s := Vector2(220,275) if portrait else Vector2(205,256)
			rects.append(Rect2(c-s*0.5,s))
		elif portrait:
			var s := Vector2(160,200)
			var c := Vector2(160+(i%3)*290,300+(i/3)*270)
			rects.append(Rect2(c-s*0.5,s))
		elif category == "마법인형":
			var s := Vector2(112,140)
			var c := Vector2(130+(i%6)*202,215+(i/6)*240)
			rects.append(Rect2(c-s*0.5,s))
		else:
			var s := Vector2(128,160)
			var c := Vector2(105+(i%5)*203,210+(i/5)*245)
			if i == 10:
				c = Vector2(1140,335)
			if category == "성물":
				s = Vector2(116,145)
				c.y += 6
			rects.append(Rect2(c-s*0.5,s))
	return rects

func _fit() -> void:
	if board == null:
		return
	var design := Vector2(900,1480) if size.y > size.x*1.1 else Vector2(1280,720)
	var factor: float = minf(size.x/design.x,size.y/design.y)
	board.size = design
	board.scale = Vector2(factor,factor)
	board.position = (size-design*factor)*0.5
	title_label.position = Vector2(20,64 if design.x > design.y else 80)
	title_label.size = Vector2(design.x-40,50)
	var rects: Array[Rect2] = layout_for(design)
	for i: int in range(cards.size()):
		cards[i].position = rects[i].position
		cards[i].size = rects[i].size
	var roomy_note: bool = showcase or design.y > design.x
	result_note.position = Vector2(30,design.y-(160 if roomy_note else 125))
	result_note.size = Vector2(design.x-60,54 if roomy_note else 32)
	for i: int in range(3):
		var button: Control = board.get_node(["PauseReveal","SkipReveal","ConfirmReveal"][i])
		button.position = Vector2(design.x*0.5-232+i*160,design.y-82)
		button.size = Vector2(144,46)
	queue_redraw()

func seek(value: float) -> void:
	clock = clampf(value,0,duration)
	for card: Control in cards:
		card.seek(clock,fusion and upgrade)
	var complete: bool = cards.all(func(card: Control) -> bool: return clock >= card.reveal_at())
	if showcase:
		result_note.text = "청색 · 적색 · 보라 · 금빛 · 에메랄드\n연출 비교 전용 · 카드 보상 없음"
	elif complete:
		result_note.text = "승급 성공" if fusion and upgrade else "합성 결과" if fusion else "카드를 획득했습니다"
		if results.size() > 1 and bool(results.back().get("pity_reward",false)):
			result_note.text += " · 별도 카드: 누적 실패 보상"
	else:
		result_note.text = "결과를 확인하고 있습니다."
	if clock >= duration:
		playing = false
	_refresh_transport()
	queue_redraw()

func _process(delta: float) -> void:
	if playing and not closing:
		var previous: float = clock
		seek(clock+minf(delta,0.08))
		if not silent:
			for i: int in range(cards.size()):
				var at: float = cards[i].lightning_at()
				if previous < at and clock >= at and not sound_played.has(i):
					sound_played[i] = true
					sound_player.stream = IMPACT
					sound_player.play()
			if fusion and upgrade and not cards.is_empty():
				var promotion_at: float = cards[0].promotion_at()
				if previous < promotion_at and clock >= promotion_at and not sound_played.has("promotion"):
					sound_played["promotion"] = true
					sound_player.stream = UPGRADE
					sound_player.play()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("060b13"))
	if BACKGROUND != null:
		draw_texture_rect(BACKGROUND,Rect2(Vector2.ZERO,size),false,Color(0.38,0.45,0.54))
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.01,0.025,0.05,0.4))
	# Illumination is separate from smoke, card movement and surface discharges.
	if not reduced_motion:
		for card: Control in cards:
			var elapsed: float = clock-card.lightning_at()
			var power: float = PROFILES.pulse(card.grade,elapsed)
			if fusion and upgrade:
				power += PROFILES.pulse(card.grade,clock-card.promotion_at())
			if power > 0.03:
				draw_rect(Rect2(Vector2.ZERO,size),Color(PROFILES.color(card.grade),minf(0.055,power*0.023*intensity_scale)))

func _refresh_transport() -> void:
	for card: Control in cards:
		card.set_sequence_playing(playing or clock>=duration)
	if pause_button != null:
		pause_button.text = "일시정지" if playing else "재생"
		pause_button.disabled = clock >= duration

func skip_to_result() -> void:
	playing = false
	sound_player.stop()
	seek(duration)

func close_reveal() -> void:
	if closing:
		return
	closing = true
	playing = false
	sound_player.stop()
	if not emitted:
		emitted = true
		finished.emit()
	queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_reveal()
		accept_event()
	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	# A transport Button may own keyboard focus after it is clicked.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_reveal()
		get_viewport().set_input_as_handled()
