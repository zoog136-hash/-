extends RefCounted
# Independent monster-only decision rules, preserving existing player skill,
# weapon, collision, save, and attack animation systems.
const RETURN_RADIUS: float = 24.0
const PATH_STUCK_RETRY: float = 0.65
const STUCK_MOVE_EPSILON: float = 0.5

static func should_disengage(
	field_active: bool, safe_zone: bool, concealed: bool,
	monster_from_home: float, player_from_home: float, player_distance: float,
	aggro_remaining: float, aggro_radius: float, leash_distance: float
) -> bool:
	if not field_active:
		return false
	if safe_zone or concealed:
		return true
	if monster_from_home > maxf(0.0,leash_distance):
		return true
	if player_from_home > maxf(0.0,leash_distance):
		return true
	# Combat hostility used to be extended forever even when the target left
	# pursuit range. End the encounter and walk home instead of freezing.
	return aggro_remaining > 0.0 and player_distance > maxf(1.0,aggro_radius) * 1.7

static func should_keep_returning(was_returning: bool, home_distance: float) -> bool:
	return was_returning and home_distance > RETURN_RADIUS

static func next_stuck_elapsed(previous: float, moved: float, requested_speed: float, delta: float) -> float:
	if requested_speed <= 2.0 or moved >= STUCK_MOVE_EPSILON:
		return 0.0
	return maxf(0.0, previous) + maxf(0.0, delta)

static func should_repath(stuck_elapsed: float) -> bool:
	return stuck_elapsed >= PATH_STUCK_RETRY
