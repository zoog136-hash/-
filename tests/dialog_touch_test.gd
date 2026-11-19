extends SceneTree
## Window-based dialogs (ConfirmationDialog / AcceptDialog and the controls
## inside them) on Android touch: the project runs with
## emulate_mouse_from_touch off. Real InputEventScreenTouch through Input on
## the actual Main HUD at phone resolution (2408x1080): OK and 취소 must each
## fire exactly once, and a control inside the dialog must take a tap.
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("DIALOG_TOUCH_FAIL: " + label)

func _initialize() -> void: call_deferred("run")

func frames(count: int = 3) -> void:
	for frame: int in count: await process_frame

## Window coordinates of a control, also inside an embedded dialog window.
func window_point(control: Control) -> Vector2:
	var local: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var owner: Window = control.get_window()
	if owner != root: local += Vector2(owner.position)
	return root.get_final_transform() * local

func touch_at(at: Vector2) -> void:
	var down := InputEventScreenTouch.new(); down.index = 0; down.pressed = true; down.position = at
	Input.parse_input_event(down)
	await frames(2)
	var up := InputEventScreenTouch.new(); up.index = 0; up.pressed = false; up.position = at
	Input.parse_input_event(up)
	await frames(3)

func run() -> void:
	root.size = Vector2i(2408, 1080); DisplayServer.window_set_size(root.size)
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "actual Main class confirmation")
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.save_timer = -100000.0
	await frames(6)
	var host: Node = world.hud
	# ConfirmationDialog as the game builds them (TJ, 계열 전환, 축복 주문서, 패키지 선택).
	var counts: Dictionary = {"ok":0,"cancel":0,"inner":0,"accept":0}
	for round: String in ["ok","cancel"]:
		var dialog := ConfirmationDialog.new()
		dialog.title = "확인"; dialog.dialog_text = "터치 확인"; dialog.ok_button_text = "확인"; dialog.cancel_button_text = "취소"
		var inner := Button.new(); inner.text = "안쪽 버튼"; inner.custom_minimum_size = Vector2(160, 44)
		inner.pressed.connect(func() -> void: counts.inner += 1)
		dialog.add_child(inner)
		dialog.confirmed.connect(func() -> void: counts.ok += 1)
		dialog.canceled.connect(func() -> void: counts.cancel += 1)
		host.add_child(dialog)
		dialog.popup_centered(Vector2i(520, 260))
		await frames(4)
		if round == "ok":
			await touch_at(window_point(inner))
			check(counts.inner == 1, "a button inside the dialog takes one tap (got %d)" % counts.inner)
		var target: Button = dialog.get_ok_button() if round == "ok" else dialog.get_cancel_button()
		await touch_at(window_point(target))
		check(not dialog.visible, "the %s tap closes the dialog" % round)
		dialog.queue_free()
		await frames(2)
	check(counts.ok == 1 and counts.cancel == 1, "확인 and 취소 each fire once (ok %d, cancel %d)" % [counts.ok, counts.cancel])
	var notice := AcceptDialog.new(); notice.title = "안내"; notice.dialog_text = "확인 버튼"
	notice.confirmed.connect(func() -> void: counts.accept += 1)
	host.add_child(notice); notice.popup_centered(Vector2i(480, 200))
	await frames(4)
	await touch_at(window_point(notice.get_ok_button()))
	check(counts.accept == 1 and not notice.visible, "AcceptDialog 확인 fires once (got %d)" % counts.accept)
	notice.queue_free()
	await frames(2)
	# A dropdown inside a dialog (축복 주문서 속성, 패키지 선택): its list is
	# another embedded window; popup_touch_bridge.gd gives it the finger.
	var chooser := ConfirmationDialog.new(); chooser.title = "선택"
	var column := VBoxContainer.new(); chooser.add_child(column)
	var choice := OptionButton.new(); choice.custom_minimum_size = Vector2(240, 44)
	for label: String in ["불","물","바람","땅"]: choice.add_item(label)
	column.add_child(choice)
	var chosen: Array[int] = [-1]
	chooser.confirmed.connect(func() -> void: chosen[0] = choice.selected)
	host.add_child(chooser); chooser.popup_centered(Vector2i(480, 240))
	await frames(4)
	await touch_at(window_point(choice))
	var list: PopupMenu = choice.get_popup()
	check(list.visible, "a dropdown inside a dialog opens on touch")
	var row: Vector2 = root.get_final_transform() * (Vector2(list.position) + Vector2(list.size.x * 0.5, list.size.y * (3.5 / 4.0)))
	await touch_at(row)
	check(choice.selected == 3 and not list.visible, "its row takes the tap (selected %d)" % choice.selected)
	await touch_at(window_point(chooser.get_ok_button()))
	check(chosen[0] == 3 and not chooser.visible, "the dialog then confirms with that choice once")
	chooser.queue_free()
	await frames(2)
	evidence["counts"] = counts
	world.queue_free()
	await process_frame
	print("DIALOG_TOUCH_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
