extends RefCounted
## The part of the original UI pack open() whose result is stored in the
## device bake: manifest content validation, number normalization and the
## record layout. The bake key is the code of THIS file (source_pack.gd
## bake_key_for), so connecting another window (source_pack.gd and its
## CODE_EXTERNAL_TEXTURE_NODES, applied after loading by _adopt) no longer
## invalidates the bake: before, every app update that touched source_pack.gd
## re-verified and re-wrote the whole UI pack on the phone ("원작 UI 정리").
## Change anything here and the key changes with it.
const FORMAT := "original_ui_pack.v2"

## "" when `value` is a complete verified manifest (it is normalized in place:
## node scopes and external texture offsets become ints), else the failure code.
static func verify(value: Variant, pack_root: String) -> String:
	if not value is Dictionary or value.get("schema")!="twilight-original-ui-v1": return "manifest_schema"
	if not value.get("scenes") is Dictionary or not value.get("files") is Dictionary or not value.get("atlases") is Dictionary or not value.get("blockers") is Array:
		return "manifest_fields"
	if not value.blockers.is_empty(): return "unresolved_source_dependencies"
	var files_problem: String=_files_intact(pack_root,value.files)
	if not files_problem.is_empty(): return files_problem
	for member: String in value.scenes:
		var tree: Variant=value.scenes[member]
		if not tree is Dictionary or not value.files.has(member) or tree.get("_source_sha256")!=value.files[member].sha256:
			return "scene_source_mismatch"
		if not tree.get("_decode_blockers") is Array or not tree._decode_blockers.is_empty(): return "unsupported_source_fields"
		if bool(tree.get("_partial_source_scene",false)):
			if not tree.get("_selected_source_offsets") is Array or tree._selected_source_offsets.is_empty():return "partial_source_node_scope_missing"
			if not value.get("node_scopes") is Dictionary or value.node_scopes.get(member)!=tree._selected_source_offsets:return "partial_source_node_scope_mismatch"
	if value.has("layout_sources"):
		if not value.layout_sources is Dictionary:return "layout_source_fields"
		for member: String in value.layout_sources:
			var layout: Variant=value.layout_sources[member]
			if not layout is Dictionary or not value.files.has(member) or layout.get("_source_sha256")!=value.files[member].sha256:return "layout_source_identity_mismatch"
			if not layout.get("_decode_blockers") is Array or not layout._decode_blockers.is_empty():return "layout_source_fields"
	if value.has("externally_bound_texture_nodes"):
		if not value.externally_bound_texture_nodes is Dictionary:return "external_texture_nodes_shape"
		for member: String in value.externally_bound_texture_nodes:
			var offsets: Variant=value.externally_bound_texture_nodes[member]
			var scope: Variant=value.get("node_scopes",{}).get(member)
			if not offsets is Array or offsets.is_empty() or not scope is Array:return "external_texture_requires_explicit_node_scope"
			var unique: Dictionary={}
			for offset: Variant in offsets:
				if typeof(offset) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(offset)) or float(offset)!=floor(float(offset)) or offset not in scope or unique.has(int(offset)):return "external_texture_node_scope_mismatch"
				unique[int(offset)]=true
	# JSON numbers load as floats, and an Array of floats never has() an int
	# offset. Every consumer asks with int source offsets: store them as ints.
	if value.get("node_scopes") is Dictionary:
		for member: String in value.node_scopes:value.node_scopes[member]=_offsets(value.node_scopes[member])
	if value.get("externally_bound_texture_nodes") is Dictionary:
		for member: String in value.externally_bound_texture_nodes:value.externally_bound_texture_nodes[member]=_offsets(value.externally_bound_texture_nodes[member])
	for member: String in value.scenes:
		if bool(value.scenes[member].get("_partial_source_scene",false)):value.scenes[member]._selected_source_offsets=_offsets(value.scenes[member]._selected_source_offsets)
	return ""

## Writes scene and layout trees as records and returns the slim manifest
## (member names kept, trees emptied) that is stored as "meta".
static func write_records(writer: RefCounted, value: Dictionary) -> Dictionary:
	var slim: Dictionary=value.duplicate()
	slim["scenes"]={}
	for member: String in value.scenes:
		slim.scenes[member]={}
		writer.add("s:"+member,value.scenes[member])
	if value.get("layout_sources") is Dictionary:
		slim["layout_sources"]={}
		for member: String in value.layout_sources:
			slim.layout_sources[member]={}
			writer.add("l:"+member,value.layout_sources[member])
	writer.add("meta",slim)
	return slim

static func _files_intact(pack_root: String, files: Dictionary) -> String:
	for member: String in files:
		if not _safe_member(member): return "unsafe_source_path"
		var entry: Variant=files[member]
		if not entry is Dictionary or not entry.get("sha256") is String or not entry.get("bytes") is float and not entry.get("bytes") is int:
			return "invalid_source_entry"
		var path: String=pack_root.path_join("originals").path_join(member)
		if not FileAccess.file_exists(path): return "source_missing:"+member
		var source:=FileAccess.open(path,FileAccess.READ)
		if source==null or source.get_length()!=int(entry.bytes) or FileAccess.get_sha256(path)!=entry.sha256:
			return "source_hash_or_size:"+member
		if member.ends_with(".fnt") and not _font_pages_present(path,member,files):
			return "bitmap_font_page_dependencies:"+member
	return ""

static func _offsets(values: Variant) -> Array:
	var result: Array=[]
	if values is Array:
		for value: Variant in values:result.append(int(value) if typeof(value) in [TYPE_INT,TYPE_FLOAT] else value)
	return result

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

static func _safe_member(path: String) -> bool:
	if not path.begins_with("UI/") or path.contains("\\") or path.contains(":"): return false
	for part: String in path.split("/"):
		if part in ["",".",".."]: return false
	return true
