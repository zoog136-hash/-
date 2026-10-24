extends SceneTree
## Ordinary Main on the actual installed PNG maps. The small negative fixture
## below proves failure does not spend an item; it is not source-image evidence.
const REGISTRY = preload("res://scripts/maps/native_png_registry.gd")
const FIELD = preload("res://scripts/maps/native_png_field.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("NATIVE_TELEPORT_FAIL: " + label)

func valid_landing(field: NativePngField, point: Vector2, origin: Vector2, minimum: float = 160.0) -> bool:
	if not point.is_finite() or point.distance_to(origin) < minimum: return false
	if not field.walkable(point) or not field.point_clear(point): return false
	var cell: Vector2i = field.world_to_cell(point)
	if field.reachable[cell.y * field.width + cell.x] == 0: return false
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
		Vector2(-1,-1).normalized(), Vector2(-1,1).normalized(), Vector2(1,-1).normalized(), Vector2(1,1).normalized()]:
		if not field.walkable(point + offset * 4.0): return false
	for portal: Dictionary in field.data.get("portal", []):
		var center := Vector2(portal.position[0], portal.position[1])
		if point.distance_to(center) <= float(portal.get("radius", 18.0)) + 4.0: return false
	return true

func inspect(mid: String) -> void:
	world._set_map(mid, false)
	check(world.active_map_id == mid and world.field_map is NativePngField, mid + " actual native field")
	if not world.field_map is NativePngField: return
	var field: NativePngField = world.field_map
	var origin: Vector2 = world.player.global_position
	check(field.point_clear(origin), mid + " entry has landing clearance")
	# Multiple RNG states must find real floor on a sparse image canvas.
	for seed_value: int in [137, 20261020, 39007, 77331]:
		world.rng.seed = seed_value
		var point: Vector2 = world.consumable_service.call("_random_destination")
		check(valid_landing(field, point, origin), mid + " scroll destination seed " + str(seed_value))
		if point.is_finite():
			var max_distance: float = origin.distance_to(point) + 1.0
			var bounded: Vector2 = world._random_walkable_position(origin, 160.0, max_distance)
			check(valid_landing(field, bounded, origin) and bounded.distance_to(origin) <= max_distance,
				mid + " world sampler preserves range")
	check(world._random_walkable_position(origin, field.bounds.size.length() * 2.0, INF) == Vector2.INF,
		mid + " impossible range reports no landing")
	world.inventory["순간이동 주문서"] = 2
	world._on_inventory_item_activated("순간이동 주문서")
	check(int(world.inventory.get("순간이동 주문서", 0)) == 1, mid + " actual scroll consumes exactly one")
	check(world.active_map_id == mid and valid_landing(field, world.player.global_position, origin),
		mid + " actual scroll stays in map outside portals")
	var saved: Vector2 = world.player.global_position
	world.player.global_position = origin
	world._load_game(true)
	check(world.active_map_id == mid and world.field_map is NativePngField and world.player.global_position.distance_to(saved) < 0.01,
		mid + " consumed scroll save restores native landing")
	check(int(world.inventory.get("순간이동 주문서", 0)) == 1, mid + " saved inventory retains one remaining scroll")

func prepare_teleport_skill() -> Dictionary:
	var skill: Dictionary = world.original_skills.catalog.record_for("텔레포트")
	check(not skill.is_empty(), "registered teleport skill exists")
	if skill.is_empty(): return {}
	world.original_skills.catalog.learned[str(skill.id)] = 1
	world._clear_combat_actions()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0.0
	world.mp = 999
	world.hp = world._effective_max_hp()
	for item: String in skill.get("items", {}): world.inventory[item] = maxi(2, int(skill.items[item]))
	check(world.original_skills.ready(skill), "registered teleport skill is ready before terrain validation")
	return skill

func skill_teleport() -> void:
	world._set_map("faith_03", false)
	var skill: Dictionary = prepare_teleport_skill()
	if skill.is_empty(): return
	var origin: Vector2 = world.player.global_position
	var mp_before: int = world.mp
	var resolved: Dictionary = world.original_skills.catalog.resolve(skill)
	check(world.original_skills.cast(skill), "actual teleport skill casts on native floor")
	check(valid_landing(world.field_map, world.player.global_position, origin, 96.0)
		and world.player.global_position.distance_to(origin) <= 600.0, "teleport skill preserves native landing range")
	check(world.mp == mp_before - int(resolved.get("mp", 0)), "successful teleport skill spends MP once")

