extends "res://scripts/maps/source_field.gd"
class_name Current523AdenSourceField
## Original M S32 bytes supply the cells; this is an OWN movement interpretation.
## Filename placement, projection and the allowlist are unverified for native M.
## Inherited DDA/A* algorithms call this field's rules, never A3 attribute rules.
const RAW = preload("res://scripts/maps/current523_aden_pack.gd")
const REVIEW = preload("res://scripts/maps/current523_aden_review.gd")
const INFERRED = preload("res://scripts/maps/current523_aden_inferred_placement.gd")
const RAW_CACHE_LIMIT: int = 48
const OWN_PROFILE: String = "CURRENT523_S32_OWN_ALLOWLIST_V1"
## Client rule (LineageM 1.10.22.0 static analysis, movement edge test RVA
## 0x01CC95C0): an S32 attribute word rejects movement when bit0 is set; a
## diagonal step is rejected only when both orthogonal sides reject
## ((r0||r1)&&(r2||r3)). Applied per TWILIGHT cell (one S32 word pair).
const CLIENT_PROFILE: String = "CURRENT523_S32_CLIENT_ATTR_BIT0_V1"
const CLIENT_RULE: String = "client523_attr_bit0"
const OWN_RULE: String = "own_allowlist"
const OWN_LAYOUT_REVISION: int = 5230001
const DEFAULT_ALLOWED_RAW_WORDS: Array[int] = [0, 4, 8, 12, 32]
var loaded: bool = false
var problem: String = ""
var source_bounds := Rect2i()
var source_origins: Dictionary = {}
var unplaced_members: Array[String] = []
var inferred_placements: Dictionary = {}
var policy: Dictionary = {}
var _raw = RAW.new()
var _source_chunks: Dictionary = {}
var _raw_cache: Dictionary = {}
var _raw_recent: Array[String] = []
var _raw_failures: Dictionary = {}
var _last_raw_origin: Vector2i
var _last_raw_chunk: Dictionary = {}
var _route_verdict_chunks: Dictionary[String, RouteVerdictChunk] = {}
var _allowed_words: Dictionary = {}
var _use_allowlist: bool = true
var _raw_reads: int = 0

func uses_original_gameplay_rules() -> bool: return false

func configure_current523(raw_root: String, interpretation: Dictionary = {}) -> bool:
	close()
	problem = ""
	if not _configure_policy(interpretation): return false
	if not _raw.load_pack(raw_root): return _fail(_raw.problem)
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483647, -2147483647)
	for member: String in _raw.source_members():
		var candidate: Variant = REVIEW.candidate_origin(member)
		if candidate==null: candidate=_inferred_origin(member,_raw.source_metadata(member))
		if candidate == null:
			unplaced_members.append(member)
			continue
		var origin: Vector2i = candidate
		if _source_chunks.has(origin): return _fail("Duplicate candidate source origin")
		source_origins[member] = origin
		_source_chunks[origin] = member
		minimum = minimum.min(origin)
		maximum = maximum.max(origin + Vector2i(64, 64))
	if source_origins.size() != 676+inferred_placements.size() or unplaced_members.size() != 1-inferred_placements.size():
		return _fail("Expected unchanged Aden chunks and explicit optional inferred member")
	source_bounds = Rect2i(minimum, maximum - minimum)
	if not coordinates.configure([minimum.x, minimum.y], [source_bounds.size.x, source_bounds.size.y], policy.coordinate_mapping):
		return _fail("Invalid own source coordinate mapping")
	width = source_bounds.size.x
	height = source_bounds.size.y
	bounds = coordinates.canvas_bounds()
	# Compatibility state only; no legacy grids, doors, actors or geography load.
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, 1, 1)
	astar.update()
	definition = {"map_id":str(policy.get("map_id", "current523_aden")), "source_map_id":4, "source_land_id":4, "source_sha256":RAW.INVENTORY_SHA256, "origin":[minimum.x,minimum.y], "dimensions":[width,height], "layout_revision":OWN_LAYOUT_REVISION, "navigation":{"profile":str(policy.get("profile",OWN_PROFILE))}, "native_m_rules_verified":false}
	data = {"map_id":str(policy.get("map_id", "current523_aden")), "source_land_id":4, "map_name":"아덴 523 · 원본 S32 / 자체 통행", "short_name":"M 원본 · 자체 통행 해석",
		"layout_revision":OWN_LAYOUT_REVISION, "navigation_profile":str(policy.get("profile",OWN_PROFILE)), "spawn_position":[], "bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],
		"collision":[], "regions":[], "water":[], "roads":[], "surfaces":[], "npc_spawn":[], "monster_spawn":[], "portal":[],
		"navigation":{"profile":str(policy.get("profile",OWN_PROFILE))}, "camera":{"zoom":1.0,"offset":[0,-32],"follow_speed":8.0},
		"streaming":{"monster_sleep_distance":1600}, "native_m_rules_verified":false}
	loaded = true
	if interpretation.has("spawn_source"):
		var spawn: Variant = interpretation.spawn_source
		if not _integer_pair(spawn): return _fail("Invalid own source spawn")
		var point: Vector2 = coordinates.to_world(Vector2(float(spawn[0]),float(spawn[1])))
		if not walkable(point): return _fail("Requested source spawn is denied by own S32 policy")
		data.spawn_position = [point.x,point.y]
	set_meta("current523_source_field",true)
	return true

