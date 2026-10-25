extends RefCounted
## World-space display geometry, owned by one minimap/field lifetime. The map
## is immutable between configure calls. Projection stays in the minimap so
## resizing or changing its bounds never retains old screen coordinates.
const GEOMETRY = preload("res://scripts/maps/map_region_geometry.gd")
var terrain: Array[Dictionary] = []
var hunting: Dictionary = {}
var intersections: int = 0

func configure(field: PlayableField) -> void:
	terrain.clear()
	hunting.clear()
	intersections = 0
	if field == null: return
	var definition: Dictionary = field.data
	if definition.has("world_geometry"):
		for zone: Dictionary in definition.world_geometry.terrain_zones:
			for raw: Array in definition.navigable_polygons:
				intersections += 1
				for polygon: PackedVector2Array in Geometry2D.intersect_polygons(GEOMETRY.polygon(zone),GEOMETRY.polygon({"polygon":raw})):
					terrain.append({"polygon":polygon,"color":Color(str(zone.tint))})
	if not definition.has("hunting_paths"): return
	for region: Dictionary in definition.get("regions",[]):
		if region.has("polygon") or str(region.type)=="safe": continue
		var id: String = str(region.id)
		if hunting.has(id): continue
		var polygons: Array[PackedVector2Array] = []
		for spawn: Dictionary in definition.get("monster_spawn",[]):
			if str(spawn.id)!=id: continue
			var geometry: PackedVector2Array
			if spawn.has("polygon"):
				geometry=GEOMETRY.polygon(spawn)
			else:
				var a: Array=spawn.rect
				geometry=PackedVector2Array([Vector2(a[0],a[1]),Vector2(a[0]+a[2],a[1]),Vector2(a[0]+a[2],a[1]+a[3]),Vector2(a[0],a[1]+a[3])])
			for floor: PackedVector2Array in field.navigable_polygons:
				intersections += 1
				polygons.append_array(Geometry2D.intersect_polygons(geometry,floor))
		hunting[id]=polygons
