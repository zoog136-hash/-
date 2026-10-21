extends SceneTree
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_NATIVE_PNG_PACK
## Actual PNG streaming, cache reuse, texture cap and Main renderer lifecycle.
const QA=preload("res://tests/qa_class_selection.gd")
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("NATIVE_STREAM_FAIL: "+label)
func warm(renderer: NativePngRenderer) -> bool:
	var deadline: int=Time.get_ticks_msec()+10000
	renderer.refresh_visible()
	while Time.get_ticks_msec()<deadline:
		var complete: bool=true
		for filename: String in renderer.wanted_rows:
			if not renderer.chunks.has(filename): complete=false;break
		if complete: return true
		await process_frame
	return false
func run() -> void:
	if not REGISTRY.installed() or not REGISTRY.enabled() or DisplayServer.get_name()=="headless":
		print("NATIVE_STREAM_SKIP: actual private PNGs and rendered --native-png-maps session required");quit();return
	root.size=Vector2i(1280,720)
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"actual Main character entry")
	world.save_timer=-100000;world.set_process(false)
	world._set_map("yahee_temple",false);world.portal_cooldown=10000
	var renderer: NativePngRenderer=world.field_renderer
	var initial_sync: int=renderer.synchronous_decodes
	world.player.camera.position_smoothing_enabled=false
	check(await warm(renderer),"actual entry and prefetch PNGs decoded")
	world.player.camera.offset=Vector2(900,0);world.player.camera.force_update_scroll()
	check(await warm(renderer),"forward camera decodes new real PNG chunks on worker")
	check(renderer.decode_count>0,"worker performed real PNG decode/mask jobs")
	var after_forward: int=renderer.decode_count
	world.player.camera.offset=Vector2.ZERO;world.player.camera.force_update_scroll()
	check(await warm(renderer),"return camera retains complete original art")
	check(renderer.decode_count==after_forward,"cached backtracking does not re-decode PNGs")
	check(renderer.synchronous_decodes==initial_sync,"movement performs zero main-thread PNG decodes/masks")
	check(renderer.peak_decoded_pixels<=renderer.texture_pixel_budget,"visible plus prefetch plus LRU textures share fixed cap")
	for filename: String in renderer.visible_rows(world.player.camera):
		check(renderer.chunks.has(filename),"real visible source tile present "+filename)
	# Emulate the mobile texture budget with REAL PNG/GPU images on Linux.
	# This verifies the memory policy, never Android hardware performance.
	for filename: String in renderer.last_used.keys(): renderer.release_source(filename)
	renderer.peak_decoded_pixels=0;renderer.texture_pixel_budget=renderer.MAX_MOBILE_PIXELS
	world.player.camera.zoom=Vector2.ONE*.12;world.player.camera.force_update_scroll()
	check(await warm(renderer),"48 MiB policy loads every selected original PNG at constrained zoom")
	check(renderer.budget_limited and world.player.camera.zoom.x>.12,"mobile policy constrains an oversized view")
	check(renderer.peak_decoded_pixels<=renderer.MAX_MOBILE_PIXELS,"real mobile-policy textures plus cache stay at or below 48 MiB")
	for filename: String in renderer.visible_rows(world.player.camera):
		check(renderer.chunks.has(filename),"mobile-policy view has no original PNG holes "+filename)
	# Finish/free a field while its next worker may still be running. A second
	# pack/map must never receive stale images or keep a live detached thread.
	world.player.camera.offset=Vector2(-1700,0);world.player.camera.force_update_scroll();renderer.refresh_visible();renderer.pump_stream()
	world._set_map("albino_01",false)
	check(world.field_renderer!=renderer and world.field_map.data.map_id=="albino_01","map replacement safely joins old worker")
	print("NATIVE_STREAM_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"decoded_on_worker":after_forward,"main_thread_moving_decodes":renderer.synchronous_decodes-initial_sync,"peak_rgba_bytes":renderer.peak_decoded_pixels*4,"actual_png":true,"android_device":"NOT_RUN"}))
	world.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
