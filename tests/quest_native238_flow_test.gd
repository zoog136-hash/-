extends SceneTree
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("QUEST_NATIVE_FLOW_FAIL: "+label)
func normalized(value: Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func make_world()->TwilightWorld:
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false)
	check(QA.enter_game(world),"actual Main class confirmation")
	return world
func held(world: TwilightWorld)->Dictionary:
	var result: Dictionary={}
	for id: String in world.item_instances:
		if world.item_instances[id].get("record",{}).get("source_pending_use",false):result[id]=world.item_instances[id]
	return normalized(result)
func _initialize()->void:call_deferred("run")
func run()->void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--quest-pack="):check(SOURCE.install_zip(arg.trim_prefix("--quest-pack=")).ok,"unchanged received quest v1 installed")
	var world: TwilightWorld=make_world()
	check(world.quest_item_provider.ready and D.pack_identity().get("sha256")==D.DATA_SHA,"actual shared provider and authenticated136-shard pack available")
	if not world.quest_item_provider.ready:world.queue_free();quit(1);return
	# Explicit valid user-edit fixture for50 slots; no item ownership is added.
	# Main separately sanitizes its fresh-save automatic skill seed on reload.
	for index: int in range(50):world.quickslots[index]={"kind":"item","id":"HP 물약"} if index%3==0 else {}
	world.ui_preferences.edited_quickslots[world.job_class]=true
	var quickslots: Array=world.quickslots.duplicate(true)
	var capture: Dictionary={}
	world.equipment_collections.test_save_writer=func(path: String,data: Dictionary)->Error:
		if not data.get("quest_state",{}).get("item_grants",{}).is_empty():
			capture["candidate"]=data.duplicate(true)
			capture["live_inventory"]=world.inventory.duplicate(true)
			capture["live_instances"]=world.item_instances.duplicate(true)
			capture["live_claims"]=world.quest_service.claimed.duplicate(true)
			capture["hash"]=FileAccess.get_sha256(path)
			return ERR_FILE_CANT_WRITE
		return WRITER.write(path,data)
	for batch: int in range(100):
		world.quest_auto.tick(world)
		if capture.has("candidate"):break
	check(capture.has("candidate"),"real automatic acquisition reaches a native/held mixed reward transaction")
	if not capture.has("candidate"):world.queue_free();quit(1);return
	var path: String=world.save_path()
	check(world.inventory==capture.live_inventory and world.item_instances==capture.live_instances and world.quest_service.claimed==capture.live_claims and FileAccess.get_sha256(path)==capture.hash,"failed native supplier transaction preserves live ownership,claims and disk")
	var retry_ids: Array[String]=[]
	for row: Dictionary in world.quest_service.source.quests:
		if capture.candidate.quest_state.claimed.has(row.id) and not capture.live_claims.has(row.id):retry_ids.append(row.id)
	var staged_held: int=0
	for physical: Dictionary in capture.candidate.item_instances.values():
		if retry_ids.has(str(physical.get("quest_reward_receipt",{}).get("quest_id",""))) and physical.get("record",{}).get("source_pending_use",false):staged_held+=1
	check(staged_held>0,"shared full-value supplier preserves held rewards prepared in the SAME batch")
	world.equipment_collections.test_save_writer=func(target: String,data: Dictionary)->Error:
		var error: Error=WRITER.write(target,data)
		return ERR_FILE_CANT_WRITE if error==OK else error
	world.quest_auto.retry_at=0
	check(world.quest_auto.complete(world,retry_ids),"post-write error is confirmed as one committed native/quest/held transaction")
	world.equipment_collections.test_save_writer=Callable()
	check(normalized(world.quest_service.item_grants)==normalized(capture.candidate.quest_state.item_grants),"native supplier receipts adopt exactly the confirmed candidate")
	var once: String=FileAccess.get_sha256(path)
	check(not world.quest_auto.complete(world,retry_ids) and FileAccess.get_sha256(path)==once,"replayed native acquisition cannot grant again")
	for batch: int in range(100):
		world.quest_auto.retry_at=0;world.quest_auto.next_scan=0
		var before: int=world.quest_service.claimed.size()
		world.quest_auto.tick(world)
		if world.quest_service.claimed.size()==before:break
	var completed: int=0;var pending: int=0
	world.quest_auto.refresh_context(world)
	for row: Dictionary in world.quest_service.entries(world.level,world.inventory):
		if row.get("source_id")!=null and row.completed:
			completed+=1
			if not row.rewards.get("pending_use",[]).is_empty():pending+=1
	check(completed==811 and world.level==86 and not world.quest_service.claimed.has("m523:quest:96201"),"all native bindings preserve original level eligibility and811 source completions")
	var claims: Dictionary=world.quest_service.claimed.duplicate(true)
	var prior_held: Dictionary=held(world)
	var receipts: Dictionary=world.quest_service.item_grants.duplicate(true)
	var buff: Dictionary=D.definition_id("859").native_record
	var bag: Dictionary=D.definition_id("1281").native_record
	var buff_name: String=str(buff.name);var bag_name: String=str(bag.name)
	var counts: Dictionary={859:0,1281:0}
	for rows: Array in receipts.values():
		for receipt: Dictionary in rows:counts[int(receipt.item_class_id)]=int(counts.get(int(receipt.item_class_id),0))+int(receipt.quantity)
	check(int(world.inventory.get(buff_name,0))==int(counts[859]) and int(counts[859])>0 and int(world.inventory.get(bag_name,0))==int(counts[1281]) and int(counts[1281])>0,"all native stacks exactly match source reward receipt quantities")
	var before_inventory: Dictionary=world.inventory.duplicate(true)
	var before_buffs: Dictionary=world.active_item_buffs.duplicate(true)
	var before_hash: String=FileAccess.get_sha256(path)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
	world._on_inventory_item_activated(buff_name)
	check(world.inventory==before_inventory and world.active_item_buffs==before_buffs and FileAccess.get_sha256(path)==before_hash,"actual native buff use write failure preserves item,effect and save")
	world.equipment_collections.test_save_writer=Callable()
	var melee_before: int=world._active_item_buff_total("melee_damage")
	var combat_before: int=world._melee_damage_stat()
	world._on_inventory_item_activated(buff_name)
	check(int(world.inventory[buff_name])==int(counts[859])-1,"actual inventory handler consumes exactly one native quest buff item")
	var spec: Dictionary=buff.source_use_spec
	check(world.active_item_buffs.has(buff_name) and world.active_item_buffs[buff_name].source_buff_class==spec.source_buff_class and int(world._active_item_buff_total("melee_damage"))-melee_before==int(spec.typed_effects.melee_damage),"exact source buff and combat modifier become live")
	check(world._melee_damage_stat()-combat_before==int(spec.typed_effects.melee_damage),"original buff reaches the actual player melee-damage calculation")
	var after_buff: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(after_buff.active_item_buffs.has(buff_name) and int(after_buff.inventory[buff_name])==int(counts[859])-1,"native buff and quantity commit in the same save")
	before_inventory=world.inventory.duplicate(true);before_hash=FileAccess.get_sha256(path)
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_FILE_CANT_WRITE
	world._on_inventory_item_activated(bag_name)
	check(world.inventory==before_inventory and FileAccess.get_sha256(path)==before_hash,"actual original food-box failure preserves box and all outputs")
	world.equipment_collections.test_save_writer=Callable()
	var expected_food: Dictionary={}
	for reward: Dictionary in bag.source_use_spec.rewards:
		if preload("res://scripts/loot/patch523_item_use.gd").class_matches(reward.get("class_ids",[]),world.BASE508.source_class_id(world.job_class)):
			var output: Dictionary=D.variant_item(D.cached_definition(str(int(reward.item_class_id))).native_record,int(reward.bless_raw))
			expected_food[str(output.name)]=int(reward.amount)
	check(not expected_food.is_empty(),"original box has exact outputs for the actual class")
	world._on_inventory_item_activated(bag_name)
	check(int(world.inventory[bag_name])==int(counts[1281])-1,"actual native box consumes exactly one source box")
	for key: String in expected_food:
		check(int(world.inventory.get(key,0))==int(before_inventory.get(key,0))+int(expected_food[key]),"original output ID,quantity and bless-specific key are received: "+key)
	check(held(world)==prior_held and world.quest_service.claimed==claims and world.quickslots==quickslots,"using new native rewards never converts old held stacks or changes claims/50 quickslots")
	var final_inventory: Dictionary=world.inventory.duplicate(true)
	var final_buffs: Dictionary=normalized(world.active_item_buffs)
	var final_hash: String=FileAccess.get_sha256(path)
	world.queue_free();await process_frame
	world=make_world()
	check(normalized(world.inventory)==normalized(final_inventory) and normalized(world.active_item_buffs)==final_buffs,"reconstructed Main keeps exact native outputs,buff and source debits")
	check(normalized(world.quest_service.item_grants)==normalized(receipts),"all native quest receipts survive reload")
	check(world.quest_service.claimed==claims and held(world)==prior_held,"all claims and held rewards survive reload")
	check(normalized(world.quickslots)==normalized(quickslots),"all50 user quickslots survive JSON numeric representation changes")
	check(not world.quest_auto.complete(world,retry_ids) and FileAccess.get_sha256(path)==final_hash,"reloaded quest receipts reject a duplicate native payout")
	var remaining: int=int(world.inventory[bag_name])
	world.equipment_collections.test_save_writer=func(target: String,data: Dictionary)->Error:
		var error: Error=WRITER.write(target,data)
		return ERR_FILE_CANT_WRITE if error==OK else error
	world._on_inventory_item_activated(bag_name)
	var committed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(committed.inventory[bag_name])==remaining-1 and world.quest_service.save_blocked,"shared consumer post-write error preserves durable debit and blocks stale live transactions")
	var committed_hash: String=FileAccess.get_sha256(path)
	world._on_inventory_item_activated(bag_name)
	check(FileAccess.get_sha256(path)==committed_hash,"retry after uncertain native effect cannot consume or grant again")
	world.queue_free();await process_frame
	world=make_world()
	check(not world.quest_service.save_blocked and int(world.inventory[bag_name])==remaining-1 and normalized(world.inventory)==committed.inventory,"fresh Main recovers exactly one committed native box and all outputs")
	print("QUEST_NATIVE_FLOW_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"completed":completed,"pending_use_completed":pending,"source_quantities":counts,"native_receipt_quests":receipts.size(),"same_batch_held_instances":staged_held,"item_class_ids":[859,1281],"pack_sha256":D.DATA_SHA,"pre_postwrite_save_sha256":final_hash,"final_save_sha256":FileAccess.get_sha256(path),"scope":"Actual source acquisition to shared supplier,inventory use,buff/box effects,atomic save,failure recovery and reload; no old-save conversion"}))
	world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
