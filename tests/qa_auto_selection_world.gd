extends "res://scripts/world.gd"
var selection_path_calls: int = 0
var blocked_positions: Dictionary = {}
var last_test_attack: TwilightMonster
var last_test_attack_automatic: bool = false
func _run_auto_ground_pickup() -> bool: return false
func _run_auto_combat_quickslots() -> bool: return false
func _has_line_of_sight_world(_from: Vector2, _to: Vector2) -> bool: return true
func _target_in_current_weapon_range(_target: TwilightMonster) -> bool: return true
func _attack(automatic_acquisition: bool = false) -> void:
	last_test_attack = selected_monster
	last_test_attack_automatic = automatic_acquisition
func find_world_path(_from: Vector2, to: Vector2) -> PackedVector2Array:
	selection_path_calls+=1
	return PackedVector2Array() if blocked_positions.has(to) else PackedVector2Array([to])