func impossible_destination() -> void:
	var previous_field: PlayableField = world.field_map
	var previous_position: Vector2 = world.player.global_position
	var small: NativePngField = FIELD.new()
	var spec: Dictionary = {"name":"negative teleport fixture", "spawn":[48,48],
		"walk_polygons":[[[16,16],[80,16],[80,80],[16,80]]], "collision":[],
		"portals":[], "route_checks":[], "collision_scope":"SYNTHETIC_NEGATIVE_TEST_ONLY"}
	small.configure_png("teleport_negative_fixture", {"revision":1,"maps":{"teleport_negative_fixture":spec}},
		{"bounds":[0,0,96,96]}, "")
	world.field_map = small
	world.player.global_position = Vector2(48,48)
	world.inventory["순간이동 주문서"] = 2
	world._on_inventory_item_activated("순간이동 주문서")
	check(int(world.inventory.get("순간이동 주문서", 0)) == 2, "no distant landing preserves scroll count")
	check(world.player.global_position == Vector2(48,48), "no distant landing preserves player position")
	var skill: Dictionary = prepare_teleport_skill()
	if not skill.is_empty():
		var mp_before: int = world.mp
		var hp_before: int = world.hp
		var inventory_before: Dictionary = world.inventory.duplicate(true)
		var cooldowns_before: Dictionary = world.skill_cooldowns.duplicate(true)
		check(not world.original_skills.cast(skill), "teleport skill rejects impossible native landing")
		check(world.player.global_position == Vector2(48,48), "failed teleport skill keeps finite player position")
		check(world.mp == mp_before and world.hp == hp_before and world.inventory == inventory_before,
			"failed teleport skill spends no MP HP or consumables")
		check(world.skill_cooldowns == cooldowns_before and world.skill_global_cooldown == 0.0,
			"failed teleport skill starts no cooldown")
	world.field_map = previous_field
	world.player.global_position = previous_position

func return_travel() -> void:
	world._set_map("faith_01", false)
	var before: Vector2 = world.player.global_position
	var installed: String = OS.get_environment("TWILIGHT_ADEN_FAITH_PNG_PACK")
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK", "user://missing-native-teleport-fixture")
	world.inventory["귀환 주문서"] = 2
	world._on_inventory_item_activated("귀환 주문서")
	check(world.active_map_id == "faith_01" and world.player.global_position == before,
		"unavailable Aden pack preserves dungeon and position")
	check(int(world.inventory.get("귀환 주문서", 0)) == 2, "unavailable Aden pack does not spend return scroll")
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK", installed)
	world._on_inventory_item_activated("귀환 주문서")
	check(world.active_map_id == "aden_world" and world.field_map is NativePngField,
		"restored pack returns to native Aden")
	check(int(world.inventory.get("귀환 주문서", 0)) == 1, "successful return consumes exactly one")
	check(world.field_map.walkable(world.player.global_position) and world.field_map.point_clear(world.player.global_position)
		and world.field_map.is_safe(world.player.global_position), "return lands on body-clear safe town floor")
	var shape: Shape2D = world.player.get_node("CollisionShape2D").shape
	check(shape is CircleShape2D and is_equal_approx((shape as CircleShape2D).radius, 4.0), "native travel keeps source foot collider")

func same_map_gates() -> void:
	world._set_map("aden_world", false)
	if not world.field_map is NativePngField:
		check(false, "native Aden available for reviewed gates")
		return
	var field: NativePngField = world.field_map
	var tested: int = 0
	for portal: Dictionary in field.data.get("portal", []):
		if str(portal.get("target_map", "")) != "aden_world" or not portal.has("target_position"): continue
		var target := Vector2(portal.target_position[0], portal.target_position[1])
		check(world.use_field_portal(str(portal.id)), "actual same-map gate " + str(portal.id))
		check(world.active_map_id == "aden_world" and world.player.global_position == target
			and field.walkable(target) and field.point_clear(target, 4.0), "gate lands on exact reviewed floor " + str(portal.id))
		if tested == 0:
			var previous: Vector2 = world.player.global_position
			var revision: int = int(portal.target_layout_revision)
			portal.target_layout_revision = revision - 1
			check(not world.use_field_portal(str(portal.id)) and world.player.global_position == previous,
				"stale same-map gate revision preserves player position")
			portal.target_layout_revision = revision
			var destination: Array = portal.target_position
			portal.target_position = [-100,-100]
			check(not world.use_field_portal(str(portal.id)) and world.player.global_position == previous,
				"invalid same-map gate cannot project to another floor")
			portal.target_position = destination
		tested += 1
	check(tested > 0, "reviewed Aden hunting gates actually exercised")

func run() -> void:
	if not REGISTRY.extra_installed():
		print("NATIVE_TELEPORT_SKIP: actual tracked Aden/Faith PNG pack unavailable")
		quit(); return
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "actual Main class entry")
	# These are travel/inventory tests. Combat remains in its dedicated active
	# population suite instead of racing a character during landing assertions.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.save_timer = -100000
	for mid: String in ["aden_world", "faith_01", "faith_02", "faith_03", "faith_04"]:
		inspect(mid)
	skill_teleport()
	impossible_destination()
	return_travel()
	same_map_gates()
	world.queue_free()
	await process_frame
	await process_frame
	print("NATIVE_TELEPORT_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
