extends RefCounted
## Runtime promotion is separate from the immutable historical input contract.
## Each map needs reviewed entry, source-grid semantics, art and save identity.
const ART=preload("res://scripts/maps/source_map_review_pack.gd")
const LOCAL=preload("res://scripts/maps/source_map_local_policy.gd")
const NATIVE=preload("res://scripts/maps/native_png_registry.gd")
const EQUAL_COLLISION=preload("res://scripts/maps/source_map_equal_collision.gd")
const FIELD=preload("res://scripts/maps/source_map_runtime_field.gd")
const MIGRATION=preload("res://scripts/maps/source_map_save_migration.gd")
const LEGACY_SOURCE=preload("res://scripts/maps/remake_registry.gd")
const LEGACY_LAYOUT=preload("res://scripts/maps/legacy_layout_policy.gd")
const POLICY_PATH="res://data/maps/source_map_runtime.json"
static var seen: Dictionary={}
static var door_states: Dictionary={}
static var gameplay_cache: Dictionary={}
# Full verification re-hashes every full-resolution chunk of the map (about
# 3 s for aden_world on a desktop CPU); every save of the current map and
# every re-entry ran it. A result is reused only while the same pack root,
# the same pinned rule and every verified file's existence/modification time
# are unchanged; any difference re-runs the complete verification. Chunk
# bytes are still hash-checked when the texture store loads them.
static var verified_rules: Dictionary={}
static var verification_runs: int=0
static var position_checks: Dictionary={}
static var policy_cache: Dictionary={}
static var policy_stamp: int=-1

static func root_path() -> String:
	return preload("res://scripts/maps/source_map_pack_location.gd").root_path()

## Parsed once and reused until the file's modification time changes: the
## 144 KB policy took ~4 ms to parse and supports()/identity()/catalog loops
## re-read it per map (hundreds of parses per save, load or map list).
## Callers treat the result as read-only.
static func policy() -> Dictionary:
	var stamp: int=FileAccess.get_modified_time(POLICY_PATH)
	if policy_cache.is_empty() or stamp!=policy_stamp or not _settled(PackedInt64Array([stamp])):
		policy_cache=ART.read_object(POLICY_PATH).get("maps",{})
		policy_stamp=stamp
	return policy_cache

static func supports(mid: String) -> bool:
	return policy().has(mid) and (mid=="aden_world" or not LEGACY_LAYOUT.active("--legacy-map-layouts"))

static func catalog_entries() -> Array:
	var result: Array=[]
	if not FileAccess.file_exists(root_path()+"/index.json"):return result
	for mid: String in policy():
		if not supports(mid):continue
		result.append({"id":mid,"name":str(policy()[mid].name),"width":1,"height":1,"tile_size_world":32,"source_map84":true})
	return result

static func verified_context(mid: String) -> Dictionary:
	if not supports(mid):return {}
	var root: String=root_path()
	var rule: Dictionary=policy()[mid]
	var cached: Dictionary=verified_rules.get(mid,{})
	if not cached.is_empty() and cached.root==root and cached.rule==rule and _file_stamps(cached.files)==cached.stamps:
		# Callers may adjust their record; never hand out the cached one.
		return {"art":cached.art,"record":cached.record.duplicate(true),"rule":rule}
	verified_rules.erase(mid)
	var context: Dictionary=_verify_context(mid)
	if context.is_empty():return {}
	var files: Array[String]=_verified_files(root,mid,context)
	var stamps: PackedInt64Array=_file_stamps(files)
	# Modification times have one-second resolution: a file written within the
	# last two seconds could change again unnoticed, so it is never cached.
	if _settled(stamps):
		verified_rules[mid]={"root":root,"rule":rule.duplicate(true),"files":files,"stamps":stamps,
			"art":context.art,"record":context.record.duplicate(true)}
	return context