func _configure_policy(value: Dictionary) -> bool:
	_allowed_words.clear()
	policy = value.duplicate(true)
	# Resource first: without an explicit own allowlist or mask the client rule applies.
	var explicit_own: bool = value.has("allowed_raw_words") or value.has("allowed_mask") or value.has("must_mask") or value.has("forbidden_mask")
	var rule: Variant = value.get("attribute_rule", OWN_RULE if explicit_own else CLIENT_RULE)
	if not rule in [CLIENT_RULE, OWN_RULE]: return _fail("Unknown S32 attribute rule")
	policy["attribute_rule"] = rule
	policy["profile"] = CLIENT_PROFILE if rule == CLIENT_RULE else OWN_PROFILE
	policy["native_m_rules_verified"] = false
	var inference: Variant=value.get(INFERRED.OPTION,true)
	if not inference is bool: return _fail("Invalid inferred Aden placement choice")
	policy[INFERRED.OPTION]=inference
	# Exact zero is explicitly mapped here; absent/corrupt cells never reach it.
	# These are local choices, not a claim that PC viewer flags are M rules.
	var words: Variant = value.get("allowed_raw_words", DEFAULT_ALLOWED_RAW_WORDS.duplicate())
	_use_allowlist = words != null
	if _use_allowlist:
		if not words is Array: return _fail("allowed_raw_words must be an array or null for mask-only policy")
		for word: Variant in words:
			if not RAW._uint(word,65534): return _fail("Invalid allowed raw u16 word")
			_allowed_words[int(word)] = true
	policy["allowed_raw_words"] = words
	for key: String in ["allowed_mask", "must_mask", "forbidden_mask"]:
		var mask: Variant = value.get(key, 65535 if key == "allowed_mask" else 0)
		if not RAW._uint(mask,65535): return _fail("Invalid own u16 mask: " + key)
		policy[key] = int(mask)
	if (int(policy.must_mask) & int(policy.forbidden_mask)) != 0 or (int(policy.must_mask) & ~int(policy.allowed_mask)) != 0:
		return _fail("Contradictory own attribute masks")
	var mapping: Variant = value.get("coordinate_mapping", {})
	if not mapping is Dictionary: return _fail("Invalid own coordinate mapping")
	policy["coordinate_mapping"] = mapping.duplicate(true)
	policy.coordinate_mapping["basis_x"] = mapping.get("basis_x", [24,-12])
	policy.coordinate_mapping["basis_y"] = mapping.get("basis_y", [24,12])
	policy.coordinate_mapping["translation"] = mapping.get("translation", [0,768])
	var limit: Variant = value.get("path_search_limit",8192)
	if not RAW._uint(limit,65536) or int(limit)<1: return _fail("Invalid own path search limit")
	policy["path_search_limit"] = int(limit)
	return true

