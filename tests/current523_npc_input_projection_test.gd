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

func _check_ordered_id_lookup() -> void:
	var relation := {"ordered_ids": PackedFloat64Array([-3, 10, 12])}
	for id: int in [-4, -3, 9, 10, 11, 12, 13]:
		var expected: int = relation.ordered_ids.find(float(id))
		check(SOURCE._unique_relation_row(relation, id) == expected, "unique ordered ID lookup %d" % id)
		var positions := PackedInt32Array([expected]) if expected >= 0 else PackedInt32Array()
		check(SOURCE._relation_rows(relation, id) == positions, "ordered source positions %d" % id)
	var disk := SOURCE.DiskTable.new()
	var different := PackedFloat64Array()
	different.resize(217916)
	disk.loaded[0] = different
	var store := {"columns": PackedStringArray(["ID"]), "count": different.size(), "disk": disk}
	check(SOURCE._ordered_bonus_ids(store).is_empty(), "matching row count alone cannot admit a different column")

func _check_original_bonus_ids() -> void:
	var ids: PackedFloat64Array = SOURCE.column("Bonus", "ID")
	check(ids.size() == 217916, "complete pinned Bonus ID column")
	if ids.is_empty(): return
	var previous: float = -INF
	var ordered := true
	for value: float in ids:
		if not SOURCE._integer(value) or value <= previous:
			ordered = false
			break
		previous = value
	check(ordered, "every original Bonus ID is strictly increasing and integral")
	var selected := {}
	var expected_rows: Array[Dictionary] = []
	for pos: int in [0, ids.size() / 2, ids.size() - 1]:
		var id := int(ids[pos])
		var row := SOURCE.row_at("Bonus", pos)
		selected[id] = true
		expected_rows.append(row)
		check(SOURCE.related_indices("Bonus", "ID", id) == PackedInt32Array([pos]), "actual Bonus table position")
		check(SOURCE.related("Bonus", "ID", id) == [row] and SOURCE.row("Bonus", id) == row, "same original row via both readers")
	check(SOURCE._relations.get("Bonus:ID", {}).has("ordered_ids"), "verified original column backs the lookup")
	check(SOURCE.rows_matching("Bonus", "ID", selected) == expected_rows, "multiple requested IDs retain table order")
	check(SOURCE.related_indices("Bonus", "ID", int(ids[-1]) + 1).is_empty(), "missing original Bonus ID stays missing")
	SOURCE.release_caches()
	check(not SOURCE._relations.has("Bonus:ID"), "World cache release drops the column index")
	check(SOURCE.row("Bonus", int(ids[0])) == expected_rows[0], "original row can be read again after release")

func _run() -> void:
	_check_ordered_id_lookup()
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
		_check_original_bonus_ids()
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
