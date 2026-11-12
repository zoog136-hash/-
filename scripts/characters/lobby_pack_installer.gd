extends RefCounted
## Private, content-addressed installation. Never touches saves or older packs.
const ARCHIVE_SHA := "2a3dee048bbca5f85450d3e0cf514f270ef8704affed7d46e290dcbd155baba0"
const ARCHIVE_BYTES := 548837574
const MANIFEST_SHA := "5a252befd85166b587e067fbd0839a90a774c162fab598da500959d9682a6700"
const BASE := "user://lobby_packs"
const ACTIVE := BASE + "/active.json"
const MAX_MEMBER := 128 * 1024 * 1024
const MAX_TOTAL := 1536 * 1024 * 1024
static var busy: bool = false

static func saved_options() -> Dictionary:
	if not FileAccess.file_exists(ACTIVE): return {"ok":true,"selected":false}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACTIVE))
	var root: String = BASE.path_join(MANIFEST_SHA)
	if not value is Dictionary or value.get("sha256") != MANIFEST_SHA or value.get("path") != root:
		return _fail("installed_lobby_selection_invalid")
	return {"ok":true,"selected":true,"path":root,"sha256":MANIFEST_SHA}

static func install_paths(paths: PackedStringArray, progress: Callable = Callable()) -> Dictionary:
	if paths.size() == 1: return install_archive(paths[0], progress)
	if paths.size() != 3: return _fail("select_zip_or_three_split_parts")
	if busy: return _fail("installation_already_running")
	var ordered: PackedStringArray = PackedStringArray()
	for suffix: String in [".001", ".002", ".003"]:
		var matching: PackedStringArray = PackedStringArray()
		for path: String in paths:
			if path.ends_with(suffix): matching.append(path)
		if matching.size() != 1: return _fail("three_matching_split_parts_required")
		ordered.append(matching[0])
	var target: String = BASE.path_join(MANIFEST_SHA)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target)) and _verify(target).get("ok",false):
		return _activate(target,true)
	busy = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	var joined: String = BASE.path_join("joined.zip")
	if progress.is_valid(): progress.call(0.0,"Joining three downloaded parts")
	var result: Dictionary = _join_parts(ordered[0], joined, ordered)
	if result.get("ok",false): result = _install(joined,progress)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(joined))
	busy = false
	return result

static func install_archive(path: String, progress: Callable = Callable()) -> Dictionary:
	if busy: return _fail("installation_already_running")
	busy = true
	var result: Dictionary = _install(path, progress)
	if path.ends_with(".001"): DirAccess.remove_absolute(ProjectSettings.globalize_path(BASE.path_join("joined.zip")))
	busy = false
	return result

