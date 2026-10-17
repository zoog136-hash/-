extends "res://tests/original_based_reaper_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.
func subject_path() -> String: return "res://assets/actors/eight_direction/original_based/pan/SpriteFrames.tres"
func subject_spec() -> Dictionary:
	return {"job":"기사", "appearance":3, "transform_id":"218", "name":"크림슨 랜스", "type":"창", "style":"thrust", "magic":false}

func inspect_poses() -> void:
	# The long original spear can be correctly hidden by foreground rocks.
	# Review it on nearby real walkable terrain; retain all gameplay checks.
	if not captures.is_empty():
		check(_position_visible_pan_review(), "whole original spear has unobstructed Main review")
	await super.inspect_poses()

func _position_visible_pan_review() -> bool:
	var original_center: Vector2 = center
	for radius: float in [0.0, 80.0, 160.0, 240.0, 320.0]:
		for direction: int in [4, 3, 5, 2, 6, 0, 1, 7]:
			var point: Vector2 = original_center + screen_direction(direction) * radius
			if not route_clear(point, 0.0): continue
			world.player.position = point
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			var body := Rect2(point + Vector2(-128, -160), Vector2(256, 176))
			var covered: bool = false
			for prop: Node2D in world.field_renderer.faded:
				if prop is Sprite2D and prop.global_position.y + 16.0 > point.y:
					if (prop.global_transform * (prop as Sprite2D).get_rect()).intersects(body):
						covered = true
						break
			if not covered:
				center = point
				report.setup.pose_review = {"offset": [point.x - original_center.x, point.y - original_center.y],
					"walkable": true, "foreground_clear": true, "terrain_hidden_or_modified": false}
				return true
	world.player.position = original_center
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	return false
