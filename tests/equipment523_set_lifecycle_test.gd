extends SceneTree
## Synthetic service-boundary regression. The store double models a successful
## verified install; this does not assert private-pack installation or delivery.
const Service = preload("res://scripts/equipment523/service.gd")
const Store = preload("res://scripts/equipment523/pack_store.gd")
const C = preload("res://scripts/equipment523/common.gd")
var checks: int = 0
var failures: Array[String] = []

class World extends Node:
	var hp: int = 20
	var inventory: Dictionary = {"Synthetic guard":1}
	var item_instances: Dictionary = {}
	var equipped_items: Dictionary = {}
	var invalidations: int = 0
	func _effective_max_hp() -> int: return 100
	func _invalidate_equipment_static() -> void: invalidations += 1

class InstalledStore extends Store:
	var reject_install: bool = false
	var replacement: Dictionary = {}
	var replacement_effects_sha: String = ""
	func install(_path: String, _digest: String) -> Dictionary:
		if reject_install: return {"ok":false,"error":"synthetic failed verified install"}
		pack = (replacement if not replacement.is_empty() else pack).duplicate(true)
		if not replacement_effects_sha.is_empty(): effects_sha256 = replacement_effects_sha
		return {"ok":true,"sha256":sha256,"effects_sha256":effects_sha256}

func _initialize() -> void:
	var world := World.new()
	var record: Dictionary = {"name":"Synthetic guard","sourceId":"m523:item:1","source_item_class_id":1,"slot":"body"}
	world.item_instances = {"physical-1":{"name":"Synthetic guard","record":record.duplicate(true)}}
	world.equipped_items = {"body":dict(record,{"instance_id":"physical-1"})}
	_test_restore(world)
	_test_install(world)
	_test_missing_definitions(world)
	_test_rejection_and_authority(world)
	_test_incoming_event(world)
	_test_restored_visuals(world)
	world.free()
	print("EQUIPMENT523_SET_LIFECYCLE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"SYNTHETIC_SERVICE_PENDING_HYDRATION_AND_VERIFIED_INSTALL_BOUNDARY"}))
	quit(0 if failures.is_empty() else 1)

func dict(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	result.merge(extra,true)
	return result

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _service() -> RefCounted:
	var service = Service.new()
	service.store = InstalledStore.new()
	service.store.pack = _fixture()
	service.store.sha256 = "a".repeat(64)
	service.store.effects_sha256 = "b".repeat(64)
	return service

func _saved() -> Dictionary:
	return {"schema":"equipment523-set-effects-v1","source_sha256":C.SOURCE_SHA,
		"guard":{"bonus_id":101,"set_id":1,"buff_id":801,"hits":59,"remaining":6.0},"cooldowns":{"group:901":59.0}}

func _hits(service, world: Node) -> int:
	return int(service.export_state(world).get("guard",{}).get("hits",0))

func _test_restore(world: Node) -> void:
	var service = _service()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_saved()))
	service.after_load(world,saved)
	_check(service._saved_set_state.is_empty(),"ready definitions transfer pending ownership exactly once during load")
	_check(service.incoming(world,"melee",false,true),"the first PC hit after load consumes the restored guard")
	_check(_hits(service,world) == 58,"export observes 59 to 58 before the first tick")
	service.tick(world,0.0)
	_check(_hits(service,world) == 58,"the first tick cannot replay the saved 59-hit snapshot")
	service.tick(world,0.5)
	_check(_hits(service,world) == 58 and is_equal_approx(float(service.export_state(world).cooldowns["group:901"]),58.5),"subsequent ticks advance the live clock without rehydrating")
	_check(int(saved.guard.hits) == 59,"runtime consumption never mutates the caller's saved dictionary")

