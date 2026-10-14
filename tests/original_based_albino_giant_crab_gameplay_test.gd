extends "res://tests/original_based_reaper_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.
# The original red shell and natural pincers remain the transformed body.
func subject_path() -> String: return "res://assets/actors/eight_direction/original_based/albino_giant_crab/SpriteFrames.tres"
func subject_spec() -> Dictionary:
	return {"job":"다크엘프", "appearance":3, "transform_id":"351", "name":"강철 크로우", "type":"크로우", "style":"slash", "magic":false}
