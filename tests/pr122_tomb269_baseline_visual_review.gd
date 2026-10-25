extends "res://tests/pr122_tomb269_small_native_sw_probe.gd"

# Add a same-map comparison after all inherited real eight-direction commands
# and the extra SW contact. The comparison uses public visual-controller time;
# it does not send damage, change stats, or provide final source approval.
const PR122_COMPLETED_BASELINE := "아이언 골렘"

func pr122_baseline_bounds(actor: TwilightMonster) -> Rect2:
	var bounds: Rect2 = actor.sprite.get_rect()
	if actor.sprite.texture is AtlasTexture:
		var atlas := actor.sprite.texture as AtlasTexture
		bounds = Rect2(bounds.position + atlas.margin.position, atlas.region.size)
	return actor.sprite.global_transform * bounds

func pr122_pair_clear(baseline: TwilightMonster) -> bool:
	var player_bounds: Rect2 = active_sprite().global_transform * transform_temporal_local_bounds(active_sprite(), transform_temporal_texture(active_sprite()))
	var baseline_bounds := pr122_baseline_bounds(baseline)
	if player_bounds.intersects(baseline_bounds): return false
	if not RENDERED_PROP_QA.clear_bounds(world.field_renderer, player_bounds) \
			or not RENDERED_PROP_QA.clear_bounds(world.field_renderer, baseline_bounds): return false
	for actor: Node in world.monsters_root.get_children():
		if actor == baseline or not actor is TwilightMonster or not actor.is_visible_in_tree(): continue
		var other := actor as TwilightMonster
		if other.sprite.texture == null: continue
		var bounds := pr122_baseline_bounds(other)
		if bounds.intersects(player_bounds) or bounds.intersects(baseline_bounds): return false
	for prop: Node2D in world.field_renderer.faded:
		if not prop is Sprite2D: continue
		var bounds: Rect2 = prop.global_transform * (prop as Sprite2D).get_rect()
		if prop.global_position.y + 16.0 > world.player.global_position.y and bounds.intersects(player_bounds): return false
		if prop.global_position.y + 16.0 > baseline.global_position.y and bounds.intersects(baseline_bounds): return false
	return true

func pr122_capture_pair(baseline: TwilightMonster, direction: int, role: String, phase: int) -> Dictionary:
	var before := player_review_snapshot()
	await RenderingServer.frame_post_draw
	check(player_review_snapshot() == before, "PR122 comparison draw preserves controller/HP/strikes")
	check(pr122_pair_clear(baseline), "PR122 both complete comparison bodies unobstructed")
	var player_bounds: Rect2 = active_sprite().get_global_transform_with_canvas() * transform_temporal_local_bounds(active_sprite(), transform_temporal_texture(active_sprite()))
	var baseline_bounds: Rect2 = world.get_global_transform_with_canvas() * pr122_baseline_bounds(baseline)
	check(root.get_visible_rect().encloses(player_bounds) and root.get_visible_rect().encloses(baseline_bounds),
		"PR122 both full comparison bodies in actual viewport")
	var stem := "pr122-tomb269-iron-golem-%s-%s-%d" % [COMPASS[direction], role, phase]
	var path := captures.path_join(stem + ".png")
	check(not FileAccess.file_exists(path), "PR122 fresh immutable comparison evidence")
	if FileAccess.file_exists(path): return {}
	check(root.get_texture().get_image().save_png(path) == OK, "PR122 same-Main comparison PNG")
	check(player_review_snapshot() == before, "PR122 screenshot cannot change damage state")
	report.screenshots.append(stem + ".png")
	var baseline_frame := -1
	var baseline_frames: SpriteFrames = baseline.motion.frame_source
	for index: int in range(baseline_frames.get_frame_count(baseline.motion._resolved_key)):
		if baseline_frames.get_frame_texture(baseline.motion._resolved_key, index) == baseline.sprite.texture:
			baseline_frame = index
			break
	check(baseline_frame >= 0, "PR122 comparison baseline texture is a real native phase")
	return {"path": path, "sha256": FileAccess.get_sha256(path), "direction": COMPASS[direction],
		"role": role, "player_native_phase": phase, "baseline_frame": baseline_frame,
		"player_base_scale": transform_temporal_vec(active_sprite().get_meta("base_scale", Vector2.ONE)),
		"player_bounds": [player_bounds.position.x, player_bounds.position.y, player_bounds.size.x, player_bounds.size.y],
		"baseline_bounds": [baseline_bounds.position.x, baseline_bounds.position.y, baseline_bounds.size.x, baseline_bounds.size.y],
		"unchanged_gameplay_state": before}

