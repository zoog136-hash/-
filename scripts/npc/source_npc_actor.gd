extends Node2D
## Native decoded pixels. Preview uses raster origin; live placement requires reviewed feet.
const CATALOG = preload("res://scripts/npc/source_npc_catalog.gd")
var sprite: Sprite2D
var visual: Dictionary = {}
var heading_slot: int = 0
var frame_index: int = 0
var clock: float = 0.0
var feet: Array = []

func configure(spawn: Dictionary, preview: bool = false) -> bool:
	var npc: Dictionary = CATALOG.record(str(spawn.get("source_catalog_id","")))
	if npc.is_empty(): return false
	visual = npc.visual
	feet = spawn.get("foot_pixels",[])
	if not preview and feet.size() != int(visual.heading_slots): return false
	var path: String = str(visual.atlas)
	var texture: Texture2D
	var image: Image
	if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != str(visual.sha256): return false
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
		if texture == null: return false
		image = texture.get_image()
	else:
		# Before first editor import only; use exact same approved PNG bytes.
		image = Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return false
		texture = ImageTexture.create_from_image(image)
	if image == null or image.is_empty(): return false
	image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	# Godot's lossless importer may fill RGB under alpha=0 at sprite edges.
	# Canonicalize only invisible pixels; every visible RGBA sample stays exact.
	var pixels: PackedByteArray = image.get_data()
	for index: int in range(0,pixels.size(),4):
		if pixels[index+3] == 0:
			pixels[index] = 0
			pixels[index+1] = 0
			pixels[index+2] = 0
	hash.update(pixels)
	if hash.finish().hex_encode() != str(visual.atlas_rgba_sha256): return false
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	sprite = Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	add_child(sprite)
	set_heading(int(spawn.get("heading_slot",0)))
	return true

func set_heading(slot: int) -> void:
	if slot < 0 or slot > 7: return
	heading_slot = slot if int(visual.get("heading_slots",1)) == 8 else 0
	_update_frame()

func _process(delta: float) -> void:
	if visual.is_empty() or not is_instance_valid(sprite): return
	clock += delta
	var duration: float = float(visual.seconds_per_frame)
	if clock >= duration:
		var steps: int = int(clock/duration)
		clock = fmod(clock,duration)
		frame_index = (frame_index + steps) % int(visual.frames)
		_update_frame()

func _update_frame() -> void:
	if not is_instance_valid(sprite): return
	var cell := Vector2(float(visual.cell_size[0]),float(visual.cell_size[1]))
	(sprite.texture as AtlasTexture).region = Rect2(Vector2(frame_index*cell.x,heading_slot*cell.y),cell)
	var anchor: Array = feet[heading_slot] if not feet.is_empty() else visual.pixel_origin_in_canvas
	sprite.position = -Vector2(float(anchor[0]),float(anchor[1]))
