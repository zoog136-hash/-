extends SceneTree
## Draw every catalog identity through the existing game's equip APIs and GL.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
var records: Array[Dictionary] = []
var failures: Array[String] = []
var directory: String = "user://full-catalog-render"

func _initialize() -> void: call_deferred("_run")

func _save() -> void:
	var file := FileAccess.open(directory + "/render.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"records": records, "failures": failures,
		"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(),
		"method": "production Main.tscn equip APIs; two distinct authored frames drawn in GL per identity",
		"manual_animation_review": false, "all_states_rendered": false}, "\t") + "\n")

func _draw_pose(node: Node2D, name_value: String) -> String:
	await RenderingServer.frame_post_draw
	var screen: Image = root.get_texture().get_image()
	var center := Vector2i(node.get_global_transform_with_canvas().origin)
	var rect := Rect2i(center - Vector2i(100, 120), Vector2i(200, 240))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, screen.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		failures.append("offscreen identity " + name_value)
		return ""
	var crop: Image = screen.get_region(rect)
	if crop.save_png(directory + "/" + name_value + ".png") != OK:
		failures.append("capture failed " + name_value)
		return ""
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(crop.get_data())
	return hash.finish().hex_encode()

func _frame_value(node: Node2D, cell_width: int) -> int:
	if node is AnimatedSprite2D: return (node as AnimatedSprite2D).frame
	var texture: Texture2D = (node as Sprite2D).texture
	if texture is AtlasTexture: return int((texture as AtlasTexture).region.position.x / maxf(1.0, cell_width))
	return -1

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	if not CLASS_QA.enter_game(world):
		push_error("Full catalog class entry failed")
		quit(1)
		return
	world._set_map("aden_world", false)
	world.save_timer = -10000
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world.field_population.set_process(false)
	for monster: TwilightMonster in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.monsters_root.hide()
	world.hud._close_workspace()
	world.hud.hide()
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550, 4300)))
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	for i: int in range(3): await process_frame
	for category: String in ["변신", "마법인형", "성물"]:
		world._apply_transform_visual({})
		world._apply_doll_visual({})
		world._apply_relic_visual({})
		for i: int in range(30): world._update_companion(.05)
		var kind: String = "transform" if category == "변신" else ("doll" if category == "마법인형" else "relic")
		for record: Dictionary in world.catalog_db[category]:
			var before: int = failures.size()
			var key: String = kind + ":" + str(record.sourceId)
			world._equip_catalog(category, record)
			for i: int in range(20): world._update_companion(.05)
			var node: Node2D = world.player.transform_sprite if kind == "transform" else (world.companion_sprite if kind == "doll" else world.relic_sprite)
			var motion: TwilightActorMotion = world.player.motion if kind == "transform" else (world.doll_motion.motion if kind == "doll" else world.relic_motion.motion)
			var frames: SpriteFrames = (node as AnimatedSprite2D).sprite_frames if node is AnimatedSprite2D else motion.frame_source
			if frames == null or str(frames.get_meta("twilight_visual_key", "")) != key or not node.visible:
				failures.append("wrong or missing equipped atlas " + key)
				continue
			motion.cancel_attack()
			motion.face(Vector2.DOWN)
			motion.advance(0.0, Vector2.DOWN * 120.0 if kind != "relic" else Vector2.ZERO)
			var hashes: Array[String] = []
			var frame_values: Array[int] = []
			for phase: int in range(2):
				motion.gait = 2.0 * phase
				motion.state_clock = .28 * phase
				if kind == "relic":
					motion.state = "float"
					motion.apply_frames(node)
				else:
					var scale_value: Vector2 = world.player.transform_sprite.get_meta("base_scale") if kind == "transform" else world.doll_motion.base_scale
					motion.apply(node, scale_value)
				frame_values.append(_frame_value(node, int(VISUALS.record(key).cell[0])))
				hashes.append(await _draw_pose(node, kind + "-" + str(record.sourceId) + "-" + str(phase)))
			if hashes[0].is_empty() or hashes[0] == hashes[1]: failures.append("rendered frames did not change " + key)
			if frame_values[0] == frame_values[1]: failures.append("authored frame did not advance " + key)
			records.append({"key":key, "name":record.name, "pixel_sha256":hashes, "frames":frame_values,
				"views_available":VISUALS.record(key).get("directions", 1), "drawn_frames":2, "passed":before == failures.size()})
			if records.size()%25 == 0:
				_save()
				print("FULL_CATALOG_RENDER_PROGRESS ",records.size())
	_save()
	print("FULL_CATALOG_RENDER_OK " if failures.is_empty() else "FULL_CATALOG_RENDER_FAIL ",
		"drawn_identities=", records.size(), " failures=", failures.size(), " evidence=", ProjectSettings.globalize_path(directory))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
