extends FieldRenderer
class_name NativePngRenderer
## Bounded native-resolution chunks, following the existing PNG loader's lazy
## ImageTexture lifecycle. No synthetic terrain nodes are created here.
var native_field: NativePngField
var decoded_pixels: int = 0
var peak_decoded_pixels: int = 0
var clock: float = 0.0
const MAX_VISIBLE_PIXELS: int = 24*1024*1024
const MAX_MOBILE_PIXELS: int = 12*1024*1024
var texture_pixel_budget: int=MAX_MOBILE_PIXELS if OS.has_feature("mobile") else MAX_VISIBLE_PIXELS
# A single worker owns CPU decoding and per-pixel layer separation. Only
# immutable row/cut snapshots cross threads; SceneTree and GPU stay on main.
# The displayed textures plus the LRU cache share a 48 MiB mobile / 96 MiB desktop cap.
const LAYERS=preload("res://scripts/maps/native_png_layers.gd")
const PREFETCH_MARGIN: float=512.0
var budget_limited: bool=false
var worker: Thread
var worker_file: String=""
var wanted_rows: Dictionary={}
var visible_files: Dictionary={}
var last_used: Dictionary={}
var access_serial: int=0
var decode_count: int=0
var synchronous_decodes: int=0
var upload_count: int=0
var cache_hits: int=0
var shutting_down: bool=false

func rows_in_view(camera: Camera2D, margin: float) -> Dictionary:
	var extent: Vector2=get_viewport_rect().size/camera.zoom
	var view:=Rect2(camera.get_screen_center_position()-extent*.5,extent).grow(margin)
	var wanted: Dictionary={}
	for row: Dictionary in native_field.png_manifest.chunks+native_field.png_manifest.get("foreground",[]):
		var box:=Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		if box.intersects(view): wanted[str(row.file)]=row
	return wanted

func visible_rows(camera: Camera2D) -> Dictionary:
	return rows_in_view(camera,96)

static func decode_chunk(path: String, row: Dictionary, cuts: Array) -> Dictionary:
	var image:=Image.new()
	if image.load(path)!=OK: return {"error":path}
	var pieces: Array[Dictionary]=[]
	if not row.has("foot_image"):
		pieces=LAYERS.split(image,Vector2(row.position[0],row.position[1]),cuts)
	return {"row":row,"image":image,"pieces":pieces}

func _exit_tree() -> void:
	shutting_down=true
	if worker!=null and worker.is_started(): worker.wait_to_finish()
	worker=null

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
	# Entry may decode synchronously before the first displayed field. Moving
	# refreshes never decode PNGs or masks on the rendering thread.
	for filename: String in visible_files:
		if chunks.has(filename): continue
		var row: Dictionary=visible_files[filename]
		synchronous_decodes+=1
		commit_chunk(filename,decode_chunk(native_field.png_root+"/"+filename,row,field.data.get("runtime_foreground",[])))

func set_visual_mode(_mode: String) -> void:
	# Preserve original source RGBA in both UI display modes.
	visual_mode="original"

func _process(delta: float) -> void:
	clock-=delta
	if clock<=0:
		clock=.1
		refresh_visible()
	pump_stream()

func release_source(filename: String) -> void:
	for key: String in chunks.keys():
		var sprite: Sprite2D=chunks[key]
		if str(sprite.get_meta("source_file"))!=filename: continue
		decoded_pixels-=int(sprite.get_meta("pixels"))
		remove_child(sprite);sprite.free();chunks.erase(key)
	last_used.erase(filename)

func reserve_pixels(pixels: int) -> bool:
	while decoded_pixels+pixels>texture_pixel_budget:
		var oldest: String=""
		var serial: int=9223372036854775807
		for filename: String in last_used:
			if visible_files.has(filename): continue
			if int(last_used[filename])<serial:
				oldest=filename;serial=int(last_used[filename])
		if oldest.is_empty(): return false
		release_source(oldest)
	return true

func commit_chunk(filename: String, result: Dictionary) -> void:
	if result.has("error"):
		push_error("Native PNG chunk decode failed: "+str(result.error));return
	if chunks.has(filename): return
	var row: Dictionary=result.row
	var count: int=int(row.size[0])*int(row.size[1])
	for piece: Dictionary in result.pieces: count+=piece.image.get_width()*piece.image.get_height()
	if not reserve_pixels(count): return
	add_image(filename,filename,row,result.image)
	for piece: Dictionary in result.pieces: add_image(filename+"#"+str(piece.id),filename,piece,piece.image)
	access_serial+=1;last_used[filename]=access_serial;upload_count+=1

func pump_stream() -> void:
	if shutting_down: return
	# At most one bounded source chunk is uploaded per displayed frame.
	if worker!=null:
		if worker.is_alive(): return
		var result: Dictionary=worker.wait_to_finish()
		worker=null
		if wanted_rows.has(worker_file): commit_chunk(worker_file,result)
	for filename: String in wanted_rows:
		if chunks.has(filename): continue
		worker_file=filename;worker=Thread.new();decode_count+=1
		var job: Callable=decode_chunk.bind(native_field.png_root+"/"+filename,wanted_rows[filename].duplicate(true),field.data.get("runtime_foreground",[]).duplicate(true))
		var error: Error=worker.start(job,Thread.PRIORITY_LOW)
		if error!=OK:
			worker=null;push_error("Native PNG decoder thread could not start: "+str(error))
		break

func visible_ready() -> bool:
	for filename: String in visible_files:
		if not chunks.has(filename): return false
	return true

func settle_visible(timeout_ms: int=10000) -> bool:
	var deadline: int=Time.get_ticks_msec()+timeout_ms
	refresh_visible()
	while not visible_ready() and Time.get_ticks_msec()<deadline:
		pump_stream()
		await get_tree().process_frame
	return visible_ready()

func refresh_visible() -> void:
	if field==null or player==null: return
	var camera: Camera2D=player.get_node("Camera2D")
	var wanted: Dictionary=visible_rows(camera)
	for attempt: int in range(12):
		var required: int=forecast_pixels(wanted)
		if required<=texture_pixel_budget: break
		camera.zoom*=maxf(1.08,sqrt(float(required)/texture_pixel_budget))
		camera.force_update_scroll();budget_limited=true;wanted=visible_rows(camera)
	visible_files=wanted
	# Visible tiles first. Prefetch fits inside the same memory budget, leaving
	# one additional <=4 MiB decoded worker chunk (plus small cut images) on CPU.
	wanted_rows=wanted.duplicate()
	var center: Vector2=camera.get_screen_center_position()
	var candidates: Array=rows_in_view(camera,PREFETCH_MARGIN).values()
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return (Vector2(a.position[0],a.position[1])+Vector2(a.size[0],a.size[1])*.5).distance_squared_to(center)<(Vector2(b.position[0],b.position[1])+Vector2(b.size[0],b.size[1])*.5).distance_squared_to(center))
	for row: Dictionary in candidates:
		var filename: String=str(row.file)
		if wanted_rows.has(filename): continue
		var trial: Dictionary=wanted_rows.duplicate();trial[filename]=row
		if forecast_pixels(trial)<=texture_pixel_budget: wanted_rows[filename]=row
	for filename: String in wanted_rows:
		if chunks.has(filename):
			access_serial+=1;last_used[filename]=access_serial;cache_hits+=1
