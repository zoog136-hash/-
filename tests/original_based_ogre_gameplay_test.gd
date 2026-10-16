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
	# Large original field HP exceeds the bounded 200-attempt CI encounter
	# (wave guardian: 5,049 HP, 1,295 real damage in 200 attempts). Never
	# report full-HP victory: establish an explicitly pre-injured encounter
	# through the production damage handler, then verify genuine equipped
	# finishing hits, death signal, authored corpse, DB drop and manual pickup.
	# This is not used for bosses, which have an independent finisher setup.
	if normal.is_boss or normal.max_hp < 3000: return
	var original: Dictionary = record_for(normal.monster_name)
	check(not original.is_empty() and normal.hp == normal.max_hp and normal.max_hp == int(original.get("hp", 0)),
		"original full field HP verified before bounded finishing encounter")
	if original.is_empty() or normal.dead or normal.hp != normal.max_hp or normal.hp <= 300: return
	var full_max_hp: int = normal.max_hp
	var prior_battle_damage: int = normal.hp - 300
	normal.take_damage(prior_battle_damage, false, "prior_battle_qa")
	# Prior setup damage must not satisfy the real weapon hit-pose assertion.
	normal.motion.hit_clock = 0.0
	check(not normal.dead and normal.hp == 300 and normal.max_hp == full_max_hp,
		"prior battle uses production nonlethal damage; full field max HP retained")
	report.setup.lifecycle_battle_scope = {"phase":"original-HP field finisher, not entire fight",
		"original_max_hp":full_max_hp, "prior_battle_damage":prior_battle_damage,
		"prior_damage_pipeline":"TwilightMonster.take_damage",
		"finishing_hits":"actual equipped weapon and native physics/death/drop"}
