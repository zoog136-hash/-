extends Node2D
## M S32 raw tail -> exact held SP2 bytes. Presentation policy, not client semantics.
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const PACK = preload("res://scripts/resources/current523_pack.gd")
const GLOBAL_DECLARATIONS=preload("res://scripts/maps/current523_spr_declarations.gd")
const USAGE=preload("res://scripts/maps/current523_map_usage.gd")
const SETTINGS = "user://current523_map_static_spr.cfg"
const POLICY = "TWILIGHT_RAW_S32_STATIC_SPR_V1"
const DECLARATION_SHA = "03378c1a8b462d60c863e4808298918c6af57161491ef872eb4021aa1e058538"
const DEFAULTS = {"enabled":false,"source_root":"","declaration_path":"","group_bit":0,"fps":0.0,"anchor_x":0,"anchor_y":0,"layer":-4095,"action_overrides":{},"frame_bindings":{}}
const MAX_RECORDS = 4096
const MAX_CACHE_BYTES = 32 * 1024 * 1024
var problem: String = ""
var options: Dictionary = {}
var coordinates: RefCounted
var _index: Dictionary = {}
var _members: Dictionary = {}
var _parsed: Dictionary = {}
var _parsed_recent: Array[String] = []
var _parsed_bytes: int = 0
var _textures: Dictionary = {}
var _texture_recent: Array[String] = []
var _texture_bytes: int = 0
var _records: Array[Dictionary] = []
var _draws: Array[Dictionary] = []
var _clock: float = 0.0
var _frame: int = -1
var _stats: Dictionary = {}
var _failed: Dictionary = {}
var _configured: bool = false
var _declarations: Dictionary = {}
var _declaration_identity: String=""
var _declaration_file_count: int=0

static func validate(value: Dictionary) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	if not value.get("enabled",false) is bool: return {}
	out.enabled = value.get("enabled",false)
	var root: Variant = value.get("source_root","")
	if not root is String or root.length()>4096 or root.to_utf8_buffer().has(0): return {}
	out.source_root = root.strip_edges().trim_suffix("/")
	var declaration: Variant=value.get("declaration_path","")
	if not declaration is String or declaration.length()>4096 or declaration.to_utf8_buffer().has(0): return {}
	out.declaration_path=declaration.strip_edges()
	if out.enabled and out.source_root.is_empty(): return {}
	# An explicit host selection chooses an existing source action. It never
	# establishes native activation, direction or a filename-suffix conversion.
	var selected_actions: Variant=value.get("action_overrides",{})
	if not selected_actions is Dictionary or selected_actions.size()>1024:return {}
	for id: Variant in selected_actions:
		var name: String=str(id)
		var selected: Variant=selected_actions[id]
		if not (id is String or id is int) or not name.is_valid_int() or name!=str(int(name)) or int(name)<0 or int(name)>65535:return {}
		if out.action_overrides.has(name):return {}
		if not (selected is int or selected is float) or not is_finite(float(selected)) or float(selected)!=floorf(float(selected)) or selected<0 or selected>65535:return {}
		out.action_overrides[name]=int(selected)
	var bindings: Variant=value.get("frame_bindings",{})
	if not bindings is Dictionary or bindings.size()>1024:return {}
	var binding_count: int=0
	for id: Variant in bindings:
		var name: String=str(id)
		if not (id is String or id is int) or not name.is_valid_int() or name!=str(int(name)) or int(name)<0 or int(name)>65535 or out.frame_bindings.has(name):return {}
		var selectors: Variant=bindings[id]
		if not selectors is Dictionary or selectors.is_empty() or selectors.size()>64:return {}
		var selected: Dictionary={}
		for selector: Variant in selectors:
			binding_count+=1
			var selector_name: String=str(selector)
			if binding_count>4096 or not (selector is String or selector is int) or not selector_name.is_valid_int() or selector_name!=str(int(selector_name)) or int(selector_name)<0 or int(selector_name)>65535 or selected.has(selector_name):return {}
			var binding: Variant=selectors[selector]
			if not binding is Dictionary or binding.size()!=2 or not binding.get("member") is String:return {}
			var member: String=binding.member
			var prefix: String="Sprite/"+name+"-"
			if not member.begins_with(prefix) or not member.ends_with(".sp2"):return {}
			var suffix: String=member.trim_prefix(prefix).trim_suffix(".sp2")
			if not suffix.is_valid_int() or suffix!=str(int(suffix)) or int(suffix)<0:return {}
			var bit: Variant=binding.get("group_bit")
			if not (bit is int or bit is float) or not is_finite(float(bit)) or float(bit)!=floorf(float(bit)) or bit<0 or bit>7:return {}
			selected[selector_name]={"member":member,"group_bit":int(bit)}
		out.frame_bindings[name]=selected
	for key: String in ["group_bit","fps","anchor_x","anchor_y","layer"]:
		var v: Variant = value.get(key,DEFAULTS[key])
		if not (v is int or v is float) or not is_finite(float(v)): return {}
		var limits: Array = {"group_bit":[0,7],"fps":[0,60],"anchor_x":[-48,48],"anchor_y":[-48,48],"layer":[-4095,-1]}[key]
		if v<limits[0] or v>limits[1] or (key!="fps" and float(v)!=floorf(float(v))): return {}
		out[key] = float(v) if key=="fps" else int(v)
	return out

