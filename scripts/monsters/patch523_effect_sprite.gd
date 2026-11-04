extends Node2D
## One source action, one layer, no replacement pixels or damage timing callbacks.
var frames: Array = []
var textures: Array[Texture2D] = []
var durations: Array[float] = []
var sprite: Sprite2D
var elapsed: float = 0
var frame_index: int = 0
var total: float = 0
var own_total: float = 0
var decoded_budget: int = 0
var layer_effects: Array[Node2D] = []
var timing_origin: String = ""
var selected_direction: int = 0
var source_action_id: int = 0

func configure(root: String, record: Dictionary, fallback_fps: float, alpha: float, factor: float, additive: bool, direction: int = 0) -> bool:
	var declared: Variant = record.get("source_fps")
	var fps: float = float(declared) if declared != null else fallback_fps
	if not is_finite(fps) or fps < 1 or fps > 120: return false
	timing_origin = "SPR_explicit" if declared != null else "host_estimated_configurable_FPS"
	selected_direction = posmod(direction,8); source_action_id = int(record.source_action_id)
	frames = (record.directions[str(selected_direction)] if int(record.get("source_direction_flag",0)) == 1 else record.frames).duplicate(true)
	var budget: int = 0
	for frame: Dictionary in frames:
		var path: String = root.path_join(frame.path)
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null or file.get_length() > 4*1024*1024 or file.get_length() != int(frame.get("bytes",-1)) or FileAccess.get_sha256(path) != frame.get("sha256"): return false
		var image := Image.new()
		if image.load_png_from_buffer(file.get_buffer(file.get_length())) != OK or image.get_width() > 2048 or image.get_height() > 2048: return false
		budget += image.get_width()*image.get_height()*4
		if budget > 64*1024*1024: return false
		textures.append(ImageTexture.create_from_image(image))
		var duration: float = float(frame.source_ticks)/fps
		durations.append(duration); total += duration
	if total <= 0 or total > 120: return false
	sprite = Sprite2D.new(); sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if additive else CanvasItemMaterial.BLEND_MODE_MIX
	sprite.material = material; sprite.modulate.a = clampf(alpha,0,1)
	add_child(sprite); scale = Vector2.ONE*factor
	show_frame(0)
	own_total = total; decoded_budget = budget
	for layer: Dictionary in record.get("children",[]):
		var child: Node2D = get_script().new()
		if not child.configure(root,layer,fallback_fps,alpha,1.0,additive,direction): child.free(); return false
		decoded_budget += int(child.decoded_budget)
		if decoded_budget > 64*1024*1024: child.free(); return false
		child.z_index = -1 if layer.get("host_layer_kind") == "shadow" else 1
		add_child(child); layer_effects.append(child)
		total = maxf(total,float(child.total))
	return true

func show_frame(index: int) -> void:
	frame_index = index; sprite.texture = textures[index]
	sprite.position = Vector2(float(frames[index].offset[0]),float(frames[index].offset[1]))

func _process(delta: float) -> void:
	elapsed += maxf(delta,0)
	if elapsed >= total: queue_free(); return
	if elapsed >= own_total: sprite.hide(); return
	var time: float = elapsed
	for i: int in durations.size():
		if time < durations[i]:
			if i != frame_index: show_frame(i)
			return
		time -= durations[i]

func clear() -> void:
	set_process(false); hide()
	textures.clear(); frames.clear(); durations.clear()
	for child: Node2D in layer_effects:
		if is_instance_valid(child): child.clear()
	layer_effects.clear()
