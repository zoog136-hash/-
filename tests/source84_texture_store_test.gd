extends SceneTree
const STORE=preload("res://scripts/maps/source_map_texture_store.gd")
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);printerr("SOURCE84_TEXTURE_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var store=STORE.new();root.add_child(store);store.set_process(false)
	var owner_a:=Node.new();var owner_b:=Node.new()
	root.add_child(owner_a);root.add_child(owner_b)
	var folder: String="user://source84_texture_fixture"
	DirAccess.make_dir_recursive_absolute(folder+"/chunks")
	DirAccess.make_dir_recursive_absolute(folder+"/local-interpretation-v1/patches")
	var rows: Array[Dictionary]=[]
	for index: int in range(4):
		var image:=Image.create(32+index*8,16,false,Image.FORMAT_RGBA8)
		image.fill(Color(0.2+index*0.1,0.4,0.6,0.5))
		var relative: String="chunks/probe%d.webp" % index
		image.save_webp(folder+"/"+relative,true)
		rows.append({"file":relative,"sha256":FileAccess.get_sha256(folder+"/"+relative),"size":[image.get_width(),image.get_height()]})
	var first: String=store.request(folder,rows[0],owner_a,true)
	var duplicate: String=store.request(folder,rows[0],owner_b,true)
	check(first==duplicate and is_same(store.texture(first),store.texture(duplicate)),"equal active placements share texture")
	check(store.decodes==1 and store.uploads==1,"one decode/upload for two placements")
	check(int(store.stats().active_bytes)==32*16*4,"unique decoded bytes rather than lease sum")
	store.idle_budget=0;store.prune()
	check(store.texture(first)!=null,"active texture survived zero idle budget")
	store.release_owner(owner_a)
	check(store.texture(first)!=null,"remaining active placement retained source")
	store.release_owner(owner_b)
	check(store.texture(first)==null,"unreferenced idle budget eviction")
	store.idle_budget=STORE.IDLE_BYTES
	var pending: Array[String]=[]
	var before: int=store.uploads
	for row: Dictionary in rows:pending.append(store.request(folder,row,owner_a))
	check(store.uploads==before,"requests did not synchronously upload")
	var frames: int=0
	while int(store.stats().pending)>0 and frames<600:
		var prior: int=store.uploads
		store.pump()
		check(store.uploads-prior<=1,"per-frame upload admission")
		frames+=1
		await process_frame
	check(int(store.stats().pending)==0 and store.max_frame_uploads<=1,"async decode and bounded main-thread uploads complete")
	check(store.max_decode_jobs<=2,"CPU preparation admission bounded to two jobs")
	var retained: Texture2D=store.texture(pending[1])
	store.release_owner(owner_a)
	var return_key: String=store.request(folder,rows[1],owner_b,true)
	check(is_same(retained,store.texture(return_key)),"map return reused idle texture")
	retained=null;store.release_owner(owner_b)
	var original: PackedByteArray=FileAccess.get_file_as_bytes(folder+"/"+rows[1].file)
	var changed:=FileAccess.open(folder+"/"+rows[1].file,FileAccess.WRITE);changed.store_string("changed");changed.close()
	check(store.request(folder,rows[1],owner_b,true).is_empty(),"cached reuse still rejects changed source bytes")
	changed=FileAccess.open(folder+"/"+rows[1].file,FileAccess.WRITE);changed.store_buffer(original);changed.close()
	var png:=Image.create(20,12,false,Image.FORMAT_RGBA8);png.fill(Color(1,0,0,0.5))
	var patch: Dictionary={"file":"local-interpretation-v1/patches/probe.png","size":[20,12],"local_patch":true}
	png.save_png(folder+"/"+patch.file);patch.sha256=FileAccess.get_sha256(folder+"/"+patch.file)
	var patch_key: String=store.request(folder,patch,owner_a,true)
	check(store.texture(patch_key)!=null and store.texture(patch_key).get_image().get_pixel(0,0).is_equal_approx(png.get_pixel(0,0)),"local patch exact RGBA pixels")
	var real: Dictionary={}
	var map_path: String="res://external_map_packs/source84_v3/maps/source_77.json"
	if FileAccess.file_exists(map_path):
		var record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(map_path))
		var begun: int=Time.get_ticks_usec()
		for index: int in range(2):
			var row: Dictionary=record.chunks[index]
			var key: String=store.request("res://external_map_packs/source84_v3",row,owner_a,true)
			check(store.texture(key)!=null,"actual source77 WebP "+str(index))
		var loaded: int=store.decodes
		store.release_owner(owner_a)
		for index: int in range(2):store.request("res://external_map_packs/source84_v3",record.chunks[index],owner_b,true)
		check(store.decodes==loaded,"actual source77 round trip did not redecode within idle budget")
		real={"chunks":2,"round_trip_new_decodes":store.decodes-loaded,"elapsed_usec":Time.get_ticks_usec()-begun}
	else:check(false,"actual source77 checkout available")
	var local_path: String="res://external_map_packs/source84_v3/local-interpretation-v1/index.json"
	var local_index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(local_path))
	var patch_spec: Dictionary=local_index.maps.source_303.patches[0]
	var actual_row: Dictionary={"file":"local-interpretation-v1/"+str(patch_spec.file),"sha256":patch_spec.sha256,"size":[3072,1536],"local_patch":true}
	var actual_patch: String=store.request("res://external_map_packs/source84_v3",actual_row,owner_a,true)
	check(store.texture(actual_patch)!=null,"actual source303 local patch loaded")
	if store.texture(actual_patch)!=null:
		var image: Image=store.texture(actual_patch).get_image();image.convert(Image.FORMAT_RGBA8)
		var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data())
		check(digest.finish().hex_encode()==str(patch_spec.rgba_sha256),"actual local patch reviewed RGBA hash")
	var bad: Dictionary=rows[0].duplicate(true);bad.size=[1,1]
	var bad_key: String=store.request(folder,bad,owner_b,true)
	check(store.texture(bad_key)==null and not store.problem(bad_key).is_empty(),"wrong declared dimensions rejected before upload")
	store.release_owner(owner_a);store.release_owner(owner_b)
	store.idle_budget=0;store.prune()
	var actual_record: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(map_path))
	var abandoned: String=store.request("res://external_map_packs/source84_v3",actual_record.chunks[0],owner_a)
	store.pump();store.release_owner(owner_a)
	var before_cancel: int=store.uploads
	for frame: int in range(20):
		await process_frame
		store.pump()
	check(store.uploads==before_cancel and store.texture(abandoned)==null,"abandoned map decode discarded before GPU upload")
	print("SOURCE84_TEXTURE_STORE_RESULT ",JSON.stringify({"failures":failures,"stats":store.stats(),"async_frames":frames,"actual_source77":real}))
	store.release_owner(owner_a);store.release_owner(owner_b)
	store.queue_free();owner_a.queue_free();owner_b.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
