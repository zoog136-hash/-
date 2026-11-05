extends RefCounted
## Exact source supply and quest receipts. Existing name-only balances stay unproven.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const SLOT_DATA=preload("res://scripts/cards/patch523_slot_data.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const CONSUMPTION=preload("res://scripts/quests/quest_reward_consumption.gd")
const ORIGINAL=preload("res://scripts/resources/current523_definition_rows.gd")
const IDS=[3252,370562,346921,365748,365758,75184,75194,95624,118992,243043]
const QUANTITY="source_awakening_quantity"
static func integer(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=0 and float(value)<=9007199254740991
static func definition(id: int) -> Dictionary:
	if id not in IDS or ORIGINAL.identity().is_empty():return {}
	var raw: Dictionary=ORIGINAL.row("ItemClass",id)
	if raw.get("TestItem")!=false or not ORIGINAL.declared_exclusion("ItemClass",raw).is_empty():return {}
	# Preserve an issued native representation only if its entire original row
	# matches the new source. It supplies ownership shape, never use semantics.
	var issued: Dictionary=D.definition_id(str(id))
	var native_record: Dictionary=issued.get("native_record",{}) if issued.get("original_item")==raw else {}
	return {"original_item":raw,"native_record":native_record,"source_definition_archive":ORIGINAL.identity()}
static func record(id: int) -> Dictionary:
	var row: Dictionary=definition(id)
	return D.variant_item(row.get("native_record",{}),1) if not row.get("original_item",{}).get("TestItem",true) else {}
static func exact(value: Dictionary,id: int) -> bool:
	var expected: Dictionary=record(id)
	if expected.is_empty() or not value.get("source_m_native_item",false) or value.get("source_item_class_id",0)!=id or value.get("source_snapshot","")!="patch523" or value.get("source_bless_raw",1)!=1:return false
	for field: String in expected:
		if value.get(field)!=expected[field]:return false
	return true
static func key(value: Dictionary) -> String:
	var wallet: String=D.currency_identity_name(value)
	return str(value.get("name","")) if wallet.is_empty() else wallet
static func stage_grant(value: Dictionary,quantity: int,instances: Dictionary,origin: Dictionary) -> Dictionary:
	var id: int=int(value.get("source_item_class_id",0))
	if quantity<1 or not integer(quantity) or not exact(value,id) or origin.is_empty():return {"ok":false}
	var next: Dictionary=instances.duplicate(true)
	var uid: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while next.has(uid):uid=Crypto.new().generate_random_bytes(16).hex_encode()
	next[uid]={"name":key(value),"level":0,"record":value.duplicate(true),QUANTITY:quantity,"source_awakening_supply":{"schema":1,"item_class_id":id,"pack_sha256":D.DATA_SHA,"origin":origin.duplicate(true)}}
	return {"ok":true,"item_instances":next,"id":uid}
static func prepare_pickup(drop: Dictionary,instances: Dictionary,next_id: int) -> Dictionary:
	var unchanged: Dictionary={"item_instances":instances,"next_item_instance_id":next_id,"created":0}
	if drop.has("physical_item") or not drop.get("item_record") is Dictionary:return unchanged
	var value: Dictionary=drop.item_record;var id: int=int(value.get("source_item_class_id",0))
	var proof: Dictionary=value.get("source_m_drop_proof",{})
	if not exact(value,id) or drop.get("item_name","")!=value.get("name") or not integer(drop.get("quantity")) or int(drop.quantity)<1 or int(proof.get("source_item_class_id",0))!=id or int(proof.get("bless_raw",0))!=1 or int(proof.get("required_quest_id",-1))!=0:return unchanged
	var staged: Dictionary=stage_grant(value,int(drop.quantity),instances,{"kind":"source523_floor","drop":proof.duplicate(true)})
	if not staged.ok:return unchanged
	return {"item_instances":staged.item_instances,"next_item_instance_id":next_id,"created":int(drop.quantity)}
static func proof(world: Node,physical_id: String,item_id: int) -> Dictionary:
	var entry: Variant=world.item_instances.get(physical_id)
	if not entry is Dictionary or not entry.get("record") is Dictionary:return {"ok":false}
	if entry.record.get("source_pending_use",false):
		if world.get("quest_service")==null:return {"ok":false}
		var owned: Dictionary=OWN.proof(world,physical_id)
		if not owned.get("ok",false) or int(owned.item_class_id)!=item_id or int(owned.bless_code_id)!=1 or owned.source_use_immediately or owned.source_item!=definition(item_id).get("original_item",{}):return {"ok":false}
		owned["receipt_kind"]="quest";return owned
	var original: Dictionary=definition(item_id).get("original_item",{})
	if not original.is_empty() and entry.record.get("source")=="lineagem_patch523" and entry.record.get("source_snapshot")=="patch523" and entry.record.get("sourceId")=="m523:item:"+str(item_id) and entry.record.get("source_item_class_id")==item_id and entry.record.get("source_item",{})==original and entry.get("name")==entry.record.get("name") and not str(entry.get("name","")).is_empty():
		var amount: Variant=entry.get("source_card_currency_quantity",1)
		if not integer(amount) or int(amount)<1 or (item_id==3252 and not entry.has("source_card_currency_quantity")):return {"ok":false}
		return {"ok":true,"receipt_kind":"legacy","physical_id":physical_id,"inventory_key":str(entry.name),"quantity":int(amount),"record":entry.record,"item_class_id":item_id}
	if not exact(entry.record,item_id) or entry.get("name","")!=key(entry.record) or not integer(entry.get(QUANTITY)) or int(entry[QUANTITY])<1:return {"ok":false}
	var stamp: Variant=entry.get("source_awakening_supply")
	if not stamp is Dictionary or stamp.get("schema")!=1 or stamp.get("item_class_id")!=item_id or stamp.get("pack_sha256")!=D.DATA_SHA or not stamp.get("origin") is Dictionary or stamp.origin.is_empty():return {"ok":false}
	return {"ok":true,"receipt_kind":"source","physical_id":physical_id,"inventory_key":str(entry.name),"quantity":int(entry[QUANTITY]),"record":entry.record,"item_class_id":item_id}
static func available(world: Node,item_id: int) -> int:
	var total: int=0
	var names: Dictionary={}
	for uid: String in world.item_instances:
		var owned: Dictionary=proof(world,uid,item_id)
		if not owned.get("ok",false):continue
		var name_value: String=str(owned.inventory_key)
		names[name_value]=int(names.get(name_value,0))+int(owned.quantity)
		if not world._item_locked(name_value,uid) and not world._item_locked(name_value):total+=int(owned.quantity)
	for name_value: String in names:
		if not integer(world.inventory.get(name_value)) or int(world.inventory.get(name_value,0))<int(names[name_value]):return 0
	return total
static func prepare_debit(world: Node,item_id: int,quantity: int=1,selected: String="") -> Dictionary:
	var denied: Dictionary={"ok":false,"error":"검증된 원본 지급·소지 수량 필요 · 기존 아이템 보존"}
	if item_id not in IDS or quantity<1 or not integer(quantity) or available(world,item_id)<quantity:return denied
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	var remaining: int=quantity;var consumed: Array[Dictionary]=[];var requests: Array=[]
	for uid: String in world.item_instances:
		if not selected.is_empty() and selected!=uid:continue
		var owned: Dictionary=proof(world,uid,item_id)
		if not owned.get("ok",false):continue
		var name_value: String=str(owned.inventory_key)
		if world._item_locked(name_value,uid) or world._item_locked(name_value):continue
		var amount: int=mini(remaining,int(owned.quantity));var rest: int=int(owned.quantity)-amount
		if owned.receipt_kind=="quest":
			# Reuse the public batch debit rather than replacing a first-use pack
			# receipt with this owner's digest after another valid consumer used a
			# partial quantity. Original grants and old saves are never converted.
			requests.append({"physical_id":uid,"quantity":amount,"expected_quantity":int(owned.quantity),"expected_remaining":rest,"quest_reward_receipt":world.item_instances[uid].quest_reward_receipt.duplicate(true)})
			if rest==0:instances.erase(uid)
			else:instances[uid].source_reward_quantity=rest
		else:
			if rest==0:instances.erase(uid)
			else:instances[uid]["source_card_currency_quantity" if owned.receipt_kind=="legacy" else QUANTITY]=rest
		inventory[name_value]=int(inventory[name_value])-amount
		if int(inventory[name_value])==0:inventory.erase(name_value)
		consumed.append({"item_class_id":item_id,"quantity":amount,"physical_id":uid,"origin":owned.receipt_kind})
		remaining-=amount
		if remaining==0:break
	if remaining!=0:return denied
	var overrides: Dictionary={"inventory":inventory,"item_instances":instances}
	var step: Dictionary={}
	if not requests.is_empty():
		step=CONSUMPTION.stage(world,requests,D.DATA_SHA)
		if not step.get("ok",false):return denied
		# Only take the journal from this candidate. Its full inventory and
		# instances do not include the independently staged non-quest inputs.
		overrides["quest_state"]=step.overrides.quest_state
		if not CONSUMPTION.matches_payload(world,step,overrides):return denied
	return {"ok":true,"overrides":overrides,"consumed":consumed,"quest_step":step}

static func matches_payload(world: Node,paid: Dictionary,payload: Dictionary) -> bool:
	if not paid.get("ok",false):return false
	var step: Variant=paid.get("quest_step",{})
	if not step is Dictionary:return false
	return step.is_empty() or CONSUMPTION.matches_payload(world,step,payload)
static func publish(world: Node,overrides: Dictionary) -> void:
	world.inventory=overrides.inventory;world.item_instances=overrides.item_instances
	if overrides.has("quest_state"):world.quest_service.import_state(overrides.quest_state)
