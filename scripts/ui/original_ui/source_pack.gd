extends RefCounted
## Explicit private source pack. Failed replacement preserves the prior pack.
const PIXELS=preload("res://scripts/ui/original_ui/atlas_pixels.gd")
var manifest: Dictionary={}
var root: String=""
var manifest_sha256: String=""
var last_error: String=""
var _pages: Dictionary={}
var _textures: Dictionary={}
var _fonts: Dictionary={}
var _bitmap_fonts: Dictionary={}

func open(pack_root: String, expected_sha256: String) -> Dictionary:
	var manifest_path: String=pack_root.path_join("original_ui.json")
	if not FileAccess.file_exists(manifest_path): return _fail("manifest_missing")
	var file:=FileAccess.open(manifest_path,FileAccess.READ)
	if file==null or file.get_length()>128*1024*1024: return _fail("manifest_size_or_access")
	var raw: PackedByteArray=file.get_buffer(file.get_length())
	if expected_sha256.length()!=64 or _sha256(raw)!=expected_sha256: return _fail("manifest_hash_mismatch")
	var value: Variant=JSON.parse_string(raw.get_string_from_utf8())
	if not value is Dictionary or value.get("schema")!="twilight-original-ui-v1": return _fail("manifest_schema")
	if not value.get("scenes") is Dictionary or not value.get("files") is Dictionary or not value.get("atlases") is Dictionary or not value.get("blockers") is Array:
		return _fail("manifest_fields")
	if not value.blockers.is_empty(): return _fail("unresolved_source_dependencies")
	for member: String in value.files:
		if not _safe_member(member): return _fail("unsafe_source_path")
		var entry: Variant=value.files[member]
		if not entry is Dictionary or not entry.get("sha256") is String or not entry.get("bytes") is float and not entry.get("bytes") is int:
			return _fail("invalid_source_entry")
		var path: String=pack_root.path_join("originals").path_join(member)
		if not FileAccess.file_exists(path): return _fail("source_missing:"+member)
		var source:=FileAccess.open(path,FileAccess.READ)
		if source==null or source.get_length()!=int(entry.bytes) or FileAccess.get_sha256(path)!=entry.sha256:
			return _fail("source_hash_or_size:"+member)
		if member.ends_with(".fnt") and not _font_pages_present(path,member,value.files):
			return _fail("bitmap_font_page_dependencies:"+member)
	for member: String in value.scenes:
		var tree: Variant=value.scenes[member]
		if not tree is Dictionary or not value.files.has(member) or tree.get("_source_sha256")!=value.files[member].sha256:
			return _fail("scene_source_mismatch")
		if not tree.get("_decode_blockers") is Array or not tree._decode_blockers.is_empty(): return _fail("unsupported_source_fields")
		if bool(tree.get("_partial_source_scene",false)):
			if not tree.get("_selected_source_offsets") is Array or tree._selected_source_offsets.is_empty():return _fail("partial_source_node_scope_missing")
			if not value.get("node_scopes") is Dictionary or value.node_scopes.get(member)!=tree._selected_source_offsets:return _fail("partial_source_node_scope_mismatch")
	if value.has("layout_sources"):
		if not value.layout_sources is Dictionary:return _fail("layout_source_fields")
		for member: String in value.layout_sources:
			var layout: Variant=value.layout_sources[member]
			if not layout is Dictionary or not value.files.has(member) or layout.get("_source_sha256")!=value.files[member].sha256:return _fail("layout_source_identity_mismatch")
			if not layout.get("_decode_blockers") is Array or not layout._decode_blockers.is_empty():return _fail("layout_source_fields")
	manifest=value
	root=pack_root
	manifest_sha256=expected_sha256
	_pages.clear()
	_textures.clear()
	_fonts.clear()
	_bitmap_fonts.clear()
	last_error=""
	return {"ok":true,"scene_count":manifest.scenes.size(),"rendered":false}

