extends SceneTree
## The cooked pack's effect index (written with compress(ZSTD)) is read back.
## decompress_dynamic has no ZSTD mode: on 523.652 the read failed every time
## ("len < 4"), the index stayed empty and every source effect was rejected.
##   godot --headless --path <repo> --script res://tests/cooked_effect_index_test.gd
const STORE = preload("res://scripts/resources/cooked_actor_store.gd")
const FORMAT = preload("res://scripts/resources/cooked_actor_format.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("COOKED_EFFECT_INDEX_FAIL: " + label)

func _initialize() -> void:
	var sha: String = "587b419b38fd9e66639b315788011c986439a005b2525942162ff71febc81eeb"
	var folder: String = OS.get_cache_dir().path_join("twilight_cooked_effect_index_test")
	var index: Dictionary = {"format": STORE.EFFECT_INDEX_FORMAT, "manifest_sha256": sha, "domains": {"a": [1, 2, 3]}, "compiled": {"a": true}, "excluded": {}}
	for i: int in 2000: index.domains["k%d" % i] = PackedInt32Array(range(i % 50))
	check(STORE.write_effect_index(folder.path_join(FORMAT.FORMAT_TAG).path_join(STORE.EFFECT_INDEX), index) == OK, "index written")
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(folder.path_join(FORMAT.FORMAT_TAG).path_join(STORE.EFFECT_INDEX))
	check(STORE.zstd_frame_bytes(raw, 256 * 1024 * 1024) == var_to_bytes(index), "the ZSTD frame decodes to the written bytes")
	check(STORE.zstd_frame_bytes(raw, 16).is_empty(), "a frame larger than the limit is refused")
	check(STORE.zstd_frame_bytes(PackedByteArray([1, 2, 3, 4, 5, 6, 7]), 1024).is_empty() and STORE.zstd_frame_bytes(var_to_bytes(index).compress(FileAccess.COMPRESSION_GZIP), 1 << 24).is_empty(), "non-ZSTD data is refused")
	STORE.root_override = folder
	STORE._root_known = false
	STORE._effect_index_root = "-"
	var loaded: Dictionary = STORE.effect_index(sha)
	check(loaded.get("format") == STORE.EFFECT_INDEX_FORMAT and (loaded.get("domains", {}) as Dictionary).size() == index.domains.size(), "effect_index() loads the pinned index")
	check(STORE.effect_index("0".repeat(64)).is_empty(), "another bank manifest gets no index")
	STORE.root_override = ""
	STORE._root_known = false
	STORE._effect_index_root = "-"
	print("COOKED_EFFECT_INDEX_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
