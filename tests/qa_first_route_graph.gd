extends "res://scripts/maps/native_png_route_graph.gd"
## Profiling only. All production calls, exact endpoints and return values persist.
var costs: Dictionary={"configure_us":0,"route_us":0,"route_calls":0,"filter_us":0,"filter_calls":0,"filter_max_us":0,"new_edges":0,"edge_cache_hits":0,"attach_us":0,"destination_us":0}
var routes: Array=[]
func configure(field: RefCounted) -> void:
	var start: int=Time.get_ticks_usec();super.configure(field)
	costs.configure_us+=Time.get_ticks_usec()-start
func route(from: Vector2,to: Vector2) -> PackedVector2Array:
	var field: RefCounted=field_ref.get_ref()
	var line_before: int=field.profile_line_us;var point_before: int=field.profile_point_us
	var before: Dictionary=costs.duplicate();var start: int=Time.get_ticks_usec()
	var result: PackedVector2Array=super.route(from,to)
	var elapsed: int=Time.get_ticks_usec()-start
	costs.route_us+=elapsed;costs.route_calls+=1
	routes.append({"from":[from.x,from.y],"to":[to.x,to.y],"us":elapsed,"line_us":field.profile_line_us-line_before,"point_us":field.profile_point_us-point_before,"filter_us":costs.filter_us-before.filter_us,"filter_calls":costs.filter_calls-before.filter_calls,"new_edges":costs.new_edges-before.new_edges,"edge_cache_hits":costs.edge_cache_hits-before.edge_cache_hits,"attach_us":costs.attach_us-before.attach_us,"destination_us":costs.destination_us-before.destination_us,"points":result.size(),"result":result})
	return result
func _filter_neighbor(from_id: int,neighbor_id: int) -> bool:
	if from_id<grid_point_limit and neighbor_id<grid_point_limit and edge_checks.has(Vector2i(mini(from_id,neighbor_id),maxi(from_id,neighbor_id))):costs.edge_cache_hits+=1
	var old_size: int=edge_checks.size();var start: int=Time.get_ticks_usec()
	var result: bool=super._filter_neighbor(from_id,neighbor_id)
	var elapsed: int=Time.get_ticks_usec()-start
	costs.filter_us+=elapsed;costs.filter_calls+=1;costs.filter_max_us=maxi(costs.filter_max_us,elapsed);costs.new_edges+=edge_checks.size()-old_size
	return result
func _attach_endpoint(id: int,point: Vector2) -> bool:
	var start: int=Time.get_ticks_usec();var result: bool=super._attach_endpoint(id,point)
	costs.attach_us+=Time.get_ticks_usec()-start;return result
func _safe_destination(point: Vector2) -> Vector2:
	var start: int=Time.get_ticks_usec();var result: Vector2=super._safe_destination(point)
	costs.destination_us+=Time.get_ticks_usec()-start;return result