static func read_options() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS)!=OK: return DEFAULTS.duplicate(true)
	var value: Dictionary = {}
	for key: String in DEFAULTS: value[key]=cfg.get_value("display",key,DEFAULTS[key])
	var checked: Dictionary = validate(value)
	return DEFAULTS.duplicate(true) if checked.is_empty() else checked

static func save_options(value: Dictionary) -> Error:
	var checked: Dictionary = validate(value)
	if checked.is_empty(): return ERR_INVALID_PARAMETER
	var cfg := ConfigFile.new()
	for key: String in checked: cfg.set_value("display",key,checked[key])
	var pending: String = SETTINGS+".pending-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var error: Error = cfg.save(pending)
	if error==OK: error=DirAccess.rename_absolute(pending,SETTINGS)
	if error!=OK: DirAccess.remove_absolute(pending)
	return error

static func parse_tail(raw: PackedByteArray, offset: int = 0) -> Dictionary:
	# Independently observed M scalar storage. Labels/extended words stay raw.
	if raw.is_empty(): return {"ok":true,"records":[],"trailer":PackedByteArray(),"count_present":false}
	if raw.size()<2 or raw.size()>1024*1024: return {"ok":false,"error":"Invalid M tail length"}
	var cursor: int = 2
	for _named: int in range(raw.decode_u16(0)):
		if cursor>=raw.size(): return {"ok":false,"error":"Truncated named record"}
		var size: int = raw[cursor]
		cursor += 1
		if size+8>raw.size()-cursor: return {"ok":false,"error":"Truncated named fields"}
		cursor += size+8
	var records: Array[Dictionary] = []
	if cursor==raw.size(): return {"ok":true,"records":records,"trailer":PackedByteArray(),"count_present":false}
	if raw.size()-cursor<2: return {"ok":false,"error":"Truncated static count"}
	var word: int = raw.decode_u16(cursor)
	cursor += 2
	var count: int = word&32767
	var stride: int = 10 if word&32768 else 6
	if count>(raw.size()-cursor)/stride: return {"ok":false,"error":"Truncated static records"}
	for _record: int in range(count):
		records.append({"source_byte_offset":offset+cursor,"sprite_id":raw.decode_u16(cursor),"raw_x":raw.decode_u16(cursor+2),"raw_y":raw.decode_u16(cursor+4),"raw_extra":raw.decode_s32(cursor+6) if stride==10 else null,"raw_bytes":raw.slice(cursor,cursor+stride)})
		cursor += stride
	return {"ok":true,"records":records,"trailer":raw.slice(cursor),"count_present":true,"raw_count_word":word}

