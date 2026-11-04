extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_MISSING_PROVIDER_FAIL: "+label)
func norm(value: Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func _initialize()->void:call_deferred("run")
func run()->void:
	var expected: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):expected=arg.trim_prefix("--seed-sha=")
	check(expected.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==expected,"unmodified actual native-grant save copied without consumer pack")
	if not failures.is_empty():quit(1);return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://twilight_v20_save.json"))
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false)
	check(QA.enter_game(world,str(original.get("job_class","기사"))) and not world.quest_item_provider.ready,"real Main loads safely with the shared item pack absent")
	check(not world.quest_service.item_grants.is_empty() and norm(world.quest_service.item_grants)==original.quest_state.item_grants,"unavailable provider does not discard native grant receipts")
	check(norm(world.inventory)==original.inventory and norm(world.item_instances)==original.item_instances,"all real native and held ownership survives missing pack load")
	check(norm(world.quickslots)==original.quickslots,"all50 saved source item references survive missing optional pack without permitting use")
	var state: Dictionary=world.quest_service.export_state()
	check(world.quest_service.validate_saved_state(state).is_empty(),"receipt validation does not depend on optional pack availability")
	var qid: String=str(state.item_grants.keys()[0])
	for field: String in ["quantity","reward_id","bless_raw"]:
		var invalid: Dictionary=state.duplicate(true);invalid.item_grants[qid][0][field]=0.5
		check(not world.quest_service.validate_saved_state(invalid).is_empty(),"fractional native receipt rejected: "+field)
	var invalid: Dictionary=state.duplicate(true);invalid.item_grants[qid].append(invalid.item_grants[qid][0].duplicate(true))
	check(not world.quest_service.validate_saved_state(invalid).is_empty(),"duplicate native source reward receipt rejected")
	invalid=state.duplicate(true);invalid.claimed.erase(qid)
	check(not world.quest_service.validate_saved_state(invalid).is_empty(),"native grant without completion relation rejected")
	var calls: Array[int]=[0]
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:calls[0]+=1;return ERR_FILE_CANT_WRITE
	for item: int in [859,1281,239,233,368202,369002,177192,177202,177212,177222,177232,177252,177332,177452,306611,306621,306631,306641]:
		var key: String=""
		for rows: Array in state.item_grants.values():
			for receipt: Dictionary in rows:
				if int(receipt.item_class_id)==item:key=str(receipt.inventory_key)
		check(not key.is_empty(),"real source receipt locates native item: "+str(item))
		world._on_inventory_item_activated(key)
	check(calls[0]==0 and norm(world.inventory)==original.inventory and norm(world.active_item_buffs)==original.active_item_buffs,"missing provider blocks use before a save or substitute name-based effect")
	check(FileAccess.get_sha256(world.save_path())==expected and norm(world.quest_service.export_state())==original.quest_state,"missing provider preserves save bytes,claims and receipt state")
	print("QUEST_MISSING_PROVIDER_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_save_sha256":expected,"scope":"actual source-granted inventory and receipts survive absent optional provider; no fixtures/grants"}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
