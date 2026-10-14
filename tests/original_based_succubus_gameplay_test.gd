extends "res://tests/original_based_pose_review_helper.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.

func subject_name() -> String: return "서큐버스"
func subject_folder() -> String: return "succubus"

func monster_start_distance() -> float:
	# Retain the real magic attack range. Start outside it to exercise pursuit
	# before the production cast/projectile, without forcing melee behavior.
	return normal.current_attack_range() + 80.

func prepare_monster_direction(direction: int) -> bool:
	# The melee clearing is not a 400 px unobstructed circle. Select a real
	# clear approach separately for each long-range cast, retaining map rocks,
	# original spell range, collision and line-of-sight checks.
	for slot: Dictionary in world.field_population.slots:
		var actor: Variant = slot.monster
		if not is_instance_valid(actor): continue
		for offset: float in [0., 80., -80., 160., -160., 320., -320.]:
			var point: Vector2 = actor.position + Vector2(offset, 0)
			var start: Vector2 = point - screen_direction(direction) * monster_start_distance()
			if not route_clear(point, 150.): continue
			if not world.field_map.walkable(start) or not world.field_map.point_clear(start) or world.field_map.is_safe(start): continue
			if not world.field_map.line_clear(point, start): continue
			center = point
			world.player.position = center
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			return true
	return false

var magic_flights: Dictionary = {}

func observe_magic_flights() -> void:
	for flight: Dictionary in world.combat_flights.flights:
		var target: Variant = flight.target.get_ref()
		if target != world.player: continue
		var delta: Vector2 = flight.position - flight.previous
		if delta.length_squared() < .01: continue
		var aim: Vector2 = world.player.combat_hit_position() - (flight.previous as Vector2)
		check(delta.normalized().dot(aim.normalized()) > .995, "real monster magic travels toward actual player hit position")
		check(str(flight.kind) == "magic", "existing magic projectile kind retained")
		var facing: int = normal.motion.facing8
		magic_flights[facing] = {"compass":COMPASS[facing], "delta":str(delta), "toward_player":true, "kind":str(flight.kind)}

func monster_case() -> void:
	# Production deliberately skips visual updates outside the viewport. Keep
	# both the caster and target visible at the original long magic range.
	var previous_zoom: Vector2 = world.player.camera.zoom
	world.player.camera.zoom = Vector2.ONE * minf(1.6, 270. / monster_start_distance())
	physics_frame.connect(observe_magic_flights)
	await super.monster_case()
	physics_frame.disconnect(observe_magic_flights)
	world.player.camera.zoom = previous_zoom
	check(magic_flights.size() == 8, "actual monster magic observed in all eight directions")
	for contact: Dictionary in monster_strikes:
		check(str(contact.kind) == "magic", "actual arrival resolves existing magic contact")
	report.monster_projectiles = magic_flights.values()
