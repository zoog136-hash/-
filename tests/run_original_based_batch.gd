extends "res://tests/original_based_succubus_gameplay_test.gd"

# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_BATCH_CAPTURE_DIR
# One engine process, fresh production Main per subject, unchanged gameplay checks.
# Requires an isolated user directory and TWILIGHT_PR100_BATCH_ISOLATED=1.
const CASE_ENV = ["TWILIGHT_ORIGINAL_SUBJECT", "TWILIGHT_ORIGINAL_POSE_CAPTURE",
	"TWILIGHT_PR100_REPORT", "TWILIGHT_PR100_CAPTURE_DIR"]
var current_case: Dictionary = {}
var batch_results: Array[Dictionary] = []
var batch_failures: Array[String] = []
var batch_checks: int = 0
var batch_report_path: String
var batch_config_path: String
var previous_environment: Dictionary = {}

func subject_name() -> String: return str(current_case.name)
func subject_folder() -> String: return str(current_case.folder)

func safe_component(value: String) -> bool:
	if value.is_empty(): return false
	for letter: String in value:
		if not letter in "abcdefghijklmnopqrstuvwxyz0123456789_-": return false
	return true

func active_save_files() -> Array[String]:
	var found: Array[String] = []
	var directory := DirAccess.open("user://")
	if directory == null:
		batch_failures.append("Cannot inspect the user directory for existing saves")
		return found
	for name_value: String in directory.get_files():
		if name_value.begins_with("twilight_") and name_value.contains("_save"):
			found.append(name_value)
	return found

func preserve_case_saves(slug: String) -> Array[String]:
	var preserved: Array[String] = []
	var files := active_save_files()
	if files.is_empty(): return preserved
	var destination := "user://pr100-batch-preserved/" + slug
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		batch_failures.append(slug + ": cannot create the save preservation directory")
		return preserved
	for name_value: String in files:
		if not name_value.begins_with("twilight_v20_save.json"):
			batch_failures.append(slug + ": unexpected save file; leave it in place: " + name_value)
			return preserved
		var target := destination.path_join(name_value)
		if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
			batch_failures.append(slug + ": existing preserved save would be overwritten: " + target)
			return preserved
		var error := DirAccess.rename_absolute("user://" + name_value, target)
		if error != OK:
			batch_failures.append(slug + ": cannot preserve save: " + name_value + " (" + str(error) + ")")
			return preserved
		preserved.append(target)
	return preserved

func reset_case_state() -> void:
	release_inputs()
	if physics_frame.is_connected(trace_flights): physics_frame.disconnect(trace_flights)
	if physics_frame.is_connected(observe_magic_flights): physics_frame.disconnect(observe_magic_flights)
	magic_flights.clear()
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
	pose_review_positioned = false

func finish_batch() -> void:
	for key: String in previous_environment:
		var saved: Dictionary = previous_environment[key]
		if saved.present: OS.set_environment(key, str(saved.value))
		else: OS.unset_environment(key)
	var summary := {"config": batch_config_path, "engine_processes": 1, "process_id": OS.get_process_id(),
		"scene_per_case": "Main.tscn", "user_directory": OS.get_user_data_dir(),
		"checks": batch_checks, "cases": batch_results, "failures": batch_failures}
	DirAccess.make_dir_recursive_absolute(batch_report_path.get_base_dir())
	var file := FileAccess.open(batch_report_path, FileAccess.WRITE)
	if file == null:
		batch_failures.append("Cannot write batch evidence: " + batch_report_path)
	else:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()
	print("PR100_ORIGINAL_BATCH_RESULT " + JSON.stringify({"cases": batch_results.size(), "checks": batch_checks,
		"failures": batch_failures, "report": batch_report_path}))
	if batch_failures.is_empty(): print("PR100_ORIGINAL_BATCH_OK")
	quit(0 if batch_failures.is_empty() else 1)

