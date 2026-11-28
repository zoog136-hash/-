extends SceneTree
## Standalone probe for scripts/ui/original_ui/source_pack_page_cache.gd.
## Synthetic pages only (no private packs). Does not load Main.tscn.
## Run: godot --headless --path <repo> --script res://tests/original_ui_page_cache_test.gd
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const CACHE=preload("res://scripts/ui/original_ui/source_pack_page_cache.gd")

var failures: Array[String]=[]
var passes: int=0

func check(ok: bool, label: String) -> void:
	if ok: passes+=1
	else: failures.append(label)
	print(("PASS " if ok else "FAIL ")+label)

func _write_pack(dir: String, variant: int) -> String:
	DirAccess.make_dir_recursive_absolute(dir.path_join("originals/UI"))
	# Page A: RGBA (PNG color type 6 -> Cocos PMA), varied alpha incl. 0 and 255.
	var a:=Image.create(64,48,false,Image.FORMAT_RGBA8)
	for y: int in 48:
		for x: int in 64:
			a.set_pixel(x,y,Color8((x*37+y*11)%256,(x*5+y*53)%256,(x*91+y*7)%256,[0,1,77,128,200,255][(x+y*3)%6]))
	a.save_png(dir.path_join("originals/UI/a.png"))
	# Page B: RGB without tRNS (color type 2 -> no PMA).
	var b:=Image.create(20,16,false,Image.FORMAT_RGB8)
	for y: int in 16:
		for x: int in 20: b.set_pixel(x,y,Color8((x*13)%256,(y*17)%256,(x*y)%256))
	b.save_png(dir.path_join("originals/UI/b.png"))
	var files: Dictionary={}
	for member: String in ["UI/a.png","UI/b.png"]:
		var path: String=dir.path_join("originals").path_join(member)
		files[member]={"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size()}
	var manifest: Dictionary={"schema":"twilight-original-ui-v1","scenes":{},"files":files,"blockers":[],"probe_variant":variant,
		"atlases":{"UI/a.plist":{"page":"UI/a.png","frames":{
			"plain":{"rect":[0,0,10,12],"source_rect":[0,0,10,12],"source_size":[10,12]},
			"trim":{"rect":[12,0,8,6],"source_rect":[3,2,8,6],"source_size":[16,12]},
			"rot":{"rect":[24,0,10,7],"rotated":true,"source_rect":[1,1,10,7],"source_size":[12,9]},
			"rot_full":{"rect":[36,5,10,7],"rotated":true,"source_rect":[0,0,10,7],"source_size":[10,7]}}}}}
	var raw: PackedByteArray=JSON.stringify(manifest).to_utf8_buffer()
	var f:=FileAccess.open(dir.path_join("original_ui.json"),FileAccess.WRITE)
	f.store_buffer(raw); f.close()
	return FileAccess.get_sha256(dir.path_join("original_ui.json"))

const REFS: Array[Dictionary]=[
	{"plistFile":"a.plist","path":"plain"},{"plistFile":"a.plist","path":"trim"},{"plistFile":"a.plist","path":"rot"},
	{"path":"a.png","resourceType":0},{"path":"b.png","resourceType":0},{"plistFile":"a.plist","path":"rot_full"}]

func _fingerprint(t: Texture2D) -> Dictionary:
	var img: Image=t.get_image()
	return {"size":img.get_size(),"format":img.get_format(),"data":img.get_data(),"pma":t.get_meta("cocos_premultiplied",null)}

# Independent of source_pack.gd: load, decode, premultiply directly.
func _baseline(dir: String, ref: Dictionary, cocos: bool) -> Dictionary:
	var member: String="UI/a.png" if ref.has("plistFile") or ref.path=="a.png" else "UI/b.png"
	var page: Image=Image.load_from_file(dir.path_join("originals").path_join(member))
	var pma: bool=member=="UI/a.png"
	page.convert(Image.FORMAT_RGBA8)
	var img: Image=page
	if ref.has("plistFile"):
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("original_ui.json")))
		var frame: Dictionary=manifest.atlases["UI/a.plist"].frames[ref.path]
		var rect: Array=frame.rect
		var rotated: bool=frame.get("rotated",false)
		var crop: Image=page.get_region(Rect2i(rect[0],rect[1],rect[3] if rotated else rect[2],rect[2] if rotated else rect[3]))
		if rotated:crop.rotate_90(COUNTERCLOCKWISE)
		img=Image.create_empty(int(frame.source_size[0]),int(frame.source_size[1]),false,Image.FORMAT_RGBA8)
		img.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(frame.source_rect[0],frame.source_rect[1]))
	if cocos and pma: img=PACK.cocos_premultiply(img)
	return {"size":img.get_size(),"format":img.get_format(),"data":img.get_data(),"pma":cocos and pma}

