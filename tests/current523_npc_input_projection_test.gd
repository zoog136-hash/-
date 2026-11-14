extends SceneTree
## NPC input closure: row positions come from the relation group, and growing
## the selection one monster type at a time equals a full rebuild.
##   godot --headless --path <repo> --script res://tests/current523_npc_input_projection_test.gd
## The original-data part runs only when the 523 definition archive is
## installed; it is reported as "original":"not_installed" otherwise.
const PROJECTION = preload("res://scripts/monsters/current523_npc_input_projection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("NPC_INPUT_PROJECTION_FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

static func _canonical(value: Dictionary) -> String:
	var copy: Dictionary = value.duplicate(true)
	var rows: Array = copy.get("excluded_source_rows", [])
	rows.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a, "", true, true) < JSON.stringify(b, "", true, true))
	return JSON.stringify(copy, "", true, true)

func _run() -> void:
	var projection = PROJECTION.new()
	# Positions: every identical row of the group, 1-based, in table order.
	var a: Dictionary = {"ID": 7.0, "Value": 1.0}
	var b: Dictionary = {"ID": 7.0, "Value": 2.0}
	var group: Array = [a, b, a.duplicate()]
	check(projection._positions_in("T", a, PackedInt32Array([4, 9, 12]), group) == [5, 13], "identical rows in the group give every 1-based table position")
	check(projection._positions_in("T", b, PackedInt32Array([4, 9, 12]), group) == [10], "a distinct row gives its own position")
	check(projection._positions_in("T", {"ID": 8.0}, PackedInt32Array([4, 9, 12]), group).is_empty(), "a row outside the group has no position")
	check(not projection._keep("T", a, [5, 13]) and projection.problem.begins_with("source_row_identity_ambiguous"), "a duplicated ID row stays ambiguous")
	projection.problem = ""
	check(projection._keep("T", b, [10]) and projection._selected["T"]["7"].source_row_1based == 10, "a unique row is kept with its position")
	var evidence: Dictionary = {"original":"not_installed"}
	var identity: Dictionary = SOURCE.identity()
	if not identity.is_empty() and identity.get("source_sha256") == PROJECTION.SOURCE_SHA:
		evidence.original = "installed"
		var ids: Array = []
		for row: Dictionary in SOURCE.rows("NpcClass"):
			if CATALOG.definition_eligible(row) and not SOURCE.related("NpcAttack", "NpcClassID", int(row.ID)).is_empty(): ids.append(int(row.ID))
			if ids.size() >= 60: break
		var memory_before: int = OS.get_static_memory_usage()
		var started: int = Time.get_ticks_usec()
		var grown = PROJECTION.new()
		check(not grown.build([]).is_empty(), "the empty selection builds")
		var last: Dictionary = {}
		for index: int in ids.size():
			last = grown.extend(ids.slice(0, index + 1))
			if last.is_empty(): break
		evidence["extend_ms"] = (Time.get_ticks_usec() - started) / 1000
		evidence["memory_growth_mb"] = (OS.get_static_memory_usage() - memory_before) / 1048576
		check(not last.is_empty() and last.boss_npc_ids.size() == ids.size(), "every monster type extends the selection: " + grown.problem)
		var full: Dictionary = PROJECTION.new().build(ids)
		check(not full.is_empty() and _canonical(last) == _canonical(full), "one-at-a-time selection equals a full rebuild")
		var earlier: Dictionary = PROJECTION.new().build(ids.slice(0, 10))
		var again = PROJECTION.new()
		again.build(ids.slice(0, 10))
		var snapshot: String = _canonical(again._result())
		again.extend(ids.slice(0, 20))
		check(_canonical(earlier) == snapshot, "returned content does not change when the selection grows later")
		check(again.extend([-1]).is_empty() and again._ids.is_empty(), "a failed extension drops the partial selection")
		check(_canonical(again.extend(ids.slice(0, 20))) == _canonical(PROJECTION.new().build(ids.slice(0, 20))), "after a failure the next extension rebuilds in full")
		check(int(evidence.memory_growth_mb) < 200, "the closure does not materialize whole tables (%d MB)" % int(evidence.memory_growth_mb))
	print("NPC_INPUT_PROJECTION_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
