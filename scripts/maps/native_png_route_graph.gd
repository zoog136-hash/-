extends AStar2D
## On-demand route repair over the unchanged PNG collision grid.
## Reject individual physical edges instead of deleting whole walking cells.
var field_ref: WeakRef
var grid_point_limit: int
var edge_checks: Dictionary = {}
const ROUTE_CACHE_LIMIT: int=128
var route_cache: Dictionary={}
var route_order: Array[Vector4i]=[]

func configure(field: RefCounted) -> void:
	field_ref=weakref(field)
	grid_point_limit=field.width*field.height
	neighbor_filter_enabled=true
	for y: int in range(field.height):
		for x: int in range(field.width):
			var cell:=Vector2i(x,y)
			var id: int=y*field.width+x
			if field.reachable[id]==0 or field.astar.is_point_solid(cell):continue
			add_point(id,field.cell_to_world(cell))
	for id: int in get_point_ids():
		var cell:=Vector2i(id%field.width,id/field.width)
		for offset: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1),Vector2i(-1,1)]:
			var neighbor: Vector2i=cell+offset
			if not field.astar.is_in_boundsv(neighbor):continue
			var next: int=neighbor.y*field.width+neighbor.x
			if has_point(next):connect_points(id,next)

func _filter_neighbor(from_id: int, neighbor_id: int) -> bool:
	var field: RefCounted=field_ref.get_ref()
	if field==null:return true
	var from: Vector2=get_point_position(from_id)
	var to: Vector2=get_point_position(neighbor_id)
	# Endpoint nodes move on every query and must never reuse an old decision.
	if from_id in [grid_point_limit,grid_point_limit+1] or neighbor_id in [grid_point_limit,grid_point_limit+1]:
		return not field.line_clear(from,to)
	var key:=Vector2i(mini(from_id,neighbor_id),maxi(from_id,neighbor_id))
	if not edge_checks.has(key):
		# Physical edges are undirected; retain a check valid in both directions.
		edge_checks[key]=field.line_clear(from,to) and field.line_clear(to,from)
	return not bool(edge_checks[key])

func _safe_destination(point: Vector2) -> Vector2:
	var field: RefCounted=field_ref.get_ref()
	if field.line_clear(point,point):return point
	var center: Vector2i=field.world_to_cell(point)
	# Match the existing click projection radius, but require a clear whole foot.
	for radius: int in range(18):
		var nearest:=Vector2.INF
		var distance: float=INF
		for y: int in range(center.y-radius,center.y+radius+1):
			for x: int in range(center.x-radius,center.x+radius+1):
				if maxi(absi(x-center.x),absi(y-center.y))!=radius:continue
				var cell:=Vector2i(x,y)
				if not field.astar.is_in_boundsv(cell):continue
				var id: int=y*field.width+x
				if not has_point(id):continue
				var candidate: Vector2=get_point_position(id)
				if not field.line_clear(candidate,candidate):continue
				var squared: float=candidate.distance_squared_to(point)
				if squared<distance:nearest=candidate;distance=squared
		if nearest.is_finite():return nearest
	return Vector2.INF

func _attach_endpoint(id: int, point: Vector2) -> bool:
	var field: RefCounted=field_ref.get_ref()
	var center: Vector2i=field.world_to_cell(point)
	add_point(id,point)
	var connected: bool=false
	# Several nearby anchors avoid trapping a valid endpoint behind one bad
	# center-to-center edge. Every connector uses the same physical foot check.
	for y: int in range(center.y-2,center.y+3):
		for x: int in range(center.x-2,center.x+3):
			var cell:=Vector2i(x,y)
			if not field.astar.is_in_boundsv(cell):continue
			var next: int=y*field.width+x
			if has_point(next) and field.line_clear(point,get_point_position(next)):
				connect_points(id,next)
				connected=true
	return connected

func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var field: RefCounted=field_ref.get_ref()
	if field==null or not field.line_clear(from,from):return PackedVector2Array()
	var target: Vector2=_safe_destination(to)
	if not target.is_finite():return PackedVector2Array()
	if field.line_clear(from,target):return PackedVector2Array([target])
	var start_cell: Vector2i=field.world_to_cell(from)
	var target_cell: Vector2i=field.world_to_cell(target)
	var key:=Vector4i(start_cell.x,start_cell.y,target_cell.x,target_cell.y)
	# The geometry is immutable for this field. Reuse only the verified
	# interior; moving endpoints must prove their new connecting segments.
	var interior: PackedVector2Array=route_cache.get(key,PackedVector2Array())
	if not interior.is_empty() and field.line_clear(from,interior[0]) and field.line_clear(interior[-1],target):
		var cached:=PackedVector2Array([from])
		cached.append_array(interior);cached.append(target)
		return _compact(cached)
	var start_id: int=grid_point_limit
	var target_id: int=grid_point_limit+1
	var start_attached: bool=_attach_endpoint(start_id,from)
	var target_attached: bool=_attach_endpoint(target_id,target)
	var result:=PackedVector2Array()
	if start_attached and target_attached:result=get_point_path(start_id,target_id)
	remove_point(start_id)
	remove_point(target_id)
	if result.size()>2:
		if not route_cache.has(key):
			if route_order.size()>=ROUTE_CACHE_LIMIT:route_cache.erase(route_order.pop_front())
			route_order.append(key)
		route_cache[key]=_compact(result.slice(1,result.size()-1))
	return _compact(result)

func _compact(points: PackedVector2Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for i: int in range(points.size()):
		if i>0 and i<points.size()-1:
			var before: Vector2=points[i]-points[i-1]
			var after: Vector2=points[i+1]-points[i]
			if before.cross(after)==0.0 and before.dot(after)>0.0:continue
		result.append(points[i])
	return result
