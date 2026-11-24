extends SceneTree
## Original 523 town NPC bodies: only town npc_spawn records get a body, a
## missing sprite or bank leaves the NPC without one (recorded, nothing drawn),
## bodies stream by distance, never join monsters_root, and the controller
## creates/clears the layer with the source field.
const BODIES = preload("res://scripts/npc/source523_town_npc_bodies.gd")
const TOWN = preload("res://scripts/npc/source523_town_npcs.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

class FakeField extends RefCounted:
	var data: Dictionary = {"npc_spawn": []}

class FakeWorld extends Node2D:
	var player: Node2D = Node2D.new()
	var monsters_root: Node2D = Node2D.new()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 20: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := FakeWorld.new()
	root.add_child(world)
	world.add_child(world.player)
	world.add_child(world.monsters_root)
	var field := FakeField.new()
	field.data.npc_spawn = [
		{"id": "m523npc:1", "name": "[잡화상인] 세린", "position": [100.0, 100.0], "source523_sprite_id": 0, "source523_direction_id": 5},
		{"id": "m523npc:2", "name": "[창고지기] 원", "position": [160.0, 100.0], "source523_sprite_id": 13374, "source523_direction_id": 4},
		{"id": "m523npc:3", "name": "far", "position": [90000.0, 100.0], "source523_sprite_id": 13374},
		{"id": "old_npc", "name": "TWILIGHT", "position": [120.0, 100.0], "role": "shop"}]
	var bodies: Node2D = BODIES.new()
	world.add_child(bodies)
	bodies.configure(world, field)
	check(bodies.records.size() == 3, "only original town npc_spawn records")
	check(bodies.y_sort_enabled and bodies.name == "Current523TownNpcs", "Y-sorted body layer")
	world.player.global_position = Vector2(110, 100)
	for frame: int in 6: await process_frame
	var metrics: Dictionary = bodies.metrics()
	check(bodies.missing.get("m523npc:1") == "earth_object_sprite_missing", "sprite 0 -> no body, recorded")
	# The test profile has no installed current523 source bank: nothing is drawn.
	check(bodies.bodies.is_empty() and bodies.missing.has("m523npc:2"), "no bank -> no body, recorded")
	check(not bodies.missing.has("m523npc:3") and not bodies.bodies.has("m523npc:3"), "far NPC is not loaded")
	check(world.monsters_root.get_child_count() == 0, "bodies never join monsters_root")
	check(int(metrics.records) == 3 and int(metrics.bodies) == 0, "metrics report records/bodies")
	var images: int = 0
	for node: Node in bodies.find_children("*", "Sprite2D", true, false): images += 1
	check(images == 0, "no substitute image is created")
	# A created body releases when the player walks away (holder bookkeeping).
	var holder := Node2D.new()
	bodies.add_child(holder)
	bodies._register_body("m523npc:2",holder)
	bodies.missing.erase("m523npc:2")
	world.player.global_position = Vector2(100000, 5000)
	bodies._scan()
	check(not bodies.bodies.has("m523npc:2") and bodies.released == 1, "far body is released")
	bodies.configure(world, null)
	check(bodies.records.is_empty() and bodies.bodies.is_empty(), "clear on field change")
	# Placement rows keep the original facing for the body.
	var source: String = FileAccess.get_file_as_string("res://scripts/npc/source523_town_npcs.gd")
	check(source.contains("\"source523_direction_id\": int(spawn.get(\"DirectionID\""), "original DirectionID kept on placement")
	var controller: String = FileAccess.get_file_as_string("res://scripts/maps/current523_aden_play_controller.gd")
	check(controller.contains("TOWN_NPC_BODIES.new()") and controller.contains("_town_npc_bodies.configure(world,field)") and controller.contains("_town_npc_bodies.queue_free()"), "controller owns the body layer")
	check(TOWN.is_town_npc_id("m523npc:7") and not TOWN.is_town_npc_id("old_npc"), "town id prefix")
	# TWILIGHT approximations (user 2026-11-16): event/clan/hideout/fishing NPCs
	# and KR world 1 server-set NPCs are placed and marked; test rows stay out.
	check(TOWN.APPROX_NAME_TAGS.has("[이벤트]") and TOWN.APPROX_CATEGORIES.has("AgitMerchant") and not TOWN.EXCLUDED_NAME_TAGS.has("[이벤트]") and TOWN.EXCLUDED_NAME_TAGS.has("[테스트]"), "approximation tag split")
	check(source.contains("\"twilight_approximation\": approximations") and BODIES.IDLE_ACTIONS[0] == 3 and BODIES.IDLE_ACTIONS.size() > 2, "approximations are recorded; idle falls back to other original actions")
	if DEF.row_count("ServerLimit") > 0:
		check(TOWN.local_server_set(762) and not TOWN.local_server_set(782) and not TOWN.local_server_set(274), "KR world 1 server sets only")
	world.queue_free()
	var result: Dictionary = {"checks": checks, "failures": failures}
	print("SOURCE523_TOWN_NPC_BODIES_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
