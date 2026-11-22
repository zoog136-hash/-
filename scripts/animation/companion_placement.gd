extends RefCounted
class_name TwilightCompanionPlacement
## Where a summoned magic doll / relic stands relative to its owner.
##
## The 523 client carries no follow offset for them: NpcCategory 14 (MagicDoll)
## and 138 (HolyStuff) only say "not attackable/selectable", NpcClass gives a
## server AI id (34 / 18368) and spr/list holds no anchor attribute. Their
## field position is server-driven. TWILIGHT 근사 (observed play + user report
## "성물이 캐릭 앞에 있어", community report of dolls and relics carried behind
## the character): the doll trails behind and to one side, the relic floats
## behind the head and is always drawn behind the character.
##
## Offsets are in the ground plane (screen y doubled, as the 2:1 Land cells),
## rotated by the owner's facing8 (clockwise from E) and turned smoothly so a
## reversal swings around the owner instead of cutting through it.

## TWILIGHT 근사: ground-plane distances behind / to the right of the facing.
const DOLL_BEHIND: float = 42.0
const DOLL_SIDE: float = 34.0
const RELIC_BEHIND: float = 22.0
const RELIC_SIDE: float = -10.0
## TWILIGHT 근사: screen lift of the relic's foot point (its own 523 frames
## already float above that point).
const RELIC_LIFT: float = 30.0
## How far behind the owner's foot line the relic sorts (screen px).
const RELIC_SORT_BEHIND: float = 1.0
## TWILIGHT 근사: heading turn rate (rad/s); a 180-degree reversal takes 0.5 s.
const TURN_SPEED: float = TAU
## The placement turns with the owner's smoothed travel direction (ground
## plane), not with every facing8 change: an auto-hunt route alternating
## diagonal and straight legs keeps one mean heading instead of swinging the
## followers to and fro. Time constant (s) of that smoothing.
const HEADING_SMOOTH_SECONDS: float = 0.35
## Below this smoothed ground speed (px/s) the last heading is kept.
const HEADING_MIN_SPEED: float = 20.0
## TWILIGHT 근사: follow lag (s of the owner's travel) and ease rate (1/s).
## The follower eases in the owner's frame: its offset approaches
## (place - owner velocity * lag), so a long phone frame moves it with the
## owner instead of snapping it onto its place and letting the lag grow back
## (the old ease toward a fixed point: 5-8 px forward/back jumps per hitch).
const DOLL_LAG_SECONDS: float = 1.0 / 7.0
const DOLL_EASE_RATE: float = 7.0
const RELIC_LAG_SECONDS: float = 1.0 / 8.0
const RELIC_EASE_RATE: float = 8.0
## Owner moves farther than this in one update (teleport/region): re-place.
const RELOCATE_DISTANCE: float = 900.0
const MAX_LAG_SPEED: float = 600.0

var heading: float = 0.0
var initialized: bool = false
var target_heading: float = 0.0
var travel: Vector2 = Vector2.ZERO # smoothed owner ground velocity
var relative: Vector2 = Vector2.ZERO # follower offset from the owner
var has_relative: bool = false
var last_owner: Vector2 = Vector2.ZERO

static func facing_angle(facing8: int) -> float:
	return float(posmod(facing8, 8)) * PI / 4.0

## Screen offset for a ground-plane (behind, side) pair at `angle`.
static func offset_at(angle: float, behind: float, side: float, lift: float = 0.0) -> Vector2:
	var forward := Vector2.RIGHT.rotated(angle)
	var right := forward.rotated(PI / 2.0)
	var ground: Vector2 = -forward * behind + right * side
	return Vector2(ground.x, ground.y * 0.5 - lift)

static func doll_offset(facing8: int, mirror: bool = false) -> Vector2:
	return offset_at(facing_angle(facing8), DOLL_BEHIND, -DOLL_SIDE if mirror else DOLL_SIDE)

static func relic_offset(facing8: int, mirror: bool = false) -> Vector2:
	return offset_at(facing_angle(facing8), RELIC_BEHIND, -RELIC_SIDE if mirror else RELIC_SIDE, RELIC_LIFT)

func reset(facing8: int) -> void:
	heading = facing_angle(facing8)
	target_heading = heading
	travel = Vector2.ZERO
	has_relative = false
	initialized = true

## Smoothed follower point (global) for this update. `relic` selects the relic
## placement and ease; the result moves only forward while the owner walks
## straight, whatever the frame pacing (see DOLL_LAG_SECONDS).
func follow(delta: float, owner_position: Vector2, owner_velocity: Vector2, facing8: int, relic: bool = false, mirror: bool = false) -> Vector2:
	if not initialized: reset(facing8)
	var dt: float = maxf(delta, 0.0)
	if has_relative and owner_position.distance_to(last_owner) > RELOCATE_DISTANCE: has_relative = false
	var ground := Vector2(owner_velocity.x, owner_velocity.y * 2.0)
	travel += (ground - travel) * (1.0 - exp(-dt / HEADING_SMOOTH_SECONDS))
	if travel.length() > HEADING_MIN_SPEED: target_heading = travel.angle()
	var diff: float = angle_difference(heading, target_heading)
	var step: float = TURN_SPEED * dt
	heading = target_heading if absf(diff) <= step else wrapf(heading + signf(diff) * step, -PI, PI)
	var place: Vector2 = offset_at(heading, RELIC_BEHIND, -RELIC_SIDE if mirror else RELIC_SIDE, RELIC_LIFT) if relic else offset_at(heading, DOLL_BEHIND, -DOLL_SIDE if mirror else DOLL_SIDE)
	var lag: float = RELIC_LAG_SECONDS if relic else DOLL_LAG_SECONDS
	var rate: float = RELIC_EASE_RATE if relic else DOLL_EASE_RATE
	var goal: Vector2 = place - owner_velocity.limit_length(MAX_LAG_SPEED) * lag
	if not has_relative:
		relative = place
		has_relative = true
	else:
		relative = goal + (relative - goal) * exp(-rate * dt)
		if relative.distance_to(goal) < 0.05: relative = goal
	last_owner = owner_position
	return owner_position + relative

## Current offset of the follower point from its owner.
func current_offset() -> Vector2:
	return relative
