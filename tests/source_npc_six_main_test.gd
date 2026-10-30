extends SceneTree
## Main/HUD/save contract with transient test-only NPC records. No source placement approval.
const CATALOG = preload("res://scripts/npc/source_npc_catalog.gd")
const ACTOR = preload("res://scripts/npc/source_npc_actor.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var errors: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: errors.append(why); printerr("SOURCE_NPC_MAIN_FAIL: ",why)

func same_counts(a: Dictionary, b: Dictionary) -> bool:
	# JSON reload represents numbers as floats; compare exact integral quantities.
	if a.size() != b.size(): return false
	for key: Variant in a:
		if not b.has(key) or float(a[key]) != float(b[key]): return false
	return true

func boot() -> Node:
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	CLASS_QA.enter_game(world)
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer = -10000
	return world

func run() -> void:
	var world: Node = await boot()
	var existing: Array = world.field_map.data.get("npc_spawn",[]).duplicate(true)
	var initial_gold: int = world.gold
	var initial_inventory: Dictionary = world.inventory.duplicate(true)
	for id: String in CATALOG.records():
		check(not CATALOG.nearby(world,id),"no automatic main spawn")
		var npc: Dictionary = CATALOG.record(id)
		var position: Vector2 = world.player.global_position+Vector2(40,0)
		var diagnostic: Dictionary = {"id":id,"source_catalog_id":id,"name":npc.name,"role":npc.role,"position":[position.x,position.y]}
		world.field_map.data.npc_spawn.append(diagnostic)
		var preview = ACTOR.new()
		world.add_child(preview)
		preview.position = position
		check(preview.configure(diagnostic,true),"native NPC actor renders inside Main diagnostic")
		check(CATALOG.nearby(world,id),"190px gate accepts nearby test NPC")
		for repeat: int in range(2):
			world._set_click_destination(position)
			await process_frame
			if npc.has_verified_normal_dialogue:
				check(world.hud.active_section=="dialogue","click opens text HUD")
				var text: Dictionary = world.dialogue_service.resolve(id,"",world._npc_dialogue_state())
				check(text.ok and text.choices.is_empty(),"text has no executable actions")
				var captures: String = OS.get_environment("TWILIGHT_NPC_MAIN_CAPTURE_DIR")
				if not captures.is_empty() and repeat == 0:
					DirAccess.make_dir_recursive_absolute(captures)
					await process_frame
					await RenderingServer.frame_post_draw
					check(root.get_texture().get_image().save_png(captures+"/"+id+".png")==OK,"Main viewport readback")
				world.hud._close_workspace()
				check(not world.hud.workspace.visible,"dialogue closes")
			else: check(world.hud.active_section!="dialogue","display-only NPC does not invent dialogue")
		world.player.global_position += Vector2(400,0)
		check(not CATALOG.nearby(world,id),"distance gate rejects far player")
		if npc.has_verified_normal_dialogue:
			check(not world.dialogue_service.resolve(id,"",world._npc_dialogue_state()).ok,"far UI resolve denied")
		world.player.global_position -= Vector2(400,0)
		world.field_map.data.npc_spawn.erase(diagnostic)
		preview.queue_free()
	check(world.field_map.data.npc_spawn==existing,"existing NPC rows unchanged")
	check(world.gold==initial_gold and world.inventory==initial_inventory,"dialogue never changes economy")
	check(world._save_game(true)==OK,"real isolated save writes")
	var save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(not JSON.stringify(save).contains("l1j_tw380_npc_"),"NPC runtime definitions not persisted into save")
	world.queue_free()
	await process_frame
	world = await boot()
	for id: String in CATALOG.records(): check(not CATALOG.nearby(world,id),"restart preserves inactive placement")
	check(world.gold==initial_gold and same_counts(world.inventory,initial_inventory),"save/restart preserves economy")
	check(world.dialogue_service.registry.size()==6 and world.dialogue_service.source_registry.size()==3,"restart reloads both registries")
	world.queue_free()
	await process_frame
	print("SOURCE_NPC_MAIN checks=",checks," failures=",errors.size()," source_map_placement=HOLD transient_fixture_only")
	quit(0 if errors.is_empty() else 1)