func _inferred_origin(member: String, metadata: Dictionary) -> Variant:
	var origin: Variant=INFERRED.candidate(member,metadata,bool(policy.get(INFERRED.OPTION,true)))
	if origin!=null: inferred_placements[member]=INFERRED.record()
	return origin

func _integer_pair(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)) or floorf(float(component)) != float(component) or absf(float(component))>2147480000: return false
	return true

func _fail(message: String) -> bool:
	problem = message
	loaded = false
	return false

func registered_source_members() -> Array: return _raw.source_members() if loaded else []
func unplaced_source_members() -> Array[String]: return unplaced_members.duplicate() if loaded else []
func source_chunk_origins() -> Dictionary: return source_origins.duplicate() if loaded else {}
func source_metadata(member: String) -> Dictionary: return _raw.source_metadata(member) if loaded else {}

func _source_origin(source: Vector2i) -> Vector2i:
	return Vector2i(floori(float(source.x)/64.0)*64,floori(float(source.y)/64.0)*64)

func _source_chunk(origin: Vector2i) -> Dictionary:
	if not loaded: return {}
	# Collision and A* often consult many cells in a single chunk. The last
	# successful read is already newest in the LRU, so leave the queue alone.
	if origin == _last_raw_origin and not _last_raw_chunk.is_empty(): return _last_raw_chunk
	var member: String = _source_chunks.get(origin, "")
	if member.is_empty(): return {}
	if _raw_cache.has(member):
		_raw_recent.erase(member)
		_raw_recent.append(member)
		_last_raw_origin = origin
		_last_raw_chunk = _raw_cache[member]
		return _last_raw_chunk
	if _raw_failures.has(member): return {}
	var row: Dictionary = _take_renderer_collision(member)
	if row.is_empty():
		row = _raw.read_member(member)
		_raw_reads += 1
	if row.is_empty():
		_raw_failures[member] = _raw.problem
		problem = _raw.problem
		return {}
	if _raw_recent.size() >= RAW_CACHE_LIMIT:
		var retired: String = _raw_recent.pop_front()
		_raw_cache.erase(retired)
		_route_verdict_chunks.erase(retired)
	_raw_cache[member] = row
	_raw_recent.append(member)
	_last_raw_origin = origin
	_last_raw_chunk = row
	return row

## Generic 523 may take fully verified floor/attribute bytes from a completed
## renderer job. Review/Aden and other sources keep their original read path.
func _take_renderer_collision(_member: String) -> Dictionary: return {}

func _allows_word(word: int) -> bool:
	if policy.get("attribute_rule") == CLIENT_RULE: return (word & 1) == 0
	if word == 65535 or (_use_allowlist and not _allowed_words.has(word)): return false
	return (word & ~int(policy.allowed_mask)) == 0 and (word & int(policy.must_mask)) == int(policy.must_mask) and (word & int(policy.forbidden_mask)) == 0

func _pair_status(attributes: PackedByteArray, floor_refs: PackedByteArray, index: int) -> String:
	if floor_refs.decode_u32(index*4) == 4294967295 or floor_refs.decode_u32((index+1)*4) == 4294967295: return "floor_sentinel"
	var first: int = attributes.decode_u16(index*2)
	var second: int = attributes.decode_u16((index+1)*2)
	if first == 65535 or second == 65535: return "unknown_attribute"
	return "allowed" if _allows_word(first) and _allows_word(second) else "policy_blocked"

