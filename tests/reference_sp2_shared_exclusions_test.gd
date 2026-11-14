extends SceneTree
## Every monster bank of one pinned manifest shares one frozen copy of the
## source dummy exclusion registry (it was deep-copied per bank, ~3 MB each).
## Synthetic fixture from reference_sp2_load_memo_test.gd.
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const ASSETS = preload("res://scripts/resources/reference_sp2_asset_service.gd")
const MEMO_TEST = preload("res://tests/reference_sp2_load_memo_test.gd")
const ACTOR: int = 9001
const DUMMY: int = 9100
const BINDINGS: Dictionary = {"idle": 0, "attack": 3}
const LOOPS: Dictionary = {"idle": true, "attack": false}

var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func exclusion(sprite: int) -> Dictionary:
	return {"source_snapshot": "patch523", "reason": "source_literal_dummy", "originals_preserved": true, "raw_member_namespace_excluded": false,
		"dummy_declarations": [{"sprite_id": sprite, "literal_name": "dummy_%d" % sprite, "literal_declaration": "dummy_%d %d" % [sprite, sprite], "matched_literal": "dummy", "source_file": "list_9.spr", "source_line": 1, "source_sha256": "a".repeat(64)}],
		"source_graph_paths": [{"kind": "source_declared_root", "sprite_ids": [sprite]}]}

## The registry as the manifest JSON stores it (numbers read back as floats).
func stored(sprite: int) -> Dictionary:
	return JSON.parse_string(JSON.stringify(exclusion(sprite)))

func with_exclusions(data: Dictionary, sprites: Array) -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data.path))
	var registry: Dictionary = {}
	for sprite: int in sprites: registry["sprite:%d" % sprite] = exclusion(sprite)
	manifest["excluded_source_actors"] = registry
	var file := FileAccess.open(data.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	var result: Dictionary = data.duplicate()
	result["sha"] = FileAccess.get_sha256(data.path)
	return result

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scratch: String = "user://reference_sp2_shared_exclusions_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ASSETS.reset_for_tests()
	BANK.forget_verified_members()
	var helper: Object = MEMO_TEST.new()
	var data: Dictionary = with_exclusions(helper.fixture(scratch.path_join("a")), [DUMMY])
	var first: RefCounted = BANK.new()
	var second: RefCounted = BANK.new()
	var loaded_first: Dictionary = first.load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS)
	var loaded_second: Dictionary = second.load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS)
	check(loaded_first.get("ok", false) and loaded_second.get("ok", false), "both banks load: " + str(loaded_first.get("error", "")) + str(loaded_second.get("error", "")))
	var shared: Dictionary = first._excluded_source_actors
	check(is_same(shared, second._excluded_source_actors), "two banks of one manifest hold the same exclusion registry object")
	check(shared.is_read_only() and (shared["sprite:%d" % DUMMY] as Dictionary).is_read_only(), "the shared registry is frozen")
	check(shared.keys() == ["sprite:%d" % DUMMY] and shared["sprite:%d" % DUMMY] == stored(DUMMY), "shared registry equals the manifest registry")
	check(first.source_actor_admission(ACTOR).get("ok", false), "a normal actor is admitted")
	var denied: Dictionary = second.source_actor_admission(DUMMY)
	check(not denied.get("ok", true) and denied.get("source_exclusion") == stored(DUMMY), "a declared dummy actor is excluded with its evidence")
	(denied.source_exclusion as Dictionary)["reason"] = "changed"
	check(shared["sprite:%d" % DUMMY].reason == "source_literal_dummy", "the evidence handed out is a copy; the shared registry is unchanged")
	# Prepared (snapshot) path: a later bank of the same request reuses the copy.
	var third: RefCounted = BANK.new()
	var fourth: RefCounted = BANK.new()
	var shared_first: Dictionary = third.load_shared_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "test")
	var shared_second: Dictionary = fourth.load_shared_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS, "test")
	check(shared_first.get("ok", false) and shared_second.get("ok", false), "prepared banks load: " + str(shared_first.get("error", "")))
	check(is_same(third._excluded_source_actors, shared) and is_same(fourth._excluded_source_actors, shared), "prepared banks share the same registry object")
	check(not fourth.source_actor_admission(DUMMY).get("ok", true), "a prepared bank still excludes the dummy actor")
	# A different manifest gets its own registry, never the previous one.
	var other: Dictionary = with_exclusions(helper.fixture(scratch.path_join("b")), [DUMMY, DUMMY + 1])
	var fifth: RefCounted = BANK.new()
	check(fifth.load_bank(other.path, other.sha, ACTOR, BINDINGS, LOOPS).get("ok", false), "bank of another manifest loads")
	check(fifth._excluded_source_actors.size() == 2 and not is_same(fifth._excluded_source_actors, shared), "another manifest's registry is its own")
	check(not fifth.source_actor_admission(DUMMY + 1).get("ok", true), "another manifest's extra dummy is excluded")
	# Reloading a bank (clear path) does not fail on the read-only registry.
	check(first.load_bank(data.path, data.sha, ACTOR, BINDINGS, LOOPS).get("ok", false), "reloading a bank replaces its shared registry without mutating it")
	first.load_static(data.path, data.sha, ACTOR)
	check(first._excluded_source_actors.is_empty() or is_same(first._excluded_source_actors, shared), "static load path replaces the registry reference without mutating it")
	helper.free()
	print("REFERENCE_SP2_SHARED_EXCLUSIONS_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
