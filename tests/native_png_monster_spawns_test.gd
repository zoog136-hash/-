extends SceneTree
## Offline contract: no private PNG is read. Real alpha/reachability is checked
## by the optional native_png_runtime_test with the user's verified art pack.
const REGISTRY = preload("res://scripts/maps/native_png_registry.gd")
const PLACEMENT = preload("res://scripts/monsters/native_png_spawns.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
const REGION = preload("res://scripts/maps/map_region_geometry.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("NATIVE_PNG_MONSTER_FAIL: "+label)

func vector(point: Array) -> Vector2:
	return Vector2(float(point[0]),float(point[1]))

func polygon(raw: Array) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for vertex: Array in raw: points.append(vector(vertex))
	return points

func traced_walkable(spec: Dictionary, p: Vector2) -> bool:
	for raw: Array in spec.walk_polygons:
		if Geometry2D.is_point_in_polygon(p,polygon(raw)): return true
	return false

func blocked(spec: Dictionary, p: Vector2) -> bool:
	for shape: Dictionary in spec.collision:
		match str(shape.get("shape","")):
			"circle":
				if p.distance_to(vector(shape.center)) < float(shape.radius)+12.: return true
			"polygon":
				if Geometry2D.is_point_in_polygon(p,polygon(shape.points)): return true
	return false

func count_candidates(spec: Dictionary, row: Dictionary) -> int:
	var bounds: Array=row.rect
	var prepared: Dictionary=REGION.prepare(row)
	var number: int=0
	for y: int in range(int(bounds[1])+16,int(bounds[1]+bounds[3]),48):
		for x: int in range(int(bounds[0])+16,int(bounds[0]+bounds[2]),48):
			var p:=Vector2(x,y)
			if REGION.contains(prepared,p) and traced_walkable(spec,p) and not blocked(spec,p):
				return 1 # Existence proof only; keep CI fast for the 114-polygon Escaros field.
	return number

func _initialize() -> void:
	var cfg: Dictionary=PLACEMENT.layout()
	var plan: Dictionary=REGISTRY.plan()
	check(not cfg.is_empty() and not plan.is_empty(),"hash-pinned spawn layout and reviewed PR128 geometry")
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json")) as Dictionary
	var registered: Dictionary={}
	for monster: Dictionary in CATALOG.expand(original.get("몬스터",[])):
		registered[str(monster.name)]=true
	var old_profiles: Dictionary=REGISTRY.read_json("res://data/monsters/world_spawn_profiles.json")
	var ids: Dictionary={}
	var normal_count: int=0
	var boss_count: int=0
	for mid: String in plan.get("maps",{}):
		var spec: Dictionary=plan.maps[mid]
		var manifest_rows: Array=cfg.get("maps",{}).get(mid,[])
		var built: Array=PLACEMENT.build(mid,spec,spec.get("portals",[]))
		check(built.size()==manifest_rows.size() and not built.is_empty(),mid+" full encounter layout built")
		var seen: Dictionary={}
		for row: Dictionary in built:
			var zone_id: String=str(row.get("id",""))
			check(not seen.has(zone_id),mid+" unique zone "+zone_id)
			seen[zone_id]=true
			check(not ids.has(mid+":"+zone_id),mid+" unique map-qualified spawn ID "+zone_id)
			ids[mid+":"+zone_id]=true
			check(row.get("coordinate_evidence","")=="reviewed_png_walk_polygons_local_unverified_original_positions",mid+" placement explicitly provisional")
			check(int(row.max_count)>0 and int(row.max_count)<=16,mid+" bounded population")
			check(row.exclusions.size()>=1,mid+" entry/portal safe buffers")
			check(row.get("polygons",[]).size()>0,mid+" verified traced ground polygons")
			check(count_candidates(spec,row)>0,mid+" sampled unblocked ground exists "+zone_id)
			for monster: String in row.monster_types:
				check(registered.has(monster),mid+" registered real monster "+monster)
			if str(row.mode)=="boss":
				boss_count+=1
				check(int(row.respawn_time)==86400,mid+" inherits existing renewed boss cooldown")
				check(row.get("boss_id","") in row.monster_types,mid+" recognized legacy boss")
				var state_map: String=str(row.get("boss_state_map_id",""))
				check(not state_map.is_empty() and old_profiles.maps.has(state_map),mid+" native boss inherits existing life and cooldown "+state_map)
				check(preload("res://scripts/monsters/boss_director.gd").new().key(mid,row)==state_map+":"+str(row.boss_id),mid+" existing boss persistence identity remains identical")
			else:
				normal_count+=int(row.max_count)
		if mid.begins_with("albino_") or mid=="escaros_world":
			for descriptor: Dictionary in manifest_rows:
				check(old_profiles.get("maps",{}).has(str(descriptor.get("source_map",""))),mid+" legacy roster source exists")
		else:
			check(built.all(func(row: Dictionary) -> bool: return str(row.mode)!="boss"),mid+" no fabricated temple boss")
	check(normal_count==289 and boss_count==8,"289 possible normal slots / eight existing boss species")
	check(ids.size()==56,"all 56 independent PNG spawn zones retained")
	print("NATIVE_PNG_MONSTER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"normal_slots":normal_count,"bosses":boss_count,"scope":"STATIC_WALK_POLYGON_NO_PRIVATE_ALPHA"}))
	quit(0 if failures.is_empty() else 1)
