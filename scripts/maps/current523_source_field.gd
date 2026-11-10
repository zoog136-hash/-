extends "res://scripts/maps/current523_aden_source_field.gd"
## Common terrain field for a selected native M Land, with an explicit own rule.
## Logical identity is never inferred from a numeric physical folder name.
const GEOGRAPHIC_CONTRACT="CURRENT523_S32_OWN_SOURCE_FIELD_V1"
const SOURCE_PACK = preload("res://scripts/maps/current523_source_pack.gd")
var native_land: Dictionary = {}
var source_asset: String = ""
var catalog_root: String = ""
var catalog_sha256: String = ""
var availability: Dictionary = {}
var unavailable_sources: Dictionary = {}

func configure_current523(_raw_root: String, _interpretation: Dictionary = {}) -> bool:
	return _fail("공통 필드는 명시된 카탈로그 SHA와 논리 Land ID가 필요합니다.")

func configure_catalog(directory: String, expected_manifest_sha256: String, land_id: int, interpretation: Dictionary = {}) -> bool:
	var originals = SOURCE_PACK.new()
	if not originals.load_catalog(directory,expected_manifest_sha256): return _fail(originals.problem)
	return configure_verified_catalog(originals,expected_manifest_sha256,land_id,interpretation)

func configure_verified_catalog(catalog: RefCounted, expected_manifest_sha256: String, land_id: int, interpretation: Dictionary = {}) -> bool:
	close()
	problem = ""
	if not _configure_policy(interpretation): return false
	if catalog==null or catalog.get_script()!=SOURCE_PACK or not SOURCE_PACK.S32_FORMAT._sha(expected_manifest_sha256) or catalog.catalog_identity().get("manifest_sha256")!=expected_manifest_sha256: return _fail("검증된 동일 SHA 카탈로그가 필요합니다.")
	var originals: RefCounted=catalog.fork_catalog()
	if originals==null: return _fail("검증된 카탈로그 복사에 실패했습니다.")
	var directory: String=originals.catalog_directory()
	var record: Dictionary = originals.land_record(land_id)
	if record.is_empty(): return _fail("선택한 논리 Land 선언이 없습니다.")
	if record.policy_status!="classified" or not record.excluded_content.is_empty(): return _fail("제외되었거나 범위가 미확인인 콘텐츠는 열지 않습니다.")
	var declaration: Dictionary = record.declaration
	if not originals.select_asset(str(declaration.AssetPath)): return _fail(originals.problem)
	_raw = originals
	native_land = declaration.duplicate(true)
	source_asset = str(declaration.AssetPath)
	catalog_root = directory
	catalog_sha256 = expected_manifest_sha256
	availability = originals.read_metadata().asset
	var minimum := Vector2i(2147483647,2147483647)
	var maximum := Vector2i(-2147483647,-2147483647)
	var supported: Dictionary = {}
	for member: String in originals.supported_s32_members(): supported[member]=true
	for member: String in originals.source_members():
		var metadata: Dictionary = originals.source_metadata(member)
		var origin: Variant = SOURCE_PACK.candidate_origin(member)
		if origin==null and supported.has(member): origin=_inferred_origin(member,metadata)
		if origin==null:
			if supported.has(member): unplaced_members.append(member)
			else: unavailable_sources[member]=str(metadata.get("status","unsupported"))
			continue
		# Missing expected chunks contribute only to declared extent, never floor.
		minimum = minimum.min(origin)
		maximum = maximum.max(origin+Vector2i(64,64))
		if not supported.has(member): unavailable_sources[member]=str(metadata.get("status","unavailable")); continue
		if _source_chunks.has(origin): return _fail("서로 다른 원문이 같은 후보 청크에 대응합니다.")
		source_origins[member]=origin
		_source_chunks[origin]=member
	if source_origins.is_empty(): return _fail("이 Land에는 검증된 배치 가능 S32 원문이 없습니다.")
	source_bounds=Rect2i(minimum,maximum-minimum)
	if not coordinates.configure([minimum.x,minimum.y],[source_bounds.size.x,source_bounds.size.y],policy.coordinate_mapping): return _fail("선택한 원문의 후보 좌표 범위가 지원되지 않습니다.")
	width=source_bounds.size.x; height=source_bounds.size.y
	bounds=coordinates.canvas_bounds()
	astar=AStarGrid2D.new(); astar.region=Rect2i(0,0,1,1); astar.update()
	definition={"map_id":"m523_land_"+str(land_id),"source_map_id":land_id,"source_land_id":land_id,"source_asset_path":source_asset,"geographic_contract":GEOGRAPHIC_CONTRACT,"source_sha256":str(availability.source_inventory_sha256),"source_manifest_sha256":catalog_sha256,"origin":[minimum.x,minimum.y],"dimensions":[width,height],"layout_revision":5230001,"navigation":{"profile":OWN_PROFILE},"native_m_rules_verified":false}
	# The original Land name only; development tags are not shown in the game.
	var title: String = str(native_land.Name)
	data={"map_id":definition.map_id,"source_land_id":land_id,"map_name":title,"short_name":str(native_land.Name),"layout_revision":5230001,"navigation_profile":str(policy.get("profile",OWN_PROFILE)),"spawn_position":[],"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"collision":[],"regions":[],"water":[],"roads":[],"surfaces":[],"npc_spawn":[],"monster_spawn":[],"portal":[],"navigation":{"profile":OWN_PROFILE},"camera":{"zoom":1.0,"offset":[0,-32],"follow_speed":8.0},"streaming":{"monster_sleep_distance":1600},"native_m_rules_verified":false}
	loaded=true
	if interpretation.has("spawn_source"):
		var entry: Variant=interpretation.spawn_source
		if not _integer_pair(entry): return _fail("원문 입장 좌표가 올바르지 않습니다.")
		var position: Vector2=coordinates.to_world(Vector2(entry[0],entry[1]))
		if not point_clear(position,4): return _fail("입장 셀을 자체 통행에서 확인하지 못했습니다.")
		data.spawn_position=[position.x,position.y]
	set_meta("current523_source_field",true)
	set_meta("current523_generic_field",true)
	return true

func region_at(_point: Vector2) -> Dictionary:
	return {"id":"m523_land_"+str(native_land.get("ID",-1)),"name":str(data.get("map_name","원문 필드")),"type":"neutral","color":"738e81","native_m_rules_verified":false}

func scope_metrics() -> Dictionary:
	return {"loaded":loaded,"native_land_id":native_land.get("ID",-1),"native_asset_path":source_asset,"source_manifest_sha256":catalog_sha256,"expected_sources":_raw.source_members().size() if loaded else 0,"ready_placed_sources":source_origins.size(),"unplaced_sources":unplaced_members.size(),"inferred_placements":inferred_placements.duplicate(true),"unavailable_sources":unavailable_sources.duplicate(),"asset_status":availability.get("status","unavailable"),"native_m_rules_verified":false}

func _fail(message: String) -> bool:
	close()
	problem = message
	return false

func close() -> void:
	super.close()
	native_land.clear(); source_asset=""; catalog_root=""; catalog_sha256=""
	availability.clear(); unavailable_sources.clear()
	if has_meta("current523_generic_field"): remove_meta("current523_generic_field")

func source_geographic_contract() -> Dictionary:
	if not loaded or not has_meta("current523_generic_field"): return {}
	return {"schema":1,"geographic_contract":GEOGRAPHIC_CONTRACT,"native_land_id":int(native_land.ID),"native_land":native_land.duplicate(true),"native_asset_path":source_asset,"source_snapshot":523,"source_manifest_sha256":catalog_sha256,"source_inventory_sha256":definition.get("source_sha256",""),"native_land_table_sha256":SOURCE_PACK.LAND_SHA256,"coordinate_profile":"OWN_8HEX_64CELL_24X12_V1","collision_profile":OWN_PROFILE,"own_policy":policy.duplicate(true),"manifest_identity_verified":true,"source_bytes_verified_on_read":true,"native_m_rules_verified":false,"scope":scope_metrics()}

func choose_source_landing(declared_bounds: Array, selection_policy: String = "EXACT_POINT_ONLY", search_budget: int = 4096) -> Dictionary:
	var result: Dictionary={"ok":false,"reason":"invalid_bounds","selection_policy":selection_policy,"native_landing_rule_verified":false}
	if not loaded: result.reason="source_field_unavailable"; return result
	if declared_bounds.size()!=4 or search_budget<1 or search_budget>65536: return result
	for value: Variant in declared_bounds:
		if not SOURCE_PACK.S32_FORMAT._uint(value,65535): return result
	var minimum:=Vector2i(int(declared_bounds[0]),int(declared_bounds[1]))
	var maximum:=Vector2i(int(declared_bounds[2]),int(declared_bounds[3]))
	if minimum.x>maximum.x or minimum.y>maximum.y: result.reason="inverted_bounds"; return result
	if selection_policy not in ["EXACT_POINT_ONLY","OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1"]: result.reason="unknown_landing_policy"; return result
	if minimum!=maximum and selection_policy=="EXACT_POINT_ONLY": result.reason="area_target_requires_explicit_own_policy"; return result
	var inspected: int=0
	for y: int in range(minimum.y,maximum.y+1):
		for x: int in range(minimum.x,maximum.x+1):
			if inspected>=search_budget: result.reason="search_budget_exhausted"; result.inspected_cells=inspected; return result
			inspected+=1
			var cell:=Vector2i(x,y)
			var info: Dictionary=source_cell_info(cell)
			if info.status=="source_integrity_failure": result.reason="source_integrity_failure"; return result
			if not info.walkable: continue
			var position: Vector2=coordinates.to_world(Vector2(cell))
			if not point_clear(position,4.0): continue
			result.merge({"ok":true,"reason":"","source_cell":cell,"source_components":[x+0.5,y+0.5],"world_position":position,"source_info":info.duplicate(true),"inspected_cells":inspected,"declared_bounds":declared_bounds.duplicate(),"geographic_contract":source_geographic_contract()},true)
			return result
	result.reason="no_confirmed_clear_cell"; result.inspected_cells=inspected
	return result
