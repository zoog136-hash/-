extends "res://tests/run_remaining106_transform_visual_review.gd"

# PR122 Tomb269: additive *real Main* SW visibility probe. The inherited 8/8
# Death Knight contacts, original QA checks, combat and native playback remain
# untouched. The source-only Tomb candidate must be staged in an isolated Main
# by the caller, never imported from an unapproved authoring draft.
#
# This script ONLY captures actual equipped-player frames with an unchanged
# smaller *production DB* opponent. It does not alter source PNGs, transforms,
# stats, physics, hit clocks, map obstacles or final approval.

const PR122_SMALL_NATIVE_TARGET := "해골 근위병"
const PR122_SW_INDEX := 3

func player_case(spec: Dictionary, transformed: bool) -> void:
	await super.player_case(spec, transformed)
	if not transformed or str(spec.get("transform_id", "")) != "269":
		return
	# This is a rendered visual-review supplement, not a fake headless approval.
	if captures.is_empty():
		return
	check(world.player.transform_active and str(world.player.motion.profile.profile_id) == "transform:269",
		"PR122 SW probe uses actual equipped Tomb269")
	if not world.player.transform_active:
		return
	var native: TwilightMonster = db_actor(PR122_SMALL_NATIVE_TARGET)
	if not is_instance_valid(native):
		return
	native.set_physics_process(false)
	var player_prior: Vector2 = world.player.position
	world.player.position = center
	world.player.cancel_attack()
	world.player.clear_click_path()
	world.player.motion.face(screen_direction(PR122_SW_INDEX))
	# The current A3 map uses native isometric cells for weapon range. Keep
	# the farthest genuinely reachable SW position; never bypass those rules.
	var legal_distance := -1.0
	for distance: float in [40.0, 30.0, 20.0, 10.0]:
		native.position = center + screen_direction(PR122_SW_INDEX) * distance
		if world.field_map.walkable(native.position) and world.field_map.point_clear(native.position) \
				and not world.field_map.is_safe(native.position) \
				and world._target_in_current_weapon_range(native) \
				and world._has_line_of_sight_world(world.player.global_position, native.position):
			legal_distance = distance
			break
	check(legal_distance > 0.0, "PR122 SW small target is on legal original-grid weapon cells")
	if legal_distance <= 0.0:
		native.queue_free()
		world.player.position = player_prior
		return
	native.home_position = native.position
	native.motion.cancel_attack()
	# The inherited case has just queue_free'd its Death Knight. Run the
	# existing production prune callback before appending the next QA target.
	world._update_target_hud()
	world._select_monster(native)
	check(world.selected_monster == native, "PR122 SW production selection binds the live small target")
	for _wait in range(160):
		if world.auto_attack_timer <= 0.0 and not world.player.motion.presenting_attack:
			break
		await tick()
	var kind: String = world._current_attack_kind()
	var chance: float = world._normal_attack_hit_chance(native, kind)
	check(chance > 0.0, "PR122 SW small native real hit can succeed")
	if chance <= 0.0:
		native.queue_free()
		world.player.position = player_prior
		return
	# Select a deterministic input seed, but leave actual damage/formulas untouched.
	var rng := RandomNumberGenerator.new()
	var found_seed := false
	for seed_value in range(1, 2001):
		rng.seed = seed_value
		if rng.randf() < chance:
			world.rng.seed = seed_value
			found_seed = true
			break
	check(found_seed, "PR122 SW small opponent original RNG positive hit seed")
	if not found_seed:
		native.queue_free()
		world.player.position = player_prior
		return
	var previous_hp: int = native.hp
	var previous_hit_count: int = native.damage_hit_count
	var prior_strikes: int = strikes.size()
	world.hud.attack_pressed.emit()
	check(not world.pending_attack.is_empty(), "PR122 SW extra real attack command")
	var saw_attack_one := false
	var saw_contact := false
	for _tick in range(180):
		await tick()
		var sprite: AnimatedSprite2D = active_sprite()
		if not saw_attack_one and world.player.motion.presenting_attack \
				and str(sprite.animation) == "attack_3" and sprite.frame == 1:
			saw_attack_one = true
			await capture_player_event("pr122-tomb269-SW-small-native-attack-1")
		if strikes.size() > prior_strikes and not saw_contact:
			saw_contact = true
			check(str(sprite.animation) == "attack_3" and sprite.frame == 1,
				"PR122 SW small opponent visible contact shares real damage marker")
			await capture_player_event("pr122-tomb269-SW-small-native-contact")
		if saw_contact and not world.player.motion.presenting_attack:
			break
	check(saw_attack_one, "PR122 SW extra native attack1 visual frame present")
	check(saw_contact and strikes.size() == prior_strikes + 1,
		"PR122 SW extra actual marker seen exactly once")
	check(native.hp < previous_hp and native.damage_hit_count == previous_hit_count + 1,
		"PR122 SW unchanged DB target takes real production damage")
	check(player_review_seen.has("pr122-tomb269-SW-small-native-attack-1")
		and player_review_seen.has("pr122-tomb269-SW-small-native-contact"),
		"PR122 SW extra source-scale/contact PNGs delivered")
	report.pr122_tomb269_smaller_target = {
		"status": "AUTOMATIC_QA_ONLY_NOT_VISUAL_APPROVAL",
		"opponent": PR122_SMALL_NATIVE_TARGET,
		"unchanged_original_8_direction_cases": true,
		"direction": "SW",
		"legal_original_grid_distance": legal_distance,
		"real_hit_count": native.damage_hit_count - previous_hit_count,
		"actual_hp_delta": previous_hp - native.hp,
		"attack_phase1_captured": saw_attack_one,
		"real_damage_contact_captured": saw_contact,
		"source_approved": false,
		"production_changed": false,
		"completed_added": 0
	}
	native.queue_free()
	await tick(2)
	world.player.position = player_prior
