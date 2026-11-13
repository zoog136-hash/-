extends Node2D
## M S32 raw tail -> exact held SP2 bytes. Presentation policy, not client semantics.
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const PACK = preload("res://scripts/resources/current523_pack.gd")
const GLOBAL_DECLARATIONS=preload("res://scripts/maps/current523_spr_declarations.gd")
const USAGE=preload("res://scripts/maps/current523_map_usage.gd")
const EXCLUSIONS=preload("res://scripts/maps/current523_static_spr_exclusions.gd")
const SETTINGS = "user://current523_map_static_spr.cfg"
const POLICY = "TWILIGHT_RAW_S32_STATIC_SPR_V1"
const CHILD_POLICY = "OWN_DECLARED_CHILD_SOURCE_ORDER_V1"
const CHILD_STORED_FRAME_POLICY = "OWN_DECLARED_CHILD_STORED_FRAME0_V1"
const HEADER_ALIAS_POLICY = "OWN_DECLARED_HEADER_ALIAS_V1"
const MODIFIER_POLICY = "IGNORE_UNRESOLVED_MODIFIERS_KEEP_SOURCE_PIXELS_V1"
const DECLARATION_SHA = "03378c1a8b462d60c863e4808298918c6af57161491ef872eb4021aa1e058538"
const DEFAULTS = {"enabled":false,"source_root":"","declaration_path":"","group_bit":0,"fps":0.0,"anchor_x":0,"anchor_y":0,"layer":-4095,"action_overrides":{},"frame_bindings":{},"child_composition_policy":CHILD_POLICY,"unresolved_modifier_policy":MODIFIER_POLICY}
const MAX_RECORDS = 4096
const MAX_CHILD_DEPTH = 8
const MAX_REFERENCE_VISITS = MAX_RECORDS * 4
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
var _candidate_indices: Array[int] = []
var _draws: Array[Dictionary] = []
var _clock: float = 0.0
var _frame: int = -1
var _stats: Dictionary = {}
var _failed: Dictionary = {}
var _source_failures: Dictionary = {}
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
	for key: String in ["child_composition_policy","unresolved_modifier_policy"]:
		var selected_policy: Variant=value.get(key,DEFAULTS[key])
		if not selected_policy is String or selected_policy not in [DEFAULTS[key],"DISABLED"]:return {}
		out[key]=selected_policy
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
		var definition: Dictionary=source.display_definition(id,int(options.action_overrides.get(str(id),3)))
		var ordered: Array[Dictionary]=[]
		for edge: Dictionary in definition.get("references",[]):
			var reference: Dictionary=edge.duplicate(true)
			reference["own_source_order"]=ordered.size()
			ordered.append(reference)
		ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			var a_offset: int=int(a.get("source_byte_offset",-1))
			var b_offset: int=int(b.get("source_byte_offset",-1))
			return int(a.own_source_order)<int(b.own_source_order) if a_offset==b_offset else a_offset<b_offset)
		definition["own_ordered_references"]=ordered
		_declarations[id]=definition
	_declaration_identity=GLOBAL_DECLARATIONS.MANIFEST_SHA if all30 else DECLARATION_SHA
	_declaration_file_count=source.source_files.size()
	return true

