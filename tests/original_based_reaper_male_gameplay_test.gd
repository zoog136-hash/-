extends "res://tests/original_based_reaper_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.

func subject_path() -> String: return "res://assets/actors/eight_direction/original_based/reaper_male/SpriteFrames.tres"
func subject_spec() -> Dictionary: return {"job":"사신", "appearance":3, "transform_id":"258", "name":"배틀 사이드", "type":"사이드", "style":"slash", "magic":false}
