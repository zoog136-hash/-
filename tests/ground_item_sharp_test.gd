extends SceneTree
## Phone report 2026-11-20: floor item pictures were blurrier than their names.
## The 523 static floor body (current523_ground_source_view) is drawn 1:1 from
## the SP2 bank as an uncompressed ImageTexture under the 1.75x field camera;
## it inherited the linear canvas filter while SP2 actors and the drop effect
## use nearest. The body now samples nearest, like the other SP2 drawings.
##   godot --headless --path <repo> --script res://tests/ground_item_sharp_test.gd
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("GROUND_ITEM_SHARP_FAIL: " + label)

func _initialize() -> void:
	var view: String = FileAccess.get_file_as_string("res://scripts/loot/current523_ground_source_view.gd")
	check(view.contains("sprite.texture = ImageTexture.create_from_image(picture.image)") and view.contains("sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST"), "the static floor body samples source pixels with nearest")
	check(not view.contains("resize(") and not view.contains("compress("), "the floor body is not resized or compressed")
	var preview: String = FileAccess.get_file_as_string("res://scripts/animation/original_source_preview.gd")
	check(preview.count("TEXTURE_FILTER_NEAREST") >= 2, "SP2 body actions and drop effects stay nearest")
	var loot: String = FileAccess.get_file_as_string("res://scripts/loot/ground_loot.gd")
	check(loot.contains("FIELD_CAMERA.keep_screen_size(source_name_label"), "the name label keeps its screen size (unchanged)")
	print("GROUND_ITEM_SHARP_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
