extends SceneTree
const Item=preload("res://scripts/cards/native_relic_unlock_item.gd")
const Slot=preload("res://scripts/cards/native_relic_subslot.gd")
var checks: int=0
var errors: Array[String]=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:errors.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(Item.source_rules_valid(),"exact consumable item BuffClass infinite duration SaveDB HolyStuffSubSlotOpened chain")
	var catalog: Dictionary={"아이템":[]}
	check(Item.install(catalog).ok and catalog["아이템"].size()==1 and Item.install(catalog).existing,"catalog installation idempotent without granting inventory")
	check(not Item.install({"아이템":[{"name":Item.record().name}]}).ok,"same-name item never aliased")
	var state: Dictionary={"revision":0,"cards":{"성물":{}},"native_doll_unlock":{"preserved":true}}
	var name_value: String=str(Item.record().name);var bag: Dictionary={name_value:1};var instances: Dictionary={}
	check(Item.prepare(state,bag,instances,96).code=="source_ownership","name-only count cannot consume or unlock")
	instances["unverified"]={"name":name_value,"record":{"sourceId":"365748"}}
	check(Item.prepare(state,bag,instances,96).code=="source_ownership","untyped numeric sourceId cannot unlock")
	instances["verified"]={"name":name_value,"record":Item.record()}
	check(Item.prepare(state,bag,instances,96).code=="source_ownership_count","mismatched physical inventory count rejected")
	bag[name_value]=2
	var original: int=hash([state,bag,instances])
	var prepared: Dictionary=Item.prepare(state,bag,instances,1)
	check(prepared.ok and prepared.consumed_quantity==1 and prepared.consumed_instance_id=="verified","only exact item is prepared for debit without inferred96 use gate")
	check(original==hash([state,bag,instances]),"prepare never mutates live ledgers before durable transaction")
	check(prepared.inventory[name_value]==1 and prepared.item_instances.has("unverified") and not prepared.item_instances.has("verified"),"unrelated physical source variant preserved")
	check(Item.unlocked(prepared.state) and Slot.unlocked(1,{},prepared.state),"permanent relic unlock marker activates independently of doll state")
	check(prepared.state.native_doll_unlock==state.native_doll_unlock,"existing doll unlock bytes preserved")
	var locked: Dictionary={name_value+"@@@verified":true}
	check(Item.prepare(state,bag,instances,96,locked).code=="item_locked" and original==hash([state,bag,instances]),"locked verified physical item preserved")
	var with_second: Dictionary=instances.duplicate(true);with_second["second"]={"name":name_value,"record":Item.record()}
	var with_bag: Dictionary={name_value:3}
	var alternate: Dictionary=Item.prepare(state,with_bag,with_second,96,locked)
	check(alternate.ok and alternate.consumed_instance_id=="second" and alternate.item_instances.has("verified"),"selection skips locked physical and preserves it while using unlocked item")
	check(Item.prepare(state,bag,instances,96,{"verified":true}).code=="item_locked","normalized physical lock IDs recognized")
	check(Item.prepare(prepared.state,prepared.inventory,prepared.item_instances,96).code=="already_unlocked","double use rejects before any further debit")
	var corrupt: Dictionary=prepared.state.duplicate(true);corrupt[Item.FIELD].source_buff_class_id=91531
	check(not Item.validate(corrupt).is_empty() and not Item.unlocked(corrupt),"doll buff cannot impersonate relic unlock")
	corrupt=prepared.state.duplicate(true);corrupt[Item.FIELD].source_snapshot="base508"
	check(not Item.validate(corrupt).is_empty(),"wrong snapshot marker rejected")
	bag[name_value]=1.5
	check(Item.prepare(state,bag,instances,96).code=="quantity","nonintegral inventory count rejected")
	print("NATIVE_RELIC_UNLOCK_ITEM ",JSON.stringify({"checks":checks,"errors":errors}));quit(0 if errors.is_empty() else 1)