func configure(value: Dictionary, mapping: RefCounted) -> bool:
	if _configured: problem="정적 SPR 표시는 새 지도 인스턴스에서만 설정할 수 있습니다.";return false
	options=validate(value)
	if options.is_empty() or not options.enabled or mapping==null or not mapping.valid:
		problem="정적 SPR 표시 설정 또는 좌표계가 유효하지 않습니다."; return false
	var path: String = options.source_root.path_join(PACK.REGISTRY)
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>2*1024*1024:
		problem="989 원문 SP2 registry를 읽지 못했습니다."; return false
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if PACK.digest(bytes)!=PACK.REGISTRY_SHA:
		problem="989 원문 SP2 registry SHA256이 다릅니다."; return false
	var rows: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not rows is Array or rows.size()!=989:
		problem="989 원문 SP2 registry 형식이 다릅니다."; return false
	for row: Dictionary in rows:
		# Literal -0 selection is our declared policy, never a native direction.
		var member: String = str(row.member)
		_members[member]=row
		if not member.ends_with("-0.sp2"): continue
		var number: String = member.trim_prefix("Sprite/").trim_suffix("-0.sp2")
		if number.is_valid_int(): _index[int(number)]=row
	if options.declaration_path.is_empty():
		problem="정적 SPR은 원문 선언 폴더 또는 list_29.spr가 필요합니다.";return false
	if not _load_declarations(options.declaration_path):return false
	coordinates=mapping
	z_index=int(options.layer)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(float(options.fps)>0)
	_configured=true
	return true

func _load_declarations(path: String) -> bool:
	var source=GLOBAL_DECLARATIONS.new()
	var all30: bool=DirAccess.dir_exists_absolute(path)
	var loaded: bool=source.load_directory(path) if all30 else source.load_single_list29(path)
	if not loaded:problem=source.problem;return false
	for id: int in source.definitions:
		_declarations[id]=source.display_definition(id,int(options.action_overrides.get(str(id),3)))
	_declaration_identity=GLOBAL_DECLARATIONS.MANIFEST_SHA if all30 else DECLARATION_SHA
	_declaration_file_count=source.source_files.size()
	return true

func refresh(records: Array[Dictionary], malformed: int = 0) -> void:
	_records=records
	_stats={"policy":POLICY,"enabled":true,"native_M_placement_action_timing_verified":false,"raw_records":records.size(),"malformed_tails":malformed,"literal_member_suffix":0,"stored_group_bit":options.group_bit,"own_fps":options.fps,"own_anchor":[options.anchor_x,options.anchor_y],"own_layer":options.layer,"projection":"OWN_ABSOLUTE_RAW_U16_CURRENT_FIELD_BASIS_NO_CELL_CENTER","alpha_policy":"opaque_samples","rgb_policy":"bit_replication"}
	_frame=-1
	_update_draws()

func _binding(sprite_id: int, selector: int) -> Dictionary:
	var selectors: Dictionary=options.frame_bindings.get(str(sprite_id),{})
	if selectors.has(str(selector)):
		var selected: Dictionary=selectors[str(selector)]
		if not _members.has(selected.member):return {}
		return {"row":_members[selected.member],"group_bit":int(selected.group_bit),"dispatch":"EXPLICIT_HOST_REGISTRY_BINDING"}
	if selector!=0 or not _index.has(sprite_id):return {}
	return {"row":_index[sprite_id],"group_bit":int(options.group_bit),"dispatch":"OWN_LITERAL_ZERO_MEMBER"}

