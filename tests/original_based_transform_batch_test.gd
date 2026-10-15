extends "res://tests/run_original_based_transform_batch.gd"

# Guard and save-preservation tests only; actual Main runs remain in the batch job.
func fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pr100_transform_regression.json"))

func write_probe(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "save probe path writable")
	if file != null:
		file.store_string(value)
		file.close()

func run() -> void:
	check(active_save_files().is_empty(), "guard test uses a fresh user directory")
	if not failures.is_empty(): quit(1); return
	var config := fixture()
	check(config.cases.size() == 10 and validate_cases(config).is_empty(), "existing ten-transform fixture is valid")
	var large := {"cases": []}
	for index: int in range(20):
		var value: Dictionary = config.cases[0].duplicate(true)
		value.slug = "case-" + str(index)
		value.spec.transform_id = str(index + 1)
		large.cases.append(value)
	check(validate_cases(large).is_empty(), "normal twenty-subject batch is supported")
	large.cases.append(large.cases[0].duplicate(true))
	check(not validate_cases(large).is_empty(), "oversized batch is refused")
	check(not validate_cases({"cases": []}).is_empty(), "empty batch is refused")
	check(not validate_cases({"cases": [null]}).is_empty(), "invalid case is refused")
	var invalid := fixture()
	invalid.cases[0].folder = "../unreviewed"
	check(not validate_cases(invalid).is_empty(), "folder path traversal is refused")
	invalid = fixture()
	invalid.cases[0].spec.erase("job")
	check(not validate_cases(invalid).is_empty(), "incomplete equipment/class specification is refused")
	invalid = fixture()
	invalid.cases[0].spec.magic = "false"
	check(not validate_cases(invalid).is_empty(), "magic flag must be a boolean")
	invalid = fixture()
	invalid.cases[0].spec.appearance = 1.5
	check(not validate_cases(invalid).is_empty(), "fractional appearance is refused")
	invalid = fixture()
	invalid.cases[1].slug = invalid.cases[0].slug
	check(not validate_cases(invalid).is_empty(), "duplicate evidence slug is refused")
	invalid = fixture()
	invalid.cases[1].spec.transform_id = invalid.cases[0].spec.transform_id
	check(not validate_cases(invalid).is_empty(), "duplicate transform source identity is refused")
	invalid = fixture()
	invalid.held = [{"transform_id": invalid.cases[0].spec.transform_id}]
	check(not validate_cases(invalid).is_empty(), "Quality-HOLD identity cannot reenter the validation batch")
	var accepted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pr100_batch21_accepted.json"))
	check(validate_cases(accepted).is_empty(), "held identities remain separate from accepted candidate cases")
	var source := "user://twilight_v20_save.json"
	write_probe(source, "generated-save-probe")
	var original_hash := FileAccess.get_sha256(source)
	var preserved := preserve_case_saves("guard-preserve")
	check(preserved.size() == 1 and not FileAccess.file_exists(source), "generated case save moved into its own preservation directory")
	if not preserved.is_empty():
		check(FileAccess.get_sha256(preserved[0]) == original_hash, "preserved save bytes are unchanged")
	write_probe(source, "new-generated-save")
	var new_hash := FileAccess.get_sha256(source)
	batch_failures.clear()
	check(preserve_case_saves("guard-preserve").is_empty() and not batch_failures.is_empty(), "existing preserved save is never overwritten")
	check(FileAccess.get_sha256(source) == new_hash, "collision retains current save")
	if not preserved.is_empty(): check(FileAccess.get_sha256(preserved[0]) == original_hash, "collision retains previous checkpoint")
	write_probe("user://twilight_unrecognized_save.json", "unexpected-save-probe")
	batch_failures.clear()
	check(preserve_case_saves("guard-unexpected").is_empty() and not batch_failures.is_empty(), "unexpected save blocks the whole move")
	check(FileAccess.get_sha256(source) == new_hash and FileAccess.get_file_as_string("user://twilight_unrecognized_save.json") == "unexpected-save-probe", "all source saves survive a refused preservation")
	print("PR100_TRANSFORM_BATCH_GUARD_RESULT " + JSON.stringify({"checks": checks, "failure_count": failures.size(), "user_directory": OS.get_user_data_dir()}))
	if failures.is_empty(): print("PR100_TRANSFORM_BATCH_GUARD_OK")
	quit(0 if failures.is_empty() else 1)
