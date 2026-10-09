extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")

## Rendered engine QA. Diagnostic hit/critical poses are separate from live AUTO.
var failed: bool = false
var captures: int = 0
const OUTPUT = "user://combat-review"

func _initialize() -> void: call_deferred("_run")

func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	if pixels == null or pixels.is_empty() or pixels.save_png(OUTPUT + "/" + name_value + ".png") != OK:
		failed = true
		push_error("Combat capture missing " + name_value)
	else:
		captures += 1
		print("COMBAT_CAPTURE ", name_value)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	if not CLASS_QA.enter_game(world):
		push_error("Rendered gameplay class confirmation failed")
		quit(1)
		return
	world.save_timer = -10000
	world.rng.seed = 20261008
	world._set_map("aden_world", false)
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550, 4300)))
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	world.set_process(false)
	world.field_population.set_process(false)
	for mob: TwilightMonster in world.monsters_root.get_children(): mob.set_physics_process(false)
	for i: int in range(12): await process_frame
	world._apply_doll_visual(world.catalog_db["마법인형"][0])
	world._apply_relic_visual(world.catalog_db["성물"][0])
	for i: int in range(30):
		world._update_companion(1.0 / 60.0)
		await process_frame
	await capture("01-base-companions")
	var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(mob)
	var record: Dictionary = {"name":"모션 검증 오우거", "hp":999999, "atk":1, "ac":0}
	mob.setup(record, world.player, world, world._monster_texture(record))
	mob.position = world.player.position + Vector2(70, 15)
	mob.set_physics_process(false)
	for pair: Array in [["slash", "02-slash-hit"], ["heavy", "03-heavy-critical"], ["magic", "04-magic-hit"]]:
		world.player.start_combat_attack(mob.position, 0.7, pair[0])
		world.player.set_physics_process(false)
		world.player.motion.advance(0.32, Vector2.ZERO)
		world.player.motion.apply(world.player.class_sprite, Vector2.ONE)
		world.feedback_style = pair[0]
		mob.take_damage(132, pair[0] == "heavy")
		mob.motion.apply(mob.sprite, mob.animation_base_scale)
		await capture(pair[1])
		world.combat_vfx.clear()
	for id: String in ["43", "393"]:
		for form: Dictionary in world.catalog_db["변신"]:
			if str(form.get("sourceId", "")) != id: continue
			world._apply_transform_visual(form)
			world.player.motion.advance(0.1, Vector2(220, 80))
			world.player.motion.apply(world.player.transform_sprite, world.player.transform_sprite.get_meta("base_scale"))
			await capture("05-transform-" + id)
			break
	mob.take_damage(mob.hp)
	mob.motion.advance(0.24, Vector2.ZERO)
	mob.motion.apply(mob.sprite, mob.animation_base_scale)
	await capture("06-monster-death")
	world.player.clear_transform_visual()
	world.player.cancel_attack()
	world.player.set_physics_process(true)
	world.field_population.set_process(true)
	world.set_process(true)
	world.hp = world._effective_max_hp()
	world.player.set_auto_enabled(true)
	var samples: Array[float] = []
	var peak_nodes: int = 0
	var peak_orphans: int = 0
	var start_xp: int = world.experience
	var start_position: Vector2 = world.player.position
	for i: int in range(360):
		var start: int = Time.get_ticks_usec()
		await process_frame
		if i >= 60: samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
		peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_orphans = maxi(peak_orphans, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
		if i in [120, 240, 359]: await capture("07-auto-" + str(i))
	samples.sort()
	var report: Dictionary = {"adapter":RenderingServer.get_video_adapter_name(), "frames":samples.size(),
		"median_ms":samples[samples.size() / 2], "p95_ms":samples[int(samples.size() * 0.95)],
		"peak_nodes":peak_nodes, "peak_orphans":peak_orphans, "vfx_high_water":world.combat_vfx.high_water,
		"movement":world.player.position.distance_to(start_position), "xp_delta":world.experience - start_xp,
		"captures":captures, "note":"Linux software GL diagnostic poses and live AUTO; not a hardware FPS guarantee."}
	var file: FileAccess = FileAccess.open(OUTPUT + "/performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if captures != 10: failed = true
	print("COMBAT_RENDER ", JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