func source_cell_info(source: Vector2i) -> Dictionary:
	var result: Dictionary = {"source_cell":source, "member":"", "source_sha256":"", "local_cell":Vector2i(-1,-1), "raw_pair":[], "floor_pair":[], "status":"not_configured", "walkable":false, "own_profile":str(policy.get("profile",OWN_PROFILE)), "native_m_rules_verified":false}
	if not loaded: return result
	if not source_bounds.has_point(source): result.status = "outside_source_bounds"; return result
	var origin: Vector2i = _source_origin(source)
	if not _source_chunks.has(origin): result.status = "unregistered_chunk"; return result
	result.member = _source_chunks[origin]
	if inferred_placements.has(result.member): result["inferred_placement"]=inferred_placements[result.member].duplicate(true)
	result.local_cell = source-origin
	var row: Dictionary = _source_chunk(origin)
	if row.is_empty(): result.status = "source_integrity_failure"; return result
	var index: int = (source.y-origin.y)*128+(source.x-origin.x)*2
	var attributes: PackedByteArray = row.sections.attributes
	var floor_refs: PackedByteArray = row.sections.floor
	result.source_sha256 = row.get("source_sha256", "")
	result.raw_pair = [attributes.decode_u16(index*2),attributes.decode_u16((index+1)*2)]
	result.floor_pair = [floor_refs.decode_u32(index*4),floor_refs.decode_u32((index+1)*4)]
	result.status = _pair_status(attributes,floor_refs,index)
	result.walkable = result.status == "allowed"
	return result

func _cell_allowed(cell: Vector2i) -> bool:
	if not loaded or not in_bounds(cell): return false
	var source: Vector2i = coordinates.origin+cell
	var origin: Vector2i = _source_origin(source)
	var row: Dictionary = _source_chunk(origin)
	if row.is_empty(): return false
	var index: int = (source.y-origin.y)*128+(source.x-origin.x)*2
	var attrs: PackedByteArray = row.sections.attributes
	var floor_refs: PackedByteArray = row.sections.floor
	if policy.get("attribute_rule") != CLIENT_RULE:
		return _pair_status(attrs,floor_refs,index) == "allowed"
	# Same guards as the diagnostic path. Both attribute words must have
	# bit 0 clear; 0xffff already fails that test.
	if (attrs.decode_u16(index*2) | attrs.decode_u16(index*2+2)) & 1: return false
	return floor_refs.decode_u32(index*4) != 4294967295 and floor_refs.decode_u32(index*4+4) != 4294967295

func value_at(cell: Vector2i, mask: bool = false) -> int:
	if mask: return 1 if _cell_allowed(cell) else 0
	if not loaded or not in_bounds(cell): return 0
	var source: Vector2i = coordinates.origin+cell
	var origin: Vector2i = _source_origin(source)
	var row: Dictionary = _source_chunk(origin)
	if row.is_empty(): return 0
	return row.sections.attributes.decode_u16(((source.y-origin.y)*128+(source.x-origin.x)*2)*2)

func walkable(point: Vector2) -> bool:
	return loaded and point.is_finite() and _cell_allowed(world_to_cell(point))

## Nearest own-clear source cell centre around `point`, searched ring by ring
## (Chebyshev radius in source cells). Used to put an actor that ended on a
## blocked or unsupported cell (old save, knockback, landing error) back on
## the map instead of closing the 523 session. `accept` may veto a candidate
## (the renderer's painted-coverage check).
func nearest_clear_point(point: Vector2, radius_cells: int = 24, accept: Callable = Callable()) -> Dictionary:
	if not loaded or not point.is_finite(): return {"ok":false,"reason":"source_field_unavailable"}
	var center: Vector2i = world_to_cell(point)+coordinates.origin
	for ring: int in range(maxi(0,radius_cells)+1):
		for y: int in range(center.y-ring,center.y+ring+1):
			for x: int in range(center.x-ring,center.x+ring+1):
				if maxi(absi(x-center.x),absi(y-center.y))!=ring: continue
				var position: Vector2 = coordinates.to_world(Vector2(x,y))
				if not point_clear(position,4.0): continue
				if accept.is_valid() and not bool(accept.call(position)): continue
				return {"ok":true,"position":position,"source_cell":Vector2i(x,y),"ring":ring}
	return {"ok":false,"reason":"no_clear_cell_within_%d" % radius_cells}

