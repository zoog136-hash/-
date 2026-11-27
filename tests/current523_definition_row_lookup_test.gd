extends SceneTree
## Fresh-row and rejection equivalence against the former row()->related()
## implementation. Synthetic fixtures do not prove original-resource delivery.
## Optional --row-lookup-original=<verified archive> compares real ItemClass
## reads and full serialized output hashes; timings never determine pass/fail.
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const SEED = preload("res://scripts/boot/startup_bake_pack.gd")
var checks: int = 0
var failures: Array[String] = []
var measurements: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

## The unchanged pre-optimization implementation, including rejection text.
func reference(table: String, id: int) -> Dictionary:
	var matches: Array[Dictionary] = ROWS.related(table,"ID",id)
	if matches.size() != 1:
		if matches.size() > 1: ROWS._problem = "원본 ID가 중복됩니다: " + table + "#" + str(id)
		elif ROWS._tables.has(table): ROWS._problem = "원본 ID가 없습니다: " + table + "#" + str(id)
		return {}
	return matches[0]

func same(table: String, id: int, label: String, clear_index: bool = false) -> void:
	if clear_index: ROWS._relations.erase(table + ":ID")
	ROWS._problem = "previous problem"
	var old: Dictionary = reference(table, id)
	var old_problem: String = ROWS.problem()
	if clear_index: ROWS._relations.erase(table + ":ID")
	ROWS._problem = "previous problem"
	var current: Dictionary = ROWS.row(table, id)
	check(var_to_bytes(current) == var_to_bytes(old), "complete ordered row bytes: " + label)
	check(ROWS.problem() == old_problem, "same problem/rejection: " + label)

func _fixture_open() -> void:
	# Only fixtures below are seeded; the real-source branch uses normal
	# _open(), SHA, byte count, table conversion and bake validation.
	ROWS.reset()
	var path: String = "user://synthetic-row-fixture.zip"
	var fixture := ZIPPacker.new()
	check(fixture.open(path) == OK, "synthetic archive opened for authoring")
	fixture.start_file("synthetic_metadata_only.txt")
	fixture.write_file("no original data".to_utf8_buffer())
	fixture.close_file()
	fixture.start_file("content/ZzSeedLookup.json")
	fixture.write_file(JSON.stringify({"rows":[{"ID":1,"Name":"raw table"}]}).to_utf8_buffer())
	fixture.close_file()
	fixture.close()
	OS.set_environment("TWILIGHT_PATCH523_CONTENT", path)
	ROWS._archive = ZIPReader.new()
	check(ROWS._archive.open(path) == OK, "synthetic archive opens for fixture isolation")
	ROWS._archive_path = path
	ROWS._verified_sha = "synthetic_fixture_only"
	ROWS._verified_bytes = 0

