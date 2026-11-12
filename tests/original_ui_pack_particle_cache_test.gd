extends SceneTree
## Invented embedded plist/PNG data; never a private original-particle claim.
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const PARTICLE={"path":"particle.plist","resourceType":0}
const SIZE=Vector2i(8,6)
const FRAME_BYTES=8*6*4
var checks: int=0
var failures: Array[String]=[]

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("FAIL: "+label)

func write_bytes(path: String,bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func fixture(directory: String) -> Dictionary:
	var original:=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x):original.set_pixel(x,y,Color8(x*29,y*41,(x+y)*17,[0,1,77,128,200,255][x%6]))
	var png: PackedByteArray=original.save_png_to_buffer()
	var expected: PackedByteArray=original.get_data()
	for at: int in range(0,expected.size(),4):
		var alpha_plus_one: int=int(expected[at+3])+1
		for channel: int in range(3):expected[at+channel]=(int(expected[at+channel])*alpha_plus_one)>>8
	var encoded: String=Marshalls.raw_to_base64(png.compress(FileAccess.COMPRESSION_GZIP))
	var plist: String='<?xml version="1.0"?><plist><dict><key>maxParticles</key><integer>1</integer><key>textureFileName</key><string></string><key>textureImageData</key><string>'+encoded+'</string></dict></plist>'
	write_bytes(directory.path_join("originals/UI/particle.plist"),plist.to_utf8_buffer())
	var files: Dictionary={}
	for index: int in range(3):
		var page:=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGBA8)
		page.fill(Color8(index*73,40,100,127))
		var path: String=directory.path_join("originals/UI/page_%d.png"%index)
		page.save_png(path)
	for member: String in ["UI/particle.plist","UI/page_0.png","UI/page_1.png","UI/page_2.png"]:
		var path: String=directory.path_join("originals/"+member)
		files[member]={"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_size(path)}
	var manifest: Dictionary={"schema":"twilight-original-ui-v1","scenes":{},"files":files,"atlases":{},"blockers":[]}
	var path: String=directory.path_join("original_ui.json")
	write_bytes(path,JSON.stringify(manifest).to_utf8_buffer())
	return {"root":directory,"sha":FileAccess.get_sha256(path),"png_sha":PACK._sha256(png),"expected":expected,"files":files}

func matches(texture: Texture2D,data: Dictionary) -> bool:
	return texture!=null and texture.get_size()==Vector2(SIZE) and texture.get_image().get_data()==data.expected and texture.get_meta("cocos_premultiplied",false)==true and texture.get_meta("original_embedded_png_sha256","")==data.png_sha

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var data: Dictionary=fixture("user://original_ui_particle_reserve_%d"%OS.get_process_id())
	var pack: RefCounted=PACK.new()
	pack.configure_texture_cache(FRAME_BYTES*2,8)
	check(pack.open(data.root,data.sha).ok,"embedded plist and all source files verify normally")
	var first: Dictionary=pack.particle(PARTICLE)
	check(first.get("ok",false),"actual particle API decodes a supplied embedded RGBA PNG")
	if not first.get("ok",false):finish();return
	var texture: Texture2D=first.texture
	check(matches(texture,data),"every PMA byte, size and original PNG evidence is preserved")
	var reference: WeakRef=weakref(texture)
	var sprite:=Sprite2D.new()
	sprite.texture=texture
	root.add_child(sprite)
	for index: int in range(3):pack.texture({"path":"page_%d.png"%index,"resourceType":0},false)
	var before: Dictionary=pack.cache_stats().instance_texture_cache
	check(before.resident_decoded_bytes_estimate<=FRAME_BYTES*2 and before.evictions>0,"embedded particles share the same bounded texture reserve")
	check(matches(sprite.texture,data),"an active sprite survives reserve eviction unchanged")
	var second: Dictionary=pack.particle(PARTICLE)
	check(second.get("ok",false) and is_same(texture,second.texture) and pack.cache_stats().instance_texture_cache.weak_hits>before.weak_hits,"embedded lookup reuses the exact externally held weak texture")
	first.clear();second.clear();texture=null
	var pack_ref: WeakRef=weakref(pack)
	pack.release_cache_leases()
	pack=null
	check(pack_ref.get_ref()==null and reference.get_ref()!=null and matches(sprite.texture,data),"pack deletion releases cache ownership while active sprites remain valid")
	sprite.queue_free()
	await process_frame
	await process_frame
	check(reference.get_ref()==null,"the last external owner frees the embedded texture")
	var reopened: RefCounted=PACK.new()
	reopened.configure_texture_cache(FRAME_BYTES,8)
	check(reopened.open(data.root,data.sha).ok,"the verified pack can reopen after complete owner retirement")
	var rebuilt: Dictionary=reopened.particle(PARTICLE)
	check(rebuilt.get("ok",false) and matches(rebuilt.texture,data),"rebuilding after eviction preserves original bytes and evidence")
	for member: String in data.files:check(FileAccess.get_sha256(data.root.path_join("originals/"+member))==data.files[member].sha256,"source bytes remain untouched: "+member)
	rebuilt.clear();reopened=null
	finish()

func finish() -> void:
	print("ORIGINAL_UI_PARTICLE_RESERVE_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true,"gpu_measured":false}))
	quit(0 if failures.is_empty() else 1)
