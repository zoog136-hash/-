extends "res://tests/run_remaining106_visual_review.gd"

const BOSS_SKILL = preload("res://tests/original_based_boss_skill_helper.gd")
var reuse_special_active := false

func lifecycle_attempt_limit() -> int:
	return BOSS_SKILL.LIFECYCLE_ATTEMPT_LIMIT if is_instance_valid(normal) and normal.is_boss else super.lifecycle_attempt_limit()

func prepare_lifecycle() -> void:
	super.prepare_lifecycle()
	if normal.is_boss:
		BOSS_SKILL.prepare_real_boss_finisher(self)

func prepare_monster_direction(direction: int) -> bool:
	if normal.is_boss:
		normal.special_cooldown = 9999.0
	return super.prepare_monster_direction(direction)

func monster_case() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_animation_profiles.json")).profiles["monster:"+subject_name()]
	var width := float(expected.get("native_width_ratio",1.0))
	check(is_equal_approx(normal.motion.profile.native_width_ratio,width), "explicit target native width profile")
	check(is_equal_approx(normal.animation_base_scale.x/normal.animation_base_scale.y,width), "target width belongs to visual scale, not collider")
	var tint: Variant = expected.get("color_tint","ffffff")
	if tint is Array:
		check(normal.motion.profile.color_tint.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])), "original source shader target multipliers retain HDR components")
	else:
		check(normal.motion.profile.color_tint == Color.from_string(str(tint),Color.WHITE), "existing string color path preserved")
	var original := record_for(subject_name())
	check(normal.base_move_speed == float(original.get("speed",70.0+float(mini(70,int(float(normal.max_hp)/10.0))))), "original movement speed retained")
	check(is_equal_approx((normal.get_node("CollisionShape2D").shape as CircleShape2D).radius,float(original.get("collision_radius",19.0))), "original collision radius retained")
	await super.monster_case()
	var kind := str(current_case.get("special_kind",""))
	if not kind.is_empty():
		check(review_body_clear(center), "actual boss special origin clear of props")
		reuse_special_active = true
		await BOSS_SKILL.exercise(self,kind)
		reuse_special_active = false

func tick(count: int = 1) -> void:
	for index in range(count):
		await super.tick()
		if not is_instance_valid(normal) or normal.motion.frame_source == null:
			continue
		var frame := review_frame()
		if review_stage == "ai" and normal.motion.state in ["walk","run"]:
			await review_capture("ai-%s-walk-native-%d" % [COMPASS[review_direction],frame])
		elif reuse_special_active:
			var label := "special-%s-%s-%d" % [COMPASS[normal.motion.facing8],normal.motion._resolved_key,frame]
			await review_capture(label)