func _source(sprite_id: int, selector: int=0) -> Dictionary:
	if _failed.has(sprite_id): return {}
	# Original pixels alone do not declare which frames should be played.
	# Never fill a missing declaration/action with guessed stored-frame order.
	if not _declarations.has(sprite_id):return _unresolved(sprite_id,"no_original_spr_declaration")
	var declaration: Dictionary=_declarations[sprite_id]
	if declaration.has("unsupported"):return _unresolved(sprite_id,str(declaration.unsupported))
	if declaration.get("sequence",[]).is_empty():return _unresolved(sprite_id,"no_selected_original_action_frames")
	# No selector is translated into a filename suffix or a group bit. Every
	# nonzero selector requires an explicit exact-member binding before playback.
	for token: Dictionary in declaration.sequence:
		if _binding(sprite_id,int(token.get("selector",0))).is_empty():return _unresolved(sprite_id,"original_selector_requires_held_member_binding")
	var binding: Dictionary=_binding(sprite_id,selector)
	if binding.is_empty():return _unresolved(sprite_id,"original_selector_requires_held_member_binding")
	var row: Dictionary=binding.row
	var cache_key: String="%d:%d:%s:%d"%[sprite_id,selector,row.member,int(binding.group_bit)]
	if _parsed.has(cache_key):
		_parsed_recent.erase(cache_key);_parsed_recent.append(cache_key)
		return _parsed[cache_key]
	var path: String = options.source_root.path_join(str(row.canonical_package_member))
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return _unresolved(sprite_id,"source_unreadable")
	var length: int = file.get_length()
	if length!=int(row.bytes) or length>DECODER.MAX_INPUT_BYTES: return _unresolved(sprite_id,"source_size")
	var raw: PackedByteArray = file.get_buffer(length)
	file.close()
	if PACK.digest(raw)!=row.sha256: return _unresolved(sprite_id,"source_sha256")
	var decoded: Dictionary = DECODER.parse(raw)
	if not decoded.ok: return _unresolved(sprite_id,"source_parse")
	var group: int = -1
	for i: int in decoded.groups.size():
		if decoded.groups[i].bit==int(binding.group_bit): group=i
	if group<0 or decoded.groups[group].frames.is_empty(): return _unresolved(sprite_id,"unavailable_stored_group")
	for frame: Dictionary in declaration.get("sequence",[]):
		if int(frame.get("selector",0))==selector and frame.frame>=decoded.groups[group].frames.size(): return _unresolved(sprite_id,"declared_frame_outside_stored_group")
	var cost: int = decoded.body.size()+raw.size()
	if cost>MAX_CACHE_BYTES: return {}
	while not _parsed_recent.is_empty() and (_parsed_bytes+cost>MAX_CACHE_BYTES or _parsed.size()>=32):
		var oldest: String = _parsed_recent.pop_front()
		_parsed_bytes-=int(_parsed[oldest].cost)
		_parsed.erase(oldest)
	_parsed_bytes+=cost
	var result: Dictionary = {"parsed":decoded,"group":group,"stored_group_bit":int(binding.group_bit),"dispatch":binding.dispatch,"member":row.member,"source_bytes":int(row.bytes),"sha256":row.sha256,"cost":cost,"declaration":declaration}
	_parsed[cache_key]=result
	_parsed_recent.append(cache_key)
	return result

func _unresolved(sprite_id: int, reason: String) -> Dictionary:
	_failed[sprite_id]=reason
	return {}

