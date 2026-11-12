extends SceneTree
## Opt-in, privately supplied original Knight male package; not a public CI fixture.
const VIEW = preload("res://scripts/characters/lobby_source_presentation.gd")
const SELECT = preload("res://scripts/characters/lobby_source_selection.gd")
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("CHARACTER_LOBBY_ORIGINAL_PRESENTATION_FAIL ",label)
func finish() -> void:
	print("CHARACTER_LOBBY_ORIGINAL_PRESENTATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"verified current523 Knight male originals, actual CSB mount/play and source byte preservation; Spine runtime unavailable, no render/layout/device acceptance"}))
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	if OS.get_environment("TWILIGHT_CHARACTER_REGRESSION_ISOLATED") != "1" or FileAccess.file_exists(ACCOUNT.DEFAULT_PATH):
		printerr("CHARACTER_LOBBY_ORIGINAL_PRESENTATION_FAIL fresh explicit isolated profile required")
		quit(2); return
	var selected: Dictionary = SELECT.selected_pack()
	if not selected.get("ok",false) or not selected.get("selected",false): check(false,"verified original lobby pack selected"); finish(); return
	var pack: RefCounted = selected.pack
	var before: Dictionary = {}
	for member: String in pack.manifest.files: before[member] = FileAccess.get_sha256(pack.root.path_join("originals").path_join(member))
	pack.release_cache_leases()
	var view = VIEW.new()
	view.size = Vector2(720,420)
	root.add_child(view)
	var state: Dictionary = view.select_profile(1,1)
	check(state.get("ok",false),"actual original class/gender relationship resolves")
	var body: Dictionary = state.get("layers",{}).get("spine",{})
	check(body.get("status") == "missing_runtime","original files do not invent an installed Spine runtime")
	check(body.get("spine_version") == "3.6.52","actual skeleton version is read from original bytes")
	check(body.get("clips",[]) == ["all_animation"],"actual original animation name retained without autoplay")
	check(body.get("page_paths",[]).size() == 2,"both actual atlas pages are verified")
	check(not state.get("rendered",true) and not state.get("original_lobby_layout_verified",true),"mounted sources do not claim visual or layout acceptance")
	for role: String in ["back_effect","front_effect"]:
		var layer: Dictionary = state.get("layers",{}).get(role,{})
		check(layer.get("status") == "mounted",role+" actual original CSB mounts")
		check(layer.get("clips",[]) == ["Loop_On"] and not layer.get("playing",false),role+" original clip is explicit and not autoplayed")
		check(view.play_layer(role,"Loop_On",false).get("ok",false),role+" original CSB clip starts")
	for index: int in 8: await process_frame
	for mount_name: String in ["BackEffect","FrontEffect"]:
		var mount: Node = view.get_node("SourcePreviewRoot/"+mount_name)
		check(mount.get_child_count() == 1,mount_name+" owns exactly one original scene")
		if mount.get_child_count() == 1:
			var scene: Node = mount.get_child(0)
			check(scene.playback_status().clip == "Loop_On",mount_name+" production scene reports exact playback clip")
	var other: Dictionary = view.select_profile(1,2)
	check(other.get("gender_id") == 2,"selecting another source gender updates identity")
	check(other.get("layers",{}).get("spine",{}).get("status") == "missing_files","absent female source is not replaced by male body")
	check(not other.get("has_layers",true),"male effects are discarded when the female package is absent")
	view.clear_selection()
	check(not view.presentation_status().get("has_layers",true),"cancel clears every original layer")
	view.queue_free()
	await process_frame
	for member: String in before: check(FileAccess.get_sha256(pack.root.path_join("originals").path_join(member)) == before[member],"original byte hash retained: "+member)
	check(not FileAccess.file_exists(ACCOUNT.DEFAULT_PATH),"presentation neither creates nor changes an account save")
	finish()
