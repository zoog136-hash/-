extends SceneTree
## Fast guards by default. Optional real archive is cancelled during extraction.
## Run with an isolated XDG_DATA_HOME; never performs a complete installation.
const INSTALL = preload("res://scripts/maps/current523_aden_install.gd")
var checks: int = 0
var failures: Array[String] = []
var _base: String = ""
var _owned: bool = false
var _nodes: Array = []
var _metrics: Array[Dictionary] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func fixture(relative: String) -> String:
	return _base.path_join(relative)

func make_installer() -> Node:
	var node := INSTALL.new()
	root.add_child(node)
	_nodes.append(node)
	return node

func wait_done(node: Node) -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while is_instance_valid(node) and node.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(node) or not node.busy, "focused operation completed within60s")
	if is_instance_valid(node) and node.busy:
		node.cancel()
		for _frame: int in range(120):
			if not node.busy: break
			await process_frame

func parent_guard_checks(root_path: String, links_available: bool) -> void:
	DirAccess.make_dir_absolute(root_path)
	var created: Array[String] = []
	check(INSTALL._make_relative_parents(root_path, "a/b/file.s32", created), "relative parent traversal creates directories")
	check(created == [root_path.path_join("a"), root_path.path_join("a/b")], "only new absolute parent paths recorded in creation order")
	check(INSTALL._make_relative_parents(root_path, "a/b/file.s32", created) and created.size() == 2, "existing parents are not added to cleanup again")
	check(not FileAccess.file_exists(root_path.path_join("a/b/file.s32")), "parent traversal never creates payload")
	check(not INSTALL._make_relative_parents(root_path, "../escape/file", created), "parent traversal rejects escaping relative path")
	check(not INSTALL._make_relative_parents(root_path.path_join("absent"), "file", created), "missing traversal root rejects")
	var file := FileAccess.open(root_path.path_join("ordinary-file"), FileAccess.WRITE)
	file.store_string("keep"); file.close()
	check(not INSTALL._make_relative_parents(root_path, "ordinary-file/child/file", created), "regular file cannot become parent directory")
	check(FileAccess.get_file_as_string(root_path.path_join("ordinary-file")) == "keep", "parent file collision preserves bytes")
	if not links_available: return
	var directory := DirAccess.open(root_path)
	directory.make_dir("real")
	check(directory.create_link(root_path.path_join("real"), root_path.path_join("linked")) == OK, "component link fixture created")
	check(not INSTALL._make_relative_parents(root_path, "linked/child/file", created), "linked first parent component rejects")
	check(not DirAccess.dir_exists_absolute(root_path.path_join("real/child")), "rejected link target receives no directories")
	check(directory.create_link(root_path.path_join("real"), root_path.path_join("a/nested-link")) == OK, "nested link fixture created")
	check(not INSTALL._make_relative_parents(root_path, "a/nested-link/child/file", created), "linked nested parent component rejects")
	check(directory.create_link(root_path.path_join("nonexistent-target"), root_path.path_join("broken-link")) == OK, "broken link fixture created")
	check(not INSTALL._make_relative_parents(root_path, "broken-link/child/file", created), "broken parent link rejects before mkdir")
	check(directory.create_link(root_path.path_join("ordinary-file"), root_path.path_join("leaf-link")) == OK, "leaf link fixture created")
	check(INSTALL._has_link(root_path.path_join("leaf-link")), "independent final target full walk rejects leaf link")

