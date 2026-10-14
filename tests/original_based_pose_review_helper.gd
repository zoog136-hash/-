extends "res://tests/original_based_ogre_gameplay_test.gd"

# Keep real AI/combat/lifecycle checks unchanged. Only the explicit authored
# pose inspection moves to nearby walkable ground without foreground cover.
var pose_review_positioned: bool = false

func capture(name_value: String) -> void:
	if not captures.is_empty() and name_value.begins_with("authored-") and not pose_review_positioned:
		pose_review_positioned = true
		check(_position_visible_pose_review(), "authored pose review has no foreground cover")
	await super.capture(name_value)

func _position_visible_pose_review() -> bool:
	var original_player: Vector2 = world.player.position
	var original_monster: Vector2 = normal.position
	for radius: float in [0.0, 80.0, 160.0, 240.0, 320.0]:
		for direction: int in [4, 3, 5, 2, 6, 0, 1, 7]:
			var offset: Vector2 = screen_direction(direction) * radius
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
			var covered: bool = false
			for prop: Node2D in world.field_renderer.faded:
				if prop is Sprite2D and prop.global_position.y + 16.0 > actor_point.y:
					var bounds: Rect2 = prop.global_transform * (prop as Sprite2D).get_rect()
					if bounds.intersects(body):
						covered = true
						break
			if not covered:
				report.setup.pose_review = {"repositioned": radius > 0.0,
					"offset": [offset.x, offset.y], "monster_position": [actor_point.x, actor_point.y],
					"walkable": true, "foreground_clear": true, "terrain_hidden_or_modified": false}
				return true
	world.player.position = original_player
	normal.position = original_monster
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	return false
