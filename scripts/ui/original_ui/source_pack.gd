extends RefCounted
## Explicit private source pack. Failed replacement preserves the prior pack.
const PIXELS=preload("res://scripts/ui/original_ui/atlas_pixels.gd")
var manifest: Dictionary={}
var root: String=""
var manifest_sha256: String=""
var last_error: String=""
var _pages: Dictionary={}
var _textures: Dictionary={}

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
	for member: String in value.scenes:
		var tree: Variant=value.scenes[member]
		if not tree is Dictionary or not value.files.has(member) or tree.get("_source_sha256")!=value.files[member].sha256:
			return _fail("scene_source_mismatch")
		if not tree.get("_decode_blockers") is Array or not tree._decode_blockers.is_empty(): return _fail("unsupported_source_fields")
	manifest=value
	root=pack_root
	manifest_sha256=expected_sha256
	_pages.clear()
	_textures.clear()
	last_error=""
	return {"ok":true,"scene_count":manifest.scenes.size(),"rendered":false}

func scene(member: String) -> Dictionary:
	return manifest.get("scenes",{}).get(member,{}).duplicate(true)

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

func texture(reference: Dictionary) -> Texture2D:
	if manifest.is_empty() or str(reference.get("path","")).is_empty(): return null
	var plist: String=str(reference.get("plistFile",""))
	var key: String=plist+":"+str(reference.path)
	if _textures.has(key): return _textures[key]
	var original: Image
	if plist.is_empty():
		if int(reference.get("resourceType",0))!=0: return null
		original=_page(_member(str(reference.path)))
	else:
		var atlas: Dictionary=manifest.atlases.get(_member(plist),{})
		var frame: Dictionary=atlas.get("frames",{}).get(str(reference.path),{})
		if frame.is_empty(): return null
		var page: Image=_page(str(atlas.get("page","")))
		if page==null: return null
		var decoded: Dictionary=PIXELS.decode(page,frame)
		if not str(decoded.get("error","")).is_empty():
			last_error=str(decoded.error); return null
		original=decoded.image
	if original==null: return null
	var result:=ImageTexture.create_from_image(original)
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
	_pages[member]=original
	return original

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
