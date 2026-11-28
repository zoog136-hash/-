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
	var return_attempts := 0
	var return_ok := true
	var return_committed_before_arrival := false
	var play: RefCounted
	func run_map_loading(operation: Callable, title: String) -> Dictionary:
		return await LOADER.run(self, operation, title)
	func dungeon523_return_to_village_loading() -> Dictionary:
		return_attempts += 1
		var tree := get_tree()
		var overlay := tree.get_first_node_in_group(LOADER.GROUP)
		return_committed_before_arrival = tree.paused and overlay != null and play.state.active.is_empty()
		var repeat: Dictionary = await LOADER.run(self, Callable(self, "dungeon523_return_to_village_loading"))
		if not repeat.get("busy", false): return {"ok": false}
		await tree.process_frame
		if not return_ok: return {"ok": false, "reason": "fixture arrival failed"}
		return dungeon523_return_to_village()

class Blessing extends RefCounted:
	var blessing := 50
	func export_state() -> Dictionary: return {"blessing":blessing}

class OrimHost extends SPECIAL.Host:
	var field_map := Node.new()
	var rng := RandomNumberGenerator.new()
	var ain_service := Blessing.new()
	var source_field := true
	var blessing_at_arrival := -1
	var source_saves: Array[Dictionary] = []
	var uncertain_save := false
	func _is_walkable_world(_point: Vector2) -> bool: return true
	func orim_current_land() -> Dictionary:
		return super.orim_current_land() if source_field else {}
	func commit_dungeon_play(candidate: Dictionary, changes: Dictionary) -> Error:
		var written: Error = super.commit_dungeon_play(candidate, changes)
		if written == OK and changes.has("ainhasad_state"): ain_service.blessing = int(changes.ainhasad_state.blessing)
		return written
	func orim_enter_land_loading(land_id: int, bounds: Array, save: Dictionary = {}) -> Dictionary:
		await get_tree().process_frame
		return orim_enter_land(land_id, bounds, save)
	func orim_enter_land(land_id: int, bounds: Array, save: Dictionary = {}) -> Dictionary:
		blessing_at_arrival = ain_service.blessing
		moves.append([land_id, bounds])
		if not move_ok: return {"ok":false, "reason":"도착 셀 없음"}
		if not save_ok: return {"ok":false, "reason":"이동 저장 실패"}
		if uncertain_save: return {"ok":false, "uncertain":true, "reason":"입장 저장 활성화 미확정"}
		if not save.is_empty(): source_saves.append(save.duplicate(true))
		land = land_id
		return {"ok":true, "saved":not save.is_empty()}

class OrimRules extends SPECIAL.Rules:
	var orim_actor_types: Dictionary = {100:"Monster"}
	func ensure_orim() -> bool: return true
	func stage(kind: String, id: int) -> Dictionary:
		if kind!="orim" or id!=2: return {}
		return {"stage":{"IsHard":false}, "prerequisites":[{"type":"MinLevel","row":{"Value":80}}],
			"spawns":[], "normal_rewards":[], "lucky_rewards":[], "sections":[]}

class OrimPlay extends PLAY:
	func orim_model() -> Dictionary:
		return {"ok":true, "characters":[{"id":2,"hp":350,"hidden":false,"start_group":0}], "groups":{},
			"stages":{2:{"land_id":48752,"land_name":"게렝의 집","territory":{"StartX":10,"StartY":20,"EndX":12,"EndY":22}}}}

