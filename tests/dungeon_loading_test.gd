extends SceneTree
const LOADER = preload("res://scripts/boot/dungeon_loading.gd")
const CONTROLLER = preload("res://scripts/maps/current523_aden_play_controller.gd")
const RENDERER = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const SPECIAL = preload("res://tests/dungeon_special_entry523_test.gd")
const PLAY = preload("res://scripts/dungeons/dungeon_play_service.gd")
const FIELD = preload("res://scripts/maps/source_map_runtime_field.gd")
var checks: int = 0
var failures: Array[String] = []
var calls: int = 0
var host: Node
var timings: Array = []
var frames: Array[int] = []
var last_frame: int = 0
class SpecialHost extends SPECIAL.Host:
	var awaited: int = 0
	func dungeon523_enter_land_loading(land_id: int, bounds: Array, save: Dictionary) -> Dictionary:
		await get_tree().process_frame
		awaited+=1
		return dungeon523_enter_land(land_id,bounds,save)
class Pending extends Node:
	var ticks: int = 0
	var ready_after: int = 4
	var failed: bool = false
	func arrival_readiness() -> Dictionary: return {"ready":ticks>=ready_after,"failed":failed,"reason":"fixture read failure"}
	func _process_step(_delta: float) -> void: ticks+=1
class Ground extends RENDERER:
	func _view_rect() -> Rect2: return Rect2(0,0,512,512)
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func _initialize() -> void: call_deferred("run")
func sample_frame() -> void:
	var now: int=Time.get_ticks_usec()
	if last_frame>0: frames.append(now-last_frame)
	last_frame=now
func operation() -> Dictionary:
	calls+=1
	check(paused,"gameplay paused during preparation")
	var overlay: Node=get_first_node_in_group(LOADER.GROUP)
	check(overlay!=null,"overlay exists before preparation")
	if DisplayServer.get_name()!="headless": check(overlay.painted,"real draw precedes operation")
	var repeated: Dictionary=await LOADER.run(host,Callable(self,"operation"))
	check(repeated.get("busy",false) and calls==1,"duplicate tap cannot run operation twice")
	LOADER.report(host,"도착 지역의 바닥을 준비하는 중")
	var pending:=Pending.new();host.add_child(pending)
	var controller=CONTROLLER.new()
	check(await controller._wait_arrival(host,pending),"late readiness eventually completes")
	check(pending.ticks==4,"preparation yields between bounded pumps")
	pending.free()
	return {"ok":true}
func failure() -> Dictionary:
	var pending:=Pending.new();host.add_child(pending);pending.failed=true
	var controller=CONTROLLER.new()
	check(not await controller._wait_arrival(host,pending) and pending.ticks==0,"read failure stops without retry or commit")
	pending.failed=false;controller.arrival_timeout_msec=0
	check(not await controller._wait_arrival(host,pending),"timeout rejects before commit")
	pending.free()
	return {"ok":false,"reason":"fixture failure"}
