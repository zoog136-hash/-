extends RefCounted
# Independent monster-only decision rules, preserving existing player skill,
# weapon, collision, save, and attack animation systems.
const RETURN_RADIUS: float = 24.0
const PATH_STUCK_RETRY: float = 0.65
const STUCK_MOVE_EPSILON: float = 0.5
# Optional field-monster tactics. Assist and enrage never change loot odds,
# save data, player skills, collision, or existing attack animation markers.
const MAX_SOCIAL_ASSIST: int = 4
const SOCIAL_ALERT_DELAY: float = 0.8
const BOSS_ENRAGE_HP_RATIO: float = 0.35
const BOSS_ENRAGE_ATTACK_FACTOR: float = 0.82
const BOSS_ENRAGE_CHASE_FACTOR: float = 1.10

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

static func can_assist(
    source_group: String, ally_group: String, distance_to_source: float,
    ally_from_home: float, target_from_ally_home: float,
    ally_leash: float, assist_radius: float, player_safe: bool,
    player_concealed: bool, ally_returning: bool
) -> bool:
    # Empty groups must NOT identify every unrelated field monster as a pack.
    if source_group.strip_edges().is_empty() or source_group != ally_group:
        return false
    if player_safe or player_concealed or ally_returning:
        return false
    if assist_radius <= 0.0 or distance_to_source > assist_radius:
        return false
    if ally_leash <= 0.0 or ally_from_home > ally_leash:
        return false
    return target_from_ally_home <= ally_leash

static func should_enrage(boss: bool, current_hp: int, maximum_hp: int, settings: Dictionary = {}) -> bool:
    if not boss or maximum_hp <= 0 or current_hp <= 0:
        return false
    if not bool(settings.get("enabled", true)):
        return false
    var threshold: float = clampf(float(settings.get("hp_ratio", BOSS_ENRAGE_HP_RATIO)), 0.05, 0.90)
    return float(current_hp) / float(maximum_hp) <= threshold

static func attack_interval(base_interval: float, raging: bool) -> float:
    return maxf(0.12, base_interval * (BOSS_ENRAGE_ATTACK_FACTOR if raging else 1.0))

static func chase_speed_factor(raging: bool) -> float:
    return BOSS_ENRAGE_CHASE_FACTOR if raging else 1.0
