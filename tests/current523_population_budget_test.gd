extends SceneTree
## Admission and deferral checks use a full source pool, so no invented art or
## source encounter enters the game. Existing world/save checks cover spawning.
const POPULATION = preload("res://scripts/maps/current523_source_population.gd")
class Host extends Node:
	var monsters_root := Node2D.new()
var checks: int = 0
var failures: Array = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func slot() -> Dictionary:
	return {"monster":null,"region":{"monster_types":["source:test"]},"remaining":0.0}
func _initialize() -> void:
	var host := Host.new()
	host.add_child(host.monsters_root)
	for index: int in POPULATION.MAX_ACTIVE: host.monsters_root.add_child(Node2D.new())
	var population = POPULATION.new()
	population.world = host
	population.records["source:test"] = {"source_m_current523_final":true}
	var first := slot()
	population._spawn_slot(first)
	check(population._budget_used == 1 and not first.has("budget_deferred"), "first current actor attempt retains admission")
	population._budget_elapsed_usec = population.SPAWN_BUDGET_USEC - 1
	var second := slot()
	population._spawn_slot(second)
	check(population._budget_used == 2 and not second.has("budget_deferred"), "below time boundary second attempt remains available")
	var third := slot()
	population._spawn_slot(third)
	check(third.get("budget_deferred") == true and third.remaining == 0.05, "original count cap still defers a third actor")
	population._budget_used = 1
	population._budget_elapsed_usec = population.SPAWN_BUDGET_USEC
	var expensive := slot()
	population._spawn_slot(expensive)
	check(expensive.get("budget_deferred") == true and population._budget_used == 1, "one expensive setup defers the second at exact time boundary")
	check(population._spawn_retry_delay(expensive) == 0.2 and not expensive.has("budget_deferred"), "budget deferral keeps short retry without floor failure backoff")
	check(not expensive.has("spawn_failures") and not expensive.has("patch523_spawn_hold"), "time deferral invents no failure or source hold")
	population._budget_frame = -1
	var fresh := slot()
	population._spawn_slot(fresh)
	check(population._budget_used == 1 and not fresh.has("budget_deferred"), "new frame resets both budgets and retries")
	population.records["source:test"]["source_m_asset_manifest_path"] = "old-pack"
	var refused := slot()
	population._spawn_slot(refused)
	check(refused.get("patch523_spawn_hold") == "old_pack_record_refused" and is_inf(refused.remaining), "old source pack remains refused before budget admission")
	population.free()
	host.free()
	print("CURRENT523_POPULATION_BUDGET_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
