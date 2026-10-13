extends "res://tests/original_based_monster_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.

func subject_name() -> String: return "고스트"
func subject_folder() -> String: return "ghost"
# The existing 50-HP ghost dies on the default character's first normal hit.
# Exercise a bounded non-lethal damage event through its production method
# before the unchanged real weapon kill/drop/pickup case. No stats are changed.
func prepare_lifecycle() -> void:
	report.setup.controlled_nonlethal_damage = 1
	normal.take_damage(1, false, "physical")
	check(normal.hp == normal.max_hp - 1 and not normal.dead, "real non-lethal ghost damage event")