func refresh(records: Array[Dictionary], malformed: int = 0) -> void:
	_records=records
	_stats={"policy":POLICY,"enabled":true,"native_M_placement_action_timing_verified":false,"raw_records":records.size(),"malformed_tails":malformed,"literal_member_suffix":0,"stored_group_bit":options.group_bit,"own_fps":options.fps,"own_anchor":[options.anchor_x,options.anchor_y],"own_layer":options.layer,"projection":"OWN_ABSOLUTE_RAW_U16_CURRENT_FIELD_BASIS_NO_CELL_CENTER","alpha_policy":"opaque_samples","rgb_policy":"bit_replication"}
	_candidate_indices.clear()
	var excluded: Array[Dictionary]=[]
	var reason_counts: Dictionary={}
	for index: int in _records.size():
		var row: Dictionary=_records[index]
		var reasons: Array[String]=EXCLUSIONS.reasons(row,_declarations.get(int(row.sprite_id),{}))
		if reasons.is_empty():_candidate_indices.append(index)
		else:
			excluded.append({"member":row.get("source_member",""),"sha256":row.get("source_sha256",""),"source_byte_offset":row.source_byte_offset,"sprite_id":row.sprite_id,"reasons":reasons})
			for reason: String in reasons:reason_counts[reason]=int(reason_counts.get(reason,0))+1
	_stats.user_excluded_records=excluded.size()
	_stats.user_excluded_record_identities=excluded
	_stats.user_exclusion_scope_total=EXCLUSIONS.TOTAL
	_stats.user_exclusion_reason=EXCLUSIONS.REASON
	_stats.user_exclusion_reason_counts=reason_counts
	_stats.exclusion_reason_counts_may_overlap=true
	_stats.connection_candidate_records=_candidate_indices.size()
	_stats.exclusions_are_original_usage=false
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

func _source(sprite_id: int, selector: int=0, declared_child: bool=false) -> Dictionary:
	var attempt: String="%d:%d:%s"%[sprite_id,selector,str(declared_child)]
	if _source_failures.has(attempt):return _unresolved(sprite_id,str(_source_failures[attempt]))
	var excluded: String=EXCLUSIONS.sprite_reason(sprite_id)
	if not excluded.is_empty():return _unresolved(sprite_id,excluded,attempt)
	if not _declarations.has(sprite_id):return _unresolved(sprite_id,"no_original_spr_declaration",attempt)
	var declaration: Dictionary=_declarations[sprite_id]
	if bool(declaration.get("explicit_dummy",false)):return _unresolved(sprite_id,EXCLUSIONS.DUMMY_REASON,attempt)
	if declaration.has("unsupported"):return _unresolved(sprite_id,str(declaration.unsupported),attempt)
	# Only a source-declared child may select existing stored frame0 when its
	# own selected action has no sequence. No parent token is inherited.
	var stored_frame0: bool=declaration.get("sequence",[]).is_empty()
	if stored_frame0 and not declared_child:return _unresolved(sprite_id,"no_selected_original_action_frames",attempt)
	# No selector is translated into a filename suffix or a group bit. Every
	# nonzero selector requires an explicit exact-member binding before playback.
	for token: Dictionary in declaration.sequence:
		if _binding(sprite_id,int(token.get("selector",0))).is_empty():return _unresolved(sprite_id,"original_selector_requires_held_member_binding",attempt)
	var binding: Dictionary=_binding(sprite_id,selector)
	if binding.is_empty():return _unresolved(sprite_id,"original_selector_requires_held_member_binding",attempt)
	var row: Dictionary=binding.row
	var cache_key: String="%d:%d:%s:%d:%s"%[sprite_id,selector,row.member,int(binding.group_bit),str(stored_frame0)]
	if _parsed.has(cache_key):
		_parsed_recent.erase(cache_key);_parsed_recent.append(cache_key)
		return _parsed[cache_key]
	var path: String = options.source_root.path_join(str(row.canonical_package_member))
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return _unresolved(sprite_id,"source_unreadable",attempt)
	var length: int = file.get_length()
	if length!=int(row.bytes) or length>DECODER.MAX_INPUT_BYTES: return _unresolved(sprite_id,"source_size",attempt)
	var raw: PackedByteArray = file.get_buffer(length)
	file.close()
	if PACK.digest(raw)!=row.sha256: return _unresolved(sprite_id,"source_sha256",attempt)
	var decoded: Dictionary = DECODER.parse(raw)
	if not decoded.ok: return _unresolved(sprite_id,"source_parse",attempt)
	var group: int = -1
	for i: int in decoded.groups.size():
		if decoded.groups[i].bit==int(binding.group_bit): group=i
	if group<0 or decoded.groups[group].frames.is_empty(): return _unresolved(sprite_id,"unavailable_stored_group",attempt)
	for frame: Dictionary in declaration.get("sequence",[]):
		if int(frame.get("selector",0))==selector and frame.frame>=decoded.groups[group].frames.size(): return _unresolved(sprite_id,"declared_frame_outside_stored_group",attempt)
	var cost: int = decoded.body.size()+raw.size()
	if cost>MAX_CACHE_BYTES: return _unresolved(sprite_id,"source_cache_budget",attempt)
	while not _parsed_recent.is_empty() and (_parsed_bytes+cost>MAX_CACHE_BYTES or _parsed.size()>=32):
		var oldest: String = _parsed_recent.pop_front()
		_parsed_bytes-=int(_parsed[oldest].cost)
		_parsed.erase(oldest)
	_parsed_bytes+=cost
	var result: Dictionary = {"parsed":decoded,"group":group,"stored_group_bit":int(binding.group_bit),"dispatch":binding.dispatch,"member":row.member,"source_bytes":int(row.bytes),"sha256":row.sha256,"cost":cost,"declaration":declaration,"stored_frame0":stored_frame0}
	_parsed[cache_key]=result
	_parsed_recent.append(cache_key)
	return result