func _update_draws() -> void:
	var tick: int = floori(_clock*float(options.fps)) if float(options.fps)>0 else 0
	if tick==_frame: return
	_frame=tick
	_draws.clear()
	var missing: int = 0
	var empty: int = 0
	var clipped: int = maxi(0,_records.size()-MAX_RECORDS)
	var visible_textures: Dictionary = {}
	var visible_bytes: int = 0
	var declared: int=0
	var unresolved_attachments: Dictionary={}
	for i: int in mini(_records.size(),MAX_RECORDS):
		var row: Dictionary = _records[i]
		var definition: Dictionary=_declarations.get(int(row.sprite_id),{})
		var sequence: Array=definition.get("sequence",[])
		var selected_token: Dictionary=GLOBAL_DECLARATIONS.own_frame_at(sequence,tick)
		var selector: int=int(selected_token.get("selector",0))
		var source_info: Dictionary = _source(int(row.sprite_id),selector)
		if source_info.is_empty(): missing+=1; continue
		var parsed: Dictionary = source_info.parsed
		var group: int = int(source_info.group)
		var frame: int = int(selected_token.frame)
		var declaration: Dictionary=source_info.declaration
		declared+=1
		if not declaration.get("attachments_unresolved",[]).is_empty(): unresolved_attachments[int(row.sprite_id)]=declaration.attachments_unresolved
		var key: String = "%s:%d:%d"%[source_info.member,int(source_info.stored_group_bit),frame]
		if not _textures.has(key):
			var rendered: Dictionary = DECODER.render(parsed,group,frame,{"alpha_policy":"opaque_samples","rgb_policy":"bit_replication"})
			if not rendered.ok: missing+=1; continue
			if rendered.get("empty",false): empty+=1; continue
			var image: Image = rendered.image
			var cost: int = image.get_data_size()
			if cost>MAX_CACHE_BYTES: missing+=1; continue
			while not _texture_recent.is_empty() and (_texture_bytes+cost>MAX_CACHE_BYTES or _textures.size()>=128):
				var oldest: String = _texture_recent.pop_front()
				_texture_bytes-=int(_textures[oldest].cost)
				_textures.erase(oldest)
			_texture_bytes+=cost
			_textures[key]={"texture":ImageTexture.create_from_image(image),"bounds":rendered.bounds,"cost":cost}
		var display: Dictionary = _textures[key]
		_texture_recent.erase(key); _texture_recent.append(key)
		if not visible_textures.has(key):
			if visible_bytes+int(display.cost)>MAX_CACHE_BYTES: missing+=1; continue
			visible_bytes+=int(display.cost);visible_textures[key]=true
		var point: Vector2 = coordinates.to_world(Vector2(row.raw_x,row.raw_y),false)+Vector2(options.anchor_x,options.anchor_y)
		_draws.append({"point":point+Vector2((display.bounds as Rect2i).position),"texture":display.texture,"record":row,"member":source_info.member,"source_sp2_sha256":source_info.sha256,"source_sp2_bytes":int(source_info.source_bytes),"stored_group_bit":int(source_info.stored_group_bit),"source_selector":selector,"selector_dispatch":source_info.dispatch,"frame":frame,"sequence_source":declaration.get("sequence_origin","LIST29_ACTION3"),"declaration_action":int(declaration.action_id),"declaration_line":declaration.get("source_line",0),"declaration_source":declaration.get("source_file","Client/Text/list_29.spr"),"declaration_sha256":declaration.get("source_sha256",""),"declaration_bytes":int(declaration.get("source_file_bytes",0)),"source_token":selected_token,"unapplied_modifiers":declaration.get("unapplied_modifiers",[])})
	_stats.drawn_records=_draws.size()
	_stats.unresolved_records=missing
	_stats.empty_frames=empty
	_stats.budget_skips=clipped
	_stats.cached_members=_parsed.size()
	_stats.cached_frames=_textures.size()
	_stats.unresolved_source_ids=_failed.duplicate()
	_stats.declared_sequence_records=declared
	_stats.declaration_SHA256=_declaration_identity
	_stats.declaration_source_file_count=_declaration_file_count
	_stats.original_declaration_and_frames_required=true
	_stats.explicit_action_overrides=options.action_overrides.duplicate(true)
	_stats.explicit_frame_bindings=options.frame_bindings.duplicate(true)
	_stats.native_selector_dispatch_verified=false
	_stats.native_action_activation_verified=false
	_stats.unresolved_attachments=unresolved_attachments
	_stats.zero_tick_policy="OWN_HOLD_SOURCE_FRAME_WITHOUT_SYNTHESIZING_DURATION"
	queue_redraw()

func _draw() -> void:
	var renderer: Node=get_parent()
	var observe: bool=USAGE.actual_main(renderer)
	var view: Rect2=(renderer.call("_view_rect") as Rect2).grow(-64.0) if observe else Rect2()
	for draw: Dictionary in _draws:
		draw_texture(draw.texture,draw.point)
		if not observe or not Rect2(draw.point,(draw.texture as Texture2D).get_size()).intersects(view):continue
		var row: Dictionary=draw.record
		USAGE.observe(renderer,str(draw.member),int(draw.source_sp2_bytes),str(draw.source_sp2_sha256),"stored-bit:%d/frame:%d"%[int(draw.stored_group_bit),int(draw.frame)])
		if row.has("source_member") and row.has("source_bytes"):
			USAGE.observe(renderer,str(row.source_member),int(row.source_bytes),str(row.source_sha256),"static-record:"+str(row.source_byte_offset),int(row.source_byte_offset),(row.raw_bytes as PackedByteArray).size())
		var token: Dictionary=draw.source_token
		if token.has("source_byte_offset") and draw.declaration_bytes>0:
			var base: String=str(token.get("raw","")).trim_suffix(str(token.get("unapplied_suffix","")))
			USAGE.observe(renderer,str(draw.declaration_source),int(draw.declaration_bytes),str(draw.declaration_sha256),"frame-token:"+str(token.source_byte_offset),int(token.source_byte_offset),base.length())
	if observe:USAGE.flush()

func _process(delta: float) -> void:
	_clock+=maxf(delta,0)
	_update_draws()

func metrics() -> Dictionary:
	var result: Dictionary=_stats.duplicate(true);result["consumption_observation"]=USAGE.status();return result

func _exit_tree() -> void:USAGE.flush(true)

func displayed_records() -> Array[Dictionary]: return _draws.duplicate(true)
