extends SceneTree
const Boundary = preload("res://scripts/honing/consumption_boundary.gd")
var checks: int = 0
var failures: int = 0

class Host extends Node:
	var inventory: Dictionary = {"fixture gear":2,"fixture material":5}
	var item_instances: Dictionary = {
		"a":{"name":"fixture gear","level":7,"record":{"source_item_class_id":9001,"sourceId":"m523:item:9001"},"unknown_option":{"x":3}},
		"b":{"name":"fixture gear","level":9,"record":{"source_item_class_id":9001,"sourceId":"m523:item:9001"}},
		"m":{"name":"fixture material","source_reward_quantity":5,"quest_reward_receipt":{"quantity":10}}}
	var quest_state: Dictionary = {"used":5}
	var locked: bool = false
	func _item_locked(_name: String,_id: String) -> bool: return locked

# Explicit ABI spy. Tests wrapper behavior, not PR262 source ownership validation.
class AbiSpy extends RefCounted:
	var calls: int = 0
	var supported: bool = true
	func available(_world: Node) -> bool: return supported
	func stamp(world: Node) -> int: return hash([world.inventory,world.item_instances,world.quest_state,world.locked])
	func stage(world: Node,requests: Array,digest: String) -> Dictionary:
		calls += 1
		var request: Dictionary = requests[0]
		if request.physical_id != "m" or request.expected_quantity != world.item_instances.m.source_reward_quantity: return {"ok":false,"use_authorized":false}
		if not Boundary.same(request.quest_reward_receipt,world.item_instances.m.quest_reward_receipt): return {"ok":false,"use_authorized":false}
		var instances: Dictionary = world.item_instances.duplicate(true)
		var inventory: Dictionary = world.inventory.duplicate(true)
		inventory["fixture material"] -= request.quantity
		instances.m.source_reward_quantity -= request.quantity
		if instances.m.source_reward_quantity == 0: instances.erase("m")
		return {"ok":true,"use_authorized":false,"stamp":stamp(world),"consumer_data_sha256":digest,
			"overrides":{"inventory":inventory,"item_instances":instances,"quest_state":{"used":world.quest_state.used+request.quantity}}}
	func current(world: Node,candidate: Dictionary) -> bool: return candidate.get("stamp") == stamp(world)
	func matches_payload(world: Node,candidate: Dictionary,payload: Dictionary) -> bool:
		return current(world,candidate) and Boundary.same(candidate.overrides,payload)