func _unresolved(sprite_id: int, reason: String, attempt: String="") -> Dictionary:
	_failed[sprite_id]=reason
	if not attempt.is_empty() and _source_failures.size()<MAX_RECORDS:_source_failures[attempt]=reason
	return {}

func _modifier_entries(definition: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary]=[]
	var seen: Dictionary={}
	for field: String in ["unapplied_modifiers","unresolved_modifiers"]:
		for entry: Dictionary in definition.get(field,[]):
			var key: String="%d:%s"%[int(entry.get("source_byte_offset",-1)),str(entry.get("raw",""))]
			if seen.has(key):continue
			seen[key]=true;entries.append(entry.duplicate(true))
	return entries

func _reference_evidence(edge: Dictionary, definition: Dictionary) -> Dictionary:
	var evidence: Dictionary=edge.duplicate(true)
	var member: String=str(edge.get("source_file",definition.get("source_file","")))
	evidence["source_file"]=member
	if member==str(definition.get("source_file","")):
		evidence["source_sha256"]=definition.get("source_sha256","")
		evidence["source_file_bytes"]=int(definition.get("source_file_bytes",0))
	return evidence

func _active_modifier_entries(entries: Array[Dictionary], token: Dictionary, stored_frame0: bool) -> Array[Dictionary]:
	var active: Array[Dictionary]=[]
	for entry: Dictionary in entries:
		# A suffix belonging to another declared frame remains unresolved source
		# metadata; it was not ignored while drawing this particular frame.
		if entry.has("raw_suffix") and (stored_frame0 or int(entry.get("source_byte_offset",-1))!=int(token.get("source_byte_offset",-2))):continue
		active.append(entry)
	return active

func _reference_failure(state: Dictionary, sprite_id: int, edge: Dictionary, reason: String, header_alias: bool=false) -> void:
	var count_field: String="unresolved_header_alias_reference_count" if header_alias else "unresolved_child_reference_count"
	var details_field: String="unresolved_header_aliases" if header_alias else "unresolved_attachments"
	state[count_field]=int(state[count_field])+1
	var details: Dictionary=state[details_field]
	if not details.has(sprite_id):details[sprite_id]={}
	var key: String="%d:%d:%s"%[int(edge.get("source_byte_offset",-1)),int(edge.get("target_id",-1)),reason]
	var entries: Dictionary=details[sprite_id]
	if not entries.has(key):entries[key]={"reference":edge.duplicate(true),"reason":reason,"occurrences":0}
	entries[key].occurrences+=1

