extends SceneTree
## Optional owned-input regression; deliberately excluded from the default core.
## Use fresh XDG directories, TWILIGHT_CHARACTER_REGRESSION_ISOLATED=1,
## TWILIGHT_PATCH523_CONTENT=<verified definition ZIP>, TWILIGHT_SOURCE_LOBBY
## and TWILIGHT_SOURCE_LOBBY_SHA256=<ALL25_PIN>. No original art is committed.
const VIEW = preload("res://scripts/characters/lobby_source_presentation.gd")
const SELECT = preload("res://scripts/characters/lobby_source_selection.gd")
const CATALOG = preload("res://scripts/characters/lobby_source_catalog.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const ALL25_PIN := "c9dc3ff88e11ef6435b13c44790756e9e31c79dcec3d7517ccf5a0cff909a62d"
const SCOPE := "OWNED_ALL25_SOURCE_CONSUMER_AND_CSB_MOUNTS_NOT_SPINE_RENDER_LAYOUT_OR_DEVICE_ACCEPTANCE"
const SAVE_PATHS := ["user://twilight_v20_save.json", "user://twilight_native_png_save.json", "user://twilight_full_cards_test_v1.json", "user://twilight_native_png_full_cards_test_v1.json", "user://twilight_growth_lab_v1.json", "user://base508_source_test_never_written.json"]
var checks: int = 0
var failures: Array[String] = []
var observations: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CHARACTER_LOBBY_ALL_ORIGINAL_PROFILES_FAIL ", label)
	return ok

func finish(skipped: bool = false, reason: String = "", reject: bool = false) -> void:
	print("CHARACTER_LOBBY_ALL_ORIGINAL_PROFILES_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "skipped":skipped, "reason":reason, "observations":observations, "scope":SCOPE}))
	quit(2 if reject else 0 if skipped or failures.is_empty() else 1)

func run() -> void:
	var options: Dictionary = SELECT.options(OS.get_cmdline_user_args(), OS.get_environment("TWILIGHT_SOURCE_LOBBY"), OS.get_environment("TWILIGHT_SOURCE_LOBBY_SHA256"))
	if OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty() or not options.get("selected",false):
		finish(true, "explicit_owned_definition_zip_and_all25_lobby_pack_required")
		return
	if not options.get("ok",false):
		check(false, "invalid explicit lobby selection: " + str(options.get("error","")))
		finish(false, "invalid_opt_in", true)
		return
	if OS.get_environment("TWILIGHT_CHARACTER_REGRESSION_ISOLATED") != "1":
		check(false, "fresh explicit isolated XDG profile required; existing saves untouched")
		finish(false, "isolation_required", true)
		return
	for path: String in SAVE_PATHS:
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".source-map-current.json"):
			check(false, "existing player save or migration pointer found; untouched")
			finish(false, "fresh_profile_required", true)
			return
	var identity: Dictionary = DEFINITIONS.identity()
	if not check(identity.get("source_sha256") == DEFINITIONS.SOURCE_SHA, "verified original definitions required"):
		finish()
		return
	var archive_path: String = DEFINITIONS.archive_path()
	var archive_before: String = FileAccess.get_sha256(archive_path)
	if not check(archive_before == DEFINITIONS.SOURCE_SHA, "actual definition archive bytes match pinned identity"):
		finish()
		return
	var selected: Dictionary = SELECT.selected_pack()
	if not check(selected.get("ok",false) and selected.get("selected",false), "actual private pinned lobby pack opens: " + str(selected.get("error",""))):
		finish()
		return
	var pack: RefCounted = selected.pack
	if not check(pack.manifest_sha256 == ALL25_PIN, "exact all25 source manifest pin"):
		pack.release_cache_leases()
		finish()
		return
	check(pack.manifest.lobby_spines.size() == 25 and pack.manifest.scenes.size() == 16, "25 original body bindings and 16 decoded CSB scenes")
	var manifest_before: String = FileAccess.get_sha256(pack.root.path_join("original_ui.json"))
	var originals_before: Dictionary = {}
	for member: String in pack.manifest.files:
		originals_before[member] = FileAccess.get_sha256(pack.root.path_join("originals").path_join(member))
		check(originals_before[member] == pack.manifest.files[member].sha256, "original input hash: " + member)
	pack.release_cache_leases()
	check(not FileAccess.file_exists(ACCOUNT.DEFAULT_PATH), "opening source packs does not create account state")
	# Create only this explicit fresh profile's sentinel, before previewing.
	var sentinel := FileAccess.open(ACCOUNT.DEFAULT_PATH, FileAccess.WRITE)
	if not check(sentinel != null, "isolated save sentinel opens"):
		finish()
		return
	sentinel.store_string("{\"scope\":\"isolated_lobby_test_save_fixture\",\"progress\":17}\n")
	sentinel.close()
	var save_before: String = FileAccess.get_sha256(ACCOUNT.DEFAULT_PATH)
	var session_before: Dictionary = ACCOUNT.session.duplicate(true)
	var catalog = CATALOG.new()
	var view = VIEW.new()
	view.catalog = catalog
	view.size = Vector2(720,420)
	root.add_child(view)
	check(not view.spine_factory.is_valid(), "no substitute Spine factory injected")
	var pairs: Array[Dictionary] = DEFINITIONS.rows("ClassAssets")
	check(pairs.size() == 25, "verified current523 class/gender pairs")
	var profiles: Dictionary = {}
	var pages: Dictionary = {}
	var effects: Dictionary = {}
	var missing_ids: Dictionary = {}
	var missing_pairs: Dictionary = {}
	var mount_occurrences: int = 0
	for pair: Dictionary in pairs:
		var label: String = "%d/%d" % [int(pair.ClassID),int(pair.GenderID)]
		var definition: Dictionary = catalog.resolve(pair.ClassID,pair.GenderID)
		var state: Dictionary = view.select_profile(pair.ClassID,pair.GenderID)
		if not check(state.get("ok",false) and state.get("class_id") == pair.ClassID and state.get("gender_id") == pair.GenderID, "final consumer selects exact " + label): continue
		profiles[label] = true
		check(not state.get("synthetic",true), "production original metadata " + label)
		check(not state.get("rendered",true) and not state.get("original_render_verified",true) and not state.get("original_lobby_layout_verified",true) and not state.get("source_offset_applied",true), "no original visual/layout/placement claim " + label)
		var body: Dictionary = state.get("layers",{}).get("spine",{})
		check(body.get("status") == "missing_runtime" and not body.get("mounted",true), "verified body remains unavailable without SDK " + label)
		check(body.get("spine_version") == "3.6.52", "actual skeleton version " + label)
		var body_path: String = str(body.get("path",""))
		check(body.get("source_sha256") == pack.manifest.files.get(body_path,{}).get("sha256","missing"), "actual body SHA " + label)
		check(body.get("atlas_path") == pack.manifest.lobby_spines.get(body_path,{}).get("atlas","missing"), "explicit source atlas binding " + label)
		check(view.get_node("SourcePreviewRoot/SpineBody").get_child_count() == 0, "no fabricated body node " + label)
		for page: String in body.get("page_paths",[]):
			check(pack.manifest.files.has(page), "body page is declared: " + page)
			check(FileAccess.get_sha256(pack.root.path_join("originals").path_join(page)) == pack.manifest.files.get(page,{}).get("sha256","missing"), "body page SHA: " + page)
			pages[page] = true
		var played: Dictionary = {}
		for index: int in 2:
			var role: String = "back_effect" if index == 0 else "front_effect"
			var mount_name: String = "BackEffect" if index == 0 else "FrontEffect"
			var layer: Dictionary = state.get("layers",{}).get(role,{})
			var source: Dictionary = definition.get(role,{})
			var mount: Node = view.get_node("SourcePreviewRoot/" + mount_name)
			if source.get("status") == "resolved":
				check(layer.get("status") == "mounted" and layer.get("mounted",false), "actual source CSB mounts " + label + " " + role)
				var path: String = str(layer.get("path",""))
				check(layer.get("source_sha256") == pack.manifest.files.get(path,{}).get("sha256","missing"), "CSB source SHA " + label + " " + role)
				check(mount.get_child_count() == 1, "one current source scene " + label + " " + role)
				if mount.get_child_count() == 1: check(mount.get_child(0).get("source_member") == path, "exact mounted member " + label + " " + role)
				check(not layer.get("playing",true), "no inferred autoplay " + label + " " + role)
				# A baked manifest stores empty scene placeholders; the scene API
				# is authoritative for both cold and restored SourcePack instances.
				var source_scene: Dictionary = pack.scene(path)
				var names: Array = []
				for clip: Dictionary in source_scene.get("animationList",[]): names.append(clip.name)
				check(layer.get("clips",[]) == names, "actual original CSB clip names " + label + " " + role)
				if not effects.has(path):
					check(not names.is_empty(), "original effect has a declared clip " + path)
					if not names.is_empty():
						check(view.play_layer(role,names[0],false).get("ok",false), "explicit source clip starts " + path)
						played[mount_name] = names[0]
				effects[path] = true
				mount_occurrences += 1
			elif source.get("status") == "optional_zero":
				check(layer.get("status") == "optional_zero" and mount.get_child_count() == 0, "explicit absent effect stays absent " + label + " " + role)
			elif source.get("status") == "missing_reference":
				check(layer.get("status") == "missing_reference" and str(layer.get("path","")).is_empty() and mount.get_child_count() == 0, "missing original ID is not repaired " + label + " " + role)
				missing_ids[int(source.get("asset_id",0))] = true
				missing_pairs[label] = true
			else: check(false, "unexpected source effect relationship " + label + " " + role)
		await process_frame
		await process_frame
		for mount_name: String in played:
			var mount: Node = view.get_node("SourcePreviewRoot/" + mount_name)
			if check(mount.get_child_count() == 1, "playing source scene remains owned " + label + " " + mount_name):
				var scene: Node = mount.get_child(0)
				if check(scene.has_method("playback_status"), "production playback status exists " + label + " " + mount_name):
					check(scene.call("playback_status").get("clip") == played[mount_name], "production scene reports exact clip " + label + " " + mount_name)
	check(profiles.size() == 25, "all 25 profiles used the final consumer")
	check(pages.size() == 78, "78 unique body pages SHA verified")
	check(effects.size() == 16 and mount_occurrences == 18, "16 unique actual CSB scenes mounted across 18 references")
	check(missing_ids.size() == 6 and missing_pairs.size() == 4, "six unresolved IDs remain in four combinations")
	for id: int in [84513,84523,84533,84543,166222,166232]: check(missing_ids.has(id), "known unresolved original effect " + str(id))
	for label: String in ["5/1","5/2","8/1","8/2"]: check(missing_pairs.has(label), "known unresolved original combination " + label)
	view.clear_selection()
	check(not view.presentation_status().get("has_layers",true), "clearing preview retires all layers")
	for name: String in ["BackEffect","SpineBody","FrontEffect"]: check(view.get_node("SourcePreviewRoot/" + name).get_child_count() == 0, "old source nodes detached " + name)
	view.queue_free()
	await process_frame
	pack.release_cache_leases()
	for member: String in originals_before: check(FileAccess.get_sha256(pack.root.path_join("originals").path_join(member)) == originals_before[member], "original bytes retained: " + member)
	check(FileAccess.get_sha256(pack.root.path_join("original_ui.json")) == manifest_before, "source manifest retained")
	check(FileAccess.get_sha256(archive_path) == archive_before, "definition archive retained")
	check(FileAccess.get_sha256(ACCOUNT.DEFAULT_PATH) == save_before, "isolated account sentinel bytes retained")
	check(ACCOUNT.session == session_before, "preview does not change active account session")
	for path: String in SAVE_PATHS:
		if path != ACCOUNT.DEFAULT_PATH: check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".source-map-current.json"), "no account save created in another namespace: " + path)
	observations = {"profiles":profiles.size(), "body_status":"missing_runtime", "spine_version":"3.6.52", "body_pages":pages.size(), "unique_csb_scenes":effects.size(), "mount_occurrences":mount_occurrences, "missing_effect_ids":missing_ids.keys(), "missing_combinations":missing_pairs.keys(), "original_files":originals_before.size(), "rendered":false, "original_lobby_layout_verified":false}
	finish()
