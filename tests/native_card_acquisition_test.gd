extends SceneTree
const Acquire=preload("res://scripts/cards/native_card_acquisition.gd")
const Items=preload("res://scripts/cards/source_awakening_items.gd")
const Fixture=preload("res://tests/native_relic_reward_box_test.gd")
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Registry=preload("res://scripts/lineagem_base508.gd")
var checks: int=0
var errors: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func run() -> void:
	check(Acquire.rules_valid() and Acquire.time_available(),"reviewed sole deterministic output and current source period")
	check(not Acquire.time_available(0),"outside source calendar is unavailable")
	var coin: Dictionary=Acquire.record(Acquire.COIN)
	check(not Acquire.prepare_craft({"마법인형 제작 코인":3000000},{},1).ok,"generic existing coin stacks never become exact source currency")
	var pickup: Dictionary=Items.prepare_pickup({"item_name":coin.name,"item_record":coin,"quantity":3000001},{"future":{"name":"future","value":{"keep":true}}},1)
	check(pickup.created==3000001 and pickup.item_instances.size()==2,"three million source coins use one physical quantity stack")
	var id: String="1";var bag: Dictionary={coin.name:3000001,"마법인형 제작 코인":42}
	check(Acquire.available_coins(bag,pickup.item_instances)==3000001,"only exact source physical quantity is available")
	check(Acquire.available_coins(bag,pickup.item_instances,{id:true})==0,"physical source currency lock respected")
	check(not Acquire.prepare_craft(bag,pickup.item_instances,pickup.next_item_instance_id,{id:true}).ok,"locked source currency cannot be consumed")
	var before: int=hash([bag,pickup.item_instances])
	var staged: Dictionary=Acquire.prepare_craft(bag,pickup.item_instances,pickup.next_item_instance_id)
	check(staged.ok and staged.consumed_source_coins==3000000 and hash([bag,pickup.item_instances])==before,"pure staged exact source debit without mutation")
	check(staged.inventory[coin.name]==1 and staged.item_instances[id][Acquire.QUANTITY]==1 and staged.inventory["마법인형 제작 코인"]==42,"partial source stack and unrelated old currency preserved")
	check(staged.item_instances.future==pickup.item_instances.future and staged.item_instances[staged.ticket_instance_id].record.source_item_class_id==370562,"future metadata and source result identity retained")
	var host=Fixture.Host.new();root.add_child(host);host.catalog_db=Registry.apply_catalog({});host.card_draw_fusion.configure(host.catalog_db)
	host.inventory=bag.duplicate(true);host.item_instances=pickup.item_instances.duplicate(true);host.next_item_instance_id=pickup.next_item_instance_id
	var runtime=Runtime.new();check(runtime.configure(host),"runtime configures")
	host.save_error=ERR_FILE_CANT_WRITE;before=hash([host.inventory,host.item_instances,host.next_item_instance_id,host.card_draw_fusion.export_state(),host.rng.state])
	check(runtime.craft_nemesis().code=="save_failed" and hash([host.inventory,host.item_instances,host.next_item_instance_id,host.card_draw_fusion.export_state(),host.rng.state])==before,"failed craft preserves source currency, result, cards, IDs and RNG")
	host.save_error=OK;var crafted: Dictionary=runtime.craft_nemesis()
	check(crafted.ok and not host.card_draw_fusion.owned["마법인형"].has(Acquire.CARD),"craft gives one physical ticket without auto-using it")
	check(host.saved.inventory==host.inventory and host.saved.item_instances==host.item_instances and host.saved.next_item_instance_id==host.next_item_instance_id,"craft debit and ticket share durable writer snapshot")
	var name_value: String=str(Acquire.record().name)
	check(not runtime.use_nemesis_ticket(name_value,"missing").ok,"wrong selected ticket cannot consume another copy")
	host.save_error=ERR_FILE_CANT_WRITE;before=hash([host.inventory,host.item_instances,host.card_draw_fusion.export_state(),host.rng.state])
	check(runtime.use_nemesis_ticket(name_value,crafted.ticket_instance_id).code=="save_failed" and hash([host.inventory,host.item_instances,host.card_draw_fusion.export_state(),host.rng.state])==before,"failed ticket use leaves all state and RNG unchanged")
	host.save_error=OK;check(runtime.use_nemesis_ticket(name_value,crafted.ticket_instance_id).ok and host.card_draw_fusion.owned["마법인형"][Acquire.CARD],"exact ticket atomically grants permanent new card")
	check(host.saved.card_draw_fusion==host.card_draw_fusion.export_state() and not host.item_instances.has(crafted.ticket_instance_id),"ticket debit and card ownership share one durable snapshot")
	check(not runtime.use_nemesis_ticket(name_value,crafted.ticket_instance_id).ok,"replayed ticket reference cannot duplicate reward")
	var extra: Dictionary=Items.prepare_pickup({"item_name":name_value,"item_record":Acquire.record(),"quantity":1},host.item_instances,host.next_item_instance_id)
	host.inventory[name_value]=1;host.item_instances=extra.item_instances;host.next_item_instance_id=extra.next_item_instance_id
	check(runtime.use_nemesis_ticket(name_value).ok and host.card_draw_fusion.spare["마법인형"][Acquire.CARD]==1,"second independently acquired ticket becomes one duplicate")
	host.queue_free();await process_frame
	print("NATIVE_CARD_ACQUISITION ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
