extends SceneTree
## Core fixtures use verified real catalog source IDs; these are not loot drops.
const Core = preload("res://scripts/collections/equipment_collection_service.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures.append(message);print("COLLECTION_BINDING_FAIL: "+message)
func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn")
	var world = scene.instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var rt = world.equipment_collections
	var successful: int = 0
	var blocked: int = 0
	var serial: int = 0
	for c: Dictionary in rt.definitions():
		var fresh: Dictionary = Core.fresh_state()
		if not bool(rt.availability(str(c.id)).get("ok",false)):
			blocked += 1
			check(not rt.core.complete(fresh,str(c.id)),"blocked collection cannot grant effect "+str(c.id))
			continue
		var eligible: bool = true
		for req: Dictionary in c.requirements:
			var record: Dictionary = rt.icon_record(str(req.name))
			check(not record.is_empty(),"actual source name binding "+str(req.name))
			if record.is_empty(): eligible=false;break
			var ids: Array = []
			for _quantity: int in range(int(req.quantity)):
				serial += 1
				var id: String = "binding-test-"+str(serial)
				ids.append(id)
				fresh.gear[id] = {"instance_id":id,"source_id":str(record.sourceId),"name":str(record.name),"enchant":req.enchant,"quantity":1,"equipped":false,"locked":false}
			var request: Dictionary = {"collection_id":str(c.id),"slot_id":str(req.slot_id),"instance_ids":ids,"expected_revision":fresh.revision,"request_id":"request-"+str(serial)}
			var result: Dictionary = rt.core.prepare_registration(fresh,request)
			check(bool(result.get("ok",false)),"actual catalog-backed fixture registration "+str(c.id))
			if not bool(result.get("ok",false)): eligible=false;break
			fresh = result.state
		if not eligible:continue
		check(rt.core.complete(fresh,str(c.id)),"all slots complete "+str(c.id))
		var expected: Dictionary = {}
		for effect: Dictionary in c.effects:
			var code: String = Core.effect_code(effect)
			expected[code] = float(expected.get(code,0.0))+float(effect.value)
		check(rt.core.bonuses(fresh)==expected,"exact combined reward, no duplicate bonus "+str(c.id))
		successful += 1
	check(successful==339,"339 verified data+capability collections; no unsupported substitutions")
	check(blocked==108,"108 unavailable definitions preserved rather than discarded")
	print("COLLECTION_BINDINGS_RESULT "+JSON.stringify({"scope":"actual_catalog_core_fixtures_not_loot","available":successful,"blocked":blocked,"checks":checks,"failures":failures}))
	world.queue_free();await process_frame
	if failures.is_empty():print("EQUIPMENT_COLLECTION_BINDINGS_OK")
	quit(0 if failures.is_empty() else 1)
