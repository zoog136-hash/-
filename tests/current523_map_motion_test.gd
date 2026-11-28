extends SceneTree

const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const FIXTURE = preload("res://tests/current523_aden_play_renderer_test.gd")
const CONTROLLER = preload("res://scripts/maps/current523_aden_play_controller.gd")
const COVER = preload("res://scripts/boot/dungeon_loading.gd")
const STEP: float = 1.0 / 60.0

var checks: int = 0
var failures: Array[String] = []
var samples: Dictionary = {}

class DelayedTiles extends FIXTURE.FakeTiles:
	var frame: int = 0
	var requested_at: Dictionary = {}
	func prefetch(id: int) -> bool:
		if not requested_at.has(id): requested_at[id] = frame
		return id != 2 or frame - int(requested_at[id]) >= 6

class Probe extends PLAY:
	var screen := Rect2(48,64,256,128)
	var lead := Vector2(96,0)
	var plan_count: int = 0
	func _view_rect() -> Rect2:
		return _arrival_view if _arrival_view.has_area() else screen
	func _motion_coverage(view: Rect2) -> Rect2:
		return view if _arrival_view.has_area() else view.merge(Rect2(view.position + lead,view.size))
	func _scope_problem() -> String: return ""
	func _refresh_markers() -> void: pass
	func _refresh_collision() -> void: pass
	func _build_frame() -> bool:
		plan_count += 1
		return super._build_frame()

class Host extends Node:
	var player: CharacterBody2D

class FakeTravelController extends RefCounted:
	var ready: bool = true
	var succeeds: bool = true
	var waits: int = 0
	var hidden_gate: bool = false
	var duplicate_blocked: bool = false
	func same_land_prepared(_point: Vector2) -> bool: return ready

class WorldProbe extends "res://scripts/world.gd":
	var gate := FakeTravelController.new()
	var cover_requests: int = 0
	func map_loading_art_pack() -> RefCounted:
		cover_requests += 1
		return null
	func _ready() -> void: pass
	func _exit_tree() -> void: pass
	func current523_aden_source_active() -> bool: return true
	func _aden_play_controller() -> RefCounted: return gate
	func prepare_map_point(_point: Vector2) -> bool:
		gate.waits += 1
		var lock := get_tree().get_first_node_in_group(COVER.GROUP) as CanvasItem
		gate.hidden_gate = lock != null and not lock.is_visible_in_tree() and get_tree().paused
		var duplicate: Dictionary = await travel_map_point(_point, func() -> Dictionary: return {"ok":true})
		gate.duplicate_blocked = not duplicate.get("ok",false)
		await get_tree().process_frame
		return gate.succeeds

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); printerr("MAP_MOTION_FAIL: ",description)

func fixture(host: Host) -> Probe:
	var renderer := Probe.new()
	host.add_child(renderer)
	renderer.set_process(false)
	renderer.player = host.player
	renderer.field = FIXTURE.FIELD.new()
	renderer.field.coordinates.configure([0,0],[64,64],{"basis_x":[24,-12],"basis_y":[24,12],"translation":[0,768]})
	renderer._tile_pack = DelayedTiles.new()
	renderer._chunk_rects = {"lane":Rect2(0,0,2048,320)}
	renderer._raw_chunks = {"lane":{-2:PackedInt64Array([100,90,256, 520,90,512, 1050,90,768, 1570,90,1024])}}
	renderer._configured = true
	renderer._background_atlases = true
	renderer._build_frame()
	renderer._refresh_clock = 0.25
	return renderer

func publish(renderer: Probe) -> void:
	if DisplayServer.get_name()=="headless":
		renderer._release_baked()
		await process_frame
	else:
		await RenderingServer.frame_post_draw

func coverage_run(host: Host, baseline: bool) -> Dictionary:
	var renderer: Probe = fixture(host)
	var tiles: DelayedTiles = renderer._tile_pack
	var overdue: int = 0
	var next_block := Vector2i(1,0)
	var costs: Array[int] = []
	if baseline: renderer.lead = Vector2.ZERO
	await publish(renderer)
	for step: int in range(1,45):
		tiles.frame = step
		renderer.screen.position.x += 8.0
		var began: int = Time.get_ticks_usec()
		if baseline:
			# Reproduce the former 250 ms view-discovery cadence with the same
			# block painter and six-frame atlas delay on both sides.
			renderer._refresh_clock -= STEP
			if renderer._refresh_clock <= 0.0:
				renderer._refresh_clock = 0.25
				renderer._refresh_view()
			renderer._bake_pending(PLAY.PENDING_BAKE_BUDGET_USEC)
		else:
			renderer._process_step(STEP)
		costs.append(Time.get_ticks_usec()-began)
		await publish(renderer)
		if PLAY._block_rect(next_block).intersects(renderer.screen) and not renderer.is_ground_ready(renderer.screen):
			overdue += 1
	var result: Dictionary = {
		"frames_missing_visible_ground": overdue,
		"atlas_requested_frame": tiles.requested_at.get(2,-1),
		"max_step_usec": costs.max(),
		"view_builds": renderer.plan_count,
		"draw_commands": renderer._blocks.get(next_block,{}).get("commands",{})
	}
	renderer.free()
	return result

