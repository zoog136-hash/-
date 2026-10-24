extends SceneTree

var errors: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		errors.append(detail)
		print("ENHANCEMENT_GAMEPLAY_FAIL: "+detail)

func _run() -> void:
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	# test_project.py gives this process an isolated user directory.
	world.set("source_save_blocked",false)
	world.set("equipped_items",{})
	world.set("inventory",{"낡은 장검":2,"무기 마법 주문서 (각인)":5})
	world.set("item_instances",{})
	world.set("enhancement_levels",{})
	world.call("_sync_item_instances")
	var instances: Dictionary = world.get("item_instances")
	var ids: Array = instances.keys()
	ids.sort()
	check(ids.size() == 2,"two physically independent swords")
	if ids.size() != 2:
		world.queue_free()
		await process_frame
		quit(1)
		return
	var hud: Node = world.get_node("HUD")
	var reference: String = "낡은 장검@@@"+str(ids[0])
	world.call("_attempt_enhancement","무기 마법 주문서 (각인)",reference)
	var stage: Control = hud.get("enhancement_reveal")
	check(is_instance_valid(stage),"real transaction opens dedicated presentation")
	check(int(instances[ids[0]].level) == 1 and int(instances[ids[1]].level) == 0,"only exact selected sword increases")
	check(int(world.get("inventory").get("무기 마법 주문서 (각인)")) == 4,"exactly one scroll consumed")
	check(stage.item_texture != null,"actual item icon connected")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.call("save_path")))
	check(int(saved.get("item_instances",{}).get(ids[0],{}).get("level",-1)) == 1 and int(saved.get("inventory",{}).get("무기 마법 주문서 (각인)",-1)) == 4,"committed level and cost saved before result reveal")
	check(hud.call("blocks_keyboard_input") and hud.call("blocks_world_input",Vector2.ZERO),"modal blocks keyboard and touch destinations")
	var rng_state: int = world.get("rng").state
	world.call("_attempt_enhancement","무기 마법 주문서 (각인)",reference)
	check(int(world.get("inventory").get("무기 마법 주문서 (각인)")) == 4 and int(instances[ids[0]].level) == 1,"repeated signal cannot spend or enchant during reveal")
	check(world.get("rng").state == rng_state,"duplicate request never rerolls")
	stage.skip_to_result()
	stage.close_reveal()
	await process_frame
	check(not hud.call("is_enhancement_presenting"),"confirmation releases modal")
	check(world.get("rng").state == rng_state,"skip and confirm do not roll gameplay RNG")
	world.call("_attempt_enhancement","무기 마법 주문서 (각인)",reference)
	check(int(world.get("inventory").get("무기 마법 주문서 (각인)")) == 3 and int(instances[ids[0]].level) == 2,"next legitimate attempt works after confirmation")
	stage = hud.get("enhancement_reveal")
	stage.skip_to_result()
	stage.close_reveal()
	await process_frame
	world.call("_set_item_locked",reference,true)
	world.call("_attempt_enhancement","무기 마법 주문서 (각인)",reference)
	check(not hud.call("is_enhancement_presenting") and int(world.get("inventory").get("무기 마법 주문서 (각인)")) == 3,"denied locked target produces no animation and no cost")
	world.call("_set_item_locked",reference,false)
	# Select a deterministic real RNG roll in the existing destroy interval.
	instances[ids[0]].level = 8
	var probe := RandomNumberGenerator.new()
	var chosen_seed: int = -1
	for seed_value: int in range(100):
		probe.seed = seed_value
		if probe.randf_range(0,100) > 33.3:
			chosen_seed = seed_value
			break
	check(chosen_seed >= 0,"deterministic failure roll available")
	world.get("rng").seed = chosen_seed
	world.call("_attempt_enhancement","무기 마법 주문서 (각인)",reference)
	stage = hud.get("enhancement_reveal")
	check(stage.result == "destroy" and stage.item_texture != null,"actual loss retains item image for dissolution")
	check(not instances.has(ids[0]) and instances.has(ids[1]) and int(world.get("inventory").get("낡은 장검")) == 1,"failure destroys only targeted physical sword")
	saved = JSON.parse_string(FileAccess.get_file_as_string(world.call("save_path")))
	check(not saved.get("item_instances",{}).has(ids[0]) and int(saved.get("inventory",{}).get("무기 마법 주문서 (각인)",-1)) == 2,"loss and scroll consumption persist before animation")
	stage.skip_to_result()
	stage.close_reveal()
	await process_frame
	world.set("source_save_blocked",true)
	world.queue_free()
	await process_frame
	if errors.is_empty(): print("ENHANCEMENT_GAMEPLAY_OK checks=%d" % checks)
	quit(0 if errors.is_empty() else 1)
