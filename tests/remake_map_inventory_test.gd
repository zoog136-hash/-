extends SceneTree
## Runtime catalog membership is distinct from verified entry/routes/portals.
const FIELD = preload("res://scripts/maps/playable_field.gd")
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
const SOURCE_TRAVEL = preload("res://scripts/maps/source_travel.gd")
# Retired areas are archived for old saves but must not count as live portal destinations.
const RETIRED_MAPS: Array[String] = ["albino_03", "albino_04"]
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("REMAKE_MAP_INVENTORY_FAIL "+label)

func vector(raw: Array) -> Vector2: return Vector2(raw[0],raw[1])
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var registered: Dictionary = {}
	for record: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/maps_v18.json")):
		var map_id: String = str(record.id)
		if map_id not in RETIRED_MAPS:
			registered[map_id] = true
	var entries: Array = []
	# The disk index also retains source files for retired areas: only test live maps.
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")):
		if str(entry.map_id) in RETIRED_MAPS:
			check(FileAccess.file_exists(str(entry.path)), str(entry.map_id)+" archived map data retained for migration")
			continue
		entries.append(entry)
	var source_entries: Array = SOURCE_TRAVEL.catalog_entries()
	for record: Dictionary in source_entries: registered[str(record.id)] = true
	var entered: Array[String] = []
	var graph: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261013
	for entry: Dictionary in entries:
		var data: Dictionary = CATALOG.apply_map(JSON.parse_string(FileAccess.get_file_as_string(str(entry.path))))
		var id: String = str(data.map_id)
		check(registered.has(id),id+" registered in active map menu")
		var field := FIELD.new()
		field.configure(data)
		var spawn: Vector2 = vector(data.spawn_position)
		var valid: bool = field.walkable(spawn) and field.point_clear(spawn)
		check(valid,id+" entry has navigation and body clearance")
		if valid: entered.append(id)
		check(field.astar.diagonal_mode == AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES,id+" diagonal corner collision policy preserved")
		graph[id] = []
		for portal: Dictionary in data.portal:
			var target: String = str(portal.target_map)
			check(registered.has(target),id+" portal destination registered: "+target)
			var point: Vector2 = vector(portal.position)
			var route: PackedVector2Array = field.path(spawn,point)
			check(field.point_clear(point) and not route.is_empty(),id+" portal approach reachable: "+str(portal.id))
			for i: int in range(1,route.size()): check(field.line_clear(route[i-1],route[i]),id+" portal path segment avoids blocked corners")
			if target == id and portal.has("target_position"):
				var landing: Vector2 = vector(portal.target_position)
				check(field.point_clear(landing) and not field.path(spawn,landing).is_empty(),id+" local portal landing connected: "+str(portal.id))
			graph[id].append(target)
		for npc: Dictionary in data.npc_spawn:
			check(field.point_clear(vector(npc.position)) and not field.path(spawn,vector(npc.position)).is_empty(),id+" service reachable: "+str(npc.id))
		for region: Dictionary in data.monster_spawn:
			for i: int in range(4):
				var point: Vector2 = field.sample_spawn(str(region.id),rng)
				check(point.is_finite() and field.walkable(point) and field.point_clear(point) and not field.is_safe(point),id+" spawn sampling: "+str(region.id))
		print("REMAKE_MAP_VERIFIED ",id," entry=",valid," portals=",data.portal.size()," spawn_regions=",data.monster_spawn.size()," blockers=",field.blockers.size())
	var source_aden=preload("res://scripts/maps/source_map_runtime.gd").load_field("aden_world")
	check(source_aden!=null,"source84 Aden supplies current portal hub")
	graph["aden_world"]=[]
	if source_aden!=null:
		for portal:Dictionary in source_aden.data.portal:graph["aden_world"].append(str(portal.target_map))
		source_aden.close()
	var reachable: Array[String] = ["aden_world"]
	var cursor: int = 0
	while cursor<reachable.size():
		var id: String = reachable[cursor]
		cursor += 1
		for target: String in graph.get(id,[]):
			if not reachable.has(target): reachable.append(target)
	check(entered.size()==entries.size(),"all authored entries verified")
	for id:String in entered:check(reachable.has(id),"retained map reachable via current Aden hub "+id)
	# Optional source maps are counted only if supplied by their actual catalog;
	# code support or absent external terrain never counts as a rendered map.
	var source_loadable: Array[String] = []
	for record: Dictionary in source_entries:
		var field = SOURCE_TRAVEL.load_field(record)
		if field != null:
			source_loadable.append(str(record.id))
			field.close()
	print("REMAKE_MAP_INVENTORY ",JSON.stringify({"registered":registered.keys(),"authored_entry_verified":entered,"authored_portal_reachable":reachable,"source_registered":source_entries.size(),"source_entry_verified":source_loadable,"original_terrain_delivery_claimed":false}))
	print("REMAKE_MAP_INVENTORY_OK " if failures.is_empty() else "REMAKE_MAP_INVENTORY_FAILED ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
