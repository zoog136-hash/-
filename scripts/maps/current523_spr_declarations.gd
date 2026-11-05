extends RefCounted
## Verified source-lexical data, not a native activation/composition interpreter.
const PACK=preload("res://scripts/resources/current523_pack.gd")
const MANIFEST_SHA="91bbf7d8e63a8407ad5489a0dbb228f9da50a5e1183e7b6960e9916db8ccd5ea"
const TEXT_IDENTITY_SHA="4426a6a7ec09c61152d04575b829b84846b342275c35ddad4ce9498759de285a"
const GRAPH_SHA="8e54942a4c51f5f166c8fc9861f2ec7c1a2bf5f07db315600bd0d291cba1d487"
var problem: String=""
var source_root: String=""
var definitions: Dictionary={}
var source_files: Dictionary={}
var references: Array=[]
var verified_tokens: int=0
static var _cache: Dictionary={}

func _fail(message: String) -> bool:
	problem=message;return false

func _verified_bytes(path: String, digest: String, limit: int) -> PackedByteArray:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()<=0 or file.get_length()>limit:
		_fail("SPR 원문 또는 검증 목록을 읽지 못했습니다.");return PackedByteArray()
	var raw: PackedByteArray=file.get_buffer(file.get_length());file.close()
	if PACK.digest(raw)!=digest:
		_fail("SPR 원문/목록 SHA256이 다릅니다.");return PackedByteArray()
	return raw

func load_directory(directory: String) -> bool:
	if not definitions.is_empty():return _fail("SPR 선언은 새 소비자에서만 연결할 수 있습니다.")
	var root: String=directory.trim_suffix("/")
	if DirAccess.dir_exists_absolute(root.path_join("SPR_reference_closure")):root=root.path_join("SPR_reference_closure")
	source_root=root
	if _cache.has(root):
		var cached: Dictionary=_cache[root]
		definitions=cached.definitions.duplicate(true);source_files=cached.source_files.duplicate(true)
		references=cached.references.duplicate(true);verified_tokens=cached.verified_tokens;return true
	var identities: PackedByteArray=_verified_bytes(root.path_join("results/all_current_text_integrity.json"),TEXT_IDENTITY_SHA,128*1024)
	if identities.is_empty():return false
	var identity_rows: Variant=JSON.parse_string(identities.get_string_from_utf8())
	if not identity_rows is Array or identity_rows.size()!=30:return _fail("정확한30 SPR 원문 목록이 필요합니다.")
	var originals: Dictionary={}
	for row: Dictionary in identity_rows:
		var path: String=str(row.path)
		var allowed: bool=false
		for n: int in 30:
			if path=="Client/Text/list_%d.spr"%n:allowed=true;break
		if not allowed or originals.has(path):return _fail("SPR 원문 경로가 잘못되거나 중복됩니다.")
		var raw: PackedByteArray=_verified_bytes(root.path_join("originals").path_join(path),str(row.sha256),2*1024*1024)
		if raw.is_empty() or raw.size()!=int(row.bytes):return _fail("SPR 원문 크기/해시가 다릅니다.")
		originals[path]=raw
		source_files[path]={"member":path,"bytes":raw.size(),"sha256":row.sha256}
	var table: PackedByteArray=_verified_bytes(root.path_join("results/all_current_global_declarations.json"),MANIFEST_SHA,8*1024*1024)
	if table.is_empty():return false
	var rows: Variant=JSON.parse_string(table.get_string_from_utf8())
	if not rows is Array or rows.size()!=1012:return _fail("검증된1012 SPR 선언 목록이 필요합니다.")
	var token_pattern:=RegEx.new();token_pattern.compile("^([0-9]+)\\.([0-9]+):([0-9]+)(.*)$")
	for row: Dictionary in rows:
		var id: int=int(row.sprite_id)
		var path: String=str(row.source_file)
		if id<0 or id>65535 or definitions.has(id) or not originals.has(path):return _fail("SPR ID/원문 경로가 모호합니다.")
		var raw: PackedByteArray=originals[path]
		var begin: int=int(row.source_byte_offset);var end: int=int(row.source_end_offset)
		if begin<0 or end<=begin or end>raw.size():return _fail("SPR 선언 바이트 범위가 잘못됐습니다.")
		var block: PackedByteArray=raw.slice(begin,end)
		if PACK.digest(block)!=row.raw_declaration_sha256 or block!=Marshalls.base64_to_raw(str(row.raw_declaration_base64)):
			return _fail("SPR 선언이 실제 원문 바이트와 다릅니다.")
		for action: Dictionary in row.actions:
			for token: Dictionary in action.tokens:
				var literal: String=str(token.raw);var bytes: PackedByteArray=literal.to_ascii_buffer()
				var offset: int=int(token.source_byte_offset)
				var parsed: RegExMatch=token_pattern.search(literal)
				if parsed==null or offset<begin or offset+bytes.size()>end or raw.slice(offset,offset+bytes.size())!=bytes:
					return _fail("SPR 프레임 토큰의 실제 바이트 위치가 다릅니다.")
				if int(parsed.get_string(1))!=int(token.raw_selector) or int(parsed.get_string(2))!=int(token.raw_frame_index) or int(parsed.get_string(3))!=int(token.raw_ticks) or parsed.get_string(4)!=str(token.raw_suffix):
					return _fail("SPR 프레임 수치가 원문 토큰과 다릅니다.")
				verified_tokens+=1
		var definition: Dictionary=row.duplicate(true)
		definition["raw_bytes"]=block
		definition["source_file_identity"]=source_files[path].duplicate(true)
		definitions[id]=definition
	var graph_bytes: PackedByteArray=_verified_bytes(root.path_join("results/complete_source_reference_graph.json"),GRAPH_SHA,2*1024*1024)
	if graph_bytes.is_empty():return false
	var graph: Variant=JSON.parse_string(graph_bytes.get_string_from_utf8())
	if not graph is Dictionary or not graph.get("explicit_source_edges") is Array or graph.get("nodes",[]).size()!=1014:
		return _fail("SPR 원문 참조 그래프가 다릅니다.")
	references=graph.explicit_source_edges.duplicate(true)
	_cache[root]={"definitions":definitions.duplicate(true),"source_files":source_files.duplicate(true),"references":references.duplicate(true),"verified_tokens":verified_tokens}
	return true

