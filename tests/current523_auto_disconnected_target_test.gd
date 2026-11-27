extends SceneTree
## Production S32 rules and automatic acquisition, driven by two synthetic rooms.
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
var checks: int = 0
var failures: Array[String] = []

class Rooms extends FIELD:
	var searches: int = 0

	func _new_path_navigator() -> TwilightL1JSourceNavigation:
		searches += 1
		return super._new_path_navigator()

	func populate(gap_y: int = -1, rule: String = CLIENT_RULE) -> void:
		close()
		width = 128
		height = 64
		coordinates.configure([0, 0], [width, height])
		policy = {"attribute_rule":rule, "path_search_limit":8192,
			"allowed_mask":0, "must_mask":0, "forbidden_mask":0}
		_use_allowlist = false
		path_search_limit_override = -1
		# Simulate an admitted reader; all cell bytes here are synthetic.
		catalog_sha256 = "fixture"
		set_meta("current523_generic_field", true)
		loaded = true
		searches = 0
		for chunk_x: int in [0, 64]:
			var origin := Vector2i(chunk_x, 0)
			var member: String = str(origin)
			var attrs := PackedByteArray()
			attrs.resize(16384)
			var floor_refs := PackedByteArray()
			floor_refs.resize(32768)
			for y: int in range(height):
				for x: int in range(chunk_x, chunk_x + 64):
					if (y >= 10 and y < 48 and ((x >= 30 and x < 63) or (x >= 64 and x < 101))) \
						or (x == 63 and y == gap_y):
						continue
					attrs.encode_u16((y * 64 + x - chunk_x) * 4, 1)
			_source_chunks[origin] = member
			_raw_cache[member] = {"sections":{"attributes":attrs,"floor":floor_refs}}
			_raw_recent.append(member)

class ProbeWorld extends TwilightWorld:
	func equipment523_can_detect(actor: TwilightMonster) -> bool:
		return not actor.concealed523

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CURRENT523_AUTO_DISCONNECTED_FAIL ", label)

func route(field: Rooms, from: Vector2, to: Vector2) -> PackedVector2Array:
	var work: Dictionary = {}
	for _slice: int in range(256):
		var step: Dictionary = field.hunt_path_step(from, to, work)
		if not step.pending: return step.path
		work = step.work
	check(false, "cooperative route completed in the fixture")
	return PackedVector2Array()

func add_target(world: ProbeWorld, at: Vector2) -> TwilightMonster:
	var target: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(target)
	target.set_physics_process(false)
	target.global_position = at
	return target

func profile(world: ProbeWorld, winner: TwilightMonster, expected: PackedVector2Array) -> Dictionary:
	var field: Rooms = world.field_map
	var times: Array[int] = []
	var start_searches: int = field.searches
	var total_usec: int = 0
	for _frame: int in range(256):
		await process_frame
		var started: int = Time.get_ticks_usec()
		var actual: PackedVector2Array = world._acquire_auto_target()
		var elapsed: int = Time.get_ticks_usec() - started
		times.append(elapsed)
		total_usec += elapsed
		if not actual.is_empty():
			check(world.auto_target == winner and actual == expected, "world selects the same nearest reachable actor and waypoints")
			break
	check(world.auto_target == winner, "world acquisition finishes")
	times.sort()
	return {"searches":field.searches - start_searches, "callbacks":times.size(),
		"cpu_us":total_usec, "max_us":times[-1], "p95_us":times[ceili(times.size() * 0.95) - 1]}

func run() -> void:
	var field := Rooms.new()
	field.populate()
	check(field.static_pursuit_epoch() != 0, "fixture exercises the admitted 523 route navigator")
	var from: Vector2 = field.cell_to_world(Vector2i(62, 28))
	var across: Vector2 = field.cell_to_world(Vector2i(64, 28))
	check(route(field, from, across).is_empty(), "exhaustive search fails across the separating wall")
	var shifted: Vector2 = field.cell_to_world(Vector2i(61, 28))
	var opposite: Vector2 = field.cell_to_world(Vector2i(65, 29))
	check(route(field, shifted, opposite).is_empty() and field.searches == 1,
		"one complete component serves another start and goal")
	check(route(field, across, opposite) == field.path(across, opposite),
		"an origin outside the proven component keeps its own reachable routes")

	field.populate(45)
	field.path_search_limit_override = 32
	check(route(field, from, across).is_empty(), "low search cap alone can produce a failure")
	field.path_search_limit_override = -1
	var detour: PackedVector2Array = route(field, from, across)
	check(not detour.is_empty() and detour == field.path(from, across),
		"new admission and raised cap still find the exact detour")
	field.populate(-1, FIELD.OWN_RULE)
	check(route(field, from, across).is_empty() and route(field, shifted, opposite).is_empty() and field.searches == 2,
		"nonverified policy does not reuse the component")

	field.populate()
	var world := ProbeWorld.new()
	world.field_map = field
	world.player = load("res://scenes/Player.tscn").instantiate()
	world.monsters_root = Node2D.new()
	root.add_child(world.player)
	root.add_child(world.monsters_root)
	world.player.set_physics_process(false)
	world.player.global_position = from
	for i: int in range(24):
		add_target(world, field.cell_to_world(Vector2i(64 + i / 6, 25 + i % 6)))
	var goal: Vector2 = field.cell_to_world(Vector2i(53, 28))
	var winner: TwilightMonster = add_target(world, goal)
	add_target(world, goal) # Equal distance must preserve original child order.
	var expected: PackedVector2Array = field.path(from, goal)
	var cold: Dictionary = await profile(world, winner, expected)
	check(cold.searches == 1, "24 unreachable actors require only one real search")
	# Simulate expiration of the per-actor retry cache during the same field admission.
	world.auto_target_failed_paths.clear()
	var warm: Dictionary = await profile(world, winner, expected)
	check(warm.searches == 0, "subsequent acquisition reuses the same disconnected terrain proof")
	world.player.free()
	world.monsters_root.free()
	world.free()
	print("CURRENT523_AUTO_DISCONNECTED_RESULT ", JSON.stringify({"checks":checks,
		"failures":failures, "cold":cold, "warm":warm}))
	quit(0 if failures.is_empty() else 1)
