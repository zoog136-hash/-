extends "res://scripts/maps/field_renderer.gd"
class_name NativePngRenderer
## Bounded native-resolution chunks, following the existing PNG loader's lazy
## ImageTexture lifecycle. No synthetic terrain nodes are created here.
# The world validates NativePngField before configure(); avoid resolving its
# full spawn/navigation class graph while Android scans renderer classes.
var native_field: Variant = null
var decoded_pixels: int = 0 # Unique resident texture pixels, including idle entries.
var peak_decoded_pixels: int = 0
var clock: float = 0.0
const MAX_VISIBLE_PIXELS: int = 24*1024*1024
const MAX_MOBILE_PIXELS: int = 12*1024*1024
var texture_pixel_budget: int=MAX_MOBILE_PIXELS if OS.has_feature("mobile") else MAX_VISIBLE_PIXELS
# A single worker owns CPU decoding and per-pixel layer separation. Only
# immutable row/cut snapshots cross threads; SceneTree and GPU stay on main.
# This is a renderer-local texture budget, not a limit on all game textures.
const LAYERS=preload("res://scripts/maps/native_png_layers.gd")
const LAYER_SHADER=preload("res://scripts/maps/png_layer.gdshader")
const MAP_TEXTURE_QUALITY=preload("res://scripts/maps/mobile_map_texture_quality.gd")
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
var texture_reuse_hits: int=0
var resident_texture_bytes: int=0
var peak_resident_texture_bytes: int=0
# A source key identifies the immutable file and its requested output quality.
# The resolved key also includes the decoded format and exact dimensions.
var texture_keys_by_source: Dictionary={}
var resident_textures: Dictionary={}
var chunk_texture_keys: Dictionary={}
var shutting_down: bool=false
# Generated plaza is optional art only. It shares the original stream/cache budget.
var generated_rows: Array=[]
var generated_full_world: bool=false
var generated_grid: Dictionary={}
var max_decode_usec: int=0
var decode_errors: int=0
func index_generated(row: Dictionary) -> void:
	var p:=Vector2(row.position[0],row.position[1]);var end:=p+Vector2(row.size[0],row.size[1])
	for y: int in range(floori(p.y/1024),floori(end.y/1024)+1):
		for x: int in range(floori(p.x/1024),floori(end.x/1024)+1):
			var key:=Vector2i(x,y)
			if not generated_grid.has(key):generated_grid[key]=[]
			generated_grid[key].append(row)
func load_generated_world() -> bool:
	return false # No pre-replacement Aden art fallback.

func row_scale(row: Dictionary) -> float:
	return 1.0 if row.get("generated",false) else native_field.artwork_scale
func row_path(filename: String) -> String:
	return filename.get_slice("#",0) if filename.begins_with("res://") else native_field.png_root+"/"+filename
func texture_source_key(filename: String, row: Dictionary) -> String:
	if row.has("texture_source_key"):return str(row.texture_source_key)
	var quality: float=MAP_TEXTURE_QUALITY.scale_for(str(field.data.map_id))
	# A foreground cut is specific to its source row; generated placements have
	# no cuts and may share one texture while retaining separate Sprite2D nodes.
	var identity: String=filename
	if row.get("generated",false):
		identity=ProjectSettings.globalize_path(row_path(str(row.file))).simplify_path()
	return "%s|%s|%s|%s|%s" % [identity,str(row.get("sha256","")),str(row.get("codec","png")),str(row.size),str(quality)]

func cached_texture_key(filename: String, row: Dictionary) -> String:
	return str(texture_keys_by_source.get(texture_source_key(filename,row),""))

func texture_stats() -> Dictionary:
	var active: int=0
	for entry: Dictionary in resident_textures.values():
		if int(entry.active)>0:active+=1
	return {"unique_textures":resident_textures.size(),"active_textures":active,
		"idle_textures":resident_textures.size()-active,"unique_bytes":resident_texture_bytes,
		"peak_unique_bytes":peak_resident_texture_bytes,"decodes":decode_count+synchronous_decodes,
		"uploads":upload_count,"reuses":texture_reuse_hits}

