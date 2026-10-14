extends "res://tests/original_based_pose_review_helper.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_CAPTURE_DIR
# RenderingServer.frame_post_draw is awaited by the inherited capture helper.
const BOSS_SKILL_QA = preload("res://tests/original_based_boss_skill_helper.gd")

func subject_name() -> String: return "불사의 머미 로드"
func subject_folder() -> String: return "mummy_lord"
func special_kind() -> String: return "nova"
func lifecycle_attempt_limit() -> int: return BOSS_SKILL_QA.LIFECYCLE_ATTEMPT_LIMIT

func prepare_monster_direction(_direction: int) -> bool:
	normal.special_cooldown = 9999.
	return true

func monster_case() -> void:
	report.setup.normal_attack_probe = "Pause only the special cooldown for normal attacks, then exercise the existing special separately"
	await super.monster_case()
	await BOSS_SKILL_QA.exercise(self, special_kind())

func lifecycle_case() -> void:
	await super.lifecycle_case()
	if is_instance_valid(normal):
		check(not normal.species_visual.warning_active and not normal.motion.active, "actual weapon death clears boss warning and motion")
