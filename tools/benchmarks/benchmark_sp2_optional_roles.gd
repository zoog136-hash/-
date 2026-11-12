extends "res://tests/reference_sp2_optional_roles_test.gd"
## Reproduce warm, synchronous optional-role preparation before/after.
## godot --headless --path <repo> --script res://tools/benchmarks/benchmark_sp2_optional_roles.gd -- --output=/tmp/sp2-optional.json --tokens=4,32
## Invented pixels/JSON only; no speed gate, private source or Android claim.

func requested_tokens() -> Array[int]:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--tokens="):
			var sizes: Array[int] = []
			for value: String in argument.trim_prefix("--tokens=").split(","):
				if value.is_valid_int() and int(value) > 0 and int(value) <= 512: sizes.append(int(value))
			if not sizes.is_empty(): return sizes
	return [4,32]

func run() -> void:
	var preview_path: String = "res://scripts/animation/original_source_preview.gd"
	var bank_path: String = "res://scripts/resources/reference_sp2_bank.gd"
	var hashes: Dictionary = {"preview":FileAccess.get_sha256(preview_path),"bank":FileAccess.get_sha256(bank_path)}
	var cases: Array = []
	for size: int in requested_tokens():
		token_count = size
		for kind: String in ["valid","missing_one","malformed_optional"]:
			var data: Dictionary = fixture("user://optional_role_benchmark_%d/%d/%s" % [OS.get_process_id(),size,kind],kind)
			var legacy := LegacyPreview.new()
			var current := PREVIEW.new()
			# Both variants are primed before timing; manifest split construction,
			# OS cold reads and first SP2 parse are intentionally separate scopes.
			var warm_before: Dictionary = observed(legacy,selection(data,kind))
			var warm_after: Dictionary = observed(current,selection(data,kind))
			check(bytes_equal(warm_before.snapshot,warm_after.snapshot),"primed complete result: %d %s" % [size,kind])
			var result_sha: String = JSON.stringify(warm_after.snapshot,"",true).sha256_text()
			warm_before = {}; warm_after = {}
			var before_samples: Array = []
			var after_samples: Array = []
			for sample: int in range(3):
				var before: Dictionary
				var after: Dictionary
				for variant: int in ([0,1] if sample % 2 == 0 else [1,0]):
					if variant == 0: before = observed(legacy,selection(data,kind))
					else: after = observed(current,selection(data,kind))
				check(bytes_equal(before.snapshot,after.snapshot),"complete result: %d %s %d" % [size,kind,sample])
				before.erase("snapshot"); after.erase("snapshot")
				before_samples.append(before); after_samples.append(after)
			var before_times: Array = []
			var after_times: Array = []
			for sample: Dictionary in before_samples: before_times.append(sample.us)
			for sample: Dictionary in after_samples: after_times.append(sample.us)
			cases.append({"tokens_per_action":size,"core_roles":4,"optional_roles":2,"directions":8,"layers":3,"kind":kind,
				"before":before_samples,"after":after_samples,"before_median_us":median(before_times),"after_median_us":median(after_times),"complete_result_sha256":result_sha})
			print("SP2_OPTIONAL_ROLE_BENCHMARK_CASE "+JSON.stringify(cases[-1]))
			legacy.free(); current.free()
	check(hashes.preview == FileAccess.get_sha256(preview_path) and hashes.bank == FileAccess.get_sha256(bank_path),"runtime sources unchanged throughout measurement")
	var result: Dictionary = {"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"synthetic_only":true,"android_measured":false,
		"source_sha256":hashes,"cases":cases,"scope":"same-process warm synchronous preview role preparation; complete baseline result comparison outside timing; no OS/GPU memory or speed threshold",
		"malformed_optional_tradeoff":"Existing but invalid optional records can cause one extra failed combined load before independent fallback; missing index entries take the original path immediately.",
		"single_spawn_limit":"This removes duplicate successful loads; a single cold SP2 read/decompress/parse remains synchronous and can exceed an inter-spawn budget."}
	write_bytes(output_path(),JSON.stringify(result,"  ",true).to_utf8_buffer())
	print("SP2_OPTIONAL_ROLE_BENCHMARK_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"output":output_path(),"source_sha256":hashes}))
	quit(0 if failures.is_empty() else 1)
