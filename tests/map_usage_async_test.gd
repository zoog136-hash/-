extends SceneTree
const USAGE = preload("res://scripts/maps/current523_map_usage.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const SHA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
var checks: int = 0
var failures: Array[String] = []
var evidence: Array = []
var maximum_pump_usec: int = 0
var folder: String

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MAP_USAGE_ASYNC_FAIL: ",label)

func reset(path: String) -> void:
	USAGE.finish()
	USAGE._worker = USAGE.LedgerWorker.new(path)
	USAGE._recorded.clear()
	USAGE._pending = []
	USAGE._pending_bytes = 0
	USAGE._retained = []
	USAGE._retained_bytes = 0
	USAGE._dropped = 0
	USAGE._committed_drops = 0
	USAGE._result = []
	USAGE._task = -1
	USAGE._force = false
	USAGE._dirty = false
	USAGE._disabled = false
	USAGE._last_flush = Time.get_ticks_msec()
	USAGE._accepted = 0
	USAGE._committed = 0
	USAGE._rejected = 0
	USAGE._conflicts = 0
	USAGE.problem = ""

func offer(unit: String, origin: String = "USER_MAIN", bytes: int = 1000, offset: int = 4, length: int = 8) -> bool:
	return USAGE._enqueue("Map/test.s32",bytes,SHA,unit,offset,length,origin)

func settle() -> void:
	USAGE.flush(true)
	for _i: int in 1000:
		var started: int = Time.get_ticks_usec()
		USAGE.pump()
		maximum_pump_usec = maxi(maximum_pump_usec, Time.get_ticks_usec()-started)
		if USAGE._task < 0 and (USAGE._disabled or (USAGE._pending.is_empty() and USAGE._retained.is_empty() and not USAGE._dirty and USAGE._dropped == USAGE._committed_drops)): return
		await process_frame
	check(false,"worker finishes within fixture frame limit")

func read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func contract() -> void:
	var path: String = folder.path_join("contract.json")
	reset(path)
	check(not USAGE.observe(null,"Map/test.s32",1000,SHA,"fixture"),"non-Main/headless renderer cannot supply evidence")
	check(offer("first") and offer("first") and USAGE._pending.size() == 1,"duplicate ingress is one immutable observation")
	check(USAGE._pending[0].is_read_only(),"worker receives read-only scalar event")
	check(offer("first","AUTOMATED_ACTUAL_MAIN"),"QA origin remains separate")
	check(offer("outside","USER_MAIN",1000,999,8),"invalid byte range does not discard the valid unit")
	USAGE.flush()
	check(not FileAccess.file_exists(path) and USAGE._task == -1,"observe and draw flush do not read/write or submit work")
	await settle()
	var value: Dictionary = read(path)
	var row: Dictionary = value.members["Map/test.s32|"+SHA]
	check(value.schema == 1 and value.inventory_JSONL_SHA256 == USAGE.INVENTORY_SHA and int(value.fixed_Map_Tile_denominator.Map.files) == 8311 and int(value.fixed_Map_Tile_denominator.Tile.files) == 8514 and int(value.fixed_Map_Tile_denominator.Map.original_member_bytes) == 994755558 and int(value.fixed_Map_Tile_denominator.Tile.original_member_bytes) == 297767184,"v1 identity and denominator unchanged")
	check(not value.usage95_verified and not row.whole_file_used and row.original_member_bytes_fully_used_proven == 0,"partial observations never claim full source byte use")
	check(row.origins.USER_MAIN.units.size() == 2 and row.origins.AUTOMATED_ACTUAL_MAIN.units.size() == 1,"origins and units exact")
	check(row.origins.USER_MAIN.source_ranges == {"4:8":true},"only valid source range retained")
	check(USAGE.status().committed_observations == 3 and not USAGE.status().uncommitted,"acknowledged only after atomic save")
	reset(path)
	offer("after-restart")
	await settle()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.has("first"),"restart loads and merges old v1 ledger on worker")
	var old: String = FileAccess.get_file_as_string(path)
	offer("wrong-bytes","USER_MAIN",2000)
	await settle()
	check(FileAccess.get_file_as_string(path) == old and USAGE.status().rejected_observation_attempts == 1,"identity conflict is rejected without changing old evidence")

class SlowWorker extends USAGE.LedgerWorker:
	var gate := Semaphore.new()
	func run(batch: USAGE.Batch, result: Array) -> void:
		gate.wait()
		super.run(batch,result)