static func _install(path: String, progress: Callable) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	var target: String = BASE.path_join(MANIFEST_SHA)
	# A complete prior installation is reused only after its files pass validation.
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target)):
		var existing: Dictionary = _verify(target)
		if existing.get("ok",false): return _activate(target, true)
		# A damaged installation is preserved below, after its replacement verifies.
		pass
	var archive: String = path
	var joined: String = BASE.path_join("joined.zip")
	if path.ends_with(".001"):
		if progress.is_valid(): progress.call(0.0,"Joining three downloaded parts")
		var join_result: Dictionary = _join_parts(path, joined)
		if not join_result.get("ok",false): return join_result
		archive = joined
	var input: FileAccess = FileAccess.open(archive,FileAccess.READ)
	if input == null: return _fail("archive_unreadable")
	var length: int = input.get_length()
	input.close()
	if length != ARCHIVE_BYTES: return _fail("archive_size_mismatch_retry_download")
	if progress.is_valid(): progress.call(0.02,"Checking archive SHA-256")
	if FileAccess.get_sha256(archive) != ARCHIVE_SHA: return _fail("archive_sha256_mismatch_retry_download")
	var reader := ZIPReader.new()
	if reader.open(archive) != OK: return _fail("archive_open_failed")
	var names: PackedStringArray = reader.get_files()
	if names.size() > 1024:
		reader.close()
		return _fail("archive_member_limit")
	var stage: String = BASE.path_join("stage_" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stage))
	var total: int = 0
	var seen: Dictionary = {}
	var failure: String = ""
	for index: int in names.size():
		var member: String = names[index]
		if not safe_member(member) or seen.has(member.to_lower()):
			failure = "unsafe_archive_member"
			break
		seen[member.to_lower()] = true
		if member.ends_with("/"): continue
		# Only the pinned archive reaches ZIPReader; untrusted archives never inflate.
		var bytes: PackedByteArray = reader.read_file(member)
		total += bytes.size()
		if bytes.size() > MAX_MEMBER or total > MAX_TOTAL:
			failure = "archive_extraction_limit"
			break
		var destination: String = stage.path_join(member)
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir())) != OK:
			failure = "insufficient_storage_or_directory_failure"
			break
		var output: FileAccess = FileAccess.open(destination,FileAccess.WRITE)
		if output == null:
			failure = "insufficient_storage_or_write_failure"
			break
		output.store_buffer(bytes)
		output.flush()
		if output.get_error() != OK: failure = "insufficient_storage_or_write_failure"
		output.close()
		if not failure.is_empty(): break
		if progress.is_valid(): progress.call(0.05+0.85*float(index+1)/names.size(),"Installing " + member.get_file())
	reader.close()
	if failure.is_empty():
		if progress.is_valid(): progress.call(0.92,"Verifying installed files")
		var checked: Dictionary = _verify(stage)
		if not checked.get("ok",false): failure = str(checked.get("error","pack_verification_failed"))
	if not failure.is_empty():
		_remove_stage(stage)
		return _fail(failure)
	var backup: String = ""
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target)):
		backup = target + ".previous_" + str(Time.get_ticks_usec())
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(target),ProjectSettings.globalize_path(backup)) != OK:
			_remove_stage(stage)
			return _fail("prior_install_preservation_failed")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(stage),ProjectSettings.globalize_path(target)) != OK:
		if not backup.is_empty(): DirAccess.rename_absolute(ProjectSettings.globalize_path(backup),ProjectSettings.globalize_path(target))
		_remove_stage(stage)
		return _fail("installation_commit_failed")
	if archive == joined: DirAccess.remove_absolute(ProjectSettings.globalize_path(joined))
	return _activate(target, false)

static func safe_member(member: String) -> bool:
	if member.is_empty() or member.is_absolute_path() or member.contains("\\") or member.contains(":"): return false
	for part: String in member.split("/"):
		if part == "." or part == "..": return false
	return true

static func _verify(root: String) -> Dictionary:
	# Avoid a preload cycle: selection references this installer for saved options.
	var selection: GDScript = load("res://scripts/characters/lobby_source_selection.gd")
	var result: Dictionary = selection.open_options({"ok":true,"selected":true,"path":root,"sha256":MANIFEST_SHA})
	if result.get("pack") != null: result.pack.release_cache_leases()
	return result

static func _activate(root: String, reused: bool) -> Dictionary:
	var temporary: String = ACTIVE + ".tmp"
	var output: FileAccess = FileAccess.open(temporary,FileAccess.WRITE)
	if output == null: return _fail("selection_write_failed")
	output.store_string(JSON.stringify({"path":root,"sha256":MANIFEST_SHA}))
	output.flush()
	var error: Error = output.get_error()
	output.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(ACTIVE)) != OK:
		return _fail("selection_commit_failed")
	return {"ok":true,"selected":true,"path":root,"sha256":MANIFEST_SHA,"reused":reused}

static func _join_parts(first: String, destination: String, selected: PackedStringArray = PackedStringArray()) -> Dictionary:
	var output: FileAccess = FileAccess.open(destination,FileAccess.WRITE)
	if output == null: return _fail("split_join_write_failed")
	for index: int in range(1,4):
		var part: String = selected[index-1] if selected.size() == 3 else first.left(-3) + ("%03d" % index)
		var input: FileAccess = FileAccess.open(part,FileAccess.READ)
		var expected: int = 209715200 if index < 3 else 129407174
		if input == null or input.get_length() != expected:
			output.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
			return _fail("three_matching_split_parts_required")
		while input.get_position() < input.get_length():
			output.store_buffer(input.get_buffer(1024*1024))
		input.close()
	output.flush()
	var error: Error = output.get_error()
	output.close()
	return {"ok":true} if error == OK else _fail("split_join_storage_failure")

static func _remove_stage(path: String) -> void:
	# This function is used only for the unique staging directory of this attempt.
	var directory: DirAccess = DirAccess.open(path)
	if directory == null: return
	for child: String in directory.get_files(): DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(child)))
	for child: String in directory.get_directories(): _remove_stage(path.path_join(child))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"selected":false,"error":reason}