func evict_idle_texture() -> bool:
	var oldest: String=""
	var serial: int=9223372036854775807
	for key: String in resident_textures:
		var entry: Dictionary=resident_textures[key]
		if int(entry.active)>0: continue
		if int(entry.used)<serial: oldest=key;serial=int(entry.used)
	if oldest.is_empty():return false
	var entry: Dictionary=resident_textures[oldest]
	decoded_pixels-=int(entry.pixels)
	resident_texture_bytes-=int(entry.bytes)
	if texture_keys_by_source.get(str(entry.source_key))==oldest:
		texture_keys_by_source.erase(str(entry.source_key))
	resident_textures.erase(oldest)
	return true
func load_generated_plaza() -> void:
	pass # Retired Aden composition has no runtime fallback.

func rows_in_view(camera: Camera2D, margin: float) -> Dictionary:
	var extent: Vector2=get_viewport_rect().size/camera.zoom
	var view:=Rect2(camera.get_screen_center_position()-extent*.5,extent).grow(margin)
	var wanted: Dictionary={}
	var candidates: Array=[]
	if generated_full_world:
		var seen: Dictionary={}
		for y: int in range(floori(view.position.y/1024),floori(view.end.y/1024)+1):
			for x: int in range(floori(view.position.x/1024),floori(view.end.x/1024)+1):
				for row: Dictionary in generated_grid.get(Vector2i(x,y),[]):
					if not seen.has(row.file):seen[row.file]=true;candidates.append(row)
	else:candidates=native_field.png_manifest.chunks+native_field.png_manifest.get("foreground",[])+generated_rows
	for row: Dictionary in candidates:
		var box:=Rect2(Vector2(row.position[0],row.position[1])*row_scale(row),Vector2(row.size[0],row.size[1])*row_scale(row))
		if box.intersects(view): wanted[str(row.file)]=row
	return wanted

func visible_rows(camera: Camera2D) -> Dictionary:
	return rows_in_view(camera,96)

static func decode_chunk(path: String, row: Dictionary, cuts: Array, render_scale: float=1.0) -> Dictionary:
	var started: int=Time.get_ticks_usec()
	var image:=Image.new()
	if row.get("generated",false) and FileAccess.get_sha256(path)!=row.sha256:return {"error":"SHA mismatch "+path}
	var error: Error
	if row.get("codec","")=="webp":error=image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path))
	elif row.get("generated",false):error=image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	else:error=image.load(path)
	if error!=OK: return {"error":path}
	var pieces: Array[Dictionary]=[]
	if not row.has("foot_image") and not row.get("generated",false):
		pieces=LAYERS.split(image,Vector2(row.position[0],row.position[1]),cuts)
	# Perform downsampling after original-resolution alpha/foreground separation.
	# This CPU work runs in the existing decode worker, never on the render thread.
	if render_scale < 1.0:
		MAP_TEXTURE_QUALITY.resize_image(image,render_scale)
		for piece: Dictionary in pieces:
			MAP_TEXTURE_QUALITY.resize_image(piece.image as Image,render_scale)
	return {"row":row,"image":image,"pieces":pieces,"decode_usec":Time.get_ticks_usec()-started}

func _exit_tree() -> void:
	shutting_down=true
	if worker!=null and worker.is_started(): worker.wait_to_finish()
	worker=null

