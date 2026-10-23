extends SceneTree
## Real Main-scene regression for field attachment, follower offsets and settings.
## Run with a separate XDG_DATA_HOME; owned/awakened fixtures stay in that session.
const CORE = preload("res://scripts/cards/option_awakening_service.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const SAMPLES: Array = [["변신", "source:146"], ["마법인형", "source:145"], ["성물", "source:4014"]]
var world
var checks: int = 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var capture_dir: String = ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--option-field-capture="):
			capture_dir = argument.trim_prefix("--option-field-capture=")
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("OPTION_FIELD_FAIL: " + label)

func _sprite(category: String) -> Node2D:
	match category:
		"변신": return world.player.transform_sprite
		"마법인형": return world.companion_sprite
		_: return world.relic_sprite

func _settle_followers() -> void:
	# Advance the existing motion adapters, including their normal summon fade.
	for step: int in range(60): world._update_companion(1.0 / 60.0)
	for aura: Node2D in world.option_awakening_auras.values(): aura.call("sync_visual")

func _check_anchors(label: String) -> void:
	for sample: Array in SAMPLES:
		var category: String = sample[0]
		var sprite: Node2D = _sprite(category)
		var aura: Node2D = world.option_awakening_auras.get(category)
		check(is_instance_valid(aura), label + " attaches " + category)
		if not is_instance_valid(aura): continue
		aura.call("sync_visual")
		# Actual catalog sprites are centered. Their drawing center is offset,
		# which differs from the foot/root position, especially for relics.
		check(bool(sprite.get("centered")), label + " centered catalog art " + category)
		var art_offset: Vector2 = sprite.get("offset")
		var expected: Vector2 = sprite.to_global(art_offset)
		var actual: Vector2 = aura.to_global(aura.get("center"))
		check(actual.distance_to(expected) < 0.05, label + " follows art center " + category)
		var foot: Node2D = sprite if category == "성물" else sprite.get_parent()
		check(aura.global_position.distance_to(foot.global_position) < 0.05, label + " preserves foot sorting " + category)
		check(aura.visible and bool(aura.get("awakened")), label + " visible " + category)

func _capture(filename: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for frame: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = capture_dir.path_join(filename)
	check(image.get_size() == Vector2i(1280, 720), "full Main viewport " + filename)
	check(image.save_png(path) == OK, "capture " + filename)
	var attachments: Array[Dictionary] = []
	for category: String in CORE.CATEGORIES:
		var aura: Node2D = world.option_awakening_auras.get(category)
		if is_instance_valid(aura):
			attachments.append({"category":category, "visible":aura.visible, "foot":str(aura.global_position), "art_center":str(aura.to_global(aura.get("center"))), "radii":str(aura.get("radii"))})
	captures.append({"path":path, "width":image.get_width(), "height":image.get_height(), "auras":attachments})

func _capture_committed_result() -> void:
	var category: String = SAMPLES[0][0]
	var identity: String = SAMPLES[0][1]
	var runtime = world.option_awakening
	var snapshot: Dictionary = runtime.view(category, identity)
	world.gold = int(snapshot.attempt_cost) + 1000
	runtime.progress.cards[category][identity].experience = int(snapshot.required_experience)
	# Select a reproducible successful roll; only this isolated fixture owns it.
	var probe := RandomNumberGenerator.new()
	for seed_value: int in range(1, 1000):
		probe.seed = seed_value
		if probe.randi_range(0, 9999) < int(runtime.core.probabilities[category][snapshot.target_record.grade]):
			runtime.rng.seed = seed_value
			break
	world._on_option_awakening_attempt_requested(category, identity)
	var reveal: Control = world.hud.option_awakening_reveal
	check(is_instance_valid(reveal), "actual saved attempt opens Main result")
	if not is_instance_valid(reveal): return
	check(bool(reveal.get("result").get("ok", false)) and bool(reveal.get("succeeded")), "Main result receives committed success")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(bool(disk.get("card_option_awakening", {}).get("cards", {}).get(category, {}).get(identity, {}).get("awakened", false)), "result displayed after durable awakened state exists")
	check(reveal.get("result").get("bonus_lines", []) == runtime.core.definition(category, identity).applied_options, "result text matches this actual card's options")
	reveal.set("silent", true)
	reveal.set_process(false)
	reveal.call("seek", float(reveal.call("reveal_time")) + 0.16)
	await _capture("main_committed_awakening_success.png")
	reveal.call("skip_to_result")
	reveal.call("close_reveal")
	await process_frame
	world.hud._close_workspace()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.save_timer = -10000
	for frame: int in range(12): await process_frame
	check(CLASS_QA.enter_game(world), "normal starter-class confirmation")
	check(world.option_awakening.problem.is_empty(), "real awakening catalog configured")
	if not failures.is_empty():
		await _finish()
		return
	world.set_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children():
		monster.set_process(false)
		monster.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world.player.set_physics_process(false)
	world.hud._close_workspace()
	world.option_awakening.progress = CORE.fresh_state()
	world.apply_presentation_settings({"impact_intensity":0.85, "reduced_motion":false, "effect_detail":"full"})
	for sample: Array in SAMPLES:
		var category: String = sample[0]
		var identity: String = sample[1]
		var record: Dictionary = world.option_awakening.core.catalog[category].get(identity, {})
		check(not record.is_empty(), "actual catalog fixture " + category)
		world.card_draw_fusion.owned[category][identity] = true
		world.option_awakening.progress.cards[category][identity] = {"experience":0, "awakened":false, "attempts":0, "failures":0}
		world._equip_catalog(category, record)
	_settle_followers()
	var any_aura: bool = false
	for aura: Node2D in world.option_awakening_auras.values():
		any_aura = any_aura or aura.visible or bool(aura.get("awakened"))
	check(not any_aura, "unawakened equipped cards have no added aura")
	await _capture("field_before_awakening.png")
	await _capture_committed_result()
	if not failures.is_empty():
		await _finish()
		return
	for sample: Array in SAMPLES:
		world.option_awakening.progress.cards[sample[0]][sample[1]].awakened = true
		world.option_awakening.progress.cards[sample[0]][sample[1]].attempts = 1
	world.option_awakening.progress.revision += 1
	world._sync_option_awakening_auras()
	_settle_followers()
	_check_anchors("equipped")
	await _capture("field_all_awakened.png")

	# Exercise actual player movement and existing follower update methods.
	var before: Vector2 = world.player.global_position
	world.player.set_physics_process(true)
	Input.action_press("move_right")
	for frame: int in range(18): await physics_frame
	Input.action_release("move_right")
	await physics_frame
	world.player.set_physics_process(false)
	check(world.player.global_position.distance_to(before) > 1.0, "normal movement changes player position")
	_settle_followers()
	_check_anchors("after movement and float")
	await _capture("field_after_movement.png")

	world.apply_presentation_settings({"impact_intensity":0.25, "reduced_motion":true, "effect_detail":"low"})
	var clocks: Dictionary = {}
	for category: String in CORE.CATEGORIES:
		var aura: Node2D = world.option_awakening_auras[category]
		clocks[category] = aura.get("clock")
		check(bool(aura.get("reduced_motion")) and bool(aura.get("low_detail")) and is_equal_approx(float(aura.get("intensity")), 0.25), "world settings reach " + category)
	for frame: int in range(6): await process_frame
	for category: String in CORE.CATEGORIES:
		check(is_equal_approx(float(world.option_awakening_auras[category].get("clock")), float(clocks[category])), "reduced motion freezes aura " + category)
	await _capture("field_reduced_motion.png")
	world.apply_presentation_settings({"impact_intensity":0.0})
	await process_frame
	await process_frame
	for category: String in CORE.CATEGORIES:
		check(not world.option_awakening_auras[category].visible, "zero intensity hides " + category)
	world.apply_presentation_settings({"impact_intensity":0.85, "reduced_motion":false, "effect_detail":"full"})
	for category: String in CORE.CATEGORIES:
		world._equip_catalog(category, {})
		var aura: Node2D = world.option_awakening_auras[category]
		check(not aura.visible and not bool(aura.get("awakened")), "unequip immediately removes " + category)
	_settle_followers()
	await _capture("field_unequipped.png")
	await _finish()

func _finish() -> void:
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		var report: FileAccess = FileAccess.open(capture_dir.path_join("field-results.json"), FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"checks":checks, "failures":failures, "renderer":RenderingServer.get_video_adapter_name(), "method":RenderingServer.get_current_rendering_method(), "captures":captures}, "\t"))
			report.close()
	if is_instance_valid(world): world.queue_free()
	await process_frame
	print("OPTION_AWAKENING_FIELD: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