func _all(pack: RefCounted) -> Dictionary:
	var out: Dictionary={}
	for i: int in REFS.size():
		for cocos: bool in [false,true]: out["%d:%s"%[i,cocos]]=pack.texture(REFS[i],cocos)
	return out

func _verify_cold_pngs(base: String) -> void:
	# Tiny synthetic RGB/palette fixtures with and without PNG tRNS; the
	# pre-existing suite covers RGBA, atlas crop/rotate and PMA frame pixels.
	var encoded: Array[String]=[
		"iVBORw0KGgoAAAANSUhEUgAAAAMAAAADCAIAAADZSiLoAAAAF0lEQVR4nGMMMHdjYGBgYGBgYoABBAsAFu4A044Koo0AAAAASUVORK5CYII=",
		"iVBORw0KGgoAAAANSUhEUgAAAAMAAAADCAIAAADZSiLoAAAABnRSTlMAUAA3AEboLt/qAAAAF0lEQVR4nGMMMHdjYGBgYGBgYoABBAsAFu4A044Koo0AAAAASUVORK5CYII=",
		"iVBORw0KGgoAAAANSUhEUgAAAAMAAAADAQMAAABs5if8AAAABlBMVEVQN0YAAAAEl9JPAAAADklEQVR4nGNgYGBgYAAAAAYAAXKCmeoAAAAASUVORK5CYII=",
		"iVBORw0KGgoAAAANSUhEUgAAAAMAAAADAQMAAABs5if8AAAABlBMVEVQN0YAAAAEl9JPAAAAAXRSTlMAQObYZgAAAA5JREFUeJxjYGBgYGAAAAAGAAFygpnqAAAAAElFTkSuQmCC",
	]
	var pack=PACK.new()
	for i: int in encoded.size():
		var member: String="UI/test%d.png"%i
		var path: String=base.path_join(member.get_file())
		var file:=FileAccess.open(path,FileAccess.WRITE)
		file.store_buffer(Marshalls.base64_to_raw(encoded[i]))
		file.close()
		var sha: String=FileAccess.get_sha256(path)
		var prechange: Image=Image.load_from_file(path)
		var actual: Image=pack._read_verified_page(path,sha,member)
		prechange.convert(Image.FORMAT_RGBA8)
		check(actual!=null and actual.get_data()==prechange.get_data(),"buffer and file loaders read identical RGB/palette pixels "+str(i))
		check(actual!=null and actual.get_meta("cocos_png_pma",null)==(i%2==1) and PACK._png_premultiplies(path)==(i%2==1),"same Cocos tRNS detection as file parser "+str(i))
		check(pack._read_verified_page(path,"0".repeat(64),member)==null and pack.last_error=="source_hash_or_size:"+member,"wrong hash fails closed "+str(i))