func run() -> void:
	host=Node.new();root.add_child(host)
	process_frame.connect(sample_frame)
	for iteration: int in 2:
		calls=0
		var result: Dictionary=await LOADER.run(host,Callable(self,"operation"))
		check(result.ok and not paused,"success restores input")
		check(get_first_node_in_group(LOADER.GROUP)==null,"completed guard released")
		timings.append(result.loading)
	var failed: Dictionary=await LOADER.run(host,Callable(self,"failure"))
	check(not failed.ok and not paused,"failure restores input")
	paused=true
	await LOADER.run(host,func() -> Dictionary: return {"ok":false})
	check(paused,"existing pause ownership preserved");paused=false
	var orphan:=Node.new();root.add_child(orphan);orphan.queue_free()
	var cancelled: Dictionary=await LOADER.run(orphan,Callable(self,"operation"))
	check(not cancelled.ok and not paused,"host freed before first paint cancels and restores input")
	var ground:=Ground.new();host.add_child(ground);ground.set_process(false)
	var actor:=Node2D.new();host.add_child(actor)
	ground.player=actor;ground.field=FIELD.new();ground._configured=true
	check(not ground.arrival_readiness().ready,"missing visible ground blocks readiness")
	var empty: Dictionary=ground._bake_block(Vector2i.ZERO,{"commands":{},"atlases":{},"draws":0,"count":0,"raw_ff":0,"unresolved":0})
	ground._blocks[Vector2i.ZERO]=empty
	check(ground.arrival_readiness().ready,"verified empty ground needs no GPU viewport")
	ground._blocks[Vector2i.ZERO]={"presented":false}
	check(not ground.arrival_readiness().ready,"unsubmitted visible block is not ready")
	ground._blocks[Vector2i.ZERO]={"presented":true}
	ground._pending_blocks.append(Vector2i(10,10))
	check(ground.arrival_readiness().ready,"margin work does not delay arrival")
	if DisplayServer.get_name()!="headless":
		ground.hide();ground.process_mode=Node.PROCESS_MODE_DISABLED
		var pixels:=Image.create_empty(384,384,false,Image.FORMAT_RGBA8)
		pixels.fill(Color.RED)
		var texture:=ImageTexture.create_from_image(pixels)
		ground._blocks[Vector2i.ZERO]=ground._bake_block(Vector2i.ZERO,{"commands":{0:PackedInt64Array([0,0,256])},"atlases":{1:texture},"draws":1,"count":1,"raw_ff":0,"unresolved":0})
		check(not ground.arrival_readiness().ready,"actual candidate bake waits for submission")
		await RenderingServer.frame_post_draw
		check(ground.arrival_readiness().ready,"hidden paused candidate viewport renders before commit")
		var rendered: Image=ground._blocks[Vector2i.ZERO].viewport.get_texture().get_image()
		check(rendered!=null and rendered.get_pixel(1,1).r>0.9 and rendered.get_pixel(1,1).a>0.9,"candidate submission contains the fixture pixel")
	ground._unreadable_chunks["broken"]=true;ground._chunk_rects["broken"]=Rect2(0,0,512,512)
	check(ground.arrival_readiness().failed,"unreadable visible chunk cannot become a gray successful arrival")
	ground.problem="fixture unresolved resource"
	check(ground.arrival_readiness().failed,"missing resources cannot release overlay")
	ground._configured=false;ground.free();actor.free();host.free()
	var special:=SpecialHost.new();root.add_child(special)
	special.hud=SPECIAL.Hud.new();special.add_child(special.hud);special.source_dungeon_runs=SPECIAL.Runs.new()
	var rules:=SPECIAL.Rules.new()
	rules.special_by_id[41]=SPECIAL.entry(41,22701,61,10000,55)
	rules.time_by_id[61]={"row":{"ID":61,"TimeLimit":3600,"MaxRechargeTime":7200},"reset":{"Name":"Daily"}}
	var play=PLAY.new();play.configure(special,rules)
	var before: int=special.gold
	special.level=1
	check(not (await play.begin_loading("special",41,1800000000)).ok and special.awaited==0,"loading preserves level refusal before travel")
	special.level=60;special.move_ok=false
	check(not (await play.begin_loading("special",41,1800000000)).ok and special.gold==before and play.state.active.is_empty(),"late failed entry preserves gold and run")
	special.move_ok=true
	check((await play.begin_loading("special",41,1800000000)).ok and special.gold==before-10000 and special.land==22701,"async special entry commits once with arrival")
	check(not (await play.begin_loading("special",41,1800000000)).ok and special.gold==before-10000,"active run cannot debit again")
	special.free()
	frames.sort()
	print("DUNGEON_LOADING_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"timings":timings,"frame_usec_max":frames.back() if not frames.is_empty() else 0,"scope":"SYNTHETIC_LINUX; NOT_ANDROID_OR_ORIGINAL_PACK"}))
	quit(0 if failures.is_empty() else 1)
