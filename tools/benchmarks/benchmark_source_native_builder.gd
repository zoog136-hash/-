extends "res://tests/reference_sp2_native_build_test.gd"
## Invented SHA-pinned native-contract JSON and tiny FE SP2 members.
## Measures synchronous metadata construction, not original input or Android.
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

func sample(data: Dictionary, shared: bool, round_index: int) -> Dictionary:
	PREPARED.clear()
	HITCH._details.clear()
	HITCH._counters.clear()
	# Scope each sample so previous banks/results cannot affect the held delta.
	var memory_before: int = OS.get_static_memory_usage()
	var bank := BANK.new()
	var started: int = HITCH.now()
	var loaded: Dictionary = build(bank,data,shared)
	var elapsed: int = HITCH.now() - started
	var held_memory_delta: int = OS.get_static_memory_usage() - memory_before
	check(loaded.get("ok",false),"native metadata configures")
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(loaded))
	return {"round":round_index,"shared":shared,"configure_usec":elapsed,"held_static_bytes_delta":held_memory_delta,"details_usec":HITCH._details.duplicate(true),"counters":HITCH._counters.duplicate(),"output_sha256":hash.finish().hex_encode()}

func run() -> void:
	var data: Dictionary = build_fixture("user://native_builder_benchmark","ordinary",128)
	var results: Array = []
	for round_index: int in 5:
		for shared: bool in [false,true]:
			results.append(sample(data,shared,round_index))
	var result: Dictionary = {"fixture":"synthetic native-contract action x 8 directions x 128 tokens x 5 layers; tiny FE SP2","results":results,"failures":failures,"scope":"Linux headless bank metadata construction with a fresh prepared snapshot; not original input, physical cold I/O, pixel decode/upload, whole spawn or Android"}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var file := FileAccess.open(argument.trim_prefix("--output="),FileAccess.WRITE)
			file.store_string(JSON.stringify(result))
	print("SOURCE_NATIVE_BUILDER_BENCHMARK ",JSON.stringify({"failures":failures,"cases":results.size()}))
	quit(0 if failures.is_empty() else 1)
