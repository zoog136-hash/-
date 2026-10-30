extends "res://scripts/world.gd"
var measured_paths: int=0
func find_world_path(from_position: Vector2,to_position: Vector2) -> PackedVector2Array:
	measured_paths+=1
	return super.find_world_path(from_position,to_position)