func _run() -> void:
	var initial_generation: int = ROWS.cache_generation()
	ROWS.reset()
	var empty_reset_generation: int = ROWS.cache_generation()
	check(empty_reset_generation > initial_generation, "reset advances generation even with no open archive")
	_fixture_open()
	check(ROWS.cache_generation() > empty_reset_generation, "every reset advances generation monotonically")
	var regular: Array = [{"ID":1.0,"Name":"one","Nested":{"a":[1,2]},"List":[{"n":1}]},
		{"ID":2.0,"Name":"two","Nested":{"a":[3]},"List":[]}]
	ROWS._tables.ZzLookup = ROWS._pack(regular)
	for cold: bool in [true, false]:
		for id: int in [1,2,0,-1,999]: same("ZzLookup", id, "packed %d cold %s" % [id,cold], cold)
	var row: Dictionary = ROWS.row("ZzLookup", 1)
	row.Nested.a.append(99)
	row.List[0].n = 99
	row.Name = "edited"
	check(var_to_bytes(ROWS.row("ZzLookup",1)) == var_to_bytes(regular[0]), "nested mutation never changes a later fresh row")
	# The repeated reference-row path must return freshly owned nested values.
	ROWS._tables.BonusType = ROWS._pack(regular)
	same("BonusType",1,"reused source reference",true)
	var cached_join: Array[Dictionary] = ROWS.related("BonusType","ID",1)
	cached_join[0].Nested.a.append(88)
	cached_join[0].List[0].n = 88
	check(var_to_bytes(ROWS.row("BonusType",1)) == var_to_bytes(regular[0]), "memoized relation and direct lookup do not share nested values with callers")
	check(not ROWS._small_reference_rows.is_empty(), "the repeated lookup exercised the bounded reference cache")
	ROWS._tables.ZzDuplicate = ROWS._pack([{"ID":1.0,"V":0},{"ID":1.0,"V":1}])
	same("ZzDuplicate",1,"duplicate cold",true)
	same("ZzDuplicate",1,"duplicate warm")
	check(ROWS.row("ZzDuplicate",1).is_empty(), "duplicate remains refused")
	ROWS._tables.ZzFraction = ROWS._pack([{"ID":1.0},{"ID":1.5}])
	same("ZzFraction",1,"fractional relation column",true)
	ROWS._tables.ZzMissingID = ROWS._pack([{"V":1},{"V":2}])
	same("ZzMissingID",1,"missing ID column",true)
	# Irregular rows use the old rows-backed fallback and keep fresh nested data.
	ROWS._tables.ZzRows = ROWS._pack([{"ID":4.0,"a":[1]},{"ID":5.0,"other":true}])
	same("ZzRows",4,"rows-backed cold",true)
	same("ZzRows",5,"rows-backed warm")
	# Explicit fallback relation groups exercise the index helper without
	# depending on the unrelated extreme-ID index builder.
	ROWS._relations["ZzLookup:ID"] = {"groups":{1:PackedInt32Array([0]),2:PackedInt32Array([1])}}
	same("ZzLookup",1,"group index unique")
	same("ZzLookup",999,"group index missing")
	ROWS._relations["ZzDuplicate:ID"] = {"groups":{1:PackedInt32Array([0,1])}}
	same("ZzDuplicate",1,"group index duplicate")
	# Real disk format: the same serialized row values and fresh dictionaries.
	var table: String = "ZzLookupDisk"
	var packed: Dictionary = ROWS._pack(regular)
	var disk: Dictionary = ROWS._publish_disk(table,"row-lookup-synthetic-key",packed)
	check(disk.has("disk"), "fixture commits and reopens with existing SHA/schema validation")
	if disk.has("disk"):
		for index: int in regular.size():
			check(var_to_bytes(disk.disk.row(index)) == var_to_bytes(ROWS._row_at(packed,index)), "direct row serialization preserves the exact encoded values")
		ROWS._tables[table] = disk
		same(table,1,"disk cold",true)
		same(table,2,"disk warm")
		same(table,999,"disk missing")
		var edited: Dictionary = ROWS.row(table,1)
		edited.Nested.a.append(7)
		check(var_to_bytes(ROWS.row(table,1)) == var_to_bytes(regular[0]), "disk rows remain fresh after nested edit")
		var before_release: int = ROWS.cache_generation()
		var before_release_row: PackedByteArray = var_to_bytes(ROWS.row(table,1))
		ROWS.release_caches()
		check(ROWS._small_reference_rows.is_empty(), "definition release clears decoded reference rows")
		check(ROWS.cache_generation() == before_release, "releasing acceleration caches keeps source generation")
		check(var_to_bytes(ROWS.row(table,1)) == before_release_row, "release leaves verified disk row values unchanged")
		# A same-size changed bake fails the original persisted-byte guard.
		var path: String = BAKE.data_path("disk_" + table)
		var file := FileAccess.open(path,FileAccess.READ_WRITE)
		var first: int = file.get_8()
		file.seek(0)
		file.store_8(first ^ 1)
		file.close()
		check(ROWS._open_disk(table,"row-lookup-synthetic-key").is_empty(), "same-size corrupted bake remains rejected")
		(disk.disk as RefCounted).file.close()
	BAKE.clear("disk_" + table)
	_check_compatible_disk_keys(table,packed,regular)
	_check_compatible_seed()
	var same_pin_identity: Dictionary = ROWS.identity()
	var same_pin_key: String = ROWS.verified_key()
	var same_pin_generation: int = ROWS.cache_generation()
	_fixture_open()
	check(ROWS.cache_generation() > same_pin_generation, "same pinned fixture reset invalidates the previous lifetime")
	check(ROWS.identity() == same_pin_identity and ROWS.verified_key() == same_pin_key, "generation is independent of stable source identity and verified key")
	ROWS._tables.ZzLookup = ROWS._pack(regular)
	check(var_to_bytes(ROWS.row("ZzLookup",1)) == var_to_bytes(regular[0]), "same source reset keeps exact returned values")
	ROWS.reset()
	OS.unset_environment("TWILIGHT_PATCH523_CONTENT")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--row-lookup-original="):
			_real(argument.trim_prefix("--row-lookup-original="))
	print("CURRENT523_DEFINITION_ROW_LOOKUP_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements}))
	quit(0 if failures.is_empty() else 1)

func _check_compatible_disk_keys(table: String, packed: Dictionary, rows: Array) -> void:
	var name: String = "disk_" + table
	var current: String = ROWS._bake_key(table)
	for format: String in ROWS.COMPATIBLE_STORE_FORMATS:
		var legacy: String = ROWS._bake_key(table,format)
		var written: Dictionary = ROWS._publish_disk(table,legacy,packed)
		check(written.has("disk"),"fixture writes " + format)
		if not written.has("disk"):continue
		written.disk.file.close()
		var key: String = ROWS._stored_read_key(name,table,current)
		check(key==legacy and legacy!=current,"reader reuses the existing compatible publication " + format)
		var reopened: Dictionary = ROWS._open_disk(table,key)
		check(reopened.has("disk") and var_to_bytes(reopened.disk.row(0))==var_to_bytes(rows[0]),"compatible publication supplies original row values " + format)
		if reopened.has("disk"):reopened.disk.file.close()
		BAKE.clear(name)
	var expected: String = BAKE.key([ROWS.RELATION_FORMAT,ROWS._bake_key(table,ROWS.COMPATIBLE_V1),"ID"])
	check(ROWS._relation_key(table,"ID")==expected,"the identical row order keeps persisted relation keys")

func _check_compatible_seed() -> void:
	var table := "ZzSeedLookup"
	var name := "definitions_" + table
	var old_key := ROWS._bake_key(table, ROWS.COMPATIBLE_V2)
	var row := {"ID":1.0, "Name":"pinned startup row"}
	var baked := var_to_bytes(ROWS._pack([row]))
	var index := JSON.stringify({"schema":SEED.SCHEMA, "files":{
		name:{"key":old_key, "sha256":SEED._hash(baked), "bytes":baked.size()}
	}})
	var base := "user://compatible_definition_seed"
	var directory := base.path_join(SEED.FOLDER).path_join(index.sha256_text())
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest := FileAccess.open(directory.path_join(SEED.INDEX), FileAccess.WRITE)
	manifest.store_string(index)
	manifest.close()
	var payload := FileAccess.open(directory.path_join(name + ".bin"), FileAccess.WRITE)
	payload.store_buffer(baked)
	payload.close()
	BAKE.clear(name)
	SEED.select(base, index.sha256_text())
	check(ROWS.stored_current(table), "a compatible pinned startup table satisfies the loading check")
	check(ROWS.row(table, 1) == row, "normal row lookup uses the compatible verified seed")
	ROWS._tables.erase(table)
	ROWS._relations.erase(table + ":ID")
	baked[-1] = baked[-1] ^ 1
	payload = FileAccess.open(directory.path_join(name + ".bin"), FileAccess.WRITE)
	payload.store_buffer(baked)
	payload.close()
	check(ROWS.row(table, 1).get("Name") == "raw table", "corrupted seed falls back to reading the source archive")
	check(BAKE.present(name, ROWS._bake_key(table)), "recovery publishes the current local table")
	SEED.select("", "")
	BAKE.clear(name)

func _real(path: String) -> void:
	ROWS.reset()
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",path)
	check(not ROWS.identity().is_empty(), "real archive exact pin and byte count verified")
	var ids: Variant = ROWS.column("ItemClass","ID")
	check(ids.size() == 34743, "complete real ItemClass row count")
	var identity_before_reset: Dictionary = ROWS.identity()
	var key_before_reset: String = ROWS.verified_key()
	var generation_before_reset: int = ROWS.cache_generation()
	var sample_before_reset: PackedByteArray = var_to_bytes(ROWS.row("ItemClass",int(ids[0])))
	ROWS.reset()
	check(ROWS.cache_generation() > generation_before_reset, "same actual pinned source reset advances generation")
	check(ROWS.verified_key() == key_before_reset and ROWS.identity() == identity_before_reset, "actual source reopens through unchanged archive identity checks")
	check(var_to_bytes(ROWS.row("ItemClass",int(ids[0]))) == sample_before_reset, "actual source reset returns exact same full row bytes")
	var old_times: Array[int] = []
	var new_times: Array[int] = []
	var signatures: Array[String] = []
	for round: int in 3:
		var pair: Dictionary = {}
		for optimized: bool in ([false,true] if round % 2 == 0 else [true,false]):
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			var elapsed: int = 0
			for value: Variant in ids:
				var started: int = Time.get_ticks_usec()
				var row: Dictionary = ROWS.row("ItemClass",int(value)) if optimized else reference("ItemClass",int(value))
				elapsed += Time.get_ticks_usec() - started
				hash.update(var_to_bytes(row))
			var signature: String = hash.finish().hex_encode()
			pair[str(optimized)] = signature
			if optimized: new_times.append(elapsed)
			else: old_times.append(elapsed)
		check(pair["true"] == pair["false"], "all real serialized rows identical round " + str(round))
		signatures.append(pair["true"])
	measurements = {"scope":"actual verified original ItemClass; loaded raw definition table; alternate-order same-process lookup-only, no producer speed claim", "rows":ids.size(),"rounds":3,"unit":"us","legacy":old_times,"direct_unique":new_times,"sha256":signatures}
	ROWS.reset()
	OS.unset_environment("TWILIGHT_PATCH523_CONTENT")
