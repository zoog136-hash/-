extends "res://tests/original_based_reaper_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.
# The transform keeps its natural beak/flippers; the equipped claw determines
# real production damage and cadence without adding a weapon to the artwork.
func subject_path() -> String: return "res://assets/actors/eight_direction/original_based/ancient_penguin/SpriteFrames.tres"
func subject_spec() -> Dictionary:
	return {"job":"다크엘프", "appearance":3, "transform_id":"249", "name":"강철 크로우", "type":"크로우", "style":"slash", "magic":false}
