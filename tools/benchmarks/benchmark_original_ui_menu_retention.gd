extends SceneTree
## Synthetic memory observation, not a speed/RSS gate or Android/GPU result.
## godot --headless --path <repo> --script res://tools/benchmarks/benchmark_original_ui_menu_retention.gd -- --output=/tmp/menu-memory.json --close-hook=release
## Baseline reproduction uses the previous source_pack.gd and --close-hook=none.
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const CACHE=preload("res://scripts/ui/original_ui/source_pack_page_cache.gd")
const IMAGE_COUNT=32
const WIDTH=1024
const HEIGHT=512
var failures: Array[String]=[]
var checks: int=0
var rows: Array=[]
var expected_pixels: Dictionary={}
var apply_close_hook: bool=true

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func argument(prefix: String,fallback: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix):return value.trim_prefix(prefix)
	return fallback

func write_bytes(path: String,bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func make_pack(directory: String) -> String:
	var files: Dictionary={}
	for index: int in range(IMAGE_COUNT):
		var member: String="UI/menu_%d.png"%index
		var path: String=directory.path_join("originals").path_join(member)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var image:=Image.create(WIDTH,HEIGHT,false,Image.FORMAT_RGBA8)
		image.fill(Color8((index*31)%256,(index*47)%256,(index*79)%256,127))
		check(image.save_png(path)==OK,"synthetic source PNG is written")
		expected_pixels[member]=PACK._sha256(image.get_data())
		files[member]={"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size()}
	var manifest: Dictionary={"schema":"twilight-original-ui-v1","files":files,"scenes":{},"atlases":{},"blockers":[]}
	var path: String=directory.path_join("original_ui.json")
	write_bytes(path,JSON.stringify(manifest).to_utf8_buffer())
	return FileAccess.get_sha256(path)

func process_memory() -> Dictionary:
	var result: Dictionary={}
	var file:=FileAccess.open("/proc/self/status",FileAccess.READ)
	if file!=null:
		while not file.eof_reached():
			var line: String=file.get_line()
			var name: String=line.get_slice(":",0)
			if name in ["VmRSS","VmHWM","RssAnon","RssFile"]:
				var values: PackedStringArray=line.get_slice(":",1).strip_edges().split(" ",false)
				if not values.is_empty():result[name+"_kib"]=int(values[0])
		file.close()
	result["godot_static_bytes"]=int(Performance.get_monitor(Performance.MEMORY_STATIC))
	result["godot_texture_monitor_bytes"]=int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	result["objects"]=int(Performance.get_monitor(Performance.OBJECT_COUNT))
	result["nodes"]=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	return result

func snapshot(label: String,pack: RefCounted) -> void:
	var row: Dictionary={"phase":label,"memory":process_memory(),"pages":CACHE.stats()}
	if pack!=null:row["pack"]=pack.cache_stats()
	rows.append(row)
	print("ORIGINAL_UI_MENU_RETENTION_STAGE "+JSON.stringify(row))

func open_and_close(pack: RefCounted,start: int,count: int) -> void:
	var window:=Node2D.new()
	root.add_child(window)
	for index: int in range(start,start+count):
		var member: String="UI/menu_%d.png"%index
		var texture: Texture2D=pack.texture({"path":member,"resourceType":0},false)
		check(texture!=null,"source texture is available")
		if texture==null:continue
		check(texture.get_size()==Vector2(WIDTH,HEIGHT) and PACK._sha256(texture.get_image().get_data())==expected_pixels[member],"all decoded source bytes and dimensions survive")
		var sprite:=Sprite2D.new()
		sprite.texture=texture
		window.add_child(sprite)
	# This is the same public lifecycle hook the real HUD calls on close.
	if apply_close_hook:pack.release_cache_leases()
	window.queue_free()

func _initialize() -> void:call_deferred("run")

func run() -> void:
	apply_close_hook=argument("--close-hook=","release")!="none"
	var source_sha: String=FileAccess.get_sha256("res://scripts/ui/original_ui/source_pack.gd")
	var directory: String="user://menu_retention_%d"%OS.get_process_id()
	var manifest_sha: String=make_pack(directory)
	var pack: RefCounted=PACK.new()
	check(pack.open(directory,manifest_sha).ok,"synthetic pack is fully verified")
	var pack_ref: WeakRef=weakref(pack)
	snapshot("before",pack)
	for batch: int in range(4):
		open_and_close(pack,batch*8,8)
		await process_frame
		await process_frame
		snapshot("closed_unique_%d"%((batch+1)*8),pack)
	for repeat: int in range(5):
		open_and_close(pack,0,8)
		await process_frame
		await process_frame
	snapshot("closed_repeat_first_8_x5",pack)
	pack=null
	await process_frame
	await process_frame
	check(pack_ref.get_ref()==null,"pack has no retaining reference cycle")
	snapshot("pack_freed",null)
	check(source_sha==FileAccess.get_sha256("res://scripts/ui/original_ui/source_pack.gd"),"source remains unchanged while measuring")
	var result: Dictionary={"checks":checks,"failures":failures,"rows":rows,"close_hook":apply_close_hook,
		"label":argument("--label=","current"),"source_pack_sha256":source_sha,"manifest_sha256":manifest_sha,
		"engine":Engine.get_version_info().string,"synthetic_only":true,"android_measured":false,"gpu_measured":false,
		"os_cache_flushed":false,"source_images":IMAGE_COUNT,"source_width":WIDTH,"source_height":HEIGHT,
		"decoded_source_bytes":IMAGE_COUNT*WIDTH*HEIGHT*4,"scope":"actual verified SourcePack.texture + Sprite2D windows; explicit close API; two frame settle; no performance threshold"}
	var output: String=argument("--output=","user://menu_retention.json")
	write_bytes(output,JSON.stringify(result,"  ",true).to_utf8_buffer())
	print("ORIGINAL_UI_MENU_RETENTION_RESULT "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