func _compose_header_alias(row: Dictionary, sprite_id: int, tick: int, ancestors: Array[int], path: Array[Dictionary], state: Dictionary, definition: Dictionary) -> String:
	state.header_alias_source_nodes+=1
	var target: int=int(definition.alias_target_raw)
	var edge: Dictionary=definition.get("alias_reference",{})
	var target_definition: Dictionary=_declarations.get(target,{})
	var target_token: Dictionary=GLOBAL_DECLARATIONS.own_frame_at(target_definition.get("sequence",[]),tick)
	var excluded_target: String=EXCLUSIONS.sprite_reason(target)
	if excluded_target.is_empty() and bool(target_definition.get("explicit_dummy",false)):excluded_target=EXCLUSIONS.DUMMY_REASON
	var modifiers: Array[Dictionary]=_modifier_entries(definition)
	if not modifiers.is_empty():state.unresolved_modifiers[sprite_id]=modifiers
	var reason: String=""
	var delegated: bool=false
	if options.child_composition_policy=="DISABLED":reason="declared_alias_requires_resolution"
	elif str(definition.get("unsupported","")) not in ["","declared_alias_requires_resolution"]:reason=str(definition.unsupported)
	elif int(state.child_reference_visits)+int(state.header_alias_reference_visits)>=MAX_REFERENCE_VISITS:
		state.unvisited_header_aliases_due_to_budget+=1;reason="composition_reference_budget"
	else:
		state.header_alias_reference_visits+=1
		if not modifiers.is_empty() and options.unresolved_modifier_policy=="DISABLED":reason="unresolved_modifiers_policy_disabled"
		elif target<0 or target>65535 or int(edge.get("source_sprite_id",-1))!=sprite_id or int(edge.get("target_id",-1))!=target or str(edge.get("kind",""))!="header_alias":reason="invalid_source_header_alias"
		elif target==sprite_id or target in ancestors:reason="self_or_cyclic_source_reference"
		elif path.size()>=MAX_CHILD_DEPTH:reason="child_depth_budget"
		elif not excluded_target.is_empty():reason=excluded_target
		elif target_definition.is_empty():reason="no_original_spr_declaration"
		elif _binding(target,int(target_token.get("selector",0))).is_empty():reason="declared_header_alias_target_requires_held_member_binding"
		else:
			var next_ancestors: Array[int]=ancestors.duplicate()
			next_ancestors.append(sprite_id)
			var alias_path: Array[Dictionary]=path.duplicate(true)
			alias_path.append(_reference_evidence(edge,definition))
			var before: int=_draws.size()
			# The target chooses its own action, member, group and stored frame.
			# The alias source is never passed to _source as a pixel substitute.
			delegated=true
			reason=_compose_node(row,target,tick,next_ancestors,alias_path,state)
			if reason.is_empty():
				state.drawn_header_alias_reference_count+=1
				var ignored: Array[Dictionary]=_active_modifier_entries(modifiers,{},true)
				if not ignored.is_empty():
					state.ignored_modifiers[sprite_id]=ignored
					for index: int in range(before,_draws.size()):
						var draw: Dictionary=_draws[index]
						var alias_modifiers: Dictionary=draw.get("ignored_header_alias_modifiers",{})
						if draw.ignored_modifiers.is_empty() and alias_modifiers.is_empty():state.ignored_modifier_records+=1
						alias_modifiers[sprite_id]=ignored.duplicate(true)
						draw["ignored_header_alias_modifiers"]=alias_modifiers
						state.ignored_modifier_occurrences+=ignored.size()
	if not reason.is_empty():
		_reference_failure(state,sprite_id,edge,reason,true)
		_unresolved(sprite_id,reason)
		if not delegated:state.missing+=1
	return reason

