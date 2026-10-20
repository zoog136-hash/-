extends SceneTree
## Actual Main rendering of new unique RUN art. No full-actor PASS is possible.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const SOURCE := "res://assets/actors/eight_direction/hero_parallel/baphomet_unique/r001/"
const EVIDENCE := "res://docs/remake/pr122-hero-parallel/evidence/baphomet_unique-r001/"
var checks := 0
var failed := false

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("HERO_UNIQUE_RUN_FAIL " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(Engine.get_version_info().string.begins_with("4.7.2"), "engine")
	_check(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"), "isolated save")
	_check(DisplayServer.get_name() != "headless", "real OpenGL required")
	var world: Node = load("res://Main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	_check(CLASS_QA.enter_game(world), "real Main class confirmation")
	world.hud._close_workspace()
	var row: Dictionary = {}
	for item: Dictionary in world.catalog_db["변신"]:
		if str(item.sourceId) == "7": row = item
	_check(not row.is_empty() and row.grade == "영웅", "hero Baphomet id")
	var profile: Resource = CATALOG.for_record("transform", row, row.image_path)
	profile.frames_path = SOURCE + "RunSpriteFrames.tres"
	profile.movement_fps = 18.0
	world.player.set_transform_visual(row.image_path, 1.0, profile)
	var player: Node = world.player
	var sprite: AnimatedSprite2D = player.transform_sprite
	_check(sprite.is_visible_in_tree() and sprite.sprite_frames.resource_path == profile.frames_path, "real loaded resource, no portrait fallback")
	player.camera.make_current()
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	await process_frame
	var sheet := Image.create(960, 1280, false, Image.FORMAT_RGBA8)
	var rows: Array = []
	var count := 0
	for direction: int in range(8):
		var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
		player.motion.face(aim)
		var track := "run_" + str(direction)
		var seen: Dictionary = {}
		var unique: Dictionary = {}
		for tick: int in range(300):
			player.motion.advance(1.0 / 240.0, aim * profile.reference_speed)
			player.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
			if str(sprite.animation) != track or seen.has(sprite.frame): continue
			seen[sprite.frame] = true
			await process_frame
			await RenderingServer.frame_post_draw
			var screen := root.get_texture().get_image()
			var center: Vector2 = sprite.get_global_transform_with_canvas().origin
			_check(root.get_visible_rect().has_point(center), "actual actor inside Main viewport")
			var region := Rect2i(Vector2i(center) - Vector2i(80, 80), Vector2i(160, 160))
			var crop := screen.get_region(region)
			sheet.blit_rect(crop, Rect2i(0, 0, 160, 160), Vector2i(sprite.frame * 160, direction * 160))
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(crop.get_data())
			unique[digest.finish().hex_encode()] = true
			count += 1
		_check(seen.size() == 6 and unique.size() == 6, "six actual distinct visible run phases")
		rows.append({"direction": direction, "played": seen.size(), "distinct_main_roi": unique.size()})
	_check(count == 48, "48 actually rendered phases")
	_check(sheet.save_webp(EVIDENCE + "Main-run-only.webp", false) == OK, "lossless file capture")
	var report := {"schema": "hero-unique-run-only-main-v1", "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "status": "FAIL" if failed else "RUN_ONLY_TECHNICAL_PASS_QUALITY_HOLD", "checks": checks, "rendered_phases": count, "source_sha256": FileAccess.get_sha256(SOURCE + "source-run.png"), "frames_sha256": FileAccess.get_sha256(SOURCE + "RunSpriteFrames.tres"), "new_final_approvals": 0, "default_game_connections": 0, "missing_roles": ["idle", "attack", "hit", "death"], "identity_contact_camera_edge_quality": "HOLD", "directions": rows}
	var file := FileAccess.open(EVIDENCE + "Main-run-only.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	world.queue_free()
	await process_frame
	print("HERO_UNIQUE_RUN_%s phases=%d checks=%d full_actor_approvals=0" % ["FAIL" if failed else "TECHNICAL_PASS_QUALITY_HOLD", count, checks])
	quit(1 if failed else 0)
