extends Node2D
## Source ground picture via the client static branch; owns no loot or save state.
signal source_status_changed(status: Dictionary)
const SELECTION = preload("res://scripts/resources/current523_source_ground_selection.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
var selection_status: Dictionary = {}

func _init() -> void:
	set_process(false)

func clear_source() -> void:
	set_process(false)
	hide()

func configure_ground_source(original_item: Dictionary, source_bank_context: Dictionary = {}, binding: Dictionary = {}, owner_context: Dictionary = {}, expected_ground_id: String = "") -> bool:
	clear_source()
	if not owner_context.is_empty() and owner_context.get("ok") != true:
		selection_status = SELECTION.fail("current523_ground_owner_context_unavailable",{"table":"ItemClass","row":original_item.duplicate(true),"field":"SpriteID"})
	elif not owner_context.is_empty() and ((not expected_ground_id.is_empty() and owner_context.get("ground_id") != expected_ground_id) or owner_context.get("original_item") != original_item):
		selection_status = SELECTION.fail("current523_ground_owner_selection_differs",{"table":"ItemClass","row":original_item.duplicate(true),"field":"SpriteID"})
	else:
		selection_status = SELECTION.select(original_item,source_bank_context,binding)
	if not owner_context.is_empty(): selection_status["source_owner_context"] = owner_context.duplicate(true)
	if selection_status.get("ok",false) and selection_status.get("status") == "selected_static_picture":
		if not _draw_static_picture(): selection_status = SELECTION.fail("current523_ground_static_picture_render_failed",selection_status.get("source_reference",{}))
	source_status_changed.emit(selection_status.duplicate(true))
	return selection_status.get("ok",false) and selection_status.get("status") == "selected_static_picture"

func _draw_static_picture() -> bool:
	# Client draw order for the static branch: main, then shadow. Each layer is
	# placed by its own SP2 frame offset; nothing is substituted when a layer fails.
	for child: Node in get_children(): child.queue_free()
	var bank = BANK.new()
	var opened: Dictionary = bank.load_static(str(selection_status.manifest_path),str(selection_status.manifest_sha256),int(selection_status.sprite_id))
	if not opened.get("ok",false): return false
	var drawn: Array = []
	for index: int in range(opened.layers.size()):
		var layer: Dictionary = opened.layers[index]
		var picture: Dictionary = bank.render_layer(layer)
		if not picture.get("ok",false):
			if layer.kind == "body": return false
			continue
		if picture.get("empty",false): continue
		var sprite := Sprite2D.new()
		sprite.name = "Static" + str(layer.kind).capitalize()
		sprite.centered = false
		sprite.texture = ImageTexture.create_from_image(picture.image)
		sprite.position = Vector2(picture.offset)
		sprite.z_index = -index if layer.kind == "shadow" else 0
		add_child(sprite)
		drawn.append(str(layer.kind))
	selection_status["drawn_layers"] = drawn
	if drawn.is_empty() or drawn[0] != "body": return false
	show()
	return true

func source_frame_status() -> Dictionary:
	return {}
