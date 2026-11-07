extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## New confirmed source-book rewards -> the existing exact native supplier.
## Existing source-qualified stacks are never converted, renamed or regranted.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const Use=preload("res://scripts/loot/patch523_item_use.gd")
const Supply=preload("res://scripts/cards/native_awakening_supply.gd")
const Same=preload("res://scripts/equipment523/native_catalog.gd")
const Dummy=preload("res://scripts/quests/source_dummy523.gd")
const FIELD="source_monsterbook_grants"

static func target(runtime: RefCounted,world: Node,reward: Dictionary) -> Dictionary:
	if not runtime.items.reward_problem(reward).is_empty() or int(reward.get("RewardTypeID",0))!=2:return {}
	if D.pack_identity().get("sha256")!=D.DATA_SHA:return {}
	var id: int=int(reward.RewardClassID)
	var original: Dictionary=runtime.catalog.row("ItemClass",id)
	var definition: Dictionary=D.definition_id(str(id))
	if not Same.same(original,definition.get("original_item")) or original.get("TestItem")!=false or not Dummy.item_evidence(original).is_empty():return {}
	var record: Dictionary=D.variant_item(definition.get("native_record",{}),1)
	if record.is_empty() or D.equipment(record) or not D.matches(world._catalog_item_from_source_id(str(record.get("sourceId",""))),record):return {}
	if not D.deadline_problem(record,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540))).is_empty():return {}
	var kind: String=""
	if D.currency_identity_name(record)=="아데나":kind="source_gold"
	elif id in Supply.IDS and Supply.exact(record,id):kind="typed_card_supply"
	else:
		var action: Dictionary=Use.action_record(world,record)
		var spec: Dictionary=NATIVE_FIELDS.full(action).get("source_use_spec",{})
		if spec.get("activation_status")=="unrestricted" and spec.get("kind") in ["source_timed_buff","source_mp_dice","guaranteed_bag","source_weighted_bag","mixed_rewards_bag"]:kind=str(spec.kind)
		elif not action.get("heal_spec",{}).is_empty():kind="source_hp_potion"
	if kind.is_empty():return {}
	var wallet: String=D.currency_identity_name(record)
	if wallet!="아데나" and (not runtime.catalog._integer(original.get("MaxStackAmount")) or int(original.MaxStackAmount)<1 or record.get("source_is_stackable")!=true):return {}
	return {"record":record,"inventory_key":wallet if not wallet.is_empty() else str(record.name),"consumer_kind":kind,"max_stack":int(original.get("MaxStackAmount",0))}

static func stage(runtime: RefCounted,world: Node,proposed: Dictionary,quote: Dictionary,rewards: Array) -> Dictionary:
	if rewards.is_empty():return {"ok":true,"overrides":{}}
	var book_id: int=int(quote.get("book_id",0))
	var epoch: String=str(quote.get("epoch",""))
	var level_id: int=int(quote.get("level",{}).get("ID",0))
	var sequence: int=int(proposed.get("books",{}).get(str(book_id),{}).get("sequence",0))
	if book_id<1 or epoch.is_empty() or level_id<1 or sequence<1 or not runtime.catalog._busy:return {"ok":false}
	var uid: String="%d:%s:%d:%d"%[book_id,epoch,level_id,sequence]
	var consumables: Dictionary=world.consumable_service.export_state()
	var ledger: Variant=consumables.get(FIELD,{})
	if not ledger is Dictionary or ledger.has(uid):return {"ok":false}
	var grants: Array=[];var outputs: Array=[];var rows: Array=[]
	for reward: Dictionary in rewards:
		var destination: Dictionary=target(runtime,world,reward)
		if destination.is_empty() or not runtime.catalog._integer(reward.get("Amount")) or int(reward.Amount)<1:return {"ok":false}
		grants.append({"item_class_id":int(reward.RewardClassID),"amount":int(reward.Amount),"bless_raw":1,"enchant":0})
		outputs.append({"reward_id":int(reward.ID),"item_class_id":int(reward.RewardClassID),"amount":int(reward.Amount),"bless_raw":1,"enchant":0,"inventory_key":str(destination.inventory_key),"consumer_kind":str(destination.consumer_kind)})
		rows.append(reward.duplicate(true))
	var origin: Dictionary={"kind":"monsterbook523_confirmed_reward","source_snapshot":"patch523","source_archive_sha256":runtime.catalog.SOURCE_SHA,"source_model_sha256":runtime.catalog.pack_sha,"book_id":book_id,"epoch":epoch,"level_id":level_id,"sequence":sequence,"receipt_id":uid,"reward_rows":rows}
	var supplied: Dictionary=world.stage_source_item_grants(grants,origin)
	if not supplied.get("ok",false):return supplied
	for reward: Dictionary in rewards:
		var destination: Dictionary=target(runtime,world,reward)
		if destination.inventory_key!="아데나" and int(supplied.overrides.inventory.get(str(destination.inventory_key),0))>int(destination.max_stack):return {"ok":false,"error":"원본 도감 보상의 실제 지급 스택 한도 초과"}
	var physical_ids: Array=[]
	for id: String in supplied.overrides.item_instances:
		if not world.item_instances.has(id):physical_ids.append(id)
	var receipt: Dictionary={"schema":1,"origin":origin,"item_pack_sha256":D.DATA_SHA,"outputs":outputs,"physical_ids":physical_ids}
	ledger=ledger.duplicate(true);ledger[uid]=receipt;consumables[FIELD]=ledger
	supplied.overrides["consumable_state"]=consumables
	return supplied
