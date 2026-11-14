extends SceneTree
## Optional RUN/HIT probe verdicts are reused while the manifest stays pinned,
## re-checked when it is not, and bounded (oldest first).
##   godot --headless --path <repo> --script res://tests/optional_role_probe_memo_test.gd
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const PATH := "user://optional_role_probe_memo_test.json"
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("OPTIONAL_ROLE_PROBE_MEMO_FAIL: " + label)

static func _key(path: String, sha: String, role: String) -> String:
	return var_to_str([path, sha, 7, role, 3, true, "npc", 7])

func _initialize() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{\"schema\":1}")
	file.close()
	var sha: String = FileAccess.get_sha256(PATH)
	PREVIEW._optional_probe_memo.clear()
	# A remembered verdict for a pinned manifest is returned without a bank load.
	PREVIEW._optional_probe_memo[_key(PATH, sha, "run")] = {"ok": true, "error": ""}
	var hit: Dictionary = PREVIEW._optional_role_probe(PATH, sha, 7, "run", 3, true, "npc", 7)
	check(hit.ok == true, "pinned manifest: the remembered verdict is reused")
	# Not remembered: the real probe runs and its verdict is kept.
	var probed: Dictionary = PREVIEW._optional_role_probe(PATH, sha, 7, "hit", 3, true, "npc", 7)
	check(probed.ok == false and not str(probed.error).is_empty(), "an invalid bank is rejected by the real probe: " + str(probed.error))
	check(PREVIEW._optional_probe_memo.has(_key(PATH, sha, "hit")), "the probe verdict is remembered")
	# A changed manifest is no longer pinned: the remembered verdict is ignored.
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{\"schema\":22}")
	file.close()
	PREVIEW._optional_probe_memo[_key(PATH, sha, "run")] = {"ok": true, "error": ""}
	var stale: Dictionary = PREVIEW._optional_role_probe(PATH, sha, 7, "run", 3, true, "npc", 7)
	check(stale.ok == false, "a manifest that changed is probed again, not served from memory")
	# Bounded: the oldest entry leaves first.
	PREVIEW._optional_probe_memo.clear()
	for index: int in PREVIEW.OPTIONAL_PROBE_MEMO_MAX: PREVIEW._optional_probe_memo["old%d" % index] = {"ok": true, "error": ""}
	PREVIEW._optional_role_probe(PATH, sha, 7, "death", 3, true, "npc", 7)
	check(PREVIEW._optional_probe_memo.size() == PREVIEW.OPTIONAL_PROBE_MEMO_MAX, "the memo stays at its bound")
	check(not PREVIEW._optional_probe_memo.has("old0") and PREVIEW._optional_probe_memo.has("old1"), "the oldest entry is evicted first")
	PREVIEW._optional_probe_memo.clear()
	DirAccess.remove_absolute(PATH)
	print("OPTIONAL_ROLE_PROBE_MEMO_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