static func _settled(stamps: PackedInt64Array) -> bool:
	var recent: int=int(Time.get_unix_time_from_system())-2
	for stamp: int in stamps:
		if stamp>=recent:return false
	return true

## Every file whose bytes _verify_context() checks for this map.
static func _verified_files(root: String, mid: String, context: Dictionary) -> Array[String]:
	var files: Array[String]=[root+"/index.json",root+"/runtime_safety.json",root+"/local-interpretation-v1/index.json",root+"/equal-collision-v1/index.json"]
	var manifest: String=root+"/"+str(context.art.index.maps[mid].file)
	files.append(manifest)
	for chunk: Variant in ART.read_object(manifest).get("chunks",[]):
		if chunk is Dictionary:files.append(root+"/"+str(chunk.get("file","")))
	for chunk: Dictionary in context.record.chunks:files.append(root+"/"+str(chunk.file))
	for spec: Variant in [context.record.collision,context.record.get("clip_grid",{})]:
		if spec is Dictionary and spec.has("file"):files.append(root+"/"+str(spec.file))
	return files

static func _file_stamps(files: Array[String]) -> PackedInt64Array:
	var stamps:=PackedInt64Array()
	for path: String in files:stamps.append(FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1)
	return stamps

static func _verify_context(mid:String) -> Dictionary:
	if not supports(mid):return {}
	verification_runs+=1
	var art=ART.new()
	if not art.open_pack(root_path()):return {}
	var record: Dictionary=art.load_map(mid)
	if record.is_empty():return {}
	var rule: Dictionary=policy()[mid]
	if bool(rule.get("local_policy",false)):
		record=LOCAL.decorate(record,root_path())
		if record.is_empty():return {}
	var requested: String=str(rule.get("collision_archive_version","360"))
	if requested=="351":
		if record.collision!=null or record.selected_collision_version!=null or rule.get("collision_basis")!="identical_archive_representative":return {}
		var equal: Dictionary=EQUAL_COLLISION.spec(root_path(),int(record.source_map_id))
		if equal.is_empty():return {}
		record.collision=equal
	elif requested=="local_authored":
		if not bool(rule.get("local_policy",false)) or record.collision==null or record.selected_collision_version!="local_authored":return {}
	elif requested!="360" or record.collision==null or record.selected_collision_version!="360":return {}
	# Door-bearing maps require the explicitly authorized local state/physics
	# adapter. The immutable incoming enabled flags are never blindly imported.
	if not record.get("doors",[]).is_empty() and not bool(rule.get("local_doors",false)):return {}
	if int(record.source_map_id)!=int(rule.source_map_id) or str(record.collision.raw_sha256)!=str(rule.grid_sha256):return {}
	if str(art.index.maps[mid].sha256)!=str(rule.art_manifest_sha256):return {}
	for chunk:Dictionary in record.chunks:
		if chunk.get("local_patch",false) and FileAccess.get_sha256(root_path()+"/"+str(chunk.file))!=str(chunk.sha256):return {}
	for spec:Dictionary in [record.collision,record.get("clip_grid",{})]:
		if spec.is_empty():continue
		if FileAccess.get_sha256(root_path()+"/"+str(spec.file))!=str(spec.sha256):return {}
	return {"art":art,"record":record,"rule":rule}