func run() -> void:
	quit_on_finish = false
	batch_report_path = OS.get_environment("TWILIGHT_PR100_BATCH_REPORT")
	if batch_report_path.is_empty(): batch_report_path = "user://pr100-batch15.json"
	batch_config_path = OS.get_environment("TWILIGHT_PR100_BATCH_CONFIG")
	if batch_config_path.is_empty(): batch_config_path = "res://tests/fixtures/pr100_batch15.json"
	if OS.get_environment("TWILIGHT_PR100_BATCH_ISOLATED") != "1":
		batch_failures.append("Use an isolated user directory and set TWILIGHT_PR100_BATCH_ISOLATED=1")
	var existing_saves := active_save_files()
	if not existing_saves.is_empty():
		batch_failures.append("Existing user saves must remain untouched; batch refused: " + str(existing_saves))
	if not batch_failures.is_empty(): finish_batch(); return
	var parser := JSON.new()
	if not FileAccess.file_exists(batch_config_path) or parser.parse(FileAccess.get_file_as_string(batch_config_path)) != OK:
		batch_failures.append("Cannot read valid batch configuration: " + batch_config_path)
		finish_batch(); return
	var config: Variant = parser.data
	if not config is Dictionary or not config.get("cases") is Array or config.cases.is_empty() or config.cases.size() > 10:
		batch_failures.append("Batch configuration must contain 1 to 10 cases")
		finish_batch(); return
	var slugs: Dictionary = {}
	for value: Variant in config.cases:
		if not value is Dictionary or str(value.get("name", "")).is_empty() or not safe_component(str(value.get("folder", ""))) or not safe_component(str(value.get("slug", ""))):
			batch_failures.append("Each case needs a name and safe folder/slug")
			continue
		var spec: Dictionary = value
		if slugs.has(spec.slug): batch_failures.append("Duplicate case slug: " + str(spec.slug))
		slugs[spec.slug] = true
		if DirAccess.dir_exists_absolute("user://pr100-batch-preserved/" + str(spec.slug)):
			batch_failures.append("Existing preserved case saves require a fresh isolated user directory: " + str(spec.slug))
		if not ResourceLoader.exists("res://assets/actors/eight_direction/original_based/" + str(spec.folder) + "/SpriteFrames.tres"):
			batch_failures.append("Missing case artwork: " + str(spec.folder))
	var capture_root := OS.get_environment("TWILIGHT_PR100_BATCH_CAPTURE_DIR")
	if DisplayServer.get_name() == "headless":
		if not capture_root.is_empty(): batch_failures.append("Batch screenshots require a rendered viewport")
	elif capture_root.is_empty(): capture_root = "user://pr100-batch-captures"
	if not batch_failures.is_empty(): finish_batch(); return
	for key: String in CASE_ENV:
		previous_environment[key] = {"present": OS.has_environment(key), "value": OS.get_environment(key)}
	var sampled_folders: Dictionary = {}
	for spec: Dictionary in config.cases:
		reset_case_state()
		current_case = spec
		var first_resource_case: bool = not sampled_folders.has(spec.folder)
		OS.set_environment("TWILIGHT_ORIGINAL_SUBJECT", str(spec.name))
		OS.set_environment("TWILIGHT_ORIGINAL_POSE_CAPTURE", "1" if first_resource_case else "0")
		OS.set_environment("TWILIGHT_PR100_REPORT", (batch_report_path.get_basename() + "-cases").path_join(str(spec.slug) + ".json"))
		OS.set_environment("TWILIGHT_PR100_CAPTURE_DIR", capture_root.path_join(str(spec.slug)) if not capture_root.is_empty() else "")
		await super.run()
		batch_checks += checks
		for failure: String in failures: batch_failures.append(str(spec.slug) + ": " + failure)
		var result := {"name": spec.name, "folder": spec.folder, "slug": spec.slug, "checks": checks,
			"failures": failures.duplicate(), "physics_ticks": ticks_elapsed, "report": out,
			"monster_directions": report.monster.size(), "pose_samples": report.get("pose_samples", []).size(),
			"full_pose_capture": first_resource_case and not capture_root.is_empty(), "screenshots": report.screenshots.size()}
		var before_preservation: int = batch_failures.size()
		result.preserved_saves = preserve_case_saves(str(spec.slug))
		batch_results.append(result)
		sampled_folders[spec.folder] = true
		if batch_failures.size() > before_preservation: break
	finish_batch()