static func _font_pages_present(path: String, member: String, files: Dictionary) -> bool:
	var text: String=FileAccess.get_file_as_string(path)
	var common:=RegEx.new()
	common.compile('(?m)^common [^\r\n]*\\bpages=(\\d+)\\b')
	var common_match: RegExMatch=common.search(text)
	if common_match==null:return false
	var expected: int=int(common_match.get_string(1))
	if expected<1:return false
	var page_pattern:=RegEx.new()
	page_pattern.compile('(?m)^page\\s+id=(\\d+)\\s+file="([^"]+)"\\s*$')
	var pages: Array[RegExMatch]=page_pattern.search_all(text)
	if pages.size()!=expected:return false
	var seen: Dictionary={}
	for page: RegExMatch in pages:
		var id: int=int(page.get_string(1))
		if id<0 or id>=expected or seen.has(id):return false
		seen[id]=true
		var resource: String=member.get_base_dir().path_join(page.get_string(2))
		if not _safe_member(resource) or not files.has(resource):return false
	return true

func scene(member: String) -> Dictionary:
	return manifest.get("scenes",{}).get(member,{}).duplicate(true)

func layout_source(member: String) -> Dictionary:
	# Parent reference geometry is not an entry scene or gameplay use. Its
	# optional siblings are neither loaded nor marked dependency-complete.
	return manifest.get("layout_sources",{}).get(member,{}).duplicate(true)

func nodes_named(member: String, source_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var tree: Dictionary=scene(member)
	if not tree.is_empty(): _find(tree.get("nodeTree",{}),source_name,result)
	return result

func _find(node: Dictionary, source_name: String, result: Array[Dictionary]) -> void:
	var options: Dictionary=node.get("options",{}) if node.get("options") is Dictionary else {}
	var widget: Dictionary=options.get("widgetOptions",options.get("nodeOptions",options))
	if widget.get("name")==source_name: result.append(node)
	for child: Dictionary in node.get("children",[]): _find(child,source_name,result)

func texture(reference: Dictionary, cocos_pixels: bool=false) -> Texture2D:
	if manifest.is_empty() or str(reference.get("path","")).is_empty(): return null
	var plist: String=str(reference.get("plistFile",""))
	var key: String=plist+":"+str(reference.path)+":"+str(cocos_pixels)
	if _textures.has(key): return _textures[key]
	var original: Image
	var premultiplied: bool=false
	if plist.is_empty():
		if int(reference.get("resourceType",0))!=0: return null
		original=_page(_member(str(reference.path)))
		if original!=null:premultiplied=bool(original.get_meta("cocos_png_pma",false))
	else:
		var atlas: Dictionary=manifest.atlases.get(_member(plist),{})
		var frame: Dictionary=atlas.get("frames",{}).get(str(reference.path),{})
		if frame.is_empty(): return null
		var page: Image=_page(str(atlas.get("page","")))
		if page==null: return null
		premultiplied=bool(page.get_meta("cocos_png_pma",false))
		var decoded: Dictionary=PIXELS.decode(page,frame)
		if not str(decoded.get("error","")).is_empty():
			last_error=str(decoded.error); return null
		original=decoded.image
	if original==null: return null
	if cocos_pixels and premultiplied:
		original=cocos_premultiply(original)
	var result:=ImageTexture.create_from_image(original)
	result.set_meta("cocos_premultiplied",cocos_pixels and premultiplied)
	_textures[key]=result
	return result

func _page(member: String) -> Image:
	if _pages.has(member): return _pages[member]
	if not _safe_member(member) or not manifest.files.has(member): return null
	var path: String=root.path_join("originals").path_join(member)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=manifest.files[member].sha256:
		last_error="source_hash_or_size:"+member; return null
	var original: Image=Image.load_from_file(path)
	if original==null or original.is_empty(): return null
	original.convert(Image.FORMAT_RGBA8)
	original.set_meta("cocos_png_pma",_png_premultiplies(path))
	_pages[member]=original
	return original

static func cocos_premultiply(original: Image) -> Image:
	var pixels: PackedByteArray=original.get_data()
	for at: int in range(0,pixels.size(),4):
		var alpha_plus_one: int=int(pixels[at+3])+1
		for channel: int in range(3):pixels[at+channel]=(int(pixels[at+channel])*alpha_plus_one)>>8
	return Image.create_from_data(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8,pixels)

static func _png_premultiplies(path: String) -> bool:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<33:return false
	var head: PackedByteArray=file.get_buffer(26)
	if head.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]):return false
	var color_type: int=head[25]
	if color_type==6:return true
	if color_type not in [2,3]:return false
	# Cocos expands palette/RGB tRNS to RGBA before premultiplication.
	file.big_endian=true
	file.seek(8)
	while file.get_position()+12<=file.get_length():
		var length: int=file.get_32()
		var kind: String=file.get_buffer(4).get_string_from_ascii()
		if kind=="tRNS":return true
		if kind in ["IDAT","IEND"]:return false
		if length>file.get_length()-file.get_position()-4:return false
		file.seek(file.get_position()+length+4)
	return false