static func load_field(mid: String) -> RemakePlayableField:
	var context:Dictionary=verified_context(mid)
	if context.is_empty():return null
	var art:RefCounted=context.art
	var record:Dictionary=context.record
	var rule:Dictionary=context.rule
	var field=FIELD.new()
	if not field.configure_runtime(record,rule,art):field.close();return null
	if mid=="aden_world":
		var path:String=str(rule.get("gameplay_snapshot",""))
		if path.is_empty() or FileAccess.get_sha256(path)!=str(rule.get("gameplay_snapshot_sha256","")):field.close();return null
		var frozen:Dictionary=ART.read_object(path)
		if frozen.get("schema")!=1 or frozen.get("map_id")!=mid or frozen.get("grid_sha256")!=rule.grid_sha256 or int(frozen.get("layout_revision",-1))!=int(rule.layout_revision):field.close();return null
		var snapshot:Dictionary=frozen.gameplay
		for id:String in snapshot.region_cells:snapshot.region_cells[id]=PackedInt32Array(snapshot.region_cells[id])
		var reserved:Array[Dictionary]=[]
		for reservation:Dictionary in snapshot.reservations:reserved.append(reservation)
		snapshot.reservations=reserved
		field.restore_gameplay(snapshot)
	elif bool(rule.get("replacement_of_existing_id",false)):
		var cache_key: String=JSON.stringify(rule,"",true,true).sha256_text()
		if gameplay_cache.has(cache_key):field.restore_gameplay(gameplay_cache[cache_key])
		else:
			var previous: PlayableField=NATIVE.load_field(mid) if rule.get("legacy_loader","")=="native" else LEGACY_SOURCE.load_field(mid)
			if previous==null:field.close();return null
			var preserved: bool=field.preserve_gameplay(previous,rule.get("legacy_frame",{}))
			if previous.has_method("close"):previous.close()
			if not preserved:field.close();return null
			gameplay_cache[cache_key]=field.gameplay_snapshot()
	if not field.apply_local_door_states(door_states.get(mid,{})):field.close();return null
	var npc_holds:Array=preload("res://scripts/npc/source_npc_catalog.gd").append_to_field(field)
	if not npc_holds.is_empty():field.close();return null
	preload("res://scripts/maps/source_map_spawns.gd").append_to_field(field)
	if not "--without-local-habitats" in OS.get_cmdline_user_args() and not preload("res://scripts/maps/source_map_habitats.gd").append_to_field(field):field.close();return null
	seen[mid]=identity(mid)
	return field

static func identity(mid: String) -> Dictionary:
	if not supports(mid):return {}
	var p: Dictionary=policy()[mid]
	return {"source_map_id":int(p.source_map_id),"layout_revision":int(p.layout_revision),
		"grid_sha256":str(p.grid_sha256),"art_manifest_sha256":str(p.art_manifest_sha256)}

static func saved_layouts() -> Dictionary:
	return seen.duplicate(true)

static func saved_doors(field: PlayableField) -> Dictionary:
	if field is FIELD:door_states[str(field.data.map_id)]=field.local_door_states.duplicate(true)
	return door_states.duplicate(true)

static func accept_layouts(data: Dictionary) -> void:
	for id: String in data.get("source_map84_doors",{}):
		if supports(id) and data.source_map84_doors[id] is Dictionary:door_states[id]=data.source_map84_doors[id].duplicate(true)
	for mid: String in data.get("source_map84_layouts",{}):
		if supports(mid) and same_identity(data.source_map84_layouts[mid],identity(mid)):seen[mid]=identity(mid)

static func same_identity(saved: Variant, expected: Dictionary) -> bool:
	if not saved is Dictionary:return false
	for key: String in expected:
		var value: Variant=saved.get(key)
		if expected[key] is int:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=float(expected[key]):return false
		elif not value is String or value!=expected[key]:return false
	return true

static func referenced(data: Dictionary, mid: String) -> bool:
	if str(data.get("map_id",""))==mid:return true
	var drops: Variant=data.get("ground_drops",[])
	if drops is Array:
		for row: Variant in drops:
			if row is Dictionary and str(row.get("map_id",""))==mid:return true
	for key: String in ["monster_world","original_monster_world"]:
		var container: Variant=data.get(key,{})
		if container is Dictionary and container.get("bosses",{}) is Dictionary:
			for id: Variant in container.get("bosses",{}):
				if str(id).begins_with(mid+":"):return true
	return false