func display_definition(id: int) -> Dictionary:
	if not definitions.has(id):return {}
	var source: Dictionary=definitions[id]
	var result: Dictionary={"header":"","source_line":source.source_line,"source_file":source.source_file,"source_byte_offset":source.source_byte_offset,"source_end_offset":source.source_end_offset,"source_sha256":source.source_file_identity.sha256,"source_file_bytes":source.source_file_identity.bytes,"declaration_sha256":source.raw_declaration_sha256,"raw_bytes":source.raw_bytes,"action_id":3,"sequence":[],"attachments_unresolved":[],"references":[],"sequence_origin":"ALL30_SOURCE_ACTION3","unapplied_modifiers":[]}
	if source.alias_target_raw!=null:
		result["unsupported"]="declared_alias_requires_resolution";return result
	for action: Dictionary in source.actions:
		if int(action.code)==105:result.attachments_unresolved=str(action.raw_body).split(" ",false)
		if int(action.code)!=3 or action.tokens.is_empty():continue
		var header: PackedStringArray=str(action.raw_body).split(",",true,1)
		var numbers: PackedStringArray=header[0].strip_edges().split(" ",false)
		if numbers.size()!=2 or not numbers[0].is_valid_int() or not numbers[1].is_valid_int() or int(numbers[1])!=action.tokens.size():
			result["unsupported"]="original_action_header_shape";continue
		result["directional_raw"]=int(numbers[0])
		var sequence: Array[Dictionary]=[]
		for token: Dictionary in action.tokens:
			if int(token.raw_selector)!=0 or int(token.raw_ticks)<0:
				result["unsupported"]="original_selector_or_tick_not_supported";sequence.clear();break
			sequence.append({"frame":int(token.raw_frame_index),"duration":int(token.raw_ticks),"selector":int(token.raw_selector),"source_byte_offset":int(token.source_byte_offset),"raw":token.raw,"unapplied_suffix":token.raw_suffix})
			if not str(token.raw_suffix).is_empty():result.unapplied_modifiers.append(token.duplicate(true))
		result.sequence=sequence
	for edge: Dictionary in references:
		if int(edge.source_sprite_id)==id:result.references.append(edge.duplicate(true))
	return result

static func own_frame_at(sequence: Array, tick: int) -> Dictionary:
	# Missing native zero-duration activation is not replaced with invented ticks.
	# Our bounded display policy holds the first zero-duration source frame.
	var total: int=0;var holds: bool=false
	for token: Dictionary in sequence:
		if int(token.duration)==0:holds=true;break
		total+=int(token.duration)
	if sequence.is_empty():return {}
	var phase: int=maxi(tick,0) if holds else posmod(tick,maxi(total,1))
	for token: Dictionary in sequence:
		if int(token.duration)==0 or phase<int(token.duration):return token
		phase-=int(token.duration)
	return sequence.back()
