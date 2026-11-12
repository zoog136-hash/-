extends SceneTree
## Synthetic (no original data): a skill buff's original BuffClass icon may be
## read from either loaded skill evidence the skill owner supports, the compiled
## pack (active_sha256) or profiles bound from the installed original 523
## definition archive (source_mode "original_bound_profiles", active_sha256
## empty by design). Before, only the first counted, so with the original ZIP
## installed every skill buff row in the HUD (e.g. 실드 "1585s") had no icon.
const ICONS = preload("res://scripts/ui/source523_skill_buff_images.gd")
const SOURCE = preload("res://scripts/skills/player_skills523.gd")
var checks: int = 0
var failures: Array[String] = []

class FakeSource extends RefCounted:
	var active_sha256: String = ""
	var source_mode: String = ""
	var source_identity: Dictionary = {}
	var source_fallback_status: Dictionary = {}
	func evidence_for(_id: String) -> Dictionary: return {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SOURCE523_BUFF_EVIDENCE_MODE_FAIL: ", label)

func bound(host: String) -> FakeSource:
	var source := FakeSource.new()
	source.source_mode = "original_bound_profiles"
	source.source_identity = {"kind":"twilight.current523.original-definitions.v1","source_snapshot":"patch523","source_sha256":SOURCE.SOURCE_SHA,"source_bytes":25031173}
	source.source_fallback_status = {"state":"loaded","applied":[host],"deferred":{}}
	return source

func run() -> void:
	check(ICONS.source_evidence(null, "x").get("reason") == "native_buff_relation_unavailable", "no skill owner -> unavailable")
	var compiled := FakeSource.new()
	compiled.active_sha256 = "a".repeat(64)
	var result: Dictionary = ICONS.source_evidence(compiled, "x")
	check(result.get("mode") == "compiled_pack" and result.get("sha256") == "a".repeat(64), "compiled pack keeps its fingerprint: %s" % result)
	result = ICONS.source_evidence(bound("lm_shield"), "lm_shield")
	check(result.get("mode") == "original_bound_profiles" and result.get("sha256") == SOURCE.SOURCE_SHA, "installed original archive profiles are accepted: %s" % result)
	check(ICONS.source_evidence(bound("lm_other"), "lm_shield").has("reason"), "a skill the owner did not apply is not accepted")
	var deferred := bound("lm_shield")
	deferred.source_fallback_status.deferred = {"lm_shield":"held_source_material:x"}
	check(ICONS.source_evidence(deferred, "lm_shield").has("reason"), "a deferred skill is not accepted")
	var other_archive := bound("lm_shield")
	other_archive.source_identity.source_sha256 = "b".repeat(64)
	check(ICONS.source_evidence(other_archive, "lm_shield").has("reason"), "a different archive is not accepted")
	var not_loaded := bound("lm_shield")
	not_loaded.source_fallback_status.state = "deferred"
	check(ICONS.source_evidence(not_loaded, "lm_shield").has("reason"), "unloaded profiles are not accepted")
	var no_mode := bound("lm_shield")
	no_mode.source_mode = ""
	check(ICONS.source_evidence(no_mode, "lm_shield").has("reason"), "without a supported mode nothing is accepted")
	print("SOURCE523_BUFF_EVIDENCE_MODE_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
