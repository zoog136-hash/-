extends RefCounted
## Runtime promotion is separate from the immutable historical input contract.
## Each map needs reviewed entry, source-grid semantics, art and save identity.
const ART=preload("res://scripts/maps/source_map_review_pack.gd")
const FIELD=preload("res://scripts/maps/source_map_runtime_field.gd")
const POLICY_PATH="res://data/maps/source_map_runtime.json"
static var seen: Dictionary={}

static func root_path() -> String:
	var configured: String=OS.get_environment("TWILIGHT_SOURCE_MAP_PACK")
	return configured.trim_suffix("/") if not configured.is_empty() else "user://source_maps_v3"

static func policy() -> Dictionary:
	return ART.read_object(POLICY_PATH).get("maps",{})

static func supports(mid: String) -> bool:
	return policy().has(mid)

static func catalog_entries() -> Array:
	var result: Array=[]
	if not FileAccess.file_exists(root_path()+"/index.json"):return result
	for mid: String in policy():
		result.append({"id":mid,"name":str(policy()[mid].name),"width":1,"height":1,"tile_size_world":32,"source_map84":true})
	return result

static func load_field(mid: String) -> RemakePlayableField:
	if not supports(mid):return null
	var art=ART.new()
	if not art.open_pack(root_path()):return null
	var record: Dictionary=art.load_map(mid)
	if record.is_empty() or record.collision==null or record.selected_collision_version!="360":return null
	# This cohort has no dynamic source doors. Door-bearing maps require an
	# explicit state/physics adapter; ignoring a drawn closed door is unsafe.
	if not record.get("doors",[]).is_empty():return null
	var rule: Dictionary=policy()[mid]
	if int(record.source_map_id)!=int(rule.source_map_id) or str(record.collision.raw_sha256)!=str(rule.grid_sha256):return null
	if str(art.index.maps[mid].sha256)!=str(rule.art_manifest_sha256):return null
	var field=FIELD.new()
	if not field.configure_runtime(record,rule,art):field.close();return null
	seen[mid]=identity(mid)
	return field

static func identity(mid: String) -> Dictionary:
	if not supports(mid):return {}
	var p: Dictionary=policy()[mid]
	return {"source_map_id":int(p.source_map_id),"layout_revision":int(p.layout_revision),
		"grid_sha256":str(p.grid_sha256),"art_manifest_sha256":str(p.art_manifest_sha256)}

static func saved_layouts() -> Dictionary:
	return seen.duplicate(true)

static func validate_save(data: Dictionary) -> String:
	var required: Dictionary={}
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
	var layouts: Variant=data.get("source_map84_layouts",{})
	if not layouts is Dictionary:return "원본 지도 저장 좌표 식별자가 손상되었습니다"
	for id: String in required:
		var expected: Dictionary=identity(id)
		var saved: Variant=layouts.get(id)
		if not saved is Dictionary:return "원본 지도 저장 좌표 버전이 없어 기존 저장을 보존합니다"
		for key: String in expected:
			var value: Variant=saved.get(key)
			var match_value: bool=false
			if expected[key] is int:
				match_value=(value is int or value is float) and is_finite(float(value)) and float(value)==float(expected[key])
			else:match_value=value is String and value==expected[key]
			if not match_value:return "원본 지도 좌표·충돌·그림 변경: 명시적 세이브 이전이 필요합니다"
		var field: RemakePlayableField=load_field(id)
		if field==null:return "원본 지도 팩 누락·손상: 기존 저장을 보존합니다"
		# Validate every persisted spatial item before any live state is retired.
		if mid==id:
			var p: Variant=data.get("position",[])
			if not valid_position(field,p):field.close();return "원본 지도 플레이어 저장 위치를 확인할 수 없습니다"
			var original: Variant=data.get("original_position",{})
			if not original is Dictionary or int(original.get("source_map_id",-1))!=int(field.definition.source_map_id) or original.get("grid_sha256")!=field.definition.source_sha256:
				field.close();return "원본 지도 저장의 소스 좌표 식별자를 확인할 수 없습니다"
			var source: Variant=original.get("source",[])
			var restored: Vector2=field.coordinates.components_to_world(source) if source is Array else Vector2.INF
			if not restored.is_finite() or restored.distance_to(Vector2(p[0],p[1]))>.01:
				field.close();return "원본 지도 저장의 화면 좌표와 소스 좌표가 일치하지 않습니다"
		for raw: Variant in drops:
			if not raw is Dictionary:continue
			var row: Dictionary=raw
			if str(row.get("map_id",""))==id and not valid_position(field,row.get("position",[])):
				field.close();return "원본 지도 바닥 아이템 위치를 확인할 수 없어 기존 저장을 보존합니다"
		field.close()
	return ""

static func valid_position(field: PlayableField, value: Variant) -> bool:
	if not value is Array or value.size()!=2:return false
	for n: Variant in value:
		if not (n is int or n is float) or not is_finite(float(n)):return false
	var p:=Vector2(value[0],value[1])
	return field.point_clear(p,4.0) and not field.path(Vector2(field.data.spawn_position[0],field.data.spawn_position[1]),p).is_empty()
