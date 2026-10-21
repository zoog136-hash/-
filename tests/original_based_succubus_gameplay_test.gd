extends "res://tests/original_based_pose_review_helper.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.

func subject_name() -> String: return "서큐버스"
func subject_folder() -> String: return "succubus"

func run() -> void:
	# These authored ranged-art fixtures require a 390px (or longer) approach
	# in every direction plus torso-height spell LOS. The reviewed native
	# pockets cannot contain that canonical arena; preserve range and physics
	# on the original A3 fixture instead of shortening or skipping the checks.
	if preload("res://tests/legacy_aden_faith_fixture.gd").delegate(self,str(get_script().resource_path)): return
	await super.run()

func monster_start_distance() -> float:
	if normal.attack_type != "magic": return super.monster_start_distance()
	# Retain the real magic attack range. Start outside it to exercise pursuit
	# before the production cast/projectile, without forcing melee behavior.
	return normal.current_attack_range() + 80.

func _magic_projectile_lane_clear(point: Vector2, direction: int) -> bool:
	# The AI checks source-ground LOS to start the cast, then launches from
	# the actual monster hit anchor; the flight uses a different, torso-offset
	# line. A ground-clear approach can still clip one original edge at impact.
	# Check BOTH real paths in advance instead of weakening impact assertions.
	var heading: Vector2 = screen_direction(direction)
	var cast_range: float = normal.current_attack_range()
	var to_ground: Vector2 = point + world.player.motion.profile.hit_position - normal.motion.profile.hit_position
	for margin: float in [-12.0, 0.0, 12.0]:
		var caster: Vector2 = point - heading * (cast_range + margin)
		var projectile_start: Vector2 = caster + heading * normal.visual_height * .18
		if not world.field_map.walkable(caster) or not world.field_map.point_clear(caster) or world.field_map.is_safe(caster): return false
		if not world.field_map.line_clear(caster, point) or not world.field_map.line_clear(projectile_start, to_ground): return false
	return true

func prepare_monster_direction(direction: int) -> bool:
	if normal.attack_type != "magic": return super.prepare_monster_direction(direction)
	# Preserve original spell range and obstacle physics. Search real occupied
	# population positions first, then sampled verified source-region cells
	# when a long cast requires more than the melee arena's 150px clearance.
	var anchors: Array[Vector2] = []
	for slot: Dictionary in world.field_population.slots:
		var actor: Variant = slot.get("monster")
		if is_instance_valid(actor) and not actor.dead: anchors.append(actor.global_position)
	if world.field_map is RemakePlayableField:
		var source: RemakePlayableField = world.field_map as RemakePlayableField
		for id: String in ["meadow", "forest", "ruins", "dragon_valley", "western_approach"]:
			var cells: PackedInt32Array = source.region_cells.get(id, PackedInt32Array())
			for index: int in range(0, cells.size(), maxi(1, int(cells.size() / 20))):
				var flat: int = cells[index]
				anchors.append(source.cell_to_world(Vector2i(flat % source.width, int(flat / source.width))))
	for anchor: Vector2 in anchors:
		for offset: float in [0., 80., -80., 160., -160., 320., -320.]:
			var point: Vector2 = anchor + Vector2(offset, 0)
			var start: Vector2 = point - screen_direction(direction) * monster_start_distance()
			if not route_clear(point, 150.): continue
			if not world.field_map.walkable(start) or not world.field_map.point_clear(start) or world.field_map.is_safe(start): continue
			if not world.field_map.line_clear(point, start): continue
			if not _magic_projectile_lane_clear(point, direction): continue
			center = point
			world.player.position = center
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			report.setup["magic_lane_" + COMPASS[direction]] = {"center": [center.x, center.y], "start": [start.x, start.y],
				"actual_spell_range": normal.current_attack_range(), "real_projectile_ground_los": true}
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
	if normal.attack_type != "magic":
		await super.monster_case()
		return
	magic_flights.clear()
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
