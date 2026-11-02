extends SceneTree
const Item=preload("res://scripts/cards/native_doll_unlock_item.gd")
const Runtime=preload("res://scripts/cards/option_awakening_runtime.gd")
const Subslot=preload("res://scripts/cards/native_doll_subslot.gd")
const Fixture=preload("res://tests/native_option_awakening_test.gd")
class Host extends Fixture.Host:
	var inventory: Dictionary={}
	var item_instances: Dictionary={}
	var level: int=95
	var active_skill_buffs: Dictionary={}
	var option_awakening
	var hud_updates: int=0
	func _update_hud() -> void:hud_updates+=1
class Messages extends Node:
	var message: String=""
	var refreshes: int=0
	func show_message(value: String) -> void:message=value
	func refresh_inventory(_inventory: Dictionary) -> void:refreshes+=1
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-cards="):path=arg.trim_prefix("--native-cards=")
	if path.is_empty():quit(2);return
	check(Item.source_rules_valid(),"exact consumable ItemBonus BuffClass permanent unlock source chain")
	var host=Host.new();root.add_child(host);host.catalog_db=JSON.parse_string(FileAccess.get_file_as_string(path)).catalog;host.card_draw_fusion.configure(host.catalog_db)
	check(Item.install(host.catalog_db).ok,"install source item definition without ownership grant")
	var count: int=host.catalog_db["아이템"].size();check(Item.install(host.catalog_db).ok and host.catalog_db["아이템"].size()==count,"catalog idempotency")
	var collision: Dictionary={"아이템":[{"name":Item.record().name,"sourceId":"346901"}]}
	check(not Item.install(collision).ok and collision["아이템"].size()==1,"same name or integer ID never becomes source alias")
	var service=Runtime.new();check(service.configure(host),"configure")
	var name_value: String=Item.record().name
	host.inventory[name_value]=1
	check(service.use_native_unlock_item(name_value).code=="source_ownership","name-only stack not accepted")
	host.item_instances["unverified"]={"name":name_value,"record":{"sourceId":"346901"}}
	check(service.use_native_unlock_item(name_value).code=="source_ownership","numeric physical ID not accepted")
	host.item_instances["verified"]={"name":name_value,"record":Item.record()}
	host.level=94;check(service.use_native_unlock_item(name_value).code=="level","no early unlock")
	host.level=95;host.save_error=ERR_FILE_CANT_WRITE
	var before: int=hash([service.export_state(),host.inventory,host.item_instances,host.gold,str(service.rng.state),str(host.rng.state)])
	check(service.use_native_unlock_item(name_value).code=="save_failed","writer failure reported")
	check(hash([service.export_state(),host.inventory,host.item_instances,host.gold,str(service.rng.state),str(host.rng.state)])==before,"write failure preserves every item ledger currency and RNG")
	host.save_error=OK;var money: int=host.gold;var rng_text: String=str(service.rng.state)
	var result: Dictionary=service.use_native_unlock_item(name_value)
	check(result.ok and result.consumed_quantity==1 and result.consumed_instance_id=="verified","use consumes one exact owned physical item")
	check(host.inventory.is_empty() and not host.item_instances.has("verified") and host.item_instances.has("unverified"),"unrelated physical source variant never consumed")
	check(Item.unlocked(service.export_state()) and Subslot.unlocked(95,{},service.export_state()),"permanent source unlock activates without expiring buff")
	check(host.gold==money and str(service.rng.state)==rng_text,"no invented fee or RNG change")
	var stored: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(host.save_path()))
	check(stored.inventory.is_empty() and Item.unlocked(stored.card_option_awakening),"durable save includes debit and unlock together")
	var restored=Runtime.new();check(restored.configure(host) and restored.accept_load(stored) and restored.subslot_view().unlocked,"reconnect restores source unlock")
	host.inventory[name_value]=1;host.item_instances["second"]={"name":name_value,"record":Item.record()}
	before=hash([host.inventory,host.item_instances,service.export_state()]);result=service.use_native_unlock_item(name_value)
	check(result.code=="already_unlocked" and before==hash([host.inventory,host.item_instances,service.export_state()]),"double use preserves second book")
	service._busy=true;check(service.use_native_unlock_item(name_value).code=="busy","reentrant use rejected");service._busy=false
	var corrupt: Dictionary=service.export_state();corrupt[Item.FIELD].source_item_class_id=1
	check(not service.core.validate_state(corrupt).is_empty(),"invalid unlock source chain rejected on load")
	check(not service.use_native_unlock_item("unrelated potion").handled,"other consumable routing unchanged")
	var route=Host.new();root.add_child(route);route.catalog_db=host.catalog_db;route.card_draw_fusion.configure(route.catalog_db)
	route.option_awakening=Runtime.new();route.option_awakening.configure(route)
	route.hud=Messages.new();route.add_child(route.hud)
	route.inventory[name_value]=1;route.item_instances["route"]={"name":name_value,"record":Item.record()}
	var consumer=preload("res://scripts/consumable_service.gd").new();route.add_child(consumer);consumer.setup(route)
	check(consumer.try_use(name_value) and Item.unlocked(route.option_awakening.progress) and route.inventory.is_empty(),"production consumable entry uses native atomic transaction")
	check(route.hud_updates==1 and route.hud.refreshes==1 and route.hud.message.contains("해금"),"successful source use publishes committed result once")
	check(not consumer.try_use("unrelated unknown item"),"unrelated consumable lookup unchanged")
	route.queue_free();host.queue_free();await process_frame
	print("NATIVE_DOLL_UNLOCK_ITEM ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
