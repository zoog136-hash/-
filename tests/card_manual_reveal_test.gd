extends SceneTree

const STAGE = preload("res://scripts/ui/card_reveal_stage.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("CARD_MANUAL_REVEAL FAIL: " + detail)

func _touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func _run() -> void:
	root.size = Vector2i(1280,720)
	Input.emulate_mouse_from_touch = false
	var stage = STAGE.new()
	root.add_child(stage)
	await process_frame
	stage.silent = true
	var records: Array[Dictionary] = [
		{"name":"첫 카드", "grade":"희귀"},
		{"name":"두 번째 카드", "grade":"영웅"},
		{"name":"세 번째 카드", "grade":"일반"}
	]
	var textures: Array[Texture2D] = []
	stage.present(records,textures,"변신")
	stage.set_process(false)
	await process_frame
	# Neither normal processing nor seeking past the old autoplay end opens one.
	stage._process(60.0)
	stage.seek(60.0)
	for card: Control in stage.cards:
		check(card.waiting_for_press and card.face.elapsed < 0, "unpressed card stays face down")
		check(not card.name_label.visible and not card.grade_label.visible, "unpressed result is concealed")
	check(stage.sound_played.is_empty(), "no anticipatory sound before touch")
	check((stage.board.get_node("ConfirmReveal") as Button).disabled, "confirmation waits for explicit reveal")
	var first: Control = stage.cards[0]
	var point: Vector2 = first.get_global_transform_with_canvas() * (first.size * .5)
	_touch(point,true)
	_touch(point,false,true)
	await process_frame
	check(first.waiting_for_press, "canceled touch does not reveal")
	_touch(point,true)
	_touch(point,false)
	await process_frame
	check(not first.waiting_for_press, "native touch reveals the touched card")
	check(stage.cards[1].waiting_for_press and stage.cards[2].waiting_for_press, "other cards keep their backs")
	var started_at: float = first.open_at
	stage._reveal_card(0)
	check(is_equal_approx(first.open_at,started_at), "duplicate input cannot restart the reveal")
	stage.seek(first.lightning_at()+1.99)
	check(not first.name_label.visible, "result waits two seconds after lightning")
	stage.seek(first.reveal_at()+.01)
	check(first.name_label.visible, "selected card confirms after lightning hold")
	check(stage.cards[1].waiting_for_press, "elapsed animation does not reveal other cards")
	var second: Control = stage.cards[1]
	point = second.get_global_transform_with_canvas() * (second.size * .5)
	_mouse(point,true)
	_mouse(point,false)
	await process_frame
	check(not second.waiting_for_press and stage.cards[2].waiting_for_press, "mouse reveals only its card")
	stage._reveal_all_or_skip()
	check(stage.cards.all(func(card: Control) -> bool: return not card.waiting_for_press), "explicit reveal all starts remaining cards")
	stage.seek(stage.duration)
	check(stage._all_revealed(), "all selected cards can complete")
	check(not (stage.board.get_node("ConfirmReveal") as Button).disabled, "confirmation becomes available")
	check(stage.results == records, "presentation never changes committed awards")
	stage.queue_free()
	await process_frame
	var fusion = STAGE.new()
	root.add_child(fusion)
	await process_frame
	fusion.silent = true
	fusion.present(records.slice(0,1),textures,"성물",true,true)
	fusion.set_process(false)
	check(not fusion.manual_reveal and not fusion.cards[0].waiting_for_press, "fusion retains its own automatic reveal")
	fusion.skip_to_result()
	check(fusion._all_revealed(), "fusion skip still completes")
	fusion.queue_free()
	await process_frame
	print("CARD_MANUAL_REVEAL_%s checks=%d" % ["OK" if failures == 0 else "FAILED",checks])
	quit(0 if failures == 0 else 1)
