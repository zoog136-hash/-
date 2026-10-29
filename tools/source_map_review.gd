extends SceneTree
## Standalone art inspector; never creates Main, Player, monsters or save services.
## Godot --path . --script res://tools/source_map_review.gd -- --pack=/absolute/pack --map=domination_summit
const PACK = preload("res://scripts/maps/source_map_review_pack.gd")
var pack = PACK.new()
var record: Dictionary = {}
var canvas := Node2D.new()
var camera := Camera2D.new()
var status := Label.new()
var sprites: Dictionary = {}
var capture_path: String = ""
var frames: int = 0
var capture_after: int = 0
var render_failed: bool = false
const MAX_VISIBLE: int = 12

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	var pack_path: String = ""
	var mid: String = "domination_summit"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pack="): pack_path = arg.trim_prefix("--pack=")
		if arg.begins_with("--map="): mid = arg.trim_prefix("--map=")
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
	root.size = Vector2i(1280,720)
	root.window_input.connect(_input)
	if not pack.open_pack(pack_path): push_error(pack.problem); quit(1); return
	root.add_child(canvas)
	canvas.add_child(camera)
	camera.zoom = Vector2.ONE*0.5
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(14,14)
	layer.add_child(panel)
	var choices := OptionButton.new()
	var ids: Array = pack.index.maps.keys()
	ids.sort()
	for id: String in ids:
		choices.add_item(id+" · "+str(pack.index.maps[id].name))
		if id == mid: choices.select(choices.item_count-1)
	choices.item_selected.connect(func(i: int) -> void: choose(str(ids[i])))
	panel.add_child(choices)
	panel.add_child(status)
	choose(mid)
	capture_after = frames+5

func choose(mid: String) -> void:
	var candidate: Dictionary = pack.load_map(mid)
	if candidate.is_empty(): status.text = pack.problem; render_failed = true; return
	render_failed = false
	for node: Sprite2D in sprites.values(): node.free()
	sprites.clear()
	record = candidate
	# Inspect a real central source chunk at 50%, not an overview stretched up.
	var chunk: Dictionary = record.chunks[0]
	camera.position = Vector2(chunk.position[0],chunk.position[1])+Vector2(chunk.size[0],chunk.size[1])*0.5
	status.text = "ART REVIEW ONLY · collision/entry/save migration not approved\nDrag to pan · Wheel to zoom · source pixels unchanged"
	refresh()

func _process(_delta: float) -> bool:
	frames += 1
	if not record.is_empty(): refresh()
	if not capture_path.is_empty() and frames >= capture_after and not record.is_empty():
		var path: String = capture_path
		capture_path = ""
		capture.call_deferred(path)
	return false

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	if render_failed or sprites.is_empty():
		printerr("SOURCE_MAP_REVIEW_CAPTURE_FAILED: ",status.text)
		quit(1)
		return
	var result: Error = root.get_texture().get_image().save_png(path)
	print("SOURCE_MAP_REVIEW_CAPTURE map=",record.target_map_id," visible_chunks=",sprites.size()," result=",result)
	quit(0 if result == OK else 1)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		camera.position -= event.relative/camera.zoom
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.zoom = Vector2.ONE*minf(2.0,camera.zoom.x*1.2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.zoom = Vector2.ONE*maxf(0.4,camera.zoom.x/1.2)

func refresh() -> void:
	var size: Vector2 = Vector2(root.size)/camera.zoom
	var view := Rect2(camera.position-size*0.5,size).grow(48)
	var wanted: Dictionary = {}
	for i: int in range(record.chunks.size()):
		var row: Dictionary = record.chunks[i]
		var box := Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		if view.intersects(box): wanted[i] = row
	# Never silently skip terrain when a view would exceed the texture budget.
	if wanted.size() > MAX_VISIBLE:
		render_failed = true
		status.text = "View contains too many chunks; zoom in to inspect all pixels"
		for node: Sprite2D in sprites.values(): node.free()
		sprites.clear()
		return
	render_failed = false
	for i: Variant in sprites.keys():
		if not wanted.has(i): sprites[i].free(); sprites.erase(i)
	for i: int in wanted:
		if sprites.has(i): continue
		var row: Dictionary = wanted[i]
		var texture: Texture2D = pack.load_texture(row)
		if texture == null: status.text = pack.problem; render_failed = true; continue
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = texture
		sprite.position = Vector2(row.position[0],row.position[1])
		# Preserve source ordering for overlapping expanded chunk margins.
		sprite.z_index = i
		canvas.add_child(sprite)
		sprites[i] = sprite
