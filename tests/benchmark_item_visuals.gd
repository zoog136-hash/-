extends SceneTree

const UI = preload("res://scripts/ui/renewal_theme.gd")
const EFFECT = preload("res://scripts/ui/item_visual.gd")
var views: Array[TextureRect] = []
var records: Array[Dictionary] = []
var samples: Array = []

func _initialize() -> void: call_deferred("_run")

func measure(context: String) -> void:
	for i: int in range(views.size()): UI.apply_item_visual(views[i],records[i],records[i].name,{},context)
	for i: int in range(60): await process_frame
	var times: Array[float] = []
	var cpu: Array[float] = []
	var begin: int = Time.get_ticks_usec()
	var previous: int = begin
	for i: int in range(240):
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		times.append(float(now-previous)/1000.0)
		previous = now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
	times.sort()
	cpu.sort()
	var scheduler: Node = root.get_node("ItemVisualScheduler")
	samples.append({"context":context,"visible_icons":300,"offscreen_icons":300,"frames":times.size(),
		"elapsed_ms":float(previous-begin)/1000.0,"average_fps":240000000.0/float(previous-begin),
		"frame_ms_p50":times[120],"frame_ms_p95":times[228],"frame_ms_p99":times[237],
		"cpu_ms_p50":cpu[120],"cpu_ms_p95":cpu[228],"active_effects":scheduler.active_count,
		"registered_effects":scheduler.clients.size(),"materials":EFFECT.materials.size(),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})

func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	for i: int in range(600):
		var record: Dictionary = db["아이템"][i%64].duplicate(true)
		# Presentation-only stress fixture: 64 real PNGs, four effect grades.
		# No source DB is written and these grade overrides are not gameplay data.
		record.grade = EFFECT.GRADES[3+i%4]
		records.append(record)
		var view := TextureRect.new()
		view.size = Vector2(40,40)
		view.position = Vector2(20+(i%20)*48,20+(i/20)*44)
		if i >= 300: view.position.y += 1000
		root.add_child(view)
		views.append(view)
	await measure("list")
	await measure("slot")
	var output: String = OS.get_environment("TWILIGHT_ITEM_BENCHMARK")
	if output.is_empty(): output = "user://item-visual-benchmark.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"fps_cap":Engine.max_fps,
		"platform":"Linux software GL; not Android/Windows device evidence",
		"fixture":"64 existing source PNGs, 300 visible + 300 offscreen, balanced presentation-only hero/legend/mythic/unique overrides","samples":samples},"\t"))
	file.close()
	var valid: bool = samples[0].active_effects == 0 and samples[1].active_effects == 300
	for view: TextureRect in views: view.queue_free()
	await process_frame
	print("ITEM_VISUAL_BENCHMARK_OK " if valid else "ITEM_VISUAL_BENCHMARK_FAILED ",JSON.stringify(samples))
	quit(0 if valid else 1)
