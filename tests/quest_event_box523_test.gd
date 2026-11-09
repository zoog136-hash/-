extends SceneTree
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const USE=preload("res://scripts/loot/patch523_item_use.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const ID=368202
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_EVENT_BOX_FAIL: "+label)
func norm(value: Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func make_world()->TwilightWorld:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false)
	check(QA.enter_game(world),"actual class-selected Main")
	return world
func use(world: TwilightWorld,key: String,id: String)->void:
	if id.is_empty():world._on_inventory_item_activated(key);return
	var bag: Variant=world.hud.lineage_inventory_ui
	bag.set_character_state(world.hud.character_state);bag.inventory=world.inventory
	bag._select_item(key+"@@@"+id);check(not bag.detail_action.disabled,"actual selected box button enabled")
	bag.detail_action.pressed.emit()
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String="";var fresh: bool=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
		if arg.begins_with("--quest-pack="):fresh=true;check(SOURCE.install_zip(arg.trim_prefix("--quest-pack=")).ok,"unchanged quest v1 installed")
	if not fresh:
		check(FileAccess.get_sha256("user://twilight_v20_save.json")==seed and seed.length()==64,"untouched real811 grant save copied")
		if not failures.is_empty():quit(1);return
	var world: TwilightWorld=make_world()
	check(world.quest_item_provider.has_definition(ID),"verified existing guaranteed-bag consumer installed")
	if fresh:
		for batch: int in range(100):
			world.quest_auto.retry_at=0;world.quest_auto.next_scan=0
			var prior: int=world.quest_service.claimed.size();world.quest_auto.tick(world)
			if prior==world.quest_service.claimed.size():break
		for index: int in range(50):world.quickslots[index]={"kind":"item","id":"HP 물약"} if index%3==0 else {}
		world.ui_preferences.edited_quickslots[world.job_class]=true
	var ids: Array[String]=[]
	for id: String in world.item_instances:
		if int(world.item_instances[id].get("record",{}).get("source_item_class_id",0))==ID:ids.append(id)
	ids.sort_custom(func(a: String,b: String)->bool:return int(a)<int(b))
	var definition: Dictionary=D.definition_id(str(ID));var record: Dictionary=D.variant_item(definition.native_record,1)
	var key: String=str(record.name) if fresh else str(world.item_instances[ids[0]].name)
	check((fresh and int(world.inventory.get(key,0))==5) or (not fresh and ids.size()==5 and OWN.proof(world,ids[0]).ok),"five genuine original training quest rewards exist")
	check(not definition.original_item.TestItem and record.source_use_spec.kind=="guaranteed_bag" and record.source_use_spec.rewards.size()==13 and int(record.source_delete_time_raw)==202611110500,"full original nonTest box,class13 outputs and deadline retained")
	check(D.deadline_problem(record,540).is_empty(),"actual source deadline currently open under existing clock policy")
	var outputs: Dictionary={}
	for reward: Dictionary in record.source_use_spec.rewards:
		if USE.class_matches(reward.get("class_ids",[]),world.BASE508.source_class_id(world.job_class)):
			var child: Dictionary=D.variant_item(D.cached_definition(str(int(reward.item_class_id))).native_record,int(reward.bless_raw))
			outputs[str(child.name)]=int(reward.amount)
	check(outputs.size()==1,"actual Knight gets only its exact source class output")
	var claims: Dictionary=world.quest_service.claimed.duplicate(true);var slots: Array=world.quickslots.duplicate(true)
	var inventory: Dictionary=world.inventory.duplicate(true);var physical: Dictionary=world.item_instances.duplicate(true)
	var path: String=world.save_path();var hash: String=FileAccess.get_sha256(path);var rng_before: int=world.rng.state
	var first: String="" if fresh else ids[0];var second: String="" if fresh else ids[1]
	var lock: String=key if fresh else key+"@@@"+first
	world.ui_preferences.item_locks[lock]=true;use(world,key,first)
	check(world.inventory==inventory and FileAccess.get_sha256(path)==hash,"source input lock blocks every output and debit")
	world.ui_preferences.item_locks.erase(lock)
	var job: String=world.job_class;world.job_class="qa_unmapped_class";use(world,key,first);world.job_class=job
	check(world.inventory==inventory and world.rng.state==rng_before and FileAccess.get_sha256(path)==hash,"controlled unsupported class cannot receive another class ticket")
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
	use(world,key,first)
	check(world.inventory==inventory and world.item_instances==physical and world.rng.state==rng_before and FileAccess.get_sha256(path)==hash,"box write failure preserves exact input,output,receipt and RNG")
	world.equipment_collections.test_save_writer=Callable();use(world,key,first)
	check(int(world.inventory[key])==4 and (fresh or not world.item_instances.has(first)),"actual selected one-unit box consumed exactly once")
	for output: String in outputs:check(int(world.inventory.get(output,0))==int(inventory.get(output,0))+int(outputs[output]),"original classID/quantity/blessing output granted: "+output)
	check(fresh or not world.inventory.has(str(record.name)),"raw use creates no canonical box alias")
	hash=FileAccess.get_sha256(path)
	if not fresh:
		world._on_inventory_item_activated(key+"@@@"+first)
		check(FileAccess.get_sha256(path)==hash and int(world.inventory[key])==4,"spent physical box cannot consume another same-name input")
	world.equipment_collections.test_save_writer=func(target: String,data: Dictionary)->Error:
		var error: Error=WRITER.write(target,data)
		return ERR_FILE_CANT_WRITE if error==OK else error
	use(world,key,second)
	var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(durable.inventory[key])==3,"write-then-error durably consumes one second actual box")
	for output: String in outputs:check(int(durable.inventory.get(output,0))==int(inventory.get(output,0))+2*int(outputs[output]),"two actual boxes produce exactly two eligible class outputs")
	check(world.quest_service.save_blocked if fresh else not world.quest_service.save_blocked,"native stale live view protected or selected transaction confirmed")
	world.equipment_collections.test_save_writer=Callable();hash=FileAccess.get_sha256(path)
	check(not world.quest_auto.complete(world,["m523:quest:101212"]) and FileAccess.get_sha256(path)==hash,"opening a reward never grants its original quest twice")
	world.queue_free();await process_frame;world=make_world()
	check(norm(world.inventory)==durable.inventory and norm(world.item_instances)==durable.item_instances and norm(world.quest_service.export_state())==durable.quest_state,"new Main restores exact box/input/output/receipt state")
	check(world.quest_service.claimed==claims and norm(world.quickslots)==norm(slots),"existing original claims and50 slots preserved")
	world.quest_auto.refresh_context(world);var completed: int=0;var pending: int=0
	for row: Dictionary in world.quest_service.entries(world.level,world.inventory):
		if row.get("source_id")!=null and row.completed:
			completed+=1
			if not row.rewards.get("pending_use",[]).is_empty():pending+=1
	print("QUEST_EVENT_BOX_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":"real_native_five_boxes" if fresh else "real_held_receipt_boxes","completed":completed,"pending_use_completed":pending,"item_class_id":ID,"actual_class_id":world.BASE508.source_class_id(world.job_class),"outputs":outputs,"final_save_sha256":FileAccess.get_sha256(path),"input_seed_sha256":seed,"controlled_qa":["lock","unmapped class flag","injected save failures"],"scope":"box opened to exact class-owned output; child skill ticket consumption is separate and not claimed"}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