func can_step(cell: Vector2i, heading: int) -> bool:
	if heading<0 or heading>=8 or not _cell_allowed(cell): return false
	var offset: Vector2i = DIRECTIONS[heading]
	if not _cell_allowed(cell+offset): return false
	if offset.x != 0 and offset.y != 0:
		if policy.get("attribute_rule") == CLIENT_RULE:
			return _cell_allowed(cell+Vector2i(offset.x,0)) or _cell_allowed(cell+Vector2i(0,offset.y))
		return _cell_allowed(cell+Vector2i(offset.x,0)) and _cell_allowed(cell+Vector2i(0,offset.y))
	return true

## Only the immutable 523 terrain query opts in. Keep one verdict per visited
## cell for this A* call, not a reusable path or a cross-frame collision cache.
## Manual DDA, live collisions, endpoint checks and non-523 fields are unchanged.
func _new_path_navigator() -> TwilightL1JSourceNavigation:
	var navigator := Source523Search.new()
	navigator.source = self
	navigator.diagonal_any = policy.get("attribute_rule") == CLIENT_RULE
	return navigator

func _route_verdict_chunk(origin: Vector2i) -> RouteVerdictChunk:
	var row: Dictionary = _source_chunk(origin)
	if row.is_empty(): return null
	var member: String = _source_chunks[origin]
	var existing: RouteVerdictChunk = _route_verdict_chunks.get(member)
	if existing != null: return existing
	var chunk := RouteVerdictChunk.new()
	chunk.attributes = row.sections.attributes
	chunk.floor_refs = row.sections.floor
	chunk.verdicts.resize(4096)
	_route_verdict_chunks[member] = chunk
	return chunk

# Lazy, byte-sized tri-state: unknown, blocked, open. No eager tile scan,
# unpacking or new I/O. Projection belongs to the caller, not cached bytes.
class RouteVerdictChunk extends RefCounted:
	var attributes: PackedByteArray
	var floor_refs: PackedByteArray
	var verdicts := PackedByteArray()
	var decoded: int = 0

	func decode(index: int) -> bool:
		var open: bool = ((attributes.decode_u16(index*4) | attributes.decode_u16(index*4+2)) & 1) == 0 \
			and floor_refs.decode_u32(index*8) != 4294967295 and floor_refs.decode_u32(index*8+4) != 4294967295
		verdicts[index] = 2 if open else 1
		decoded += 1
		return open

class Source523Search extends TwilightL1JSourceNavigation:
	const MAX_VERDICTS: int = 32768
	var source: RefCounted
	var diagonal_any: bool = false
	var verdicts: Dictionary = {}

	func _allowed(cell: Vector2i) -> bool:
		var cached: int = int(verdicts.get(cell, -1))
		if cached >= 0: return cached != 0
		var allowed: bool = source._cell_allowed(cell)
		if verdicts.size() < MAX_VERDICTS: verdicts[cell] = int(allowed)
		return allowed

	func can_step(cell: Vector2i, heading: int) -> bool:
		# Same endpoint and diagonal rules as Current523AdenSourceField.can_step.
		if heading < 0 or heading >= 8 or not _allowed(cell): return false
		var offset: Vector2i = DIRECTIONS[heading]
		if not _allowed(cell + offset): return false
		if offset.x == 0 or offset.y == 0: return true
		var sideways: bool = _allowed(cell + Vector2i(offset.x, 0))
		if diagonal_any:
			return sideways or _allowed(cell + Vector2i(0, offset.y))
		return sideways and _allowed(cell + Vector2i(0, offset.y))

