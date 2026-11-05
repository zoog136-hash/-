extends Node2D
## M S32 raw tail -> exact held SP2 bytes. Presentation policy, not client semantics.
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const PACK = preload("res://scripts/resources/current523_pack.gd")
const SETTINGS = "user://current523_map_static_spr.cfg"
const POLICY = "TWILIGHT_RAW_S32_STATIC_SPR_V1"
const DECLARATION_SHA = "03378c1a8b462d60c863e4808298918c6af57161491ef872eb4021aa1e058538"
const DEFAULTS = {"enabled":false,"source_root":"","declaration_path":"","group_bit":0,"fps":0.0,"anchor_x":0,"anchor_y":0,"layer":-4095}
const MAX_RECORDS = 4096
const MAX_CACHE_BYTES = 32 * 1024 * 1024
var problem: String = ""
var options: Dictionary = {}
var coordinates: RefCounted
var _index: Dictionary = {}
var _parsed: Dictionary = {}
var _parsed_recent: Array[int] = []
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

static func validate(value: Dictionary) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate()
	if not value.get("enabled",false) is bool: return {}
	out.enabled = value.get("enabled",false)
	var root: Variant = value.get("source_root","")
	if not root is String or root.length()>4096 or root.to_utf8_buffer().has(0): return {}
	out.source_root = root.strip_edges().trim_suffix("/")
	var declaration: Variant=value.get("declaration_path","")
	if not declaration is String or declaration.length()>4096 or declaration.to_utf8_buffer().has(0): return {}
	out.declaration_path=declaration.strip_edges()
	if out.enabled and out.source_root.is_empty(): return {}
	for key: String in ["group_bit","fps","anchor_x","anchor_y","layer"]:
		var v: Variant = value.get(key,DEFAULTS[key])
		if not (v is int or v is float) or not is_finite(float(v)): return {}
		var limits: Array = {"group_bit":[0,7],"fps":[0,60],"anchor_x":[-48,48],"anchor_y":[-48,48],"layer":[-4095,-1]}[key]
		if v<limits[0] or v>limits[1] or (key!="fps" and float(v)!=floorf(float(v))): return {}
		out[key] = float(v) if key=="fps" else int(v)
	return out

static func read_options() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS)!=OK: return DEFAULTS.duplicate()
	var value: Dictionary = {}
	for key: String in DEFAULTS: value[key]=cfg.get_value("display",key,DEFAULTS[key])
	var checked: Dictionary = validate(value)
	return DEFAULTS.duplicate() if checked.is_empty() else checked

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
		if not member.ends_with("-0.sp2"): continue
		var number: String = member.trim_prefix("Sprite/").trim_suffix("-0.sp2")
		if number.is_valid_int(): _index[int(number)]=row
	if not options.declaration_path.is_empty():
		if not _load_declarations(options.declaration_path): return false
	coordinates=mapping
	z_index=int(options.layer)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(float(options.fps)>0)
	_configured=true
	return true

func _load_declarations(path: String) -> bool:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()!=1210871:
		problem="승인된 list_29.spr 원문 크기가 다릅니다.";return false
	var bytes: PackedByteArray=file.get_buffer(file.get_length());file.close()
	if PACK.digest(bytes)!=DECLARATION_SHA:
		problem="승인된 list_29.spr 원문 SHA256이 다릅니다.";return false
	var text: String=bytes.get_string_from_utf8()
	var header:=RegEx.new();header.compile("(?m)^#([0-9]+)[ \\t]+([0-9]+)(?:=([0-9]+))?([^\\r\\n]*)")
	var action:=RegEx.new();action.compile("(?m)^[ \\t]*3\\.[^()\\r\\n]+\\(0[ \\t]+([0-9]+),([^()]*)\\)")
	var token:=RegEx.new();token.compile("^([0-9]+)\\.([0-9]+):([0-9]+)$")
	var attachment:=RegEx.new();attachment.compile("105\\.[^()]+\\(([^()]*)\\)")
	var headers: Array[RegExMatch]=header.search_all(text)
	for i: int in headers.size():
		var h: RegExMatch=headers[i]
		var id: int=int(h.get_string(1))
		if not _index.has(id): continue
		var body: String=text.substr(h.get_end(),(headers[i+1].get_start() if i+1<headers.size() else text.length())-h.get_end())
		var record: Dictionary={"header":h.get_string(),"source_line":text.left(h.get_start()).count("\n")+1,"source_sha256":DECLARATION_SHA,"raw_body":body,"action_id":3,"sequence":[],"attachments_unresolved":[]}
		var clothes: RegExMatch=attachment.search(body)
		if clothes!=null: record.attachments_unresolved=clothes.get_string(1).split(" ",false)
		if not h.get_string(3).is_empty():
			record["unsupported"]="declared_alias_requires_resolution"
		else:
			var found: RegExMatch=action.search(body)
			if found!=null:
				var sequence: Array[Dictionary]=[]
				for frame: String in found.get_string(2).split(" ",false):
					var parsed: RegExMatch=token.search(frame.strip_edges())
					if parsed==null or int(parsed.get_string(1))!=0 or int(parsed.get_string(3))<=0:
						sequence.clear();break
					sequence.append({"frame":int(parsed.get_string(2)),"duration":int(parsed.get_string(3))})
				if sequence.size()==int(found.get_string(1)): record.sequence=sequence
				else: record["unsupported"]="declared_frame_mapping_or_modifiers"
		_declarations[id]=record
	return true

