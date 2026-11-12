extends SceneTree
## Standalone synthetic check: the original UI pack's device bake is keyed by
## source_pack_manifest.gd only, so connecting another window in
## source_pack.gd (CODE_EXTERNAL_TEXTURE_NODES) does not re-verify the pack on
## every app update; code-declared texture nodes are merged after loading and
## are never stored in the bake.
##   godot --headless --path <repo> --script res://tests/original_ui_bake_key_test.gd
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const MANIFEST = preload("res://scripts/ui/original_ui/source_pack_manifest.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const CODE_MEMBER := "UI/CommonUi/Common_Slot.csb"
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("ORIGINAL_UI_BAKE_KEY_FAIL: " + label)

func write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(PACK.CODE_EXTERNAL_TEXTURE_NODES.has(CODE_MEMBER), "the fixture member is a code-declared texture node")
	var directory: String = "user://original_ui_bake_key_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var member_path: String = directory.path_join("originals/" + CODE_MEMBER)
	write_bytes(member_path, ("slot %d" % Time.get_ticks_usec()).to_utf8_buffer())
	var files: Dictionary = {CODE_MEMBER: {"sha256": FileAccess.get_sha256(member_path), "bytes": FileAccess.get_size(member_path)}}
	var manifest: Dictionary = {"schema": "twilight-original-ui-v1", "scenes": {}, "files": files, "blockers": [], "atlases": {}}
	var manifest_path: String = directory.path_join("original_ui.json")
	write_bytes(manifest_path, JSON.stringify(manifest).to_utf8_buffer())
	var sha: String = FileAccess.get_sha256(manifest_path)
	# Key: manifest pin + the manifest module's code, not source_pack.gd.
	var expected: String = BAKE.key([MANIFEST.FORMAT, sha, BAKE.code_key(["res://scripts/ui/original_ui/source_pack_manifest.gd"])])
	check(PACK.bake_key_for(sha) == expected, "the bake key is the manifest pin and source_pack_manifest.gd")
	check(PACK.bake_key_for(sha) != BAKE.key(["original_ui_pack.v1", sha, BAKE.code_key(["res://scripts/ui/original_ui/source_pack.gd"])]), "the bake key no longer depends on source_pack.gd")
	check(not FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_pack_manifest.gd").contains("CODE_EXTERNAL_TEXTURE_NODES ="), "code declarations live outside the keyed module")
	var name: String = PACK.bake_name_for(sha)
	BAKE.clear(name)
	var prior: bool = PACK.bake_enabled
	PACK.bake_enabled = true
	var fresh: RefCounted = PACK.new()
	check(fresh.open(directory, sha).get("ok", false), "a fresh pack opens and writes its bake")
	check(BAKE.present(name, PACK.bake_key_for(sha)), "the bake is present after the first open")
	check((fresh.manifest.get("externally_bound_texture_nodes", {}) as Dictionary).get(CODE_MEMBER, []) == PACK.CODE_EXTERNAL_TEXTURE_NODES[CODE_MEMBER], "a fresh open merges code-declared texture nodes")
	var records: RefCounted = BAKE.open_records(name, PACK.bake_key_for(sha))
	var stored: Variant = records.read("meta") if records != null else null
	check(stored is Dictionary, "the stored meta record is readable")
	check(stored is Dictionary and not (stored as Dictionary).has("externally_bound_texture_nodes"), "the bake stores the pack's own declarations only")
	var baked: RefCounted = PACK.new()
	check(baked.open(directory, sha).get("ok", false), "a second open uses the bake")
	check((baked.manifest.get("externally_bound_texture_nodes", {}) as Dictionary).get(CODE_MEMBER, []) == PACK.CODE_EXTERNAL_TEXTURE_NODES[CODE_MEMBER], "a baked open merges the current code-declared texture nodes")
	check(baked.manifest.get("files") == fresh.manifest.get("files") and baked.manifest.get("scenes") == fresh.manifest.get("scenes"), "baked and fresh opens expose the same manifest")
	# A changed original still refuses the bake and fails verification.
	write_bytes(member_path, "changed bytes".to_utf8_buffer())
	var changed: RefCounted = PACK.new()
	check(not changed.open(directory, sha).get("ok", true), "a changed original is refused")
	PACK.bake_enabled = prior
	BAKE.clear(name)
	print("ORIGINAL_UI_BAKE_KEY_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