func forecast_pixels(rows: Dictionary) -> int:
	var count: int=0
	var render_scale: float=MAP_TEXTURE_QUALITY.scale_for(str(field.data.map_id))
	var counted: Dictionary={}
	for row: Dictionary in rows.values():
		var source_key: String=texture_source_key(str(row.file),row)
		if not counted.has(source_key):
			counted[source_key]=true
			count+=MAP_TEXTURE_QUALITY.pixel_count(Vector2i(int(row.size[0]),int(row.size[1])),render_scale)
		if row.has("foot_image") or row.get("generated",false): continue
		var chunk:=Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		for cut: Dictionary in field.data.get("runtime_foreground",[]):
			var first: Array=cut.polygon_image[0]
			var box:=Rect2(Vector2(first[0],first[1]),Vector2.ZERO)
			for point: Array in cut.polygon_image: box=box.expand(Vector2(point[0],point[1]))
			box=box.grow(1).intersection(chunk)
			if box.has_area():
				count+=MAP_TEXTURE_QUALITY.pixel_count(Vector2i(ceili(box.size.x+1.0),ceili(box.size.y+1.0)),render_scale)
	return count

func add_texture(key: String, source_file: String, row: Dictionary, texture_key: String) -> void:
	var entry: Dictionary=resident_textures[texture_key]
	var texture: Texture2D=entry.texture
	var sprite:=Sprite2D.new()
	var scale_value: float=row_scale(row)
	var pixel_ratio: Vector2=MAP_TEXTURE_QUALITY.pixel_ratio(Vector2i(int(row.size[0]),int(row.size[1])),texture.get_size())
	sprite.centered=false;sprite.position=Vector2(row.position[0],row.position[1])*scale_value;sprite.z_index=int(row.get("z_index",-20))
	# Restore the exact source-world footprint after storing fewer texture pixels.
	sprite.scale=Vector2.ONE*scale_value/pixel_ratio
	if MAP_TEXTURE_QUALITY.scale_for(str(field.data.map_id))<1.0:
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if scale_value>1:
		var layer_material:=ShaderMaterial.new();layer_material.shader=LAYER_SHADER;sprite.material=layer_material
	if row.has("foot_image"):
		sprite.z_index=0;sprite.position=Vector2(row.foot_image[0],row.foot_image[1])*scale_value
		sprite.offset=(Vector2(row.position[0],row.position[1])-Vector2(row.foot_image[0],row.foot_image[1]))*pixel_ratio
		sprite.set_meta("native_foreground",row.id)
	sprite.texture=texture
	sprite.set_meta("pixels",int(entry.pixels));sprite.set_meta("source_file",source_file)
	sprite.set_meta("source_position",row.position)
	add_child(sprite);chunks[key]=sprite;chunk_texture_keys[key]=texture_key
	entry.active=int(entry.active)+1
	access_serial+=1;entry.used=access_serial

func add_image(key: String, source_file: String, row: Dictionary, image: Image) -> void:
	var source_key: String=texture_source_key(key,row)
	var texture_key: String="%s|%d|%dx%d" % [source_key,image.get_format(),image.get_width(),image.get_height()]
	if not resident_textures.has(texture_key):
		var texture: ImageTexture=ImageTexture.create_from_image(image)
		var pixels: int=image.get_width()*image.get_height()
		var bytes: int=image.get_data().size()
		resident_textures[texture_key]={"texture":texture,"pixels":pixels,"bytes":bytes,"active":0,"used":access_serial,"source_key":source_key}
		texture_keys_by_source[source_key]=texture_key
		decoded_pixels+=pixels;peak_decoded_pixels=maxi(peak_decoded_pixels,decoded_pixels)
		resident_texture_bytes+=bytes;peak_resident_texture_bytes=maxi(peak_resident_texture_bytes,resident_texture_bytes)
		upload_count+=1
	else:texture_reuse_hits+=1
	add_texture(key,source_file,row,texture_key)

