extends PlayableField
class_name NativePngField
## Pixel coordinates come from the decoded PNG, not an assumed server map ID.
## Hand-traced floors share one navigation/physics mesh. Unreviewed pockets stay solid.
const NATIVE_SPAWNS = preload("res://scripts/monsters/native_png_spawns.gd")
const PNG_SCALE = preload("res://scripts/maps/png_world_scale.gd")
const DOMINATION_GAMEPLAY=preload("res://scripts/maps/domination_png_gameplay.gd")
const PRECISE_ROUTE_GRAPH=preload("res://scripts/maps/native_png_route_graph.gd")
var artwork_scale: float=1.0
var precise_routes: AStar2D
var route_graph_key: String=""
var precise_route_required: bool=false
var cold_route_fallbacks: int=0
const ROUTE_FOOT_RADIUS: float=4.0

func final_route_key() -> String:
	# This fingerprint is made only after alpha solids and reachability have
	# settled. It covers the actual grid, corrected shapes, scale, and the
	# physical foot rules used by both edges and endpoint projection.
	var snapshot: Dictionary=navigation_snapshot()
	var material: String=JSON.stringify([
		PRECISE_ROUTE_GRAPH.GRAPH_VERSION,geometry_signature(),str(data.get("map_id","")),
		int(data.get("layout_revision",0)),str(data.get("collision_scope","")),
		artwork_scale,ROUTE_FOOT_RADIUS,LANDING_BODY_OFFSETS,
		png_manifest.get("sha256","") if png_manifest!=null else "",
		png_manifest.get("source_sha256","") if png_manifest!=null else "",
		png_manifest.get("alpha_guard_cell_size",0) if png_manifest!=null else 0,
		png_manifest.get("alpha_solid_runs",[]) if png_manifest!=null else []
	],"",true,true)
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(material.to_utf8_buffer())
	context.update((snapshot.solid_runs as PackedInt32Array).to_byte_array())
	context.update(reachable)
	return context.finish().hex_encode()

func prepare_precise_routes_step(max_cells: int=256,max_usec: int=2000) -> bool:
	if route_graph_key.is_empty():route_graph_key=final_route_key()
	if precise_routes==null:
		precise_routes=PRECISE_ROUTE_GRAPH.take_idle(route_graph_key,self)
		if precise_routes==null:
			precise_routes=PRECISE_ROUTE_GRAPH.new()
			precise_routes.begin(self,route_graph_key)
	return precise_routes.advance(max_cells,max_usec)

func park_precise_routes() -> void:
	if precise_routes!=null and precise_routes.ready():precise_routes.park_idle()
	precise_routes=null
	precise_route_required=false

func route_graph_stats() -> Dictionary:
	return {"key":route_graph_key,"ready":precise_routes!=null and precise_routes.ready(),
		"points":precise_routes.get_point_count() if precise_routes!=null else 0,
		"build_calls":int(precise_routes.build_calls) if precise_routes!=null else 0,
		"build_usec":int(precise_routes.build_usec) if precise_routes!=null else 0,
		"cold_fallbacks":cold_route_fallbacks}

func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if walkable(from) and walkable(to):
		var start: Vector2i=world_to_cell(from)
		var finish: Vector2i=world_to_cell(to)
		if reachable[start.y*width+start.x]!=0 and reachable[finish.y*width+finish.x]!=0 and line_clear(from,to):
			return PackedVector2Array([to])
	if precise_route_required and precise_routes!=null and precise_routes.ready():return precise_routes.route(from,to)
	var route: PackedVector2Array=super.path(from,to)
	if route.is_empty():return route
	var previous: Vector2=from
	var valid: bool=true
	for point: Vector2 in route:
		if not line_clear(previous,point):valid=false;break
		previous=point
	if valid:return route
	# Cell centers alone cannot prove the intervening segment clears a wall
	# or narrow floor corner. Build exact edge checks only when one is needed.
	precise_route_required=true
	if precise_routes==null:prepare_precise_routes_step(1,1000)
	# Early blocked requests retain the original synchronous correctness path;
	# ordinary map frames have already prepared the same graph in small slices.
	if not precise_routes.ready():
		cold_route_fallbacks+=1
		while not precise_routes.advance(4096,1000000):pass
	return precise_routes.route(from,to)

const FLOOR_BUCKET: int=512
var floor_buckets: Dictionary={}
var floor_polygons_empty: bool=true