static func prepare_migrations(original: Dictionary, source_sha: String) -> Dictionary:
	var data: Dictionary=original.duplicate(true)
	var changed: bool=false
	if not data.get("source_map84_layouts",{}) is Dictionary:return {"ok":false,"error":"지도 저장 식별자가 손상되었습니다"}
	for mid: String in policy():
		var rule: Dictionary=policy()[mid]
		if not supports(mid) or not bool(rule.get("replacement_of_existing_id",false)) or not referenced(data,mid):continue
		var previous_value: Variant=data.get("source_map84_layouts",{}).get(mid,{})
		if not previous_value is Dictionary:return {"ok":false,"error":"지도 저장 식별자가 손상되었습니다"}
		var previous: Dictionary=previous_value
		if same_identity(previous,identity(mid)):continue
		if not previous.is_empty() and int(previous.get("layout_revision",0))>=int(rule.layout_revision):return {"ok":false,"error":"알 수 없는 새 지도 revision · 이전하지 않고 원본 저장을 보존합니다"}
		var field: RemakePlayableField=load_field(mid)
		if field==null:return {"ok":false,"error":"좌표 이전 대상 맵 팩 누락·손상 · 원본 저장을 보존합니다"}
		var result: Dictionary=MIGRATION.plan(data,mid,field,rule,source_sha)
		field.close()
		if not result.ok:return result
		data=result.data
		if not data.has("source_map84_layouts"):data.source_map84_layouts={}
		data.source_map84_layouts[mid]=identity(mid)
		changed=true
	return {"ok":true,"data":data,"changed":changed}