func configure(value: PlayableField, actor: Node2D) -> void:
	field=value;native_field=value;player=actor
	if not load_generated_world():load_generated_plaza()
	z_index=0
	y_sort_enabled=true
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR if native_field.artwork_scale>1 else CanvasItem.TEXTURE_FILTER_NEAREST
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
	# Decode only the entry tile synchronously; other visible chunks stream.
	var source_position: Vector2=player.global_position
	for filename: String in visible_files:
		var row: Dictionary=visible_files[filename]
		var source_rect:=Rect2(Vector2(row.position[0],row.position[1]),Vector2(row.size[0],row.size[1]))
		if not source_rect.has_point(source_position/row_scale(row)) or row.has("foot_image"): continue
		synchronous_decodes+=1
		commit_chunk(filename,decode_chunk(row_path(filename),row,field.data.get("runtime_foreground",[]),MAP_TEXTURE_QUALITY.scale_for(str(field.data.map_id))))
		break

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
		var texture_key: String=str(chunk_texture_keys[key])
		var entry: Dictionary=resident_textures[texture_key]
		entry.active=int(entry.active)-1
		remove_child(sprite);sprite.free();chunks.erase(key)
		chunk_texture_keys.erase(key)
	last_used.erase(filename)

func reserve_pixels(pixels: int) -> bool:
	while decoded_pixels+pixels>texture_pixel_budget:
		if evict_idle_texture():continue
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
		decode_errors+=1;push_error("Native PNG chunk decode failed: "+str(result.error));return
	if chunks.has(filename): return
	max_decode_usec=maxi(max_decode_usec,int(result.get("decode_usec",0)))
	var row: Dictionary=result.row
	# Reserve the complete row before adding any sprite. Cached generated rows
	# take the zero-decode path above, so this cannot evict a texture needed by
	# another placement in the same commit.
	var count: int=result.image.get_width()*result.image.get_height()
	for piece: Dictionary in result.pieces:count+=piece.image.get_width()*piece.image.get_height()
	if not reserve_pixels(count): return
	add_image(filename,filename,row,result.image)
	for piece: Dictionary in result.pieces: add_image(filename+"#"+str(piece.id),filename,piece,piece.image)
	access_serial+=1;last_used[filename]=access_serial

func commit_cached_generated(filename: String, row: Dictionary) -> bool:
	if not row.get("generated",false):return false
	var texture_key: String=cached_texture_key(filename,row)
	if texture_key.is_empty() or not resident_textures.has(texture_key):return false
	add_texture(filename,filename,row,texture_key)
	texture_reuse_hits+=1
	access_serial+=1;last_used[filename]=access_serial
	return true

func can_decode_without_thrash(filename: String, row: Dictionary) -> bool:
	var need: int=forecast_pixels({filename:row})
	var evictable: int=0
	var protected: Dictionary={}
	for key: String in chunks:
		var sprite: Sprite2D=chunks[key]
		if visible_files.has(str(sprite.get_meta("source_file"))):protected[str(chunk_texture_keys[key])]=true
	for key: String in resident_textures:
		if not protected.has(key):evictable+=int(resident_textures[key].pixels)
	return decoded_pixels+need-evictable<=texture_pixel_budget

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
		if commit_cached_generated(filename,wanted_rows[filename]):continue
		if not can_decode_without_thrash(filename,wanted_rows[filename]): continue
		worker_file=filename;worker=Thread.new();decode_count+=1
		var job: Callable=decode_chunk.bind(row_path(filename),wanted_rows[filename].duplicate(true),field.data.get("runtime_foreground",[]).duplicate(true),MAP_TEXTURE_QUALITY.scale_for(str(field.data.map_id)))
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
		return ((Vector2(a.position[0],a.position[1])+Vector2(a.size[0],a.size[1])*.5)*row_scale(a)).distance_squared_to(center)<((Vector2(b.position[0],b.position[1])+Vector2(b.size[0],b.size[1])*.5)*row_scale(b)).distance_squared_to(center))
	for row: Dictionary in candidates:
		var filename: String=str(row.file)
		if wanted_rows.has(filename): continue
		var trial: Dictionary=wanted_rows.duplicate();trial[filename]=row
		if forecast_pixels(trial)<=texture_pixel_budget: wanted_rows[filename]=row
	for filename: String in wanted_rows:
		if chunks.has(filename):
			access_serial+=1;last_used[filename]=access_serial;cache_hits+=1