func index_walk_polygons(raw: Array) -> void:
	floor_buckets.clear();floor_polygons_empty=raw.is_empty()
	for points: Array in raw:
		var polygon:=PackedVector2Array()
		for point: Array in points: polygon.append(Vector2(point[0],point[1]))
		if polygon.is_empty(): continue
		var box:=Rect2(polygon[0],Vector2.ZERO)
		for point: Vector2 in polygon: box=box.expand(point)
		# Godot polygon edge tests tolerate float rounding near a vertex.
		# Expand only the broad phase; exact membership still uses the source polygon.
		box=box.grow(1)
		var low:=Vector2i((box.position/FLOOR_BUCKET).floor())
		var high:=Vector2i((box.end/FLOOR_BUCKET).floor())
		for y: int in range(low.y,high.y+1):
			for x: int in range(low.x,high.x+1):
				var key:=Vector2i(x,y)
				if not floor_buckets.has(key): floor_buckets[key]=[]
				floor_buckets[key].append(polygon)

func inside_navigable_area(point: Vector2) -> bool:
	if floor_polygons_empty: return true
	# Exact polygon tests remain unchanged. Broad phase avoids scanning all
	# 114 Escaros floor polygons for every grid cell or moving monster.
	for polygon: PackedVector2Array in floor_buckets.get(Vector2i((point/FLOOR_BUCKET).floor()),[]):
		if Geometry2D.is_point_in_polygon(point,polygon): return true
	return false

var png_manifest: Dictionary
var png_root: String
var landing_candidates := PackedVector2Array()
var landing_candidates_ready: bool = false
const LANDING_BODY_OFFSETS := [Vector2(4,0),Vector2(-4,0),Vector2(0,4),Vector2(0,-4),
	Vector2(2.83,2.83),Vector2(-2.83,2.83),Vector2(2.83,-2.83),Vector2(-2.83,-2.83)]

