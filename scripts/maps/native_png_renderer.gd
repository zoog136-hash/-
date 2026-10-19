extends FieldRenderer
class_name NativePngRenderer
## Bounded native-resolution chunks, following the existing PNG loader's lazy
## ImageTexture lifecycle. No synthetic terrain nodes are created here.
var native_field: NativePngField
var decoded_pixels: int = 0
var peak_decoded_pixels: int = 0
var clock: float = 0.0
const MAX_VISIBLE_PIXELS: int = 24*1024*1024
const LAYERS=preload("res://scripts/maps/native_png_layers.gd")
var budget_limited: bool=false

func visible_rows(camera: Camera2D) -> Dictionary:
	var extent: Vector2=get_viewport_rect().size/camera.zoom
	var view:=Rect2(camera.get_screen_center_position()-extent*.5,extent).grow(96)
	var wanted: Dictionary={}
	for row: Dictionary in native_field.png_manifest.chunks+native_field.png_manifest.get("foreground",[]):
		var box:=Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		if box.intersects(view): wanted[str(row.file)]=row
	return wanted

func forecast_pixels(rows: Dictionary) -> int:
	var count: int=0
	for row: Dictionary in rows.values():
		count+=int(row.size[0])*int(row.size[1])
		if row.has("foot_image"): continue
		var chunk:=Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		for cut: Dictionary in field.data.get("runtime_foreground",[]):
			var first: Array=cut.polygon_image[0]
			var box:=Rect2(Vector2(first[0],first[1]),Vector2.ZERO)
			for point: Array in cut.polygon_image: box=box.expand(Vector2(point[0],point[1]))
			box=box.grow(1).intersection(chunk)
			if box.has_area(): count+=int(ceilf(box.size.x+1))*int(ceilf(box.size.y+1))
	return count

func add_image(key: String, source_file: String, row: Dictionary, image: Image) -> void:
	var sprite:=Sprite2D.new()
	sprite.centered=false;sprite.position=Vector2(row.position[0],row.position[1]);sprite.z_index=-20
	if row.has("foot_image"):
		sprite.z_index=0;sprite.position=Vector2(row.foot_image[0],row.foot_image[1])
		sprite.offset=Vector2(row.position[0],row.position[1])-sprite.position
		sprite.set_meta("native_foreground",row.id)
	var pixels: int=image.get_width()*image.get_height()
	sprite.texture=ImageTexture.create_from_image(image)
	sprite.set_meta("pixels",pixels);sprite.set_meta("source_file",source_file)
	sprite.set_meta("source_position",row.position)
	add_child(sprite);chunks[key]=sprite
	decoded_pixels+=pixels;peak_decoded_pixels=maxi(peak_decoded_pixels,decoded_pixels)

func configure(value: PlayableField, actor: Node2D) -> void:
	field=value;native_field=value as NativePngField;player=actor
	z_index=0
	y_sort_enabled=true
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_meta("native_png",true)
	var markers:=Node2D.new()
	markers.name="Portals";markers.z_index=-10;add_child(markers)
	for portal: Dictionary in field.data.portal:
		var ring:=Line2D.new()
		ring.position=Vector2(portal.position[0],portal.position[1])
		for i: int in range(33): ring.add_point(Vector2.from_angle(TAU*i/32)*float(portal.radius))
		ring.width=2;ring.default_color=Color("74d9d0");ring.antialiased=true;markers.add_child(ring)
		var label:=Label.new()
		label.text=str(portal.name);label.position=ring.position+Vector2(-28,-40)
		label.add_theme_font_size_override("font_size",14);markers.add_child(label)
	refresh_visible()

func set_visual_mode(_mode: String) -> void:
	# Preserve original source RGBA in both UI display modes.
	visual_mode="original"

func _process(delta: float) -> void:
	clock-=delta
	if clock<=0:
		clock=.1
		refresh_visible()

func refresh_visible() -> void:
	if field==null or player==null: return
	var camera: Camera2D=player.get_node("Camera2D")
	var wanted: Dictionary=visible_rows(camera)
	# Large windows/zoom-out must not silently skip visible chunks at the cap.
	# Restrict the view before allocation; every selected source tile is shown.
	for attempt: int in range(12):
		var required: int=forecast_pixels(wanted)
		if required<=MAX_VISIBLE_PIXELS: break
		camera.zoom*=maxf(1.08,sqrt(float(required)/MAX_VISIBLE_PIXELS))
		camera.force_update_scroll();budget_limited=true;wanted=visible_rows(camera)
	# Release old textures first; no cache retains offscreen images.
	for filename: String in chunks.keys():
		var sprite: Sprite2D=chunks[filename]
		if wanted.has(str(sprite.get_meta("source_file",filename))): continue
		decoded_pixels-=int(sprite.get_meta("pixels"))
		remove_child(sprite);sprite.free();chunks.erase(filename)
	for filename: String in wanted:
		if chunks.has(filename): continue
		var row: Dictionary=wanted[filename]
		var image:=Image.new()
		if image.load(native_field.png_root+"/"+filename)!=OK:
			push_error("Native PNG chunk decode failed: "+filename);continue
		var pieces: Array[Dictionary]=[]
		if not row.has("foot_image"):
			pieces=LAYERS.split(image,Vector2(row.position[0],row.position[1]),field.data.get("runtime_foreground",[]))
		add_image(filename,filename,row,image)
		for piece: Dictionary in pieces: add_image(filename+"#"+str(piece.id),filename,piece,piece.image)

