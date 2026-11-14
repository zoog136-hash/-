extends SceneTree
## Current523 field spawns: per-frame time budget, rest frames after a heavy
## (cold) setup, and every deferred slot still spawns later.
##   godot --headless --path <repo> --script res://tests/current523_spawn_frame_budget_test.gd
const POPULATION = preload("res://scripts/maps/current523_source_population.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CURRENT523_SPAWN_FRAME_BUDGET_FAIL: " + label)

## Replaces the real spawn pipeline with a fixed busy cost per call.
class FakePopulation extends POPULATION:
	var cost_usec: int = 0
	var spawned: Array[int] = []
	var ever: Dictionary = {}
	func _spawn_slot_measured(slot: Dictionary) -> void:
		var until: int = Time.get_ticks_usec() + cost_usec
		while Time.get_ticks_usec() < until: pass
		spawned.append(int(slot.slot_id))
		ever[int(slot.slot_id)] = true

class FakeWorld extends Node:
	var monsters_root: Node = Node.new()

func _slots(population: FakePopulation, count: int) -> Array[Dictionary]:
	var key: String = "lineagem_base508:npc:1:spawn:2:territory:3"
	population.records[key] = {"source_m_current523_final": true}
	var result: Array[Dictionary] = []
	for index: int in count:
		result.append({"region": {"monster_types": [key]}, "slot_id": index, "monster": null, "remaining": 0.0})
	return result

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var population := FakePopulation.new()
	var world := FakeWorld.new()
	population.world = world
	var slots: Array[Dictionary] = _slots(population, 6)
	await process_frame
	# Cheap spawns: the count cap (2) still applies.
	population.cost_usec = 500
	for slot: Dictionary in slots.slice(0, 3): population._spawn_slot(slot)
	check(population.spawned == [0, 1], "two cheap spawns per frame: %s" % [population.spawned])
	check(slots[2].has("budget_deferred") and float(slots[2].remaining) > 0.0, "the third waits for a later frame")
	check(is_equal_approx(population._spawn_retry_delay(slots[2]), 0.2) and not slots[2].has("budget_deferred"), "a budget deferral retries in 0.2 s without failure backoff")
	check(int(slots[2].get("spawn_failures", 0)) == 0, "a budget deferral is not a spawn failure")
	await process_frame
	# A spawn over the frame budget ends this frame's spawning.
	population.spawned.clear()
	population.cost_usec = POPULATION.FRAME_BUDGET_USEC + 2000
	population._spawn_slot(slots[2])
	population._spawn_slot(slots[3])
	check(population.spawned == [2], "no second spawn after the frame budget is spent: %s" % [population.spawned])
	await process_frame
	# A heavy spawn rests the next HEAVY_REST_FRAMES frames.
	population.spawned.clear()
	population.cost_usec = POPULATION.HEAVY_SPAWN_USEC + 5000
	population._spawn_slot(slots[3])
	check(population.spawned == [3], "the heavy spawn itself runs")
	population.cost_usec = 200
	for frame: int in POPULATION.HEAVY_REST_FRAMES:
		await process_frame
		population._spawn_slot(slots[4])
	check(population.spawned == [3], "no spawn in the rest frames after a heavy setup: %s" % [population.spawned])
	await process_frame
	population._spawn_slot(slots[4])
	population._spawn_slot(slots[5])
	check(population.spawned == [3, 4, 5], "spawning resumes after the rest frames: %s" % [population.spawned])
	# Every slot was eventually spawned: deferral delays, never drops.
	var ids: Array = population.ever.keys()
	ids.sort()
	check(ids == [0, 1, 2, 3, 4, 5], "all six slots spawned: %s" % [ids])
	population.free()
	world.monsters_root.free()
	world.free()
	print("CURRENT523_SPAWN_FRAME_BUDGET_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
