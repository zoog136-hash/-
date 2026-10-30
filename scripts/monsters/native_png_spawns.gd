extends RefCounted
## PR #128 follow-up. Reuse registered TWILIGHT species on the *reviewed*
## PNG walking geometry. These are local encounter areas, NOT original-game
## server coordinates, temple species evidence or independent map IDs.
const LAYOUT_PATH := "res://data/monsters/native_png_spawn_layout.json"
const LEGACY_PATH := "res://data/monsters/world_spawn_profiles.json"
const RULES_PATH := "res://data/monsters/renewed_map_spawn_rules.json"
const PLAN_PATH := "res://data/maps/native_png_plan.json"
const EXTRA_LAYOUT_PATH := "res://data/monsters/aden_faith_png_spawn_layout.json"
const EXTRA_PLAN_PATH := "res://data/maps/aden_faith_png_plan.json"
const EXTRA_MAP_IDS := ["faith_01","faith_02","faith_03","faith_04"]
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
const LOOT = preload("res://scripts/loot_drop.gd")

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return result as Dictionary if result is Dictionary else {}

static func layout() -> Dictionary:
	var value: Dictionary = read_json(LAYOUT_PATH)
	if int(value.get("schema_version",0)) != 1: return {}
	if str(value.get("base_plan_sha256","")) != FileAccess.get_sha256(PLAN_PATH): return {}
	return value

static func extra_layout() -> Dictionary:
	# The new five maps have a different coordinate plan. Never let a matching
	# PR128 hash authorize encounters on the Aden/Faith canvas, or vice versa.
	var value: Dictionary = read_json(EXTRA_LAYOUT_PATH)
	if int(value.get("schema_version",0)) != 1: return {}
	if str(value.get("base_plan_sha256","")) != FileAccess.get_sha256(EXTRA_PLAN_PATH): return {}
	if not value.get("maps",{}) is Dictionary or not value.get("map_settings",{}) is Dictionary: return {}
	return value

static func _polygons_for(spec: Dictionary, entry: Dictionary) -> Array:
	if entry.has("polygons"):
		return entry.polygons.duplicate(true) if entry.polygons is Array else []
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
	if mid in EXTRA_MAP_IDS: return _build_extra(mid,spec,portals)
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
			# PNG Escaros merges five old fields; cooldown and remaining HP are
			# intentionally shared with each corresponding original field boss.
			row["boss_state_map_id"]=roster_source if not roster_source.is_empty() else mid
			row["verification_status"]={"exact_spawn_area":"unverified","schedule":"twilight_boss_policy","roster":"existing_world_spawn_profile"}
		result.append(row)
	return result

static func _packed_polygon(raw: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if raw.size()<3: return polygon
	for point: Variant in raw:
		if not point is Array or point.size()!=2: return PackedVector2Array()
		if not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int): return PackedVector2Array()
		var vertex := Vector2(float(point[0]),float(point[1]))
		if not vertex.is_finite(): return PackedVector2Array()
		polygon.append(vertex)
	return polygon

static func _raw_polygon(polygon: PackedVector2Array) -> Array:
	var result: Array = []
	for vertex: Vector2 in polygon: result.append([vertex.x,vertex.y])
	return result

static func _extra_polygons(spec: Dictionary, record: Dictionary) -> Array:
	var requested: Array = _polygons_for(spec,record)
	if requested.is_empty(): return []
	var result: Array = []
	for raw: Variant in requested:
		if not raw is Array: return []
		var polygon: PackedVector2Array = _packed_polygon(raw)
		if polygon.is_empty(): return []
		# Authored encounter outlines are clipped to the reviewed walking floor.
		# Final navigation, source alpha and explicit obstacles still filter cells.
		for ground: Array in spec.get("walk_polygons",[]):
			var floor_polygon: PackedVector2Array = _packed_polygon(ground)
			if floor_polygon.is_empty(): return []
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(polygon,floor_polygon):
				if clipped.size()>=3: result.append(_raw_polygon(clipped))
	if not record.has("rect_override"): return result
	var box: Array = record.rect_override
	if box.size()!=4 or float(box[2])<=0.0 or float(box[3])<=0.0: return []
	var rectangle := PackedVector2Array([
		Vector2(box[0],box[1]),Vector2(box[0]+box[2],box[1]),
		Vector2(box[0]+box[2],box[1]+box[3]),Vector2(box[0],box[1]+box[3])])
	var limited: Array = []
	for raw: Array in result:
		for clipped: PackedVector2Array in Geometry2D.intersect_polygons(_packed_polygon(raw),rectangle):
			if clipped.size()>=3: limited.append(_raw_polygon(clipped))
	# A rectangle must constrain saved homes and patrols too, not just the
	# candidate-cell loop. RegionGeometry gives polygons priority over rect.
	return limited

static func _registered_records() -> Dictionary:
	if CATALOG.records_by_name.is_empty():
		CATALOG.expand(read_json("res://data/game_db_v17.json").get("몬스터",[]))
	return CATALOG.records_by_name