func preparation(host: Host) -> void:
	var renderer: Probe = fixture(host)
	renderer._ensure_ground()
	var old_block: Dictionary = renderer._blocks[Vector2i.ZERO]
	var earlier: Vector2 = host.player.global_position
	var target := Rect2(1536,64,256,128)
	var controller = CONTROLLER.new()
	await publish(renderer)
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	var source_pixel := Vector2i(105,95)
	if DisplayServer.get_name()!="headless":
		check(root.get_texture().get_image().get_pixelv(source_pixel).r > 0.9,"source floor is visible before travel")
	check(renderer.is_ground_ready(renderer.screen) and not renderer.is_ground_ready(target),"prepared and cold destinations are distinguished")
	var outcome: Dictionary = await COVER.run(host,func() -> Dictionary:
		renderer.begin_arrival_view(target)
		if DisplayServer.get_name()=="headless":
			await process_frame
			renderer._process_step(STEP)
			renderer._release_baked()
		var ready: bool = await controller._wait_arrival(host,renderer)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().get_pixelv(source_pixel).r > 0.9,"source floor stays visible through the cold arrival")
		renderer.end_arrival_view()
		check(host.player.global_position==earlier,"background preparation never publishes a provisional actor position")
		check(renderer._blocks[Vector2i.ZERO].get("viewport")==old_block.get("viewport"),"source viewport survives staging")
		check(renderer.is_ground_ready(target),"staged destination remains cached for the committing caller")
		return {"ok":ready}
	,"지도 이동 준비",false)
	check(outcome.ok and not outcome.has("loading") and not paused,"silent preparation restores input without a cover")
	if DisplayServer.get_name()!="headless":
		var ground: Image = renderer._blocks[Vector2i(3,0)].viewport.get_texture().get_image()
		check(ground.get_pixel(35,91).r > 0.9 and ground.get_pixel(35,91).a > 0.9,"prepared viewport has the original fixture pixel")
	renderer.begin_arrival_view(Rect2(8192,8192,256,128))
	renderer._process_step(STEP)
	check(not await controller._wait_arrival(host,renderer),"unsupported destination fails before commit")
	renderer.end_arrival_view()
	check(renderer.problem.is_empty() and renderer._configured and renderer.is_ground_ready(renderer.screen),"failed staging restores the original renderer and floor")
	check(host.player.global_position==earlier,"failed staging leaves actor and position intact")
	renderer.free()

func travel_dispatch() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	world.set_script(WorldProbe)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var payments := [0]
	var destination := Vector2(1536,50)
	var debit: Callable = func() -> Dictionary:
		payments[0] += 1
		return {"ok":true}
	var warm: Dictionary = await world.travel_map_point(destination,debit)
	check(warm.ok and payments[0]==1 and world.gate.waits==0 and not warm.has("loading"),"prepared magic move commits immediately without a cover")
	world.gate.ready=false
	world.gate.succeeds=false
	var failed: Dictionary = await world.travel_map_point(destination,debit)
	check(not failed.ok and not paused and payments[0]==1 and world.gate.waits==1,"cold failure returns control and never reaches debit")
	check(world.gate.hidden_gate and world.gate.duplicate_blocked,"silent travel uses the same duplicate-input gate")
	world.gate.succeeds=true
	var cold: Dictionary = await world.travel_map_point(destination,debit)
	check(cold.ok and not paused and payments[0]==2 and world.gate.waits==2 and not cold.has("loading"),"cold magic move commits once without a cover")
	world.gate.ready=true
	var scroll: Dictionary = await world.travel_map_point(destination,debit)
	check(scroll.ok and payments[0]==3 and world.gate.waits==2 and not scroll.has("loading"),"a repeat scroll uses the prepared destination immediately")
	check(world.cover_requests==0,"teleports do not load art during destination preparation")
	var dungeon: Dictionary = await world.run_map_loading(func() -> Dictionary: return {"ok":true}, "던전·퇴장 준비")
	check(dungeon.ok and dungeon.has("loading") and world.cover_requests==1,"the shared visible dungeon transition still requests its art")
	world.free()


func camera_projection(host: Host) -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(0,-32)
	camera.zoom = Vector2(0.75,0.75)
	camera.limit_left = -32
	camera.limit_top = 0
	camera.limit_right = 3200
	camera.limit_bottom = 2400
	camera.position_smoothing_enabled = true
	host.player.add_child(camera)
	camera.make_current()
	var renderer := PLAY.new()
	host.add_child(renderer)
	renderer.player = host.player
	var old: Vector2 = host.player.global_position
	var destination := Vector2(3150,1050)
	var predicted: Rect2 = renderer.destination_view(destination,camera)
	check(host.player.global_position==old,"previewing the real camera does not move the actor")
	host.player.global_position=destination
	camera.reset_smoothing()
	camera.force_update_scroll()
	check(predicted.is_equal_approx(renderer._view_rect()),"destination projection agrees with a snapped camera at the map edge")
	host.player.global_position=old
	renderer.free()
	camera.free()


func run() -> void:
	var host := Host.new()
	root.add_child(host)
	host.player = CharacterBody2D.new()
	host.add_child(host.player)
	var baseline: Dictionary = await coverage_run(host,true)
	var updated: Dictionary = await coverage_run(host,false)
	check(updated.atlas_requested_frame < baseline.atlas_requested_frame,"next atlas is requested ahead of the previous timer")
	check(baseline.frames_missing_visible_ground > 0 and updated.frames_missing_visible_ground == 0,"look-ahead covers the delayed fast-walk edge")
	check(not updated.draw_commands.is_empty() and updated.draw_commands == baseline.draw_commands,"prefetch preserves source draw commands and order")
	check(updated.view_builds < 8,"moving view does not rebuild every frame")
	baseline.erase("draw_commands")
	updated.erase("draw_commands")
	samples = {"former_timer":baseline,"look_ahead":updated}
	await preparation(host)
	camera_projection(host)
	await travel_dispatch()
	host.free()
	print("MAP_MOTION_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"headless":DisplayServer.get_name()=="headless"}))
	quit(0 if failures.is_empty() else 1)
