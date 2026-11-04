extends "res://scripts/maps/native_png_field.gd"
## Main-game field interface; gameplay stays in the existing legacy pixel space.
const SOURCE_NAV=preload("res://scripts/maps/base508_registered_navigation.gd")
var source_navigation: RefCounted
var source_pack: RefCounted
var world_links: RefCounted

func configure_world_links(path: String, manifest_sha256: String) -> bool:
	if source_pack == null or not source_pack.loaded: return false
	var links = preload("res://scripts/maps/patch523_world_links.gd").new()
	if not links.load_land(path, int(source_pack.manifest.land.ID), str(source_pack.manifest.land.AssetPath), manifest_sha256): return false
	world_links = links
	data.source_definition_snapshot = "patch523"
	data.source_definition_manifest_sha256 = manifest_sha256
	data.source_definition_scope = "TERRITORY_AND_CONDITIONS_ONLY; NOT_CONFIRMED_INSTANCES"
	return true

func spawn_evidence(pack_id: int = -1) -> Array:
	return world_links.spawn_evidence(pack_id) if world_links != null else []

func spawn_conditions(pack_id: int) -> Dictionary:
	return world_links.pack_conditions(pack_id) if world_links != null else {}

func portal_context(portal_id: int) -> Dictionary:
	return world_links.portal_context(portal_id) if world_links != null else {}

func portal_contract(portal_id: int) -> Dictionary:
	return world_links.portal_contract(portal_id) if world_links != null else {}

func configure_source(pack: RefCounted, certificate: String, legacy_root: String, legacy_map: String, review_population: bool=false) -> bool:
	var candidate=SOURCE_NAV.new()
	if not candidate.configure(pack,certificate,legacy_root,legacy_map):return false
	var registry=preload("res://scripts/maps/native_png_registry.gd")
	var plan:Dictionary=registry.merge_review(registry.base_plan(),registry.read_json(registry.REVIEW_PATH),candidate.proof.plan_sha256)
	var manifest:Dictionary=registry.read_json(legacy_root+"/"+legacy_map+"/manifest.json")
	world_links = null # Reusing this field for another source must not retain old-Land links.
	configure_png(legacy_map,plan,manifest,legacy_root+"/"+legacy_map)
	source_navigation=candidate
	source_pack=pack
	data.map_id="%s_review_%s" % [pack.source_map_key(),legacy_map]
	data.map_name="base508 원본 지형 · 기존 검토 충돌"
	data.short_name=data.map_name
	data.portal=[] # Albino original destinations are regions: no invented landing point.
	data.teleport=[]
	data.npc_spawn=[]
	if not review_population:data.monster_spawn=[]
	data.population_status="LEGACY_REVIEW_POPULATION_NOT_ORIGINAL_M_SPAWNS" if review_population else "NO_ORIGINAL_CONFIRMED_INSTANCE_POINTS"
	data.source_coordinate_contract=pack.geographic_contract()
	data.collision_scope="REGISTERED_LEGACY_REVIEW_COLLISION; M_TERRAIN_UNKNOWN"
	set_meta("base508_source_test",true)
	set_meta("base508_legacy_map",legacy_map)
	for y:int in range(height):
		for x:int in range(width):
			var cell:=Vector2i(x,y)
			if not astar.is_point_solid(cell) and not source_navigation.safe_point(cell_to_world(cell)):astar.set_point_solid(cell,true)
	_build_reachability()
	return line_clear(Vector2(data.spawn_position[0],data.spawn_position[1]),Vector2(data.spawn_position[0],data.spawn_position[1]))

func walkable(point: Vector2) -> bool:
	return super.walkable(point) and (source_navigation==null or source_navigation.safe_point(point))

func point_clear(point: Vector2, padding: float=24.0) -> bool:
	return super.point_clear(point,padding) and (source_navigation==null or source_navigation.safe_point(point))

func line_clear(from: Vector2,to: Vector2) -> bool:
	if not super.line_clear(from,to):return false
	if source_navigation==null:return true
	var count:int=maxi(1,ceili(from.distance_to(to)/2.0))
	for i:int in range(count+1):
		if not source_navigation.safe_point(from.lerp(to,float(i)/count)):return false
	return true

func source_to_world(source: Vector2) -> Vector2:
	# Explicit review renderer policy: visual cell center; M actor foot is unknown.
	return (source_pack.COORDINATE_CONTRACT.visual_cell_center(source_pack.manifest,source)-source_navigation.translation)/source_navigation.scale

func world_to_source(world_point: Vector2) -> Vector2:
	return source_pack.COORDINATE_CONTRACT.source_from_grid_anchor(source_pack.manifest,source_navigation.to_render(world_point)-Vector2(24,12))

func actor_contract(actor: Node2D) -> Dictionary:
	if not is_instance_valid(actor):return {}
	var source:Vector2=world_to_source(actor.global_position)
	return {"map_key":source_pack.source_map_key(),"land_id":int(source_pack.manifest.land.ID),"asset_path":source_pack.manifest.land.AssetPath,"coordinate_space":source_pack.COORDINATE_CONTRACT.SPACE,"source_position":[source.x,source.y],"position_evidence":"PROJECTED_RUNTIME_REVIEW; NOT_AN_ORIGINAL_SPAWN_RECORD","actor_foot_policy":"VISUAL_CELL_CENTER; ORIGINAL_M_FOOT_UNVERIFIED"}

func place_confirmed_source_actor(actor: Node2D, record: Dictionary, cell: Vector2i, confirmed: Variant) -> bool:
	if not is_instance_valid(actor):return false
	if not confirmed is bool or not confirmed or not source_pack.COORDINATE_CONTRACT.accepts_record(source_pack.manifest,record):return false
	if not source_pack.COORDINATE_CONTRACT.supplied_cell(source_pack.manifest,cell):return false
	var point:Vector2=source_to_world(Vector2(cell))
	if not line_clear(point,point):return false
	actor.global_position=point
	actor.set_meta("base508_source_record",record.duplicate(true))
	return true

func overview_texture() -> Texture2D:
	return null # Existing minimap draws this field's exact legacy navigation geometry.

func portal_evidence() -> Array:
	if world_links != null: return world_links.portal_evidence()
	var result:Array=[]
	for portal:Dictionary in source_pack.portals:
		result.append({"portal":portal.duplicate(true),"runtime_enabled":false,"reason":"Destination is a source region; trigger and arrival selection unverified"})
	return result