func configure_png(mid: String, plan: Dictionary, manifest: Dictionary, local_root: String) -> void:
	png_manifest = manifest
	png_root = local_root
	landing_candidates.clear()
	landing_candidates_ready = false
	precise_routes=null
	route_graph_key=""
	precise_route_required=false
	cold_route_fallbacks=0
	var spec: Dictionary = plan.maps[mid]
	var faith_map: bool=mid in ["faith_01","faith_02","faith_03","faith_04"]
	artwork_scale=PNG_SCALE.map_scale(mid)
	var spawn: Array = spec.spawn.duplicate(true)
	var portals: Array = [{"id":"aden_return","name":"아덴 귀환","position":[spawn[0]-60,spawn[1]],"target_map":"aden_world","radius":18}]
	if mid.begins_with("albino_"):
		var next: String = "albino_%02d" % (int(mid.right(2))%3+1)
		portals.append({"id":"next","name":"다음 구역","position":[spawn[0]+60,spawn[1]],"target_map":next,"radius":18})
	portals=spec.get("portals",portals).duplicate(true)
	# Keep retired Albino map aliases out of both live portals and generated spawns.
	if mid=="albino_02":
		for portal: Dictionary in portals:
			if str(portal.get("target_map","")) in ["albino_03","albino_04"]:
				portal["target_map"]="faith_01"
				portal["name"]="신념의 탑 입장"
	var monster_spawns: Array=NATIVE_SPAWNS.build(mid,spec,portals)
	var npcs: Array=[]
	if mid=="domination_summit":
		var gameplay: Dictionary=DOMINATION_GAMEPLAY.build(spec)
		monster_spawns=gameplay.get("monster_spawn",[])
		npcs=gameplay.get("npc_spawn",[])
		portals=gameplay.get("portal",[])
	var geometry: Dictionary=PNG_SCALE.geometry(spec,artwork_scale,"",mid)
	spawn=PNG_SCALE.geometry(spawn,artwork_scale,"spawn",mid)
	portals=PNG_SCALE.geometry(portals,artwork_scale,"",mid)
	monster_spawns=PNG_SCALE.geometry(monster_spawns,artwork_scale,"",mid)
	if mid=="aden_world" or faith_map:
		for zone: Dictionary in monster_spawns:
			zone.layout_revision=PNG_SCALE.ADEN_REVISION if mid=="aden_world" else PNG_SCALE.FAITH_REVISION
	for portal: Dictionary in portals:
		if str(portal.get("target_map",""))==mid and portal.has("target_layout_revision"):
			if mid=="aden_world":portal.target_layout_revision=PNG_SCALE.ADEN_REVISION
			elif faith_map:portal.target_layout_revision=PNG_SCALE.FAITH_REVISION
	var value: Dictionary = {
		"map_id":mid,"map_name":spec.name,"short_name":spec.name,
		"layout_revision":PNG_SCALE.ADEN_REVISION if mid=="aden_world" else (PNG_SCALE.FAITH_REVISION if faith_map else int(spec.get("layout_revision",plan.revision))),"bounds":PNG_SCALE.geometry(manifest.bounds,artwork_scale,"bounds"),"native_png":true,
		"navigation":{"cell_size":48 if mid=="aden_world" else 16,"clearance":4,"use_baked_cache":false},
		"streaming":{"chunk_size":1024,"margin":360,"monster_sleep_distance":2100},
		"camera":{"zoom":1.0,"offset":[0,0],"follow_speed":7.0},
		"spawn_position":spawn,"navigable_polygons":geometry.walk_polygons,
		"portal_connected_regions":bool(spec.get("portal_connected_regions",false)),
		"constrain_all_population_patrol":mid in NATIVE_SPAWNS.EXTRA_MAP_IDS or mid=="domination_summit",
		"collision":geometry.get("collision",[]),"monster_spawn":monster_spawns,"npc_spawn":npcs,"portal":portals,"teleport":portals.filter(func(p: Dictionary) -> bool:return str(p.target_map)==mid) if mid=="domination_summit" else [],
		"regions":geometry.get("regions",[]),"surfaces":[],"roads":[],"water":[],"props":[],"bridges":[],
		"safe_zone":spec.get("safe_zone",[]),"combat_zone":spec.get("combat_zone",[]),"boss_zone":spec.get("boss_zone",[]),"route_checks":geometry.route_checks,"blocked_probes":geometry.get("blocked_probes",[]),
		"minimap":{"title":spec.name},"collision_scope":spec.collision_scope,
		"population_status":spec.get("population_status","LOCAL_PNG_PLACEMENT_UNVERIFIED_ORIGINAL_COORDINATES"),
		"spawn_layout_revision":"aden_faith_png_spawns_20261020_v2" if mid in NATIVE_SPAWNS.EXTRA_MAP_IDS else "native_png_spawns_20261019"}
	value["runtime_foreground"]=spec.get("runtime_foreground",[])
	index_walk_polygons(geometry.walk_polygons)
	configure(value)
	# This mask only excludes transparent source pixels. Actual water, walls and
	# obstacles still come from the independent visual trace, never PNG colours.
	var alpha_cell: int=roundi(float(manifest.get("alpha_guard_cell_size",0))*artwork_scale)
	if alpha_cell>=cell_size and alpha_cell%cell_size==0:
		var factor: int=alpha_cell/cell_size
		for run: Array in manifest.get("alpha_solid_runs",[]):
			var box:=Rect2i(int(run[1])*factor,int(run[0])*factor,int(run[2])*factor,factor).intersection(Rect2i(0,0,width,height))
			if box.has_area():astar.fill_solid_region(box)
		_build_reachability()
	# The alpha guard was applied after PlayableField built its candidates.
	# Drop any now-solid/unreachable or poorly cleared samples, rather than
	# materialising actors in invisible pixels, pillars or wall edges.
	for zone: Dictionary in value["monster_spawn"]:
		var zone_id: String=str(zone.id)
		var candidates: Array[Vector2i]=[]
		for cell: Vector2i in spawn_cells.get(zone_id,[]):
			if astar.is_point_solid(cell) or reachable[cell.y*width+cell.x]==0: continue
			if not point_clear(cell_to_world(cell),12.0): continue
			candidates.append(cell)
		spawn_cells[zone_id]=candidates
	route_graph_key=final_route_key()

func _portal_endpoint(raw: Variant) -> Vector2:
	if not raw is Array or raw.size()!=2: return Vector2.INF
	if not (raw[0] is float or raw[0] is int) or not (raw[1] is float or raw[1] is int): return Vector2.INF
	var point := Vector2(float(raw[0]),float(raw[1]))
	if not point.is_finite() or not walkable(point) or not point_clear(point,ROUTE_FOOT_RADIUS): return Vector2.INF
	for offset: Vector2 in LANDING_BODY_OFFSETS:
		if not walkable(point+offset): return Vector2.INF
	return point