# Used only by the verified generic field with the native attribute rule.
# Keep A* heap/ties, endpoints and the same at-least-one diagonal side.
class Verified523Search extends TwilightL1JSourceNavigation:
	var source: RefCounted
	var grid_size := Vector2i.ZERO
	var origin_offset := Vector2i.ZERO
	var last_cell_origin := Vector2i.ZERO
	var last_chunk: RouteVerdictChunk
	var last_from := Vector2i(-1,-1)
	var last_from_open: bool = false

	func can_step(cell: Vector2i, heading: int) -> bool:
		if heading < 0 or heading >= 8: return false
		if cell != last_from:
			last_from = cell
			last_from_open = _allowed(cell)
		if not last_from_open: return false
		var offset: Vector2i = DIRECTIONS[heading]
		if not _allowed(cell + offset): return false
		return offset.x == 0 or offset.y == 0 \
			or _allowed(cell + Vector2i(offset.x, 0)) or _allowed(cell + Vector2i(0, offset.y))

	func _allowed(cell: Vector2i) -> bool:
		if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y: return false
		var local: Vector2i = cell - last_cell_origin
		if last_chunk == null or local.x < 0 or local.x >= 64 or local.y < 0 or local.y >= 64:
			var point: Vector2i = cell + origin_offset
			var origin := Vector2i(point.x & -64, point.y & -64)
			var chunk: RouteVerdictChunk = source._route_verdict_chunk(origin)
			if chunk == null: return false
			last_chunk = chunk
			last_cell_origin = origin - origin_offset
			local = point - origin
		var index: int = local.y*64 + local.x
		var stored: int = last_chunk.verdicts[index]
		return stored == 2 if stored != 0 else last_chunk.decode(index)

func line_clear(from: Vector2, to: Vector2) -> bool:
	return loaded and super.line_clear(from,to)

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	# Validate exact endpoints only once. Unlike generic source fields, 523
	# never snaps a blocked click or start to some other nearest cell.
	if not loaded or not from.is_finite() or not to.is_finite(): return PackedVector2Array()
	var from_grid: Array = coordinates.grid_components(from)
	var to_grid: Array = coordinates.grid_components(to)
	var start: Vector2i = coordinates.world_to_cell(from,from_grid)
	var goal: Vector2i = coordinates.world_to_cell(to,to_grid)
	if not _cell_allowed(start) or (goal != start and not _cell_allowed(goal)): return PackedVector2Array()
	# The 523 line_clear wrapper only added the endpoint checks already done.
	# DDA and its edge rules are unchanged, including fractional coordinates.
	if _line_between_validated_cells(from_grid,to_grid,start,goal): return PackedVector2Array([to])
	return _route_between_validated_cells(from,to,start,goal)

const HUNT_SEARCH_BUDGET_USEC: int = 4000
const HUNT_SEARCH_MAX_POPS: int = 512
const HUNT_COMPONENT_MAX_CELLS: int = 4096
var _hunt_field_epoch: int = 0
var _hunt_complete_component: Dictionary[Vector2i, Vector3i] = {}

func static_pursuit_epoch() -> int: return 0

## Automatic target acquisition only. A pending slice is not a failed path.
## Exact endpoints, direct DDA, cap and waypoints match the synchronous path.
func hunt_path_step(from: Vector2,to: Vector2,work: Dictionary = {}) -> Dictionary:
	var deadline: int = Time.get_ticks_usec() + HUNT_SEARCH_BUDGET_USEC
	if not loaded or not from.is_finite() or not to.is_finite(): return {"pending":false,"path":PackedVector2Array()}
	var from_grid: Array = coordinates.grid_components(from)
	var to_grid: Array = coordinates.grid_components(to)
	var start: Vector2i = coordinates.world_to_cell(from,from_grid)
	var goal: Vector2i = coordinates.world_to_cell(to,to_grid)
	if _hunt_complete_component.has(start) and not _hunt_complete_component.has(goal) \
		and static_pursuit_epoch() != 0 and policy.get("attribute_rule") == CLIENT_RULE:
		return {"pending":false,"path":PackedVector2Array(),"known_disconnected":true}
	if not _cell_allowed(start) or (goal != start and not _cell_allowed(goal)): return {"pending":false,"path":PackedVector2Array()}
	var limit: int = _path_node_limit()
	var nav: TwilightL1JSourceNavigation
	var search: TwilightL1JSourceNavigation.PathSearch
	if not work.is_empty() and work.field_id == get_instance_id() and work.epoch == _hunt_field_epoch and work.limit == limit and work.search.start == start and work.search.goal == goal:
		nav = work.nav
		search = work.search
	else:
		if _line_between_validated_cells(from_grid,to_grid,start,goal): return {"pending":false,"path":PackedVector2Array([to])}
		nav = _new_path_navigator()
		nav.loaded = true
		nav.coordinates.configure(Vector2i(width,height),Vector2i.ZERO,Transform2D.IDENTITY)
		search = nav.begin_search(start,goal,limit)
		work = {"nav":nav,"search":search,"field_id":get_instance_id(),"epoch":_hunt_field_epoch,"limit":limit}
	if not nav.advance_search(search,deadline,HUNT_SEARCH_MAX_POPS):
		return {"pending":true,"work":work}
	# On verified 523 terrain the DDA and A* share the same bidirectional
	# edges. An empty result with an exhausted frontier below the node cap
	# proves that the visited cells form a complete component. Keep only
	# one small component; reaching the cap gives no such proof.
	if nav is Verified523Search and search.result.is_empty() and not search.visited.is_empty() \
		and search.visited.size() < search.max_nodes and search.visited.size() <= HUNT_COMPONENT_MAX_CELLS:
		_hunt_complete_component = search.visited
	return {"pending":false,"path":_finish_cell_path(from,to,search.result)}