func _compose_node(row: Dictionary, sprite_id: int, tick: int, ancestors: Array[int], path: Array[Dictionary], state: Dictionary) -> String:
	if int(state.composition_nodes)>=MAX_RECORDS:
		state.budget_skips+=1;return "composition_record_budget"
	state.composition_nodes+=1
	var definition: Dictionary=_declarations.get(sprite_id,{})
	var blocked: String=EXCLUSIONS.sprite_reason(sprite_id)
	if blocked.is_empty() and definition.is_empty():blocked="no_original_spr_declaration"
	if blocked.is_empty() and bool(definition.get("explicit_dummy",false)):blocked=EXCLUSIONS.DUMMY_REASON
	if blocked.is_empty() and sprite_id in ancestors:blocked="self_or_cyclic_source_reference"
	if not blocked.is_empty():
		_unresolved(sprite_id,blocked);state.missing+=1;return blocked
	if definition.get("alias_target_raw")!=null:return _compose_header_alias(row,sprite_id,tick,ancestors,path,state,definition)
	var sequence: Array=definition.get("sequence",[])
	var selected_token: Dictionary=GLOBAL_DECLARATIONS.own_frame_at(sequence,tick)
	var selector: int=int(selected_token.get("selector",0))
	var attachment_path: Array[Dictionary]=[]
	var header_alias_path: Array[Dictionary]=[]
	for reference: Dictionary in path:
		if str(reference.get("kind",""))=="header_alias":header_alias_path.append(reference)
		else:attachment_path.append(reference)
	var child: bool=not attachment_path.is_empty()
	var source_info: Dictionary=_source(sprite_id,selector,child)
	if source_info.is_empty():
		state.missing+=1;return str(_failed.get(sprite_id,"source_unavailable"))
	var declaration: Dictionary=source_info.declaration
	var modifiers: Array[Dictionary]=_modifier_entries(declaration)
	if not modifiers.is_empty():state.unresolved_modifiers[sprite_id]=modifiers
	if not modifiers.is_empty() and options.unresolved_modifier_policy=="DISABLED":
		_unresolved(sprite_id,"unresolved_modifiers_policy_disabled")
		state.missing+=1;return "unresolved_modifiers_policy_disabled"
	if not bool(source_info.stored_frame0):state.declared+=1
	var before: int=_draws.size()
	var next_ancestors: Array[int]=ancestors.duplicate()
	next_ancestors.append(sprite_id)
	var references: Array=declaration.get("own_ordered_references",[])
	for index: int in references.size():
		var edge: Dictionary=references[index]
		if int(state.child_reference_visits)+int(state.header_alias_reference_visits)>=MAX_REFERENCE_VISITS:
			state.unvisited_child_references_due_to_budget+=references.size()-index;break
		state.child_reference_visits+=1
		var target: int=int(edge.get("target_id",-1))
		var reason: String=""
		if options.child_composition_policy=="DISABLED":reason="child_policy_disabled"
		elif int(edge.get("source_sprite_id",-1))!=sprite_id or target<0 or target>65535:reason="invalid_source_reference"
		elif str(edge.get("kind","")) not in ["shadow","clothes"]:reason="unsupported_source_reference_kind"
		elif target in next_ancestors:reason="self_or_cyclic_source_reference"
		elif path.size()>=MAX_CHILD_DEPTH:reason="child_depth_budget"
		else:
			var child_path: Array[Dictionary]=path.duplicate(true)
			child_path.append(_reference_evidence(edge,declaration))
			reason=_compose_node(row,target,tick,next_ancestors,child_path,state)
		if reason.is_empty():state.drawn_child_reference_count+=1
		else:_reference_failure(state,sprite_id,edge,reason)
	# All references use the same own placement anchor. The lexical 'shadow'
	# name does not introduce a PC alpha, layer, tuple or offset rule.
	var frame: int=0 if bool(source_info.stored_frame0) else int(selected_token.frame)
	var key: String="%s:%d:%d"%[source_info.member,int(source_info.stored_group_bit),frame]
	var own_reason: String=""
	if not _textures.has(key):
		var rendered: Dictionary=DECODER.render(source_info.parsed,int(source_info.group),frame,{"alpha_policy":"opaque_samples","rgb_policy":"bit_replication"})
		if not rendered.ok:own_reason="original_frame_render_failed";state.missing+=1
		elif rendered.get("empty",false):own_reason="empty_original_frame";state.empty+=1
		else:
			var image: Image=rendered.image
			var cost: int=image.get_data_size()
			if cost>MAX_CACHE_BYTES:own_reason="texture_cache_budget";state.missing+=1
			else:
				while not _texture_recent.is_empty() and (_texture_bytes+cost>MAX_CACHE_BYTES or _textures.size()>=128):
					var oldest: String=_texture_recent.pop_front()
					_texture_bytes-=int(_textures[oldest].cost);_textures.erase(oldest)
				_texture_bytes+=cost
				_textures[key]={"texture":ImageTexture.create_from_image(image),"bounds":rendered.bounds,"cost":cost}
	if own_reason.is_empty():
		var display: Dictionary=_textures[key]
		_texture_recent.erase(key);_texture_recent.append(key)
		if not state.visible_textures.has(key) and int(state.visible_bytes)+int(display.cost)>MAX_CACHE_BYTES:
			own_reason="visible_texture_budget";state.missing+=1
		else:
			if not state.visible_textures.has(key):
				state.visible_bytes+=int(display.cost);state.visible_textures[key]=true
			var point: Vector2=coordinates.to_world(Vector2(row.raw_x,row.raw_y),false)+Vector2(options.anchor_x,options.anchor_y)
			var selection_policy: String=CHILD_STORED_FRAME_POLICY if bool(source_info.stored_frame0) else str(declaration.get("sequence_origin","LIST29_ACTION3"))
			var ignored: Array[Dictionary]=_active_modifier_entries(modifiers,selected_token,bool(source_info.stored_frame0))
			_draws.append({"point":point+Vector2((display.bounds as Rect2i).position),"texture":display.texture,"record":row,"drawn_sprite_id":sprite_id,"is_declared_child":child,"child_depth":attachment_path.size(),"composition_depth":path.size(),"header_alias_depth":header_alias_path.size(),"child_composition_policy":options.child_composition_policy,"header_alias_policy":HEADER_ALIAS_POLICY if not header_alias_path.is_empty() else "NONE","attachment_references":attachment_path.duplicate(true),"header_alias_references":header_alias_path.duplicate(true),"composition_references":path.duplicate(true),"member":source_info.member,"source_sp2_sha256":source_info.sha256,"source_sp2_bytes":int(source_info.source_bytes),"stored_group_bit":int(source_info.stored_group_bit),"source_selector":selector,"selector_dispatch":source_info.dispatch,"frame":frame,"sequence_source":selection_policy,"own_frame_selection_policy":selection_policy,"uses_declared_frame_token":not bool(source_info.stored_frame0),"declaration_action":int(declaration.action_id),"declaration_line":declaration.get("source_line",0),"declaration_source":declaration.get("source_file","Client/Text/list_29.spr"),"declaration_sha256":declaration.get("source_sha256",""),"declaration_bytes":int(declaration.get("source_file_bytes",0)),"source_token":selected_token,"unapplied_modifiers":declaration.get("unapplied_modifiers",[]),"unresolved_modifiers":modifiers,"ignored_modifiers":ignored,"ignored_header_alias_modifiers":{},"unresolved_modifier_policy":options.unresolved_modifier_policy})
			if child:state.drawn_child_records+=1
			else:state.drawn_parent_records+=1
			if bool(source_info.stored_frame0):state.drawn_child_stored_frame0_records+=1
			if not header_alias_path.is_empty():state.drawn_header_alias_records+=1
			if not ignored.is_empty():
				state.ignored_modifier_records+=1;state.ignored_modifier_occurrences+=ignored.size()
				state.ignored_modifiers[sprite_id]=ignored
	return "" if _draws.size()>before else own_reason

