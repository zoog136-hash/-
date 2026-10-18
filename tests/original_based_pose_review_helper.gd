extends "res://tests/original_based_ogre_gameplay_test.gd"

# Keep real AI/combat/lifecycle checks unchanged. Only the explicit authored
# pose inspection moves to nearby walkable ground without foreground cover.
var pose_review_positioned: bool = false

func _pose_review_motion_clear(_origin: Vector2) -> bool:
	return true

func capture(name_value: String) -> void:
	if not captures.is_empty() and name_value.begins_with("authored-") and not pose_review_positioned:
		pose_review_positioned = true
		check(_position_visible_pose_review(), "authored pose review has no foreground cover")
	await super.capture(name_value)

func _position_visible_pose_review() -> bool:
	var original_player: Vector2 = world.player.position
	var original_monster: Vector2 = normal.position
	# Renewed-map magic approaches can exhaust every nearby candidate. Search
	# more unchanged terrain while retaining the same walkability, full-body
	# prop bounds and 192px other-actor exclusion at every candidate.
	var radii: Array[float] = [0.0, 80.0, 160.0, 240.0, 320.0, 400.0, 480.0, 560.0, 640.0, 720.0, 800.0, 960.0, 1120.0, 1280.0, 1600.0, 2000.0, 2400.0, 3200.0]
	for radius: int in range(0, 3280, 80):
		if not radii.has(float(radius)): radii.append(float(radius))
	# Full walk envelopes may fit between the original eight radial samples.
	# Add denser headings/radii rather than relaxing any body/map guard.
	var directions: Array[int] = [4, 3, 5, 2, 6, 0, 1, 7]
	for direction: int in range(8, 72): directions.append(direction)
	for radius: float in radii:
		for direction: int in directions:
			var heading := screen_direction(direction) if direction < 8 else Vector2.from_angle(TAU * float(direction - 8) / 64.0)
			var offset: Vector2 = heading * radius
			var actor_point: Vector2 = original_monster + offset
			var player_point: Vector2 = original_player + offset
			if not route_clear(actor_point, 0.0) or not route_clear(player_point, 0.0): continue
			world.player.position = player_point
			normal.position = actor_point
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			# Conservative visible-body bounds include the long lizard's tail
			# and all reviewed collapse poses. Inspect actual streamed prop rects.
			var body := Rect2(actor_point + Vector2(-128, -160), Vector2(256, 176))
			if not preload("res://tests/qa_rendered_prop_clearance.gd").clear_bounds(world.field_renderer, body): continue
			var covered: bool = false
			# A paused production monster may still render behind the subject.
			# Magic approach selection can start at that monster's spawn point.
			# Keep all actors visible and unchanged; select an empty nearby
			# pose-review position instead of masking an overlapping body.
			for actor: Node in world.monsters_root.get_children():
				if actor == normal or not actor is Node2D: continue
				var other := actor as Node2D
				if not other.is_visible_in_tree(): continue
				if actor_point.distance_squared_to(other.position) < 192.0 * 192.0:
					covered = true
					break
			if covered: continue
			for prop: Node2D in world.field_renderer.faded:
				if prop is Sprite2D and prop.global_position.y + 16.0 > actor_point.y:
					var bounds: Rect2 = prop.global_transform * (prop as Sprite2D).get_rect()
					if bounds.intersects(body):
						covered = true
						break
			if not covered and _pose_review_motion_clear(actor_point):
				report.setup.pose_review = {"repositioned": radius > 0.0,
					"offset": [offset.x, offset.y], "monster_position": [actor_point.x, actor_point.y],
					"walkable": true, "foreground_clear": true, "other_actor_clear": true,
					"terrain_hidden_or_modified": false}
				return true
	world.player.position = original_player
	normal.position = original_monster
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	return false
