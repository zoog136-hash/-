extends SceneTree
const CACHE = preload("res://scripts/maps/minimap_geography_cache.gd")
const GEOMETRY = preload("res://scripts/maps/map_region_geometry.gd")
var checks: int = 0
var failures: Array[String] = []
var metrics: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("MINIMAP_CACHE_FAIL "+label)

func _initialize() -> void: call_deferred("run")

# Independent copy of the former draw-time clipping, preserving order/colors.
func previous_geometry(field: PlayableField) -> Array:
	var result: Array = []
	for zone: Dictionary in field.data.world_geometry.terrain_zones:
		for raw: Array in field.data.navigable_polygons:
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(GEOMETRY.polygon(zone),GEOMETRY.polygon({"polygon":raw})):
				result.append({"polygon":polygon,"color":Color(str(zone.tint))})
	for region: Dictionary in field.data.regions:
		if region.has("polygon") or str(region.type)=="safe" or not field.data.has("hunting_paths"): continue
		for spawn: Dictionary in field.data.get("monster_spawn",[]):
			if str(spawn.id)!=str(region.id): continue
			var geometry: PackedVector2Array
			if spawn.has("polygon"): geometry=GEOMETRY.polygon(spawn)
			else:
				var a: Array=spawn.rect
				geometry=PackedVector2Array([Vector2(a[0],a[1]),Vector2(a[0]+a[2],a[1]),Vector2(a[0]+a[2],a[1]+a[3]),Vector2(a[0],a[1]+a[3])])
			for floor: PackedVector2Array in field.navigable_polygons:
				for clipped: PackedVector2Array in Geometry2D.intersect_polygons(geometry,floor):
					result.append({"polygon":clipped,"color":Color(str(region.color),.16)})
	return result

func cached_geometry(cache: RefCounted, field: PlayableField) -> Array:
	var result: Array = cache.terrain.duplicate()
	for region: Dictionary in field.data.regions:
		if region.has("polygon") or str(region.type)=="safe" or not field.data.has("hunting_paths"): continue
		for polygon: PackedVector2Array in cache.hunting.get(str(region.id),[]):
			result.append({"polygon":polygon,"color":Color(str(region.color),.16)})
	return result

func run() -> void:
	var cache = CACHE.new()
	for map_id: String in ["albino_01","albino_02","escaros_01","oman_01"]:
		var field := PlayableField.new()
		field.data=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/"+map_id+".json"))
		for raw: Array in field.data.navigable_polygons: field.navigable_polygons.append(GEOMETRY.polygon({"polygon":raw}))
		cache.configure(field)
		var expected: Array=previous_geometry(field)
		var actual: Array=cached_geometry(cache,field)
		check(actual==expected,map_id+" exact polygon/order/color equivalence")
		check(actual.is_empty() if map_id=="oman_01" else not actual.is_empty(),map_id+" expected geometry presence")
		var began: int=Time.get_ticks_usec()
		for i: int in range(100): previous_geometry(field)
		var before: int=Time.get_ticks_usec()-began
		began=Time.get_ticks_usec()
		for i: int in range(100): cached_geometry(cache,field)
		var after: int=Time.get_ticks_usec()-began
		metrics.append({"map":map_id,"queries":100,"polygons":actual.size(),"clipping_calls_per_old_redraw":cache.intersections,"before_us":before,"after_us":after,"scope":"geometry CPU only; not frame time or Android"})
	cache.configure(null)
	check(cache.terrain.is_empty() and cache.hunting.is_empty(),"null map clears cache and field lifetime")
	var plain := PlayableField.new()
	plain.data={"regions":[],"monster_spawn":[]}
	cache.configure(plain)
	check(cache.terrain.is_empty() and cache.hunting.is_empty(),"native/empty map cannot retain previous geography")
	var output: String="user://minimap-geography-cache.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"metrics":metrics},"  "))
	file.close()
	print("MINIMAP_CACHE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty(): print("MINIMAP_CACHE_OK")
	quit(0 if failures.is_empty() else 1)
