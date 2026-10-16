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
	# Renewed-map magic approaches can exhaust every nearby candidate. Search
	# more unchanged terrain while retaining the same walkability, full-body
	# prop bounds and 192px other-actor exclusion at every candidate.
	for radius: float in [0.0, 80.0, 160.0, 240.0, 320.0, 400.0, 480.0, 560.0, 640.0, 720.0, 800.0, 960.0, 1120.0, 1280.0, 1600.0, 2000.0, 2400.0, 3200.0]:
