extends RefCounted
## Godot's own dialogs (ConfirmationDialog, AcceptDialog, FileDialog) show
## the engine's English defaults (OK / Cancel / Open / Alert! ...) unless the
## caller names its buttons. The game's texts are Korean like the original
## client (확인 / 취소): every dialog that enters the tree gets the Korean
## text for a button or title still at the engine default. A caller's own
## text is never replaced.
const BUTTONS: Dictionary = {"OK":"확인", "Cancel":"취소", "Open":"열기", "Save":"저장",
	"Select Current Folder":"현재 폴더 선택", "Select This Folder":"이 폴더 선택", "Close":"닫기"}
const TITLES: Dictionary = {"Alert!":"알림", "Please Confirm...":"확인", "Open a File":"파일 열기",
	"Open File(s)":"파일 열기", "Open a Directory":"폴더 열기", "Open a File or Directory":"파일 또는 폴더 열기", "Save a File":"파일 저장"}

## Watches `tree` (once per tree).
static func install(tree: SceneTree) -> void:
	var hook: Callable = Callable(preload("res://scripts/ui/dialog_korean_texts.gd"), "_on_node_added")
	if not tree.node_added.is_connected(hook): tree.node_added.connect(hook)

static func _on_node_added(node: Node) -> void:
	if not node is AcceptDialog: return
	# After the caller's own setup in the same frame; FileDialog resets its
	# button text when its mode changes, so again before each popup.
	var apply_now: Callable = Callable(preload("res://scripts/ui/dialog_korean_texts.gd"), "apply")
	apply_now.call_deferred(node)
	var again: Callable = apply_now.bind(node)
	if not node.about_to_popup.is_connected(again): node.about_to_popup.connect(again)

static func apply(dialog: AcceptDialog) -> void:
	if not is_instance_valid(dialog): return
	# An empty text is the engine's own default (OK, or Open / Save by mode).
	if dialog.ok_button_text.is_empty(): dialog.ok_button_text = _default_ok(dialog)
	elif BUTTONS.has(dialog.ok_button_text): dialog.ok_button_text = BUTTONS[dialog.ok_button_text]
	if dialog is ConfirmationDialog and BUTTONS.has((dialog as ConfirmationDialog).cancel_button_text):
		(dialog as ConfirmationDialog).cancel_button_text = BUTTONS[(dialog as ConfirmationDialog).cancel_button_text]
	if TITLES.has(dialog.title): dialog.title = TITLES[dialog.title]

static func _default_ok(dialog: AcceptDialog) -> String:
	if dialog is FileDialog:
		match (dialog as FileDialog).file_mode:
			FileDialog.FILE_MODE_SAVE_FILE: return "저장"
			FileDialog.FILE_MODE_OPEN_DIR: return "선택"
			_: return "열기"
	return "확인"

## A content column for `dialog`: its text as a label, then whatever the
## caller adds below it. (A control added straight to the dialog is laid over
## the dialog text; Godot 4 has no get_vbox.)
static func content(dialog: AcceptDialog, text: String) -> VBoxContainer:
	dialog.dialog_text = ""
	var column := VBoxContainer.new()
	column.name = "DialogContent"
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(360, 0)
	column.add_child(label)
	dialog.add_child(column)
	return column
