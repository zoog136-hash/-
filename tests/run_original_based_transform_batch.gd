extends "res://tests/original_based_reaper_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_BATCH_CAPTURE_DIR
# Fresh production Main per transform; inherited gameplay assertions are unchanged.
# Use 10-20 subjects normally; 1-9 cases remain available for cautious retries.
const MAX_CASES = 20
const CASE_ENV = ["TWILIGHT_ORIGINAL_POSE_CAPTURE", "TWILIGHT_PR100_REPORT", "TWILIGHT_PR100_CAPTURE_DIR"]
var current_case: Dictionary = {}
var batch_results: Array[Dictionary] = []
var batch_failures: Array[String] = []
var batch_checks: int = 0
var batch_report_path: String
var batch_config_path: String
var previous_environment: Dictionary = {}
var batch_metadata: Dictionary = {}

func subject_path() -> String:
	return "res://assets/actors/eight_direction/original_based/" + str(current_case.folder) + "/SpriteFrames.tres"

func subject_spec() -> Dictionary: return current_case.spec.duplicate(true)

func lifecycle_attempt_limit() -> int: return 200

func find_clearing() -> Vector2:
	var initial: Vector2 = super.find_clearing()
	if not initial.is_finite(): return initial
	# Keep untouched terrain and paused background actors out of the portrait
	# sampling area by selecting an empty real walkable part of the same map.
	# The production map is 48,000 x 25,120 world pixels. The original 720px
	# search stayed inside a dense spawn cluster; inspect farther real terrain.
	for radius: float in [0., 240., 320., 400., 560., 720., 960., 1280., 1600., 2000., 2400., 3200.]:
		for direction: int in range(8):
			var point: Vector2 = initial + screen_direction(direction) * radius
			if not route_clear(point, 150.): continue
			var occupied := false
			for actor: Node in world.monsters_root.get_children():
				if actor is Node2D and (actor as Node2D).visible and (actor as Node2D).position.distance_to(point) < 192.:
					occupied = true
					break
			if occupied: continue
			world.player.position = point
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			# Walking clearance alone does not rule out tall foreground art.
			# Inspect the same streamed prop rectangles as the monster pose QA.
			var body := Rect2(point + Vector2(-128, -160), Vector2(256, 176))
			for prop: Node2D in world.field_renderer.faded:
				if prop is Sprite2D and prop.global_position.y + 16.0 > point.y:
					var bounds: Rect2 = prop.global_transform * (prop as Sprite2D).get_rect()
					if bounds.intersects(body):
						occupied = true
						break
			if not occupied:
				report.qa_clearing = {"initial": [initial.x, initial.y], "position": [point.x, point.y],
					"search_radius": radius, "walkable_radius": 150.0,
					"other_actors_hidden": false, "terrain_hidden_or_modified": false}
				return point
	return Vector2.INF

func incoming_and_death() -> void:
	await super.incoming_and_death()
	world.player.position = center
	world.player.camera.zoom = Vector2(1.6, 1.6)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	await monster_case()
	# Use the same deterministic production drop-seed setup as the existing
	# original-based monster test. Keep the real drop table and award handlers.
	var probe := RandomNumberGenerator.new()
	var drop_seed := 1
	while drop_seed < 1000:
		probe.seed = drop_seed
		if not world.LOOT_DROP.roll_detailed(normal.drop_items, normal.is_boss, world.loot_catalog, probe, normal.monster_name).is_empty(): break
		drop_seed += 1
	check(drop_seed < 1000, "real production drop seed found")
	report.setup.drop_rng_seed = drop_seed
	normal.died.disconnect(world._on_monster_died)
	normal.died.connect(func(_actor: TwilightMonster) -> void: world.rng.seed = drop_seed)
	normal.died.connect(world._on_monster_died)
	await lifecycle_case()
	check(world.player.transform_active and world.player.motion.profile.profile_id == "transform:" + str(current_case.spec.transform_id), "AI and manual pickup retain the exact equipped transformation")
	report.setup.additional_cases = "existing production field-monster AI in8directions,real weapon kill,floor drop,manual UI pickup"
	report.setup.ai_camera_zoom = 1.6

