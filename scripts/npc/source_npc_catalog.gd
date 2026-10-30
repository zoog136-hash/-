extends RefCounted
## Six approved identities. Original map labels are provenance, never runtime aliases.
const PATH = "res://data/npc/source_six.json"
const BINDINGS = "res://data/npc/source_six_bindings.json"
const PROTECTED = ["albino_01","albino_02","escaros_01","escaros_02","escaros_03","escaros_04","escaros_05","faith_01","faith_02","faith_03","faith_04"]
static var _records: Dictionary = {}
static var placements: Dictionary = {}

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
		elif str(spawn.get("source_position_mode","")) != "fixed_point" and str(binding.get("random_policy","")) != "reviewed_source_offsets_v1":
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
		var present:bool=false
		for old:Dictionary in field.data.get("npc_spawn",[]):
			if str(old.get("id",""))==id and str(old.get("source_catalog_id",""))==id:present=true
		if present:continue
		var selected:Array=spawn.source_position.duplicate()
		if str(spawn.get("source_position_mode",""))=="random_offsets":
			if placements.has(id):selected=placements[id].source_position.duplicate()
			else:
				var candidates:Array=[]
				for candidate:Array in binding.get("valid_source_positions",[]):
					if not _within_source_offsets(candidate,spawn):continue
					var q:Vector2=coordinates.to_world(Vector2(candidate[0],candidate[1]))
					if _floor_clear(field,q):candidates.append(candidate)
				if candidates.is_empty():holds.append({"id":id,"reason":"no reviewed random floor"});continue
				var rng:=RandomNumberGenerator.new();rng.randomize()
				selected=candidates[rng.randi_range(0,candidates.size()-1)].duplicate()
				placements[id]={"source_position":selected.duplicate(),"source_grid_sha256":binding.source_grid_sha256}
			if not _within_source_offsets(selected,spawn) or not binding.get("valid_source_positions",[]).has(selected):holds.append({"id":id,"reason":"saved random position is not reviewed"});continue
		var p: Vector2 = coordinates.to_world(Vector2(float(selected[0]),float(selected[1])))
		if not p.is_finite() or not _floor_clear(field,p): holds.append({"id":id,"reason":"source cell is not walkable"}); continue
		var duplicate: bool = false
		for old: Dictionary in field.data.get("npc_spawn",[]):
			var old_position: Array = old.get("position",[])
			if str(old.get("id","")) == id or str(old.get("name","")) == str(npc.name) or str(old.get("source_spawn_key","")) == str(spawn.source_spawn_key): duplicate = true
			if old_position.size() == 2 and Vector2(float(old_position[0]),float(old_position[1])).distance_to(p) < 20.0: duplicate = true
		if duplicate: holds.append({"id":id,"reason":"existing identity/spawn/position overlap"}); continue
		var installed: Dictionary = {"id":id,"source_catalog_id":id,"name":npc.name,"role":npc.role,
			"source_spawn_key":spawn.source_spawn_key,"source_map_id":spawn.source_map_id,
			"source_position":spawn.source_position.duplicate(),"runtime_source_position":selected.duplicate(),"source_position_mode":spawn.source_position_mode,"heading_slot":int(spawn.source_heading),
			"position":[p.x,p.y],"foot_pixels":binding.foot_pixels.duplicate(true)}
		field.data.npc_spawn.append(installed)
	return holds

static func _floor_clear(field:Object,p:Vector2) -> bool:
	return field.point_clear(p,6.0) if field.has_method("point_clear") else field.walkable(p)

static func _within_source_offsets(value:Variant,spawn:Dictionary) -> bool:
	if not value is Array or value.size()!=2:return false
	for axis:int in range(2):
		if not (value[axis] is int or value[axis] is float) or not is_finite(float(value[axis])) or float(value[axis])!=floorf(float(value[axis])):return false
		if absf(float(value[axis])-float(spawn.source_position[axis]))>float(spawn.source_random_offsets[axis]):return false
	return true

static func export_state() -> Dictionary:
	return {"schema":1,"placements":placements.duplicate(true)}

static func validate_state(value:Variant) -> String:
	if not value is Dictionary:return "NPC placement state is malformed"
	if value.is_empty():return ""
	if value.get("schema")!=1 or not value.get("placements") is Dictionary:return "NPC placement schema is unknown"
	var bindings:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BINDINGS))
	for id:String in value.placements:
		var saved:Variant=value.placements[id]
		var found:bool=false
		for b:Dictionary in bindings.bindings:
			if b.npc_id!=id or b.get("random_policy")!="reviewed_source_offsets_v1":continue
			if not saved is Dictionary or saved.get("source_grid_sha256")!=b.source_grid_sha256:return "NPC placement grid identity changed"
			if not _within_source_offsets(saved.get("source_position"),record(id).spawns[0]) or not b.valid_source_positions.has(saved.source_position):return "NPC saved position is outside reviewed offsets"
			found=true
		if not found:return "NPC saved identity has no reviewed random policy"
	return ""

static func import_state(value:Dictionary) -> void:
	placements=value.get("placements",{}).duplicate(true)

static func nearest_click_record(world:Node,target:Vector2) -> Dictionary:
	if world.field_map==null:return {}
	var closest:Dictionary={};var distance:float=55.0
	for row:Dictionary in world.field_map.data.get("npc_spawn",[]):
		var point:Vector2=Vector2(row.position[0],row.position[1]);var d:float=target.distance_to(point)
		if d<distance:closest=row;distance=d
	if not records().has(str(closest.get("source_catalog_id",""))):return {}
	return closest if nearby(world,str(closest.source_catalog_id)) else {}