func refresh(records: Array[Dictionary], malformed: int = 0) -> void:
	_records=records
	_stats={"policy":POLICY,"enabled":true,"native_M_placement_action_timing_verified":false,"raw_records":records.size(),"malformed_tails":malformed,"literal_member_suffix":0,"stored_group_bit":options.group_bit,"own_fps":options.fps,"own_anchor":[options.anchor_x,options.anchor_y],"own_layer":options.layer,"projection":"OWN_ABSOLUTE_RAW_U16_CURRENT_FIELD_BASIS_NO_CELL_CENTER","alpha_policy":"opaque_samples","rgb_policy":"bit_replication"}
	_frame=-1
	_update_draws()

func _source(sprite_id: int) -> Dictionary:
	if _parsed.has(sprite_id):
		_parsed_recent.erase(sprite_id); _parsed_recent.append(sprite_id)
		return _parsed[sprite_id]
	if _failed.has(sprite_id): return {}
	if not _index.has(sprite_id): return _unresolved(sprite_id,"no_literal_0_member")
	var row: Dictionary = _index[sprite_id]
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
		if decoded.groups[i].bit==int(options.group_bit): group=i
	if group<0 or decoded.groups[group].frames.is_empty(): return _unresolved(sprite_id,"unavailable_stored_group")
	var declaration: Dictionary=_declarations.get(sprite_id,{})
	if declaration.has("unsupported"): return _unresolved(sprite_id,str(declaration.unsupported))
	for frame: Dictionary in declaration.get("sequence",[]):
		if frame.frame>=decoded.groups[group].frames.size(): return _unresolved(sprite_id,"declared_frame_outside_stored_group")
	var cost: int = decoded.body.size()+raw.size()
	if cost>MAX_CACHE_BYTES: return {}
	while not _parsed_recent.is_empty() and (_parsed_bytes+cost>MAX_CACHE_BYTES or _parsed.size()>=32):
		var oldest: int = _parsed_recent.pop_front()
		_parsed_bytes-=int(_parsed[oldest].cost)
		_parsed.erase(oldest)
	_parsed_bytes+=cost
	var result: Dictionary = {"parsed":decoded,"group":group,"member":row.member,"sha256":row.sha256,"cost":cost,"declaration":declaration}
	_parsed[sprite_id]=result
	_parsed_recent.append(sprite_id)
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
		var source_info: Dictionary = _source(int(row.sprite_id))
		if source_info.is_empty(): missing+=1; continue
		var parsed: Dictionary = source_info.parsed
		var group: int = int(source_info.group)
		var frame: int = posmod(tick,parsed.groups[group].frames.size())
		var declaration: Dictionary=source_info.declaration
		var sequence: Array=declaration.get("sequence",[])
		if not sequence.is_empty():
			var duration: int=0
			for entry: Dictionary in sequence: duration+=int(entry.duration)
			var phase: int=posmod(tick,duration)
			for entry: Dictionary in sequence:
				frame=int(entry.frame)
				if phase<int(entry.duration): break
				phase-=int(entry.duration)
			declared+=1
		if not declaration.get("attachments_unresolved",[]).is_empty(): unresolved_attachments[int(row.sprite_id)]=declaration.attachments_unresolved
		var key: String = str(row.sprite_id)+":"+str(frame)
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
		_draws.append({"point":point+Vector2((display.bounds as Rect2i).position),"texture":display.texture,"record":row,"member":source_info.member,"source_sp2_sha256":source_info.sha256,"frame":frame,"sequence_source":"LIST29_ACTION3" if not sequence.is_empty() else "OWN_STORED_ORDER","declaration_line":declaration.get("source_line",0)})
	_stats.drawn_records=_draws.size()
	_stats.unresolved_records=missing
	_stats.empty_frames=empty
	_stats.budget_skips=clipped
	_stats.cached_members=_parsed.size()
	_stats.cached_frames=_textures.size()
	_stats.unresolved_source_ids=_failed.duplicate()
	_stats.declared_sequence_records=declared
	_stats.declaration_SHA256=DECLARATION_SHA if not options.declaration_path.is_empty() else ""
	_stats.unresolved_attachments=unresolved_attachments
	queue_redraw()

func _draw() -> void:
	for draw: Dictionary in _draws: draw_texture(draw.texture,draw.point)

func _process(delta: float) -> void:
	_clock+=maxf(delta,0)
	_update_draws()

func metrics() -> Dictionary: return _stats.duplicate(true)

func displayed_records() -> Array[Dictionary]: return _draws.duplicate(true)
