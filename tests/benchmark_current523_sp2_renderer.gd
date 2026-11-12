extends SceneTree
## Manual synthetic CPU benchmark, not a pass/fail speed threshold.
## godot --headless --path <repo> --script res://tests/benchmark_current523_sp2_renderer.gd -- --output=<absolute JSON path>
## Both implementations render the same already parsed frames. The decoder
## renderer is unchanged, so no external copy or original pack is needed.
const BEFORE = preload("res://scripts/resources/current523_sp2_decoder.gd")
const AFTER = preload("res://scripts/resources/current523_sp2_frame_renderer.gd")
const FIXTURE = preload("res://tests/sp2_parse_cache_test.gd")
var failures: Array[String] = []
var rows: Array = []

func _initialize() -> void: _run.call_deferred()

func _measure(parsed: Dictionary, improved: bool, options: Dictionary) -> int:
	var elapsed: int = 0
	for group: int in parsed.groups.size():
		for frame: int in parsed.groups[group].frames.size():
			var started: int = Time.get_ticks_usec()
			var result: Dictionary = AFTER.render(parsed,group,frame,options) if improved else BEFORE.render(parsed,group,frame,options)
			elapsed += Time.get_ticks_usec()-started
			if not result.get("ok",false): failures.append(str(result))
	return elapsed

func _run() -> void:
	for spec: Array in [[8,100,31,0],[2,100,255,4]]:
		var parsed: Dictionary = BEFORE.parse(FIXTURE.build(spec[0],spec[1],spec[2],spec[3]))
		if not parsed.get("ok",false): failures.append("fixture parse"); continue
		for alpha: String in ["opaque_samples","index0_transparent"]:
			for rgb: String in ["bit_replication","linear"]:
				var options: Dictionary = {"alpha_policy":alpha,"rgb_policy":rgb}
				# Equality is checked outside the timed loops, including metadata.
				for group: int in parsed.groups.size():
					for frame: int in parsed.groups[group].frames.size():
						var before: Dictionary = BEFORE.render(parsed,group,frame,options)
						var after: Dictionary = AFTER.render(parsed,group,frame,options)
						if before.image.get_data()!=after.image.get_data() or before.offset!=after.offset or before.bounds!=after.bounds or before.empty!=after.empty: failures.append("different frame")
				var before_times: Array[int] = []
				var after_times: Array[int] = []
				for iteration: int in 5:
					# Alternate order, retaining each observed CPU duration.
					if iteration%2==0:
						before_times.append(_measure(parsed,false,options))
						after_times.append(_measure(parsed,true,options))
					else:
						after_times.append(_measure(parsed,true,options))
						before_times.append(_measure(parsed,false,options))
				var before_sorted: Array[int] = before_times.duplicate()
				var after_sorted: Array[int] = after_times.duplicate()
				before_sorted.sort(); after_sorted.sort()
				rows.append({"fixture_groups":spec[0],"frames_per_group":spec[1],"rows_per_frame":spec[2],"palette_marker":spec[3],"alpha":alpha,"rgb":rgb,"rendered_frames_per_sample":int(spec[0])*int(spec[1]),"before_usec":before_times,"after_usec":after_times,"before_median_usec":before_sorted[2],"after_median_usec":after_sorted[2]})
	var report: Dictionary = {"engine":Engine.get_version_info().string,"synthetic_only":true,"cpu_render_only":true,"texture_upload_measured":false,"decoder_sha256":FileAccess.get_sha256("res://scripts/resources/current523_sp2_decoder.gd"),"renderer_sha256":FileAccess.get_sha256("res://scripts/resources/current523_sp2_frame_renderer.gd"),"rows":rows,"failures":failures}
	for item: String in OS.get_cmdline_user_args():
		if item.begins_with("--output="):
			var file:=FileAccess.open(item.trim_prefix("--output="),FileAccess.WRITE)
			if file==null: failures.append("output unavailable")
			else: file.store_string(JSON.stringify(report,"\t")); file.close()
	print("CURRENT523_SP2_RENDERER_BENCHMARK "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
