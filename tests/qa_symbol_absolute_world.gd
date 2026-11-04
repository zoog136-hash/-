extends TwilightWorld
## Deterministic hit/critical outcomes only; use production damage consumers.
var symbol_test_critical: bool = false
func _roll_monster_hit(_attacker: TwilightMonster, _attack_type: String = "melee") -> bool:
	return true
func _critical_chance(_rate: int, _resistance: int) -> float:
	return 1.0 if symbol_test_critical else 0.0
