extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Exact source supply and quest receipts. Existing name-only balances stay unproven.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
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
	return {"original_item":raw,"source_definition_archive":ORIGINAL.identity()}
static func record(id: int) -> Dictionary:
	var row: Dictionary=definition(id);var raw: Dictionary=row.get("original_item",{})
	if raw.is_empty():return {}
	var category: Dictionary=ORIGINAL.row("ItemCategory",int(raw.get("CategoryID",0)))
	var grade: Dictionary=ORIGINAL.row("Grade",int(raw.get("GradeID",0)))
	if category.is_empty() or grade.is_empty():return {}
	var text: Dictionary=ORIGINAL.row("DescData_Korean",int(raw.get("DescID",0)))
	var label: String=str(text.get("Description",raw.get("Name","")))
	if label.is_empty():return {}
	# This is an actually source-derived supplier definition, not an assertion
	# that a sidecar-native/use/equipment implementation exists for this item.
	return {"name":label+" · 원본#"+str(id),"source":"lineagem_patch523","source_snapshot":"patch523","source_item_class_id":id,"sourceId":"m523:item:"+str(id),"source_item":raw.duplicate(true),"source_definition_archive":row.source_definition_archive.duplicate(true),"source_current523_awakening_supply":true,"source_bless_raw":1,"source_enchant":0,"type":"소모품" if category.get("IsConsumable")==true else "재료","slot":"consumable" if category.get("IsConsumable")==true else "material","grade":str(grade.get("Name","")),"source_grade_id":int(raw.GradeID),"stackable":true,"source_image_status":"original_icon_not_installed"}
static func exact(value: Dictionary,id: int) -> bool:
	var expected: Dictionary=record(id)
	if expected.is_empty() or value.get("source_pending_use",false):return false
	for field: String in expected:
		if value.get(field)!=expected[field]:return false
	return true
static func _issued_v1_exact(value: Dictionary,id: int) -> bool:
	# Historical issuance proof only. Current source is mandatory and its full
	# row must agree; old files never supply final definitions or use effects.
	var current: Dictionary=definition(id).get("original_item",{})
	var issued: Dictionary=D.issued_definition_for_reference(str(id))
	if current.is_empty() or issued.get("original_item")!=current:return false
	var expected: Dictionary=D.variant_item(issued.get("native_record",{}),1)
	if expected.is_empty() or value.get("source_m_native_item")!=true:return false
	for field: String in expected:
		if value.get(field)!=expected[field]:return false
	return true
static func key(value: Dictionary) -> String:
	if value.get("source_current523_awakening_supply")==true:return str(value.get("name",""))
	var wallet: String=D.currency_identity_name(value)
	return str(value.get("name","")) if wallet.is_empty() else wallet
