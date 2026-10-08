extends RefCounted

## Existing stat/skill tests run in one frame. Advance the real combat clocks so
## their assertions now observe impact, without enabling unrelated AI or save I/O.
static func settle(world: Node) -> void:
	var actor: TwilightPlayer = world.get("player")
	for step: int in range(180):
		actor.motion.advance(1.0 / 60.0, Vector2.ZERO)
		world.combat_flights._physics_process(1.0 / 60.0)
		if world.pending_attack.is_empty() and world.combat_flights.flights.is_empty() and not actor.motion.active:
			return
