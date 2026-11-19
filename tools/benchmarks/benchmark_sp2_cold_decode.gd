extends SceneTree
## Synthetic cold structural parsing, never Android or a whole monster setup.
## --baseline-decoder=/absolute/path/to/unchanged_decoder.gd enables comparison.
## --compressed=/absolute/path/to/synthetic.sp2 adds a caller-supplied fixture.
## No timing thresholds; output is verified separately from the timed call.
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const FIXTURE = preload("res://tests/sp2_parse_cache_test.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func sample(parser: Script, raw: PackedByteArray) -> Dictionary:
	HITCH._details.clear()
	HITCH._counters.clear()
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = parser.parse(raw)
	var elapsed: int = Time.get_ticks_usec() - started
	return {"us":elapsed,"ok":result.get("ok", false),"output_sha256":digest(var_to_bytes(result)),"details":HITCH._details.duplicate(true),"counters":HITCH._counters.duplicate(true)}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var baseline: Script = null
	var compressed: String = ""
	var output: String = "user://sp2_cold_decode_benchmark.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-decoder="): baseline = load(argument.trim_prefix("--baseline-decoder="))
		if argument.begins_with("--compressed="): compressed = argument.trim_prefix("--compressed=")
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var inputs: Array = []
	for spec: Array in [[4,200,31,0],[8,255,28,0],[2,100,20,4]]:
		inputs.append({"spec":spec,"raw":FIXTURE.build(spec[0],spec[1],spec[2],spec[3])})
	if not compressed.is_empty(): inputs.append({"spec":"supplied_synthetic_compressed","raw":FileAccess.get_file_as_bytes(compressed)})
	var rows: Array = []
	var failures: Array = []
	for entry: Dictionary in inputs:
		var raw: PackedByteArray = entry.raw
		var reference: Dictionary = sample(baseline if baseline != null else DECODER, raw)
		var times: Dictionary = {"before":[],"after":[]}
		var phases: Array = []
		for iteration: int in 7:
			for which: String in (["before","after"] if iteration % 2 == 0 else ["after","before"]):
				if which == "before" and baseline == null: continue
				var observed: Dictionary = sample(baseline if which == "before" else DECODER, raw)
				if not observed.ok or observed.output_sha256 != reference.output_sha256: failures.append([entry.spec,which,iteration])
				times[which].append(observed.us)
				if which == "after": phases.append({"details":observed.details,"counters":observed.counters})
		var before: Array = times.before.duplicate()
		var after: Array = times.after.duplicate()
		before.sort(); after.sort()
		rows.append({"spec":entry.spec,"bytes":raw.size(),"raw_sha256":digest(raw),"parse_sha256":reference.output_sha256,"samples_us":times,"median_before_us":before[before.size()/2] if not before.is_empty() else null,"median_after_us":after[after.size()/2],"after_phases":phases})
	var result: Dictionary = {"engine":Engine.get_version_info().string,"synthetic_only":true,"android_measured":false,"cache":"direct parser, no disk/shared parse cache","decoder_sha256":FileAccess.get_sha256("res://scripts/resources/current523_sp2_decoder.gd"),"baseline_sha256":FileAccess.get_sha256(baseline.resource_path) if baseline != null else null,"rows":rows,"failures":failures}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: failures.append("output unavailable")
	else: file.store_string(JSON.stringify(result,"  ")); file.close()
	print("SP2_COLD_DECODE_BENCHMARK " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