func run() -> void:
	var archive: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--archive="): archive = arg.trim_prefix("--archive=")
	check(archive.is_empty() or FileAccess.file_exists(archive), "optional reviewed ZIP path exists")
	for path: String in ["../x", "/x", "a//b", "a\\b", "a/./b", "C:/x"]:
		check(not INSTALL.safe_relative(path), "unsafe relative path rejected: " + path)
	check(INSTALL.safe_relative("aden523-raw/originals/Map/Aden/800f7ff3e.s32"), "literal source path accepted")
	for store: String in ["user://", "res://assets", "/tmp/not-user", "user://../bad", "user://a/./b", "relative/path"]:
		check(INSTALL.safe_store_root(store).is_empty(), "unsafe store rejected: " + store)
	_base = "user://current523-install-test-" + str(Time.get_ticks_usec()) + "-" + str(get_instance_id())
	var absolute: String = INSTALL.safe_store_root(_base)
	check(not absolute.is_empty() and not DirAccess.dir_exists_absolute(absolute) and not FileAccess.file_exists(absolute), "unique owned test root")
	if absolute.is_empty() or DirAccess.dir_exists_absolute(absolute) or FileAccess.file_exists(absolute) or DirAccess.make_dir_absolute(absolute) != OK:
		failures.append("could not create unique test root")
		await finish_test(not archive.is_empty(), 0)
		return
	_owned = true
	DirAccess.make_dir_recursive_absolute(fixture("input"))
	DirAccess.make_dir_recursive_absolute(fixture("real-directory"))
	check(not INSTALL.safe_store_root(fixture("store")).is_empty(), "owned user subtree accepted")
	var access := DirAccess.open(absolute)
	var link: String = ProjectSettings.globalize_path(fixture("link"))
	var link_error: Error = access.create_link(ProjectSettings.globalize_path(fixture("real-directory")), link)
	if link_error == OK:
		check(INSTALL.safe_store_root(fixture("link/store")).is_empty(), "symlink store rejected")
	else:
		print("CURRENT523_INSTALL_TEST_SKIP symlink creation unavailable: ", link_error)
	parent_guard_checks(ProjectSettings.globalize_path(fixture("parent-guards")), link_error == OK)
	var sentinel := FileAccess.open(fixture("unrelated-save"), FileAccess.WRITE)
	sentinel.store_string("unchanged"); sentinel.close()
	var bad := FileAccess.open(fixture("input/bad.zip"), FileAccess.WRITE)
	bad.store_string("not-a-zip"); bad.close()
	var node: Node = make_installer()
	check(node.start(fixture("input/missing.zip")), "missing archive checked asynchronously")
	await wait_done(node)
	check(not node.last_result.get("ok", true) and node.problem.contains("읽지 못"), "missing archive rejected")
	check(node.start(fixture("input/bad.zip")), "wrong-size archive checked asynchronously")
	await wait_done(node)
	check(not node.last_result.get("ok", true) and node.problem.contains("크기"), "wrong-size archive rejected")
	check(not node.busy and not node.problem.is_empty(), "failed preflight exposes problem and stays idle")
	var detached: Node = make_installer()
	detached.progress.connect(func(_stage: String, _done: int, _total: int) -> void:
		if detached.is_inside_tree(): root.remove_child(detached))
	check(not detached.start(fixture("input/bad.zip")), "initial synchronous detach prevents worker start")
	check(not detached.busy and detached.last_result.get("cancelled", false), "pre-worker detach preserves cancellation result")
	detached.free()
	var replacement: Node = make_installer()
	var replaced: Array[bool] = [false]
	var restarted: Array[bool] = [false]
	replacement.progress.connect(func(_stage: String, _done: int, _total: int) -> void:
		if not replaced[0]:
			replaced[0] = true
			root.remove_child(replacement)
			root.add_child(replacement)
			restarted[0] = replacement.start(fixture("input/bad.zip"), fixture("replacement-store")))
	check(not replacement.start(fixture("input/bad.zip"), fixture("obsolete-store")), "obsolete start cannot start replacement thread twice")
	await wait_done(replacement)
	check(restarted[0] and replacement.problem.contains("크기"), "callback replacement completes its own request")
	var completed: Array[Dictionary] = []
	node.finished.connect(func(result: Dictionary) -> void: completed.append(result))
	var max_written: Array[int] = [0]
	if not archive.is_empty():
		var stop_hash := func(stage: String, _done: int, _total: int) -> void:
			if stage == "archive_sha256": node.cancel()
		node.progress.connect(stop_hash)
		check(node.start(archive, fixture("hash-cancel")), "real archive readonly phase starts")
		await wait_done(node)
		await process_frame
		check(completed.size() == 1 and completed[0].cancelled, "initial cancellation emits exactlyonce")
		check(not DirAccess.dir_exists_absolute(fixture("hash-cancel")), "readonly cancellation creates no store")
		node.progress.disconnect(stop_hash)
		completed.clear()
		var stop_first := func(stage: String, done: int, _total: int) -> void:
			if stage == "extract" and done > 0:
				max_written[0] = maxi(max_written[0], done)
				node.cancel()
		node.progress.connect(stop_first)
		check(node.start(archive, fixture("first-file-cancel")), "real first-file cancellation starts")
		await wait_done(node)
		check(completed.size() == 1 and completed[0].cancelled, "extraction cancellation emits exactlyonce")
		var stage_path: String = str(node.last_result.get("stage_root", ""))
		max_written[0] = maxi(max_written[0], int(node.last_result.get("written_files", 0)))
		_metrics.append({"case": "extract_cancel", "phase_msec": node.last_result.get("phase_msec", {}), "phase_steps": node.last_result.get("phase_steps", {})})
		check(max_written[0] > 0 and max_written[0] < INSTALL.FILE_COUNT, "partial payload only; no full installation")
		check(not stage_path.is_empty() and not DirAccess.dir_exists_absolute(stage_path) and node.last_result.get("cleanup_complete", false), "cancel removes owned staging tree")
		check(not DirAccess.dir_exists_absolute(INSTALL.safe_store_root(fixture("first-file-cancel")).path_join("523-" + INSTALL.ARCHIVE_SHA256)), "cancel never publishes version")
		node.progress.disconnect(stop_first)
		node.queue_free()
		await process_frame
		var exit_node: Node = make_installer()
		var exit_written: Array[int] = [0]
		var exit_result: Array[Dictionary] = [{}]
		exit_node.tree_exited.connect(func() -> void: exit_result[0] = exit_node.last_result.duplicate(true))
		exit_node.progress.connect(func(stage: String, done: int, _total: int) -> void:
			if stage == "extract" and done > 0:
				exit_written[0] = maxi(exit_written[0], done)
				exit_node.queue_free())
		check(exit_node.start(archive, fixture("exit-cancel")), "exit cleanup case starts")
		var deadline: int = Time.get_ticks_msec() + 60000
		while is_instance_valid(exit_node) and Time.get_ticks_msec() < deadline: await process_frame
		check(not is_instance_valid(exit_node), "exit case freed without callback errors")
		var exit_stage: String = str(exit_result[0].get("stage_root", ""))
		exit_written[0] = maxi(exit_written[0], int(exit_result[0].get("written_files", 0)))
		_metrics.append({"case": "exit_cancel", "phase_msec": exit_result[0].get("phase_msec", {}), "phase_steps": exit_result[0].get("phase_steps", {})})
		check(exit_written[0] > 0 and exit_written[0] < INSTALL.FILE_COUNT and not exit_stage.is_empty() and not DirAccess.dir_exists_absolute(exit_stage) and exit_result[0].get("cleanup_complete", false), "exit_tree joins worker and removes partial stage")
		max_written[0] = maxi(max_written[0], exit_written[0])
		var removed: Node = make_installer()
		removed.progress.connect(func(stage: String, done: int, _total: int) -> void:
			if stage == "archive_sha256" and done > 0:
				root.remove_child(removed))
		check(removed.start(archive, fixture("synchronous-remove")), "synchronous tree-exit case starts")
		await wait_done(removed)
		check(not removed.is_inside_tree() and removed.last_result.get("cancelled", false), "synchronous final-hash exit has no cleared-handle error")
		check(not DirAccess.dir_exists_absolute(fixture("synchronous-remove")), "synchronous exit remains readonly")
		removed.free()
		var corrupt_store: String = fixture("corrupt-existing")
		var corrupt_version: String = INSTALL.safe_store_root(corrupt_store).path_join("523-" + INSTALL.ARCHIVE_SHA256)
		DirAccess.make_dir_recursive_absolute(corrupt_version)
		var existing: Node = make_installer()
		check(existing.start(archive, corrupt_store), "incomplete existing version verification starts")
		await wait_done(existing)
		check(not existing.last_result.get("ok", true) and existing.problem.contains("기존 버전"), "incomplete existing version rejected")
		check(DirAccess.dir_exists_absolute(corrupt_version), "corrupt existing version preserved by installer")
		var sparse := FileAccess.open(fixture("input/wrong-hash.zip"), FileAccess.WRITE)
		sparse.seek(INSTALL.ARCHIVE_BYTES - 1); sparse.store_8(0); sparse.close()
		var wrong_hash: Node = make_installer()
		check(wrong_hash.start(fixture("input/wrong-hash.zip"), fixture("wrong-hash-store")), "exact-size sparse bad hash starts readonly")
		await wait_done(wrong_hash)
		check(not wrong_hash.last_result.get("ok", true) and wrong_hash.problem.contains("SHA256"), "whole SHA rejects exact-size wrong archive")
		check(not DirAccess.dir_exists_absolute(fixture("wrong-hash-store")), "bad hash creates no store or extraction")
	check(FileAccess.get_file_as_string(fixture("unrelated-save")) == "unchanged", "unrelated save sentinel unchanged")
	await finish_test(not archive.is_empty(), max_written[0])

func finish_test(real: bool, maximum_written: int) -> void:
	for value: Variant in _nodes:
		if is_instance_valid(value): (value as Node).queue_free()
	await process_frame
	if _owned:
		var absolute: String = ProjectSettings.globalize_path(_base)
		if not INSTALL._has_link(absolute):
			remove_fixture_tree(absolute)
		check(not DirAccess.dir_exists_absolute(absolute), "only owned fixture root cleaned")
	print("CURRENT523_INSTALL_FOCUSED_RESULT " + JSON.stringify({"checks": checks, "failures": failures,
		"real_archive_selected": real, "maximum_payload_files_written": maximum_written, "full_install_performed": false,
		"operations": _metrics}))
	quit(0 if failures.is_empty() else 1)

func remove_fixture_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(_base)
	if not _owned or (path != absolute and not path.begins_with(absolute + "/")): return
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.include_hidden = true
	directory.include_navigational = false
	directory.list_dir_begin()
	var name: String = directory.get_next()
	var count: int = 0
	while not name.is_empty() and count < 128:
		count += 1
		var child: String = path.path_join(name)
		if directory.is_link(name):
			directory.remove(name)
		elif directory.current_is_dir():
			remove_fixture_tree(child)
		else:
			directory.remove(name)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
