extends RefCounted
## Preserve the current catalog's lives, species, levels and travel IDs. Only
## the explicitly reviewed PNG positions change, never a guessed server affine.
const CATALOG=preload("res://scripts/monsters/monster_catalog.gd")
const LEGACY="res://data/maps/domination_summit.json"

static func build(spec: Dictionary) -> Dictionary:
	var original: Variant=JSON.parse_string(FileAccess.get_file_as_string(LEGACY))
	if not original is Dictionary:return {}
	var current: Dictionary=CATALOG.apply_map(original)
	var zones: Array=[]
	var entry: Array=spec.spawn
	var exclusions: Array=[{"center":entry,"radius":48.0}]
	for portal: Dictionary in spec.portals:exclusions.append({"center":portal.position,"radius":float(portal.radius)+8})
	for npc: Dictionary in spec.npc_spawn:exclusions.append({"center":npc.position,"radius":48.0})
	for source: Dictionary in current.monster_spawn:
		var id: String=str(source.id)
		var points: Array=spec.get("encounter_polygons",{}).get(id,[])
		if points.size()<3:return {}
		var box:=Rect2(Vector2(points[0][0],points[0][1]),Vector2.ZERO)
		for p: Array in points:box=box.expand(Vector2(p[0],p[1]))
		var zone: Dictionary=source.duplicate(true)
		zone.rect=[box.position.x,box.position.y,box.size.x,box.size.y]
		zone.polygons=[points.duplicate(true)]
		zone.exclusions=exclusions.duplicate(true)
		zone.layout_revision=int(spec.layout_revision)
		zone.coordinate_evidence="MANUALLY_REVIEWED_111_PNG_COURTYARD_NOT_SERVER_COORDINATES"
		# Retain the existing boss life key across this coordinate migration.
		if str(zone.get("mode","normal"))=="boss":zone.boss_state_map_id="domination_summit"
		zones.append(zone)
	var npcs: Array=current.npc_spawn.duplicate(true)
	for npc: Dictionary in npcs:
		var found: bool=false
		for placement: Dictionary in spec.npc_spawn:
			if placement.id==npc.id:npc.position=placement.position.duplicate();found=true;break
		if not found:return {}
	var portals: Array=current.portal.duplicate(true)
	for portal: Dictionary in portals:
		var found: bool=false
		for placement: Dictionary in spec.portals:
			if placement.id!=portal.id:continue
			portal.position=placement.position.duplicate()
			if str(portal.target_map)=="domination_summit":
				portal.target_position=placement.target_position.duplicate()
				portal.target_layout_revision=int(spec.layout_revision)
			found=true;break
		if not found:return {}
	return {"monster_spawn":zones,"npc_spawn":npcs,"portal":portals}
