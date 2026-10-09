extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://docs/skills/previews/" + name + ".png"
	if image.save_png(path) != OK:
		push_error("Cannot preserve rendered preview: " + path)
		quit(1)
		return
	print("RENDER_CAPTURE ",name," size=",image.get_size())

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Real GL rendering required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://docs/skills/previews")
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	if not QA.enter_game(world): quit(1); return
	world.save_timer = -100000
	world.self_mode_enabled = false
	world.player.set_auto_enabled(false)
	for entry: Dictionary in world.quickslots: entry["auto"] = false
	world.level = 90
	world.gold = 10000000
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3300,4370)))
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	world.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.equipped_items["weapon"] = {"name":"검사 양손검","type":"양손검","slot":"weapon"}
	var catalog := world.original_skills.catalog
	for skill: Dictionary in catalog.records:
		if skill.classes.has("기사"):
			catalog.learned[str(skill.id)] = 1
	world._update_hud()
	world.hud.open_skills()
	for _frame: int in range(12): await process_frame
	var view: Node = world.hud.skills_view
	for index: int in range(view.filtered.size()):
		if str(view.filtered[index].name)=="카운터 배리어": view.cards.select(index);view.select(index)
	await capture("01-knight-catalog")
	view.preview_button.pressed.emit()
	for _frame: int in range(3): await process_frame
	await capture("02-skill-preview")
	world.hud._close_workspace()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	if not world._cast_job_skill("카운터 배리어"):
		push_error("Counter aura capture requires a successful cast")
		quit(1)
		return
	for _frame: int in range(4): await process_frame
	await capture("03-counter-aura")
	var samples: Array[float] = []
	for frame: int in range(60):
		var start := Time.get_ticks_usec()
		world.original_skills.vfx.emit_skill(str(catalog.records[frame%catalog.records.size()].id),"impact",world.player.global_position + Vector2(frame%8*14-56,0))
		await process_frame
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	await capture("04-effect-crowd")
	samples.sort()
	print("ORIGINAL_RENDER_OK driver=",RenderingServer.get_video_adapter_name()," median_ms=",samples[30]," p95_ms=",samples[57]," active=",world.original_skills.vfx.live.size()," available=",world.original_skills.vfx.available.size())
	world.queue_free()
	await process_frame
	quit()
