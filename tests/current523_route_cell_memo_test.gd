extends SceneTree
const BASE = preload("res://scripts/maps/source_field.gd")
const FIELD = preload("res://scripts/maps/current523_aden_source_field.gd")
var checks := 0
var failures: Array[String] = []

class Fixture extends FIELD:
	var baseline: bool = false
	var cell_reads: int = 0
	func _cell_allowed(cell: Vector2i) -> bool:
		cell_reads += 1
		return super._cell_allowed(cell)
	func _new_path_navigator() -> TwilightL1JSourceNavigation:
		if not baseline: return super._new_path_navigator()
		var nav := BASE.OriginalChunkNavigation.new()
		nav.source = self
		return nav

	func populate(gap: int) -> void:
		width = 128
		height = 128
		coordinates.configure([0,0], [width,height])
		loaded = true
		_raw_cache.clear()
		_raw_recent.clear()
		_last_raw_chunk = {}
		for y: int in [0,64]:
			for x: int in [0,64]:
				var origin := Vector2i(x,y)
				var key: String = str(origin)
				_source_chunks[origin] = key
				var attrs := PackedByteArray()
				attrs.resize(16384)
				var floor_data := PackedByteArray()
				floor_data.resize(32768)
				if x == 64:
					for local_y: int in range(64):
						if y + local_y == gap: continue
						attrs.encode_u16(local_y*256,1)
				_raw_cache[key] = {"sections":{"attributes":attrs,"floor":floor_data}}
				_raw_recent.append(key)

class WorldProbe extends TwilightWorld:
	func equipment523_can_detect(_actor: TwilightMonster) -> bool:
		return true

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CURRENT523_ROUTE_MEMO_FAIL ",label)

func _initialize() -> void:
	_run.call_deferred()

func profile(f: Fixture, baseline: bool, a: Vector2, b: Vector2) -> Dictionary:
	f.baseline = baseline
	f.cell_reads = 0
	var started: int = Time.get_ticks_usec()
	var path: PackedVector2Array = f.path(a,b)
	return {"path":path,"us":Time.get_ticks_usec()-started,"reads":f.cell_reads}

func sliced(f: Fixture, from: Vector2, to: Vector2, work: Dictionary = {}) -> Dictionary:
	var max_us: int = 0
	var count: int = 0
	var step: Dictionary = {}
	for _i: int in 512:
		var started: int = Time.get_ticks_usec()
		step = f.hunt_path_step(from,to,work)
		max_us = maxi(max_us,Time.get_ticks_usec()-started)
		count += 1
		if not bool(step.pending):
			return {"ok":true,"path":step.path,"max_us":max_us,"slices":count}
		work = step.work
	return {"ok":false,"path":PackedVector2Array(),"max_us":max_us,"slices":count}

func check_world_budget(f: Fixture) -> Dictionary:
	f.populate(75)
	var world := WorldProbe.new()
	world.field_map = f
	world.player = load("res://scenes/Player.tscn").instantiate()
	world.monsters_root = Node2D.new()
	root.add_child(world.player)
	root.add_child(world.monsters_root)
	world.player.set_physics_process(false)
	world.player.global_position = f.cell_to_world(Vector2i(42,12))
	var target: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(target)
	target.set_physics_process(false)
	target.global_position = f.cell_to_world(Vector2i(85,12))
	var expected: PackedVector2Array = f.path(world.player.global_position,target.global_position)
	var result: PackedVector2Array = world._acquire_auto_target()
	check(result.is_empty() and world.auto_target_failed_paths.is_empty() and world.auto_target_path_checks == 1,"Main retains pending route without blacklisting the target")
	var handle: Dictionary = world._auto_source_search_work
	var before_reads: int = f.cell_reads
	world._acquire_auto_target()
	check(not handle.is_empty() and world._auto_source_search_work == handle and f.cell_reads == before_reads,"Main does not advance a second slice in the same frame")
	var longest: int = 0
	var frames: int = 0
	for _i: int in 180:
		await process_frame
		var started: int = Time.get_ticks_usec()
		result = world._acquire_auto_target()
		longest = maxi(longest,Time.get_ticks_usec()-started)
		frames += 1
		if not result.is_empty(): break
	check(not expected.is_empty() and result == expected and world.auto_target == target,"Main selects the same live actor and exact route after successive frames")
	check(world.auto_target_path_checks == 1 and world._auto_source_search_work.is_empty(),"Main completes one logical search, clears finished work")
	world.player.free()
	world.monsters_root.free()
	world.free()
	return {"continuation_frames":frames,"largest_continuation_us":longest}