func line_clear(from: Vector2,to: Vector2) -> bool:
	# The raster physics occupies entire cells. Center-only shortcut tests can
	# cut a solid cell corner with the real foot, stranding a click path before
	# its next waypoint. Use the same foot for shortcutting and actor motion.
	# Ordinary per-frame movement spans only one or two raster cells. Prove the
	# whole swept foot's bounding box clear once, rather than checking the same
	# cells nine times per two-pixel sample. When that conservative test fails,
	# retain the exact original samples (including narrow/corner paths).
	var raster_clear: bool = _foot_raster_box_clear(from, to)
	var steps: int=maxi(1,ceili(from.distance_to(to)/2.0))
	for i: int in range(steps+1):
		var point: Vector2=from.lerp(to,float(i)/steps)
		if not point_clear(point,ROUTE_FOOT_RADIUS):return false
		if not raster_clear:
			if not walkable(point): return false
			for offset: Vector2 in LANDING_BODY_OFFSETS:
				if not walkable(point+offset):return false
	return true

func _foot_raster_box_clear(from: Vector2, to: Vector2) -> bool:
	var low: Vector2i = world_to_cell(from.min(to) - Vector2.ONE * ROUTE_FOOT_RADIUS)
	var high: Vector2i = world_to_cell(from.max(to) + Vector2.ONE * ROUTE_FOOT_RADIUS)
	var span: Vector2i = high - low + Vector2i.ONE
	if span.x * span.y > 16 or not astar.is_in_boundsv(low) or not astar.is_in_boundsv(high): return false
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			if astar.is_point_solid(Vector2i(x, y)): return false
	return true

func _flood_portal_component(start: Vector2i) -> void:
	if not astar.is_in_boundsv(start) or astar.is_point_solid(start): return
	if reachable[start.y*width+start.x]!=0: return
	var queue: Array[Vector2i] = [start]
	reachable[start.y*width+start.x]=1
	var cursor: int = 0
	while cursor<queue.size():
		var cell: Vector2i = queue[cursor]
		cursor+=1
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+offset
			if not astar.is_in_boundsv(next) or astar.is_point_solid(next): continue
			var key: int = next.y*width+next.x
			if reachable[key]==0:
				reachable[key]=1
				queue.append(next)

func _build_reachability() -> void:
	super._build_reachability()
	landing_candidates.clear()
	landing_candidates_ready=false
	if not bool(data.get("portal_connected_regions",false)): return
	var portals: Array = data.get("portal",[])
	# A reviewed island counts as accessible only through an actual same-map
	# portal whose source is already reachable. Nothing changes the solid grid
	# or invents an AStar path across the unreviewed terrain between islands.
	for _iteration: int in range(portals.size()):
		var changed: bool = false
		for portal: Dictionary in portals:
			if str(portal.get("target_map",""))!=str(data.map_id): continue
			if int(portal.get("target_layout_revision",-1))!=int(data.layout_revision): continue
			var source: Vector2 = _portal_endpoint(portal.get("position",[]))
			var target: Vector2 = _portal_endpoint(portal.get("target_position",[]))
			if not source.is_finite() or not target.is_finite(): continue
			var source_cell: Vector2i = world_to_cell(source)
			var target_cell: Vector2i = world_to_cell(target)
			if reachable[source_cell.y*width+source_cell.x]==0: continue
			if reachable[target_cell.y*width+target_cell.x]!=0: continue
			_flood_portal_component(target_cell)
			changed=true
		if not changed: break

func _build_landing_candidates() -> void:
	if landing_candidates_ready: return
	landing_candidates.clear()
	# Sparse PNG maps have a large transparent canvas. Sample the final actual
	# connected floor, after its alpha guard, rather than retrying canvas pixels.
	for y: int in range(height):
		for x: int in range(width):
			if reachable[y*width+x]==0: continue
			var cell := Vector2i(x,y)
			if astar.is_point_solid(cell): continue
			var point: Vector2 = cell_to_world(cell)
			# Keep the existing consumable clearance contract at explicit obstacles.
			# Also check the real native 4px foot against polygon/alpha grid edges.
			if not point_clear(point): continue
			var allowed: bool = true
			for offset: Vector2 in LANDING_BODY_OFFSETS:
				if not walkable(point+offset):
					allowed=false
					break
			if not allowed: continue
			for portal: Dictionary in data.get("portal",[]):
				var raw: Array = portal.get("position",[])
				if raw.size()!=2: continue
				var radius: float = float(portal.get("radius",18))+4.0
				if point.distance_squared_to(Vector2(raw[0],raw[1]))<=radius*radius:
					allowed=false
					break
			if allowed: landing_candidates.append(point)
	landing_candidates_ready=true

