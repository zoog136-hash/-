extends "res://scripts/world.gd"
var selection_path_calls: int = 0
var blocked_positions: Dictionary = {}
func find_world_path(_from: Vector2, to: Vector2) -> PackedVector2Array:
	selection_path_calls+=1
	return PackedVector2Array() if blocked_positions.has(to) else PackedVector2Array([to])
