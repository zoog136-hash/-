extends RefCounted
## Existing HP/MP effects with exact current-source physical quantity ownership.
## No name-only conversion, reference effect activation, or live trial grant.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const QUANTITY="source_native_stack_quantity"
const RECEIPT="source_native_stack_receipt"
const USES="source_native_stack_uses"
static var busy: bool=false
static var _candidate: Dictionary={}

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

static func stage_grant(record: Dictionary,quantity: int,instances: Dictionary,origin: Dictionary) -> Dictionary:
	if quantity<1 or not integer(quantity) or origin.is_empty() or profile(record).is_empty():return {"ok":false,"error":"현재 원문 HP/MP 물리 공급 계약 미지원"}
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
	if profile(record).is_empty() or entry.get("name")!=record.get("name") or entry.get("level")!=0:return {}
	var receipt: Dictionary=entry[RECEIPT]
	if receipt.get("schema")!=1 or receipt.get("issued_physical_id")!=uid or receipt.get("source_definition_archive")!=SOURCE.identity() or receipt.get("source_original_item")!=record.get("source_original_item") or receipt.get("item_class_id")!=record.get("source_item_class_id") or receipt.get("bless_raw")!=record.get("source_bless_raw") or not receipt.get("origin") is Dictionary or receipt.origin.is_empty():return {}
	var remaining: Variant=entry.get(QUANTITY);var used: Variant=entry.get("source_native_stack_used_quantity");var granted: Variant=receipt.get("granted_quantity")
	if not integer(remaining) or not integer(used) or not integer(granted) or int(remaining)<1 or int(used)>int(granted) or int(remaining)!=int(granted)-int(used):return {}
	return {"record":record,"remaining":int(remaining),"used":int(used),"receipt":receipt}

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
	if owned.used==0 and ledger.has(uid):return _failure("물리 공급 영수증과 기존 사용 장부 불일치")
	if owned.used>0 and ledger.get(uid)!={"receipt":owned.receipt,"used_quantity":owned.used,"remaining_quantity":owned.remaining}:return _failure("물리 잔량과 원본 사용 장부 불일치")
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
	ledger=ledger.duplicate(true);ledger[uid]={"receipt":owned.receipt.duplicate(true),"used_quantity":int(owned.used)+1,"remaining_quantity":int(owned.remaining)-1};state[USES]=ledger
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
static func state_error(inventory: Variant,instances: Variant,state: Variant) -> String:
	if not inventory is Dictionary or not instances is Dictionary or not state is Dictionary:return "원본 물리 수량 저장 후보 형식 확인 필요"
	var ledger: Variant=state.get(USES,{})
	if not ledger is Dictionary:return "원본 물리 사용 장부 형식 확인 필요"
	var totals: Dictionary={}
	for uid: String in instances:
		var entry: Variant=instances[uid]
		if not entry is Dictionary or not entry.has(RECEIPT):continue
		var owned: Dictionary=proof_entry(entry,uid)
		if owned.is_empty():return "원본 물리 개체·최초량·잔량 증명 불일치"
		if owned.used==0 and ledger.has(uid):return "원본 최초 소유와 소비 장부 불일치"
		if owned.used>0 and ledger.get(uid)!={"receipt":owned.receipt,"used_quantity":owned.used,"remaining_quantity":owned.remaining}:return "원본 물리 잔량·소비 장부 불일치"
		var name_value: String=str(entry.name)
		var previous: int=int(totals.get(name_value,0))
		if previous>9007199254740991-int(owned.remaining):return "원본 물리 수량 범위 초과"
		totals[name_value]=previous+int(owned.remaining)
	for name_value: String in totals:
		if not integer(inventory.get(name_value,0)) or int(inventory.get(name_value,0))<int(totals[name_value]):return "원본 물리 잔량보다 소지 수량이 적습니다 · 기존 저장 보존"
	for uid: String in ledger:
		var entry: Variant=ledger[uid]
		if not entry is Dictionary or not entry.get("receipt") is Dictionary or not integer(entry.get("used_quantity")) or not integer(entry.get("remaining_quantity")):return "원본 소비 장부 행 형식 확인 필요"
		var receipt: Dictionary=entry.receipt
		if receipt.get("schema")!=1 or receipt.get("issued_physical_id")!=uid or receipt.get("source_definition_archive")!=SOURCE.identity() or not integer(receipt.get("item_class_id")) or not integer(receipt.get("granted_quantity")) or int(receipt.granted_quantity)<1 or receipt.get("source_original_item")!=SOURCE.row("ItemClass",int(receipt.item_class_id)) or receipt.get("bless_raw") not in [1,2,3] or not receipt.get("origin") is Dictionary or receipt.origin.is_empty():return "원본 소비 장부 출처 확인 필요"
		if int(entry.used_quantity)<1 or int(entry.used_quantity)>int(receipt.granted_quantity) or int(entry.remaining_quantity)!=int(receipt.granted_quantity)-int(entry.used_quantity):return "원본 소비 장부 최초량·사용량·잔량 불일치"
		if int(entry.remaining_quantity)>0 and not instances.has(uid):return "남은 원본 물리 개체가 없습니다 · 소비 장부 보존"
		if int(entry.remaining_quantity)==0 and instances.has(uid):return "소비 완료 원본 개체의 중복 소유 보존 중지"
	return ""

static func override_error(world: Node,overrides: Dictionary) -> String:
	var inventory: Variant=overrides.get("inventory",world.inventory)
	var instances: Variant=overrides.get("item_instances",world.item_instances)
	var state: Variant=overrides.get("consumable_state",world.consumable_service.export_state())
	var issue: String=state_error(inventory,instances,state)
	if not issue.is_empty():return issue
	var ledger: Dictionary=state.get(USES,{})
	for uid: String in world.item_instances:
		var previous: Variant=world.item_instances[uid]
		if not previous is Dictionary or not previous.has(RECEIPT):continue
		var before: Dictionary=proof_entry(previous,uid)
		if before.is_empty():return "기존 원본 물리 증명 보존 필요"
		var next: Variant=instances.get(uid)
		if next==previous:continue
		var remaining: int=0
		if next!=null:
			var after: Dictionary=proof_entry(next,uid)
			if after.is_empty():return "원본 물리 잔량 변경 후보 불일치"
			remaining=int(after.remaining)
			var expected: Dictionary=previous.duplicate(true)
			expected[QUANTITY]=remaining;expected.source_native_stack_used_quantity=int(before.used)+int(before.remaining)-remaining
			if next!=expected:return "원본 물리 개체의 출처·다른 필드 변경 금지"
		var consumed: int=int(before.remaining)-remaining
		if consumed<1 or ledger.get(uid)!={"receipt":before.receipt,"used_quantity":int(before.used)+consumed,"remaining_quantity":remaining}:return "원본 물리 차감과 사용 장부 공동 저장 필요"
	var old_ledger: Variant=world.consumable_service.export_state().get(USES,{})
	if not old_ledger is Dictionary:return "기존 원본 사용 장부 보존 필요"
	for uid: String in old_ledger:
		if ledger.get(uid)==old_ledger[uid]:continue
		if not world.item_instances.has(uid) or not world.item_instances[uid].has(RECEIPT):return "이미 끝난 원본 사용 영수증 변경 금지"
	return ""