## The public fixture supplies its own original pixels and has no release-approved catalog.
func _verify_prepared_frames(dir: String, pin: String) -> void:
	var pack := PACK.new()
	check(pack.open(dir, pin).ok, "open settings fixture")
	var ref: Dictionary = REFS[2]
	var expected: Dictionary = _baseline(dir, ref, true)
	var atlas: Dictionary = pack.manifest.atlases["UI/a.plist"]
	var frame: Dictionary = atlas.frames.rot
	var raw: PackedByteArray = expected.data
	var digest := PACK._sha256(raw)
	var geometry := [frame.rect, frame.source_rect, frame.source_size, true]
	var entry := {"page": atlas.page, "source_sha256": pack.manifest.files[atlas.page].sha256,
		"frames": {"rot": {"geometry": geometry, "rgba_sha256": digest}}}
	var pages := {"UI/a.plist": entry}
	var compressed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var ranges := {digest: [0, compressed.size()]}
	var reader := PACK.SETTINGS_FRAMES.new()
	var doc := JSON.stringify({"schema": reader.SCHEMA, "manifest_sha256": pin,
		"catalog": JSON.stringify(pages), "ranges": ranges}).to_utf8_buffer()
	var blob := PackedByteArray()
	blob.resize(4)
	blob.encode_u32(0, doc.size())
	blob.append_array(doc)
	blob.append_array(compressed)
	var path := dir.path_join(reader.MEMBER)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(blob)
	file.close()
	check(not reader.load_bundle(dir, pin, PACK._sha256(blob)), "matching outer pin cannot authorize new pixels or geometry")
	check(not reader.load_bundle(dir, pin, "0".repeat(64)), "corrupt or wrong pack is rejected")
	# Exercise the post-authentication decoder with an independent RGBA oracle.
	reader._atlases = pages
	reader._ranges = ranges
	reader._bytes = compressed
	pack._settings_frames = reader
	pack._settings_frames_checked = true
	pack.set_settings_frame_scope(true)
	var tex := pack.texture(ref, true)
	check(tex != null and _fingerprint(tex).data == raw and tex.get_meta("cocos_premultiplied"), "decoded Zstd fixture matches rotated, padded PMA pixels")
	check(pack._pages.is_empty() and is_same(tex, pack.texture(ref, true)), "prepared texture uses the resident cache without decoding a page")
	var other_frame := frame.duplicate(true)
	other_frame.source_rect = [0, 0, 10, 7]
	check(reader.frame_image("UI/a.plist", "rot", atlas, other_frame, pack) == null, "changed source geometry rejected")
	reader._ranges[digest] = [compressed.size(), 1]
	check(reader.frame_image("UI/a.plist", "rot", atlas, frame, pack) == null, "invalid record range rejected")
	var wrong := raw.duplicate()
	wrong[0] ^= 0xff
	reader._bytes = wrong.compress(FileAccess.COMPRESSION_ZSTD)
	reader._ranges[digest] = [0, reader._bytes.size()]
	check(reader.frame_image("UI/a.plist", "rot", atlas, frame, pack) == null, "different valid Zstd pixels rejected by reviewed digest")
	var straight := pack.texture(ref, false)
	check(straight != null and _fingerprint(straight).data == _baseline(dir, ref, false).data, "straight-alpha mode keeps the original source decoder")
	pack.release_cache_leases()
	check(pack._settings_frames == null and not pack._settings_frames_checked, "lease release drops optional bytes and source-page verification")
	check(is_same(tex, pack.texture(ref, true)) and not pack._settings_frames_checked, "warm settings texture skips all preparation file I/O")
	pack.set_settings_frame_scope(false)
	CACHE.reset()