func _update_draws() -> void:
	var tick: int=floori(_clock*float(options.fps)) if float(options.fps)>0 else 0
	if tick==_frame:return
	_frame=tick
	_draws.clear();_failed.clear()
	var state: Dictionary={"missing":0,"empty":0,"budget_skips":maxi(0,_candidate_indices.size()-MAX_RECORDS),"visible_textures":{},"visible_bytes":0,"declared":0,"composition_nodes":0,"drawn_parent_records":0,"drawn_child_records":0,"drawn_child_stored_frame0_records":0,"child_reference_visits":0,"drawn_child_reference_count":0,"unresolved_child_reference_count":0,"unvisited_child_references_due_to_budget":0,"unresolved_attachments":{},"header_alias_source_nodes":0,"header_alias_reference_visits":0,"drawn_header_alias_reference_count":0,"unresolved_header_alias_reference_count":0,"unvisited_header_aliases_due_to_budget":0,"drawn_header_alias_records":0,"unresolved_header_aliases":{},"unresolved_modifiers":{},"ignored_modifiers":{},"ignored_modifier_records":0,"ignored_modifier_occurrences":0}
	for i: int in mini(_candidate_indices.size(),MAX_RECORDS):
		var row: Dictionary=_records[_candidate_indices[i]]
		var ancestors: Array[int]=[]
		var path: Array[Dictionary]=[]
		_compose_node(row,int(row.sprite_id),tick,ancestors,path,state)
	_stats.drawn_records=_draws.size()
	_stats.drawn_parent_records=state.drawn_parent_records
	_stats.drawn_child_records=state.drawn_child_records
	_stats.drawn_child_stored_frame0_records=state.drawn_child_stored_frame0_records
	_stats.drawn_header_alias_records=state.drawn_header_alias_records
	_stats.unresolved_records=state.missing
	_stats.empty_frames=state.empty
	_stats.budget_skips=state.budget_skips
	_stats.cached_members=_parsed.size()
	_stats.cached_frames=_textures.size()
	_stats.unresolved_source_ids=_failed.duplicate()
	_stats.declared_sequence_records=state.declared
	_stats.declaration_SHA256=_declaration_identity
	_stats.declaration_source_file_count=_declaration_file_count
	_stats.original_declaration_and_frames_required=true
	_stats.original_action_sequence_required_for_parent=true
	_stats.original_action_sequence_required_for_child=false
	_stats.child_stored_frame0_is_declared_frame_token=false
	_stats.child_composition_policy=options.child_composition_policy
	_stats.child_stored_frame_policy=CHILD_STORED_FRAME_POLICY
	_stats.header_alias_policy=HEADER_ALIAS_POLICY if options.child_composition_policy!="DISABLED" else "DISABLED"
	_stats.header_alias_source_nodes=state.header_alias_source_nodes
	_stats.header_alias_reference_visits=state.header_alias_reference_visits
	_stats.drawn_header_alias_reference_count=state.drawn_header_alias_reference_count
	_stats.unresolved_header_alias_reference_count=state.unresolved_header_alias_reference_count
	_stats.unvisited_header_aliases_due_to_budget=state.unvisited_header_aliases_due_to_budget
	_stats.unresolved_header_aliases=state.unresolved_header_aliases
	_stats.header_alias_parent_tuple_inherited=false
	_stats.child_frame_selection="OWN_CHILD_ACTION_OR_DECLARED_CHILD_STORED_FRAME0_NO_PARENT_TUPLE"
	_stats.child_reference_visits=state.child_reference_visits
	_stats.drawn_child_reference_count=state.drawn_child_reference_count
	_stats.unresolved_child_reference_count=state.unresolved_child_reference_count
	_stats.unvisited_child_references_due_to_budget=state.unvisited_child_references_due_to_budget
	_stats.composition_nodes=state.composition_nodes
	_stats.max_composition_records=MAX_RECORDS
	_stats.max_child_depth=MAX_CHILD_DEPTH
	_stats.max_composition_depth=MAX_CHILD_DEPTH
	_stats.max_child_reference_visits=MAX_REFERENCE_VISITS
	_stats.composition_reference_visits=int(state.child_reference_visits)+int(state.header_alias_reference_visits)
	_stats.explicit_action_overrides=options.action_overrides.duplicate(true)
	_stats.explicit_frame_bindings=options.frame_bindings.duplicate(true)
	_stats.native_selector_dispatch_verified=false
	_stats.native_action_activation_verified=false
	_stats.native_child_composition_verified=false
	_stats.native_header_alias_activation_verified=false
	_stats.native_modifier_semantics_verified=false
	_stats.reference_observation_requires_verified_byte_length=true
	_stats.unresolved_attachments=state.unresolved_attachments
	_stats.unresolved_modifier_policy=options.unresolved_modifier_policy
	_stats.modifier_count_scope="SOURCE_READY_OR_HEADER_ALIAS_DECLARATION_NODES_AT_CURRENT_TICK"
	_stats.ignored_modifier_count_scope="CURRENT_DRAW_LIST_CURRENT_FRAME_SUFFIX_AND_DECLARATION_METADATA"
	_stats.unresolved_modifiers=state.unresolved_modifiers
	_stats.unresolved_modifier_source_entry_count=0
	for entries: Array in state.unresolved_modifiers.values():_stats.unresolved_modifier_source_entry_count+=entries.size()
	_stats.ignored_modifiers=state.ignored_modifiers
	_stats.ignored_modifier_source_entry_count=0
	for entries: Array in state.ignored_modifiers.values():_stats.ignored_modifier_source_entry_count+=entries.size()
	_stats.ignored_modifier_records=state.ignored_modifier_records
	_stats.ignored_modifier_occurrences=state.ignored_modifier_occurrences
	_stats.zero_tick_policy="OWN_HOLD_SOURCE_FRAME_WITHOUT_SYNTHESIZING_DURATION"
	queue_redraw()

