extends RefCounted
## Existing HP/MP effects with exact current-source physical quantity ownership.
## No name-only conversion, reference effect activation, or live trial grant.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const QUANTITY="source_native_stack_quantity"
const RECEIPT="source_native_stack_receipt"
const USES="source_native_stack_uses"
const PARTITIONS="source_native_stack_partitions"
const TRANSFERRED="source_native_stack_transferred_quantity"
static var busy: bool=false
static var _candidate: Dictionary={}
static var _candidate_kind: String=""
static var _floor_record: Dictionary={}
static var _floor_commit_confirmed: bool=false
static var _partition_parent: String=""

static func authorizes(payload: Dictionary) -> bool:
	return busy and not _candidate.is_empty() and _candidate==payload

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=0 and value<=9007199254740991.0

static func profile(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity() or record.get("slot")!="consumable":return {}
	var definition: Dictionary=D.item_definition(record)
	if definition.is_empty() or definition.get("original_item",{}).get("TestItem")!=false or not record.get("source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	if not record.get("heal_spec",{}).is_empty():
		var metadata: Dictionary=D.hp_use_metadata(record)
		if record.get("source_item_class_id")==233:metadata=load("res://scripts/loot/quest_hp233_use.gd").call("metadata",record)
		if metadata.get("ok",false):return {"kind":"hp","metadata":metadata}
	var spec: Dictionary=record.get("source_use_spec",{})
	if spec.get("kind")=="source_mp_dice" and spec.get("activation_status")=="unrestricted":return {"kind":"mp","spec":spec}
	return {}

static func supply_profile(record: Dictionary) -> Dictionary:
	var effect: Dictionary=profile(record)
	if not effect.is_empty():return effect
	if record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity() or record.get("slot")!="material" or not record.get("source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var definition: Dictionary=D.item_definition(record)
	if definition.get("original_item",{}).get("TestItem")!=false or definition.get("excluded",false):return {}
	# This is a material-owner admission, not individual use/effect activation.
	# Actual recipe rows/choices/limits are still checked by the craft executor.
	if SOURCE.related("ItemCraftInput","ItemClassID",int(record.get("source_item_class_id",0))).is_empty():return {}
	return {"kind":"craft_material","standalone_effect_complete":false}

static func stage_grant(record: Dictionary,quantity: int,instances: Dictionary,origin: Dictionary) -> Dictionary:
	if quantity<1 or not integer(quantity) or origin.is_empty() or supply_profile(record).is_empty():return {"ok":false,"error":"현재 원문 물리 공급 계약 미지원"}
	var uid: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while instances.has(uid):uid=Crypto.new().generate_random_bytes(16).hex_encode()
	var receipt: Dictionary={"schema":1,"issued_physical_id":uid,"item_class_id":record.source_item_class_id,"bless_raw":record.source_bless_raw,"granted_quantity":quantity,"source_definition_archive":SOURCE.identity(),"source_original_item":record.source_original_item.duplicate(true),"origin":origin.duplicate(true)}
	var result: Dictionary=instances.duplicate(true)
	result[uid]={"name":str(record.name),"record":record.duplicate(true),"level":0,QUANTITY:quantity,RECEIPT:receipt,"source_native_stack_used_quantity":0}
	return {"ok":true,"item_instances":result,"id":uid}

static func proof(world: Node,uid: String) -> Dictionary:
	return proof_entry(world.item_instances.get(uid),uid)

static func proof_entry(entry: Variant,uid: String) -> Dictionary:
	if not entry is Dictionary or not entry.get("record") is Dictionary or not entry.get(RECEIPT) is Dictionary:return {}
	var record: Dictionary=D.current_owned_record(entry.record)
	if supply_profile(record).is_empty() or entry.get("name")!=record.get("name") or entry.get("level")!=0:return {}
	var receipt: Dictionary=entry[RECEIPT]
	if not receipt_valid(receipt,uid) or receipt.get("source_original_item")!=record.get("source_original_item") or receipt.get("item_class_id")!=record.get("source_item_class_id") or receipt.get("bless_raw")!=record.get("source_bless_raw"):return {}
	var remaining: Variant=entry.get(QUANTITY);var used: Variant=entry.get("source_native_stack_used_quantity");var granted: Variant=receipt.get("granted_quantity");var transferred: Variant=entry.get(TRANSFERRED,0)
	if not integer(remaining) or not integer(used) or not integer(granted) or not integer(transferred) or int(remaining)<1 or int(used)>int(granted)-int(transferred) or int(remaining)!=int(granted)-int(used)-int(transferred):return {}
	return {"record":record,"remaining":int(remaining),"used":int(used),"transferred":int(transferred),"receipt":receipt,"first_grant_receipt":first_grant_receipt(receipt),"allocated_quantity":int(granted)}

static func receipt_valid(receipt: Dictionary,uid: String,depth: int=0) -> bool:
	if depth>128 or receipt.get("schema") not in [1,2] or receipt.get("issued_physical_id")!=uid or receipt.get("source_definition_archive")!=SOURCE.identity() or not integer(receipt.get("item_class_id")) or not integer(receipt.get("granted_quantity")) or int(receipt.granted_quantity)<1 or receipt.get("source_original_item")!=SOURCE.row("ItemClass",int(receipt.item_class_id)) or receipt.get("bless_raw") not in [1,2,3] or not receipt.get("origin") is Dictionary or receipt.origin.is_empty():return false
	if receipt.schema==1:return true
	var origin: Dictionary=receipt.origin
	if origin.get("kind")!="owned_quantity_partition" or not origin.get("partition_id") is String or str(origin.partition_id).length()!=32 or not str(origin.partition_id).is_valid_hex_number(false) or not origin.get("parent_physical_id") is String or origin.parent_physical_id==uid or not origin.get("parent_receipt") is Dictionary:return false
	var parent: Dictionary=origin.parent_receipt
	return receipt_valid(parent,str(origin.parent_physical_id),depth+1) and parent.get("item_class_id")==receipt.item_class_id and parent.get("bless_raw")==receipt.bless_raw and parent.get("source_original_item")==receipt.source_original_item and int(receipt.granted_quantity)<=int(parent.granted_quantity)

static func first_grant_receipt(receipt: Dictionary) -> Dictionary:
	var root: Dictionary=receipt
	for depth: int in range(129):
		if root.get("schema")==1:return root.duplicate(true)
		if root.get("schema")!=2 or not root.get("origin",{}).get("parent_receipt") is Dictionary:return {}
		root=root.origin.parent_receipt
	return {}

static func ledger_row(owned: Dictionary,used: int,remaining: int,discarded: int=0) -> Dictionary:
	var row: Dictionary={"receipt":owned.receipt.duplicate(true),"used_quantity":used,"remaining_quantity":remaining}
	if int(owned.get("transferred",0))>0:row["transferred_quantity"]=int(owned.transferred)
	if discarded>0:row["discarded_quantity"]=discarded;row["discard_reason"]="TWILIGHT_existing_ground_lifetime"
	return row

static func _failure(reason: String) -> Dictionary:
	return {"handled":true,"ok":false,"saved":false,"consumed":0,"reason":reason}

static func try_use(world: Node,item_name: String,selected: String="") -> Dictionary:
	var named: Dictionary=world._find_catalog_item_record(item_name)
	var selected_entry: Variant=world.item_instances.get(selected,{})
	var claims: bool=not profile(named).is_empty() or (selected_entry is Dictionary and selected_entry.has(RECEIPT))
	if not claims:
		for entry: Variant in world.item_instances.values():
			if entry is Dictionary and entry.get("name")==item_name and entry.has(RECEIPT):claims=true;break
	if not claims:return {"handled":false}
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return _failure("원본 소비 저장 보호 중 · 물리 수량 보존")
	if not world._patch523_item_allowed() or world.hp<=0 or world._option_awakening_busy():return _failure("현재 사용·생존 상태 조건 미충족")
	var uid: String="";var owned: Dictionary={};var total: int=0
	for id: String in world.item_instances:
		var entry: Variant=world.item_instances[id]
		if not entry is Dictionary or entry.get("name")!=item_name or not entry.has(RECEIPT):continue
		var current: Dictionary=proof(world,id)
		if current.is_empty():return _failure("원본 물리 소유·최초량·잔량 증명 불일치")
		if total>9007199254740991-int(current.remaining):return _failure("물리 수량 정수 범위 초과")
		total+=int(current.remaining)
		if uid.is_empty() and (selected.is_empty() or selected==id) and not world._item_locked(item_name,id):uid=id;owned=current
	if not integer(world.inventory.get(item_name,0)) or total>int(world.inventory.get(item_name,0)) or uid.is_empty() or world._item_locked(item_name):return _failure("선택 물리 개체·잠금·소지 수량 확인 필요 · 이름만 같은 보유품 보존")
	var record: Dictionary=owned.record;var effect: Dictionary=profile(record)
	if effect.is_empty():return _failure("원본 제작 재료입니다 · 해당 제작식에서 물리 개체와 수량을 선택하세요")
	var use_owner: Resource=load("res://scripts/loot/patch523_item_use.gd")
	var problem: String=str(use_owner.call("eligibility",world,record))
	if not problem.is_empty():return _failure(problem)
	var details: Dictionary=effect.get("metadata",{});var spec: Dictionary=effect.get("spec",{})
	if not bool(details.get("can_use_when_invisible",spec.get("can_use_when_invisible",false))) and world.is_player_concealed():return _failure("원본 조건: 은신 중 사용할 수 없습니다")
	var cooldown_key: String="m523:item:"+str(record.source_item_class_id)
	if float(world.item_use_cooldowns.get(cooldown_key,0.0))>0:return _failure("원본 아이템 재사용 대기")
	var maximum: int=world._effective_max_hp() if effect.kind=="hp" else world._effective_max_mp()
	var before: int=int(world.hp if effect.kind=="hp" else world.mp)
	if before>=maximum:return _failure("HP가 가득 찼습니다" if effect.kind=="hp" else "MP가 가득 찼습니다")
	var parameters: Dictionary=world._source_hp_potion_parameters(0) if effect.kind=="hp" else {}
	if effect.kind=="hp" and float(world.item_use_cooldowns.get(str(parameters.cooldown_key),0.0))>0:return _failure("HP 물약 재사용 대기")
	var state: Dictionary=world.consumable_service.export_state()
	var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return _failure("기존 원본 물리 소비 장부 형식 보존")
	if int(owned.used)+int(owned.transferred)==0 and ledger.has(uid):return _failure("물리 공급 영수증과 기존 사용 장부 불일치")
	if int(owned.used)+int(owned.transferred)>0 and ledger.get(uid)!=ledger_row(owned,int(owned.used),int(owned.remaining)):return _failure("물리 잔량과 원본 사용 장부 불일치")
	var candidate_rng:=RandomNumberGenerator.new();candidate_rng.seed=world.rng.seed;candidate_rng.state=world.rng.state
	var amount: int=0
	if effect.kind=="hp":
		amount=D.healing_amount(record,candidate_rng,0)
		parameters=world._source_hp_potion_parameters(amount)
		amount=world.patch523_npc_spells.extensions.healing(int(parameters.heal_amount),true)
	else:
		amount=int(spec.base)
		for die: int in range(int(spec.dice_number)):amount+=candidate_rng.randi_range(1,int(spec.dice_spot_count))
	var after: int=mini(maximum,before+amount)
	var bag: Dictionary=world.inventory.duplicate(true);bag[item_name]=int(bag[item_name])-1
	if int(bag[item_name])==0:bag.erase(item_name)
	var instances: Dictionary=world.item_instances.duplicate(true)
	if owned.remaining==1:instances.erase(uid)
	else:instances[uid][QUANTITY]=int(owned.remaining)-1;instances[uid].source_native_stack_used_quantity=int(owned.used)+1
	ledger=ledger.duplicate(true);ledger[uid]=ledger_row(owned,int(owned.used)+1,int(owned.remaining)-1);state[USES]=ledger
	var cooldowns: Dictionary=world.item_use_cooldowns.duplicate(true)
	var delay: float=float(details.get("source_consume_delay_ms",spec.get("consume_delay_ms",0)))/1000.0
	if delay>0:cooldowns[cooldown_key]=delay;cooldowns[item_name]=delay
	if effect.kind=="hp":cooldowns[str(parameters.cooldown_key)]=float(parameters.cooldown_seconds)
	var payload: Dictionary={"inventory":bag,"item_instances":instances,"consumable_state":state,"item_use_cooldowns":cooldowns,"patch523_transaction_rng":{"schema":1,"seed":str(candidate_rng.seed),"state":str(candidate_rng.state)}}
	payload["hp" if effect.kind=="hp" else "mp"]=after
	busy=true;_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear()
	if saved!=OK:
		world.patch523_owner_state_problem="원본 물리 소비 저장 실패·결과 미확정 · 다시 불러오기 전 저장·재사용 중지"
		busy=false;return _failure(world.patch523_owner_state_problem)
	world.inventory=bag;world.item_instances=instances;world.item_use_cooldowns=cooldowns;world.consumable_service.import_state(state)
	world.rng.seed=candidate_rng.seed;world.rng.state=candidate_rng.state
	if effect.kind=="hp":world.hp=after;world._source_hp_potion_committed(amount)
	else:world.mp=after
	world.deferred_save.cancel();busy=false
	var sprite: int=int(details.get("consume_effect_sprite_id",spec.get("consume_effect_sprite_id",0)))
	if sprite>0:world.option_awakening.combat.emit_sprite(sprite,world.player)
	return {"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"message":"%s · %s %d 회복" % [str(record.source_display_name),"HP" if effect.kind=="hp" else "MP",after-before]}

# Existing save/load owner uses these pure candidate guards. No game load or
# validation command is executed while implementing this boundary.
static func state_error(inventory: Variant,instances: Variant,state: Variant,warehouse: Variant={},floor: Variant=[]) -> String:
	if not inventory is Dictionary or not instances is Dictionary or not state is Dictionary or not warehouse is Dictionary or not floor is Array:return "원본 물리 수량 저장 후보 형식 확인 필요"
	var stored: Variant=warehouse.get("instances",{});var stored_counts: Variant=warehouse.get("stacks",{})
	if not stored is Dictionary or not stored_counts is Dictionary:return "원본 창고 물리 저장 형식 확인 필요"
	var all: Dictionary=instances.duplicate()
	for uid: String in stored:
		if not stored[uid] is Dictionary or not stored[uid].has(RECEIPT):continue
		if all.has(uid):return "소지·창고 원본 개체 ID 중복 · 저장 보존"
		all[uid]=stored[uid]
	var floor_ids: Dictionary={}
	for entry: Variant in floor:
		if not entry is Dictionary:return "바닥 소유 기록 형식 확인 필요"
		var physical: Variant=entry.get("physical_item",{})
		if not physical is Dictionary or not physical.get("data") is Dictionary or not physical.data.has(RECEIPT):continue
		var uid: String=str(physical.get("id",""))
		var owned: Dictionary=proof_entry(physical.data,uid)
		if uid.is_empty() or all.has(uid) or owned.is_empty() or entry.get("player_dropped")!=true or entry.get("quantity")!=1 or int(owned.remaining)!=1 or entry.get("item_name")!=physical.data.get("name") or entry.get("item_record")!=physical.data.get("record"):return "바닥 원본 개체·잔량·출처 중복 또는 불일치"
		all[uid]=physical.data;floor_ids[uid]=true
	var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return "원본 물리 사용 장부 형식 확인 필요"
	var totals: Dictionary={};var stored_totals: Dictionary={}
	for uid: String in all:
		var entry: Variant=all[uid]
		if not entry is Dictionary or not entry.has(RECEIPT):continue
		var owned: Dictionary=proof_entry(entry,uid)
		if owned.is_empty():return "원본 물리 개체·최초량·잔량 증명 불일치"
		if int(owned.used)+int(owned.transferred)==0 and ledger.has(uid):return "원본 최초 소유와 소비 장부 불일치"
		if int(owned.used)+int(owned.transferred)>0 and ledger.get(uid)!=ledger_row(owned,int(owned.used),int(owned.remaining)):return "원본 물리 잔량·소비 장부 불일치"
		if floor_ids.has(uid):continue
		var name_value: String=str(entry.name)
		var amounts: Dictionary=stored_totals if stored.has(uid) else totals
		var previous: int=int(amounts.get(name_value,0))
		if previous>9007199254740991-int(owned.remaining):return "원본 물리 수량 범위 초과"
		amounts[name_value]=previous+int(owned.remaining)
	for name_value: String in totals:
		if not integer(inventory.get(name_value,0)) or int(inventory.get(name_value,0))<int(totals[name_value]):return "원본 물리 잔량보다 소지 수량이 적습니다 · 기존 저장 보존"
	for name_value: String in stored_totals:
		if not integer(stored_counts.get(name_value,0)) or int(stored_counts.get(name_value,0))<int(stored_totals[name_value]) or int(stored_counts.get(name_value,0))>1000000:return "원본 창고 물리 수량·저장 범위 불일치"
	for uid: String in ledger:
		var entry: Variant=ledger[uid]
		if not entry is Dictionary or not entry.get("receipt") is Dictionary or not integer(entry.get("used_quantity")) or not integer(entry.get("remaining_quantity")):return "원본 소비 장부 행 형식 확인 필요"
		var receipt: Dictionary=entry.receipt
		if not receipt_valid(receipt,uid):return "원본 소비 장부 출처 확인 필요"
		var disposed: Variant=entry.get("discarded_quantity",0);var transferred: Variant=entry.get("transferred_quantity",0)
		if not integer(disposed) or not integer(transferred) or int(entry.used_quantity)+int(disposed)+int(transferred)<1 or int(entry.used_quantity)>int(receipt.granted_quantity)-int(disposed)-int(transferred) or int(entry.remaining_quantity)!=int(receipt.granted_quantity)-int(entry.used_quantity)-int(disposed)-int(transferred):return "원본 장부 최초량·사용량·잔량·분할량·소멸량 불일치"
		if int(disposed)>0 and (entry.get("discard_reason")!="TWILIGHT_existing_ground_lifetime" or int(entry.remaining_quantity)!=0):return "원본 바닥 소멸 출처·잔량 확인 필요"
		if int(entry.remaining_quantity)>0 and not all.has(uid):return "남은 원본 물리 개체가 없습니다 · 소비 장부 보존"
		if int(entry.remaining_quantity)==0 and all.has(uid):return "소비 완료 원본 개체의 중복 소유 보존 중지"
	return partition_error(all,ledger,state.get(PARTITIONS,{}))

static func override_error(world: Node,overrides: Dictionary) -> String:
	var inventory: Variant=overrides.get("inventory",world.inventory)
	var instances: Variant=overrides.get("item_instances",world.item_instances)
	var state: Variant=overrides.get("consumable_state",world.consumable_service.export_state())
	var warehouse: Variant=overrides.get("warehouse",world.warehouse.snapshot())
	var floor: Variant=overrides["ground_drops"] if overrides.has("ground_drops") else world._ground_drops_snapshot()
	var issue: String=state_error(inventory,instances,state,warehouse,floor)
	if not issue.is_empty():return issue
	var ledger: Dictionary=state.get(USES,{})
	for uid: String in world.item_instances:
		var previous: Variant=world.item_instances[uid]
		if not previous is Dictionary or not previous.has(RECEIPT):continue
		var before: Dictionary=proof_entry(previous,uid)
		if before.is_empty():return "기존 원본 물리 증명 보존 필요"
		var next: Variant=instances.get(uid)
		if next==previous:continue
		if authorizes(overrides) and _candidate_kind in ["partition_warehouse","partition_drop"] and uid==_partition_parent:continue
		if next==null and authorizes(overrides) and _candidate_kind=="warehouse_transfer" and warehouse.get("instances",{}).get(uid)==previous:continue
		if next==null and authorizes(overrides) and _candidate_kind=="floor_drop" and floor_physical(floor,uid)==previous:continue
		var remaining: int=0
		if next!=null:
			var after: Dictionary=proof_entry(next,uid)
			if after.is_empty():return "원본 물리 잔량 변경 후보 불일치"
			remaining=int(after.remaining)
			var expected: Dictionary=previous.duplicate(true)
			expected[QUANTITY]=remaining;expected.source_native_stack_used_quantity=int(before.used)+int(before.remaining)-remaining
			if next!=expected:return "원본 물리 개체의 출처·다른 필드 변경 금지"
		var consumed: int=int(before.remaining)-remaining
		if consumed<1 or ledger.get(uid)!=ledger_row(before,int(before.used)+consumed,remaining):return "원본 물리 차감과 사용 장부 공동 저장 필요"
	for uid: String in world.warehouse.instances:
		var previous: Variant=world.warehouse.instances[uid]
		if not previous is Dictionary or not previous.has(RECEIPT):continue
		if warehouse.get("instances",{}).get(uid)==previous:continue
		if authorizes(overrides) and _candidate_kind=="partition_warehouse" and uid==_partition_parent:continue
		if authorizes(overrides) and _candidate_kind=="warehouse_transfer" and instances.get(uid)==previous:continue
		return "창고 원본 개체의 정확한 이동 소유자 필요 · 영수증 보존"
	var old_floor: Dictionary={}
	for record: Dictionary in world.ground_loot.records.values():
		var physical: Variant=record.get("physical_item",{})
		if not physical is Dictionary or not physical.get("data") is Dictionary or not physical.data.has(RECEIPT):continue
		var uid: String=str(physical.get("id",""));old_floor[uid]=record
		if floor_physical(floor,uid)==physical.data:continue
		if authorizes(overrides) and _candidate_kind=="floor_pickup" and instances.get(uid)==physical.data:continue
		if authorizes(overrides) and _candidate_kind=="floor_expire" and _floor_record==record:
			var owned: Dictionary=proof_entry(physical.data,uid)
			if not owned.is_empty() and ledger.get(uid)==ledger_row(owned,int(owned.used),0,int(owned.remaining)):continue
		return "바닥 원본 물리 개체의 정확한 습득·소멸 소유자 필요"
	var previous_partitions: Variant=world.consumable_service.export_state().get(PARTITIONS,{})
	var next_partitions: Variant=state.get(PARTITIONS,{})
	if not previous_partitions is Dictionary or not next_partitions is Dictionary:return "기존 물리 분할 장부 형식 보존"
	for id: String in previous_partitions:
		if next_partitions.get(id)!=previous_partitions[id]:return "원본 물리 분할 이력 변경 금지"
	for id: String in next_partitions:
		if not previous_partitions.has(id) and not (authorizes(overrides) and _candidate_kind in ["partition_warehouse","partition_drop"]):return "새 물리 분할은 정확한 이전 소유자 거래가 필요합니다"
	var old_ledger: Variant=world.consumable_service.export_state().get(USES,{})
	if not old_ledger is Dictionary:return "기존 원본 사용 장부 보존 필요"
	for uid: String in old_ledger:
		if ledger.get(uid)==old_ledger[uid]:continue
		if authorizes(overrides) and _candidate_kind in ["partition_warehouse","partition_drop"] and uid==_partition_parent:continue
		if not world.item_instances.has(uid) or not world.item_instances[uid].has(RECEIPT):
			if authorizes(overrides) and _candidate_kind=="floor_expire" and old_floor.has(uid):continue
			return "이미 끝난 원본 사용 영수증 변경 금지"
	return ""

static func stage_debit(world: Node,requests: Array) -> Dictionary:
	var bag: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	var state: Dictionary=world.consumable_service.export_state()
	var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return _failure("원본 물리 사용 장부 형식 보존")
	ledger=ledger.duplicate(true)
	var seen: Dictionary={};var selections: Array=[]
	for request: Variant in requests:
		if not request is Dictionary or request.size()!=5:return _failure("원본 물리 재료 요청5필드 필요")
		for key: String in ["physical_id","quantity","expected_quantity","expected_remaining","source_native_stack_receipt"]:
			if not request.has(key):return _failure("원본 물리 재료 요청 필드 누락")
		var uid: Variant=request.physical_id
		if not uid is String or uid.is_empty() or seen.has(uid):return _failure("원본 물리 개체 중복 요청 금지")
		var owned: Dictionary=proof(world,uid)
		if owned.is_empty() or not integer(request.quantity) or int(request.quantity)<1 or int(request.quantity)>int(owned.remaining) or request.expected_quantity!=owned.remaining or request.expected_remaining!=int(owned.remaining)-int(request.quantity) or request.source_native_stack_receipt!=owned.receipt:return _failure("선택한 원본 물리 재료·수량·예상 잔량 불일치")
		var name_value: String=str(owned.record.name)
		if world._item_locked(name_value,uid) or world._item_locked(name_value) or not integer(bag.get(name_value,0)) or int(bag.get(name_value,0))<int(request.quantity):return _failure("원본 재료 잠금·소지 수량 불일치")
		var deadline: String=D.deadline_problem(owned.record,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if not deadline.is_empty():return _failure(deadline)
		var used: int=int(owned.used)+int(request.quantity);var remaining: int=int(request.expected_remaining)
		bag[name_value]=int(bag[name_value])-int(request.quantity)
		if int(bag[name_value])==0:bag.erase(name_value)
		if remaining==0:instances.erase(uid)
		else:instances[uid][QUANTITY]=remaining;instances[uid].source_native_stack_used_quantity=used
		ledger[uid]=ledger_row(owned,used,remaining)
		selections.append({"physical_id":uid,"inventory_key":name_value,"quantity":int(request.quantity),"remaining_after":remaining,"source_native_stack_receipt":owned.receipt.duplicate(true)})
		seen[uid]=true
	state[USES]=ledger
	var overrides: Dictionary={"inventory":bag,"item_instances":instances,"consumable_state":state}
	var issue: String=override_error(world,overrides)
	if not issue.is_empty():return _failure(issue)
	return {"ok":true,"overrides":overrides,"selections":selections}

static func join_craft_output(world: Node,book: RefCounted,transaction: Dictionary,context: Dictionary) -> Dictionary:
	var output: Dictionary=transaction.get("selected_output",{})
	var quantity: Variant=transaction.get("result_quantity",0)
	if not integer(quantity):return _failure("원본 제작 출력 수량 형식 확인 필요")
	if int(quantity)==0 or output.get("empty_result",false) or output.get("physical",false):return transaction
	var retained: Variant=transaction.get("source_native_retained_output_quantity",0)
	if not integer(retained) or int(retained)>int(quantity):return _failure("원본 반환 수량·출력 수량 불일치")
	quantity=int(quantity)-int(retained)
	if int(quantity)==0:return transaction # Exact old selected units already remain owned.
	var record: Dictionary=book.record(str(output.get("source_id","")),int(output.get("bless_code",0)))
	if record.is_empty():return _failure("원본 제작 출력 정의 미연결 · 재료 보존")
	if output.get("wallet_currency",false) and str(output.get("source_id"))=="26" and record.get("name")=="아데나":return transaction
	var supply: Script=load("res://scripts/cards/native_awakening_supply.gd")
	var typed: bool=supply.call("exact",record,int(output.get("source_id",0)))
	if not typed and record.get("source_projection")!="current523_original_typed_game_dto_v1":return transaction
	if int(output.get("level",-1))!=0 or not integer(transaction.inventory.get(str(record.get("name","")),0)) or int(transaction.inventory.get(str(record.get("name","")),0))<int(quantity):return _failure("원본 제작 출력 강화·소지 수량 불일치")
	var origin: Dictionary={"kind":"source523_compiled_craft","recipe_id":str(context.get("source_recipe_id","")),"rules_sha256":book.digest,"source_output":output.duplicate(true),"source_craft_receipt_id":str(transaction.get("source_craft_receipt_id","")),"selected_native_inputs":context.get("quest_material_review",{}).get("native_requests",[]).duplicate(true)}
	var granted: Dictionary=supply.call("stage_grant",record,int(quantity),transaction.item_instances,origin) if typed else stage_grant(record,int(quantity),transaction.item_instances,origin)
	if not granted.get("ok",false):return _failure("원본 제작 비장비 출력의 물리 소유·사용 계약 연결 대기 · 재료와 난수 보존")
	transaction.item_instances=granted.item_instances
	var receipt_id: String=str(transaction.get("source_craft_receipt_id",""))
	if not receipt_id.is_empty() and transaction.get("consumable_state",{}).get("source_quest_craft_receipts",{}).has(receipt_id):transaction.consumable_state.source_quest_craft_receipts[receipt_id].output_physical_ids.append(str(granted.id))
	return transaction

static func can_supply(record: Dictionary,inventory: Dictionary,instances: Dictionary) -> bool:
	if supply_profile(record).is_empty():return false
	var name_value: String=str(record.get("name",""));var total: int=0
	for uid: String in instances:
		var entry: Variant=instances[uid]
		if not entry is Dictionary or entry.get("name")!=name_value:continue
		var owned: Dictionary=proof_entry(entry,uid)
		if owned.is_empty() or owned.record.get("sourceId")!=record.get("sourceId") or owned.record.get("source_bless_raw")!=record.get("source_bless_raw"):return false
		if total>9007199254740991-int(owned.remaining):return false
		total+=int(owned.remaining)
	return integer(inventory.get(name_value,0)) and int(inventory.get(name_value,0))>=total

static func transfer_warehouse(world: Node,item_name: String,quantity: int,direction: String,uid: String) -> Dictionary:
	if direction not in ["deposit","withdraw"]:return {"handled":false}
	var source: Dictionary=world.item_instances if direction=="deposit" else world.warehouse.instances
	var claims: bool=false
	for entry: Variant in source.values():
		if entry is Dictionary and entry.get("name")==item_name and entry.has(RECEIPT):claims=true;break
	if not claims:return {"handled":false}
	if busy or not str(world.patch523_owner_state_problem).is_empty() or world.quest_service.save_blocked:return _failure("원본 창고 거래 저장 보호 중")
	var owned: Dictionary=proof_entry(source.get(uid),uid)
	if owned.is_empty() or owned.record.get("name")!=item_name:return _failure("이동할 실제 원본 묶음 개체를 선택하세요")
	if quantity<1 or quantity>99 or quantity>int(owned.remaining):return _failure("선택한 원본 묶음의 실제 잔량 안에서 수량을 지정하세요")
	if world._item_locked(item_name,uid) or world._item_locked(item_name):return _failure("잠긴 원본 개체는 이동할 수 없습니다")
	if direction=="deposit" and (owned.receipt.source_original_item.get("IsStorable")!=true or world._is_instance_equipped(uid)):return _failure("원본 보관 제한·장착 조건 미충족")
	if direction=="withdraw" and world._inventory_total_weight()+quantity*maxi(0,int(world.item_weight_index.get(item_name,3)))>world._carrying_capacity():return _failure("기존 소지 무게 한도 초과")
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	var warehouse: Dictionary=world.warehouse.snapshot()
	var from_counts: Dictionary=inventory if direction=="deposit" else warehouse.stacks
	var to_counts: Dictionary=warehouse.stacks if direction=="deposit" else inventory
	var from_instances: Dictionary=instances if direction=="deposit" else warehouse.instances
	var to_instances: Dictionary=warehouse.instances if direction=="deposit" else instances
	if not integer(from_counts.get(item_name,0)) or int(from_counts.get(item_name,0))<quantity or not integer(to_counts.get(item_name,0)) or int(to_counts.get(item_name,0))>9007199254740991-quantity or to_instances.has(uid):return _failure("원본 창고 수량·개체 ID 충돌 · 기존 보유 보존")
	if direction=="deposit" and int(to_counts.get(item_name,0))>1000000-quantity:return _failure("기존 창고 저장 수량 한도 초과")
	var moved_uid: String=uid;var partition: Dictionary={}
	if quantity<int(owned.remaining):
		partition=prepare_partition(world,from_instances[uid],uid,quantity,world.consumable_service.export_state())
		if not partition.get("ok",false):return partition
		moved_uid=str(partition.child_id)
	from_counts[item_name]=int(from_counts[item_name])-quantity
	if int(from_counts[item_name])==0:from_counts.erase(item_name)
	to_counts[item_name]=int(to_counts.get(item_name,0))+quantity
	if partition.is_empty():to_instances[uid]=from_instances[uid].duplicate(true);from_instances.erase(uid)
	else:from_instances[uid]=partition.parent;to_instances[moved_uid]=partition.child
	var payload: Dictionary={"inventory":inventory,"item_instances":instances,"warehouse":warehouse}
	if not partition.is_empty():payload["consumable_state"]=partition.consumable_state
	busy=true;_candidate_kind="partition_warehouse" if not partition.is_empty() else "warehouse_transfer";_partition_parent=uid if not partition.is_empty() else "";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";_partition_parent=""
	if saved!=OK:
		world.patch523_owner_state_problem="원본 창고 저장 실패·결과 미확정 · 정상 저장 불러오기 전 재이동 중지"
		busy=false;return _failure(world.patch523_owner_state_problem)
	world.inventory=inventory;world.item_instances=instances;world.warehouse.stacks=warehouse.stacks;world.warehouse.instances=warehouse.instances
	if payload.has("consumable_state"):world.consumable_service.import_state(payload.consumable_state)
	world.deferred_save.cancel();busy=false
	return {"handled":true,"ok":true,"saved":true,"physical_id":moved_uid,"parent_physical_id":uid,"quantity":quantity,"direction":direction,"message":"원본 영수증과 실제 수량을 보존해 창고 이동했습니다"}

static func floor_physical(floor: Array,uid: String) -> Dictionary:
	for record: Dictionary in floor:
		if record.get("physical_item",{}).get("id")==uid:return record.physical_item.get("data",{})
	return {}

static func can_remove_floor(record: Dictionary) -> bool:
	if not busy or not _floor_commit_confirmed or _candidate_kind not in ["floor_pickup","floor_expire"] or _floor_record!=record:return false
	for next: Dictionary in _candidate.get("ground_drops",[]):
		if next.get("id")==record.get("id"):return false
	return true

static func _floor_payload(record: Dictionary) -> Dictionary:
	var physical: Variant=record.get("physical_item")
	if not physical is Dictionary or not physical.get("data") is Dictionary or not physical.data.has(RECEIPT):return {}
	var uid: String=str(physical.get("id",""));var owned: Dictionary=proof_entry(physical.data,uid)
	if owned.is_empty() or owned.remaining!=1 or record.get("quantity")!=1 or record.get("player_dropped")!=true or record.get("item_name")!=physical.data.get("name") or record.get("item_record")!=physical.data.get("record"):return {}
	return {"uid":uid,"owned":owned,"physical":physical.data}

static func _clear_floor_candidate() -> void:
	_candidate.clear();_candidate_kind="";_floor_record.clear();_floor_commit_confirmed=false;_partition_parent="";busy=false

static func drop(world: Node,reference: String,requested_position: Vector2) -> Dictionary:
	var selected: Dictionary=world._parse_enhancement_target(reference)
	var name_value: String=str(selected.get("name",""));var uid: String=str(selected.get("id",""))
	var claims: bool=false
	for entry: Variant in world.item_instances.values():
		if entry is Dictionary and entry.get("name")==name_value and entry.has(RECEIPT):claims=true;break
	if not claims:return {"handled":false}
	if busy or not str(world.patch523_owner_state_problem).is_empty() or world.quest_service.save_blocked:return _failure("원본 바닥 이동 저장 보호 중")
	var owned: Dictionary=proof(world,uid)
	if owned.is_empty() or owned.record.get("name")!=name_value:return _failure("바닥으로 이동할 실제 원본 개체를 선택하세요")
	if world.hp<=0 or world.death_recovery.blocked() or world._item_locked(name_value,uid) or world._item_locked(name_value) or world._is_instance_equipped(uid) or owned.receipt.source_original_item.get("IsDroppable")!=true:return _failure("원본 내려놓기·잠금·장착·생존 조건 미충족")
	if not requested_position.is_finite():return _failure("유효한 바닥 좌표 필요")
	var point: Vector2=world.player.global_position+(requested_position-world.player.global_position).limit_length(96.0)
	if not world._is_walkable_world(point) or not world._has_line_of_sight_world(world.player.global_position,point):point=world.player.global_position
	var physical: Dictionary=world.item_instances[uid].duplicate(true)
	var moved_uid: String=uid;var partition: Dictionary={}
	if int(owned.remaining)>1:
		partition=prepare_partition(world,physical,uid,1,world.consumable_service.export_state())
		if not partition.get("ok",false):return partition
		physical=partition.child;moved_uid=str(partition.child_id)
	var record: Dictionary=world.ground_loot.stage_spawn(name_value,point,1,"",{"player_dropped":true,"item_record":physical.record.duplicate(true),"physical_item":{"id":moved_uid,"data":physical}})
	if record.is_empty():return _failure("기존 바닥 배치 공간 없음 · 소유 보존")
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	if not integer(inventory.get(name_value,0)) or int(inventory[name_value])<1:return _failure("원본 소지 수량 불일치")
	inventory[name_value]=int(inventory[name_value])-1
	if int(inventory[name_value])==0:inventory.erase(name_value)
	if partition.is_empty():instances.erase(uid)
	else:instances[uid]=partition.parent
	var floor: Array=world._ground_drops_snapshot();floor.append(record.duplicate(true))
	var payload: Dictionary={"inventory":inventory,"item_instances":instances,"ground_drops":floor}
	if not partition.is_empty():payload["consumable_state"]=partition.consumable_state
	busy=true;_candidate_kind="partition_drop" if not partition.is_empty() else "floor_drop";_partition_parent=uid if not partition.is_empty() else "";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	if saved!=OK:
		world.patch523_owner_state_problem="원본 바닥 이동 저장 실패·결과 미확정 · 정상 저장 불러오기 전 재이동 중지";_clear_floor_candidate();return _failure(world.patch523_owner_state_problem)
	var view: Button=world.ground_loot.publish_spawn(record)
	if view==null:
		world.patch523_owner_state_problem="원본 바닥 이동 저장 후 표시 채택 미확정 · 정상 저장 불러오기 필요";_clear_floor_candidate();return _failure(world.patch523_owner_state_problem)
	world.inventory=inventory;world.item_instances=instances
	if payload.has("consumable_state"):world.consumable_service.import_state(payload.consumable_state)
	world.deferred_save.cancel();_clear_floor_candidate()
	return {"handled":true,"ok":true,"saved":true,"physical_id":moved_uid,"parent_physical_id":uid,"quantity":1,"message":"원본 물리 개체1개를 바닥으로 이동했습니다"}

static func collect_floor(world: Node,view: Button,record: Dictionary) -> Dictionary:
	var envelope: Variant=record.get("physical_item",{})
	if not envelope is Dictionary:return {"handled":false}
	var physical: Variant=envelope.get("data",{})
	if not physical is Dictionary or not physical.has(RECEIPT):return {"handled":false}
	if busy or not str(world.patch523_owner_state_problem).is_empty() or world.quest_service.save_blocked:return _failure("원본 바닥 습득 저장 보호 중")
	var source: Dictionary=_floor_payload(record)
	if source.is_empty() or not world.ground_loot.valid_view(view) or world.item_instances.has(source.uid) or world.warehouse.instances.has(source.uid) or world.hp<=0:return _failure("원본 바닥 개체·소유·생존 조건 불일치")
	var point: Array=record.get("position",[])
	if point.size()!=2:return _failure("바닥 좌표 구조 오류")
	var destination:=Vector2(float(point[0]),float(point[1]))
	if not destination.is_finite() or world.player.global_position.distance_to(destination)>world.GROUND_PICKUP_RADIUS or Time.get_ticks_msec()-int(view.get("visible_since"))<world.ground_loot.MIN_VISIBLE_MS or not world._has_line_of_sight_world(world.player.global_position,destination):return _failure("기존 바닥 습득 거리·시간·시야 조건 미충족")
	var name_value: String=str(source.physical.name)
	if world._inventory_total_weight()+maxi(0,int(world.item_weight_index.get(name_value,3)))>world._carrying_capacity():return _failure("기존 소지 무게 한도 초과")
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	if not integer(inventory.get(name_value,0)) or int(inventory.get(name_value,0))>=9007199254740991:return _failure("원본 습득 수량 범위 초과")
	inventory[name_value]=int(inventory.get(name_value,0))+1;instances[source.uid]=source.physical.duplicate(true)
	var floor: Array=[];var found: bool=false
	for previous: Dictionary in world._ground_drops_snapshot():
		if previous.get("id")==record.get("id"):
			if found or previous!=record:return _failure("선택 바닥 상태 변경")
			found=true
		else:floor.append(previous)
	if not found:return _failure("선택 바닥 개체가 없습니다")
	var payload: Dictionary={"inventory":inventory,"item_instances":instances,"ground_drops":floor}
	busy=true;_candidate_kind="floor_pickup";_candidate=payload.duplicate(true);_floor_record=record.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	if saved!=OK:
		world.patch523_owner_state_problem="원본 재습득 저장 실패·결과 미확정 · 정상 저장 불러오기 전 재사용 중지";_clear_floor_candidate();return _failure(world.patch523_owner_state_problem)
	_floor_commit_confirmed=true
	var taken: Dictionary=world.ground_loot.take(view,world.player.global_position,world.GROUND_PICKUP_RADIUS)
	if taken.is_empty():
		world.patch523_owner_state_problem="원본 재습득 저장 후 바닥 채택 미확정 · 정상 저장 불러오기 필요";_clear_floor_candidate();return _failure(world.patch523_owner_state_problem)
	world.inventory=inventory;world.item_instances=instances;world.deferred_save.cancel();_clear_floor_candidate()
	return {"handled":true,"ok":true,"saved":true,"record":taken}

static func expire_floor(world: Node,record: Dictionary) -> bool:
	if busy or not str(world.patch523_owner_state_problem).is_empty() or world.quest_service.save_blocked:return false
	var source: Dictionary=_floor_payload(record)
	if source.is_empty() or world.ground_loot.records.get(str(record.get("id","")))!=record or not is_finite(float(record.get("expires_at",INF))) or float(record.get("expires_at",INF))>Time.get_unix_time_from_system():return false
	var state: Dictionary=world.consumable_service.export_state();var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return false
	ledger=ledger.duplicate(true);ledger[source.uid]=ledger_row(source.owned,int(source.owned.used),0,1);state[USES]=ledger
	var floor: Array=[]
	for previous: Dictionary in world.ground_loot.records.values():
		if previous.get("id")!=record.get("id"):floor.append(previous.duplicate(true))
	var payload: Dictionary={"ground_drops":floor,"consumable_state":state}
	busy=true;_candidate_kind="floor_expire";_candidate=payload.duplicate(true);_floor_record=record.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	if saved!=OK:
		world.patch523_owner_state_problem="원본 바닥 유효시간 소멸 저장 실패·결과 미확정 · 정상 저장 불러오기 필요";_clear_floor_candidate();return false
	_floor_commit_confirmed=true
	if not world.ground_loot._remove(str(record.id)):
		world.patch523_owner_state_problem="원본 바닥 소멸 저장 후 채택 미확정 · 정상 저장 불러오기 필요";_clear_floor_candidate();return false
	world.consumable_service.import_state(state);world.deferred_save.cancel();_clear_floor_candidate()
	return true

static func partition_error(all: Dictionary,ledger: Dictionary,partitions: Variant) -> String:
	if not partitions is Dictionary:return "원본 물리 분할 장부 형식 확인 필요"
	var receipts: Dictionary={};var transferred: Dictionary={};var by_parent: Dictionary={}
	for uid: String in all:
		if all[uid] is Dictionary and all[uid].has(RECEIPT):receipts[uid]=all[uid][RECEIPT];transferred[uid]=int(all[uid].get(TRANSFERRED,0))
	for uid: String in ledger:
		receipts[uid]=ledger[uid].receipt;transferred[uid]=int(ledger[uid].get("transferred_quantity",0))
	for id: String in partitions:
		var event: Variant=partitions[id]
		if not event is Dictionary or event.get("schema")!=1 or not event.get("parent_id") is String or not event.get("child_id") is String or event.parent_id==event.child_id or not event.get("parent_receipt") is Dictionary or not event.get("child_receipt") is Dictionary:return "원본 분할 거래 정체 확인 필요"
		for key: String in ["quantity","before_remaining","after_remaining","before_transferred","after_transferred","used_at_partition"]:
			if not integer(event.get(key)):return "원본 분할 수량 형식 불일치"
		if int(event.quantity)<1 or int(event.quantity)>=int(event.before_remaining) or int(event.after_remaining)!=int(event.before_remaining)-int(event.quantity) or int(event.after_transferred)!=int(event.before_transferred)+int(event.quantity):return "원본 분할 전후 잔량 불일치"
		if not receipt_valid(event.parent_receipt,event.parent_id) or not receipt_valid(event.child_receipt,event.child_id) or receipts.get(event.parent_id)!=event.parent_receipt or receipts.get(event.child_id)!=event.child_receipt:return "원본 분할 부모·자식 영수증 보존 필요"
		var child: Dictionary=event.child_receipt
		if child.schema!=2 or child.origin.get("partition_id")!=id or child.origin.get("parent_physical_id")!=event.parent_id or child.origin.get("parent_receipt")!=event.parent_receipt or child.granted_quantity!=event.quantity or int(event.before_remaining)+int(event.before_transferred)+int(event.used_at_partition)!=int(event.parent_receipt.granted_quantity):return "원본 지급량과 분할 배정량의 불변 관계 불일치"
		if not by_parent.has(event.parent_id):by_parent[event.parent_id]=[]
		by_parent[event.parent_id].append(event)
	for uid: String in receipts:
		var receipt: Dictionary=receipts[uid]
		if receipt.get("schema")==2:
			var event: Variant=partitions.get(str(receipt.origin.partition_id))
			if not event is Dictionary or event.get("child_id")!=uid or event.get("child_receipt")!=receipt:return "근거 없는 원본 분할 소유 생성 금지"
		var events: Array=by_parent.get(uid,[]);events.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return int(a.before_transferred)<int(b.before_transferred))
		var amount: int=0
		for event: Dictionary in events:
			if int(event.before_transferred)!=amount:return "원본 분할 장부 순서·합계 불일치"
			amount+=int(event.quantity)
		if amount!=int(transferred.get(uid,0)):return "원본 물리 이전량과 분할 장부 합계 불일치"
	return ""

static func prepare_partition(world: Node,parent: Dictionary,uid: String,quantity: int,state: Dictionary) -> Dictionary:
	var owned: Dictionary=proof_entry(parent,uid)
	if owned.is_empty() or quantity<1 or quantity>=int(owned.remaining):return _failure("실제 원본 잔량 안의 부분 수량 필요")
	var events: Variant=state.get(PARTITIONS,{})
	var ledger: Variant=state.get(USES,{})
	if not events is Dictionary or not ledger is Dictionary:return _failure("원본 분할·사용 장부 형식 보존")
	var child_id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while world.item_instances.has(child_id) or world.warehouse.instances.has(child_id) or not floor_physical(world.ground_loot.records.values(),child_id).is_empty() or ledger.has(child_id):child_id=Crypto.new().generate_random_bytes(16).hex_encode()
	var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while events.has(id):id=Crypto.new().generate_random_bytes(16).hex_encode()
	var receipt: Dictionary=owned.receipt.duplicate(true);receipt.schema=2;receipt.issued_physical_id=child_id;receipt.granted_quantity=quantity
	receipt.origin={"kind":"owned_quantity_partition","partition_id":id,"parent_physical_id":uid,"parent_receipt":owned.receipt.duplicate(true)}
	var child: Dictionary=parent.duplicate(true);child[QUANTITY]=quantity;child[RECEIPT]=receipt;child.source_native_stack_used_quantity=0;child.erase(TRANSFERRED)
	var after: Dictionary=parent.duplicate(true);after[QUANTITY]=int(owned.remaining)-quantity;after[TRANSFERRED]=int(owned.transferred)+quantity
	var next_owned: Dictionary=owned.duplicate(true);next_owned.transferred=int(owned.transferred)+quantity
	events=events.duplicate(true);events[id]={"schema":1,"parent_id":uid,"child_id":child_id,"quantity":quantity,"before_remaining":owned.remaining,"after_remaining":after[QUANTITY],"before_transferred":owned.transferred,"after_transferred":after[TRANSFERRED],"used_at_partition":owned.used,"parent_receipt":owned.receipt.duplicate(true),"child_receipt":receipt.duplicate(true)}
	ledger=ledger.duplicate(true);ledger[uid]=ledger_row(next_owned,int(owned.used),int(after[QUANTITY]))
	var result: Dictionary=state.duplicate(true);result[PARTITIONS]=events;result[USES]=ledger
	return {"ok":true,"parent":after,"child":child,"child_id":child_id,"consumable_state":result,"partition_id":id}

# Exact source-reader -> existing physical native-use boundary. Original raw
# ItemClass and opaque immutable ownership proof stay separate arguments.
static func use_owned_original(world: Node,original_item: Dictionary,request: Dictionary) -> Dictionary:
	if request.size()!=5:return _failure("원문 소모품 선택 소유 요청5필드 필요")
	for key: String in ["physical_id","quantity","expected_quantity","expected_remaining","source_native_stack_receipt"]:
		if not request.has(key):return _failure("원문 소모품 소유 증명 필드 누락")
	if not request.physical_id is String or request.physical_id.is_empty() or not integer(request.quantity) or int(request.quantity)!=1 or not integer(request.expected_quantity) or not integer(request.expected_remaining):return _failure("원문 소모품은 실제 선택 개체의1단위와 정확한 정수 잔량을 지정하세요")
	var owned: Dictionary=proof(world,request.physical_id)
	if owned.is_empty() or original_item!=owned.receipt.source_original_item or original_item!=SOURCE.row("ItemClass",int(owned.receipt.item_class_id)) or request.source_native_stack_receipt!=owned.receipt or request.expected_quantity!=owned.remaining or request.expected_remaining!=int(owned.remaining)-1:return _failure("원문 행·선택 개체·최초량·현재 잔량 증명 불일치")
	if profile(owned.record).is_empty():
		var result: Dictionary=_failure("해당 원문 소모품의 실제 효과 소유자 연결 대기 · 소유와 영수증 보존")
		result["source_use_supported"]=false;result["source_problem"]="current_original_effect_owner_required"
		return result
	return try_use(world,str(owned.record.name),str(request.physical_id))