func _init() -> void:
	var base: String=ProjectSettings.globalize_path("user://original_ui_page_cache_test_synthetic")
	var root1: String=base.path_join("pack1"); var root2: String=base.path_join("pack2")
	var sha1: String=_write_pack(root1,1); var sha2: String=_write_pack(root2,2)
	_verify_cold_pngs(base)
	_verify_prepared_frames(root1,sha1)
	check(sha1!=sha2,"synthetic packs have distinct manifest identity")
	var key_a1: String=CACHE.page_key(sha1,root1,"UI/a.png",JSON.parse_string(FileAccess.get_file_as_string(root1.path_join("original_ui.json"))).files["UI/a.png"].sha256)

	# 1. Unshared reference path (cache disabled == previous behaviour).
	CACHE.reset(); CACHE.enabled=false
	var legacy=PACK.new(); check(legacy.open(root1,sha1).ok,"legacy open")
	var legacy_tex: Dictionary=_all(legacy)
	var legacy_fp: Dictionary={}
	for k: String in legacy_tex: legacy_fp[k]=_fingerprint(legacy_tex[k])
	check(CACHE.stats().page_stores==0 and CACHE.stats().live_pages==0,"disabled cache stores nothing")
	legacy=null; legacy_tex.clear()
	for i: int in REFS.size():
		for cocos: bool in [false,true]:
			var b: Dictionary=_baseline(root1,REFS[i],cocos); var l: Dictionary=legacy_fp["%d:%s"%[i,cocos]]
			check(b.size==l.size and b.format==l.format and b.data==l.data and b.pma==l.pma,"legacy == independent decode %s cocos=%s"%[REFS[i].path,cocos])

	# 2. Two UI instances on the same pack share pages and frames.
	CACHE.reset()
	var p1=PACK.new(); var p2=PACK.new()
	check(p1.open(root1,sha1).ok and p2.open(root1,sha1).ok,"shared open x2")
	var t1: Dictionary=_all(p1); var t2: Dictionary=_all(p2)
	var all_same: bool=true
	for k: String in t1: all_same=all_same and t1[k]!=null and is_same(t1[k],t2[k])
	check(all_same,"two instances receive the identical frame texture objects")
	check(p2._pages.is_empty(),"second instance needed no page at all (every frame was a shared hit)")
	# A screen decoding a frame nobody holds yet acquires the shared page.
	check(is_same(p2._page("UI/a.png"),p1._pages["UI/a.png"]) and is_same(p2._page("UI/b.png"),p1._pages["UI/b.png"]),"two instances share CPU page images")
	var s: Dictionary=CACHE.stats()
	check(s.page_stores==2 and s.live_pages==2 and s.live_leases==4 and CACHE.page_leases(key_a1)==2,"one decode per page, two live leases each: "+str(s))
	check(s.live_bytes==64*48*4+20*16*4,"live bytes = RGBA8 page payload")

	# 3. Pixel modes stay separate.
	var a_pma: Texture2D=t1["0:true"]; var a_straight: Texture2D=t1["0:false"]
	check(not is_same(a_pma,a_straight) and a_pma.get_image().get_data()!=a_straight.get_image().get_data(),"cocos_pixels true/false are distinct frames on a PMA page")
	check(a_pma.get_meta("cocos_premultiplied")==true and a_straight.get_meta("cocos_premultiplied")==false and t1["4:true"].get_meta("cocos_premultiplied")==false,"PMA meta per mode/page preserved")

	# 4. A different pack (manifest identity) stays separate even with identical page bytes.
	var p3=PACK.new(); check(p3.open(root2,sha2).ok,"second pack open")
	var t3: Dictionary=_all(p3)
	var none_shared: bool=true
	for k: String in t3: none_shared=none_shared and not is_same(t3[k],t1[k])
	check(none_shared and not is_same(p3._pages["UI/a.png"],p1._pages["UI/a.png"]),"different pack: no frame/page sharing")
	check(CACHE.stats().page_stores==4,"different pack decodes its own pages")

	# 5. Byte/geometry identity: shared path == unshared path, for every frame and mode.
	var identical: bool=true
	for k: String in legacy_fp:
		for tex: Dictionary in [t1,t2,t3]:
			var fp: Dictionary=_fingerprint(tex[k])
			identical=identical and fp.size==legacy_fp[k].size and fp.format==legacy_fp[k].format and fp.data==legacy_fp[k].data and fp.pma==legacy_fp[k].pma
	check(identical,"all shared frames byte/size/format/PMA-identical to unshared path")

	# 6. resourceType guard is not bypassed by a shared hit.
	var p5=PACK.new(); p5.open(root1,sha1)
	check(p5.texture({"path":"b.png","resourceType":1},false)==null,"resourceType!=0 still rejected despite shared frame")
	p5=null

	# 7. Failed reopen preserves the prior pack and its leases.
	var before: int=CACHE.page_leases(key_a1)
	check(not p1.open(root1,"0".repeat(64)).ok and p1._pages.has("UI/a.png") and CACHE.page_leases(key_a1)==before,"failed open keeps prior pages and leases")

	# 8. Closing releases leases; idle only after the last owner.
	p1.release_cache_leases()
	check(CACHE.page_leases(key_a1)==1 and p1._pages.is_empty(),"close releases this screen's lease only")
	p1.release_cache_leases()
	check(CACHE.page_leases(key_a1)==1,"double release is a no-op")
	p2=null  # predelete releases
	s=CACHE.stats()
	check(CACHE.page_leases(key_a1)==0 and s.idle_pages==2 and s.live_pages==2,"freed instance releases leases; pack1 pages idle, pack2 live: "+str(s))

	# 9. Idle LRU respects budget, never evicts live pages.
	var page_a_bytes: int=64*48*4
	CACHE.budget_bytes=s.live_bytes+page_a_bytes  # room for live + one idle page A
	CACHE.trim_idle()
	s=CACHE.stats()
	check(s.cache_owned_bytes<=CACHE.budget_bytes and s.live_pages==2 and s.idle_pages==1,"idle trimmed to budget, live kept: "+str(s))
	CACHE.budget_bytes=0; CACHE.trim_idle(); s=CACHE.stats()
	check(s.idle_pages==0 and s.live_pages==2 and s.live_bytes>0,"budget 0: all idle evicted, live pages survive")
	# LRU order: touch pages so that b is older than a, then evict one.
	CACHE.budget_bytes=CACHE.DEFAULT_BUDGET_BYTES
	var p6=PACK.new(); p6.open(root1,sha1)
	# Frames are still shared hits (p1 holds them), so decode pages directly.
	p6._page("UI/a.png"); p6._page("UI/b.png"); p6._page("UI/a.png")
	p6.release_cache_leases()
	CACHE.budget_bytes=CACHE.stats().live_bytes+page_a_bytes; CACHE.trim_idle()
	check(CACHE.page_leases(key_a1)==0 and CACHE.stats().idle_pages==1,"actual latest use of a borrowed page orders the idle reserve")

	# 10. Re-decode after eviction is byte-identical; frames shared while alive only.
	t1.clear(); t2.clear(); legacy_tex.clear(); a_pma=null; a_straight=null
	p1=null; p6=null
	var alive_before: int=CACHE.stats().shared_frames_alive
	t3.clear(); p3=null
	check(CACHE.stats().shared_frames_alive==0 and alive_before>0,"frame registry does not retain textures (alive %d -> 0)"%alive_before)
	CACHE.budget_bytes=0; CACHE.trim_idle()
	check(CACHE.stats().cache_owned_bytes==0,"everything released after all owners closed")
	CACHE.budget_bytes=CACHE.DEFAULT_BUDGET_BYTES
	var p7=PACK.new(); p7.open(root1,sha1)
	var t7: Dictionary=_all(p7)
	var again: bool=true
	for k: String in legacy_fp: again=again and _fingerprint(t7[k]).data==legacy_fp[k].data
	check(again,"rebuilt after full eviction: identical bytes")
	print("CACHE_STATS ",p7.cache_stats())
	t7.clear(); p7=null
	CACHE.reset()
	print("PROBE_RESULT passes=%d failures=%d"%[passes,failures.size()])
	print("ORIGINAL_UI_PAGE_CACHE_RESULT "+JSON.stringify({"checks":passes,"failures":failures}))
	for f: String in failures: print("  failed: ",f)
	quit(0 if failures.is_empty() else 1)
