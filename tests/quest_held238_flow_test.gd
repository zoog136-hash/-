extends SceneTree
## Uses an untouched COPY of the actual ee4856dd 811-claim save. No fixture
## invents ownership; adversarial cases temporarily corrupt only that copy.
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_HELD_FLOW_FAIL: "+label)
func norm(value: Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func make_world()->TwilightWorld:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false)
	check(QA.enter_game(world),"real Main and saved class load")
	return world
func find(world: TwilightWorld,item: int)->String:
	for id: String in world.item_instances:
		if int(world.item_instances[id].get("record",{}).get("source_item_class_id",0))==item:return id
	return ""
func use(world: TwilightWorld,id: String)->void:
	var bag: Variant=world.hud.lineage_inventory_ui
	bag.set_character_state(world.hud.character_state);bag.inventory=world.inventory
	bag._select_item(str(world.item_instances[id].name)+"@@@"+id)
	check(not bag.detail_action.disabled,"actual inventory selected-instance action enabled")
	bag.detail_action.pressed.emit()
func _initialize()->void:call_deferred("run")
func run()->void:
	var seed: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed-sha="):seed=arg.trim_prefix("--seed-sha=")
	check(seed.length()==64 and FileAccess.get_sha256("user://twilight_v20_save.json")==seed,"input is the unmodified real811-claim save copy")
	if not failures.is_empty():quit(1);return
	var world: TwilightWorld=make_world()
	var buff_id: String=find(world,859);var bag_id: String=find(world,1281)
	var buff: Dictionary=OWN.proof(world,buff_id);var bag: Dictionary=OWN.proof(world,bag_id)
	check(world.quest_item_provider.ready and buff.ok and bag.ok,"real supplier pack authenticates existing quest-produced859/1281 receipts")
	if not buff.ok or not bag.ok:print(buff);print(bag);world.queue_free();quit(1);return
	check(int(buff.quantity)==3 and int(bag.quantity)==1,"actual source ownership includes partial-three buff stack and one box")
	var path: String=world.save_path();var hash: String=FileAccess.get_sha256(path)
	var physical: Dictionary=world.item_instances[buff_id].duplicate(true)
	var inventory: Dictionary=world.inventory.duplicate(true)
	var claims: Dictionary=world.quest_service.claimed.duplicate(true)
	var slots: Array=world.quickslots.duplicate(true)
	var receipt: Dictionary=physical.quest_reward_receipt.duplicate(true)
	world.item_instances[buff_id].erase("quest_reward_receipt")
	check(not OWN.proof(world,buff_id).ok,"old unreceipted ownership stays blocked without migration")
	world.item_instances[buff_id]=physical.duplicate(true)
	for key: String in ["source_sha256","quest_id","reward_id","item_class_id","bless_code_id","quantity"]:
		world.item_instances[buff_id].quest_reward_receipt[key]="wrong" if key in ["source_sha256","quest_id"] else 999999
		check(not OWN.proof(world,buff_id).ok,"tampered receipt blocked: "+key)
		world.item_instances[buff_id]=physical.duplicate(true)
	world.item_instances["duplicate-proof"]=physical.duplicate(true)
	check(not OWN.proof(world,buff_id).ok,"duplicate original reward proof blocked")
	world.item_instances.erase("duplicate-proof")
	world.inventory[buff.inventory_key]=int(world.inventory[buff.inventory_key])+1
	check(not OWN.proof(world,buff_id).ok,"aggregate inventory without physical proof blocked")
	world.inventory=inventory.duplicate(true)
	var reference: String=str(buff.inventory_key)+"@@@"+buff_id
	world.ui_preferences.item_locks[reference]=true
	use(world,buff_id)
	check(world.item_instances[buff_id]==physical and FileAccess.get_sha256(path)==hash,"selected physical lock preserves quantity,effect and disk")
	world.ui_preferences.item_locks.erase(reference)
	var candidate: Dictionary=OWN.prepare_debit(world,buff_id,1)
	world.item_instances[buff_id].source_reward_quantity=2
	check(not OWN.current(world,candidate),"stale debit quote cannot commit")
	world.item_instances[buff_id]=physical.duplicate(true)
	var buffs: Dictionary=world.active_item_buffs.duplicate(true)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
	use(world,buff_id)
	check(world.inventory==inventory and world.item_instances[buff_id]==physical and world.active_item_buffs==buffs and FileAccess.get_sha256(path)==hash,"real held buff save failure preserves all input,effect,receipt and bytes")
	world.equipment_collections.test_save_writer=Callable()
	var melee: int=world._melee_damage_stat()
	use(world,buff_id)
	var canonical: String=str(D.definition_id("859").native_record.name)
	check(int(world.item_instances[buff_id].source_reward_quantity)==2 and world.item_instances[buff_id].quest_reward_receipt==receipt and int(world.inventory[buff.inventory_key])==int(inventory[buff.inventory_key])-1,"partial use preserves exact physicalID and immutable original quantity-three receipt")
	check(not world.inventory.has(canonical) and world._melee_damage_stat()==melee+int(D.definition_id("859").native_record.source_use_spec.typed_effects.melee_damage),"real held debit activates native combat effect without canonical stack conversion")
	var state: Dictionary=world.quest_service.export_state()
	check(world.quest_service.validate_saved_state(state).is_empty() and int(state.item_grants[buff.quest_id][0].used_quantity)==1,"partial consumption and exact binding receipt persist together")
	var malformed: Dictionary=state.duplicate(true);malformed.item_grants[buff.quest_id][0].used_quantity=0.5
	check(not world.quest_service.validate_saved_state(malformed).is_empty(),"fractional use receipt rejected")
	var box_inventory: Dictionary=world.inventory.duplicate(true);var box_physical: Dictionary=world.item_instances[bag_id].duplicate(true)
	hash=FileAccess.get_sha256(path)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
	use(world,bag_id)
	check(world.inventory==box_inventory and world.item_instances[bag_id]==box_physical and FileAccess.get_sha256(path)==hash,"held food-box failure preserves exact box and all output keys")
	world.equipment_collections.test_save_writer=func(target: String,data: Dictionary)->Error:
		var error: Error=WRITER.write(target,data)
		return ERR_FILE_CANT_WRITE if error==OK else error
	use(world,bag_id)
	check(not world.item_instances.has(bag_id) and not world.quest_service.save_blocked,"post-write error confirms one committed held-box consumption")
	var expected: Dictionary={}
	for reward: Dictionary in D.definition_id("1281").native_record.source_use_spec.rewards:
		if preload("res://scripts/loot/patch523_item_use.gd").class_matches(reward.get("class_ids",[]),world.BASE508.source_class_id(world.job_class)):
			var output: Dictionary=D.variant_item(D.cached_definition(str(int(reward.item_class_id))).native_record,int(reward.bless_raw))
			expected[str(output.name)]=int(reward.amount)
	for key: String in expected:check(int(world.inventory.get(key,0))==int(box_inventory.get(key,0))+int(expected[key]),"held box grants original class-specific output/bless/quantity: "+key)
	check(not world.inventory.has(str(D.definition_id("1281").native_record.name)),"spent held box never becomes native aliases")
	world.equipment_collections.test_save_writer=Callable()
	hash=FileAccess.get_sha256(path)
	world._on_inventory_item_activated(str(bag.inventory_key)+"@@@"+bag_id)
	check(FileAccess.get_sha256(path)==hash,"spent selected reference cannot debit another held box")
	check(world.quest_service.claimed==claims and world.quickslots==slots,"effects never regrant quests or alter50 quickslots")
	var final_inventory: Dictionary=norm(world.inventory);var final_instances: Dictionary=norm(world.item_instances)
	var final_state: Dictionary=norm(world.quest_service.export_state());var final_buffs: Dictionary=norm(world.active_item_buffs)
	world.queue_free();await process_frame
	world=make_world()
	check(norm(world.inventory)==final_inventory and norm(world.item_instances)==final_instances and norm(world.active_item_buffs)==final_buffs,"new Main restores exact held remainder,box outputs and active effect")
	check(norm(world.quest_service.export_state())==final_state and world.quest_service.claimed==claims and norm(world.quickslots)==norm(slots),"binding receipts,old claims and50 user slots survive reconnect")
	check(OWN.proof(world,buff_id).ok and int(world.item_instances[buff_id].source_reward_quantity)==2,"remaining selected source stack stays provable after reconnect")
	check(not world.quest_auto.complete(world,[str(buff.quest_id),str(bag.quest_id)]) and FileAccess.get_sha256(path)==hash,"consumption never permits a second quest grant")
	print("QUEST_HELD_FLOW_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_seed_sha256":seed,"final_save_sha256":FileAccess.get_sha256(path),"item_ids":[859,1281],"scope":"real old811 receipt-selected partial use; no mass conversion/regrant; old822 without receipts blocked"}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
