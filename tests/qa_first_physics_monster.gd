extends "res://scripts/monster.gd"
## Diagnostic only: production behavior is called unchanged; counters are inclusive.
var profile_physics_us: int=0
var profile_physics_calls: int=0
var profile_ai_us: int=0
var profile_ai_calls: int=0
var profile_move_us: int=0
var profile_move_calls: int=0
func _physics_process(delta: float) -> void:
	var begin: int=Time.get_ticks_usec();super._physics_process(delta)
	profile_physics_us+=Time.get_ticks_usec()-begin;profile_physics_calls+=1
func _tick_ai(delta: float) -> void:
	var begin: int=Time.get_ticks_usec();super._tick_ai(delta)
	profile_ai_us+=Time.get_ticks_usec()-begin;profile_ai_calls+=1
func _move_on_map() -> void:
	var begin: int=Time.get_ticks_usec();super._move_on_map()
	profile_move_us+=Time.get_ticks_usec()-begin;profile_move_calls+=1
