extends SceneTree
const SOURCE=preload("res://scripts/quests/source_quest523.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const CHOICE=preload("res://scripts/quests/quest_choice523.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_CHOICE523_FAIL: "+label)
func norm(value: Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func freeze(node: Node,hud: Node)->void:
	if node==hud:return
	node.set_process(false);node.set_physics_process(false)
	for child: Node in node.get_children():freeze(child,hud)
func make_world()->TwilightWorld:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"actual class-selected Main")
	freeze(world,world.hud)
	return world
func open_box(world: TwilightWorld,key: String,id: String)->Node:
	world._on_inventory_item_activated(key+("@@@"+id if not id.is_empty() else ""))
	return world.hud.get_meta("patch523_reward_choice",null)
func _initialize()->void:call_deferred("run")
func run()->void:
	var fresh: bool=false;var seed: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
		if arg.begins_with("--quest-pack="):fresh=true;check(SOURCE.install_zip(arg.trim_prefix("--quest-pack=")).ok,"unchanged quest v1 installed")
	if not fresh:
		check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"unmodified actual811 grant save copy")
		if not failures.is_empty():quit(1);return
	var world: TwilightWorld=make_world()
	check(world.quest_item_provider.has_definition(369002),"existing original choice consumer available")
	if fresh:
		for batch: int in range(100):
			world.quest_auto.retry_at=0;world.quest_auto.next_scan=0
			var prior: int=world.quest_service.claimed.size();world.quest_auto.tick(world)
			if prior==world.quest_service.claimed.size():break
		for i: int in range(50):world.quickslots[i]={"kind":"item","id":"HP 물약"} if i%3==0 else {}
		world.ui_preferences.edited_quickslots[world.job_class]=true
	var id: String=""
	if not fresh:
		for physical: String in world.item_instances:
			if int(world.item_instances[physical].get("record",{}).get("source_item_class_id",0))==369002:id=physical;break
		check(not id.is_empty() and OWN.proof(world,id).ok,"actual quest101252 reward421592 selected physical receipt")
	var definition: Dictionary=D.definition_id("369002");var canonical: Dictionary=D.variant_item(definition.native_record,1)
	var key: String=str(canonical.name) if fresh else str(world.item_instances[id].name)
	check(int(world.inventory.get(key,0))==1 and not definition.original_item.TestItem,"one genuine nonTest original choice box owned")
	var path: String=world.save_path();var hash: String=FileAccess.get_sha256(path)
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	var claims: Dictionary=world.quest_service.claimed.duplicate(true);var slots: Array=world.quickslots.duplicate(true)
	var dialog: Node=open_box(world,key,id)
	check(dialog!=null and dialog.choices.item_count==4,"actual existing UI offers all four original entity choices")
	check(world.inventory==inventory and FileAccess.get_sha256(path)==hash,"opening selection never consumes or grants")
	var entity: int=int(dialog.choices.get_item_metadata(0));var row: Dictionary={}
	for candidate: Dictionary in canonical.source_use_spec.rewards:
		if int(candidate.source_entity_id)==entity:row=candidate
	check(not row.is_empty() and entity!=int(row.item_class_id),"real source entityID is distinct from output ItemClass ID")
	var output: Dictionary=D.variant_item(D.cached_definition(str(int(row.item_class_id))).native_record,int(row.bless_raw))
	dialog.find_child("CancelSourceReward",true,false).pressed.emit();await process_frame
	check(world.inventory==inventory and world.item_instances==instances and FileAccess.get_sha256(path)==hash,"actual cancel button preserves exact input and all ownership")
	dialog=open_box(world,key,id)
	check(not CHOICE.claim_selection(world,dialog.record,int(row.item_class_id)) and FileAccess.get_sha256(path)==hash,"passing resultItemClass instead of source entity cannot claim")
	world.ui_preferences["patch523_select_reward_initial_zero_enabled"]=false
	check(not CHOICE.claim_selection(world,dialog.record,entity) and world.inventory==inventory and FileAccess.get_sha256(path)==hash,"disabled existing +0 policy preserves source box")
	world.ui_preferences["patch523_select_reward_initial_zero_enabled"]=true
	var lock: String=key if fresh else key+"@@@"+id
	world.ui_preferences.item_locks[lock]=true
	check(not CHOICE.claim_selection(world,dialog.record,entity) and FileAccess.get_sha256(path)==hash,"lock added AFTER opening is rechecked on confirm")
	world.ui_preferences.item_locks.erase(lock)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
	dialog.choices.select(0);dialog.choices.item_selected.emit(0);dialog.confirm.pressed.emit()
	check(is_instance_valid(dialog) and not dialog.committing and world.inventory==inventory and world.item_instances==instances and FileAccess.get_sha256(path)==hash,"actual confirm save failure preserves UI choice,input,gear outputs and bytes")
	world.equipment_collections.test_save_writer=func(target: String,data: Dictionary)->Error:
		var error: Error=WRITER.write(target,data)
		return ERR_FILE_CANT_WRITE if error==OK else error
	dialog.confirm.pressed.emit()
	var durable: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(durable.inventory.get(key,0))==0 and int(durable.inventory.get(str(output.name),0))==int(inventory.get(str(output.name),0))+1,"write-then-error commits one exact source output and one actual input")
	var added: Array=[]
	for physical: String in durable.item_instances:
		if not instances.has(physical):added.append(physical)
	check(added.size()==1,"one real physical rune instance created")
	if added.size()==1:
		var gear: Dictionary=durable.item_instances[added[0]];var proof: Dictionary=gear.source_m_reward_proof
		check(gear.name==output.name and int(gear.level)==0 and int(proof.entity_id)==entity and int(proof.source_item_class_id)==int(row.item_class_id) and int(proof.bless)==int(row.bless_raw),"exact rune ID,blessing,entity and explicit host +0 policy persisted")
		if not fresh:check(gear.quest_source_input_receipt==norm(instances[id].quest_reward_receipt) and gear.quest_source_input_physical_id==id,"new gear retains selected immutable quest origin proof")
	check(world.quest_service.save_blocked if fresh else not world.quest_service.save_blocked,"native uncertain result protected or selected receipt transaction confirmed")
	world.equipment_collections.test_save_writer=Callable();hash=FileAccess.get_sha256(path)
	if not fresh:
		world._on_inventory_item_activated(key+"@@@"+id)
		check(FileAccess.get_sha256(path)==hash and not world.item_instances.has(id),"spent physical selection cannot consume any other item")
	check(not world.quest_auto.complete(world,["m523:quest:101252"]) and FileAccess.get_sha256(path)==hash,"selection cannot regrant original quest")
	world.queue_free();await process_frame;world=make_world()
	check(norm(world.inventory)==durable.inventory and norm(world.item_instances)==durable.item_instances and norm(world.quest_service.export_state())==durable.quest_state,"fresh Main restores exact output,input and receipt state")
	check(world.quest_service.claimed==claims and norm(world.quickslots)==norm(slots),"all source claims and50 slots preserved")
	check(not world.quest_service.save_blocked,"confirmed reload clears native stale-state protection")
	world.quest_auto.refresh_context(world);var completed: int=0;var pending: int=0
	for entry: Dictionary in world.quest_service.entries(world.level,world.inventory):
		if entry.get("source_id")!=null and entry.completed:
			completed+=1
			if not entry.rewards.get("pending_use",[]).is_empty():pending+=1
	print("QUEST_CHOICE523_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"mode":"real_native_choice" if fresh else "real_held_choice_receipt","completed":completed,"pending_use_completed":pending,"source_item_id":369002,"chosen_entity_id":entity,"output_item_id":int(row.get("item_class_id",0)),"final_save_sha256":FileAccess.get_sha256(path),"input_seed_sha256":seed,"scope":"real source box/UI/physical output/atomic proof/failure/reconnect; rune wear/effect remains equipment-owner scope"}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
