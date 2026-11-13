extends "res://tests/benchmark_reference_sp2_attributes.gd"
## Synthetic five-core-role NPC preview preparation. Timers stop before
## fingerprints. Engine static allocation is not process RSS or Android RAM.
const PREVIEW=preload("res://scripts/animation/original_source_preview.gd")
const LEGACY=preload("res://tests/qa_unshared_reference_preview.gd")
const PREPARED=preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")

func run() -> void:
	token_count=32
	var data: Dictionary=fixture("user://prepared_bank_bench_%d" % OS.get_process_id())
	# Prime the existing manifest/raw caches equally. Each cohort starts with
	# no prepared owner; its first actor still pays full source validation.
	var primer:=LEGACY.new()
	check(primer._configure_reference_bank(data.path,data.sha,ACTOR,CORE_BINDINGS,CORE_LOOPS,"idle","npc"),"baseline primer")
	var signature: String=var_to_str(primer._playback_tracks).sha256_text()
	primer.free()
	var results: Array=[]
	for round_index: int in 3:
		for kind: String in (["before","after"] if round_index%2==0 else ["after","before"]):
			PREPARED.clear()
			var views: Array=[]
			var times: Array=[]
			var rows: Array=[]
			var allocation_before: int=OS.get_static_memory_usage()
			for index: int in 10:
				HITCH._details.clear();HITCH._counters.clear()
				var view: Node=LEGACY.new() if kind=="before" else PREVIEW.new()
				var started: int=Time.get_ticks_usec()
				var ok: bool=view._configure_reference_bank(data.path,data.sha,ACTOR,CORE_BINDINGS,CORE_LOOPS,"idle","npc")
				var elapsed: int=Time.get_ticks_usec()-started
				times.append(elapsed)
				rows.append({"us":elapsed,"details":HITCH._details.duplicate(true),"counters":HITCH._counters.duplicate()})
				check(ok,"preview configures")
				views.append(view)
			var live_allocation: int=OS.get_static_memory_usage()-allocation_before
			var identical: bool=true
			var shared_records: int=0
			for view: Node in views:
				identical=identical and var_to_str(view._playback_tracks).sha256_text()==signature
				if is_same(view._record,views[0]._record): shared_records+=1
			check(identical,"all actor outputs identical to baseline")
			for view: Node in views: view.free()
			var weak_keys_after: int=PREPARED.size()
			check(weak_keys_after==0,"last preview releases snapshot")
			results.append({"round":round_index,"kind":kind,"times_us":times,"first_us":times[0],"subsequent_median_us":median(times.slice(1)),"engine_live_allocation_delta":live_allocation,"actors_sharing_first_record":shared_records,"weak_keys_after_free":weak_keys_after,"operations":rows})
	var result: Dictionary={"engine":Engine.get_version_info().string,"synthetic_only":true,"android_measured":false,"baseline":"main 3ea41de9 NPC preview function; unchanged full bank validation","roles":5,"tokens_per_role":32,"directions":8,"actors":10,"action_bytes":data.action_bytes,"track_sha256":signature,"rows":results,"failures":failures,"memory_scope":"Godot static allocator live delta, includes diagnostic rows; excludes RSS, driver/GPU and Android. No timing threshold."}
	var path: String="user://prepared_bank_benchmark.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):path=argument.trim_prefix("--output=")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"  "));file.close()
	print("SP2_PREPARED_BANK_BENCHMARK "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