func bounded_and_lifetime() -> void:
	var path: String = folder.path_join("bounded.json")
	reset(path)
	var slow := SlowWorker.new(path)
	USAGE._worker = slow
	offer("inflight")
	USAGE.flush(true); USAGE.pump()
	var start: int = Time.get_ticks_usec()
	for i: int in 100: USAGE.flush(true); USAGE.pump()
	var returned: int = Time.get_ticks_usec()-start
	check(USAGE._task >= 0 and not WorkerThreadPool.is_task_completed(USAGE._task),"repeated pump never joins a blocked worker")
	for i: int in USAGE.MAX_PENDING: offer("pending%d" % i)
	check(USAGE._pending.size() <= USAGE.MAX_PENDING and USAGE._pending_bytes <= USAGE.MAX_PENDING_BYTES and USAGE._retained_bytes <= USAGE.MAX_RETAINED_BYTES and USAGE._retained.size() <= USAGE.MAX_RETAINED and USAGE._recorded.size() <= USAGE.MAX_RECENT,"inbox, byte reservation and dedup memory bounded")
	for i: int in USAGE.MAX_RETAINED: offer("retained%d" % i)
	check(not offer("overflow") and USAGE.status().rejected_observation_attempts == 1,"overload is reported, never falsely marked accepted")
	# A scene's exit flush only signals; process-owned worker and inbox survive.
	USAGE.flush(true)
	check(USAGE._pending.size() == USAGE.MAX_PENDING,"scene flush keeps pending evidence alive")
	slow.gate.post()
	# One signal for the in-flight batch and another for the queued batch.
	slow.gate.post()
	slow.gate.post()
	await settle()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.size() == USAGE.MAX_PENDING+USAGE.MAX_RETAINED+1,"all bounded batches survive scene change and commit")
	check(offer("overflow"),"rejected observation can be retried after capacity returns")
	slow.gate.post()
	USAGE.finish()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.has("overflow"),"normal teardown drains final observations")
	evidence.append({"blocked_worker_100_pumps_usec":returned})

func retained_without_draw() -> void:
	var path: String = folder.path_join("retained.json")
	reset(path)
	for i: int in USAGE.MAX_PENDING: offer("fill%d" % i)
	var ground: Array = ["Tile/1.til",1000,SHA,"subimage:1",-1,0,"AUTOMATED_ACTUAL_MAIN"]
	var sprite: Array = ["Sprite/test.sp2",1000,SHA,"stored-bit:0/frame:7",4,8,"AUTOMATED_ACTUAL_MAIN"]
	check(USAGE._enqueue_result.callv(ground) == USAGE.Observation.RETAINED and USAGE._enqueue_result.callv(sprite) == USAGE.Observation.RETAINED,"ground and short-lived static scalars retained under transient pressure")
	check(USAGE._enqueue_result.callv(sprite) == USAGE.Observation.ACCEPTED and USAGE._retained.size() == 2,"retained observations deduplicate")
	check(USAGE._enqueue_result("Map/bad",0,SHA,"bad",0,1,"USER_MAIN") == USAGE.Observation.INVALID and USAGE._retained.size() == 2,"invalid input never enters retry queue")
	# No flush, camera update, redraw or repeated observe: pressure drives pump.
	for _i: int in 1000:
		USAGE.pump()
		if not USAGE.status().uncommitted: break
		await process_frame
	var value: Dictionary = read(path)
	check(value.members[ground[0]+"|"+SHA].origins.AUTOMATED_ACTUAL_MAIN.units.has(ground[3]) and value.members[sprite[0]+"|"+SHA].origins.AUTOMATED_ACTUAL_MAIN.source_ranges == {"4:8":true},"retained ground and static evidence commits without another draw")
	reset(path)
	for i: int in USAGE.MAX_PENDING: offer("shutdown%d" % i)
	var shutdown_event: Array = sprite.duplicate()
	shutdown_event[3] = "shutdown-static-frame"
	shutdown_event[4] = 88
	USAGE._enqueue_result.callv(shutdown_event)
	USAGE.finish()
	check(read(path).members[sprite[0]+"|"+SHA].origins.AUTOMATED_ACTUAL_MAIN.units.has("shutdown-static-frame"),"shutdown persists a new retained short-lived frame")
	check(USAGE._retained.is_empty() and not USAGE.status().uncommitted,"normal shutdown drains retained observations too")
	reset(path)
	USAGE._disabled = true
	check(USAGE._enqueue_result.callv(sprite) == USAGE.Observation.DISABLED and USAGE._retained.is_empty(),"disabled recording never spins a retry")
	reset(path)
	for i: int in USAGE.MAX_PENDING + USAGE.MAX_RETAINED: offer("drop-fill%d" % i)
	var missing: Array = sprite.duplicate()
	missing[3] = "hard-never-observed-again"
	missing[4] = 80
	missing[5] = 4
	check(USAGE._enqueue_result.callv(missing) == USAGE.Observation.DROPPED and USAGE.status().dropped_observation_attempts == 1,"hard bound has a distinct drop outcome and counter")
	USAGE.finish()
	check(read(path).recording_dropped_observation_attempts == 1 and USAGE.status().committed_drop_attempts == 1,"drop attempt is recorded durably without claiming the missing unit")
	check(not read(path).members[sprite[0]+"|"+SHA].origins.AUTOMATED_ACTUAL_MAIN.units.has(missing[3]) and not read(path).members[sprite[0]+"|"+SHA].origins.AUTOMATED_ACTUAL_MAIN.source_ranges.has("80:4"),"hard-dropped frame/range is absent rather than falsely acknowledged")
	reset(path); offer("after-drop-restart"); await settle()
	check(read(path).recording_dropped_observation_attempts == 1,"v1 reload preserves the prior drop counter")

