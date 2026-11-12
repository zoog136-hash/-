extends SceneTree
## Optional CPU/Variant experiment with synthetic source metadata, not original
## CSBs, rendered pixels, Android latency or a CI timing threshold.
## git show 4c78a97:scripts/ui/original_ui/source_node_scope.gd > /tmp/scope-before.gd
## XDG_DATA_HOME=/tmp/scope-bench-data XDG_CONFIG_HOME=/tmp/scope-bench-config \
## XDG_CACHE_HOME=/tmp/scope-bench-cache godot --headless --path . \
##   --script res://tools/benchmarks/benchmark_original_ui_node_scope.gd \
##   -- --baseline=/tmp/scope-before.gd
## The baseline is supplied explicitly; no old implementation is copied here.
const CURRENT=preload("res://scripts/ui/original_ui/source_node_scope.gd")
const REPEATS=20
const MAX_STATIC_GROWTH=64*1024*1024
var serial: int=0
var failures: Array[String]=[]
var samples: Array=[]

func _initialize() -> void:_run.call_deferred()

func _node(depth: int, width: int) -> Dictionary:
	serial+=1
	var value: Dictionary={"_offset":serial,"classname":"Node","options":{"actionTag":serial,"position":[0.0,0.0],"metadata":{"source_identity":"synthetic-only:"+str(serial),"padding":"x".repeat(512),"types":[true,17,0.5,null],"rgba":PackedByteArray([1,2,3,4])}},"children":[]}
	for index: int in (width if depth>0 else 0):value.children.append(_node(depth-1,width))
	return value

func _measure(implementation: GDScript, tree: Dictionary, offsets: Array[int]) -> Dictionary:
	var before: int=OS.get_static_memory_usage()
	var started: int=Time.get_ticks_usec()
	var result: Dictionary
	for repeat_index: int in REPEATS:result=implementation.select(tree,offsets)
	var elapsed: int=Time.get_ticks_usec()-started
	return {"mean_usec":float(elapsed)/REPEATS,"retained_engine_static_bytes":OS.get_static_memory_usage()-before,"result":result}

func _run() -> void:
	var baseline_path: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--baseline="):baseline_path=value.trim_prefix("--baseline=")
	if not baseline_path.is_absolute_path() or not FileAccess.file_exists(baseline_path):
		printerr("NODE_SCOPE_BENCHMARK requires --baseline=/absolute/path/to/source_node_scope.gd")
		quit(2);return
	var baseline:=GDScript.new()
	baseline.source_code=FileAccess.get_file_as_string(baseline_path)
	if baseline.reload()!=OK or not baseline.has_method("select"):
		printerr("NODE_SCOPE_BENCHMARK baseline must compile and provide select(tree, offsets).")
		quit(2);return
	var before: int=OS.get_static_memory_usage()
	for depth: int in [3,4]:
		serial=0
		var tree: Dictionary={"schema_version":1,"nodeTree":_node(depth,5),"action":{"timeLines":[]},"_source_sha256":"synthetic-evidence-not-original"}
		var total: int=serial
		var offsets: Array[int]=[total]
		var input: PackedByteArray=var_to_bytes(tree)
		var old: Dictionary=_measure(baseline,tree,offsets)
		var current: Dictionary=_measure(CURRENT,tree,offsets)
		if var_to_bytes(old.result)!=var_to_bytes(current.result):failures.append("Complete encoded result differs for "+str(total)+" synthetic nodes.")
		if var_to_bytes(tree)!=input:failures.append("An implementation mutated the source input.")
		samples.append({"synthetic_nodes":total,"selected_offsets":offsets,"baseline_mean_usec":old.mean_usec,"current_mean_usec":current.mean_usec,"baseline_result_static_bytes":old.retained_engine_static_bytes,"current_result_static_bytes":current.retained_engine_static_bytes,"encoded_results_equal":var_to_bytes(old.result)==var_to_bytes(current.result)})
		if OS.get_static_memory_usage()-before>MAX_STATIC_GROWTH:
			failures.append("64MiB engine static growth guard reached; remaining work skipped.")
			break
	print("ORIGINAL_UI_NODE_SCOPE_BENCHMARK ",JSON.stringify({"engine":Engine.get_version_info().string,"scope":"synthetic CPU/Variant only; engine static allocations are not RSS or GPU bytes; no original CSB/Android performance claim","repeats":REPEATS,"static_growth_guard_bytes":MAX_STATIC_GROWTH,"measurements":samples,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
