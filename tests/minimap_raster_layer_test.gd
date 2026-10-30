extends SceneTree

# Real renderer: the static minimap layer is rasterized once and then drawn as
# one texture. It must match direct drawing, cut draw calls, and rebuild only
# when the field or display scale changes.
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("MINIMAP_RASTER_LAYER_FAIL: " + message)

func _drawn(count: int = 1) -> void:
	for frame: int in range(count): await RenderingServer.frame_post_draw

func _wait_ready(minimap: Node) -> bool:
	for frame: int in range(40):
		if minimap.raster_cache.ready: return true
		await _drawn()
	return minimap.raster_cache.ready

func _calls(frames: int = 6) -> float:
	var total: float = 0.0
	for frame: int in range(frames):
		await _drawn()
		total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return total / frames

func _capture(minimap: Control) -> Image:
	await _drawn(2)
	var image: Image = root.get_texture().get_image()
	var rect := Rect2i(minimap.get_global_rect())
	return image.get_region(rect.intersection(Rect2i(Vector2i.ZERO, image.get_size())))

func _max_difference(a: Image, b: Image, area: Rect2i) -> int:
	var worst: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			worst = maxi(worst, roundi(maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b)) * 255.0))
	return worst

func _run() -> void:
	root.size = Vector2i(1280, 720)
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for frame: int in range(4): await process_frame
	check(QA.enter_game(world), "real class picker enters game")
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.source_save_blocked = true
	world.save_timer = -10000
	for monster: Node in world.monsters_root.get_children():
		monster.set_process(false)
		monster.set_physics_process(false)
	if world.field_population != null: world.field_population.set_process(false)
	var minimap: Control = world.field_minimap
	minimap.set_process(false)
	check(await _wait_ready(minimap), "static layer raster becomes ready")
	var builds: int = minimap.raster_cache.builds
	check(builds >= 1, "raster built at least once")
	var direct_before: int = minimap.static_redraws
	minimap.queue_redraw()
	minimap.overlay.queue_redraw()
	await _drawn(3)
	check(minimap.static_redraws == direct_before, "owner redraw uses the texture, not direct terrain")
	check(minimap.raster_cache.builds == builds, "owner/overlay redraw does not rebuild the raster")
	var cached_calls: float = await _calls()
	var cached_image: Image = await _capture(minimap)
	minimap.set_static_cache_enabled(false)
	var direct_calls: float = await _calls()
	var direct_image: Image = await _capture(minimap)
	minimap.set_static_cache_enabled(true)
	await _drawn(2)
	check(cached_calls <= direct_calls, "raster never adds draw calls (%.1f cached vs %.1f direct)" % [cached_calls, direct_calls])
	var area := Rect2i(minimap.area)
	area = area.intersection(Rect2i(Vector2i.ZERO, cached_image.get_size()))
	var difference: int = _max_difference(cached_image, direct_image, area) if cached_image.get_size() == direct_image.get_size() else 255
	check(difference <= 8, "raster matches direct drawing inside the map area (max channel diff %d)" % difference)
	check(minimap.raster_cache.builds == builds, "toggling the cache keeps the same raster")
	minimap.configure(world, world.field_map)
	check(not minimap.raster_cache.ready, "reconfigure invalidates immediately")
	check(await _wait_ready(minimap), "reconfigure rebuilds the raster")
	check(minimap.raster_cache.builds == builds + 1, "reconfigure rebuilds exactly once")
	root.size = Vector2i(854, 480)
	await _drawn(2)
	check(await _wait_ready(minimap), "display scale change rebuilds the raster")
	check(minimap.raster_cache.builds == builds + 2, "scale change rebuilds exactly once")
	print("MINIMAP_RASTER_LAYER_STATS ", JSON.stringify({"cached_draw_calls": cached_calls, "direct_draw_calls": direct_calls,
		"max_channel_difference": difference, "builds": minimap.raster_cache.builds,
		"raster_size": str(minimap.raster_cache.viewport.size), "map": str(world.active_map_id)}))
	world.queue_free()
	await process_frame
	print("MINIMAP_RASTER_LAYER_OK checks=%d" % checks if failures.is_empty() else "MINIMAP_RASTER_LAYER_FAILED %d/%d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
