extends SceneTree

const STAGE = preload("res://scripts/ui/card_reveal_stage.gd")
const PROFILES = preload("res://scripts/ui/card_reveal_profiles.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CARD_TIMELINE_FAIL: "+label)

func _stage(grade: String, success: bool = true) -> Control:
	var stage: Control = STAGE.new()
	root.add_child(stage)
	var cards: Array[Dictionary] = [{"name":"연출 검수", "grade":grade, "id":"unchanged-result"}]
	var textures: Array[Texture2D] = []
	stage.present(cards,textures,"변신",true,success)
	stage.set_process(false)
	return stage

func _touch(button: Control) -> void:
	var at: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = false
	root.push_input(event,true)
	await process_frame

func _run() -> void:
	# The final Unique primary pulse is 4.278 s. Starting promotion at 4.15 s
	# must not reset the first discharge's clock before that pulse is rendered.
	var stage: Control = _stage("유일")
	stage.seek(4.278)
	var card: Control = stage.cards[0]
	_check(is_equal_approx(card.surface_fx.elapsed,0.728),"unique primary clock survives overlapping promotion")
	_check(PROFILES.pulse("유일",card.surface_fx.elapsed) > 0.4,"unique sixth primary pulse remains visible")
	var promotion: Control = card.get_node_or_null("CardSurfaceClip/PromotionLightningInsideCard")
	_check(promotion != null,"promotion has an independent clipped surface pass")
	if promotion != null:
		_check(is_equal_approx(promotion.elapsed,0.128),"promotion has its own clock")
		_check(promotion.get_parent() == card.surface_fx.get_parent() and promotion.get_parent().clip_contents,"both discharges stay within the same card clip")
		_check(promotion.size == card.surface_fx.size,"promotion follows card bounds")
	var original: Array = stage.results.duplicate(true)
	stage.skip_to_result()
	_check(stage.results == original,"skip keeps committed result")
	_check(PROFILES.pulse("유일",card.surface_fx.elapsed) == 0.0,"skip settles primary")
	if promotion != null:
		_check(PROFILES.pulse("유일",promotion.elapsed) == 0.0,"skip settles promotion")
	stage.close_reveal()
	await process_frame
	# A low-tier reel is 0.65 s, so its promotion is at 1.8 s, not 4.15 s.
	for grade: String in ["고급","희귀","영웅","전설","신화","유일"]:
		stage = _stage(grade)
		card = stage.cards[0]
		var at: float = card.open_at+card.reel_seconds+0.5
		stage.seek(at-0.01)
		stage._process(0.02)
		_check(stage.sound_played.has("promotion"),grade+" upgrade sound follows actual reveal clock")
		_check(stage.sound_player.stream == STAGE.UPGRADE,grade+" upgrade cue uses correct sound")
		stage.close_reveal()
		await process_frame
	stage = _stage("유일",false)
	stage.seek(4.278)
	card = stage.cards[0]
	promotion = card.get_node_or_null("CardSurfaceClip/PromotionLightningInsideCard")
	if promotion != null:
		_check(promotion.elapsed < 0.0,"ordinary result has no promotion discharge")
	stage.seek(4.14)
	stage._process(0.02)
	_check(not stage.sound_played.has("promotion"),"ordinary result has no success sound")
	stage.close_reveal()
	await process_frame
	# The grade signal precedes the visual result by two full seconds.
	for grade: String in ["일반","고급","희귀","영웅","전설","신화","유일"]:
		stage = _stage(grade)
		card = stage.cards[0]
		var signal_at: float = card.lightning_at()
		_check(is_equal_approx(card.reveal_at()-signal_at,2.0),grade+" confirms two seconds after lightning")
		stage.seek(signal_at+0.028)
		_check(PROFILES.pulse(grade,card.surface_fx.elapsed) > 0.0 and not card.name_label.visible,grade+" lightning fires before result")
		stage.seek(signal_at+1.98)
		_check(card.face.elapsed < card.face.duration and not card.name_label.visible and not card.grade_label.visible,grade+" remains unresolved throughout anticipation")
		_check(card.aura.elapsed < 0.0 and stage.result_note.text == "결과를 확인하고 있습니다.",grade+" result aura and success text wait for confirmation")
		stage.seek(signal_at+2.01)
		_check(card.face.elapsed >= card.face.duration and card.name_label.visible and card.grade_label.visible,grade+" confirms artwork and labels together")
		_check(card.aura.elapsed >= 0.0 and stage.result_note.text == "승급 성공",grade+" confirmation starts result aura and success text")
		_check(stage.duration-card.reveal_at() >= 3.0,grade+" retains time to inspect result")
		stage.close_reveal()
		await process_frame
	stage = STAGE.new()
	root.add_child(stage)
	var pack: Array[Dictionary] = []
	for index: int in range(11):
		pack.append({"name":"결과 "+str(index),"grade":"유일","id":str(index)})
	var candidate_textures: Array[Texture2D] = []
	stage.present(pack,candidate_textures,"변신")
	stage.set_process(false)
	stage.seek(stage.cards[10].reveal_at()-0.02)
	_check(stage.cards[0].name_label.visible and not stage.cards[10].name_label.visible,"eleven-card sequence coexists with pending result")
	_check(stage.result_note.text == "결과를 확인하고 있습니다.","pack completion waits for last delayed card")
	stage.seek(stage.cards[10].reveal_at()+0.02)
	_check(stage.result_note.text == "카드를 획득했습니다","pack confirms after last delayed card")
	stage.close_reveal()
	await process_frame
	# Real ScreenTouch events, with mouse emulation disabled by project.godot.
	stage = _stage("영웅")
	await process_frame
	_check(not Input.emulate_mouse_from_touch,"test uses native touch, not mouse emulation")
	await _touch(stage.pause_button)
	_check(not stage.playing,"native touch pauses")
	await _touch(stage.pause_button)
	_check(stage.playing,"native touch resumes")
	await _touch(stage.board.get_node("SkipReveal"))
	_check(stage.clock == stage.duration and not stage.playing,"native touch skips to stable result")
	var closed: Array[int] = [0]
	stage.finished.connect(func() -> void: closed[0] += 1)
	await _touch(stage.board.get_node("ConfirmReveal"))
	_check(closed[0] == 1,"native touch confirms exactly once")
	if is_instance_valid(stage):
		stage.close_reveal()
	await process_frame
	stage = _stage("희귀")
	await process_frame
	for expected: bool in [false,true]:
		var at: Vector2 = stage.pause_button.get_global_transform_with_canvas()*(stage.pause_button.size*0.5)
		for down: bool in [true,false]:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.position = at
			mouse.pressed = down
			root.push_input(mouse,true)
			await process_frame
		_check(stage.playing == expected,"mouse transport remains usable")
	closed = [0]
	stage.finished.connect(func() -> void: closed[0] += 1)
	stage.pause_button.grab_focus()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	await process_frame
	_check(closed[0] == 1,"Escape from a focused transport closes exactly once")
	if is_instance_valid(stage):
		stage.close_reveal()
	await process_frame
	print("CARD_TIMELINE_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
