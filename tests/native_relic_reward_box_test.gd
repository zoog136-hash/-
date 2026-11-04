extends SceneTree
const Box=preload("res://scripts/cards/native_relic_reward_box.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Registry=preload("res://scripts/lineagem_base508.gd")
const Fixture=preload("res://tests/relic_subslot_runtime_test.gd")
class Host extends Fixture.Host:
	var next_item_instance_id: int=1
var checks: int=0
var errors: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func run() -> void:
	check(Box.rules_valid(),"only the exact two IsGiven rows are executable")
	var record: Dictionary=Box.record();var bag: Dictionary={record.name:2}
	var physicals: Dictionary={"1":{"name":record.name,"record":record},"2":{"name":record.name,"record":record},"future":{"name":"future","metadata":{"retain":true}}}
	var before: int=hash([bag,physicals])
	check(not Box.prepare(bag,physicals,1,"missing").ok,"selected missing instance cannot debit another box")
	check(not Box.prepare(bag,physicals,1,"1",{"1":true}).ok,"selected locked instance cannot fall back to unlocked box")
	check(not Box.prepare({record.name:1},physicals,1).ok,"inconsistent physical ownership rejected")
	check(not Box.prepare({record.name:1},{},1).ok,"legacy name-only inventory is not backfilled")
	var prepared: Dictionary=Box.prepare(bag,physicals,1,"1")
	check(prepared.ok and prepared.consumed_quantity==1 and prepared.rewards.size()==2,"one exact box gives both guaranteed outputs")
	check(hash([bag,physicals])==before,"prepare does not mutate input")
	check(prepared.item_instances.has("2") and prepared.item_instances.future==physicals.future and not prepared.item_instances.has("1"),"other box and unknown future metadata preserved")
	check(prepared.inventory[record.name]==1,"only selected box debited")
	for reward: Dictionary in prepared.rewards:
		check(prepared.inventory[reward.name]==1 and prepared.item_instances[reward.instance_id].record.source_item_class_id==reward.item_class_id,"exact physical output "+str(reward.item_class_id))
	check(not Box.prepare(prepared.inventory,prepared.item_instances,prepared.next_item_instance_id,"1").ok,"replayed selected reference cannot consume another box")
	var host=Host.new();root.add_child(host);host.catalog_db=Registry.apply_catalog({});host.card_draw_fusion.configure(host.catalog_db)
	host.inventory=bag.duplicate(true);host.item_instances=physicals.duplicate(true)
	var runtime=Runtime.new();check(runtime.configure(host),"runtime configures")
	host.save_error=ERR_FILE_CANT_WRITE;before=hash([host.inventory,host.item_instances,host.next_item_instance_id,runtime.export_state(),host.rng.state])
	check(runtime.use_relic_reward_box(record.name,"1").code=="save_failed" and hash([host.inventory,host.item_instances,host.next_item_instance_id,runtime.export_state(),host.rng.state])==before,"writer failure preserves box, rewards, progress, IDs and RNG")
	host.save_error=OK
	check(runtime.use_relic_reward_box(record.name,"1").ok,"runtime opens through durable writer")
	check(host.saved.inventory==host.inventory and host.saved.item_instances==host.item_instances and host.saved.next_item_instance_id==host.next_item_instance_id,"debit, both rewards and ID counter share one saved snapshot")
	check(not Unlock.unlocked(runtime.progress),"opening box never auto-uses unlock item or grants a quest claim")
	check(runtime.use_relic_unlock_item(str(Unlock.record().name)).ok and Unlock.unlocked(runtime.progress),"received original physical item unlocks via existing item use")
	host.queue_free();await process_frame
	print("RELIC_REWARD_BOX ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
