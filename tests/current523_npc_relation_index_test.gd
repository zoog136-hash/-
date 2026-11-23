extends SceneTree
## Synthetic on/off lazy NPC index equivalence, never original 523 proof.
## Run with a disposable XDG_DATA_HOME (as tools/ci_core.py does).
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
var checks: int = 0
var failures: Array[String] = []
var timings: Dictionary = {}
const COUNT: int = 6000
const PATH := "user://npc-preparation-synthetic.zip"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _open_fixture() -> void:
	ROWS.reset()
	OS.set_environment("TWILIGHT_PATCH523_CONTENT", PATH)
	ROWS._archive = ZIPReader.new()
	check(ROWS._archive.open(PATH) == OK, "fixture archive opens")
	ROWS._archive_path = PATH
	# Explicit fixture injection, no modification of the production SHA pin.
	ROWS._verified_sha = "synthetic-npc-preparation-only"
	ROWS._verified_bytes = FileAccess.open(PATH, FileAccess.READ).get_length()

func _clear_bakes() -> void:
	for table: String in ROWS.ENCOUNTER_RELATIONS:
		BAKE.clear("disk_" + table)
		BAKE.clear(ROWS._relation_name(table, ROWS.ENCOUNTER_RELATIONS[table]))

func _query() -> Array:
	var result: Array = []
	for table: String in ROWS.ENCOUNTER_RELATIONS:
		result.append(ROWS.related(table, ROWS.ENCOUNTER_RELATIONS[table], 7))
	return result

func _run() -> void:
	var zip := ZIPPacker.new()
	check(zip.open(PATH) == OK, "fixture authoring")
	var metadata: Array = []
	for table: String in ROWS.ENCOUNTER_RELATIONS:
		var rows: Array = []
		for i: int in COUNT:
			rows.append({"ID": i, "NpcClassID": i / 60, "Value": i * 3, "Text": "fixture", "Nested": [i, {"a": true}]})
		var bytes: PackedByteArray = ("\ufeff" + JSON.stringify({"rows": rows})).to_utf8_buffer()
		zip.start_file("content/" + table + ".json")
		zip.write_file(bytes); zip.close_file()
		metadata.append({"path": "content/" + table + ".json", "row_count": COUNT})
	zip.start_file("index.json")
	zip.write_file(JSON.stringify(metadata).to_utf8_buffer()); zip.close_file(); zip.close()
	_open_fixture()
	ROWS.related("NpcAttack", "NpcClassID", 7)
	check(ROWS._tables.keys() == ["NpcAttack"], "only the requested table opens; SpellClass remains lazy")
	var expected: PackedByteArray
	var expected_indexes: PackedByteArray
	for enabled: bool in [false, true]:
		OS.set_environment("TWILIGHT_NPC_RELATION_FAST", "1" if enabled else "0")
		_open_fixture(); _clear_bakes()
		for state: String in ["cold", "restart"]:
			if state == "restart": _open_fixture()
			var builds: int = ROWS.npc_fast_index_builds
			var started: int = Time.get_ticks_usec()
			var rows: Array = _query()
			var elapsed: float = (Time.get_ticks_usec() - started) / 1000.0
			timings[("on_" if enabled else "off_") + state + "_total_ms"] = elapsed
			if not enabled and state == "cold":
				expected = var_to_bytes(rows)
				expected_indexes = var_to_bytes(ROWS._relations)
			check(var_to_bytes(rows) == expected, "complete rows equal: %s %s" % [enabled, state])
			check(var_to_bytes(ROWS._relations) == expected_indexes, "byte-identical index representation: %s %s" % [enabled, state])
			check(ROWS.npc_fast_index_builds - builds == (4 if enabled and state == "cold" else 0), "only cold queried indexes are built")
			rows[0][0].Nested.append(999)
			check(var_to_bytes(_query()) == expected, "fresh nested values")
			ROWS._relations["Other:ID"] = {"groups": {1: PackedInt32Array([0])}}
			var released: Dictionary = ROWS.release_caches()
			check(released.encounter_indexes == (4 if enabled else 0), "on/off release policy")
			check(not ROWS._relations.has("Other:ID"), "unrelated indexes released")
			for table: String in ROWS.ENCOUNTER_RELATIONS:
				check(ROWS._tables[table].disk.loaded.is_empty(), "columns released")
	# Edge cases compare to the unchanged builder, including table order.
	for values: Array in [[], [0.0], [-2.0,-2.0,0.0,7.0], [7.0,-2.0,7.0,0.0,-2.0],
		[1.0,1.5], [INF], [NAN], [4398046511104.0], [-4398046511104.0],
		[4398046511103.0,-4398046511103.0]]:
		var column := PackedFloat64Array(values)
		var fast: Dictionary = ROWS._npc_compact_relation(column)
		var valid: bool = true
		for value: float in column:
			if not ROWS._integer(value) or absf(value) >= ROWS.RELATION_VALUE_LIMIT: valid = false
		check(not fast.is_empty() == valid, "typed validation matches integer/compact bounds")
		if not valid: continue
		var rows: Array = []
		for i: int in values.size(): rows.append({"ID":float(i), "NpcClassID":values[i]})
		ROWS._tables.NpcAttack = ROWS._pack(rows)
		ROWS._relations.erase("NpcAttack:NpcClassID")
		OS.set_environment("TWILIGHT_NPC_RELATION_FAST", "0")
		ROWS.related("NpcAttack", "NpcClassID", 7)
		check(var_to_bytes(fast) == var_to_bytes(ROWS._relations["NpcAttack:NpcClassID"]), "sorted and unsorted complete indexes equal")
	var huge := PackedInt32Array()
	huge.resize(ROWS.ENCOUNTER_INDEX_BYTES / 4 + 1)
	ROWS._relations = {"NpcAttack:NpcClassID": {"keys": PackedInt64Array(), "starts": PackedInt32Array(), "rows": huge}}
	check(ROWS._encounter_indexes().is_empty(), "bounded retention")
	OS.set_environment("TWILIGHT_PATCH523_CONTENT", "user://missing-npc-source.zip")
	check(ROWS.related_indices("NpcAttack", "NpcClassID", 7).is_empty() and ROWS._relations.is_empty(), "source change rejects retained index")
	ROWS.reset()
	OS.set_environment("TWILIGHT_PATCH523_CONTENT", PATH)
	check(ROWS.related("NpcAttack", "NpcClassID", 7).is_empty(), "unverified fixture is rejected without injection")
	OS.unset_environment("TWILIGHT_PATCH523_CONTENT")
	OS.unset_environment("TWILIGHT_NPC_RELATION_FAST")
	_clear_bakes(); DirAccess.remove_absolute(PATH)
	print("NPC_RELATION_INDEX_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "synthetic_only": timings}))
	quit(0 if failures.is_empty() else 1)
