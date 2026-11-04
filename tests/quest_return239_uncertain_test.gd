extends SceneTree
const WRITER=preload("res://scripts/skills/save_writer.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const KEY="귀환 주문서 (각인) · 원본#239"
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_RETURN239_UNCERTAIN_FAIL: "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
	check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"copy of actual source-granted239 save used for controlled inconsistent-writer fault")
	if not failures.is_empty():quit(1);return
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false)
	check(QA.enter_game(world) and int(world.inventory.get(KEY,0))>0,"actual owned native239 and Main load")
	var quantity: int=int(world.inventory[KEY]);var position: Vector2=world.player.global_position
	var original_buffs: Dictionary=world.patch523_npc_spells.player_buffs.duplicate(true)
	for restriction: String in ["CannotUseItem","CannotTeleport"]:
		# Controlled runtime restriction fixture; no native NPC encounter or
		# inventory provenance is invented by this guard check.
		var values: Dictionary={};values[restriction]=1
		world.patch523_npc_spells.player_buffs[-239]={"values":values}
		var blocked: Dictionary=world.consumable_service.use_owned_native_return(KEY)
		check(not blocked.ok and int(blocked.consumed)==0 and world.player.global_position==position and int(world.inventory[KEY])==quantity,"current host restriction retained: "+restriction)
		world.patch523_npc_spells.player_buffs=original_buffs.duplicate(true)
	var calls: Array[int]=[0]
	world.equipment_collections.test_save_writer=func(path: String,data: Dictionary)->Error:
		calls[0]+=1
		# Deliberately store a DIFFERENT movement than the transaction requests.
		data["position"]=[float(data.position[0])+1.0,float(data.position[1])]
		var error: Error=WRITER.write(path,data)
		return ERR_FILE_CANT_WRITE if error==OK else error
	var outcome: Dictionary=world.consumable_service.use_owned_native_return(KEY)
	check(not outcome.ok and not outcome.saved and outcome.get("uncertain",false) and int(outcome.consumed)==0,"unconfirmed movement/debit result is explicit, never reported committed/preserved")
	check(world.quest_service.save_blocked and world.player.global_position==position and int(world.inventory[KEY])==quantity,"stale live ownership is protected pending recovery")
	var path: String=world.save_path();var hash: String=FileAccess.get_sha256(path)
	var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(durable.inventory[KEY])==quantity-1 and hash!=seed and calls[0]==1,"controlled inconsistent disk result is retained for inspection, not overwritten")
	var retry: Dictionary=world.consumable_service.use_owned_native_return(KEY)
	check(not retry.ok and calls[0]==1 and FileAccess.get_sha256(path)==hash,"uncertain result cannot issue a second writer/debit")
	print("QUEST_RETURN239_UNCERTAIN_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"injected_fault":"writer stored a different position and returned error","original_seed_sha256":seed,"controlled_uncertain_save_sha256":hash,"scope":"isolated fault profile only; normal validated source saves unchanged"}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