static func stage_grant(value: Dictionary,quantity: int,instances: Dictionary,origin: Dictionary) -> Dictionary:
	var id: int=int(value.get("source_item_class_id",0))
	if quantity<1 or not integer(quantity) or not exact(value,id) or origin.is_empty():return {"ok":false}
	var next: Dictionary=instances.duplicate(true)
	var uid: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while next.has(uid):uid=Crypto.new().generate_random_bytes(16).hex_encode()
	next[uid]={"name":key(value),"level":0,"record":value.duplicate(true),QUANTITY:quantity,"source_awakening_supply":{"schema":2,"item_class_id":id,"granted_quantity":quantity,"source_definition_archive":ORIGINAL.identity(),"origin":origin.duplicate(true)}}
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
	if original.is_empty() or entry.get("level",0)!=0 or entry.record.get("source_bless_raw",1)!=1 or entry.record.get("source_enchant",0)!=0:return {"ok":false}
	var stamp: Variant=entry.get("source_awakening_supply")
	if stamp is Dictionary:
		if entry.get("name","")!=key(entry.record) or not integer(entry.get(QUANTITY)) or int(entry[QUANTITY])<1 or stamp.get("item_class_id")!=item_id or not stamp.get("origin") is Dictionary or stamp.origin.is_empty():return {"ok":false}
		if stamp.get("schema")==2:
			if not integer(stamp.get("granted_quantity")) or int(stamp.granted_quantity)<int(entry[QUANTITY]) or stamp.get("source_definition_archive")!=ORIGINAL.identity() or not exact(entry.record,item_id):return {"ok":false}
		elif stamp.get("schema")==1:
			if stamp.get("pack_sha256")!=D.DATA_SHA or not _issued_v1_exact(entry.record,item_id):return {"ok":false}
		else:return {"ok":false}
		return {"ok":true,"receipt_kind":"source","physical_id":physical_id,"inventory_key":str(entry.name),"quantity":int(entry[QUANTITY]),"record":entry.record,"item_class_id":item_id}
	# Existing explicit m523 physical ownership retains its original provenance.
	# It cannot masquerade as a typed quantity record with a missing receipt.
	if entry.has(QUANTITY) or entry.has("quest_reward_receipt"):return {"ok":false}
	if entry.record.get("source")=="lineagem_patch523" and entry.record.get("source_snapshot")=="patch523" and entry.record.get("sourceId")=="m523:item:"+str(item_id) and entry.record.get("source_item_class_id")==item_id and entry.record.get("source_item",{})==original and entry.get("name")==entry.record.get("name") and not str(entry.get("name","")).is_empty():
		var amount: Variant=entry.get("source_card_currency_quantity",1)
		if not integer(amount) or int(amount)<1 or (item_id==3252 and not entry.has("source_card_currency_quantity")):return {"ok":false}
		return {"ok":true,"receipt_kind":"legacy","physical_id":physical_id,"inventory_key":str(entry.name),"quantity":int(amount),"record":entry.record,"item_class_id":item_id}
	return {"ok":false}
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
		step=CONSUMPTION.stage(world,requests,JSON.stringify({"source_definition_archive":ORIGINAL.identity(),"item":definition(item_id).get("original_item",{}),"consumer":"native_awakening_supply_selected_debit_v2"}).sha256_text())
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

static func install_current_definitions(catalog: Dictionary) -> Dictionary:
	if not catalog.get("아이템",[]) is Array:return {"ok":false,"error":"item_catalog"}
	var records: Array=catalog.get("아이템",[]);var pending: Array=[]
	for id: int in IDS:
		var current: Dictionary=record(id)
		if current.is_empty():pending.append({"item_class_id":id,"reason":"current_source_definition_unavailable"});continue
		var positions: Array=[]
		for index: int in range(records.size()):
			if records[index] is Dictionary and records[index].get("sourceId")==current.sourceId:positions.append(index)
		if positions.size()>1:pending.append({"item_class_id":id,"reason":"ambiguous_registered_source_id"});continue
		if positions.size()==1:
			var previous: Dictionary=records[int(positions[0])]
			if exact(previous,id):continue
			var same_original: bool=previous.get("source_item")==current.source_item and previous.get("source_definition_archive")==ORIGINAL.identity() and previous.get("source_snapshot")=="patch523" and previous.get("source")=="lineagem_patch523"
			var current_projection: bool=previous.get("source_projection")=="current523_original_typed_game_dto_v1" and NATIVE_FIELDS.full(previous).get("source_original_item")==current.source_item and previous.get("source_definition_archive")==ORIGINAL.identity()
			if not same_original and not current_projection and not _issued_v1_exact(previous,id):pending.append({"item_class_id":id,"reason":"unverified_registered_prototype_preserved"});continue
			# Preserve the former definition for provenance only; no owned record,
			# inventory key, quantity or receipt is rewritten here.
			if not catalog.has("_preserved_awakening_supply_definitions"):catalog["_preserved_awakening_supply_definitions"]={}
			if not catalog._preserved_awakening_supply_definitions.has(current.sourceId):catalog._preserved_awakening_supply_definitions[current.sourceId]=previous.duplicate(true)
			records[int(positions[0])]=current
		else:
			var alias: bool=false
			for previous: Dictionary in records:
				if previous.get("name")==current.name:alias=true
			if alias:pending.append({"item_class_id":id,"reason":"same_name_unproven_identity_preserved"});continue
			records.append(current)
	catalog["아이템"]=records
	return {"ok":true,"source_definition_archive":ORIGINAL.identity(),"pending":pending,"ownership_changed":false}
