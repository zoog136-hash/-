extends SceneTree
## Synthetic table conversion/index retention only, never original 523 proof.
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

func _prepare() -> void:
	for table: String in ROWS.encounter_tables_to_prepare():
		check(ROWS.prepare_encounter_table(table), "prepare " + table)
		ROWS.release_caches()

func _run() -> void:
	var zip := ZIPPacker.new()
	check(zip.open(PATH) == OK, "fixture authoring")
	var metadata: Array = []
	for table: String in ROWS.ENCOUNTER_RELATIONS:
		var rows: Array = []
		for i: int in COUNT:
			rows.append({"ID": i, "NpcClassID": i % 100, "Value": i * 3, "Text": "fixture", "Nested": [i, {"a": true}]})
		var bytes: PackedByteArray = ("\ufeff" + JSON.stringify({"rows": rows})).to_utf8_buffer()
		zip.start_file("content/" + table + ".json")
		zip.write_file(bytes)
		zip.close_file()
		metadata.append({"path": "content/" + table + ".json", "row_count": COUNT})
	zip.start_file("index.json")
	zip.write_file(JSON.stringify(metadata).to_utf8_buffer())
	zip.close_file()
	zip.close()
	_open_fixture()
	_clear_bakes()
	var started: int = Time.get_ticks_usec()
	var expected: Array = _query()
	timings.cold_unprepared_ms = (Time.get_ticks_usec() - started) / 1000.0
	check(expected[0].size() == 60 and expected[3].size() == 1, "owner multiplicity and unique spell ID")
	ROWS.reset()
	_clear_bakes()
	_open_fixture()
	var memory_before: int = OS.get_static_memory_usage()
	started = Time.get_ticks_usec()
	_prepare()
	timings.cold_prepare_ms = (Time.get_ticks_usec() - started) / 1000.0
	timings.retained_memory_bytes = OS.get_static_memory_usage() - memory_before
	check(ROWS.encounter_tables_to_prepare().is_empty(), "same-process preparation is complete")
	check(not ROWS.prepare_encounter_table("Bonus"), "no broad closure preparation")
	var generation: int = ROWS.cache_generation()
	ROWS._relations["Other:ID"] = {"groups": {1: PackedInt32Array([0])}}
	var released: Dictionary = ROWS.release_caches()
	check(released.encounter_indexes == 4 and not ROWS._relations.has("Other:ID"), "only bounded NPC indexes survive World release")
	check(ROWS.cache_generation() == generation, "release is not source invalidation")
	for table: String in ROWS.ENCOUNTER_RELATIONS:
		check(ROWS._tables[table].disk.loaded.is_empty(), "columns released: " + table)
	started = Time.get_ticks_usec()
	var received: Array = _query()
	timings.prepared_query_ms = (Time.get_ticks_usec() - started) / 1000.0
	check(var_to_bytes(received) == var_to_bytes(expected), "prepared complete rows equal cold reads")
	var edited: Array = _query()
	edited[0][0].Nested.append(999)
	check(var_to_bytes(_query()) == var_to_bytes(expected), "returned nested values stay independent")
	# Restart-equivalent reader reset: stored tables/indexes must be reused.
	_open_fixture()
	var disk_reads: int = ROWS.relation_disk_reads
	started = Time.get_ticks_usec()
	_prepare()
	timings.restart_prepare_ms = (Time.get_ticks_usec() - started) / 1000.0
	check(ROWS.relation_disk_reads - disk_reads == 4, "existing verified relation bakes reused")
	check(var_to_bytes(_query()) == var_to_bytes(expected), "restart rows unchanged")
	var old_key: String = ROWS._relation_key("NpcAttack", "NpcClassID")
	ROWS._verified_sha = "different-synthetic-source"
	check(ROWS._relation_key("NpcAttack", "NpcClassID") != old_key, "measured source identity changes relation key")
	check(ROWS._read_relation("NpcAttack", "NpcClassID", ROWS._tables.NpcAttack).is_empty(), "stale source index rejected")
	ROWS._verified_sha = "synthetic-npc-preparation-only"
	var path: String = BAKE.verified_file(ROWS._relation_name("NpcAttack", "NpcClassID"), old_key)
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	var byte: int = file.get_8()
	file.seek(0); file.store_8(byte ^ 1); file.close()
	check(ROWS._read_relation("NpcAttack", "NpcClassID", ROWS._tables.NpcAttack).is_empty(), "same-size corrupt relation bake rejected")
	# Never retain an oversized compact index or a dictionary fallback.
	var huge := PackedInt32Array()
	huge.resize(ROWS.ENCOUNTER_INDEX_BYTES / 4 + 1)
	ROWS._relations = {"NpcAttack:NpcClassID": {"keys": PackedInt64Array(), "starts": PackedInt32Array(), "rows": huge},
		"SpellClass:ID": {"groups": {1: PackedInt32Array([0])}}}
	check(ROWS._encounter_indexes().is_empty(), "retention budget and compact-only policy")
	_open_fixture()
	_clear_bakes()
	BAKE.fault = "disk_NpcAttack|commit"
	check(not ROWS.prepare_encounter_table("NpcAttack"), "failed disk publish is not prepared")
	check(not ROWS._relations.has("NpcAttack:NpcClassID") and not ROWS._tables.has("NpcAttack"), "failed bake retains no whole table or index")
	BAKE.fault = ""
	check(not ROWS.prepare_encounter_table("NpcAttack"), "failed conversion is not retried during the same lifetime")
	_open_fixture()
	check(ROWS.prepare_encounter_table("NpcAttack"), "new lifetime retries a failed conversion")
	OS.set_environment("TWILIGHT_PATCH523_CONTENT", "user://missing-npc-source.zip")
	check(ROWS.related_indices("NpcAttack", "NpcClassID", 7).is_empty(), "direct retained-index read verifies the current source")
	check(ROWS.encounter_tables_to_prepare().is_empty() and ROWS._relations.is_empty(), "changed source path invalidates retained indexes")
	ROWS.reset()
	check(ROWS._relations.is_empty(), "reset discards retained indexes")
	OS.set_environment("TWILIGHT_PATCH523_CONTENT", PATH)
	check(ROWS.encounter_tables_to_prepare().is_empty(), "unverified archive cannot prepare")
	check(not ROWS.prepare_encounter_table("NpcAttack"), "unverified archive cannot read baked data")
	OS.set_environment("TWILIGHT_PATCH523_CONTENT", "")
	check(ROWS.encounter_tables_to_prepare().is_empty(), "explicit empty source preserves degraded behavior")
	ROWS.reset()
	OS.unset_environment("TWILIGHT_PATCH523_CONTENT")
	_clear_bakes()
	DirAccess.remove_absolute(PATH)
	print("NPC_PREPARATION_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "synthetic_only": timings}))
	quit(0 if failures.is_empty() else 1)
