extends "res://scripts/maps/field_population.gd"
var spawn_costs: Array=[]
var process_costs: Array=[]
var point_us: int=0
func _spawn_point(region: Dictionary) -> Vector2:
	var start: int=Time.get_ticks_usec()
	var result: Vector2=super._spawn_point(region)
	point_us+=Time.get_ticks_usec()-start
	return result
func _spawn_slot(slot: Dictionary) -> void:
	var start: int=Time.get_ticks_usec()
	var points_before: int=point_us
	var count: int=world.monsters_root.get_child_count()
	super._spawn_slot(slot)
	if world.physics_profile_script!=null:
		for index: int in range(count,world.monsters_root.get_child_count()):world.install_actor_physics_profile(world.monsters_root.get_child(index))
	spawn_costs.append({"region":str(slot.region.id),"slot":slot.slot_id,"total_us":Time.get_ticks_usec()-start,"point_us":point_us-points_before,"created":world.monsters_root.get_child_count()-count})
func _process(delta: float) -> void:
	var start: int=Time.get_ticks_usec()
	var before: int=spawn_costs.size()
	super._process(delta)
	process_costs.append({"us":Time.get_ticks_usec()-start,"spawn_calls":spawn_costs.size()-before})
