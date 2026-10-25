extends SceneTree
## Same loaded Main, camera and population; compare the old periodic refresh
## against the cached request while keeping the streaming pump in both paths.
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var output: String = "res://docs/presentation-20261025/performance/"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("VISIBILITY_CACHE_FAIL "+label)

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children(): freeze(child)

func warm(renderer: NativePngRenderer) -> bool:
	var deadline: int = Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<deadline:
		renderer._process(1.0/60.0)
		var ready: bool = true
		for filename: String in renderer.wanted_rows:
			if not renderer.chunks.has(filename): ready=false; break
		if ready: return true
		await process_frame
	return false

func sample(renderer: NativePngRenderer, before: bool) -> Dictionary:
	print("VISIBILITY_SAMPLE_BEGIN ","before" if before else "after")
	var times: Array[float] = []
	var cpu_us: int = 0
	var refresh_start: int = renderer.visibility_refresh_count
	renderer.clock=0
	for i: int in range(120):
		var frame_start: int = Time.get_ticks_usec()
		var cpu_start: int = Time.get_ticks_usec()
		if before:
			renderer.clock-=1.0/60.0
			if renderer.clock<=0:
				renderer.clock=.1
				renderer.refresh_visible()
			renderer.pump_stream()
		else: renderer._process(1.0/60.0)
		cpu_us+=Time.get_ticks_usec()-cpu_start
		await process_frame
		times.append(float(Time.get_ticks_usec()-frame_start)/1000.0)
	print("VISIBILITY_SAMPLE_END ","before" if before else "after")
	times.sort()
	return {"frames":120,"frame_median_ms":times[60],"frame_p95_ms":times[114],"frame_max_ms":times[-1],"renderer_cpu_us":cpu_us,"visibility_refreshes":renderer.visibility_refresh_count-refresh_start}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world),"real Main character entry")
	world.save_timer=-100000
	world.player.set_auto_enabled(false)
	world._set_map("escaros_world",false)
	check(world.field_renderer is NativePngRenderer and world.active_map_id=="escaros_world","native Escaros active")
	if not world.field_renderer is NativePngRenderer: quit(1);return
	world.player.camera.position_smoothing_enabled=false
	world.player.camera.force_update_scroll()
	freeze(world)
	var renderer: NativePngRenderer=world.field_renderer
	renderer.refresh_visible()
	check(await warm(renderer),"all visible/prefetch chunks settled")
	var visible_before: Dictionary=renderer.visible_files.duplicate(true)
	var wanted_before: Dictionary=renderer.wanted_rows.duplicate(true)
	var population: int=world.monsters_root.get_child_count()
	var position: Vector2=world.player.global_position
	var baseline: Dictionary=await sample(renderer,true)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"stationary-before.png")
	var cached: Dictionary=await sample(renderer,false)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"stationary-after.png")
	check(baseline.visibility_refreshes>0 and cached.visibility_refreshes==0,"stationary periodic work removed")
	check(renderer.visible_files==visible_before and renderer.wanted_rows==wanted_before,"same visibility/prefetch set and order")
	check(world.player.global_position==position and world.monsters_root.get_child_count()==population,"equal coordinates and population")
	check(renderer.visible_ready(),"no missing visible source chunks after skipped refreshes")
	var count: int=renderer.visibility_refresh_count
	world.player.camera.offset+=Vector2(500,0);world.player.camera.force_update_scroll()
	renderer._process(.11)
	check(renderer.visibility_refresh_count==count+1,"camera motion invalidates")
	count=renderer.visibility_refresh_count
	world.player.camera.zoom*=1.1;world.player.camera.force_update_scroll()
	renderer._process(.11)
	check(renderer.visibility_refresh_count==count+1,"zoom invalidates")
	count=renderer.visibility_refresh_count
	renderer.texture_pixel_budget-=1024
	renderer._process(.11)
	check(renderer.visibility_refresh_count==count+1,"budget invalidates")
	count=renderer.visibility_refresh_count
	root.content_scale_size=Vector2i(1000,700)
	root.size=Vector2i(1000,700)
	await process_frame
	renderer._process(.11)
	check(renderer.visibility_refresh_count==count+1,"viewport invalidates")
	count=renderer.visibility_refresh_count
	renderer.refresh_visible()
	check(renderer.visibility_refresh_count==count+1,"explicit refresh remains forced")
	check(await warm(renderer),"streaming completes after changes")
	world._set_map("aden_world",false)
	check(world.field_renderer!=renderer,"map replacement owns new visibility cache")
	check((world.field_renderer as NativePngRenderer).visibility_refresh_count>0,"new map forces initial visibility")
	var file := FileAccess.open(output+"visibility-cache.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"checks":checks,"failures":failures,"map":"escaros_world","position":[position.x,position.y],"population":population,"before":baseline,"after":cached,"workload":"same Main instance; stationary camera, all actor/process logic frozen in both phases; no combat, no input, render plus renderer stream pump","android":"NOT_RUN"},"  "))
	file.close()
	world.queue_free()
	await process_frame
	print("VISIBILITY_CACHE_RESULT ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