func _test_install(world: Node) -> void:
	var service = _service()
	service.after_load(world,_saved())
	_check(service.incoming(world,"melee",false,true),"install fixture starts with a spent live guard")
	var clock: Dictionary = service.export_state(world).cooldowns.duplicate(true)
	service.pending = {"quote":"stale"}
	_check(bool(service.install(world,"synthetic-identical-pack","ignored").get("ok",false)),"service accepts the store's successful identical verified reinstall")
	_check(_hits(service,world) == 58 and service.pending.is_empty(),"identical reinstall preserves the live guard and invalidates quotes")
	_check(service.incoming(world,"ranged",false,true),"identical reinstall has no unguarded incoming gap")
	service.tick(world,0.0)
	_check(_hits(service,world) == 57 and service.export_state(world).cooldowns == clock,"post-reinstall consumption survives the next tick without cooldown reset")
	service.store.replacement_effects_sha = "c".repeat(64)
	_check(bool(service.install(world,"synthetic-changed-addon","ignored").get("ok",false)),"changed verified definitions take the staged restoration path")
	_check(service.incoming(world,"melee",true,true),"changed definitions restore and reauthorize before the next incoming hit")
	service.tick(world,0.0)
	_check(_hits(service,world) == 56 and service.export_state(world).cooldowns == clock,"changed-install hydration also occurs only once")
	service.store.reject_install = true
	var before: Dictionary = service.export_state(world)
	_check(not bool(service.install(world,"synthetic-rejected-pack","ignored").get("ok",false)) and service.export_state(world) == before,"failed installation preserves the live state")

func _test_missing_definitions(world: Node) -> void:
	var service = _service()
	var ready: Dictionary = service.store.pack
	service.store.pack = {}
	var saved: Dictionary = _saved()
	service.after_load(world,saved)
	service.tick(world,10.0)
	_check(not service.incoming(world,"melee",false,true) and service.export_state(world) == saved,"missing base pack preserves opaque pending clocks and blocks consumption")
	service.store.pack = ready.duplicate(true)
	service.store.pack.erase("equipment523_effect_audit")
	service.tick(world,10.0)
	_check(not service.incoming(world,"melee",false,true) and service.export_state(world) == saved,"missing addon cannot consume or erase a pending source guard")
	service.store.pack = ready
	_check(service.incoming(world,"melee",false,true) and _hits(service,world) == 58,"definitions becoming available hydrate before the first incoming hit")
	service.tick(world,0.0)
	_check(_hits(service,world) == 58 and service._saved_set_state.is_empty(),"late hydration cannot be replayed by tick")
	service.store.replacement = ready.duplicate(true)
	service.store.replacement.erase("equipment523_effect_audit")
	service.store.replacement_effects_sha = "d".repeat(64)
	var before: Dictionary = service.export_state(world)
	_check(bool(service.install(world,"synthetic-base-without-addon","ignored").get("ok",false)),"successful base install may temporarily lack its addon")
	service.tick(world,10.0)
	_check(service.export_state(world) == before and not service.incoming(world,"melee",false,true),"addon removal parks the current spent state without resetting its clocks")
	service.store.replacement = ready
	service.store.replacement_effects_sha = "e".repeat(64)
	service.install(world,"synthetic-restored-addon","ignored")
	_check(service.incoming(world,"melee",false,true) and _hits(service,world) == 57,"addon reinstallation restores the parked spent counter immediately")

func _test_rejection_and_authority(world: Node) -> void:
	var service = _service()
	var invalid: Dictionary = _saved()
	invalid.source_sha256 = "f".repeat(64)
	service.after_load(world,invalid)
	service.tick(world,1.0)
	_check(service.save_blocked and service.export_state(world) == invalid and not service.incoming(world,"melee",false,true),"unknown saved source remains rejected and preserved")
	_check(not bool(service.install(world,"synthetic-pack","ignored").get("ok",false)),"a rejected save still blocks installation")
	service.after_load(world,_saved())
	var worn: Dictionary = world.equipped_items.duplicate(true)
	world.equipped_items.clear()
	_check(not service.incoming(world,"melee",false,true) and _hits(service,world) == 0,"hydrated guard must pass current physical equipment authority")
	_check(service.export_state(world).cooldowns == _saved().cooldowns,"lost equipment removes the guard without resetting reuse")
	world.equipped_items = worn
	service.after_load(world,_saved())
	_check(service.cancel(world,[]) == 1,"source cancellation sees a hydrated guard before tick")
	service.tick(world,0.0)
	_check(_hits(service,world) == 0 and service.export_state(world).cooldowns == _saved().cooldowns,"tick cannot resurrect a source-cancelled restored guard")
	service.after_load(world,_saved())
	service.on_death(world)
	service.tick(world,0.0)
	_check(_hits(service,world) == 0 and service.export_state(world).cooldowns == _saved().cooldowns,"tick cannot resurrect a death-cleared restored guard")