func navigation_search_limit() -> int: return int(policy.get("path_search_limit",8192))

func region_at(_point: Vector2) -> Dictionary:
	return {"id":"current523_own_neutral", "name":"아덴 523 · 지역 의미 미확정", "type":"neutral", "color":"738e81", "native_m_rules_verified":false}

func is_safe(_point: Vector2) -> bool: return false

func build_physics(parent: Node2D) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Current523SourceMotionGuard"
	body.collision_layer = 4
	body.collision_mask = 0
	parent.add_child(body)
	return body

func random_landing(random: RandomNumberGenerator, near: Vector2, min_distance: float = 160.0, max_distance: float = INF) -> Vector2:
	if not loaded: return Vector2.INF
	var origins: Array = _source_chunks.keys()
	for attempt: int in range(1500):
		var origin: Vector2i = origins[random.randi_range(0,origins.size()-1)]
		var cell: Vector2i = origin-coordinates.origin+Vector2i(random.randi_range(0,63),random.randi_range(0,63))
		var point: Vector2 = cell_to_world(cell)
		if _cell_allowed(cell) and point.distance_to(near)>=min_distance and point.distance_to(near)<=max_distance: return point
	return Vector2.INF

func overview_texture() -> ImageTexture:
	if overview != null: return overview
	var image := Image.create(128,64,false,Image.FORMAT_RGBA8)
	if loaded:
		for y: int in range(64):
			for x: int in range(128):
				var cell := Vector2i(int((x+0.5)*width/128.0),int((y+0.5)*height/64.0))
				if _cell_allowed(cell): image.set_pixel(x,y,Color("576e5b"))
	overview = ImageTexture.create_from_image(image)
	return overview

func cache_metrics() -> Dictionary:
	return {"raw_reads":_raw_reads, "cached_chunks":_raw_cache.size(), "cache_limit":RAW_CACHE_LIMIT, "failed_chunks":_raw_failures.size(), "placed_chunks":source_origins.size(), "unplaced_members":unplaced_members.size(), "native_m_rules_verified":false}

func close() -> void:
	_hunt_field_epoch += 1
	_hunt_complete_component = {}
	loaded = false
	if has_meta("current523_source_field"): remove_meta("current523_source_field")
	_raw = RAW.new()
	_raw_cache.clear()
	_route_verdict_chunks.clear()
	_raw_recent.clear()
	_raw_failures.clear()
	_last_raw_chunk = {}
	_source_chunks.clear()
	source_origins.clear()
	unplaced_members.clear()
	inferred_placements.clear()
	_allowed_words.clear()
	_raw_reads = 0
	source_bounds = Rect2i()
	width = 0
	height = 0
	bounds = Rect2()
	coordinates.valid = false
	policy.clear()
	data = {}
	definition.clear()
	overview = null
	# These inherited stores are never populated by the current523 field.
	packs.clear()
	nav_cache.clear()
	nav_used.clear()
	chunk_table.clear()
