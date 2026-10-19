extends RefCounted
## PR #128 follow-up. Reuse registered TWILIGHT species on the *reviewed*
## PNG walking geometry. These are local encounter areas, NOT original-game
## server coordinates, temple species evidence or independent map IDs.
const LAYOUT_PATH := "res://data/monsters/native_png_spawn_layout.json"
const LEGACY_PATH := "res://data/monsters/world_spawn_profiles.json"
const RULES_PATH := "res://data/monsters/renewed_map_spawn_rules.json"
const PLAN_PATH := "res://data/maps/native_png_plan.json"

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return result as Dictionary if result is Dictionary else {}

static func layout() -> Dictionary:
	var value: Dictionary = read_json(LAYOUT_PATH)
	if int(value.get("schema_version",0)) != 1: return {}
	if str(value.get("base_plan_sha256","")) != FileAccess.get_sha256(PLAN_PATH): return {}
	return value

static func _polygons_for(spec: Dictionary, entry: Dictionary) -> Array:
	if entry.has("walk_polygon"):
		var index: int = int(entry.walk_polygon)
		var polygons: Array = spec.get("walk_polygons",[])
		if index < 0 or index >= polygons.size(): return []
		return [polygons[index].duplicate(true)]
	var region_id: String = str(entry.get("region_id",""))
	for region: Dictionary in spec.get("regions",[]):
		if str(region.get("id","")) != region_id: continue
		return region.get("polygons",[]).duplicate(true)
	return []

static func _bounding_rect(polygons: Array) -> Array:
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for polygon: Array in polygons:
		if polygon.size()<3: return []
		for point: Array in polygon:
			if point.size()!=2: return []
			var value := Vector2(float(point[0]),float(point[1]))
			low=Vector2(minf(low.x,value.x),minf(low.y,value.y))
			high=Vector2(maxf(high.x,value.x),maxf(high.y,value.y))
	if not low.is_finite() or not high.is_finite() or high.x<=low.x or high.y<=low.y: return []
	return [floori(low.x),floori(low.y),ceili(high.x-low.x),ceili(high.y-low.y)]

static func build(mid: String, spec: Dictionary, portals: Array) -> Array:
	var config: Dictionary = layout()
	var definitions: Variant = config.get("maps",{}).get(mid,[])
	if not definitions is Array or definitions.is_empty(): return []
	var source_maps: Dictionary = read_json(LEGACY_PATH).get("maps",{})
	var settings: Dictionary = read_json(RULES_PATH)
	var boss_seconds: int = int(settings.get("boss_respawn_seconds",{}).get("other_maps",86400))
	if boss_seconds < 1: return []
	var entry_position: Array = spec.get("spawn",[])
	if entry_position.size()!=2: return []
	var exclusions: Array = [{"center":entry_position.duplicate(true),"radius":float(config.get("spawn_exclusion_radius",320))}]
	for portal: Dictionary in portals:
		if portal.get("position",[]) is Array and portal.position.size()==2:
			exclusions.append({"center":portal.position.duplicate(true),"radius":float(config.get("portal_exclusion_radius",180))})
	var result: Array = []
	var ids: Dictionary = {}
	for record: Dictionary in definitions:
		var zone_id: String = str(record.get("id",""))
		if zone_id.is_empty() or ids.has(zone_id): return []
		ids[zone_id]=true
		var polygons: Array = _polygons_for(spec,record)
		var box: Array = _bounding_rect(polygons)
		if box.is_empty(): return []
		if record.has("rect_override"):
			var special: Array = record.rect_override
			if special.size()!=4 or special[2]<=0 or special[3]<=0: return []
			if special[0]<box[0] or special[1]<box[1] or special[0]+special[2]>box[0]+box[2] or special[1]+special[3]>box[1]+box[3]: return []
			box=special.duplicate(true)
		var source: Dictionary = {}
		var roster_source: String = str(record.get("source_map",""))
		if not roster_source.is_empty():
			for candidate: Dictionary in source_maps.get(roster_source,{}).get("monster_spawn",[]):
				if str(candidate.get("id","")) == str(record.get("source_zone","")):
					source=candidate
					break
			# Missing historical rows fail closed: do not fabricate an enemy.
			if source.is_empty(): return []
		var names: Array = source.get("monster_types",record.get("monster_types",[]))
		if names.is_empty(): return []
		var count: int = int(record.get("max_count",source.get("max_count",0)))
		if count < 1 or count > 16: return []
		var is_boss: bool = str(source.get("mode",record.get("mode","normal"))) == "boss"
		var row: Dictionary = {
			"id":zone_id,"rect":box,"polygons":polygons,"exclusions":exclusions.duplicate(true),
			"monster_types":names.duplicate(true),"max_count":count,"mode":"boss" if is_boss else "normal",
			"respawn_time":boss_seconds if is_boss else int(source.get("respawn_time",25)),
			"roaming_radius":int(source.get("roaming_radius",120)),
			"min_spacing":40,"spawn_radius":0,
			"roster_evidence":"existing_world_spawn_profile" if not roster_source.is_empty() else "provisional_registered_temple_species",
			"coordinate_evidence":"reviewed_png_walk_polygons_local_unverified_original_positions",
			"layout_revision":1
		}
		if source.has("weights"): row["weights"]=source.weights.duplicate(true)
		if is_boss:
			row["boss_id"]=str(source.get("boss_id",names[0]))
			row["map_id"]=mid
			row["verification_status"]={"exact_spawn_area":"unverified","schedule":"twilight_boss_policy","roster":"existing_world_spawn_profile"}
		result.append(row)
	return result
