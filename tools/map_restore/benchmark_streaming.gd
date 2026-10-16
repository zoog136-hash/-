extends SceneTree
## Production Main, actual draw intervals, bounded streaming and revisit checks.
## QA teleports exercise chunk turnover; this is not a walking-speed/device test.
var world: TwilightWorld
var output: String="user://remake-streaming.json"
var failures: Array[String]=[]
var rows: Array=[]
var authored_only: bool=false

func _initialize() -> void: call_deferred("run")

func snapshots() -> Dictionary:
	var result: Dictionary={}
	if world.field_map is AuthoredRemakeField:
		for key: Vector2i in world.field_renderer.floor_stream.chunks:
			result[str(key)]=world.field_renderer.floor_stream.chunk_signature(key)
		return result
	for key: Vector2i in world.field_renderer.chunks:
		var chunk: Node=world.field_renderer.chunks[key]
		var mesh: MeshInstance2D=chunk.get_node("BatchedGround")
		var hash:=HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(var_to_bytes(mesh.mesh.surface_get_arrays(0)))
		result[str(key)]=hash.finish().hex_encode()
	return result

func draw_intervals() -> Dictionary:
	var samples: Array[float]=[]
	await RenderingServer.frame_post_draw
	var before: int=Time.get_ticks_usec()
	for index: int in range(60):
		await RenderingServer.frame_post_draw
		var now: int=Time.get_ticks_usec()
		samples.append((now-before)/1000.0)
		before=now
	samples.sort()
	return {"samples":samples.size(),"median_ms":samples[30],"p95_ms":samples[56],"max_ms":samples[-1],"kind":"ACTUAL_DRAW_INTERVAL_IDLE_ACTORS_ACTIVE"}

func move_camera(point: Vector2) -> void:
	world.player.global_position=point
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	for index: int in range(3): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("BENCHMARK_REQUIRES_RENDERER");quit(1);return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg=="--authored": authored_only=true
	if not authored_only and not preload("res://scripts/maps/remake_registry.gd").installed("oman_01"):
		printerr("BENCHMARK_REQUIRES_PRIVATE_PACK");quit(2);return
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	world.hud.complete_class_selection();world.hud._close_workspace()
	world.save_timer=-100000;world.level=100;world.max_hp=1000000;world.hp=world.max_hp
	world.player.camera.position_smoothing_enabled=false
	world.player.set_auto_enabled(false)
	var selected: Array[String]=[]
	if authored_only:
		for record: Dictionary in world.maps:
			if not str(record.id).begins_with("oman_"): selected.append(str(record.id))
	else:
		for floor_number: int in range(1,11): selected.append("oman_%02d" % floor_number)
	for id: String in selected:
		var start: int=Time.get_ticks_usec()
		world._set_map(id,false)
		var entry_ms: float=(Time.get_ticks_usec()-start)/1000.0
		world.portal_cooldown=10000
		var entry: Vector2=world.player.global_position
		await move_camera(entry)
		var original: Dictionary=snapshots()
		var near: Dictionary=await draw_intervals()
		var far: Vector2=entry
		for portal: Dictionary in world.field_map.data.portal:
			var point:=Vector2(portal.position[0],portal.position[1])
			if point.distance_squared_to(entry)>far.distance_squared_to(entry): far=point
		var stream: Node2D=world.field_renderer.floor_stream if authored_only else world.field_renderer
		var freed_before: int=stream.freed_chunks
		await move_camera(far)
		var distant: Dictionary=await draw_intervals()
		await move_camera(entry)
		var revisit: Dictionary=snapshots()
		var identical: bool=original==revisit
		if not identical: failures.append(id+" revisit mesh mismatch")
		var freed: int=stream.freed_chunks-freed_before
		if freed<=0: failures.append(id+" did not unload distant chunks")
		if (world.field_renderer.floor_stream.chunks.size()>49 if authored_only else world.field_renderer.chunks.size()>49):
			failures.append(id+" chunk budget exceeded")
		if not authored_only and world.field_map.collision_stream.chunks.size()>9: failures.append(id+" physical chunk budget exceeded")
		rows.append({"map":id,"layout_revision":world.field_map.data.get("layout_revision",0),
			"synchronous_map_entry_ms":entry_ms,"entry_draw_intervals":near,"distant_draw_intervals":distant,
			"memory_static_bytes":OS.get_static_memory_usage(),"render_chunks":world.field_renderer.chunks.size(),
			"floor_chunks":world.field_renderer.floor_stream.chunks.size() if authored_only else world.field_renderer.chunks.size(),
			"physics_chunks":world.field_map.collision_stream.chunks.size(),
			"nav_chunks":PlayableField.navigation_snapshots.size() if authored_only else world.field_map.nav_cache.size(),
			"unloaded_chunks":freed,"revisit_identical_meshes":identical,
			"max_synchronous_chunk_build_usec":null if authored_only else world.field_renderer.stream_build_usec})
		print("STREAM_BENCHMARK_MAP ",id)
	var report: Dictionary={"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),
		"display":DisplayServer.get_name(),"maps":rows,"failures":failures,"android":"NOT_RUN",
		"scope":"Existing authored 15 maps" if authored_only else "Oman 10 A3 floors",
		"method":"Idle frame intervals + QA teleport streaming; not A3 mainland walking or hardware acceptance"}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	world.queue_free();await process_frame
	print("STREAM_BENCHMARK_RESULT maps=",rows.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
