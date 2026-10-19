extends FieldRenderer
class_name NativePngRenderer
## Bounded native-resolution chunks, following the existing PNG loader's lazy
## ImageTexture lifecycle. No synthetic terrain nodes are created here.
var native_field: NativePngField
var decoded_pixels: int = 0
var peak_decoded_pixels: int = 0
var clock: float = 0.0
const MAX_VISIBLE_PIXELS: int = 24*1024*1024

func configure(value: PlayableField, actor: Node2D) -> void:
	field=value;native_field=value as NativePngField;player=actor
	z_index=-20
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_meta("native_png",true)
	var markers:=Node2D.new()
	markers.name="Portals";markers.z_index=1;add_child(markers)
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
	var extent: Vector2=get_viewport_rect().size/camera.zoom
	var view:=Rect2(camera.get_screen_center_position()-extent*.5,extent).grow(96)
	var wanted: Dictionary={}
	for row: Dictionary in native_field.png_manifest.chunks:
		var box:=Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		if box.intersects(view): wanted[str(row.file)]=row
	# Release old textures first; no cache retains offscreen images.
	for filename: String in chunks.keys():
		if wanted.has(filename): continue
		var sprite: Sprite2D=chunks[filename]
		decoded_pixels-=int(sprite.get_meta("pixels"))
		remove_child(sprite);sprite.free();chunks.erase(filename)
	for filename: String in wanted:
		if chunks.has(filename): continue
		var row: Dictionary=wanted[filename]
		var pixels: int=int(row.size[0])*int(row.size[1])
		if decoded_pixels+pixels>MAX_VISIBLE_PIXELS: continue
		var image:=Image.new()
		if image.load(native_field.png_root+"/"+filename)!=OK:
			push_error("Native PNG chunk decode failed: "+filename);continue
		var sprite:=Sprite2D.new()
		sprite.centered=false;sprite.position=Vector2(row.position[0],row.position[1])
		sprite.texture=ImageTexture.create_from_image(image)
		sprite.set_meta("pixels",pixels);add_child(sprite);chunks[filename]=sprite
		decoded_pixels+=pixels;peak_decoded_pixels=maxi(peak_decoded_pixels,decoded_pixels)