func player_case(spec: Dictionary, transformed: bool) -> void:
	await super.player_case(spec, transformed)
	if not transformed or str(spec.get("transform_id", "")) != "269" or captures.is_empty(): return
	await tick(60) # Let existing production impact effects expire naturally.
	var baseline: TwilightMonster = db_actor(PR122_COMPLETED_BASELINE)
	if not is_instance_valid(baseline): return
	check(baseline.motion.profile.profile_id == "monster:" + PR122_COMPLETED_BASELINE
		and baseline.motion.profile.frames_path == "res://assets/actors/eight_direction/original_based/iron_golem/SpriteFrames.tres",
		"PR122 exact completed production Iron Golem, including spaced DB key")
	var original_motion: TwilightActorMotion = world.player.motion
	var profile: TwilightAnimationProfile = original_motion.profile
	var sprite := active_sprite()
	var base_scale: Vector2 = sprite.get_meta("base_scale", Vector2.ONE)
	check(is_equal_approx(base_scale.x, base_scale.y * 0.9), "PR122 comparison retains latest transform X0.90/Y1.00")
	var before := transform_temporal_invariants(profile, sprite)
	var original_position: Vector2 = world.player.position
	var original_camera_position: Vector2 = world.player.camera.position
	var original_camera_zoom: Vector2 = world.player.camera.zoom
	var original_world_mode: Node.ProcessMode = world.process_mode
	var baseline_profile: TwilightAnimationProfile = baseline.motion.profile
	var baseline_frames: SpriteFrames = baseline.motion.frame_source
	var baseline_hp: int = baseline.hp
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.camera.zoom = Vector2(1.8, 1.8)
	world.player.camera.position = Vector2(90, -32)
	var placed := false
	for radius: float in [0.0, 240.0, 480.0, 720.0, 1120.0, 1600.0]:
		for heading: int in range(8):
			var point := center + screen_direction(heading) * radius
			var left := point - Vector2(90, 0)
			var right := point + Vector2(90, 0)
			if not route_clear(left, 150.0) or not route_clear(right, 150.0): continue
			world.player.position = left
			baseline.position = right
			world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			if pr122_pair_clear(baseline): placed = true; break
		if placed: break
	check(placed, "PR122 same untouched map has a clear complete-body comparison pair")
	var samples: Array[Dictionary] = []
	if placed:
		for direction: int in range(8):
			for role: String in ["idle", "walk"]:
				var motion: TwilightActorMotion = TRANSFORM_TEMPORAL_MOTION.new()
				motion.profile = profile
				world.player.motion = motion
				var comparison_motion: TwilightActorMotion = TRANSFORM_TEMPORAL_MOTION.new()
				comparison_motion.profile = baseline_profile
				comparison_motion.frame_source = baseline_frames
				baseline.motion = comparison_motion
				var aim := screen_direction(direction)
				motion.face(aim); comparison_motion.face(aim)
				var seen: Dictionary = {}
				var expected := 1 if role == "idle" else sprite.sprite_frames.get_frame_count("walk_" + str(direction))
				for step: int in range(480):
					var delta := 0.0 if step == 0 else TRANSFORM_TEMPORAL_STEP
					motion.advance(delta, aim * profile.reference_speed * 0.75 if role == "walk" else Vector2.ZERO)
					comparison_motion.advance(delta, aim * baseline_profile.reference_speed * 0.75 if role == "walk" else Vector2.ZERO)
					motion.apply(sprite, base_scale)
					comparison_motion.apply(baseline.sprite, baseline.animation_base_scale)
					check(motion._resolved_key == role + "_" + str(direction), "PR122 public controller selects exact facing/role")
					if not seen.has(sprite.frame):
						seen[sprite.frame] = true
						samples.append(await pr122_capture_pair(baseline, direction, role, sprite.frame))
					if seen.size() == expected: break
				check(seen.size() == expected, "PR122 every native walk comparison phase rendered")
	world.player.motion = original_motion
	world.player.position = original_position
	world.player.camera.position = original_camera_position
	world.player.camera.zoom = original_camera_zoom
	original_motion.apply(sprite, base_scale)
	world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	world.process_mode = original_world_mode
	check(transform_temporal_invariants(profile, sprite) == before, "PR122 comparison restores exact original profile/stats/HP/weapon clock")
	check(baseline.hp == baseline_hp and baseline.motion.profile == baseline_profile, "PR122 completed baseline stats/profile unchanged")
	report.pr122_tomb269_completed_baseline = {"scope": "Additive same-Main QA-clocked visual comparison; inherited actual input/contact/lifecycle retained",
		"baseline": PR122_COMPLETED_BASELINE, "baseline_profile": baseline_profile.profile_id,
		"baseline_frames": baseline_profile.frames_path, "samples": samples,
		"production_changes": false, "source_approved": false, "completed_added": 0}
	baseline.queue_free()
	await tick(2)