func _run() -> void:
	var f := Fixture.new()
	var summary: Dictionary = {}
	for rule: String in [FIELD.CLIENT_RULE,FIELD.OWN_RULE]:
		f.policy = {"attribute_rule":rule,"allowed_mask":0,"must_mask":0,"forbidden_mask":0,"path_search_limit":8192}
		f._use_allowlist = false
		f.populate(75)
		var start: Vector2 = f.cell_to_world(Vector2i(42,12))
		var target: Vector2 = f.cell_to_world(Vector2i(85,12))
		var local: Vector2 = f.cell_to_world(Vector2i(43,12))
		check(f.path(start,local) == PackedVector2Array([local]), rule+" direct route still bypasses A*")
		check(f.path(start,f.cell_to_world(Vector2i(64,12))).is_empty(),rule+" blocked endpoint rejected")
		check(f.path(start,Vector2.INF).is_empty(),rule+" nonfinite endpoint rejected")
		var before: Dictionary = {}
		var after: Dictionary = {}
		var old_times: Array[int] = []
		var new_times: Array[int] = []
		for i: int in range(9):
			if i % 2 == 0:
				before = profile(f,true,start,target)
				after = profile(f,false,start,target)
			else:
				after = profile(f,false,start,target)
				before = profile(f,true,start,target)
			old_times.append(int(before.us))
			new_times.append(int(after.us))
			check(not before.path.is_empty() and before.path == after.path,rule+" detour has exactly the same points "+str(i))
		old_times.sort()
		new_times.sort()
		summary[rule] = {"base_us":old_times[4],"memo_us":new_times[4],"base_cell_reads":before.reads,"memo_cell_reads":after.reads,"path_points":after.path.size()}
		check(int(after.reads)*2 < int(before.reads),rule+" redundant source-cell evaluations reduced by at least half")
		var paced: Dictionary = sliced(f,start,target)
		check(paced.ok and paced.path == before.path and paced.slices > 1,rule+" resumable detour returns the exact synchronous route")
		summary[rule]["largest_slice_us"] = paced.max_us
		summary[rule]["slices"] = paced.slices
		var pending: Dictionary = f.hunt_path_step(start,target)
		check(pending.pending,rule+" long route remains pending rather than failing")
		if pending.pending:
			var different: Vector2 = f.cell_to_world(Vector2i(85,110))
			check(sliced(f,start,different,pending.work).path == f.path(start,different),rule+" moved target cannot receive the previous route")
			var other := Fixture.new()
			other.policy = f.policy.duplicate()
			other._use_allowlist = false
			other.populate(-1)
			check(sliced(other,start,target,pending.work).path.is_empty(),rule+" replaced field cannot publish the previous route")
		f.path_search_limit_override = 2
		check(profile(f,true,start,target).path == profile(f,false,start,target).path and f.path(start,target).is_empty(),rule+" existing full-search cap and failure unchanged")
		f.path_search_limit_override = -1
		f.populate(-1)
		check(profile(f,true,start,target).path == profile(f,false,start,target).path and f.path(start,target).is_empty(),rule+" new query sees closed gap, no stale verdict")
		var no_route: Dictionary = sliced(f,start,target)
		check(no_route.ok and no_route.path.is_empty() and no_route.slices>1,rule+" sliced exhaustion completes without a fabricated route")
	var world_result: Dictionary = await check_world_budget(f)
	print("CURRENT523_ROUTE_MEMO_RESULT ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"synthetic":summary,"world_fixture":world_result}))
	quit(0 if failures.is_empty() else 1)