func orim_entry() -> void:
	var orim_host := OrimHost.new()
	root.add_child(orim_host)
	orim_host.player = Node2D.new()
	orim_host.add_child(orim_host.player)
	orim_host.add_child(orim_host.field_map)
	orim_host.source_dungeon_runs = SPECIAL.Runs.new()
	orim_host.level = 80
	var orim_play := OrimPlay.new()
	orim_play.configure(orim_host, OrimRules.new())
	orim_play.template = {"name":"fixture"}
	var now := 1800000000
	orim_host.move_ok = false
	var refused: Dictionary = await orim_play.begin_loading("orim", 2, now, 2)
	check(not refused.ok and orim_host.land == 4 and orim_host.blessing_at_arrival == 50, "Orim cannot charge while its original destination is refused")
	check(orim_host.ain_service.blessing == 50 and orim_play.state.active.is_empty() and orim_play.state.attempts.is_empty() and orim_host.saved.is_empty(), "a refused Orim move consumes neither Ain nor the daily attempt")
	if not orim_play.state.active.is_empty():
		orim_host.free()
		return
	orim_host.move_ok = true
	orim_host.save_ok = false
	check(not (await orim_play.begin_loading("orim", 2, now, 2)).ok and orim_host.land == 4 and orim_host.ain_service.blessing == 50 and orim_host.source_saves.is_empty(), "failed arrival save leaves the Orim origin and fee untouched")
	orim_host.save_ok = true
	var success: Dictionary = await orim_play.begin_loading("orim", 2, now, 2)
	check(success.ok and success.travel and orim_host.land == 48752 and orim_host.ain_service.blessing == 40 and orim_host.source_saves.size() == 1 and orim_host.saved.is_empty(), "exact Orim Land, fee and attempt commit in a single arrival save")
	if not orim_host.source_saves.is_empty():
		var saved: Dictionary = orim_host.source_saves[0]
		check(saved.source_dungeon_play == orim_play.state and saved.ainhasad_state.blessing == 40 and orim_play.state.active.home == {"land_id":4,"cell":[10,10]}, "the saved run contains the original return point and exact debit")
	check(not (await orim_play.begin_loading("orim", 2, now, 2)).ok and orim_host.source_saves.size() == 1, "an active Orim attempt cannot debit twice")
	orim_host.source_field = false
	orim_play.state = PLAY.empty_state()
	var local: Dictionary = await orim_play.begin_loading("orim", 2, now, 2)
	check(local.ok and not local.travel and orim_host.ain_service.blessing == 30 and not orim_play.state.active.has("land"), "the existing current-field practice route remains available without a source field")
	orim_host.source_field = true
	orim_play.state = PLAY.empty_state()
	orim_host.uncertain_save = true
	check(not orim_play.begin("orim", 2, now, 2).ok and orim_play.save_blocked and orim_play.state.active.is_empty() and orim_host.ain_service.blessing == 30, "uncertain synchronous arrival save blocks retry without publishing a debit")
	var move_count: int = orim_host.moves.size()
	check(not orim_play.begin("orim", 2, now, 2).ok and orim_host.moves.size() == move_count, "uncertainty cannot call map travel again")
	orim_host.free()

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
	special.play=play
	special.save_ok=false
	var exit_failed: Dictionary=await play.stop_loading()
	check(not exit_failed.ok and special.land==22701 and special.return_attempts==0 and not play.state.active.is_empty(),"failed exit save cannot start a return or close the run")
	special.save_ok=true
	var exit_success: Dictionary=await play.stop_loading()
	check(exit_success.ok and exit_success.loading.painted and not paused,"manual exit shows the shared overlay and restores input")
	check(special.return_committed_before_arrival and special.land==4 and special.returns==1,"successful exit saves closure before awaiting the sole village return")
	check((await play.stop_loading()).ok and special.return_attempts==1,"repeated exit after closure does not return twice")
	check((await play.begin_loading("special",41,1800000000)).ok,"start a separate run for a return-map failure")
	special.return_ok=false
	var rejected_map: Dictionary=await play.stop_loading()
	check(not rejected_map.ok and rejected_map.closed and not paused and play.state.active.is_empty(),"failed return is reported separately from the confirmed dungeon closure")
	check(special.land==22701 and play.special_return_land==22701,"failed return keeps the current Land and the existing retry target")
	play._retry_special_return()
	check(special.land==4 and play.special_return_land==-1 and special.returns==2,"successful retry clears the pending return without reopening the dungeon")
	special.free()
	await orim_entry()
	frames.sort()
	print("DUNGEON_LOADING_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"timings":timings,"frame_usec_max":frames.back() if not frames.is_empty() else 0,"scope":"SYNTHETIC_LINUX; NOT_ANDROID_OR_ORIGINAL_PACK"}))
	quit(0 if failures.is_empty() else 1)
