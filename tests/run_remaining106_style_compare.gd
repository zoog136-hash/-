extends "res://tests/run_remaining106_visual_review.gd"

# Visual comparison only. Actual AI/combat/lifecycle are separately retained.
func comparison_capture(stem: String, baseline: TwilightMonster) -> void:
	var minimap := world.hud.find_child("FieldMinimap",true,false) as Control
	for actor: TwilightMonster in [normal,baseline]:
		var bounds: Rect2 = actor.sprite.get_rect()
		if actor.sprite.texture is AtlasTexture:
			var atlas := actor.sprite.texture as AtlasTexture
			bounds = Rect2(bounds.position + atlas.margin.position,atlas.region.size)
		var screen: Rect2 = actor.sprite.get_global_transform_with_canvas() * bounds
		check(root.get_visible_rect().encloses(screen),"full comparison body in actual viewport " + stem)
		if minimap != null and minimap.is_visible_in_tree():
			var hud_rect: Rect2 = minimap.get_global_transform_with_canvas() * Rect2(Vector2.ZERO,minimap.size)
			check(not hud_rect.intersects(screen),"actual minimap cannot hide comparison body " + stem)
	await capture(stem)

func run() -> void:
	out = OS.get_environment("TWILIGHT_PR100_REPORT")
	captures = OS.get_environment("TWILIGHT_PR100_CAPTURE_DIR")
	check(DisplayServer.get_name() != "headless", "style comparison requires actual rendered Main")
	check(OS.get_environment("TWILIGHT_PR100_BATCH_ISOLATED") == "1", "explicit isolated style invocation")
	check(preload("res://tests/qa_isolated_user_path.gd").contains_user_directory(OS.get_user_data_dir(),OS.get_environment("XDG_DATA_HOME"),OS.has_feature("windows")), "fresh platform user root")
	check(active_save_files().is_empty(), "no existing player saves")
	check(not out.is_empty() and not captures.is_empty() and not FileAccess.file_exists(out), "new evidence paths required")
	if not failures.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(captures)
	report = {"comparisons":[],"screenshots":[],"scope":"Actual Main side-by-side production MotionController inputs; visual comparison, not AI proof","production_changes":false}
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world,"기사"), "real class entry")
	world.hud._hide_aux_panels()
	world.save_timer = -10000.
	world._set_map("aden_world",false)
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	world.player.set_auto_enabled(false)
	center = find_clearing()
	check(center.is_finite(), "real map comparison clearing")
	for subject: String in ["알비노 이구아나","공포의 아그니"]:
		normal = db_actor(subject)
		var baseline: TwilightMonster = db_actor("지옥의 쿠거")
		check(normal != null and baseline != null,"real subject and completed Hell Cougar v3")
		if normal == null or baseline == null: continue
		var placed := false
		for radius: float in [0.,160.,320.,480.,800.,1120.,1600.,2400.]:
			for heading: int in range(8):
				var point := center + screen_direction(heading) * radius
				var left := point - Vector2(148,0)
				var right := point + Vector2(148,0)
				if not route_clear(left,0.) or not route_clear(right,0.): continue
				world.player.position = point + Vector2(0,160)
				world.player.camera.position = Vector2(0,-220)
				world.player.camera.zoom = Vector2(1.8,1.8)
				world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
				world.field_renderer.refresh_visible()
				normal.position = left; baseline.position = right
				var left_clear := review_body_clear(left)
				var subject_actor := normal
				normal = baseline
				var right_clear := review_body_clear(right)
				normal = subject_actor
				if left_clear and right_clear: placed = true; break
			if placed: break
		check(placed,"both actual bodies clear of props/other actors " + subject)
		if not placed: normal.queue_free(); baseline.queue_free(); await process_frame; continue
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var comparison := {"subject":subject,"baseline":"지옥의 쿠거","subject_frames":normal.motion.profile.frames_path,
			"baseline_frames":baseline.motion.profile.frames_path,"same_map_camera":true,"source_stats_unchanged":true,"samples":[]}
		for direction: int in range(8):
			for actor: TwilightMonster in [normal,baseline]:
				actor.motion.face(screen_direction(direction)); actor.motion.advance(.01,Vector2.ZERO)
				actor.motion.apply(actor.sprite,actor.animation_base_scale)
			var stem := str(report.comparisons.size()) + "-" + str(COMPASS[direction]) + "-idle"
			await comparison_capture(stem,baseline)
			comparison.samples.append({"path":captures.path_join(stem+".png"),"sha256":FileAccess.get_sha256(captures.path_join(stem+".png")),"direction":COMPASS[direction],"role":"idle"})
			if direction not in [0,2,4,6]: continue
			for step: int in range(96):
				for actor: TwilightMonster in [normal,baseline]:
					actor.motion.advance(1./120.,screen_direction(direction)*actor.motion.profile.reference_speed*.75)
					actor.motion.apply(actor.sprite,actor.animation_base_scale)
				if step not in [0,23,47,71,95]: continue
				stem = str(report.comparisons.size()) + "-" + str(COMPASS[direction]) + "-walk-" + str(step)
				await comparison_capture(stem,baseline)
				comparison.samples.append({"path":captures.path_join(stem+".png"),"sha256":FileAccess.get_sha256(captures.path_join(stem+".png")),"direction":COMPASS[direction],"role":"walk","simulation_seconds":float(step+1)/120.,"subject_key":normal.motion._resolved_key,"baseline_key":baseline.motion._resolved_key})
		report.comparisons.append(comparison)
		world.process_mode = Node.PROCESS_MODE_INHERIT
		normal.queue_free(); baseline.queue_free(); await process_frame
	report.checks = checks; report.failures = failures
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var file := FileAccess.open(out,FileAccess.WRITE)
	check(file != null,"comparison report writable")
	if file != null: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("REMAINING106_STYLE_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"report":out}))
	quit(0 if failures.is_empty() else 1)
