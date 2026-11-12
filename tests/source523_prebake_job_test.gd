extends SceneTree
## Authored metadata fixture only, no original art or redistribution proof.
const JOB = preload("res://scripts/boot/source523_prebake_job.gd")
const PREBAKE = preload("res://scripts/boot/source523_prebake.gd")
const UI_PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var job = JOB.new()
	check(job.poll().state == "idle" and job.result().is_empty(), "new worker is idle without completed work")
	check(job.start({}) == ERR_INVALID_PARAMETER and job.poll().state == "idle", "invalid work cannot start or count as complete")
	var base: String = "user://prebake_job_fixture"
	DirAccess.make_dir_recursive_absolute(base.path_join("originals/UI"))
	var member: String = "UI/Synthetic.csb"
	var raw: PackedByteArray = "metadata fixture only".to_utf8_buffer()
	var member_file := FileAccess.open(base.path_join("originals").path_join(member), FileAccess.WRITE)
	member_file.store_buffer(raw)
	member_file.close()
	var pin: String = "metadata fixture only".sha256_text()
	var value: Dictionary = {"schema":"twilight-original-ui-v1", "files":{member:{"sha256":pin,"bytes":raw.size()}},
		"scenes":{member:{"_source_sha256":pin,"_decode_blockers":[]}}, "atlases":{}, "blockers":[]}
	var manifest := FileAccess.open(base.path_join("original_ui.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify(value))
	manifest.close()
	var sha: String = FileAccess.get_sha256(base.path_join("original_ui.json"))
	var name: String = UI_PACK.bake_name_for(sha)
	BAKE.clear(name)
	var step: Dictionary = {"id":"ui", "label":"fixture", "root":base, "sha":sha}
	check(not UI_PACK.baked(sha), "cold fixture has no committed bake")
	check(job.start(step) == OK, "valid metadata verification starts on worker")
	check(job.start(step) == ERR_BUSY, "active/unjoined thread cannot be replaced")
	# Mutating caller data after launch cannot change worker identity or pin.
	step.sha = "0".repeat(64)
	var waited: int = 0
	while not job.completed() and waited < 300:
		waited += 1
		await process_frame
	var result: Dictionary = job.finish()
	check(result.get("ok", false) and result.get("baked", false), "cold worker verifies and commits complete metadata")
	check(job.poll().state == "complete" and job.completed(), "poll only reports complete after joined result")
	check(result.get("id") == "ui" and result.get("ms", -1) >= 0, "worker reports actual verification identity and elapsed measurement")
	check(UI_PACK.baked(sha), "complete worker cache is available to later readers")
	OS.set_environment("TWILIGHT_SOURCE_UI", base)
	OS.set_environment("TWILIGHT_SOURCE_UI_SHA256", sha)
	var pending: Array[Dictionary] = PREBAKE.pending()
	check(not pending.any(func(entry: Dictionary) -> bool: return entry.id == "ui"), "warm boot skips the exact completed pin")
	check(job.start(step) == OK, "failed pin verification can launch after prior join")
	var failed: Dictionary = job.finish()
	check(not failed.get("ok", true) and not failed.get("baked", true), "wrong manifest pin never succeeds or accepts old cache")
	step.sha = sha
	check(job.start(step) == OK and job.finish().get("ok", false), "retry of correct pin succeeds after failure")
	# Storage failure must not be mislabeled as a persisted bake.
	BAKE.clear(name)
	BAKE.fault = name + "|create"
	check(job.start(step) == OK, "storage-failure fixture starts")
	var storage: Dictionary = job.finish()
	check(storage.get("ok", false) and not storage.get("baked", true), "verification success and storage failure remain distinct")
	check(not UI_PACK.baked(sha), "no failed or partial cache is accepted")
	BAKE.fault = ""
	check(job.start(step) == OK and job.finish().get("baked", false), "storage retry commits and verifies the fixture bake")
	BAKE.clear(name)
	# Releasing an active owner must join rather than destroying a live Thread.
	var closing = JOB.new()
	check(closing.start(step) == OK, "shutdown fixture starts")
	closing = null
	check(UI_PACK.baked(sha), "owner shutdown joins an atomic verification before returning")
	BAKE.clear(name)
	OS.set_environment("TWILIGHT_SOURCE_UI", "")
	OS.set_environment("TWILIGHT_SOURCE_UI_SHA256", "")
	print("SOURCE523_PREBAKE_JOB_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"fixture":"synthetic_metadata_only"}))
	quit(0 if failures.is_empty() else 1)