func safe_component(value: String) -> bool:
	if value.is_empty(): return false
	for letter: String in value:
		if not letter in "abcdefghijklmnopqrstuvwxyz0123456789_-": return false
	return true

func validate_cases(config: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not config is Dictionary or not config.get("cases") is Array or config.cases.is_empty() or config.cases.size() > MAX_CASES:
		errors.append("Transform batch configuration must contain 1 to 20 cases")
		return errors
	var slugs: Dictionary = {}
	var identities: Dictionary = {}
	var held_identities: Dictionary = {}
	var held: Variant = config.get("held", [])
	if not held is Array:
		errors.append("Quality-HOLD metadata must be an array")
		return errors
	for value: Variant in held:
		if not value is Dictionary or str(value.get("transform_id", "")).is_empty():
			errors.append("Each Quality-HOLD record needs a transform source ID")
			continue
		held_identities[str(value.transform_id)] = true
	for value: Variant in config.cases:
		if not value is Dictionary or str(value.get("name", "")).is_empty() or not safe_component(str(value.get("folder", ""))) or not safe_component(str(value.get("slug", ""))):
			errors.append("Each transform case needs a name and safe folder/slug")
			continue
		var spec: Variant = value.get("spec")
		if not spec is Dictionary:
			errors.append(str(value.slug) + ": missing production class/equipment specification")
			continue
		for key: String in ["job", "transform_id", "name", "type", "style"]:
			if not spec.get(key) is String or str(spec.get(key, "")).is_empty():
				errors.append(str(value.slug) + ": missing string specification " + key)
		if not str(spec.get("transform_id", "")).is_valid_int():
			errors.append(str(value.slug) + ": transform_id must be a catalog source ID")
		if not (spec.get("appearance") is int or spec.get("appearance") is float) or not is_equal_approx(float(spec.get("appearance", -1)), float(int(spec.get("appearance", -1)))) or int(spec.get("appearance", -1)) < 0 or int(spec.get("appearance", -1)) > 3:
			errors.append(str(value.slug) + ": appearance must be an integer from 0 to 3")
		if not spec.get("magic") is bool:
			errors.append(str(value.slug) + ": magic must be a boolean")
		if value.has("unobstructed_pose_review") and not value.unobstructed_pose_review is bool:
			errors.append(str(value.slug) + ": unobstructed_pose_review must be a boolean")
		if slugs.has(value.slug): errors.append("Duplicate case slug: " + str(value.slug))
		slugs[value.slug] = true
		var identity := str(spec.get("transform_id", ""))
		if held_identities.has(identity): errors.append("Quality-HOLD transform must not enter the batch: " + identity)
		if identities.has(identity): errors.append("Duplicate transform source ID: " + identity)
		identities[identity] = true
	return errors

func active_save_files() -> Array[String]:
	var found: Array[String] = []
	var directory := DirAccess.open("user://")
	if directory == null:
		batch_failures.append("Cannot inspect the user directory for existing saves")
		return found
	for name_value: String in directory.get_files():
		if name_value.begins_with("twilight_") and name_value.contains("_save"): found.append(name_value)
	return found

func preserve_case_saves(slug: String) -> Array[String]:
	var preserved: Array[String] = []
	var files := active_save_files()
	if files.is_empty(): return preserved
	var destination := "user://pr100-transform-batch-preserved/" + slug
	# Validate every source and destination before moving any generated save.
	for name_value: String in files:
		if not name_value.begins_with("twilight_v20_save.json"):
			batch_failures.append(slug + ": unexpected save file; leave it in place: " + name_value)
			return preserved
		var target := destination.path_join(name_value)
		if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
			batch_failures.append(slug + ": existing preserved save would be overwritten: " + target)
			return preserved
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		batch_failures.append(slug + ": cannot create the save preservation directory")
		return preserved
	for name_value: String in files:
		var target := destination.path_join(name_value)
		var error := DirAccess.rename_absolute("user://" + name_value, target)
		if error != OK:
			batch_failures.append(slug + ": cannot preserve save: " + name_value + " (" + str(error) + ")")
			return preserved
		preserved.append(target)
	return preserved

func reset_case_state() -> void:
	release_inputs()
	if physics_frame.is_connected(trace_flights): physics_frame.disconnect(trace_flights)
	world = null
	normal = null
	center = Vector2.INF
	failures.clear()
	checks = 0
	ticks_elapsed = 0
	strikes.clear()
	monster_strikes.clear()
	flight_observations.clear()
	report = {"player": [], "staff_normal": [], "monster": [], "boss": [], "lifecycle": {}, "screenshots": []}
	out = ""
	captures = ""

func inspect_poses() -> void:
	if current_case.get("unobstructed_pose_review", false) and not captures.is_empty():
		check(position_visible_pose_review(), "whole original spear has unobstructed Main review")
	await super.inspect_poses()

func position_visible_pose_review() -> bool:
	# Same production-terrain placement used by the existing Pan regression.
	var original_center: Vector2 = center
	for radius: float in [0.0, 80.0, 160.0, 240.0, 320.0]:
		for direction: int in [4, 3, 5, 2, 6, 0, 1, 7]:
			var point: Vector2 = original_center + screen_direction(direction) * radius
			if not route_clear(point, 0.0): continue
			world.player.position = point
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			var body := Rect2(point + Vector2(-128, -160), Vector2(256, 176))
			var covered: bool = false
			for prop: Node2D in world.field_renderer.faded:
				if prop is Sprite2D and prop.global_position.y + 16.0 > point.y:
					if (prop.global_transform * (prop as Sprite2D).get_rect()).intersects(body):
						covered = true
						break
			if not covered:
				center = point
				report.setup.pose_review = {"offset": [point.x - original_center.x, point.y - original_center.y],
					"walkable": true, "foreground_clear": true, "terrain_hidden_or_modified": false}
				return true
	world.player.position = original_center
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	return false

func finish_batch() -> void:
	for key: String in previous_environment:
		var saved: Dictionary = previous_environment[key]
		if saved.present: OS.set_environment(key, str(saved.value))
		else: OS.unset_environment(key)
	DirAccess.make_dir_recursive_absolute(batch_report_path.get_base_dir())
	if FileAccess.file_exists(batch_report_path):
		batch_failures.append("Existing batch report retained: " + batch_report_path)
		batch_report_path += ".refused-" + str(Time.get_ticks_usec()) + ".json"
	var summary := {"config": batch_config_path, "engine_processes": 1, "process_id": OS.get_process_id(),
		"scene_per_case": "Main.tscn", "user_directory": OS.get_user_data_dir(),
		"metadata": batch_metadata, "checks": batch_checks, "cases": batch_results, "failures": batch_failures}
	var file := FileAccess.open(batch_report_path, FileAccess.WRITE)
	if file == null: batch_failures.append("Cannot write transform batch evidence: " + batch_report_path)
	else:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()
	print("PR100_TRANSFORM_BATCH_RESULT " + JSON.stringify({"cases": batch_results.size(), "checks": batch_checks,
		"failure_count": batch_failures.size(), "failures": batch_failures, "report": batch_report_path}))
	if batch_failures.is_empty(): print("PR100_TRANSFORM_BATCH_OK")
	quit(0 if batch_failures.is_empty() else 1)

func run() -> void:
	quit_on_finish = false
	batch_report_path = OS.get_environment("TWILIGHT_PR100_BATCH_REPORT")
	if batch_report_path.is_empty(): batch_report_path = "user://pr100-transform-batch.json"
	batch_config_path = OS.get_environment("TWILIGHT_PR100_BATCH_CONFIG")
	if batch_config_path.is_empty(): batch_config_path = "res://tests/fixtures/pr100_transform_regression.json"
	if OS.get_environment("TWILIGHT_PR100_BATCH_ISOLATED") != "1":
		batch_failures.append("Use an isolated user directory and set TWILIGHT_PR100_BATCH_ISOLATED=1")
	var existing_saves := active_save_files()
	if not existing_saves.is_empty():
		batch_failures.append("Existing user saves must remain untouched; transform batch refused")
	if FileAccess.file_exists(batch_report_path): batch_failures.append("Use a fresh batch evidence path")
	if not batch_failures.is_empty(): finish_batch(); return
	var parser := JSON.new()
	if not FileAccess.file_exists(batch_config_path) or parser.parse(FileAccess.get_file_as_string(batch_config_path)) != OK:
		batch_failures.append("Cannot read valid transform batch configuration: " + batch_config_path)
		finish_batch(); return
	var config: Variant = parser.data
	batch_failures.append_array(validate_cases(config))
	if not batch_failures.is_empty(): finish_batch(); return
	for key: String in ["batch", "kind", "scope", "source_fixture", "held"]:
		if config.has(key): batch_metadata[key] = config[key]
	for spec: Dictionary in config.cases:
		if DirAccess.dir_exists_absolute("user://pr100-transform-batch-preserved/" + str(spec.slug)):
			batch_failures.append("Existing preserved case saves require a fresh isolated user directory: " + str(spec.slug))
		if not ResourceLoader.exists("res://assets/actors/eight_direction/original_based/" + str(spec.folder) + "/SpriteFrames.tres"):
			batch_failures.append("Missing case artwork: " + str(spec.folder))
	var capture_root := OS.get_environment("TWILIGHT_PR100_BATCH_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless":
		if not capture_root.is_empty(): batch_failures.append("Batch screenshots require a rendered viewport")
	elif capture_root.is_empty(): capture_root = "user://pr100-transform-batch-captures"
	if not batch_failures.is_empty(): finish_batch(); return
	for key: String in CASE_ENV:
		previous_environment[key] = {"present": OS.has_environment(key), "value": OS.get_environment(key)}
	var sampled_folders: Dictionary = {}
	for spec: Dictionary in config.cases:
		reset_case_state()
		current_case = spec
		var first_resource_case: bool = not sampled_folders.has(spec.folder)
		OS.set_environment("TWILIGHT_ORIGINAL_POSE_CAPTURE", "1" if first_resource_case else "0")
		OS.set_environment("TWILIGHT_PR100_REPORT", (batch_report_path.get_basename() + "-cases").path_join(str(spec.slug) + ".json"))
		OS.set_environment("TWILIGHT_PR100_CAPTURE_DIR", capture_root.path_join(str(spec.slug)) if not capture_root.is_empty() else "")
		await super.run()
		batch_checks += checks
		for failure: String in failures: batch_failures.append(str(spec.slug) + ": " + failure)
		var result := {"name": spec.name, "folder": spec.folder, "slug": spec.slug, "transform_id": spec.spec.transform_id,
			"checks": checks, "failures": failures.duplicate(), "physics_ticks": ticks_elapsed, "report": out,
			"player_directions": report.player.size(), "incoming_directions": report.get("incoming", []).size(),
			"monster_directions": report.monster.size(), "lifecycle": report.lifecycle.duplicate(true),
			"pose_samples": report.get("pose_samples", []).size(), "full_pose_capture": first_resource_case and not capture_root.is_empty(),
			"screenshots": report.screenshots.size()}
		var before_preservation: int = batch_failures.size()
		result.preserved_saves = preserve_case_saves(str(spec.slug))
		batch_results.append(result)
		sampled_folders[spec.folder] = true
		if batch_failures.size() > before_preservation: break
	finish_batch()
