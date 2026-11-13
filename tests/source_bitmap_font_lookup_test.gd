extends SceneTree
## Real pack verification/PNG/font parsing; synthetic private user:// files.
## Instrument copy calls only in in-memory old/new production implementations.
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const PAGES=preload("res://scripts/ui/original_ui/source_pack_page_cache.gd")
const BITMAP=preload("res://scripts/ui/original_ui/source_bitmap_text.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const REF={"path":"fixture.fnt","resourceType":0}
const MEMBER="UI/fixture.fnt"
const OLD_FUNCTION="""func _bitmap_font(reference: Dictionary) -> Dictionary:
	if int(reference.get("resourceType",0))!=0 or not str(reference.get("plistFile","")).is_empty():return {"ok":false,"error":"source_bitmap_resource_type"}
	var member: String=_member(str(reference.get("path","")))
	if not _safe_member(member) or not member.ends_with(".fnt") or not manifest.get("files",{}).has(member):return {"ok":false,"error":"source_bitmap_descriptor_missing"}
	var data: Dictionary
	if _bitmap_fonts.has(member):data=_bitmap_fonts[member].duplicate(true)
	else:
		var path: String=root.path_join("originals").path_join(member)
		if FileAccess.get_sha256(path)!=manifest.files[member].sha256:return {"ok":false,"error":"source_bitmap_descriptor_hash"}
		var parsed: Dictionary=preload("res://scripts/ui/original_ui/source_bitmap_font_data.gd").parse(FileAccess.get_file_as_bytes(path))
		if not parsed.get("ok",false):return parsed
		data=parsed.font_data
	var pages: Dictionary={}
	for page_id: int in data.pages:
		var page_member: String=member.get_base_dir().path_join(str(data.pages[page_id].file))
		if not _safe_member(page_member) or not manifest.files.has(page_member):return {"ok":false,"error":"source_bitmap_page_missing"}
		var original: Texture2D=texture({"path":page_member,"resourceType":0},true)
		if original==null:return {"ok":false,"error":"source_bitmap_page_unavailable"}
		if original.get_width()!=int(data.common.scaleW) or original.get_height()!=int(data.common.scaleH):return {"ok":false,"error":"source_bitmap_page_dimensions"}
		pages[page_id]=original
	data["member"]=member
	# Only parsed descriptors/glyphs belong to this lifetime cache. Returned
	# font data owns its page textures while a screen uses them; keeping pages
	# here would bypass the bounded frame reserve after that screen closes.
	_bitmap_fonts[member]=data.duplicate(true)
	data["page_textures"]=pages
	return {"ok":true,"font_data":data.duplicate(true)}

"""
var pixel_comparisons: int=0
var checks: int=0
var failures: Array[String]=[]
var samples: Array=[]
var directory: String
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func compiled(old: bool) -> GDScript:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_pack.gd")
	var begin: int=source.find("func _bitmap_font(")
	var end: int=source.find("func particle(",begin)
	check(begin>=0 and end>begin,"actual bitmap accessor located")
	var body: String=OLD_FUNCTION if old else source.substr(begin,end-begin)
	body=body.replace("_bitmap_fonts[member].duplicate(true)","_test_copy(_bitmap_fonts[member])")
	body=body.replace("data.duplicate(true)","_test_copy(data)")
	source=source.left(begin)+body+"\n"+source.substr(end)
	source=source.replace("extends RefCounted\n","extends RefCounted\nvar test_copies: int=0\nvar test_glyph_rows: int=0\nvar test_page_calls: int=0\nfunc _test_copy(data: Dictionary) -> Dictionary:\n\ttest_copies+=1\n\ttest_glyph_rows+=data.get(\"glyphs\",{}).size()\n\treturn data.duplicate(true)\n")
	source=source.replace("func texture(reference: Dictionary, cocos_pixels: bool=false) -> Texture2D:\n","func texture(reference: Dictionary, cocos_pixels: bool=false) -> Texture2D:\n\ttest_page_calls+=1\n")
	var script:=GDScript.new();script.source_code=source
	check(script.reload()==OK,"instrumented pack compiles")
	script.bake_enabled=false
	return script
func write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(bytes);f.close()
func fixture(name: String, glyph_count: int, width: int=16, text: String="") -> Dictionary:
	var root_path: String=directory.path_join(name)
	var descriptor: String=text
	if descriptor.is_empty():
		descriptor='info face="Synthetic" size=12 unicode=1\ncommon lineHeight=12 base=10 scaleW=16 scaleH=16 pages=2 packed=0\npage id=0 file="page0.png"\npage id=1 file="page1.png"\nchars count=%d\n'%glyph_count
		for index: int in glyph_count:descriptor+='char id=%d x=0 y=0 width=4 height=4 xoffset=0 yoffset=0 xadvance=5 page=%d chnl=15\n'%[1000+index,index%2]
		descriptor+='kernings count=%d\n'%glyph_count
		for index: int in glyph_count:descriptor+='kerning first=%d second=%d amount=-1\n'%[1000+index,1000+(index+1)%glyph_count]
	write(root_path.path_join("originals/"+MEMBER),descriptor.to_utf8_buffer())
	for index: int in 2:
		var image:=Image.create(width,16,false,Image.FORMAT_RGBA8)
		image.fill(Color(0.2+index*0.2,0.4,0.6,0.5))
		image.save_png(root_path.path_join("originals/UI/page%d.png"%index))
	var files: Dictionary={}
	for member: String in [MEMBER,"UI/page0.png","UI/page1.png"]:
		var path: String=root_path.path_join("originals/"+member)
		files[member]={"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_size(path)}
	var manifest: Dictionary={"schema":"twilight-original-ui-v1","scenes":{},"files":files,"blockers":[],"atlases":{}}
	var manifest_path: String=root_path.path_join("original_ui.json")
	write(manifest_path,JSON.stringify(manifest).to_utf8_buffer())
	return {"root":root_path,"sha":FileAccess.get_sha256(manifest_path)}
func fingerprint(result: Dictionary) -> Dictionary:
	var value: Dictionary=result.duplicate(true)
	if value.get("ok",false):
		var pages: Dictionary={}
		for id: int in value.font_data.page_textures:
			var t: Texture2D=value.font_data.page_textures[id]
			pages[id]={"size":t.get_size(),"pixels":t.get_image().get_data(),"pma":t.get_meta("cocos_premultiplied",null)}
		value.font_data.page_textures=pages
	return value
func no_objects(value: Variant) -> bool:
	if value is Object:return false
	if value is Dictionary:
		for child: Variant in value.values():
			if not no_objects(child):return false
	elif value is Array:
		for child: Variant in value:
			if not no_objects(child):return false
	return true
func open_pair(scripts: Array[Script], source: Dictionary) -> Array[RefCounted]:
	var pair: Array[RefCounted]=[]
	for script: Script in scripts:
		var p: RefCounted=script.new()
		check(p.open(source.root,source.sha).get("ok",false),"actual synthetic pack opens")
		pair.append(p)
	return pair
func reset_counts(pair: Array[RefCounted]) -> void:
	for p: RefCounted in pair:p.test_copies=0;p.test_glyph_rows=0;p.test_page_calls=0
func run() -> void:
	directory="user://bitmap_lookup_%d_%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	HITCH.reset_for_test(directory.path_join("hitches"))
	var pages_enabled: bool=PAGES.enabled
	PAGES.enabled=false
	var scripts: Array[Script]=[compiled(true),compiled(false)]
	for count: int in [4,4096]:_lookup_work(scripts,count)
	_failures(scripts)
	if "--render" in OS.get_cmdline_user_args():await _pixels(scripts)
	check(HITCH._details.has("ui.bitmap_font"),"font preparation has its own inclusive diagnostic")
	PAGES.enabled=pages_enabled
	print("SOURCE_BITMAP_FONT_LOOKUP_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"pixel_comparisons":pixel_comparisons,"android_measured":false}))
	quit(0 if failures.is_empty() else 1)
func _lookup_work(scripts: Array[Script], count: int) -> void:
	var source: Dictionary=fixture("valid%d"%count,count)
	var pair: Array[RefCounted]=open_pair(scripts,source)
	var a: Dictionary=pair[0].bitmap_font(REF);var b: Dictionary=pair[1].bitmap_font(REF)
	check(a.get("ok",false) and b.get("ok",false),"cold lookup returns validated pages")
	check(fingerprint(a)==fingerprint(b),"cold metadata and page pixels are equivalent")
	check(pair[0].test_copies==2 and pair[1].test_copies==1,"cold copies reduced from two to one")
	var pristine: Dictionary=fingerprint(b)
	var cached: Dictionary=pair[1]._bitmap_fonts[MEMBER]
	reset_counts(pair)
	for index: int in 12:
		a=pair[0].bitmap_font(REF);b=pair[1].bitmap_font(REF)
		check(fingerprint(a)==fingerprint(b) and fingerprint(b)==pristine,"warm output equivalent and deterministic")
		check(is_same(cached,pair[1]._bitmap_fonts[MEMBER]),"warm lookup retains cache descriptor identity")
		check(not is_same(b.font_data,cached) and not is_same(b.font_data.glyphs,cached.glyphs),"caller still receives detached nested metadata")
		check(not cached.has("page_textures") and no_objects(cached),"cached metadata cannot retain texture/resource owners")
		b.font_data.glyphs[1000].xadvance=99
		b.font_data.kernings["1000:1001"]=99
		b.font_data.pages[0].file="changed"
		b.font_data.common.scaleW=99
		b.font_data.page_textures.clear()
	check(pair[0].test_copies==36 and pair[1].test_copies==12,"twelve warm lookups avoid twenty-four metadata copies")
	check(pair[0].test_page_calls==24 and pair[1].test_page_calls==24,"every warm lookup still validates both page textures")
	samples.append({"glyphs":count,"warm_lookups":12,"old_copies":pair[0].test_copies,"new_copies":pair[1].test_copies,"old_glyph_rows_copied":pair[0].test_glyph_rows,"new_glyph_rows_copied":pair[1].test_glyph_rows})
	b=pair[1].bitmap_font(REF)
	var bitmap:=BITMAP.new()
	check(bitmap.configure(b.font_data,{"text":String.chr(1000)+String.chr(1001)},Vector2(80,20)).get("ok",false),"actual bitmap renderer consumes returned font")
	b.font_data.glyphs[1000].xadvance=999
	check(bitmap._font_data.glyphs[1000].xadvance==5,"public renderer retains independent caller snapshot")
	var page_ref: WeakRef=weakref(b.font_data.page_textures[0])
	a.clear();b.clear()
	pair[1]._texture_cache.clear(true)
	pair[1].release_cache_leases()
	check(page_ref.get_ref()!=null,"live rendered glyphs retain their page after pack eviction")
	bitmap.free()
	check(page_ref.get_ref()==null,"last caller release drops texture; metadata cache does not pin it")
	for p: RefCounted in pair:p.release_cache_leases()
func _failures(scripts: Array[Script]) -> void:
	var source: Dictionary=fixture("failures",4)
	var pair: Array[RefCounted]=open_pair(scripts,source)
	for reference: Dictionary in [{"path":"fixture.fnt","resourceType":1},{"path":"fixture.fnt","plistFile":"atlas"},{"path":"../fixture.fnt"},{"path":"missing.fnt"},{"path":"page0.png"}]:
		check(pair[0].bitmap_font(reference)==pair[1].bitmap_font(reference),"invalid reference failure remains identical")
	for p: RefCounted in pair:p.manifest.files[MEMBER].sha256="invalid"
	check(pair[0].bitmap_font(REF)==pair[1].bitmap_font(REF) and not pair[1].bitmap_font(REF).ok,"cold descriptor hash rejection preserved")
	for p: RefCounted in pair:check(p._bitmap_fonts.is_empty(),"failed descriptor does not enter cache")
	pair=open_pair(scripts,source)
	for p: RefCounted in pair:p.bitmap_font(REF)
	for p: RefCounted in pair:p.manifest.files.erase("UI/page1.png")
	check(pair[0].bitmap_font(REF)==pair[1].bitmap_font(REF) and pair[1].bitmap_font(REF).error=="source_bitmap_page_missing","warm lookup still rejects missing second page")
	for p: RefCounted in pair:check(not p._bitmap_fonts[MEMBER].has("page_textures"),"partial page failure never stores textures")
	var wrong: Dictionary=fixture("wrong_dimensions",4,8)
	pair=open_pair(scripts,wrong)
	check(pair[0].bitmap_font(REF)==pair[1].bitmap_font(REF) and pair[1].bitmap_font(REF).error=="source_bitmap_page_dimensions","cold page dimension failure preserved")
	for p: RefCounted in pair:check(p._bitmap_fonts.is_empty(),"page validation failure cannot commit parsed metadata")
	var valid: Dictionary=fixture("replacement",4)
	for p: RefCounted in pair:check(p.open(valid.root,valid.sha).get("ok",false),"valid replacement still opens")
	check(fingerprint(pair[0].bitmap_font(REF))==fingerprint(pair[1].bitmap_font(REF)),"replacement output remains equivalent")
	for p: RefCounted in pair:
		check(not p.open(valid.root,"invalid").get("ok",false),"failed replacement rejected")
		check(p.bitmap_font(REF).get("ok",false),"failed replacement preserves earlier font cache")
		p.release_cache_leases()

func _picture(transparent: bool) -> Dictionary:
	var vp:=SubViewport.new();vp.size=Vector2i(96,48);vp.disable_3d=true;vp.transparent_bg=transparent;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var bg:=ColorRect.new();bg.size=Vector2(96,48);bg.color=Color(0.25,0.43,0.81,0.61);vp.add_child(bg)
	var p:=BITMAP.new();p.position=Vector2(8,32);vp.add_child(p)
	return {"vp":vp,"p":p}
func _image_bytes(v: Dictionary) -> PackedByteArray:
	var image: Image=v.vp.get_texture().get_image();image.convert(Image.FORMAT_RGBA8);return image.get_data()
func _pixels(scripts: Array[Script]) -> void:
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility":check(false,"render requires Compatibility GL");return
	var source: Dictionary=fixture("pixels",4)
	var pair: Array[RefCounted]=open_pair(scripts,source)
	for transparent: bool in [false,true]:
		var views: Array[Dictionary]=[_picture(transparent),_picture(transparent)]
		var nonempty: PackedByteArray
		var values: Array[String]=[String.chr(1000)+String.chr(1001),String.chr(1001)+String.chr(1000),String.chr(1002)+String.chr(1003),String.chr(1000),""]
		for phase: int in values.size():
			for index: int in 2:
				var result: Dictionary=pair[index].bitmap_font(REF)
				check(result.get("ok",false),"pixel scene receives actual validated font")
				check(views[index].p.configure(result.font_data,{"text":values[phase]},Vector2(80,20)).get("ok",false),"actual font result configures glyph player")
				views[index].p.set_source_display(Color(0.8,0.5,0.7,0.6))
			await process_frame;await RenderingServer.frame_post_draw
			var actual: PackedByteArray=_image_bytes(views[1])
			check(_image_bytes(views[0])==actual,"cold/warm font accessors yield identical complete RGBA output")
			pixel_comparisons+=1
			if phase==0:nonempty=actual
			if values[phase].is_empty():check(actual!=nonempty,"equivalence includes visible glyph pixels rather than two blank scenes")
		for v: Dictionary in views:v.vp.free()
	for p: RefCounted in pair:p.release_cache_leases()