func _draw() -> void:
	var started: int=FRAME_HITCH.now()
	var nested: int=FRAME_HITCH.nested()
	_draw_step()
	FRAME_HITCH.add_self("map_object_draw",started,nested)

func _draw_step() -> void:
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
		if bool(draw.get("uses_declared_frame_token",true)) and token.has("source_byte_offset") and draw.declaration_bytes>0:
			var base: String=str(token.get("raw","")).trim_suffix(str(token.get("unapplied_suffix","")))
			USAGE.observe(renderer,str(draw.declaration_source),int(draw.declaration_bytes),str(draw.declaration_sha256),"frame-token:"+str(token.source_byte_offset),int(token.source_byte_offset),base.length())
		for edge: Dictionary in draw.get("composition_references",draw.get("attachment_references",[])):
			var offset: int=int(edge.get("source_byte_offset",-1))
			var length: int=int(edge.get("source_byte_length",0))
			if length<=0 or offset<0:continue
			var unit: String="header-alias-reference" if str(edge.get("kind",""))=="header_alias" else "child-reference"
			USAGE.observe(renderer,str(edge.get("source_file","")),int(edge.get("source_file_bytes",0)),str(edge.get("source_sha256","")),"%s:%d:%d"%[unit,offset,int(edge.get("target_id",-1))],offset,length)
	if observe:USAGE.flush()

func _process(delta: float) -> void:
	var hitch_started: int = FRAME_HITCH.now()
	var hitch_nested: int = FRAME_HITCH.nested()
	_process_step(delta)
	FRAME_HITCH.add_self("map_objects", hitch_started, hitch_nested)

func _process_step(delta: float) -> void:
	_clock+=maxf(delta,0)
	_update_draws()

func metrics() -> Dictionary:
	var result: Dictionary=_stats.duplicate(true);result["consumption_observation"]=USAGE.status();return result

func _exit_tree() -> void:USAGE.flush(true)

func displayed_records() -> Array[Dictionary]: return _draws.duplicate(true)