static func _build_extra(mid: String, spec: Dictionary, portals: Array) -> Array:
	var config: Dictionary = extra_layout()
	var definitions: Variant = config.get("maps",{}).get(mid,[])
	if not definitions is Array or definitions.is_empty(): return []
	var map_settings: Dictionary = config.get("map_settings",{}).get(mid,{})
	var source_maps: Dictionary = read_json(LEGACY_PATH).get("maps",{})
	var records: Dictionary = _registered_records()
	var settings: Dictionary = read_json(RULES_PATH)
	var boss_policy: String = "aden_world" if mid=="aden_world" else "other_maps"
	var boss_seconds: int = int(settings.get("boss_respawn_seconds",{}).get(boss_policy,0))
	if boss_seconds<1: return []
	var entry_position: Array = spec.get("spawn",[])
	if entry_position.size()!=2: return []
	var entry_radius: float = float(map_settings.get("spawn_exclusion_radius",320))
	var portal_radius: float = float(map_settings.get("portal_exclusion_radius",180))
	if entry_radius<0.0 or portal_radius<0.0: return []
	var exclusions: Array = [{"center":entry_position.duplicate(true),"radius":entry_radius}]
	for portal: Dictionary in portals:
		if portal.get("position",[]) is Array and portal.position.size()==2:
			exclusions.append({"center":portal.position.duplicate(true),"radius":maxf(portal_radius,float(portal.get("radius",18))+4.0)})
	for safe: Dictionary in spec.get("regions",[]):
		if str(safe.get("type",""))=="safe": exclusions.append(safe.duplicate(true))
	exclusions.append_array(map_settings.get("exclusions",[]).duplicate(true))
	var result: Array = []
	var ids: Dictionary = {}
	for record: Dictionary in definitions:
		var zone_id: String = str(record.get("id",""))
		if zone_id.is_empty() or ids.has(zone_id): return []
		ids[zone_id]=true
		var polygons: Array = _extra_polygons(spec,record)
		var box: Array = _bounding_rect(polygons)
		if box.is_empty(): return []
		var roster_source: String = str(record.get("source_map",""))
		var source_zone: String = str(record.get("source_zone",""))
		var source: Dictionary = {}
		if not source_zone.is_empty():
			for candidate: Dictionary in source_maps.get(roster_source,{}).get("monster_spawn",[]):
				if str(candidate.get("id",""))==source_zone:
					source=candidate
					break
			if source.is_empty(): return []
		var source_names: Array = source.get("monster_types",[])
		var requested_names: Array = record.get("monster_types",source_names)
		var is_boss: bool = str(source.get("mode",record.get("mode","normal")))=="boss"
		var names: Array = []
		var weights: Array = []
		var authored_weights: Array = record.get("weights",[])
		var source_weights: Array = source.get("weights",[])
		var has_authored_weights: bool = not authored_weights.is_empty() and authored_weights.size()==requested_names.size()
		var has_source_weights: bool = not source_weights.is_empty() and source_weights.size()==source_names.size()
		for index: int in range(requested_names.size()):
			var monster_name: String = str(requested_names[index])
			if not records.has(monster_name): return []
			if not source.is_empty() and not source_names.has(monster_name): return []
			if names.has(monster_name): continue
			var boss_record: bool = LOOT.is_boss_record(records[monster_name])
			if is_boss and not boss_record: return []
			# Raw historical Aden habitats still include the dedicated dark elder.
			# Use the same classification as combat and loot before making a life.
			if not is_boss and boss_record: continue
			names.append(monster_name)
			if has_authored_weights: weights.append(authored_weights[index])
			elif has_source_weights: weights.append(source_weights[source_names.find(monster_name)])
		if names.is_empty(): return []
		var count: int = int(record.get("max_count",source.get("max_count",0)))
		if count<1 or count>16 or (is_boss and (count!=1 or names.size()!=1)): return []
		var local_exclusions: Array = exclusions.duplicate(true)
		local_exclusions.append_array(record.get("exclusions",[]).duplicate(true))
		var spacing: float = float(record.get("min_spacing",map_settings.get("min_spacing",40)))
		if spacing<8.0: return []
		var row: Dictionary = {
			"id":zone_id,"rect":box,"polygons":polygons,"exclusions":local_exclusions,
			"monster_types":names,"max_count":count,"mode":"boss" if is_boss else "normal",
			"respawn_time":boss_seconds if is_boss else int(source.get("respawn_time",record.get("respawn_time",25))),
			"roaming_radius":int(record.get("roaming_radius",map_settings.get("roaming_radius",source.get("roaming_radius",120)))),
			"min_spacing":spacing,"spawn_radius":0,
			"roster_evidence":"existing_world_spawn_profile" if not source.is_empty() else "existing_registered_monster",
			"coordinate_evidence":"reviewed_png_walk_polygons_local_unverified_original_positions",
			"layout_revision":int(config.get("layout_revision",2026102002))
		}
		if weights.size()==names.size(): row["weights"]=weights
		if bool(map_settings.get("constrain_patrol",true)):
			row["patrol_region"]={"polygons":polygons.duplicate(true),"exclusions":local_exclusions.duplicate(true)}
		if is_boss:
			row["boss_id"]=str(source.get("boss_id",record.get("boss_id",names[0])))
			row["boss_name"]=names[0]
			row["map_id"]=mid
			row["boss_state_map_id"]=str(record.get("boss_state_map_id",roster_source if not roster_source.is_empty() else mid))
			row["initial_delay"]=float(source.get("initial_delay",0))
			row["respawn_policy"]="wall_clock"
			row["encounter_region"]={"polygons":polygons.duplicate(true),"exclusions":local_exclusions.duplicate(true)}
			row["verification_status"]={"exact_spawn_area":"unverified","schedule":"twilight_boss_policy","roster":row.roster_evidence}
		result.append(row)
	return result
