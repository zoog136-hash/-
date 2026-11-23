extends SceneTree
## Checks the exact native-ledger input gate on the dungeon timer save.
## The synthetic non-receipted rows model validation/scanning, not phone I/O.
const NATIVE = preload("res://scripts/loot/current523_native_stack.gd")

class Consumables extends RefCounted:
	var state: Dictionary = {}
	func export_state() -> Dictionary: return state.duplicate(true)

class Warehouse extends RefCounted:
	var instances: Dictionary = {}
	var stacks: Dictionary = {}
	func snapshot() -> Dictionary: return {"instances":instances.duplicate(true),"stacks":stacks.duplicate(true)}

class Floor extends RefCounted:
	var records: Dictionary = {}

class Host extends Node:
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var warehouse := Warehouse.new()
	var consumable_service := Consumables.new()
	var ground_loot := Floor.new()
	var dormant: Dictionary = {}
	func _ground_drops_snapshot() -> Array: return ground_loot.records.values().duplicate(true)
	func dormant_character_items() -> Dictionary: return dormant

var failures: Array[String] = []
var checks: int = 0

func expect(ok: bool, name: String) -> void:
	checks += 1
	if not ok:
		failures.append(name)
		printerr("DUNGEON_TICK_SAVE_SCOPE_FAIL ", name)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world := Host.new()
	root.add_child(world)
	var ledger: Dictionary = {"source_dungeon_play":{"revision":1}}
	for i: int in 8000:
		world.item_instances[str(i)]={"name":"synthetic fixture","extra":{"notes":[1,2,3]}}
	world.inventory["synthetic fixture"]=8000
	expect(NATIVE.override_error(world,{}).is_empty(),"ordinary proof succeeds")
	expect(NATIVE.override_error(world,ledger).is_empty(),"ledger-only candidate succeeds on the same ownership")
	expect(NATIVE.override_error(world,{"source_dungeon_play":ledger.source_dungeon_play,"item_instances":{}}).is_empty(),"transaction still evaluated as its own valid candidate")
	# Every input must still fail closed after a previous proof of unchanged state.
	expect(NATIVE.override_error(world,ledger).is_empty(),"warm ledger before floor mutation")
	world.ground_loot.records["bad"]="not a record"
	expect(not NATIVE.override_error(world,ledger).is_empty(),"changed floor can't reuse the proof")
	world.ground_loot.records.clear()
	expect(NATIVE.override_error(world,ledger).is_empty(),"valid floor succeeds again")
	world.dormant["0"]={}
	expect(not NATIVE.override_error(world,ledger).is_empty(),"dormant item conflict can't reuse the proof")
	world.dormant.clear()
	expect(NATIVE.override_error(world,ledger).is_empty(),"valid dormant state succeeds again")
	world.consumable_service.state[NATIVE.USES]=[]
	expect(not NATIVE.override_error(world,ledger).is_empty(),"changed use journal can't reuse the proof")
	world.consumable_service.state.clear()
	expect(NATIVE.override_error(world,ledger).is_empty(),"valid use journal succeeds again")
	expect(not NATIVE.override_error(world,{"source_dungeon_play":ledger.source_dungeon_play,"consumable_state":{NATIVE.USES:[]}}).is_empty(),"economic override remains checked")
	expect(NATIVE.override_error(world,ledger).is_empty(),"warm after rejection")
	var elapsed: Array[int] = []
	for i: int in 31:
		var start: int = Time.get_ticks_usec()
		var ok: bool = NATIVE.override_error(world,ledger).is_empty()
		elapsed.append(Time.get_ticks_usec()-start)
		if not ok:
			expect(false,"all repeated proofs remained valid")
			break
	elapsed.sort()
	print("DUNGEON_TICK_SAVE_SCOPE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"loop_samples":elapsed.size(),"native_proof_median_usec":elapsed[int(elapsed.size()/2)]}))
	world.free()
	quit(0 if failures.is_empty() else 1)
