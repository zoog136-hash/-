extends SceneTree
## Synthetic cost-walk observation; no timing/OS-memory threshold.
const FIXTURE=preload("res://tests/sp2_parse_cache_test.gd")
const DECODER=preload("res://scripts/resources/current523_sp2_decoder.gd")
const PAYLOAD=preload("res://scripts/resources/sp2_parsed_payload.gd")

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var raw: PackedByteArray=FIXTURE.build(8,200,31,0)
	var parsed: Dictionary=DECODER.parse(raw)
	if not parsed.get("ok",false):
		printerr(parsed)
		quit(1)
		return
	var times: Array=[]
	var measured: int=0
	for sample: int in range(20):
		var started: int=Time.get_ticks_usec()
		measured=PAYLOAD.bytes_of(parsed)
		times.append(Time.get_ticks_usec()-started)
	var sorted: Array=times.duplicate()
	sorted.sort()
	var result: Dictionary={"engine":Engine.get_version_info().string,"synthetic_only":true,"android_measured":false,
		"source_format":"FE, 8 groups x 200 frames x 31 rows x 31 samples",
		"raw_body_alias_bytes":raw.size(),"packed_payload_lower_bound_bytes":measured,"walk_us":times,"median_walk_us":sorted[sorted.size()/2],
		"helper_sha256":FileAccess.get_sha256("res://scripts/resources/sp2_parsed_payload.gd"),
		"accounting":"logical packed-buffer bytes only; excludes Dictionary/Array/Variant, allocation capacity/headers, GPU and RSS",
		"scope":"one complete structural walk per new shared parse publication; warm bank/share hits use stored integer sidecars; no serialization for accounting"}
	var output: String="user://sp2_parsed_payload_benchmark.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"  ",true));file.close()
	print("SP2_PARSED_PAYLOAD_BENCHMARK_RESULT "+JSON.stringify(result))
	quit(0)
