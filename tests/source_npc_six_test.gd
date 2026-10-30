extends SceneTree
const CATALOG = preload("res://scripts/npc/source_npc_catalog.gd")
const ACTOR = preload("res://scripts/npc/source_npc_actor.gd")
const DIALOGUE = preload("res://scripts/npc/dialogue_service.gd")
const COORD = preload("res://scripts/maps/source_coordinates.gd")
var errors: Array[String] = []
var checks: int = 0

class Field:
	extends RefCounted
	var data: Dictionary = {"map_id":"test_source_4","npc_spawn":[]}
	var definition: Dictionary = {"source_map_id":4,"source_sha256":"a".repeat(64)}
	var coordinates = COORD.new()
	var blocked: bool = false
	func walkable(_p: Vector2) -> bool: return not blocked

func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: errors.append(why); printerr("SOURCE_NPC_FAIL: ",why)

func run() -> void:
	check(CATALOG.records().size()==6,"six exact identities")
	var service = DIALOGUE.new()
	service.load_dialogues()
	check(service.registry.size()==6,"existing registry unchanged")
	check(service.source_registry.size()==3,"three text-only dialogues")
	var f = Field.new()
	f.coordinates.configure([32000,32000],[2000,2000])
	CATALOG.append_to_field(f)
	check(f.data.npc_spawn.is_empty(),"shipping bindings reject an unrelated fixture map")
	for id: String in CATALOG.records():
		var n: Dictionary = CATALOG.record(id)
		check(not n.shop_enabled and not n.quest_execution_enabled and not n.combat_enabled,"no invented services")
		var actor = ACTOR.new()
		root.add_child(actor)
		check(not actor.configure({"source_catalog_id":id}),"live actor rejects unknown foot")
		check(actor.configure({"source_catalog_id":id},true),"native pixels load in diagnostic preview")
		for slot: int in range(8):
			actor.set_heading(slot)
			check(actor.heading_slot==(slot if int(n.visual.heading_slots)==8 else 0),"literal heading or explicit horse reuse")
		actor._process(float(n.visual.seconds_per_frame)*2.1)
		check(actor.frame_index==2,"idle advances")
		actor._process(float(n.visual.seconds_per_frame)*int(n.visual.frames))
		check(actor.frame_index==2,"idle loops without invalid frame")
		actor.queue_free()
		if service.source_registry.has(id):
			check(not service.resolve(id,"",{}).ok,"remote dialogue rejected")
			var state: Dictionary = {"source_npc_nearby":{id:true}}
			var first: Dictionary = service.resolve(id,"",state)
			check(first.ok and first.choices.is_empty(),"text only")
			check(service.resolve(id,"",state)==first,"repeated dialogue stable")
			for action: String in ["shop","teleport","quest","reward","warehouse"]:
				check(not service.allowed_action(id,"welcome",action,state),"forged action rejected")
	var id: String = "l1j_tw380_npc_70649"
	var n: Dictionary = CATALOG.record(id)
	var binding: Dictionary = {"npc_id":id,"enabled":true,"game_map_id":"test_source_4","source_grid_sha256":"a".repeat(64),"actor_foot_reviewed":true,"foot_pixels":[]}
	binding["visual_sha256"] = n.visual.sha256
	for slot: int in range(8): binding.foot_pixels.append([1,2])
	CATALOG.append_to_field(f,[binding])
	check(f.data.npc_spawn.size()==1,"explicit fixture binding accepted")
	var p: Vector2 = f.coordinates.to_world(Vector2(33603,32503))
	check(Vector2(f.data.npc_spawn[0].position[0],f.data.npc_spawn[0].position[1])==p,"source coordinate transform used")
	CATALOG.append_to_field(f,[binding])
	check(f.data.npc_spawn.size()==1,"repeat load does not duplicate")
	f.data.npc_spawn.clear()
	f.blocked=true
	check(not CATALOG.append_to_field(f,[binding]).is_empty() and f.data.npc_spawn.is_empty(),"collision rejects placement")
	f.blocked=false
	f.data.map_id="albino_01"
	binding.game_map_id="albino_01"
	CATALOG.append_to_field(f,[binding])
	check(f.data.npc_spawn.is_empty(),"protected map rejects placement")
	f.data.map_id="test_source_4"
	binding.game_map_id="test_source_4"
	binding.npc_id="l1j_tw380_npc_71094"
	check(not CATALOG.append_to_field(f,[binding]).is_empty() and f.data.npc_spawn.is_empty(),"Endia random anchor cannot spawn as fixed")
	print("SOURCE_NPC_SIX checks=",checks," failures=",errors.size()," placement=checked_by_live_test")
	quit(0 if errors.is_empty() else 1)
