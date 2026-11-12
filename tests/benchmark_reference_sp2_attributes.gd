extends "res://tests/reference_sp2_load_memo_test.gd"
## Synthetic preparation benchmark, separate from the deterministic CI check.
## godot --headless --path <repo> --script res://tests/benchmark_reference_sp2_attributes.gd -- --output=/tmp/sp2-attributes.json
## Three tiny invented SP2 members; no private/original pack or Android claim.
const INDEX = preload("res://scripts/resources/reference_sp2_manifest_index.gd")
const CORE_BINDINGS = {"idle":3,"walk":0,"attack":1,"hit":2,"death":8}
const CORE_LOOPS = {"idle":true,"walk":true,"attack":false,"hit":false,"death":false}
const BASE_COMMIT = "11df08720afdb988884ad1c2b316d937fb7dc64d"
var token_count: int = 4

class CountingBank:
	extends "res://scripts/resources/reference_sp2_bank.gd"
	var attribute_validations: int = 0
	func _attributes(record: Dictionary, kind: String, sprite: int) -> Dictionary:
		attribute_validations += 1
		return super._attributes(record,kind,sprite)

class BaselineBank:
	extends CountingBank
	func _load_action_attributes(record: Dictionary, kind: String, sprite: int, _memo: Dictionary) -> Dictionary:
		return _attributes(record,kind,sprite)

func source_action(action: int) -> Dictionary:
	var source: Dictionary = super.source_action(action)
	var role: String = "source_action:" + str(action)
	var tokens: Array = []
	for index: int in token_count: tokens.append(TOKENS[index % TOKENS.size()].duplicate())
	var original: Array = source.actor.roles[role].directions
	var directions: Array = []
	for direction: int in range(8):
		var frames: Array = []
		for index: int in token_count: frames.append(original[direction][index % TOKENS.size()].duplicate(true))
		directions.append(frames)
	source.actor.roles[role].directions = directions
	source.compact_roles[role].tokens = tokens
	source.source_proof.roles[role].tokens = tokens.duplicate(true)
	return source

func fixture(directory: String, _mutation: String = "") -> Dictionary:
	var data: Dictionary = super.fixture(directory)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data.path))
	var actions: Dictionary = {}
	var action_bytes: int = 0
	for action: int in [3,0,1,2,8]:
		var relative: String = "actors/%d/action-%d.json" % [ACTOR,action]
		var path: String = directory.path_join(relative)
		actions[str(action)] = {"path":relative,"sha256":write_json(path,source_action(action))}
		action_bytes += FileAccess.get_size(path)
	manifest.actors["sprite:" + str(ACTOR)] = actions
	data.sha = write_json(data.path,manifest)
	data.action_bytes = action_bytes
	return data

func load_core(bank: RefCounted, data: Dictionary) -> Dictionary:
	return bank.load_bank(data.path,data.sha,ACTOR,CORE_BINDINGS,CORE_LOOPS)

func median(samples: Array) -> int:
	var sorted: Array = samples.duplicate()
	sorted.sort()
	return int(sorted[sorted.size()/2])

func output_path() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): return argument.trim_prefix("--output=")
	return "user://reference_sp2_attribute_benchmark.json"

func run() -> void:
	var bank_code_sha: String = FileAccess.get_sha256("res://scripts/resources/reference_sp2_bank.gd")
	var scratch_dir: String = "user://reference_sp2_attributes_bench_%d" % OS.get_process_id()
	var results: Array = []
	for size: int in [4,16,64,128]:
		token_count = size
		var data: Dictionary = fixture(scratch_dir.path_join(str(size)))
		# Compare warm preparation itself: the separate manifest-index benchmark
		# measures first-process verification and first-device split construction.
		var indexed: Dictionary = INDEX.open(data.path,data.sha,BANK.MAX_MANIFEST_JSON,true)
		check(indexed.get("ok",false),"exact manifest index primes")
		var legacy := BaselineBank.new()
		var optimized := CountingBank.new()
		var before: Dictionary = load_core(legacy,data)
		var after: Dictionary = load_core(optimized,data)
		check(before.get("ok",false) and after.get("ok",false) and bytes_equal(before,after),"warm-up output equals the pre-memo path")
		before = {}; after = {}
		var legacy_samples: Array = []
		var optimized_samples: Array = []
		var legacy_counts: Array = []
		var optimized_counts: Array = []
		for sample: int in range(5):
			# Alternate order and free previous output outside each timed call.
			# These are timing observations, never a CI speed threshold.
			for variant: int in ([0,1] if sample % 2 == 0 else [1,0]):
				var bank: RefCounted = legacy if variant == 0 else optimized
				var validations_before: int = bank.attribute_validations
				var started: int = Time.get_ticks_usec()
				var loaded: Dictionary = load_core(bank,data)
				var elapsed: int = Time.get_ticks_usec()-started
				var validations: int = bank.attribute_validations-validations_before
				if variant == 0:
					legacy_samples.append(elapsed); legacy_counts.append(validations); before = loaded
				else:
					optimized_samples.append(elapsed); optimized_counts.append(validations); after = loaded
			check(before.get("ok",false) and after.get("ok",false) and bytes_equal(before,after),"sample outputs preserve all source metadata")
			before = {}; after = {}
		results.append({"tokens_per_action":size,"roles":5,"directions":8,"layers":3,"action_json_bytes":data.action_bytes,
			"baseline_us":legacy_samples,"optimized_us":optimized_samples,
			"baseline_median_us":median(legacy_samples),"optimized_median_us":median(optimized_samples),
			"baseline_attribute_validations":legacy_counts,"optimized_attribute_validations":optimized_counts})
		print("REFERENCE_SP2_ATTRIBUTE_BENCHMARK_CASE " + JSON.stringify(results[-1]))
	var bank_code_after: String = FileAccess.get_sha256("res://scripts/resources/reference_sp2_bank.gd")
	check(bank_code_sha == bank_code_after,"bank source remains unchanged throughout the measurement")
	var result: Dictionary = {"checks":checks,"failures":failures,"cases":results,"engine":Engine.get_version_info().string,
		"base_commit":BASE_COMMIT,"bank_code_sha256":bank_code_sha,"bank_code_sha256_after":bank_code_after,
		"synthetic_only":true,"android_measured":false,"os_cache_flushed":false,"scratch":scratch_dir,
		"timed_scope":"same-process warm synchronous bank.load_bank only; alternating order; complete output comparison outside timing; no speed assertion"}
	var destination: String = output_path()
	write_bytes(destination,JSON.stringify(result,"  ",true).to_utf8_buffer())
	print("REFERENCE_SP2_ATTRIBUTE_BENCHMARK_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
