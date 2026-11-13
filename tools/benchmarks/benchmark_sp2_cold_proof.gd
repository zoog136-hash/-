extends "res://tests/benchmark_reference_sp2_attributes.gd"
## Compare first prepared-bank construction after equally priming raw caches.
## Supply the previous bank script explicitly; never infer a baseline version.
const PREPARED=preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
func run() -> void:
	var baseline_path: String=""
	var output: String="user://cold_proof_benchmark.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline="): baseline_path=argument.trim_prefix("--baseline=")
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	if baseline_path.is_empty():
		push_error("Supply --baseline=res://path/to/previous_bank.gd")
		quit(1);return
	var previous: GDScript=load(baseline_path)
	token_count=32
	var data: Dictionary=fixture("user://cold_proof_%d" % OS.get_process_id())
	var oracle: Dictionary=BANK.new().load_bank(data.path,data.sha,ACTOR,CORE_BINDINGS,CORE_LOOPS,"npc")
	var signature: String=var_to_str(oracle).sha256_text()
	oracle={}
	var previous_primer: RefCounted=previous.new()
	previous_primer.load_bank(data.path,data.sha,ACTOR,CORE_BINDINGS,CORE_LOOPS,"npc")
	previous_primer=null
	var rows: Array=[]
	for round_index: int in 7:
		for kind: String in (["before","after"] if round_index%2==0 else ["after","before"]):
			PREPARED.clear()
			var bank: RefCounted=previous.new() if kind=="before" else BANK.new()
			HITCH._details.clear();HITCH._counters.clear()
			var allocation: int=OS.get_static_memory_usage()
			var started: int=Time.get_ticks_usec()
			var result: Dictionary=bank.load_shared_bank(data.path,data.sha,ACTOR,CORE_BINDINGS,CORE_LOOPS,"npc")
			var elapsed: int=Time.get_ticks_usec()-started
			var retained: int=OS.get_static_memory_usage()-allocation
			check(result.ok and var_to_str(result).sha256_text()==signature,"exact mutable-oracle result")
			rows.append({"round":round_index,"kind":kind,"us":elapsed,"retained_static_bytes":retained,"details":HITCH._details.duplicate(true)})
			result={};bank=null
			check(PREPARED.size()==0,"snapshot released")
	var result: Dictionary={"engine":Engine.get_version_info().string,"synthetic_only":true,"android_measured":false,"scope":"first prepared metadata; raw/manifest warm; excludes selection, pixels, upload and whole spawn","rows":rows,"failures":failures,"baseline_script_sha256":FileAccess.get_sha256(baseline_path)}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "));file.close()
	print("SP2_COLD_PROOF_BENCHMARK "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
