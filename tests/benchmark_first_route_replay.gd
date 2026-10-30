extends SceneTree
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
const CURRENT_GRAPH=preload("res://scripts/maps/native_png_route_graph.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);printerr("FIRST_ROUTE_REPLAY_FAIL "+label)
func rss_kib() -> int:
	var file:=FileAccess.open("/proc/self/status",FileAccess.READ)
	if file==null:return -1
	while not file.eof_reached():
		var line: String=file.get_line()
		if line.begins_with("VmRSS:"):return int(line.trim_prefix("VmRSS:").strip_edges().split(" ",false)[0])
	return -1
func stats(values: Array) -> Dictionary:
	var sorted: Array=values.duplicate();sorted.sort()
	return {"count":sorted.size(),"median_us":sorted[maxi(0,ceili(sorted.size()*.5)-1)],"p95_us":sorted[maxi(0,ceili(sorted.size()*.95)-1)],"p99_us":sorted[maxi(0,ceili(sorted.size()*.99)-1)],"max_us":sorted[-1]}
func run() -> void:
	var source_path: String=OS.get_environment("TWILIGHT_ROUTE_TRACE")
	var trace_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var trace: Array=[]
	var grouped: bool=trace_data.get("route_profile",{}).is_empty()
	if grouped:
		for frame: Dictionary in trace_data.frames:
			for entry: Dictionary in frame.get("world_paths",{}).get("entries",[]):
				if not entry.graph_before and not entry.graph_after:continue
				var row: Dictionary=entry.duplicate(true);row["observed_frame"]=frame.frame
				trace.append(row)
	else:trace=trace_data.route_profile.replay_cold
	var field=REGISTRY.load_field("escaros_world")
	check(field!=null,"verified native field loaded")
	var baseline_script: Script=load(OS.get_environment("TWILIGHT_ROUTE_BASELINE"))
	var original_field_source: String=FileAccess.get_file_as_string(OS.get_environment("TWILIGHT_FIELD_BASELINE"))
	var start: int=original_field_source.find("func line_clear(")
	var finish: int=original_field_source.find("\nfunc ",start+1)
	check(start>=0 and finish>start,"original physical predicate found")
	var original: String=original_field_source.substr(start,finish-start).replace("func line_clear(","func _original_line_clear(")
	var file:=FileAccess.open("user://route-original-predicate.gd",FileAccess.WRITE)
	file.store_string('extends "res://scripts/maps/native_png_field.gd"\nvar replay_original: bool=false\nfunc line_clear(from: Vector2,to: Vector2) -> bool:\n\treturn _original_line_clear(from,to) if replay_original else super.line_clear(from,to)\n'+original);file.close()
	var saved: Dictionary={}
	for property: Dictionary in field.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:saved[property.name]=field.get(property.name)
	field.set_script(load("user://route-original-predicate.gd"))
	for key: String in saved:field.set(key,saved[key])
	var segments: Array=[]
	for row: Dictionary in trace:
		var from:=Vector2(row.from[0],row.from[1]);var to:=Vector2(row.to[0],row.to[1])
		segments.append([from,to]);segments.append([to,from]);segments.append([from,from])
		var cell: Vector2i=field.world_to_cell(from)
		var corner: Vector2=field.bounds.position+Vector2(cell*field.cell_size)
		for offset: Vector2 in [Vector2.ZERO,Vector2(0.0001,0),Vector2(-0.0001,0),Vector2(4,0),Vector2(-4,0),Vector2(2.83,2.83)]:
			segments.append([corner+offset,corner+offset+Vector2(field.cell_size,field.cell_size)])
	var predicate_equal: bool=true
	var oracle_samples=preload("res://scripts/maps/native_line_sample_cache.gd").new()
	for pair: Array in segments:
		var expected: bool=field._original_line_clear(pair[0],pair[1])
		predicate_equal=predicate_equal and expected==field.line_clear(pair[0],pair[1]) and expected==field.cached_line_clear(pair[0],pair[1],oracle_samples)
	check(predicate_equal,"original/direct/cached foot predicate on endpoints and cell boundaries")
	var baseline=baseline_script.new();var current=CURRENT_GRAPH.new()
	var configure_started: int=Time.get_ticks_usec();baseline.configure(field)
	var baseline_configure_us: int=Time.get_ticks_usec()-configure_started
	configure_started=Time.get_ticks_usec();current.configure(field)
	var current_configure_us: int=Time.get_ticks_usec()-configure_started
	check(current.sample_checks.size()==0,"fresh graph has cold sample cache")
	var baseline_outputs: Array=[];var baseline_times: Array=[];var current_times: Array=[];var rows: Array=[]
	var rss_before: int=rss_kib();var static_before: int=Performance.get_monitor(Performance.MEMORY_STATIC)
	field.replay_original=true
	for row: Dictionary in trace:
		var from:=Vector2(row.from[0],row.from[1]);var to:=Vector2(row.to[0],row.to[1])
		if grouped:field.precise_routes=baseline
		var begin: int=Time.get_ticks_usec();var result: PackedVector2Array=field.path(from,to) if grouped else baseline.route(from,to)
		baseline_times.append(Time.get_ticks_usec()-begin);baseline_outputs.append(result)
	var rss_baseline: int=rss_kib()
	var all_equal: bool=true
	field.replay_original=false
	for i: int in range(trace.size()):
		var row: Dictionary=trace[i];var from:=Vector2(row.from[0],row.from[1]);var to:=Vector2(row.to[0],row.to[1])
		if grouped:field.precise_routes=current
		var begin: int=Time.get_ticks_usec();var result: PackedVector2Array=field.path(from,to) if grouped else current.route(from,to)
		var elapsed: int=Time.get_ticks_usec()-begin;current_times.append(elapsed)
		var equal: bool=result==baseline_outputs[i];all_equal=all_equal and equal
		rows.append({"observed_frame":row.get("observed_frame",-1),"from":row.from,"to":row.to,"baseline_us":baseline_times[i],"current_us":elapsed,"points":result.size(),"exact_equal":equal})
	check(all_equal,"all ordered cold route outputs exactly identical")
	var memory: Dictionary={"rss_before_kib":rss_before,"rss_after_baseline_kib":rss_baseline,"rss_after_current_kib":rss_kib(),"static_before_bytes":static_before,"static_after_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
	var cache_info: Dictionary={"graph_sample_checks":current.sample_checks.size(),"graph_edges":current.edge_checks.size(),"oracle_sample_checks":oracle_samples.size()}
	for property: Dictionary in field.get_property_list():
		if str(property.name).contains("cache"):
			var value=field.get(property.name)
			if value is Dictionary or value is Array:cache_info[property.name]=value.size()
	var frame_groups: Dictionary={}
	for row: Dictionary in rows:
		var key: String=str(row.observed_frame)
		if not frame_groups.has(key):frame_groups[key]={"count":0,"baseline_us":0,"current_us":0}
		frame_groups[key].count+=1;frame_groups[key].baseline_us+=row.baseline_us;frame_groups[key].current_us+=row.current_us
	var out: String=OS.get_environment("TWILIGHT_PERF_OUTPUT")
	file=FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify({"baseline_original_line_clear":true,"engine":Engine.get_version_info().string,"trace_routes":trace.size(),"frame_groups":frame_groups,"baseline_configure_us":baseline_configure_us,"current_configure_us":current_configure_us,"predicate_segments":segments.size(),"predicate_equal":predicate_equal,"all_routes_equal":all_equal,"baseline":stats(baseline_times),"current":stats(current_times),"routes":rows,"memory":memory,"cache_info":cache_info,"failures":failures,"scope":"same field and ordered endpoints, two fresh graphs; grouped mode calls real field.path with each graph, excludes initial coarse discovery and reports graph setup separately; frame sums are path CPU only, not rendered frames; no per-predicate timers"},"  "));file.close()
	print("FIRST_ROUTE_REPLAY_RESULT ",JSON.stringify({"failures":failures}));quit(0 if failures.is_empty() else 1)