static func validate_save(data: Dictionary, current_field:PlayableField=null) -> String:
	var required: Dictionary={}
	if not data.get("source_map84_doors",{}) is Dictionary:return "문 상태 저장 형식이 손상되었습니다"
	var mid: String=str(data.get("map_id",""))
	if mid.begins_with("source_") and not supports(mid):return "저장된 원본 지도가 현재 검증 범위에 없어 기존 저장을 보존합니다"
	if supports(mid):required[mid]=true
	var drops: Variant=data.get("ground_drops",[])
	if not drops is Array:
		return "원본 지도 바닥 아이템 저장 형식이 손상되었습니다" if supports(mid) else ""
	for raw: Variant in drops:
		if not raw is Dictionary:continue
		var row: Dictionary=raw
		if str(row.get("map_id","")).begins_with("source_") and not supports(str(row.map_id)):return "바닥 아이템의 원본 지도가 현재 검증 범위에 없어 기존 저장을 보존합니다"
		if supports(str(row.get("map_id",""))):required[str(row.map_id)]=true
	for container: String in ["monster_world","original_monster_world"]:
		var holder: Variant=data.get(container,{})
		if not holder is Dictionary or not holder.get("bosses",{}) is Dictionary:return "몬스터 지도 저장 형식이 손상되었습니다"
		for key: Variant in holder.get("bosses",{}):
			var boss_map: String=str(key).get_slice(":",0)
			if supports(boss_map):required[boss_map]=true
	var layouts: Variant=data.get("source_map84_layouts",{})
	if not layouts is Dictionary:return "원본 지도 저장 좌표 식별자가 손상되었습니다"
	for id: String in required:
		var expected: Dictionary=identity(id)
		var saved: Variant=layouts.get(id)
		if not same_identity(saved,expected):return "원본 지도 좌표·충돌·그림 변경: 명시적 세이브 이전이 필요합니다"
		var borrowed:bool=current_field!=null and current_field is FIELD and str(current_field.data.map_id)==id
		var field:RemakePlayableField
		if borrowed:
			# Recheck the pack files and pinned policy on every transaction (full
			# hashes whenever any verified file changed since the last check).
			# Only geometry decoding is reused; never close the live world's field.
			var context:Dictionary=verified_context(id)
			if context.is_empty() or current_field.png_game_pack.root_path!=root_path() or current_field.definition.source_sha256!=context.rule.grid_sha256 or int(current_field.data.layout_revision)!=int(context.rule.layout_revision):return "원본 지도 팩 누락·손상: 기존 저장을 보존합니다"
			field=current_field
		else:field=load_field(id)
		if field==null:return "원본 지도 팩 누락·손상: 기존 저장을 보존합니다"
		var doors: Variant=data.get("source_map84_doors",{}).get(id,{})
		if not doors is Dictionary:_close_validation_field(field,borrowed);return "문 상태 저장 형식이 손상되었습니다"
		if borrowed:
			if doors!=field.local_door_states:return "현재 지도와 문 상태 저장이 일치하지 않습니다"
		elif not field.apply_local_door_states(doors):field.close();return "문 상태 저장 형식이 손상되었습니다"
		# Validate every persisted spatial item before any live state is retired.
		if mid==id:
			var p: Variant=data.get("position",[])
			if not valid_position(field,p):_close_validation_field(field,borrowed);return "원본 지도 플레이어 저장 위치를 확인할 수 없습니다"
			var original: Variant=data.get("original_position",{})
			if not original is Dictionary or int(original.get("source_map_id",-1))!=int(field.definition.source_map_id) or original.get("grid_sha256")!=field.definition.source_sha256:
				_close_validation_field(field,borrowed);return "원본 지도 저장의 소스 좌표 식별자를 확인할 수 없습니다"
			var source: Variant=original.get("source",[])
			var restored: Vector2=field.coordinates.components_to_world(source) if source is Array else Vector2.INF
			if not restored.is_finite() or restored.distance_to(Vector2(p[0],p[1]))>.01:
				_close_validation_field(field,borrowed);return "원본 지도 저장의 화면 좌표와 소스 좌표가 일치하지 않습니다"
		for raw: Variant in drops:
			if not raw is Dictionary:continue
			var row: Dictionary=raw
			if str(row.get("map_id",""))==id and not valid_position(field,row.get("position",[])):
				_close_validation_field(field,borrowed);return "원본 지도 바닥 아이템 위치를 확인할 수 없어 기존 저장을 보존합니다"
		for container: String in ["monster_world","original_monster_world"]:
			for key: Variant in data.get(container,{}).get("bosses",{}):
				if not str(key).begins_with(id+":"):continue
				var state: Variant=data[container].bosses[key]
				if not state is Dictionary:_close_validation_field(field,borrowed);return "몬스터 위치 저장 형식이 손상되었습니다"
				for coordinate: String in ["position","home"]:
					var value: Variant=state.get(coordinate,[])
					if value is Array and value.is_empty():continue
					if not valid_position(field,value):_close_validation_field(field,borrowed);return "원본 지도 몬스터 저장 위치를 확인할 수 없습니다"
		_close_validation_field(field,borrowed)
	return ""

static func valid_position(field: PlayableField, value: Variant) -> bool:
	if not value is Array or value.size()!=2:return false
	for n: Variant in value:
		if not (n is int or n is float) or not is_finite(float(n)):return false
	var p:=Vector2(value[0],value[1])
	# A spawn->point path search costs up to ~200 ms on aden_world and every
	# save repeats it for the player, floor items and each boss position/home,
	# most of which have not moved. The answer depends only on this field's
	# immutable grid, its current door states and the exact point.
	var doors: Variant=field.get("local_door_states")
	var source_doors: Variant=field.get("source_doors")
	var opened: Variant=source_doors.get("opened") if source_doors is Object else null
	var key: Array=[field.get_instance_id(),hash(doors) if doors is Dictionary else 0,hash(opened) if opened is Dictionary else 0,p.x,p.y]
	if position_checks.has(key):return position_checks[key]
	var ok: bool=field.point_clear(p,4.0) and not field.path(Vector2(field.data.spawn_position[0],field.data.spawn_position[1]),p).is_empty()
	if position_checks.size()>=4096:position_checks.clear()
	position_checks[key]=ok
	return ok

static func _close_validation_field(field:RemakePlayableField,borrowed:bool) -> void:
	if not borrowed:field.close()
