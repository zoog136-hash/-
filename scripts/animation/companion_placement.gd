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

var heading: float = 0.0
var initialized: bool = false

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
	initialized = true

## Advance the smoothed heading toward `facing8`; returns the current angle.
func advance(delta: float, facing8: int) -> float:
	var target: float = facing_angle(facing8)
	if not initialized:
		reset(facing8)
		return heading
	var diff: float = angle_difference(heading, target)
	var step: float = TURN_SPEED * maxf(delta, 0.0)
	heading = target if absf(diff) <= step else wrapf(heading + signf(diff) * step, -PI, PI)
	return heading

func doll(delta: float, facing8: int, mirror: bool = false) -> Vector2:
	return offset_at(advance(delta, facing8), DOLL_BEHIND, -DOLL_SIDE if mirror else DOLL_SIDE)

func relic(delta: float, facing8: int, mirror: bool = false) -> Vector2:
	return offset_at(advance(delta, facing8), RELIC_BEHIND, -RELIC_SIDE if mirror else RELIC_SIDE, RELIC_LIFT)