func _landing_matches(point: Vector2, from: Vector2, minimum_squared: float, maximum_squared: float, avoid_safe: bool) -> bool:
	var distance: float = point.distance_squared_to(from)
	return distance>=minimum_squared and distance<=maximum_squared and (not avoid_safe or not is_safe(point))

func random_landing(random: RandomNumberGenerator, from: Vector2, min_distance: float = 160.0, max_distance: float = INF, avoid_safe: bool = false) -> Vector2:
	if not from.is_finite() or min_distance<0.0 or max_distance<min_distance: return Vector2.INF
	_build_landing_candidates()
	if landing_candidates.is_empty(): return Vector2.INF
	var minimum_squared: float = min_distance*min_distance
	var maximum_squared: float = max_distance*max_distance
	# Ordinary broad requests return quickly. A rare distance window still gets
	# an exhaustive fallback, so valid landings cannot fail due to bad luck.
	for attempt: int in range(mini(64,landing_candidates.size())):
		var candidate: Vector2 = landing_candidates[random.randi_range(0,landing_candidates.size()-1)]
		if _landing_matches(candidate,from,minimum_squared,maximum_squared,avoid_safe): return candidate
	var start: int = random.randi_range(0,landing_candidates.size()-1)
	for offset: int in range(landing_candidates.size()):
		var candidate: Vector2 = landing_candidates[(start+offset)%landing_candidates.size()]
		if _landing_matches(candidate,from,minimum_squared,maximum_squared,avoid_safe): return candidate
	return Vector2.INF

func solid_rectangles() -> Array[Rect2i]:
	# Merge equal runs vertically. No cell changes its solid/walking ownership.
	var result: Array[Rect2i]=[]
	var active: Dictionary={}
	for y: int in range(height):
		var seen: Dictionary={}
		var start: int = -1
		for x: int in range(width+1):
			var solid: bool = x<width and astar.is_point_solid(Vector2i(x,y))
			if solid and start<0: start=x
			if not solid and start>=0:
				var key:=Vector2i(start,x-start)
				if active.has(key):
					var box: Rect2i=active[key];box.size.y+=1;active[key]=box
				else: active[key]=Rect2i(start,y,x-start,1)
				seen[key]=true
				start=-1
		for key: Vector2i in active.keys():
			if not seen.has(key): result.append(active[key]);active.erase(key)
	for box: Rect2i in active.values(): result.append(box)
	return result

func build_physics(parent: Node2D) -> StaticBody2D:
	# Raster cells alone leave sub-cell slivers at angled polygon feet. Keep
	# the exact reviewed walls/trunks as physical shapes as well as the grid.
	var body: StaticBody2D=super.build_physics(parent)
	body.name="NativePngCollision"
	for box: Rect2i in solid_rectangles():
		var node:=CollisionShape2D.new()
		var shape:=RectangleShape2D.new()
		shape.size=Vector2(box.size*cell_size);node.shape=shape
		node.position=bounds.position+Vector2(box.position*cell_size)+shape.size*.5
		body.add_child(node)
	# Explicit external walls cover the finite canvas as well.
	for box: Rect2 in [Rect2(bounds.position-Vector2(32,32),Vector2(bounds.size.x+64,32)),Rect2(Vector2(bounds.position.x-32,bounds.end.y),Vector2(bounds.size.x+64,32)),Rect2(bounds.position-Vector2(32,0),Vector2(32,bounds.size.y)),Rect2(Vector2(bounds.end.x,bounds.position.y),Vector2(32,bounds.size.y))]:
		var node := CollisionShape2D.new()
		node.set_meta("external_canvas_wall",true)
		var shape := RectangleShape2D.new()
		shape.size=box.size;node.shape=shape;node.position=box.get_center();body.add_child(node)
	return body

func overview_texture() -> Texture2D:
	var image := Image.new()
	if image.load(png_root+"/overview.png") != OK: return null
	return ImageTexture.create_from_image(image)