# Real production draw callbacks in a visible synthetic Main-owned harness.
# Suppress gameplay setup; never select or modify the player's ledger/profile.
class DrawWorld extends "res://scripts/world.gd":
	func _ready() -> void: set_process(false)
	func _exit_tree() -> void: pass

class DrawGround extends "res://scripts/maps/current523_aden_play_renderer.gd":
	func _view_rect() -> Rect2: return Rect2(-100,-100,1000,1000)

class UsageTiles extends RefCounted:
	var identity_reads: int = 0
	func source_usage_identity(_id: int) -> Dictionary:
		identity_reads += 1
		return {"member":"Tile/1.til","bytes":1000,"sha256":SHA}

func visible_draw_retention() -> void:
	if DisplayServer.get_name() == "headless": return
	var path: String = folder.path_join("visible-draw.json")
	reset(path)
	for i: int in USAGE.MAX_PENDING: offer("draw-fill%d" % i)
	var world := Node2D.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	world.set_script(DrawWorld) # Attach after ready: no gameplay onready/bootstrap.
	world.scene_file_path = "res://Main.tscn"
	var ground := DrawGround.new()
	world.set("field_renderer", ground)
	world.set("current523_aden_play_active", true)
	ground.field = PlayableField.new()
	ground.field.set_meta("current523_source_field",true)
	ground._configured = true
	ground._tile_pack = UsageTiles.new()
	ground._visible_blocks.assign([Vector2i.ZERO])
	var viewport := SubViewport.new()
	viewport.size = Vector2i(4,4)
	ground.add_child(viewport)
	ground._blocks[Vector2i.ZERO] = {"viewport":viewport,"commands":{-2:PackedInt64Array([0,0,0x101,24,0,0x102,48,0,0x101,950,0,0x103])}}
	var canvas := Node2D.new()
	ground.add_child(canvas)
	var draws: Array = [0,0]
	canvas.draw.connect(func() -> void: draws[0] += 1; ground._draw_tiles(canvas))
	var static_spr = load("res://scripts/maps/current523_static_spr.gd").new()
	static_spr.set_process(false)
	var pixels := Image.create_empty(4,4,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	static_spr._draws.assign([{"texture":ImageTexture.create_from_image(pixels),"point":Vector2.ZERO,"member":"Sprite/test.sp2","source_sp2_bytes":1000,"source_sp2_sha256":SHA,"stored_group_bit":0,"frame":7,"source_token":{},"record":{"source_member":"Map/test.s32","source_bytes":1000,"source_sha256":SHA,"source_byte_offset":40,"raw_bytes":PackedByteArray([1,2,3,4])}}])
	static_spr.draw.connect(func() -> void: draws[1] += 1)
	ground.add_child(static_spr)
	world.add_child(ground)
	check(USAGE.actual_main(ground),"visible harness passes unchanged production Main gate")
	await RenderingServer.frame_post_draw
	check(draws[0] > 0 and draws[1] > 0 and USAGE._retained.size() == 4,"real ground/static draw callbacks retain all four observations")
	check(ground._tile_pack.identity_reads == 1,"distinct visible subimages from one atlas share one source identity lookup")
	world.hide() # The short-lived static frame disappears, and camera is idle.
	check(USAGE.observe_result(ground,"Sprite/test.sp2",1000,SHA,"unseen-hidden-frame") == USAGE.Observation.INVALID and USAGE._retained.size() == 4,"hidden Main cannot create new evidence while already observed scalars remain retryable")
	var prior_draws: Array = draws.duplicate()
	for _i: int in 1000:
		USAGE.pump()
		if not USAGE.status().uncommitted: break
		await process_frame
	var value: Dictionary = read(path)
	check(draws == prior_draws and value.members.has("Tile/1.til|"+SHA) and value.members.has("Sprite/test.sp2|"+SHA) and value.members["Map/test.s32|"+SHA].origins.AUTOMATED_ACTUAL_MAIN.source_ranges.has("40:4"),"production draw evidence drains after hiding without any redraw or camera update")
	var units: Dictionary = value.get("members",{}).get("Tile/1.til|"+SHA,{}).get("origins",{}).get("AUTOMATED_ACTUAL_MAIN",{}).get("units",{})
	check(units.has("subimage:1") and units.has("subimage:2") and not units.has("subimage:3"),"each visible subimage keeps its evidence and the offscreen subimage stays unobserved")
	world.free()

class MissingResultWorker extends USAGE.LedgerWorker:
	func run(envelope: USAGE.Batch, _result: Array) -> void:
		envelope.events = []

func missing_result() -> void:
	var path: String = folder.path_join("missing-result.json")
	reset(path)
	USAGE._worker = MissingResultWorker.new(path)
	offer("unknown")
	await settle()
	check(USAGE._disabled and USAGE.status().uncommitted and not USAGE.problem.is_empty() and not FileAccess.file_exists(path),"missing worker result cannot crash gameplay or falsely acknowledge storage")

func payload_bound() -> void:
	var path: String = folder.path_join("payload-bound.json")
	reset(path)
	var accepted: int = 0
	var member: String = "Map/" + "p".repeat(1020)
	for i: int in 1000:
		if USAGE._enqueue(member,1000,SHA,("u%04d" % i)+"x".repeat(250),0,1,"USER_MAIN"): accepted += 1
	check(accepted > 0 and accepted < 1000 and USAGE._pending_bytes <= USAGE.MAX_PENDING_BYTES and USAGE._retained_bytes <= USAGE.MAX_RETAINED_BYTES,"byte cap applies independently of event-count cap")
	check(USAGE._pending.size() + USAGE._retained.size() == accepted and USAGE.status().rejected_observation_attempts == 1000-accepted,"saturated byte queue never claims rejected events")
	await settle()
	check(read(path).members[member+"|"+SHA].origins.USER_MAIN.units.size() == accepted,"all accepted byte-bound events survive persistence")

func failures_and_recovery() -> void:
	var path: String = folder.path_join("recover.json")
	reset(path); offer("old"); await settle()
	var old: String = FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(path+".tmp")
	offer("new"); USAGE.flush(true); USAGE.pump()
	while USAGE._task >= 0:
		USAGE.pump(); await process_frame
	check(USAGE._dirty and not USAGE.problem.is_empty() and FileAccess.get_file_as_string(path) == old,"failed atomic write retains old file and uncommitted worker state")
	USAGE.finish()
	check(USAGE._task < 0 and USAGE._dirty and USAGE.status().uncommitted,"failed shutdown has bounded retries and never claims durability")
	DirAccess.remove_absolute(path+".tmp")
	await settle()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.has("new") and not USAGE.status().uncommitted,"retry commits retained delta after storage recovers")
	# Orphan temp is never mistaken for committed evidence after restart.
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE); file.store_string("partial"); file.close()
	reset(path); offer("restart"); await settle()
	check(read(path).members["Map/test.s32|"+SHA].origins.USER_MAIN.units.has("old"),"restart ignores incomplete temp and preserves committed observations")
	for content: String in ["{broken", '{"schema":2}', '{"schema":1,"inventory_JSONL_SHA256":"wrong","members":{}}']:
		path = folder.path_join("corrupt%d.json" % checks)
		file = FileAccess.open(path,FileAccess.WRITE); file.store_string(content); file.close()
		reset(path); offer("must-not-overwrite"); await settle()
		check(USAGE._disabled and FileAccess.get_file_as_string(path) == content and USAGE.status().uncommitted,"corrupt/incompatible ledger is retained byte-for-byte with explicit uncommitted status")
	# No save writer state/path is shared with game saves.
	var save_path: String = folder.path_join("player-save.json")
	WRITER.write(save_path,{"progress":42,"items":[7,8],"boss":12345})
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	reset(folder.path_join("separate-ledger.json")); offer("separate"); await settle()
	check(FileAccess.get_file_as_bytes(save_path) == save_bytes,"game-save sentinel remains byte-identical")

