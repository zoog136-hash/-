extends SceneTree
## Bounded first conversion of original definition tables (handoff P0 "큰 표의
## 첫 변환"). Synthetic tables only; needs no private original archive:
##   godot --headless --path <repo> --script res://tests/current523_definition_stream_test.gd
## (1) _convert() (streaming, batched) gives byte-identical packed stores and
##     the same failures as the former JSON.parse_string() + _pack() for
##     regular, empty, unicode, escaped, nested, numeric, mixed-type, pretty-
##     printed, multi-batch and irregular inputs; (2) regular tables really
##     take the streaming path; (3) its transient peak is below the former
##     whole parse; (4) a failed storage bake of a large table is a safe stop
##     (no resident packed fallback, no part file, problem recorded).
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
var checks: int = 0
var failures: Array[String] = []
var stats: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void: call_deferred("run")

func same_result(text: String, label: String, streamed: bool) -> void:
	var bytes: PackedByteArray = text.to_utf8_buffer()
	same_bytes(bytes, label, streamed)

func same_bytes(bytes: PackedByteArray, label: String, streamed: bool) -> void:
	var old: Dictionary = ROWS._convert_whole(bytes)
	var new: Dictionary = ROWS._convert(bytes)
	check(var_to_bytes(old) == var_to_bytes(new), "identical conversion: " + label)
	var streaming: Dictionary = ROWS._convert_streaming(bytes)
	if streamed:
		check(not streaming.is_empty(), "streaming path used: " + label)
		check(var_to_bytes(streaming) == var_to_bytes(old), "streaming result identical: " + label)
	else:
		check(streaming.is_empty(), "falls back to the whole parse: " + label)

func many_rows(count: int, mixed_at: int) -> String:
	var parts: PackedStringArray = []
	for index: int in count:
		var value: String = str(index) if index != mixed_at else "\"text\""
		# Same key set, varying order every third row.
		if index % 3 == 0:
			parts.append("{\"Name\":\"행%d \\\"q\\\" }]\",\"ID\":%d,\"V\":%s,\"F\":%s,\"L\":[%d,{\"k\":\"v\"}]}" % [index, index, value, "true" if index % 2 else "false", index])
		else:
			parts.append("{\"ID\":%d,\"Name\":\"행%d \\\"q\\\" }]\",\"V\":%s,\"F\":%s,\"L\":[%d,{\"k\":\"v\"}]}" % [index, index, value, "true" if index % 2 else "false", index])
	return "{\"schema\":2,\"rows\":[" + ",".join(parts) + "],\"tail\":{\"n\":[1,2]}}"

