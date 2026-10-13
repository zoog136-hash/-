extends "res://tests/original_based_monster_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.

func subject_name() -> String: return "오우거"
func subject_folder() -> String: return "ogre"

func prepare_lifecycle() -> void:
	if normal.monster_level < 100 and normal.max_hp < 1500: return
	# High-level or high-HP regional targets outlast the starter weapon's
	# bounded fight. Equip a real high-accuracy DB weapon through the inventory
	# handler; do not lower monster HP/armor or force successful damage rolls.
	var weapon: Dictionary = world._find_catalog_item_record("진명황의 집행검")
	check(not weapon.is_empty(), "existing endgame sword for high-level target")
	world._equip_or_acquire_item(weapon, true)
	check(world._current_weapon_type() == "양손검", "real endgame weapon equipment")
	report.setup.lifecycle_weapon = "진명황의 집행검"
