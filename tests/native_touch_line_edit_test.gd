extends SceneTree
## Android has emulate_mouse_from_touch off: a field must take focus from a tap.
const FIELD = preload("res://scripts/ui/native_touch_line_edit.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func touch(field: Control, index: int, pressed: bool, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	field._gui_input(event)

func _initialize() -> void:
	var field: LineEdit = FIELD.new()
	field.size = Vector2(300, 52)
	root.add_child(field)
	await process_frame
	check(not field.has_focus(), "starts unfocused")
	touch(field, 0, true, Vector2(20, 20))
	touch(field, 0, false, Vector2(28, 22))
	check(field.has_focus() and field.is_editing(), "short tap focuses and starts editing")
	field.unedit()
	field.release_focus()
	touch(field, 0, true, Vector2(20, 20))
	touch(field, 0, false, Vector2(120, 20))
	check(not field.has_focus(), "drag across the field is not a tap")
	touch(field, 1, true, Vector2(20, 20))
	touch(field, 2, false, Vector2(20, 20))
	check(not field.has_focus(), "release of another finger is ignored")
	field.editable = false
	touch(field, 1, false, Vector2(20, 20))
	check(not field.has_focus(), "read-only field stays unfocused")
	var lobby_source: String = FileAccess.get_file_as_string("res://scripts/characters/character_lobby.gd")
	check(lobby_source.contains("native_touch_line_edit.gd") and not lobby_source.contains("LineEdit.new()"), "character name field uses the touch field")
	print("NATIVE_TOUCH_LINE_EDIT_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
