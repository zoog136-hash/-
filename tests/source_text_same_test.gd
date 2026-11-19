extends SceneTree
## Setting a source Text to the text it already shows changes nothing and
## skips the glyph/options work (HUD labels are set every frame).
##   godot --headless --path <repo> --script res://tests/source_text_same_test.gd
const TEXT = preload("res://scripts/ui/original_ui/source_text.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("SOURCE_TEXT_SAME_FAIL: " + label)

func _initialize() -> void:
	var font := SystemFont.new()
	var file := FontFile.new()
	file.data = (ThemeDB.fallback_font as FontFile).data if ThemeDB.fallback_font is FontFile else PackedByteArray()
	var node: Node2D = TEXT.new()
	var options: Dictionary = {"text": "HP 10", "fontSize": 12, "_type": "TextOptions", "isCustomSize": false, "widgetOptions": {"ignoreSize": true}, "hAlignment": 0, "vAlignment": 0, "shadowEnabled": false, "outlineEnabled": false}
	var used: FontFile = ThemeDB.fallback_font as FontFile
	check(used != null, "a fallback FontFile is available")
	if used == null:
		_finish(); return
	check(node.configure(used, options, Vector2(80, 16)).ok, "configured")
	var before: Dictionary = node.original_options
	check(node.set_source_text("HP 10").ok, "same text answers ok")
	check(is_same(node.original_options, before), "same text keeps the committed options (no copy)")
	check(node.set_source_text("HP 11").ok and node.original_options.text == "HP 11" and not is_same(node.original_options, before), "new text is committed as before")
	check(node.source_lines == PackedStringArray(["HP 11"]), "lines follow the new text")
	node.free()
	_finish()

func _finish() -> void:
	print("SOURCE_TEXT_SAME_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
