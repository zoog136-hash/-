extends Node2D
## Explicit preview renderer only. Production map selection is unchanged.
const BASE="res://assets/maps/aden_modular_pilot/compiled/"
var manifest: Dictionary
var actor: Node2D
var active: Dictionary={}
var foreground: Array[Sprite2D]=[]
var textures: Dictionary={}
var peak_ground_bytes: int=0
func configure(player: Node2D) -> void:
	actor=player;y_sort_enabled=true;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	manifest=JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json"))
	position=Vector2(manifest.world_bounds[0],manifest.world_bounds[1])
	for row: Dictionary in manifest.foreground:
		if not textures.has(row.file):
			assert(FileAccess.get_sha256(BASE+row.file)==row.sha256)
			textures[row.file]=ImageTexture.create_from_image(Image.load_from_file(BASE+row.file))
		var sprite:=Sprite2D.new();sprite.texture=textures[row.file];sprite.centered=false
		sprite.position=Vector2(row.foot[0],row.foot[1]);sprite.offset=Vector2(row.position[0]-row.foot[0],row.position[1]-row.foot[1])
		add_child(sprite);foreground.append(sprite)
	refresh()
func refresh() -> void:
	var camera: Camera2D=actor.get_node("Camera2D")
	var size: Vector2=get_viewport_rect().size/camera.zoom
	var visible_world:=Rect2(camera.get_screen_center_position()-size*.5,size).grow(64)
	var keep: Dictionary={}
	for row: Dictionary in manifest.ground_chunks:
		var at:=Vector2(row.position[0],row.position[1])
		if not visible_world.intersects(Rect2(global_position+at,Vector2(row.size[0],row.size[1]))):continue
		keep[row.file]=true
		if active.has(row.file):continue
		assert(FileAccess.get_sha256(BASE+"ground/"+row.file)==row.sha256)
		var sprite:=Sprite2D.new();sprite.centered=false;sprite.position=at;sprite.z_index=-20
		sprite.texture=ImageTexture.create_from_image(Image.load_from_file(BASE+"ground/"+row.file));add_child(sprite);active[row.file]=sprite
	for key: String in active.keys():
		if not keep.has(key):active[key].queue_free();active.erase(key)
	peak_ground_bytes=maxi(peak_ground_bytes,active.size()*512*512*4)
	for sprite: Sprite2D in foreground:
		sprite.visible=visible_world.intersects(Rect2(sprite.global_position+sprite.offset,sprite.texture.get_size()))
func _process(_delta: float) -> void:refresh()