static func _member(path: String) -> String:
	return path if path.begins_with("UI/") else "UI/"+path

static func _safe_member(path: String) -> bool:
	if not path.begins_with("UI/") or path.contains("\\") or path.contains(":"): return false
	for part: String in path.split("/"):
		if part in ["",".",".."]: return false
	return true

static func _sha256(raw: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(raw)
	return context.finish().hex_encode()

func _fail(reason: String) -> Dictionary:
	last_error=reason
	return {"ok":false,"error":reason}

func font(reference: Dictionary) -> FontFile:
	if int(reference.get("resourceType",0))!=0 or not str(reference.get("plistFile","")).is_empty(): return null
	var member: String=_member(str(reference.get("path","")))
	if not _safe_member(member) or not manifest.get("files",{}).has(member): return null
	if _fonts.has(member): return _fonts[member]
	var path: String=root.path_join("originals").path_join(member)
	if FileAccess.get_sha256(path)!=manifest.files[member].sha256:
		last_error="source_font_hash:"+member; return null
	var original:=FontFile.new()
	original.data=FileAccess.get_file_as_bytes(path)
	original.allow_system_fallback=false
	if original.get_supported_chars().is_empty():
		last_error="source_font_invalid:"+member; return null
	_fonts[member]=original
	return original

func bitmap_font(reference: Dictionary) -> Dictionary:
	if int(reference.get("resourceType",0))!=0 or not str(reference.get("plistFile","")).is_empty():return {"ok":false,"error":"source_bitmap_resource_type"}
	var member: String=_member(str(reference.get("path","")))
	if not _safe_member(member) or not member.ends_with(".fnt") or not manifest.get("files",{}).has(member):return {"ok":false,"error":"source_bitmap_descriptor_missing"}
	if _bitmap_fonts.has(member):return {"ok":true,"font_data":_bitmap_fonts[member].duplicate(true)}
	var path: String=root.path_join("originals").path_join(member)
	if FileAccess.get_sha256(path)!=manifest.files[member].sha256:return {"ok":false,"error":"source_bitmap_descriptor_hash"}
	var parsed: Dictionary=preload("res://scripts/ui/original_ui/source_bitmap_font_data.gd").parse(FileAccess.get_file_as_bytes(path))
	if not parsed.get("ok",false):return parsed
	var data: Dictionary=parsed.font_data
	var pages: Dictionary={}
	for page_id: int in data.pages:
		var page_member: String=member.get_base_dir().path_join(str(data.pages[page_id].file))
		if not _safe_member(page_member) or not manifest.files.has(page_member):return {"ok":false,"error":"source_bitmap_page_missing"}
		var original: Texture2D=texture({"path":page_member,"resourceType":0},true)
		if original==null:return {"ok":false,"error":"source_bitmap_page_unavailable"}
		if original.get_width()!=int(data.common.scaleW) or original.get_height()!=int(data.common.scaleH):return {"ok":false,"error":"source_bitmap_page_dimensions"}
		pages[page_id]=original
	data["page_textures"]=pages
	data["member"]=member
	_bitmap_fonts[member]=data
	return {"ok":true,"font_data":data.duplicate(true)}

func particle(reference: Dictionary) -> Dictionary:
	if int(reference.get("resourceType",0))!=0 or not str(reference.get("plistFile","")).is_empty():return {"ok":false,"error":"particle_resource_type"}
	var member: String=_member(str(reference.get("path","")))
	if not _safe_member(member) or not manifest.get("files",{}).has(member):return {"ok":false,"error":"particle_source_missing"}
	var path: String=root.path_join("originals").path_join(member)
	if FileAccess.get_sha256(path)!=manifest.files[member].sha256:return {"ok":false,"error":"particle_source_hash"}
	var decoded: Dictionary=preload("res://scripts/ui/original_ui/source_particle_data.gd").parse(FileAccess.get_file_as_bytes(path))
	if not decoded.ok:return decoded
	var texture_member: String=member.get_base_dir().path_join(str(decoded.values.get("textureFileName","")))
	var original: Texture2D
	if _safe_member(texture_member) and manifest.files.has(texture_member):
		original=texture({"path":texture_member},true)
	if original==null and not str(decoded.values.get("textureImageData","")).is_empty():
		original=_embedded_particle_texture(member,str(decoded.values.textureImageData))
		texture_member=member+"#textureImageData"
	if original==null:return {"ok":false,"error":"particle_texture_missing_or_unsupported:"+texture_member}
	return {"ok":true,"values":decoded.values,"texture":original,"member":member,"texture_member":texture_member}

func _embedded_particle_texture(member: String, encoded: String) -> Texture2D:
	var key: String="embedded_particle:"+member
	if _textures.has(key):return _textures[key]
	var compressed: PackedByteArray=Marshalls.base64_to_raw(encoded)
	if compressed.size()<2:return null
	var mode: int=FileAccess.COMPRESSION_GZIP if compressed[0]==31 and compressed[1]==139 else FileAccess.COMPRESSION_DEFLATE
	var png: PackedByteArray=compressed.decompress_dynamic(32*1024*1024,mode)
	# The supplied embedded original is RGBA8 PNG. Other formats stay explicit
	# until their original Cocos decode semantics have been verified.
	if png.size()<33 or png.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]) or png[24]!=8 or png[25]!=6:return null
	var width: int=(int(png[16])<<24)|(int(png[17])<<16)|(int(png[18])<<8)|int(png[19])
	var height: int=(int(png[20])<<24)|(int(png[21])<<16)|(int(png[22])<<8)|int(png[23])
	if width<=0 or height<=0 or width>8192 or height>8192 or width*height>16*1024*1024:return null
	var original:=Image.new()
	if original.load_png_from_buffer(png)!=OK:return null
	original.convert(Image.FORMAT_RGBA8)
	var result:=ImageTexture.create_from_image(cocos_premultiply(original))
	result.set_meta("cocos_premultiplied",true)
	result.set_meta("original_embedded_png_sha256",_sha256(png))
	_textures[key]=result
	return result


func declared_system_font(family: String) -> FontFile:
	# Cocos uses the serialized fontName when no fontResource was declared.
	# Resolve only that exact installed family; never choose a replacement.
	if family.is_empty() or not OS.get_system_fonts().has(family):
		last_error="declared_system_font_unavailable:"+family
		return null
	var key: String="declared_system_font:"+family
	if _fonts.has(key):return _fonts[key]
	var path: String=OS.get_system_font_path(family)
	if path.is_empty() or not FileAccess.file_exists(path):
		last_error="declared_system_font_unavailable:"+family
		return null
	var original:=FontFile.new()
	original.data=FileAccess.get_file_as_bytes(path)
	original.allow_system_fallback=false
	if original.get_font_name()!=family or original.get_supported_chars().is_empty():
		last_error="declared_system_font_identity_mismatch:"+family
		return null
	original.set_meta("source_font_kind","declared_host_system_font")
	original.set_meta("original_declared_system_font",family)
	_fonts[key]=original
	return original
