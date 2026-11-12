extends SceneTree
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var dialog = load("res://scripts/characters/lobby_pack_install_dialog.gd").new()
	root.add_child(dialog)
	check(dialog.exclusive and dialog.transient, "modal install prevents changing scenes")
	check(dialog._picker.use_native_dialog, "native Android picker")
	check(dialog._picker.file_mode == FileDialog.FILE_MODE_OPEN_FILES, "three split parts selectable")
	dialog._start(PackedStringArray(["missing.zip"]))
	check(dialog._choose.disabled and dialog._close.disabled, "controls disabled while worker active")
	var deadline := Time.get_ticks_msec() + 10000
	while dialog._busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not dialog._busy and not dialog._choose.disabled and not dialog._close.disabled, "failed import enables retry")
	check(dialog._label.text.contains("설치하지 못했습니다"), "failure shown")
	dialog.queue_free()
	await process_frame
	print("LOBBY_PACK_DIALOG_RESULT ", JSON.stringify({"failures":[] if failures == 0 else [failures]}))
	quit(0 if failures == 0 else 1)