func benchmark(target_bytes: int) -> void:
	var path: String = folder.path_join("bench%d.json" % target_bytes)
	var units: Dictionary = {}
	for i: int in int(target_bytes / 196): units[("u%08d" % i) + "x".repeat(180)] = true
	var key: String = "Map/test.s32|"+SHA
	var value: Dictionary = {"schema":1,"inventory_JSONL_SHA256":USAGE.INVENTORY_SHA,"members":{key:{"member":"Map/test.s32","sha256":SHA,"original_member_bytes":1000,"usage":"PARTIAL_OBSERVATION","whole_file_used":false,"original_member_bytes_fully_used_proven":0,"origins":{"USER_MAIN":{"units":units,"source_ranges":{"4:8":true}}}}}}
	WRITER.write(path,value)
	var original: String = FileAccess.get_file_as_string(path)
	var started: int = Time.get_ticks_usec()
	var parsed: Dictionary = read(path)
	var parse_usec: int = Time.get_ticks_usec()-started
	parsed.members[key].origins.USER_MAIN.units["bench-new"] = true
	started = Time.get_ticks_usec()
	WRITER.write(path,parsed)
	var write_usec: int = Time.get_ticks_usec()-started
	var expected: Dictionary = read(path).members
	WRITER.write_text(path,original)
	reset(path)
	var memory: int = OS.get_static_memory_usage()
	started = Time.get_ticks_usec()
	offer("bench-new"); USAGE.flush(true)
	var ingress_usec: int = Time.get_ticks_usec()-started
	var ingress_memory: int = OS.get_static_memory_usage()-memory
	started = Time.get_ticks_usec()
	await settle()
	var wall_usec: int = Time.get_ticks_usec()-started
	check(read(path).members == expected,"benchmark exact committed units/ranges match synchronous v1 at %d bytes" % original.length())
	evidence.append({"ledger_bytes":original.to_utf8_buffer().size(),"sync_first_parse_usec":parse_usec,"sync_write_usec":write_usec,"render_ingress_and_flush_usec":ingress_usec,"worker_read_merge_write_usec":USAGE._last_worker_usec,"ready_wall_usec":wall_usec,"ingress_static_bytes_delta":ingress_memory,"process_static_bytes_delta_during_worker":OS.get_static_memory_usage()-memory,"process_static_peak_bytes":OS.get_static_memory_peak_usage()})

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--crash-fixture="):
			reset(arg.trim_prefix("--crash-fixture="))
			USAGE._worker = SlowWorker.new(arg.trim_prefix("--crash-fixture="))
			offer("crash-uncommitted")
			USAGE.flush(true); USAGE.pump()
			print("CRASH_FIXTURE_PENDING ", JSON.stringify(USAGE.status()))
			return
		if arg.begins_with("--exit-fixture="):
			reset(arg.trim_prefix("--exit-fixture="))
			for i: int in USAGE.MAX_PENDING: offer("exit-fill%d" % i)
			offer("exit-unflushed")
			quit() # Autoload teardown, not an explicit test drain.
			return
	root.get_node("MapUsagePump").set_process(false)
	folder = ProjectSettings.globalize_path("user://map-usage-async-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	await contract()
	await bounded_and_lifetime()
	await retained_without_draw()
	await visible_draw_retention()
	await missing_result()
	await payload_bound()
	await failures_and_recovery()
	for size: int in [800000,3000000,5600000]: await benchmark(size)
	USAGE.finish()
	print("MAP_USAGE_ASYNC_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"maximum_poll_submit_usec":maximum_pump_usec,"synthetic_only":true}))
	quit(0 if failures.is_empty() else 1)
