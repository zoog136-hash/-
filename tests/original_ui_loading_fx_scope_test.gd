extends SceneTree

const PACK := preload("res://scripts/ui/original_ui/source_pack.gd")
const BAKE := preload("res://scripts/resources/current523_bake_cache.gd")
const ATLAS_PAGE := "UI/atlas.png"
const UNRELATED_PAGE := "UI/other.png"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func _fixture(directory: String) -> Dictionary:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color8(30, 60, 90, 255))
	var payloads := {
		PACK.LOADING_FX_MEMBER: "authored CSB fixture".to_utf8_buffer(),
		PACK.LOADING_FX_ATLAS: "authored plist fixture".to_utf8_buffer(),
		PACK.LOADING_FX_FONT: "authored TTF fixture".to_utf8_buffer(),
		ATLAS_PAGE: image.save_png_to_buffer(),
		UNRELATED_PAGE: image.save_png_to_buffer(),
	}
	var files := {}
	for member: String in payloads:
		var file := directory.path_join("originals").path_join(member)
		_write(file, payloads[member])
		files[member] = {"sha256": FileAccess.get_sha256(file), "bytes": FileAccess.get_size(file)}
	var manifest := {
		"schema": "twilight-original-ui-v1", "blockers": [], "files": files,
		"atlases": {PACK.LOADING_FX_ATLAS: {"page": ATLAS_PAGE}},
		"scenes": {PACK.LOADING_FX_MEMBER: {
			"_source_sha256": files[PACK.LOADING_FX_MEMBER].sha256,
			"_decode_blockers": [], "nodeTree": {},
		}},
	}
	_write(directory.path_join("original_ui.json"), JSON.stringify(manifest).to_utf8_buffer())
	return payloads

func _changed_bytes(bytes: PackedByteArray) -> PackedByteArray:
	var corrupt := bytes.duplicate()
	corrupt[0] = corrupt[0] ^ 0xff
	return corrupt

func _run() -> void:
	var directory := "user://ui_loading_scope_test/%d" % Time.get_ticks_usec()
	var originals := directory.path_join("originals")
	var manifest_path := directory.path_join("original_ui.json")
	var payloads := _fixture(directory)
	var sha := FileAccess.get_sha256(manifest_path)
	var full := PACK.new()
	var scoped := PACK.new()
	_check(full.open(directory, sha).ok and PACK.baked(sha), "full verification establishes a bake")
	_check(scoped.open_loading_fx(directory, sha).ok, "selected bake can expose the loading scene")
	_check(scoped.scene(PACK.LOADING_FX_MEMBER) == full.scene(PACK.LOADING_FX_MEMBER), "same verified authored scene")
	_check(scoped.manifest.files.size() == 4 and not scoped.manifest.files.has(UNRELATED_PAGE), "only exact source dependencies")
	var outside := {"path": UNRELATED_PAGE, "resourceType": 0}
	var texture := full.texture(outside)
	_check(texture != null and scoped.texture(outside) == null, "full-pack shared texture cannot cross the loading scope")

	var outside_path := originals.path_join(UNRELATED_PAGE)
	_write(outside_path, _changed_bytes(payloads[UNRELATED_PAGE]))
	_check(PACK.new().open_loading_fx(directory, sha).ok, "a separate screen's unused page does not block the indicator")
	_check(PACK.new().open(directory, sha).get("error") == "source_hash_or_size:" + UNRELATED_PAGE, "HUD still rejects same-size corruption outside the loading scope")
	_write(outside_path, payloads[UNRELATED_PAGE])

	for member: String in [PACK.LOADING_FX_MEMBER, PACK.LOADING_FX_ATLAS, PACK.LOADING_FX_FONT, ATLAS_PAGE]:
		var path := originals.path_join(member)
		_write(path, _changed_bytes(payloads[member]))
		_check(PACK.new().open_loading_fx(directory, sha).get("error") == "source_hash_or_size:" + member, "scoped verification rejects changed bytes in " + member)
		_write(path, payloads[member])
	_check(PACK.new().open_loading_fx(directory, sha).ok, "retry after restoring originals")

	var manifest_bytes := FileAccess.get_file_as_bytes(manifest_path)
	_write(manifest_path, _changed_bytes(manifest_bytes))
	_check(PACK.new().open_loading_fx(directory, sha).get("error") == "manifest_hash_mismatch", "scope requires the pinned original manifest")
	_write(manifest_path, manifest_bytes)

	var bake := BAKE.verified_file(PACK.bake_name_for(sha), PACK.bake_key_for(sha))
	_write(bake, _changed_bytes(FileAccess.get_file_as_bytes(bake)))
	_check(PACK.new().open_loading_fx(directory, sha).get("error") == "original_ui_pack_not_baked", "scoped reader rejects same-size bake tampering")
	_check(PACK.new().open(directory, sha).ok, "full reader can recover from the verified original")
	_check(scoped.open(directory, sha).ok and scoped.texture(outside) != null, "successful full open releases the prior scope")
	print("ORIGINAL_UI_LOADING_FX_SCOPE_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
