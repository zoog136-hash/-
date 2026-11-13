extends RefCounted
## Partial, source-backed Main draw observations. Never a whole-file95% counter.
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const PATH="user://current523_map_consumption_v1.json"
const INVENTORY_SHA="c395f35afa067dfad04db3d615c7f39acbdea7134ae8f2023bbbf75c5639f1b7"
const DENOMINATOR={"Map":{"files":8311,"original_member_bytes":994755558},"Tile":{"files":8514,"original_member_bytes":297767184}}
static var _loaded: bool=false
static var _members: Dictionary={}
static var _dirty: bool=false
static var _last_flush: int=0
static var _disabled: bool=false
static var problem: String=""

static func actual_main(renderer: Node) -> bool:
	if DisplayServer.get_name()=="headless" or not is_instance_valid(renderer) or not renderer is CanvasItem or not renderer.is_visible_in_tree():return false
	var world: Node=renderer.get_parent()
	if world==null or world.scene_file_path!="res://Main.tscn":return false
	# Main uses the existing potion-feedback World subclass. Validate its real
	# inheritance chain rather than mistaking that subclass for an inspection.
	var script: Script=world.get_script()
	var owns_world: bool=false
	while script!=null:
		if script.resource_path=="res://scripts/world.gd":owns_world=true;break
		script=script.get_base_script()
	if not owns_world:return false
	return world.get("field_renderer")==renderer and bool(world.get("current523_aden_play_active")) and renderer.get("field")!=null and bool(renderer.get("field").get_meta("current523_source_field",false))

static func _origin() -> String:
	for arg: String in OS.get_cmdline_args():
		if arg in ["--script","-s"] or arg.begins_with("res://tests/"):return "AUTOMATED_ACTUAL_MAIN"
	return "USER_MAIN"

static func _load() -> void:
	if _loaded:return
	var started: int=HITCH.now()
	_load_step()
	HITCH.detail("map.usage_load",started)

static func _load_step() -> void:
	_loaded=true
	var file:=FileAccess.open(PATH,FileAccess.READ)
	if file==null:
		if FileAccess.file_exists(PATH):problem="기존 소비 장부를 읽지 못했습니다.";_disabled=true
		return
	if file.get_length()>16*1024*1024:problem="기존 소비 장부가 검사 한도를 초과했습니다.";_disabled=true;return
	var value: Variant=JSON.parse_string(file.get_as_text());file.close()
	if value is Dictionary and value.get("schema")==1 and value.get("inventory_JSONL_SHA256")==INVENTORY_SHA and value.get("members") is Dictionary:
		for key: Variant in value.members:
			var row: Variant=value.members[key]
			if not row is Dictionary or not row.get("origins") is Dictionary or row.get("whole_file_used",true)!=false or row.get("original_member_bytes_fully_used_proven",-1)!=0:_disabled=true;break
			for origin: Variant in row.origins:
				var entry: Variant=row.origins[origin]
				if not entry is Dictionary or not entry.get("units") is Dictionary or not entry.get("source_ranges") is Dictionary:_disabled=true;break
		if not _disabled:_members=value.members
	else:_disabled=true
	if _disabled:problem="기존 소비 장부 형식이 달라 기록을 중단했습니다. 게임 상태는 바꾸지 않습니다."

static func observe(renderer: Node, member: String, original_bytes: int, sha256: String, unit: String, source_offset: int=-1, source_length: int=0) -> void:
	if not actual_main(renderer) or original_bytes<=0 or sha256.length()!=64 or not sha256.is_valid_hex_number(false):return
	if not member.begins_with("Map/") and not member.begins_with("Tile/") and not member.begins_with("Sprite/") and not member.begins_with("Client/Text/"):return
	if unit.is_empty() or unit.length()>256:return
	_load()
	if _disabled:return
	var key: String=member+"|"+sha256
	if not _members.has(key):
		_members[key]={"member":member,"sha256":sha256,"original_member_bytes":original_bytes,"usage":"PARTIAL_OBSERVATION","whole_file_used":false,"original_member_bytes_fully_used_proven":0,"origins":{}}
	var row: Dictionary=_members[key]
	if int(row.get("original_member_bytes",-1))!=original_bytes or not row.get("origins") is Dictionary:problem="소비 장부의 원본 정체성이 다릅니다.";return
	var origin: String=_origin()
	if not row.origins.has(origin):row.origins[origin]={"units":{},"source_ranges":{}}
	var event: Dictionary=row.origins[origin]
	if not event.units.has(unit):event.units[unit]=true;_dirty=true
	if source_offset>=0 and source_length>0 and source_offset<=original_bytes-source_length:
		var range_key: String=str(source_offset)+":"+str(source_length)
		if not event.source_ranges.has(range_key):event.source_ranges[range_key]=true;_dirty=true

static func flush(force: bool=false) -> void:
	if _disabled or not _dirty or (not force and Time.get_ticks_msec()-_last_flush<1000):return
	var snapshot: Dictionary={"schema":1,"scope_owner":"MAPS","dataset":"current523","inventory_JSONL_SHA256":INVENTORY_SHA,"fixed_Map_Tile_denominator":DENOMINATOR,"members":_members,"claim":"Partial observations only. Compressed Sprite/TI2 frame units do not prove original byte coverage. QA Main is separate from USER_MAIN; no fixture/inspection observations.","global_non_sound_denominator_known":false,"usage95_verified":false}
	var started: int=HITCH.now()
	var result: Error=WRITER.write(PATH,snapshot)
	HITCH.detail("map.usage_write",started)
	if result!=OK:problem="소비 장부 저장 실패: "+error_string(result);_disabled=true;return
	problem="";_dirty=false;_last_flush=Time.get_ticks_msec()

static func status() -> Dictionary:
	return {"file":PATH,"partial_member_identities":_members.size(),"whole_files_used_claimed":0,"whole_original_bytes_used_claimed":0,"usage95_verified":false,"problem":problem}
