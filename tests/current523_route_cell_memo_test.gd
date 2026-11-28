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

func check_world_budget(f: Fixture) -> Dictionary:
	f.populate(75)
	var world := WorldProbe.new()
	world.field_map = f
	world.player = load("res://scenes/Player.tscn").instantiate()
	world.monsters_root = Node2D.new()
	root.add_child(world.player)
	root.add_child(world.monsters_root)
	world.player.set_physics_process(false)
	world.player.global_position = f.cell_to_world(Vector2i(59,12))
	var target: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(target)
	target.set_physics_process(false)
	target.global_position = f.cell_to_world(Vector2i(68,12))
	var expected: PackedVector2Array = f.path(world.player.global_position,target.global_position)
	var result: PackedVector2Array = world._acquire_auto_target()
	check(result.is_empty() and world.auto_target_failed_paths.is_empty() and world.auto_target_path_checks == 1,"Main retains pending route without blacklisting the target")
	var handle: Dictionary = world._auto_source_search_work
	var before_reads: int = f.cell_reads
	world._acquire_auto_target()
	check(not handle.is_empty() and world._auto_source_search_work == handle and f.cell_reads == before_reads,"Main does not advance a second slice in the same frame")
	var acquired_at: int = Time.get_ticks_usec()
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
	# Beginning work for the old cell, then moving the same actor, must not
	# publish the obsolete route or treat the move as a path failure.
	await process_frame
	world._acquire_auto_target()
	check(not world._auto_source_search_work.is_empty(),"Main has pending work for the old target cell")
	await process_frame
	target.global_position = f.cell_to_world(Vector2i(61,12))
	result = world._acquire_auto_target()
	check(result == PackedVector2Array([target.global_position]) and world.auto_target == target and world.auto_target_failed_paths.is_empty(),
		"Main changes to the target's new cell without publishing the old route")
	# If the same actor comes into attack range, no walking route is needed.
	await process_frame
	target.global_position = f.cell_to_world(Vector2i(68,12))
	world._acquire_auto_target()
	check(not world._auto_source_search_work.is_empty(), "a new pursuit search has pending work")
	await process_frame
	target.global_position = f.cell_to_world(Vector2i(60,12))
	var route_checks: int = world.auto_target_path_checks
	result = world._acquire_auto_target()
	check(result.is_empty() and world.auto_target == target and world._auto_source_search_work.is_empty() \
		and world.auto_target_failed_paths.is_empty() and world.auto_target_path_checks == route_checks,
		"an actor entering weapon range and sight releases pending route work without starting another search")
	world.player.free()
	world.monsters_root.free()
	world.free()
	return {"continuation_frames":frames,"largest_continuation_us":longest,"fixture_elapsed_us":Time.get_ticks_usec()-acquired_at}

func _run() -> void:
	var f := Fixture.new()
	var summary: Dictionary = {}
	var exact_routes: Array = []
	for rule: String in [FIELD.CLIENT_RULE,FIELD.OWN_RULE]:
		f.policy = {"attribute_rule":rule,"allowed_mask":0,"must_mask":0,"forbidden_mask":0,"path_search_limit":8192}
		f._use_allowlist = false
		f.populate(75)
		var start: Vector2 = f.cell_to_world(Vector2i(42,12))
		var target: Vector2 = f.cell_to_world(Vector2i(85,12))
		var local: Vector2 = f.cell_to_world(Vector2i(43,12))
		f.cell_reads = 0
		check(f.path(start,local) == PackedVector2Array([local]), rule+" direct route still bypasses A*")
		check(f.cell_reads == 4, rule+" direct ray reads two endpoints once plus the edge check")
		f.cell_reads = 0
		check(f.path(start,start) == PackedVector2Array([start]) and f.cell_reads == 1,
			rule+" same-cell endpoints share one verdict")
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
		exact_routes.append(Array(after.path).map(func(point: Vector2) -> Vector2i: return f.world_to_cell(point)))
		# Exercise different tie patterns, seams, limits, direct rays and lifts
		# around the same obstacle. Retain the exact grid waypoint sequence.
		for i: int in range(24):
			var a: Vector2 = f.cell_to_world(Vector2i(60-i%8,7+i*4))
			var b: Vector2 = f.cell_to_world(Vector2i(67+i%11,10+i*4))
			f.path_search_limit_override = [64,256,8192][i%3]
			var old: PackedVector2Array = profile(f,true,a,b).path
			var new: PackedVector2Array = profile(f,false,a,b).path
			check(old == new,rule+" crossing route exact "+str(i))
			exact_routes.append(Array(new).map(func(point: Vector2) -> Vector2i: return f.world_to_cell(point)))
		var expected: PackedVector2Array = f.path(start,target)
		var started: int = Time.get_ticks_usec()
		var peak: int = 0
		var slices: int = 0
		var work: Dictionary = {}
		var sliced := PackedVector2Array()
		while slices < 256:
			var step_started: int = Time.get_ticks_usec()
			var step: Dictionary = f.hunt_path_step(start,target,work)
			peak = maxi(peak,Time.get_ticks_usec()-step_started)
			slices += 1
			if not step.pending:
				sliced = step.path
				break
			work = step.work
			check(work.search.visited.size() <= 8192,rule+" actual visited count stays within the cap")
		check(slices > 1 and sliced == expected and not sliced.is_empty(),rule+" sliced detour matches exact synchronous waypoints")
		summary[rule]["hunt_slices"] = slices
		summary[rule]["hunt_peak_us"] = peak
		summary[rule]["hunt_cpu_us"] = Time.get_ticks_usec()-started
		var pending: Dictionary = f.hunt_path_step(start,target)
		check(bool(pending.pending),rule+" obstructed query yields")
		var moved: Dictionary = f.hunt_path_step(start,local,pending.get("work",{}))
		check(not moved.pending and moved.path == PackedVector2Array([local]),rule+" moved target cannot publish old path")
		f.path_search_limit_override = 2
		var capped_step: Dictionary = f.hunt_path_step(start,target,pending.get("work",{}))
		check(not capped_step.pending and capped_step.path.is_empty(),rule+" reduced cap restarts pending search and rejects detour")
		f.path_search_limit_override = 65536
		check(f._path_node_limit() == 8192,rule+" override cannot raise field limit")
		f.path_search_limit_override = 2
		check(profile(f,true,start,target).path == profile(f,false,start,target).path and f.path(start,target).is_empty(),rule+" existing full-search cap and failure unchanged")
		f.path_search_limit_override = -1
		f.populate(-1)
		check(profile(f,true,start,target).path == profile(f,false,start,target).path and f.path(start,target).is_empty(),rule+" new query sees closed gap, no stale verdict")
	f.policy = {"attribute_rule":FIELD.CLIENT_RULE,"allowed_mask":0,"must_mask":0,"forbidden_mask":0,"path_search_limit":8192}
	summary["world_acquisition"] = await check_world_budget(f)
	var signature: String = str(exact_routes).sha256_text()
	# Recorded by the same fixture against main bd9dc3b8 (before the memo
	# and heap changes). Assert waypoints and ties, not just endpoint/length.
	check(signature == "3b9d8b21df94722c0a5a4d0f8c5983f22ea6a5eb4ebb47dc89192b55d84139d5",
		"exact route corpus matches main bd9dc3b8")
	print("CURRENT523_ROUTE_MEMO_RESULT ",JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"synthetic":summary,"route_signature":signature}))
	quit(0 if failures.is_empty() else 1)
