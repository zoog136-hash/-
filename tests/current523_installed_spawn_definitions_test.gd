extends SceneTree
## Monster spawning on 523 maps reads the world-links definitions the 523
## resource pack installer selected (user://current523_source_definitions.cfg),
## the same selection 523 play mode binds. Before, spawning only looked at
## fixed folders, so with the pack installed 523 maps had no monsters.
## Real input: -- --source523-pack=<installed pack with the world-links add-on>.
## Without it: selection rules only.
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
const PREFERENCES = preload("res://scripts/maps/current523_source_definition_preferences.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _finish(extra: Dictionary = {}) -> void:
	var result: Dictionary = {"checks":checks,"failures":failures}
	result.merge(extra)
	print("CURRENT523_INSTALLED_SPAWN_DEFINITIONS_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var base: String = arg("--source523-pack=")
	if base.is_empty():
		_rules()
		return
	var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
	check(read.ok and PACK.apply(PACK.selections(base, read.descriptor, PACK.read_addons(base))).ok, "installed pack applied")
	HOST.refresh()
	var settings: Dictionary = POLICY.settings()
	check(settings.get("enabled", false) and str(settings.get("root", "")) == base.path_join("world_links") and settings.get("sha") == POLICY.PINNED_PACK_SHA256, "spawning uses the installed world links: " + str(settings))
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for _frame: int in 900:
		if bool(world.get("current523_aden_play_active")): break
		await process_frame
	check(bool(world.get("current523_aden_play_active")), "523 play mode is active: " + str(world.get("current523_aden_play_problem")))
	var controller: RefCounted = world.call("_aden_play_controller")
	var summary: Dictionary = controller.get("spawn_summary") if controller != null else {}
	check(bool(summary.get("ok", false)), "523 Aden reads its spawn definitions: " + str(summary.get("reason", "")))
	check(int(summary.get("regions", 0)) > 0, "523 Aden has original spawn regions")
	check(int(summary.get("registered", 0)) > 0, "some regions have monsters the game can draw")
	_finish({"real_input_checked":true,"regions":summary.get("regions"),"registered":summary.get("registered"),"bosses":summary.get("bosses"),"slots":summary.get("slots"),"skipped":summary.get("skipped")})

func _rules() -> void:
	var path: String = PREFERENCES.PATH
	var had: bool = FileAccess.file_exists(path)
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(path) if had else PackedByteArray()
	if had: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(not POLICY.settings().get("enabled", false), "nothing selected: spawning stays off")
	# A selection whose folder does not hold the pinned manifest is not used.
	var fake: String = "user://spawn_definitions_fixture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fake))
	var manifest := FileAccess.open(fake.path_join("manifest.json"), FileAccess.WRITE)
	manifest.store_string("{}")
	manifest.close()
	check(PREFERENCES.write(fake, PREFERENCES.PIN) == OK, "fixture selection written")
	check(not POLICY.settings().get("enabled", false), "a selected folder with other bytes is refused")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fake.path_join("manifest.json")))
	check(not POLICY.settings().get("enabled", false), "a selected folder without a manifest is refused")
	check(PREFERENCES.disable() == OK and not POLICY.settings().get("enabled", false), "a disabled selection is not used")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fake))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if had:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	_finish({"real_input_checked":false})
