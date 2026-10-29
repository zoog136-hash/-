extends "res://scripts/maps/source_renderer.gd"
## Stream original full-resolution WebPs in the same source frame as physics.
var art: RefCounted
var record: Dictionary
var failure: String=""
var pixel_material: ShaderMaterial
const MAX_VISIBLE=12

func configure(value: PlayableField, actor: Node2D) -> void:
	field=value;source=value as OriginalPlayableField;player=actor
	art=(value as RemakePlayableField).png_game_pack
	record=value.runtime_record
	y_sort_enabled=true
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_material=ShaderMaterial.new()
	pixel_material.shader=load("res://assets/maps/source_map_texel.gdshader")
	refresh_visible()

func refresh_visible() -> void:
	if not is_instance_valid(player) or record.is_empty():return
	var rect: Rect2=get_viewport_rect()
	var inverse: Transform2D=get_canvas_transform().affine_inverse()
	var view:=Rect2(inverse*rect.position,Vector2.ZERO).expand(inverse*rect.end).grow(64)
	var needed: Dictionary={}
	for i: int in range(record.chunks.size()):
		var row: Dictionary=record.chunks[i]
		var box:=Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		if box.intersects(view):needed[i]=row
	if needed.size()>MAX_VISIBLE:
		failure="Original map view exceeds texture budget";push_error(failure);return
	for i: Variant in chunks.keys():
		if not needed.has(i):remove_child(chunks[i]);chunks[i].queue_free();chunks.erase(i)
	for i: int in needed:
		if chunks.has(i):continue
		var row: Dictionary=needed[i]
		var texture: Texture2D=art.load_texture(row)
		if texture==null:failure=art.problem;push_error(failure);return
		var sprite:=Sprite2D.new()
		sprite.centered=false;sprite.texture=texture;sprite.position=Vector2(row.position[0],row.position[1])
		sprite.material=pixel_material
		# Ground stays behind actors; no invented foreground masks.
		sprite.z_index=-30+i
		add_child(sprite);chunks[i]=sprite
	_refresh_markers()
	if source is RemakePlayableField and is_instance_valid(source.collision_stream):source.collision_stream.refresh()

func set_visual_mode(_mode: String) -> void:pass
