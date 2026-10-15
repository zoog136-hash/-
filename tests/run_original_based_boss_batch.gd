extends "res://tests/run_original_based_batch.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_BATCH_CAPTURE_DIR
# Reuse the full per-case Main/AI/combat/lifecycle checks and save isolation.
const BOSS_SKILL_QA = preload("res://tests/original_based_boss_skill_helper.gd")

func lifecycle_attempt_limit() -> int:
	return BOSS_SKILL_QA.LIFECYCLE_ATTEMPT_LIMIT

func prepare_monster_direction(direction: int) -> bool:
	normal.special_cooldown = 9999.
	return super.prepare_monster_direction(direction)

func monster_case() -> void:
	report.setup.normal_attack_probe = "Pause only special cooldown for normal attacks; exercise the unchanged existing special separately"
	await super.monster_case()
	var expected_kind: String = str(current_case.get("special", ""))
	check(not expected_kind.is_empty(), "boss fixture names its existing special kind")
	if not expected_kind.is_empty(): await BOSS_SKILL_QA.exercise(self, expected_kind)

func lifecycle_case() -> void:
	await super.lifecycle_case()
	if is_instance_valid(normal):
		check(not normal.species_visual.warning_active and not normal.motion.active,
			"actual weapon death clears boss warning and motion")
