extends SceneTree

const Store = preload("res://scripts/resources/private_catalog_motion.gd")
const Visual = preload("res://scripts/animation/visual_manifest.gd")
const Catalog = preload("res://scripts/animation/animation_catalog.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("PRIVATE_CATALOG_MAIN_FAIL: ", label)

func _initialize() -> void:
	var isolated := OS.get_environment("TWILIGHT_PRIVATE_TEST_ROOT")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").simplify_path().begins_with(isolated.simplify_path() + "/"):
		push_error("Run via ci_core.py --catalog-pack with disposable user data")
		quit(1)
		return
	call_deferred("run")

func boot() -> void:
	check(change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene"))) == OK, "production default scene starts")
	await process_frame
	await process_frame

func wait_for_main() -> TwilightWorld:
	for frame: int in range(150):
		await process_frame
		if current_scene is TwilightWorld:
			return current_scene as TwilightWorld
	return null

func external_frames(frames: SpriteFrames, key: String) -> bool:
	if frames == null or str(frames.get_meta("twilight_visual_key", "")) != key: return false
	var names := frames.get_animation_names()
	if names.is_empty(): return false
	var texture := frames.get_frame_texture(names[0], 0) as AtlasTexture
	return texture != null and texture.atlas is ImageTexture and not texture.atlas.get_image().is_empty()

func run() -> void:
	check(str(ProjectSettings.get_setting("application/run/main_scene")) == "res://CatalogPackSetup.tscn", "default startup uses real setup")
	check(not Store.embedded_complete() and Store.active_root().is_empty(), "no embedded or installed catalog")
	for relative: String in Store.index_data().files:
		check(not FileAccess.file_exists("res://" + relative), "embedded atlas absent: " + relative)
	await boot()
	check(current_scene != null and current_scene.get_script() == load("res://scripts/resources/catalog_pack_setup.gd"), "first run stays on setup")
	var setup := current_scene as Control
	check(not bool(setup._busy) and setup._status.text.contains("설치해"), "missing pack has usable install guidance")
	check(not FileAccess.file_exists("user://twilight_v20_save.json"), "first run creates no player save")
	var args := OS.get_cmdline_user_args()
	check(args.size() == 1, "explicit delivered ZIP")
	if args.size() != 1: quit(1); return
	await setup._selected(args[0])
	var world := await wait_for_main()
	check(world != null, "installer hands off to actual Main World")
	if world == null: quit(1); return
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual class selection after install")
	world.player.set_physics_process(false)
	check(world.active_map_id == "aden_world" and world.field_map != null, "actual current map connected")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Visual.PATH))
	for kind: String in ["transform", "doll", "relic"]:
		var tested := false
		for key: String in manifest.catalog:
			if not key.begins_with(kind + ":"): continue
			var record := {"sourceId":key.trim_prefix(kind + ":"), "name":key, "image_path":manifest.catalog[key].source}
			var profile := Catalog.for_record(kind, record, record.image_path)
			if profile.frames_path != str(manifest.catalog[key].atlas): continue
			match kind:
				"transform":
					world._apply_transform_visual(record)
					check(world.player.transform_active and external_frames(world.player.transform_sprite.sprite_frames, key), "World transform uses external pixels and profile")
				"doll":
					world._apply_doll_visual(record)
					check(world.doll_motion.enabled and external_frames(world.companion_sprite.sprite_frames, key), "World doll uses external pixels and profile")
				"relic":
					world._apply_relic_visual(record)
					check(world.relic_motion.enabled and external_frames(world.relic_motion.motion.frame_source, key), "World relic uses external pixels and profile")
			tested = true
			break
		check(tested, "real compatibility consumer exercised: " + kind)
	# The native identity must still take its pre-catalog profile return.
	var native := Catalog.for_record("transform", {"sourceId":"m508:missing", "source":"lineagem_base508"})
	check(native.frames_path.is_empty() and native.pixel_scale == 1.0 and native.embedded_shadow, "native profile priority preserved; native pixels not claimed")
	world.gold = 8765432
	check(world._save_game(true) == OK, "real World save after external install")
	var save_path: String = world.save_path()
	var save_sha := FileAccess.get_sha256(save_path)
	await boot()
	world = await wait_for_main()
	check(world != null, "verified installed pack restarts actual Main")
	if world == null: quit(1); return
	world.set_process(false)
	world.save_timer = -100000.0
	world.player.set_physics_process(false)
	check(FileAccess.get_sha256(save_path) == save_sha and world.gold == 8765432, "startup preserves save bytes and loads gold")
	var relative := str(Store.index_data().files.keys()[0])
	var path := Store.active_root().path_join(relative)
	var original := FileAccess.get_file_as_bytes(path)
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_string("damaged"); writer.close()
	await boot()
	for frame: int in range(60): await process_frame
	check(not current_scene is TwilightWorld and current_scene._status.text.contains("손상"), "damaged installed pack blocks Main")
	check(FileAccess.get_sha256(save_path) == save_sha, "blocked startup preserves real save bytes")
	writer = FileAccess.open(path, FileAccess.WRITE)
	writer.store_buffer(original); writer.close()
	print("PRIVATE_CATALOG_MAIN_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_DEFAULT_SETUP_MAIN_WORLD_EXTERNAL_COMPAT_SAVE; NOT_NATIVE_M_RENDER_OR_DEVICE"}))
	quit(0 if failures.is_empty() else 1)
