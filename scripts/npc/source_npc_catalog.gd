extends RefCounted
## Six approved identities. Original map labels are provenance, never runtime aliases.
const PATH = "res://data/npc/source_six.json"
const BINDINGS = "res://data/npc/source_six_bindings.json"
const PROTECTED = ["albino_01","albino_02","escaros_01","escaros_02","escaros_03","escaros_04","escaros_05","faith_01","faith_02","faith_03","faith_04"]
static var _records: Dictionary = {}

static func records() -> Dictionary:
	if _records.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for raw: Dictionary in parsed.get("npcs",[]):
				_records[str(raw.id)] = raw
	return _records

static func record(id: String) -> Dictionary:
	return records().get(id,{}).duplicate(true)

static func nearby(world: Node, id: String) -> bool:
	if not records().has(id) or world.field_map == null or not is_instance_valid(world.player): return false
	for npc: Dictionary in world.field_map.data.get("npc_spawn",[]):
		if str(npc.get("source_catalog_id","")) != id or str(npc.get("id","")) != id: continue
		var p: Array = npc.get("position",[])
		if p.size() == 2 and world.player.global_position.distance_to(Vector2(float(p[0]),float(p[1]))) <= 190.0: return true
	return false

static func nearby_ids(world: Node) -> Dictionary:
	var found: Dictionary = {}
	for id: String in records():
		if nearby(world,id): found[id] = true
	return found

static func append_to_field(field: Object, bindings: Array = []) -> Array[Dictionary]:
	var holds: Array[Dictionary] = []
	if bindings.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDINGS))
		if parsed is Dictionary: bindings = parsed.get("bindings",[])
	var map_id: String = str(field.data.get("map_id",""))
	if map_id in PROTECTED: return holds
	# Only actual installed source definitions expose this exact coordinate contract.
	var definition: Variant = field.get("definition")
	var coordinates: Variant = field.get("coordinates")
	if not definition is Dictionary or coordinates == null: return holds
	for binding: Dictionary in bindings:
		if not bool(binding.get("enabled",false)) or str(binding.get("game_map_id","")) != map_id: continue
		var id: String = str(binding.get("npc_id",""))
		var npc: Dictionary = record(id)
		if npc.is_empty(): continue
		var spawn: Dictionary = npc.spawns[0]
		var reason: String = ""
		if int(definition.get("source_map_id",-1)) != int(spawn.source_map_id) or str(binding.get("source_grid_sha256","")) != str(definition.get("source_sha256","")) or str(binding.get("source_grid_sha256","")).length() != 64:
			reason = "source map identity/grid binding mismatch"
		elif str(spawn.get("source_position_mode","")) != "fixed_point":
			reason = "random-offset placement requires separate verified policy"
		elif str(binding.get("visual_sha256","")) != str(npc.visual.sha256) or not bool(binding.get("actor_foot_reviewed",false)) or not binding.get("foot_pixels",null) is Array or binding.foot_pixels.size() != int(npc.visual.heading_slots):
			reason = "actor foot registration unresolved"
		if not reason.is_empty():
			holds.append({"id":id,"reason":reason})
			continue
		var feet_valid: bool = true
		for foot: Variant in binding.foot_pixels:
			if not foot is Array or foot.size() != 2: feet_valid = false; break
			for component: Variant in foot:
				if not (component is int or component is float) or not is_finite(float(component)): feet_valid = false
		if not feet_valid: holds.append({"id":id,"reason":"invalid foot pixels"}); continue
		var p: Vector2 = coordinates.to_world(Vector2(float(spawn.source_position[0]),float(spawn.source_position[1])))
		if not p.is_finite() or not field.walkable(p): holds.append({"id":id,"reason":"source cell is not walkable"}); continue
		var duplicate: bool = false
		for old: Dictionary in field.data.get("npc_spawn",[]):
			var old_position: Array = old.get("position",[])
			if str(old.get("id","")) == id or str(old.get("name","")) == str(npc.name) or str(old.get("source_spawn_key","")) == str(spawn.source_spawn_key): duplicate = true
			if old_position.size() == 2 and Vector2(float(old_position[0]),float(old_position[1])).distance_to(p) < 20.0: duplicate = true
		if duplicate: holds.append({"id":id,"reason":"existing identity/spawn/position overlap"}); continue
		var installed: Dictionary = {"id":id,"source_catalog_id":id,"name":npc.name,"role":npc.role,
			"source_spawn_key":spawn.source_spawn_key,"source_map_id":spawn.source_map_id,
			"source_position":spawn.source_position.duplicate(),"heading_slot":int(spawn.source_heading),
			"position":[p.x,p.y],"foot_pixels":binding.foot_pixels.duplicate(true)}
		field.data.npc_spawn.append(installed)
	return holds