func run() -> void:
	# (3) transient peak, measured first (MEMORY_STATIC_MAX only grows):
	# streaming, then the former whole parse.
	var large: PackedByteArray = many_rows(20000, -1).to_utf8_buffer()
	var base: int = OS.get_static_memory_usage()
	var started: int = Time.get_ticks_msec()
	var streamed: Dictionary = ROWS._convert(large)
	var stream_ms: int = Time.get_ticks_msec() - started
	var stream_peak: int = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) - base
	streamed = {}
	started = Time.get_ticks_msec()
	var whole: Dictionary = ROWS._convert_whole(large)
	var whole_ms: int = Time.get_ticks_msec() - started
	var whole_peak: int = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) - base
	stats = {"json_bytes": large.size(), "stream_peak_bytes": stream_peak, "whole_peak_bytes": whole_peak, "stream_ms": stream_ms, "whole_ms": whole_ms}
	check(var_to_bytes(ROWS._convert(large)) == var_to_bytes(whole), "large table identical")
	large = PackedByteArray()
	check(stream_peak > 0 and whole_peak > stream_peak * 2, "streaming transient peak below half of the whole parse")
	# (1) identical results, streaming path for every regular table.
	same_result("{\"rows\":[]}", "empty rows", true)
	same_result(" \n{ \"rows\" : [ ] } \n", "empty rows with whitespace", true)
	same_result("{\"rows\":[{\"ID\":1,\"Name\":\"가나다\",\"V\":1.5}]}", "one row", true)
	same_result("{\"rows\":[{\"S\":\"\\u00e9\\ud83d\\ude00 \\\"x\\\" \\\\ \\/ \\b\\f\\n\\r\\t }{][,: \\\\\\\"\",\"K\":\"한글 😀 é\"},{\"S\":\"\\\\\",\"K\":\"\"}]}", "unicode and escapes", true)
	same_result("{\"meta\":{\"a\":[1,{\"b\":\"]}\"}]},\"rows\":[{\"A\":[1,[2,{\"x\":null}]],\"B\":{\"k\":[true,false],\"z\":{}},\"C\":null,\"D\":[]},{\"A\":[],\"B\":{},\"C\":null,\"D\":[[]]}],\"after\":\"[{\"}", "nested values", true)
	same_result("{\"rows\":[{\"N\":1,\"M\":1.0,\"Z\":-0,\"H\":0.5,\"E\":1e3,\"e\":1E-7,\"B\":9007199254740993,\"G\":-12345678901234567890,\"P\":3.141592653589793},{\"N\":2,\"M\":-2.25,\"Z\":0,\"H\":-0.0,\"E\":2E+2,\"e\":-1e-300,\"B\":1,\"G\":0,\"P\":1e308}]}", "numbers int vs float", true)
	same_result("{\"rows\":[{\"A\":1,\"B\":true,\"C\":null,\"D\":\"s\"},{\"A\":\"one\",\"B\":false,\"C\":null,\"D\":2}]}", "mixed and non-numeric columns", true)
	same_result("{\r\n\t\"rows\": [\r\n\t\t{ \"ID\" : 1 ,\n \"T\" : \"a\" } ,\r\n\t\t{\"T\":\"b\",\"ID\":2}\r\n\t]\r\n}\r\n", "pretty printed, CRLF, reordered keys", true)
	same_result(many_rows(1500, -1), "1500 rows across batches", true)
	same_result(many_rows(1300, 1100), "column type changes in a later batch", true)
	same_result("{\"rows\":[{\"ID\":1,\"Big\":\"" + "가".repeat(400000) + "\"},{\"ID\":2,\"Big\":\"x\"},{\"ID\":3,\"Big\":\"" + "y".repeat(1200000) + "\"}]}", "byte-capped batches", true)
	same_result("{\"\\u0072ows\":[{\"A\":1}]}", "escaped rows key", true)
	# Same results through the fallback (the former whole parse).
	same_result("{\"rows\":[{\"A\":1},{\"B\":2}]}", "irregular keys keep rows mode", false)
	same_result("{\"rows\":[{\"A\":1},{\"A\":2,\"B\":3}]}", "extra key keeps rows mode", false)
	same_result("{\"rows\":[{\"A\":1},2]}", "non-object row", false)
	same_result("{\"rows\":[{\"A\":1},]}", "trailing comma", false)
	same_result("{\"rows\":[{\"A\":1}]", "truncated", false)
	same_result("{\"rows\":[{\"A\":tru}]}", "invalid literal", false)
	same_result("{\"schema\":1}", "missing rows", false)
	same_result("{\"rows\":{\"A\":1}}", "rows not an array", false)
	same_result("[{\"A\":1}]", "top-level array", false)
	same_result("{}", "empty object", false)
	same_result("", "empty member", false)
	same_result("{\"rows\":[{\"A\":1}]} x", "trailing bytes", false)
	same_result("{\"rows\":[{\"A\":1}],\"rows\":[{\"B\":2}]}", "duplicate rows member", false)
	same_result("{\"rows\":[{\"A\":1}],\"x\":nul}", "invalid other member", false)
	var bom := PackedByteArray([0xEF, 0xBB, 0xBF])
	bom.append_array("{\"rows\":[{\"A\":1}]}".to_utf8_buffer())
	# The installed original's members all start with one UTF-8 BOM: streamed,
	# with exactly the whole parse's result.
	same_bytes(bom, "UTF-8 BOM", true)
	var bom_pretty := PackedByteArray([0xEF, 0xBB, 0xBF])
	bom_pretty.append_array("{\r\n  \"rows\": [\r\n    {\r\n      \"ID\": 1,\r\n      \"Name\": \"가\"\r\n    },\r\n    {\r\n      \"ID\": 2,\r\n      \"Name\": \"나\"\r\n    }\r\n  ]\r\n}\r\n".to_utf8_buffer())
	same_bytes(bom_pretty, "UTF-8 BOM, pretty printed CRLF (original layout)", true)
	var bom_many := PackedByteArray([0xEF, 0xBB, 0xBF])
	bom_many.append_array(many_rows(1500, -1).to_utf8_buffer())
	same_bytes(bom_many, "UTF-8 BOM, 1500 rows across batches", true)
	var double_bom := PackedByteArray([0xEF, 0xBB, 0xBF, 0xEF, 0xBB, 0xBF])
	double_bom.append_array("{\"rows\":[{\"A\":1}]}".to_utf8_buffer())
	same_bytes(double_bom, "two BOMs", false)
	# (4) storage bake of a large table: verified publish, or a safe stop.
	var packed: Dictionary = whole.store
	var table := "ZzStreamProbe"
	check(not FileAccess.file_exists(BAKE.data_path("disk_" + table)), "probe table name unused")
	var published: Dictionary = ROWS._publish_disk(table, "zz-probe-key", packed)
	check(published.has("disk") and int(published.count) == int(packed.count), "disk table published")
	if published.has("disk"):
		var disk = published.disk
		var equal: bool = true
		for index: int in [0, 1, 2, 511, 512, 513, 19999]:
			if var_to_bytes(disk.row(index)) != var_to_bytes(ROWS._row_at(packed, index)): equal = false
		for position: int in (packed.columns as PackedStringArray).size():
			if var_to_bytes(disk.column(position)) != var_to_bytes(packed.data[position]): equal = false
		check(equal, "disk rows/columns equal the packed store")
		disk.file.close()
	BAKE.clear("disk_" + table)
	ROWS._store_failures.erase(table)
	# An empty key cannot be committed: the write is discarded and the table
	# is a recorded safe stop, not a resident packed store.
	var failed: Dictionary = ROWS._publish_disk(table, "", packed)
	check(failed.is_empty(), "failed bake returns no table")
	check(str(ROWS._store_failures.get(table, "")).contains("다시 시작"), "failed bake records a retry problem")
	check(not FileAccess.file_exists(BAKE.data_path("disk_" + table) + ".part") and not FileAccess.file_exists(BAKE.data_path("disk_" + table)), "failed bake leaves no part or data file")
	ROWS._store_failures.erase(table)
	BAKE.clear("disk_" + table)
	_row_scanner_units()
	print("CURRENT523_DEFINITION_STREAM_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"stats":stats}))
	quit(0 if failures.is_empty() else 1)

func _row_scanner_units() -> void:
	same_result("{\"rows\":[{\"a\":[1}]}]}", "scanner nested bracket mismatch falls back exactly", false)
	var invalid_escape: String = "{\"rows\":[{\"s\":\"bad" + String.chr(92) + "q\"}]}"
	same_result(invalid_escape, "scanner invalid escape falls back exactly", false)
	var truncated_batch: String = many_rows(700,-1)
	truncated_batch = truncated_batch.left(truncated_batch.length()-30)
	same_result(truncated_batch, "scanner truncated second batch discards earlier packed batch", false)
	for text: String in ["{}", "{\"s\":\"}][{\",\"a\":[{\"b\":1}]}", "{\"s\":\"\\\"escaped\\\"\"}", "{\"bad\":[1}", "{\"unterminated\":\"x", "{\"open\":[1]"]:
		var bytes: PackedByteArray = text.to_utf8_buffer()
		var scanner := ROWS.RowScanner.new(bytes)
		check(scanner.object_end(0) == ROWS._object_end(bytes,0), "row scanner: original endpoint " + text)
	var rows := PackedStringArray()
	for index: int in 200: rows.append("{\"N\":%d,\"S\":\"plain text without bracket tokens\"}" % index)
	var source: PackedByteArray = ("[" + ",".join(rows) + "]").to_utf8_buffer()
	var scanner := ROWS.RowScanner.new(source)
	var at: int = 1
	var equal: bool = true
	for _index: int in 200:
		var expected: int = ROWS._object_end(source,at)
		var actual: int = scanner.object_end(at)
		if actual != expected: equal = false; break
		at = actual + 1
	check(equal, "row scanner: one scanner preserves endpoints across all rows")
	check(scanner.positions[3] == -1 and scanner.find_calls < source.size(), "row scanner: absent opening array cursor remains exhausted across rows")
	check(source.find(123,source.size()) == -1, "row scanner: native find at EOF returns exhausted sentinel")
	var after: int = scanner.find_calls
	check(scanner.object_end(source.size()) == -1 and scanner.find_calls == after, "row scanner: exhausted end does not search again")
