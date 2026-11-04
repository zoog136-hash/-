extends SceneTree
## Consumes a SHA-pinned COPY of the real full-source Main grant save.
## This test never fabricates inventory, marks a quest complete or changes time.
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const QUEST = "m523:quest:101242"
const ITEM = 117304
const REWARD = 421582
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("QUEST_ITEM_USE_FAIL: "+label)
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func make_world() -> TwilightWorld:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false);world.player.set_physics_process(false)
	check(QA.enter_game(world),"existing class-confirmed Main save loads")
	return world
func owned(world: TwilightWorld) -> Array[String]:
	var ids: Array[String] = []
	for id: String in world.item_instances:
		var physical: Dictionary = world.item_instances[id]
		var receipt: Dictionary = physical.get("quest_reward_receipt",{})
		if int(physical.get("record",{}).get("source_item_class_id",0))==ITEM and receipt.get("quest_id")==QUEST and int(receipt.get("reward_id",0))==REWARD: ids.append(id)
	ids.sort_custom(func(a: String,b: String) -> bool:return int(a)<int(b))
	return ids
func other_items(world: TwilightWorld, name_value: String) -> Dictionary:
	var inventory: Dictionary = world.inventory.duplicate(true);inventory.erase(name_value)
	var physical: Dictionary = {}
	for id: String in world.item_instances:
		if str(world.item_instances[id].name)!=name_value: physical[id]=world.item_instances[id]
	return normalized({"inventory":inventory,"physical":physical})
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var expected: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--quest-use-seed-sha="): expected=arg.trim_prefix("--quest-use-seed-sha=")
	var seed_path: String = "user://twilight_v20_save.json"
	check(expected.length()==64 and FileAccess.get_sha256(seed_path)==expected,"input is the unmodified copied real Main grant save")
	if failures.size()>0:quit(1);return
	var world: TwilightWorld = make_world()
	check(world.quest_service.source.loaded_path==SOURCE.USER_PATH,"installed full original quest payload is consumed")
	check(world.quest_service.claimed.size()>=811 and world.quest_service.claimed.has(QUEST),"quest was already automatically completed and durably granted")
	world.quest_auto.refresh_context(world)
	var quest: Dictionary = world.quest_service.index[QUEST]
	check(world.quest_service.source.gate(quest,world.quest_auto.context,world.quest_service.claimed,int(Time.get_unix_time_from_system())).is_empty(),"actual original period, parent and level eligibility are satisfied")
	var original: Dictionary = {}
	for reward: Dictionary in quest.source_rewards:
		if int(reward.ID)==REWARD: original=reward
	check(int(original.get("RewardClassID",0))==ITEM and int(original.get("Amount",0))==3 and int(original.get("ItemBlessCodeID",0))==1 and not original.get("UseImmediately",true),"original reward defines exactly three normal-state items for explicit use")
	var ids: Array[String] = owned(world)
	check(ids.size()==3,"three real source-granted physical instances have exact reward receipts")
	if ids.size()!=3:world.queue_free();quit(1);return
	var item: Dictionary = world.item_instances[ids[0]]
	var name_value: String = str(item.name)
	check(item.record.source_original_item==original.source_item,"consumer receives the complete exact original ItemClass row")
	var amount: int = int(world.growth.source523.recharge(item).get("amount",0))
	check(amount==1000,"production source consumer resolves the original1000-point charge")
	var path: String = world.save_path()
	var claims: Dictionary = world.quest_service.claimed.duplicate(true)
	var quickslots: Array = world.quickslots.duplicate(true)
	var unrelated: Dictionary = other_items(world,name_value)
	var gold: int = world.gold
	var points: int = int(world.growth.state.points)
	var before_inventory: Dictionary = world.inventory.duplicate(true)
	var before_physical: Dictionary = world.item_instances.duplicate(true)
	var before_growth: Dictionary = world.growth.state.duplicate(true)
	var before_hash: String = FileAccess.get_sha256(path)
	world.equipment_collections.test_save_writer=func(_path: String,_data: Dictionary)->Error:return ERR_FILE_CANT_WRITE
	world._on_inventory_item_activated(name_value+"@@@"+ids[0])
	check(world.inventory==before_inventory and world.item_instances==before_physical and world.growth.state==before_growth,"failed consume write preserves exact instances, quantity and effect")
	check(FileAccess.get_sha256(path)==before_hash and world.quest_service.claimed==claims,"failed consume write preserves save bytes and quest completion")
	world.equipment_collections.test_save_writer=Callable()
	world._on_inventory_item_activated(name_value+"@@@"+ids[0])
	check(int(world.growth.state.points)==points+amount and int(world.inventory[name_value])==2 and not world.item_instances.has(ids[0]),"inventory use consumes exactly its selected source instance and adds1000 points")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(disk.growth.points)==points+amount and int(disk.inventory[name_value])==2 and not disk.item_instances.has(ids[0]),"effect and exact source debit commit atomically")
	var once_hash: String = FileAccess.get_sha256(path)
	world._on_inventory_item_activated(name_value+"@@@"+ids[0])
	check(FileAccess.get_sha256(path)==once_hash and int(world.growth.state.points)==points+amount and owned(world).size()==2,"reusing a consumed physical reference cannot consume another item by name")
	check(other_items(world,name_value)==unrelated and world.quickslots==quickslots and world.gold==gold and world.quest_service.claimed==claims,"other original rewards,50 quickslots, currency and completion remain intact")
	world.queue_free();await process_frame
	world=make_world()
	check(int(world.growth.state.points)==points+amount and int(world.inventory[name_value])==2 and owned(world).size()==2,"new Main instance restores one committed effect and two exact remaining rewards")
	world.equipment_collections.test_save_writer=func(target: String,data: Dictionary)->Error:
		var result: Error=WRITER.write(target,data)
		return ERR_FILE_CANT_WRITE if result==OK else result
	world._on_inventory_item_activated(name_value+"@@@"+ids[1])
	disk=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(disk.growth.points)==points+2*amount and int(disk.inventory[name_value])==1 and not disk.item_instances.has(ids[1]),"post-write error exposes the committed effect and debit on disk")
	var committed_hash: String=FileAccess.get_sha256(path)
	world._on_inventory_item_activated(name_value+"@@@"+ids[1])
	check(FileAccess.get_sha256(path)==committed_hash,"retry before recovery cannot apply a second effect to the same saved source item")
	world.equipment_collections.test_save_writer=Callable()
	world._load_game(true)
	check(int(world.growth.state.points)==points+2*amount and int(world.inventory[name_value])==1 and owned(world).size()==1,"valid reload recovers committed consumption after a writer-error result")
	check(not world.quest_auto.complete(world,[QUEST]),"consuming a quest reward never makes its completed quest payable again")
	world._on_inventory_item_activated(name_value+"@@@"+ids[2])
	check(int(world.growth.state.points)==points+3*amount and int(world.inventory.get(name_value,0))==0 and owned(world).is_empty(),"all three source-granted items each apply exactly one original charge")
	var exhausted_hash: String=FileAccess.get_sha256(path)
	world._on_inventory_item_activated(name_value+"@@@"+ids[2])
	check(FileAccess.get_sha256(path)==exhausted_hash,"exhausted source rewards cannot be reused")
	check(other_items(world,name_value)==unrelated and world.quickslots==quickslots and world.gold==gold and world.quest_service.claimed==claims,"failure recovery and full use preserve unrelated rewards and all original claims")
	world.queue_free();await process_frame
	world=make_world()
	check(int(world.growth.state.points)==points+3*amount and owned(world).is_empty() and world.quest_service.claimed==claims,"final process reconstruction keeps all effects and never recreates consumed source rewards")
	check(other_items(world,name_value)==unrelated and world.quickslots==quickslots and world.gold==gold,"final reconstruction preserves original inventory, currency and quickslots")
	print("QUEST_ITEM_USE_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"quest":QUEST,"reward_id":REWARD,"item_class_id":ITEM,"source_quantity":3,"charge_per_item":amount,"total_charge":3*amount,"input_save_sha256":expected,"final_save_sha256":FileAccess.get_sha256(path),"original_conditions_waived":false,"external_pr_consumers_installed":false}))
	world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