func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var host := Host.new()
	var abi := AbiSpy.new()
	var request: Dictionary = {"physical_id":"m","quantity":2,"expected_quantity":5,"expected_remaining":3,"quest_reward_receipt":{"quantity":10}}
	var before: PackedByteArray = var_to_bytes([host.inventory,host.item_instances,host.quest_state])
	check(Boundary.review(host,"a",[request],"/not-present/honing.zip").code == "verified_local_source_missing","production missing source stays locked")
	check(Boundary._abi() == null,"old-main lacks public ABI; no engine copied")
	check(not Boundary.source_matches("res://project.godot"),"wrong-sized file is not source")
	check(abi.calls == 0,"production refusal cannot call staging")
	var result: Dictionary = Boundary._review_with(host,"a",[request],Boundary.SOURCE_SHA,abi)
	check(result.get("ok",false) and not result.use_authorized,"staging never authorizes use")
	check(result.payload.inventory["fixture material"] == 3,"candidate debit only")
	check(result.payload.quest_state.used == 7,"ledger accompanies candidate")
	check(result.payload.item_instances.m.quest_reward_receipt.quantity == 10,"grant quantity remains immutable")
	check(result.target_id == "a" and result.source_item_class_id == 9001,"exact selected identity")
	check(result.payload.item_instances.b.level == 9,"same-name other gear intact")
	check(Boundary._matches_with(host,result,result.payload,abi),"unchanged ownership payload matches")
	check(var_to_bytes([host.inventory,host.item_instances,host.quest_state]) == before,"stage leaves live state unchanged")
	var altered: Dictionary = result.payload.duplicate(true)
	altered.quest_state = host.quest_state.duplicate(true)
	check(not Boundary._matches_with(host,result,altered,abi),"old ledger overwrite rejected")
	altered = result.payload.duplicate(true)
	altered.inventory = host.inventory.duplicate(true)
	check(not Boundary._matches_with(host,result,altered,abi),"old inventory overwrite rejected")
	altered = result.payload.duplicate(true)
	altered.item_instances.a.level = 8
	check(not Boundary._matches_with(host,result,altered,abi),"unverified target effect rejected")
	host.item_instances.a.level = 8
	check(not Boundary._matches_with(host,result,result.payload,abi),"stale target rejected")
	host.item_instances.a.level = 7
	host.locked = true
	check(not Boundary._review_with(host,"a",[request],Boundary.SOURCE_SHA,abi).ok,"target lock enforced")
	check(not Boundary._matches_with(host,result,result.payload,abi),"stale lock state rejected")
	host.locked = false
	check(not Boundary._review_with(host,"a",[request,request],Boundary.SOURCE_SHA,abi).ok,"duplicate materials rejected")
	var bad: Dictionary = request.duplicate(true)
	bad.physical_id = "a"
	check(not Boundary._review_with(host,"a",[bad],Boundary.SOURCE_SHA,abi).ok,"target cannot be material")
	bad = request.duplicate(true)
	bad.expected_remaining = 4
	check(not Boundary._review_with(host,"a",[bad],Boundary.SOURCE_SHA,abi).ok,"wrong expected remainder rejected")
	bad = request.duplicate(true)
	bad.expected_quantity = 10
	bad.expected_remaining = 8
	check(not Boundary._review_with(host,"a",[bad],Boundary.SOURCE_SHA,abi).ok,"original grant cannot stand in for current quantity")
	check(not Boundary._review_with(host,"a",[request],"0".repeat(64),abi).ok,"wrong source digest rejected")
	host.item_instances.a.record.sourceId = "name-alias:9001"
	check(not Boundary._review_with(host,"a",[request],Boundary.SOURCE_SHA,abi).ok,"no name or namespace alias")
	host.item_instances.a.record.sourceId = "m523:item:9001"
	abi.supported = false
	check(not Boundary._review_with(host,"a",[request],Boundary.SOURCE_SHA,abi).ok,"missing quest contract refused")
	abi.supported = true
	for index: int in range(5):
		var repeated: Dictionary = Boundary._review_with(host,"a",[request],Boundary.SOURCE_SHA,abi)
		check(not repeated.use_authorized and Boundary.same(repeated.payload,result.payload),"repeat is only same candidate")
	check(var_to_bytes([host.inventory,host.item_instances,host.quest_state]) == before,"failed and repeated reviews preserve all live fields")
	# In-memory JSON boundary only: not Main/process restart or durable save proof.
	var restored: Dictionary = JSON.parse_string(JSON.stringify(result.payload))
	check(Boundary._matches_with(host,result,restored,abi),"JSON numeric representation matches")
	check(restored.item_instances.m.source_reward_quantity == 3 and restored.item_instances.m.quest_reward_receipt.quantity == 10,"roundtrip preserves remaining vs original")
	request.quantity = 5
	request.expected_remaining = 0
	var exhausted: Dictionary = Boundary._review_with(host,"a",[request],Boundary.SOURCE_SHA,abi)
	check(not exhausted.payload.item_instances.has("m"),"zero candidate removes selected ID")
	altered = exhausted.payload.duplicate(true)
	altered.item_instances.m = host.item_instances.m.duplicate(true)
	check(not Boundary._matches_with(host,exhausted,altered,abi),"resurrected consumed ID rejected")
	host.free()
	print("HONING_CONSUMPTION_BOUNDARY checks=%d failures=%d (synthetic ABI spy, no save/effect execution)" % [checks,failures])
	quit(1 if failures else 0)
