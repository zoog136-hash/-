extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String]=[]
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/aden_world_mobile/manifest.json"))
	var field:=NativePngField.new()
	field.data={"map_id":"aden_world","runtime_foreground":[]}
	field.artwork_scale=1.0
	var renderer:=NativePngRenderer.new()
	renderer.field=field;renderer.native_field=field
	root.add_child(renderer)
	if not renderer.load_generated_world():
		printerr("Generated world manifest unavailable");quit(1);return
	if renderer.generated_rows.size()!=manifest.ground.size()+manifest.placements.size():failures.append("placement count changed")
	var rows: Array=[]
	for row: Dictionary in renderer.generated_rows:
		if str(row.file).contains("/objects/oak.webp.bin#"):rows.append(row)
		if rows.size()==2:break
	if rows.size()!=2:
		printerr("Two oak placements are required");quit(1);return
	var first: Dictionary=rows[0]
	var second: Dictionary=rows[1]
	if renderer.forecast_pixels({first.file:first,second.file:second})!=int(first.size[0])*int(first.size[1]):failures.append("forecast counts placements instead of unique texture")
	renderer.wanted_rows={first.file:first}
	renderer.visible_files={first.file:first,second.file:second}
	var deadline: int=Time.get_ticks_msec()+5000
	while not renderer.chunks.has(first.file) and Time.get_ticks_msec()<deadline:
		renderer.pump_stream()
		await process_frame
	if not renderer.chunks.has(first.file):
		printerr("First placement did not stream");quit(1);return
	renderer.wanted_rows={first.file:first,second.file:second}
	renderer.pump_stream()
	if not renderer.chunks.has(second.file):failures.append("second placement missed shared texture")
	if not failures.is_empty():
		printerr(failures);quit(1);return
	var a: Sprite2D=renderer.chunks[first.file]
	var b: Sprite2D=renderer.chunks[second.file]
	var shared_bytes: int=a.texture.get_image().get_data().size()
	if not is_same(a.texture,b.texture):failures.append("simultaneous placements have different textures")
	if renderer.decode_count!=1 or renderer.upload_count!=1 or renderer.texture_reuse_hits!=1:failures.append("duplicate decode/upload or missed reuse")
	if renderer.resident_textures.size()!=1 or renderer.decoded_pixels!=a.texture.get_width()*a.texture.get_height():failures.append("unique texture accounting")
	if renderer.resident_texture_bytes!=shared_bytes:failures.append("format byte accounting")
	for i: int in range(2):
		var sprite: Sprite2D=a if i==0 else b
		var row: Dictionary=rows[i]
		if sprite.position!=Vector2(row.foot_image[0],row.foot_image[1]):failures.append("foot position changed")
		if sprite.offset!=Vector2(row.position[0]-row.foot_image[0],row.position[1]-row.foot_image[1]):failures.append("placement offset changed")
		if sprite.z_index!=0 or sprite.get_meta("native_foreground")!=row.id:failures.append("Y sort changed")
	renderer.release_source(first.file)
	if not is_instance_valid(b) or renderer.resident_texture_bytes==0:failures.append("active placement texture evicted")
	renderer.release_source(second.file)
	renderer.reserve_pixels(renderer.texture_pixel_budget)
	if renderer.resident_texture_bytes!=0 or not renderer.resident_textures.is_empty():failures.append("idle texture did not evict")
	print("NATIVE_TEXTURE_SHARING_RESULT ",JSON.stringify({"failures":failures,"placements":2,"decodes":renderer.decode_count,"uploads":renderer.upload_count,"reuse":renderer.texture_reuse_hits,"encoded_source_bytes":int(manifest.assets.oak.bytes),"shared_texture_bytes":shared_bytes}))
	renderer.queue_free()
	quit(0 if failures.is_empty() else 1)