func _test_incoming_event(world: Node) -> void:
	var service = _service()
	service.after_load(world,{})
	service.tick(world,0.0)
	_check(_hits(service,world) == 0,"low HP alone cannot fabricate a defensive invoke outside an incoming event")
	_check(not service.incoming(world,"melee",false,false) and _hits(service,world) == 0,"an NPC incoming event preserves the source PC-only activation gate")
	_check(not service.incoming(world,"melee",false,true,false) and _hits(service,world) == 60,"the source failed-attack event can activate the guard without consuming a landed hit")
	_check(service.incoming(world,"melee",false,true,true) and _hits(service,world) == 59,"the next landed PC attack consumes exactly one active guard count")

func _bonus(pack: Dictionary, id: int, name: String, unit: int, value: int, application: int = 0, target: int = 0) -> void:
	pack.bonuses[str(id)] = {"raw":{"ID":id,"BonusTypeID":id,"Value":value,"BonusApplicationTypeID":application,"BonusApplicationTargetID":target},"type":{"ID":id,"Name":name,"UnitID":unit}}

func _test_restored_visuals(world: Node) -> void:
	var service = _service()
	var expiring: Dictionary = _saved()
	expiring.guard.remaining = 0.01
	service.after_load(world,expiring)
	service.tick(world,0.02)
	_check(service.set_effects.guard.is_empty() and service.set_visual_results.size() == 1 and int(service.set_visual_results[0].sprite_id) == 1201,"first-tick expiry restores the exact removal SpriteID before advancing")
	service.tick(world,0.02)
	_check(service.set_visual_results.size() == 1,"restored expiry removal is emitted exactly once")
	service.after_load(world,_saved())
	service.on_death(world)
	_check(service.set_visual_results.size() == 2 and int(service.set_visual_results[1].sprite_id) == 1201,"death before first tick retains a source-derived removal event")
	service.after_load(world,_saved())
	var count: int = service.set_visual_results.size()
	service.shutdown(world)
	_check(service.set_visual_results.size() == count and service.set_effects.drain_visual_events().is_empty(),"shutdown drains teardown events without spawning a renderer effect")

func _fixture() -> Dictionary:
	var pack: Dictionary = {"schema":C.SCHEMA,"source_sha256":C.SOURCE_SHA,"equipment523_effect_audit":{"synthetic":true},"bonuses":{},
		"items":{"1":{"raw":{"ID":1,"TestItem":false},"names":["Synthetic guard"]}},"tables":{}}
	pack.tables = {"ItemSet":[{"ID":1,"Name":"Synthetic guard set"}],"ItemForItemSet":[{"ItemSetID":1,"ItemClassID":1}],
		"ItemSetBonus":[{"ID":1,"ItemSetID":1,"CompletionDegree":1,"BonusID":101}],"IntervalBonusCategory":[{"ID":201}],
		"IntervalBonus":[{"ID":301,"IntervalBonusCategory":201,"Low":0,"High":20,"BonusID":401}],
		"InvokeOption":[{"ID":501,"InvokeOptionTypeID":2,"Param1":601,"Param3":1,"Param4":true}],
		"SpellClass":[{"ID":601,"TargettingTypeID":1,"CastDelay":60000}],
		"SpellBonus":[{"ID":1,"SpellClassID":601,"BonusID":701,"MinSpellLevel":0},{"ID":2,"SpellClassID":601,"BonusID":702,"MinSpellLevel":0}],
		"BuffClass":[{"ID":801,"IsGood":true,"BuffGroupID":901,"IsImmuneToCancellation":false,"IsImmuneToDead":false}],
		"BuffBonus":[{"ID":1,"BuffClassID":801,"BonusID":703},{"ID":2,"BuffClassID":801,"BonusID":704},{"ID":3,"BuffClassID":801,"BonusID":705}],
		"UniversalGroupSet":[]}
	_bonus(pack,101,"HPIntervalBonus",10674,201)
	_bonus(pack,401,"InvokeOption",3,1000000,10,501)
	_bonus(pack,701,"SpellBuffDuration",17,6)
	_bonus(pack,702,"BuffClassID",16,801)
	_bonus(pack,703,"CounterAssult",1,60,381,1001)
	_bonus(pack,704,"StatusEffectID",121,1101)
	_bonus(pack,705,"OnBuffRemovedEffectSpriteID",21,1201)
	for attack: int in [1,2,52,62]: pack.tables.UniversalGroupSet.append({"ID":attack,"GroupID":1001,"UnitID":10431,"Value":attack})
	return pack
