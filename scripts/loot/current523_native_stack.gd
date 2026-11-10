extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Existing HP/MP effects with exact current-source physical quantity ownership.
## No name-only conversion, reference effect activation, or live trial grant.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const SERVER=preload("res://scripts/loot/current523_server_profile.gd")
const RESTORATION=preload("res://scripts/shop/source523_restoration.gd")
const QUEST_OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const QUEST_CONSUME=preload("res://scripts/quests/quest_reward_consumption.gd")
const QUANTITY="source_native_stack_quantity"
const RECEIPT="source_native_stack_receipt"
const USES="source_native_stack_uses"
const PARTITIONS="source_native_stack_partitions"
const BAG_USES="source_native_bag_uses"
const AMMO_EQUIPPED="source_native_ammo_equipped"
const AMMO_USES="source_native_ammo_uses"
const AMMO_RNG="source_native_ammo_rng"
const SKILL_MATERIAL_USES="source_native_skill_material_uses"
const TRANSFERRED="source_native_stack_transferred_quantity"
static var busy: bool=false
static var _candidate: Dictionary={}
static var _candidate_kind: String=""
static var _floor_record: Dictionary={}
static var _floor_commit_confirmed: bool=false
static var _partition_parent: String=""

class SupplierView extends Node:
	var host: Node
	var inventory: Dictionary
	var item_instances: Dictionary
	var gold: int
	func _catalog_item_from_source_id(id: String) -> Dictionary:return host._catalog_item_from_source_id(id)

static func authorizes(payload: Dictionary) -> bool:
	return busy and not _candidate.is_empty() and _candidate==payload

static func integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=0 and value<=9007199254740991.0
## Table and save JSON numbers are floats; `in` is type-strict, so an integral
## one is compared as the int it is. Other values are returned unchanged.
static func whole(value: Variant) -> Variant:
	return int(value) if typeof(value)==TYPE_FLOAT and is_finite(value) and value==floorf(value) and absf(value)<=9007199254740991.0 else value

static func profile(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity():return {}
	var definition: Dictionary=D.item_definition(record)
	if definition.is_empty() or definition.get("original_item",{}).get("TestItem")!=false or not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var ammo: Dictionary=load("res://scripts/loot/patch523_ammo.gd").call("current_profile",record)
	if not ammo.is_empty():return {"kind":"ammo","spec":ammo}
	if record.get("slot")!="consumable":return {}
	if record.get("source_item_class_id")==310:
		var cure: Dictionary=load("res://scripts/quests/quest_cure310.gd").call("profile",record)
		if not cure.is_empty():return {"kind":"cure","spec":NATIVE_FIELDS.full(cure).source_use_spec}
	if not record.get("heal_spec",{}).is_empty():
		var metadata: Dictionary=D.hp_use_metadata(record)
		if record.get("source_item_class_id")==233:metadata=load("res://scripts/loot/quest_hp233_use.gd").call("metadata",record)
		elif whole(record.get("source_item_class_id")) in [237,236]:metadata=restoration_metadata(record)
		if metadata.get("ok",false):return {"kind":"hp","metadata":metadata}
	var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
	if spec.get("kind")=="source_skill_book" and (spec.get("activation_status")=="unrestricted" or presentation_only(record,spec)):return {"kind":"skill_book","spec":spec,"runtime_presentation":spec.get("activation_status")!="unrestricted"}
	if spec.get("kind")=="source_mp_dice" and spec.get("activation_status")=="unrestricted":return {"kind":"mp","spec":spec}
	if spec.get("kind")=="fixed_card" and spec.get("activation_status")=="unrestricted":return {"kind":"card","spec":spec}
	if spec.get("kind")=="equipment_bless" and spec.get("activation_status")=="unrestricted":return {"kind":"bless","spec":spec}
	if spec.get("kind")=="weapon_mastery_points" and spec.get("activation_status")=="unrestricted":return {"kind":"mastery","spec":spec}
	if spec.get("kind")=="source_timed_buff" and spec.get("activation_status")=="unrestricted" and not spec.get("typed_effects",{}).is_empty():return {"kind":"buff","spec":spec}
	if spec.get("kind") in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"] and (spec.get("activation_status")=="unrestricted" or presentation_only(record,spec)):return {"kind":"bag","spec":spec,"runtime_presentation":spec.get("activation_status")!="unrestricted"}
	if spec.get("kind")=="source_selectable_reward" and (spec.get("activation_status")=="unrestricted" or presentation_only(record,spec)):return {"kind":"selection","spec":spec,"runtime_presentation":spec.get("activation_status")!="unrestricted"}
	if spec.get("kind")=="source_timed_buff" and presentation_only(record,spec):return {"kind":"buff","spec":spec,"runtime_presentation":true}
	var regen: Script=load("res://scripts/quests/quest_regen523.gd")
	if not regen.call("contract",record).is_empty():return {"kind":"buff","runtime_regen":true}
	var original_buff: Script=load("res://scripts/quests/quest_source_buffs523.gd")
	var expanded: Dictionary=original_buff.call("profile",record)
	if NATIVE_FIELDS.full(expanded).get("source_use_spec",{}).get("activation_status")=="unrestricted":return {"kind":"buff","spec":NATIVE_FIELDS.full(expanded).source_use_spec}
	return {}

static func supply_profile(record: Dictionary) -> Dictionary:
	var effect: Dictionary=profile(record)
	if not effect.is_empty():return effect
	var material: Dictionary=spell_material_profile(record)
	if not material.is_empty():return material
	var ticket: Dictionary=draw_ticket_profile(record)
	if not ticket.is_empty():return ticket
	if record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity() or record.get("slot")!="material" or not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var definition: Dictionary=D.item_definition(record)
	if definition.get("original_item",{}).get("TestItem")!=false or definition.get("excluded",false):return {}
	# This is a material-owner admission, not individual use/effect activation.
	# Actual recipe rows/choices/limits are still checked by the craft executor.
	if SOURCE.related("ItemCraftInput","ItemClassID",int(record.get("source_item_class_id",0))).is_empty():return {}
	return {"kind":"craft_material","standalone_effect_complete":false}

## Original draw tickets (ItemCategory LinMarketProduct) are owned as physical
## stacks like materials. Redemption belongs to the owned-ticket service
## (source523_inventory_tickets.gd), which checks the ticket's products and
## pools; an unsupported ticket is explained there and stays owned.
static func draw_ticket_profile(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity() or NATIVE_FIELDS.field(record,"source_category_name")!="LinMarketProduct" or record.get("slot")!="consumable" or not NATIVE_FIELDS.field(record,"source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var definition: Dictionary=D.item_definition(record)
	if definition.get("original_item",{}).get("TestItem")!=false or definition.get("excluded",false):return {}
	return {"kind":"draw_ticket","standalone_effect_complete":false,"use_owner":"source523_inventory_tickets"}

static func stage_grant(record: Dictionary,quantity: int,instances: Dictionary,origin: Dictionary) -> Dictionary:
	if quantity<1 or not integer(quantity) or origin.is_empty() or supply_profile(record).is_empty():return {"ok":false,"error":"현재 원문 물리 공급 계약 미지원"}
	var uid: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while instances.has(uid):uid=Crypto.new().generate_random_bytes(16).hex_encode()
	var receipt: Dictionary={"schema":1,"issued_physical_id":uid,"item_class_id":record.source_item_class_id,"bless_raw":record.source_bless_raw,"granted_quantity":quantity,"source_definition_archive":SOURCE.identity(),"source_original_item":NATIVE_FIELDS.full(record).source_original_item.duplicate(true),"origin":origin.duplicate(true)}
	var result: Dictionary=instances.duplicate(true)
	result[uid]={"name":str(record.name),"record":NATIVE_FIELDS.full(record).duplicate(true),"level":0,QUANTITY:quantity,RECEIPT:receipt,"source_native_stack_used_quantity":0}
	return {"ok":true,"item_instances":result,"id":uid}

static func proof(world: Node,uid: String) -> Dictionary:
	return proof_entry(world.item_instances.get(uid),uid)

static func proof_entry(entry: Variant,uid: String) -> Dictionary:
	if not entry is Dictionary or not entry.get("record") is Dictionary or not entry.get(RECEIPT) is Dictionary:return {}
	var record: Dictionary=D.current_owned_record(entry.record)
	if supply_profile(record).is_empty() or entry.get("name")!=record.get("name") or entry.get("level")!=0:return {}
	var receipt: Dictionary=entry[RECEIPT]
	if not receipt_valid(receipt,uid) or NATIVE_FIELDS.full(receipt).get("source_original_item")!=NATIVE_FIELDS.full(record).get("source_original_item") or receipt.get("item_class_id")!=record.get("source_item_class_id") or receipt.get("bless_raw")!=record.get("source_bless_raw"):return {}
	var remaining: Variant=entry.get(QUANTITY);var used: Variant=entry.get("source_native_stack_used_quantity");var granted: Variant=receipt.get("granted_quantity");var transferred: Variant=entry.get(TRANSFERRED,0)
	if not integer(remaining) or not integer(used) or not integer(granted) or not integer(transferred) or int(remaining)<1 or int(used)>int(granted)-int(transferred) or int(remaining)!=int(granted)-int(used)-int(transferred):return {}
	return {"record":record,"remaining":int(remaining),"used":int(used),"transferred":int(transferred),"receipt":receipt,"first_grant_receipt":first_grant_receipt(receipt),"allocated_quantity":int(granted)}

static func receipt_valid(receipt: Dictionary,uid: String,depth: int=0) -> bool:
	if depth>128 or whole(receipt.get("schema")) not in [1,2] or receipt.get("issued_physical_id")!=uid or receipt.get("source_definition_archive")!=SOURCE.identity() or not integer(receipt.get("item_class_id")) or not integer(receipt.get("granted_quantity")) or int(receipt.granted_quantity)<1 or NATIVE_FIELDS.full(receipt).get("source_original_item")!=SOURCE.row("ItemClass",int(receipt.item_class_id)) or whole(receipt.get("bless_raw")) not in [1,2,3] or not receipt.get("origin") is Dictionary or receipt.origin.is_empty():return false
	if receipt.schema==1:return true
	var origin: Dictionary=receipt.origin
	if origin.get("kind")!="owned_quantity_partition" or not origin.get("partition_id") is String or str(origin.partition_id).length()!=32 or not str(origin.partition_id).is_valid_hex_number(false) or not origin.get("parent_physical_id") is String or origin.parent_physical_id==uid or not origin.get("parent_receipt") is Dictionary:return false
	var parent: Dictionary=origin.parent_receipt
	return receipt_valid(parent,str(origin.parent_physical_id),depth+1) and parent.get("item_class_id")==receipt.item_class_id and parent.get("bless_raw")==receipt.bless_raw and NATIVE_FIELDS.full(parent).get("source_original_item")==NATIVE_FIELDS.full(receipt).source_original_item and int(receipt.granted_quantity)<=int(parent.granted_quantity)

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
	if effect.is_empty() and not draw_ticket_profile(record).is_empty():return {"handled":false} # The owned-ticket service redeems it.
	if effect.is_empty():return _failure("원본 소비 재료입니다 · 해당 스킬·제작에서 물리 개체와 수량을 확인하세요")
	if effect.kind=="ammo":return {"handled":false} # Existing inventory activation wears the selected physical ammunition.
	var use_owner: Resource=load("res://scripts/loot/patch523_item_use.gd")
	var problem: String=str(use_owner.call("eligibility",world,record))
	if not problem.is_empty():return _failure(problem)
	var details: Dictionary=effect.get("metadata",{});var spec: Dictionary=effect.get("spec",{})
	if effect.get("runtime_regen",false):
		var regen_owner: Script=load("res://scripts/quests/quest_regen523.gd")
		var active: Dictionary=regen_owner.call("action",world,record)
		spec=NATIVE_FIELDS.full(active).get("source_use_spec",{})
		if spec.get("activation_status")!="unrestricted":return _failure("기존 MP 재생 주기 설정·원본 조건 확인 필요 · 물약 보존")
	if effect.get("runtime_presentation",false):
		var active: Dictionary=use_owner.call("action_record",world,record)
		spec=NATIVE_FIELDS.full(active).get("source_use_spec",{})
		if spec.get("activation_status")!="unrestricted":return _failure("기존 표시 메타데이터·기간 정책에서 사용을 보류합니다 · 아이템 보존")
	if not bool(details.get("can_use_when_invisible",spec.get("can_use_when_invisible",false))) and world.is_player_concealed():return _failure("원본 조건: 은신 중 사용할 수 없습니다")
	var cooldown_key: String="m523:item:"+str(record.source_item_class_id)
	if float(world.item_use_cooldowns.get(cooldown_key,0.0))>0:return _failure("원본 아이템 재사용 대기")
	if effect.kind=="cure":return load("res://scripts/quests/quest_cure310.gd").call("perform",world,record,uid)
	if effect.kind=="skill_book":return learn_skill_book(world,uid,owned,record,spec)
	if effect.kind=="card":return use_fixed_card(world,uid,owned,record,spec)
	if effect.kind=="mastery":return use_mastery_points(world,uid,owned,record,spec)
	# A bless scroll needs a target: the existing blessing chooser opens and its
	# confirmation debits the physical scroll (consumable_service.apply_bless_scroll).
	if effect.kind=="bless":world.consumable_service.call("_use_bless_scroll",item_name);return {"handled":true,"ok":false,"silent":true}
	if effect.kind=="selection":return selection_pending(world,uid,owned,record,spec)
	if effect.kind=="bag":return use_bag(world,uid,owned,record,spec)
	var maximum: int=world._effective_max_hp() if effect.kind=="hp" else (world._effective_max_mp() if effect.kind=="mp" else 0)
	var before: int=int(world.hp if effect.kind=="hp" else (world.mp if effect.kind=="mp" else 0))
	if effect.kind in ["hp","mp"] and before>=maximum:return _failure("HP가 가득 찼습니다" if effect.kind=="hp" else "MP가 가득 찼습니다")
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
	elif effect.kind=="mp":
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
	if effect.kind=="buff":
		var source: Dictionary=spec.get("source_buff_class",{});var group: Dictionary=spec.get("source_buff_group",{})
		if source.is_empty() or group.is_empty() or float(spec.get("duration_seconds",0))<=0:return _failure("원본 버프 수치·기간·그룹 연결 필요")
		var buffs: Dictionary=world.active_item_buffs.duplicate(true)
		for key: String in buffs.keys():
			var previous: Dictionary=buffs[key]
			if not previous.get("source_buff_class") is Dictionary:continue
			var old: Dictionary=previous.source_buff_class
			if old.get("ID")==source.get("ID") or (not group.get("IsAllowOverlap",false) and old.get("BuffGroupID")==source.get("BuffGroupID")):buffs.erase(key)
		var value: Dictionary=spec.typed_effects.duplicate(true)
		value.merge({"remaining":float(spec.duration_seconds),"duration":float(spec.duration_seconds),"source_buff_class":source.duplicate(true),"source_buff_group":group.duplicate(true),"source_item_class_id":int(record.source_item_class_id),"source_snapshot":"patch523"})
		buffs[item_name]=value;payload["active_item_buffs"]=buffs
		payload["hp"]=mini(world.hp,world._effective_max_hp(-1,buffs));payload["mp"]=mini(world.mp,world._effective_max_mp(buffs))
	else:payload["hp" if effect.kind=="hp" else "mp"]=after
	busy=true;_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear()
	if saved!=OK:
		world.patch523_owner_state_problem="원본 물리 소비 저장 실패·결과 미확정 · 다시 불러오기 전 저장·재사용 중지"
		busy=false;return _failure(world.patch523_owner_state_problem)
	world.inventory=bag;world.item_instances=instances;world.item_use_cooldowns=cooldowns;world.consumable_service.import_state(state)
	world.rng.seed=candidate_rng.seed;world.rng.state=candidate_rng.state
	if effect.kind=="hp":world.hp=after;world._source_hp_potion_committed(amount)
	elif effect.kind=="mp":world.mp=after
	else:
		world.active_item_buffs=payload.active_item_buffs;world.hp=int(payload.hp);world.mp=int(payload.mp)
		world._invalidate_equipment_static();world._refresh_speed_modifiers()
	world.deferred_save.cancel();busy=false
	var sprite: int=int(details.get("consume_effect_sprite_id",spec.get("consume_effect_sprite_id",0)))
	if sprite>0:world.option_awakening.combat.emit_sprite(sprite,world.player)
	var message: String="%s · 원본 버프 %s" % [str(NATIVE_FIELDS.field(record,"source_display_name")),world._format_seconds_short(float(spec.get("duration_seconds",0)))] if effect.kind=="buff" else "%s · %s %d 회복" % [str(NATIVE_FIELDS.field(record,"source_display_name")),"HP" if effect.kind=="hp" else "MP",after-before]
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"message":message}
	return committed_use_context(result,record,sprite,sprite>0,"current523_native_stack.try_use")

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
	if not state.get(USES,{}) is Dictionary:return "원본 소비 장부 형식 보존 필요"
	var selected_ammo: Variant=state.get(AMMO_EQUIPPED,{})
	if not selected_ammo is Dictionary:return "원본 탄약 선택 소유 형식 확인 필요"
	if not selected_ammo.is_empty():
		if selected_ammo.get("ownership_kind")=="quest":
			var issue: String=quest_ammo_state_error(instances,state,selected_ammo)
			if not issue.is_empty():return issue
		else:
			if selected_ammo.size()!=3 or not selected_ammo.get("physical_id") is String:return "원본 탄약 선택 개체 증명 필요"
			var selected: Dictionary=proof_entry(instances.get(selected_ammo.physical_id),selected_ammo.physical_id)
			if selected.is_empty():
				# Pure staged last-unit debit keeps only its inactive spent receipt.
				var spent: Variant=state.get(USES,{}).get(selected_ammo.physical_id,{})
				if not spent is Dictionary or spent.get("receipt")!=selected_ammo.get("receipt") or spent.get("remaining_quantity")!=0 or not integer(spent.get("used_quantity")) or int(spent.used_quantity)<1:return "원본 탄약 소지 개체 또는 정확한 마지막 소비 영수증 보존 필요"
			elif profile(selected.record).get("kind")!="ammo" or selected.record.get("name")!=selected_ammo.get("name") or selected.receipt!=selected_ammo.get("receipt"):return "착용한 원본 탄약은 실제 소지 개체·최초 영수증을 유지해야 합니다"
	var ammo_rng: Variant=state.get(AMMO_RNG,{})
	if not ammo_rng is Dictionary:return "원본 탄약 독립 난수 저장 형식 보존 필요"
	if not ammo_rng.is_empty() and (ammo_rng.size()!=3 or ammo_rng.get("schema")!=1 or not ammo_rng.get("seed") is String or not ammo_rng.get("state") is String or not str(ammo_rng.seed).is_valid_int() or not str(ammo_rng.state).is_valid_int()):return "원본 탄약 독립 난수 저장 증명 불일치"
	var ammo_uses: Variant=state.get(AMMO_USES,{})
	if not ammo_uses is Dictionary:return "원본 탄약 발사 장부 형식 확인 필요"
	for event: Variant in ammo_uses.values():
		if not event is Dictionary or event.get("schema")!=1 or not event.get("input") is Array or event.input.is_empty() or not event.get("source_definition_archive") is Dictionary:return "원본 탄약 발사 기록 보존 필요"
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
	var old_consumables: Dictionary=world.consumable_service.export_state()
	if old_consumables.get(AMMO_EQUIPPED,{})!=state.get(AMMO_EQUIPPED,{}) and not (authorizes(overrides) and _candidate_kind in ["ammo_equip","ammo_consume"]):return "원본 탄약 개체 착용은 정확한 소유자 저장이 필요합니다"
	if old_consumables.get(AMMO_RNG,{})!=state.get(AMMO_RNG,{}) and not (authorizes(overrides) and _candidate_kind=="ammo_consume"):return "원본 탄약 독립 난수 변경은 실제 소비 소유자 저장이 필요합니다"
	var old_ammo_uses: Variant=old_consumables.get(AMMO_USES,{})
	var next_ammo_uses: Variant=state.get(AMMO_USES,{})
	if not old_ammo_uses is Dictionary or not next_ammo_uses is Dictionary:return "원본 탄약 발사 장부 보존 필요"
	for event_id: String in old_ammo_uses:
		if next_ammo_uses.get(event_id)!=old_ammo_uses[event_id]:return "기존 원본 탄약 발사 기록 변경 금지"
	for event_id: String in next_ammo_uses:
		if not old_ammo_uses.has(event_id) and not (authorizes(overrides) and _candidate_kind=="ammo_consume"):return "새 원본 탄약 발사 기록은 실제 물리 차감 소유자가 필요합니다"
	var old_material_uses: Variant=old_consumables.get(SKILL_MATERIAL_USES,{})
	var next_material_uses: Variant=state.get(SKILL_MATERIAL_USES,{})
	if not old_material_uses is Dictionary or not next_material_uses is Dictionary:return "기존 원문 스킬 재료 소비 기록 보존 필요"
	for event_id: String in old_material_uses:
		if next_material_uses.get(event_id)!=old_material_uses[event_id]:return "기존 원문 스킬 재료 소비 기록 변경 금지"
	for event_id: String in next_material_uses:
		if not old_material_uses.has(event_id) and not (authorizes(overrides) and _candidate_kind=="skill_material_use"):return "새 원문 스킬 재료 기록은 실제 공동 차감 소유자 저장 필요"
	var previous_bags: Variant=world.consumable_service.export_state().get(BAG_USES,{})
	var next_bags: Variant=state.get(BAG_USES,{})
	if not previous_bags is Dictionary or not next_bags is Dictionary:return "기존 원본 상자 사용 장부 형식 보존"
	for id: String in previous_bags:
		if next_bags.get(id)!=previous_bags[id]:return "이전 원본 상자 결과·난수 영수증 변경 금지"
	for id: String in next_bags:
		if not previous_bags.has(id) and not (authorizes(overrides) and _candidate_kind=="bag_use"):return "새 상자 결과 영수증은 정확한 지급·소비 소유자가 필요합니다"
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
	if direction=="deposit" and (NATIVE_FIELDS.full(owned.receipt).source_original_item.get("IsStorable")!=true or world._is_instance_equipped(uid)):return _failure("원본 보관 제한·장착 조건 미충족")
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
	if world.hp<=0 or world.death_recovery.blocked() or world._item_locked(name_value,uid) or world._item_locked(name_value) or world._is_instance_equipped(uid) or NATIVE_FIELDS.full(owned.receipt).source_original_item.get("IsDroppable")!=true:return _failure("원본 내려놓기·잠금·장착·생존 조건 미충족")
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
	var quest: bool=request.has("quest_reward_receipt")
	var field: String="quest_reward_receipt" if quest else "source_native_stack_receipt"
	for key: String in ["physical_id","quantity","expected_quantity","expected_remaining",field]:
		if not request.has(key):return _failure("원문 소모품 소유 증명 필드 누락")
	if not request.physical_id is String or request.physical_id.is_empty() or not integer(request.quantity) or int(request.quantity)!=1 or not integer(request.expected_quantity) or not integer(request.expected_remaining):return _failure("원문 소모품은 실제 선택 개체의1단위와 정확한 정수 잔량을 지정하세요")
	if quest:return use_quest_original_bag(world,original_item,request)
	var owned: Dictionary=proof(world,request.physical_id)
	if owned.is_empty() or original_item!=NATIVE_FIELDS.full(owned.receipt).source_original_item or original_item!=SOURCE.row("ItemClass",int(owned.receipt.item_class_id)) or request.source_native_stack_receipt!=owned.receipt or request.expected_quantity!=owned.remaining or request.expected_remaining!=int(owned.remaining)-1:return _failure("원문 행·선택 개체·최초량·현재 잔량 증명 불일치")
	if profile(owned.record).is_empty():
		var result: Dictionary=_failure("해당 원문 소모품의 실제 효과 소유자 연결 대기 · 소유와 영수증 보존")
		result["source_use_supported"]=false;result["source_problem"]="current_original_effect_owner_required"
		return result
	return try_use(world,str(owned.record.name),str(request.physical_id))

static func use_quest_original_bag(world: Node,original_item: Dictionary,request: Dictionary) -> Dictionary:
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return _failure("원본 상자 저장 보호 중")
	var uid: String=str(request.physical_id);var owned: Dictionary=QUEST_OWN.proof(world,uid)
	if not owned.get("ok",false) or owned.get("source_use_immediately",true) or original_item!=owned.get("source_item") or original_item!=SOURCE.row("ItemClass",int(owned.get("item_class_id",0))) or world.item_instances.get(uid,{}).get("quest_reward_receipt")!=request.quest_reward_receipt or request.expected_quantity!=owned.quantity or request.expected_remaining!=int(owned.quantity)-1:return _failure("원본 퀘스트 상자 지급·물리 잔량 증명 불일치")
	if world.hp<=0 or not world._patch523_item_allowed() or world._option_awakening_busy() or world._item_locked(str(owned.inventory_key),uid) or world._item_locked(str(owned.inventory_key)):return _failure("원본 상자 생존·사용·잠금 조건 미충족")
	var definition: Dictionary=D.definition_id(str(int(owned.item_class_id)))
	var record: Dictionary=D.variant_item(definition.get("native_record",{}),int(owned.bless_code_id))
	var executor: Script=load("res://scripts/loot/patch523_item_use.gd")
	record=executor.call("action_record",world,record)
	var issue: String=str(executor.call("eligibility",world,record))
	if not issue.is_empty():return _failure(issue)
	var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
	if spec.get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward","source_skill_book"] or spec.get("activation_status")!="unrestricted":return _failure("원본 퀘스트 아이템의 현재 효과 소유자 연결 대기")
	if world.is_player_concealed() and not spec.get("can_use_when_invisible",false):return _failure("원본 조건: 은신 중 사용할 수 없습니다")
	if float(world.item_use_cooldowns.get("m523:item:"+str(int(owned.item_class_id)),0.0))>0:return _failure("원본 상자 재사용 대기")
	var selected_owned: Dictionary={"record":record,"remaining":int(owned.quantity),"receipt":request.quest_reward_receipt,"ownership_kind":"quest"}
	if spec.kind=="source_skill_book":return learn_skill_book(world,uid,selected_owned,record,spec)
	if spec.kind=="source_selectable_reward":return selection_pending(world,uid,selected_owned,record,spec)
	return use_bag(world,uid,selected_owned,record,spec)

static func restoration_metadata(record: Dictionary) -> Dictionary:
	var id: int=int(record.get("source_item_class_id",0))
	if id not in [237,236] or record.get("source_bless_raw")!=1:return {"ok":false}
	var values: Dictionary=RESTORATION._source_items()
	var definition: Dictionary=D.item_definition(record);var raw: Dictionary=definition.get("original_item",{})
	var held: Dictionary=RESTORATION.source_provenance.get("selected_inputs",{}).get(str(id),{})
	if values.get(str(id),{}).is_empty() or RESTORATION.source_input_identity!=SOURCE.identity() or held.get("item_class")!=raw or raw.get("TargettingTypeID")!=1 or not str(raw.get("ServiceRegionCode","")).is_empty() or definition.get("category",{}).get("Name")!="Potion" or definition.get("category",{}).get("IsConsumable")!=true:return {"ok":false}
	var spec: Dictionary=values[str(id)];var heal: Dictionary=record.get("heal_spec",{})
	if heal.get("HPRestoration",0)!=spec.base or heal.get("HPRestorationDiceNumber",0)!=spec.dice_count or heal.get("HPRestorationDiceSpotCount",0)!=spec.dice_sides:return {"ok":false}
	var allowed: Dictionary={"HPRestoration":"Value","HPRestorationDiceNumber":"Value","HPRestorationDiceSpotCount":"Value","ItemConsumeDelay":"MilliSeconds","ItemConsumeEffectSpriteID":"SpriteID","AutoUseRegistrable":"TrueFalse"}
	var seen: Dictionary={};var result: Dictionary={"ok":true,"can_use_when_invisible":raw.get("CanUseWhenInvisible",false),"auto_use_registrable":false,"consume_effect_sprite_id":0}
	for row: Dictionary in definition.get("item_bonus",[]):
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""));var bonus: Dictionary=row.get("bonus",{})
		if not allowed.has(name_value) or seen.has(name_value) or row.get("IsPossession")!=false or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or row.get("unit",{}).get("Name")!=allowed[name_value]:return {"ok":false}
		seen[name_value]=true
		if name_value=="AutoUseRegistrable":
			if whole(bonus.get("Value")) not in [0,1]:return {"ok":false}
			result.auto_use_registrable=bonus.Value==1
		elif name_value=="ItemConsumeDelay":result["source_consume_delay_ms"]=int(bonus.Value)
		elif name_value=="ItemConsumeEffectSpriteID":result.consume_effect_sprite_id=int(bonus.Value)
	# AutoUseRegistrable is optional: the 523 rows of #236/#237 carry only the
	# five restoration/consume rows (no AutoUseRegistrable => not auto-use).
	for required: String in ["HPRestoration","HPRestorationDiceNumber","HPRestorationDiceSpotCount","ItemConsumeDelay","ItemConsumeEffectSpriteID"]:
		if not seen.has(required):return {"ok":false}
	return result if result.get("source_consume_delay_ms")==1000 else {"ok":false}

static func presentation_only(record: Dictionary,spec: Dictionary) -> bool:
	if spec.get("activation_status")!="blocked" or spec.get("blocked_reasons",[]).is_empty():return false
	var flags: Dictionary={"UIShowFilter":"Value","NoAnnounce":"TrueFalse"};var recognized: Dictionary={}
	for row: Dictionary in D.item_definition(record).get("item_bonus",[]):
		var name_value: String=str(row.get("bonus_type",{}).get("Name",""))
		if not flags.has(name_value):continue
		if row.get("IsPossession")!=false or row.get("bonus",{}).get("BonusApplicationTypeID")!=0 or row.bonus.get("BonusApplicationTargetID")!=0 or row.get("unit",{}).get("Name")!=flags[name_value] or whole(row.bonus.get("Value")) not in [0,1]:return false
		recognized["unsupported_item_bonus:"+name_value]=true
	if recognized.is_empty():return false
	for reason: String in spec.blocked_reasons:
		if recognized.has(reason):continue
		if reason in ["source_item_lifetime_unresolved","conditional_or_possession_item_bonus:DeleteTime"] and NATIVE_FIELDS.has_field(record,"source_delete_time_raw") and not record.get("source_delete_time_unresolved",false):continue
		return false
	return true

static func current_class(world: Node) -> int:
	var matches: Array=[]
	for entry: Dictionary in preload("res://scripts/lineagem_base508.gd").cards().get("classes",[]):
		var raw: Variant=entry.get("source_original")
		if entry.get("name")==world.job_class and raw is Dictionary and integer(raw.get("ID")) and raw.get("CanCreateClient")==true and SOURCE.row("Class",int(raw.ID))==raw:matches.append(int(raw.ID))
	return int(matches[0]) if matches.size()==1 else 0

static func use_bag(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	if spec.get("activation_status")!="unrestricted" or spec.get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"]:return _failure("원본 상자 실행 정의 연결 필요")
	var requirements: Dictionary=spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or not str(requirements.get("service_region_code","")).is_empty():return _failure("원본 상자 사용 대상·서비스 조건 미지원")
	if spec.kind!="guaranteed_bag" and not world.ui_preferences.get("patch523_source_reward_bags_enabled",true):return _failure("기존 원본 확률상자 선택 정책이 꺼져 있습니다 · 상자 보존")
	var class_id: int=current_class(world);var needs_class: bool=spec.kind!="guaranteed_bag"
	for reward: Dictionary in spec.get("rewards",[]):
		if not reward.get("class_ids",[]).is_empty():needs_class=true
	if needs_class and class_id<=0:return _failure("정확한 현재 원본 직업 정체 연결 필요 · 클래스 풀을 합치지 않습니다")
	var executor: Script=load("res://scripts/loot/patch523_item_use.gd")
	var supplier: Script=load("res://scripts/loot/patch523_item_inventory.gd")
	var view:=SupplierView.new();view.host=world;view.inventory=world.inventory;view.item_instances=world.item_instances;view.gold=world.gold
	# Every eligible positive candidate must have a real registered supplier.
	# Missing candidates never disappear or renormalize a random pool.
	for reward: Dictionary in spec.get("rewards",[]):
		if not executor.call("class_matches",reward.get("class_ids",[]),class_id):continue
		if reward.get("entity_type_id")==0 and int(reward.get("probability_raw",0))<=0:continue
		var definition: Dictionary=D.definition_id(str(int(reward.get("item_class_id",0))))
		var item: Dictionary=D.variant_item(definition.get("native_record",{}),int(reward.get("bless_raw",0)))
		if item.is_empty() or definition.get("original_item",{}).get("TestItem")!=false or definition.get("excluded",false) or not NATIVE_FIELDS.field(item,"source_condition_pending",[]).is_empty():view.free();return _failure("전체 원본 보상 정체·사용 공급 조건 미연결 · 후보 제거 없이 상자 보존")
		var deadline: String=D.deadline_problem(item,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if not deadline.is_empty():view.free();return _failure(deadline)
		var ready: Dictionary=supplier.call("stage",view,[{"item_class_id":int(reward.item_class_id),"amount":int(reward.amount),"bless_raw":int(reward.bless_raw),"enchant":int(reward.enchant)}],{"kind":"source_native_bag_candidate_quote","input_physical_id":uid,"entity_id":reward.source_entity_id})
		if not ready.get("ok",false):view.free();return _failure(str(ready.get("error","전체 원본 보상 공급자 연결 대기")))
	var candidate_rng:=RandomNumberGenerator.new();candidate_rng.seed=world.rng.seed;candidate_rng.state=world.rng.state
	var selected: Dictionary=executor.call("select_rewards",spec,class_id,candidate_rng,clampi(int(world.ui_preferences.get("patch523_reward_bag_draw_count",1)),1,10))
	if not selected.get("ok",false):view.free();return _failure("원본 전체 보상 풀·선택 계약 불일치")
	view.free()
	var origin: Dictionary={"kind":"current_original_native_bag","lucky_bag_class_id":spec.lucky_bag_class_id,"draw_count_origin":spec.get("draw_count_origin","all_source_IsGiven")}
	var evidence: Dictionary={"original_lucky_bag_class":spec.original_lucky_bag_class.duplicate(true),"class_id":class_id,"draw_count_origin":spec.get("draw_count_origin","all_source_IsGiven")}
	return commit_owned_rewards(world,uid,owned,record,spec,selected.rewards,candidate_rng,origin,evidence)

# Source UI receives this immutable proposal; it never creates a dialog or
# consumes an input. Confirmation re-reads source/ownership rather than trusting it.
static func selection_pending(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	if spec.get("kind")!="source_selectable_reward" or spec.get("activation_status")!="unrestricted" or spec.get("select_max_count")!=1:return _failure("원문 선택 보상 규칙 연결 대기")
	var class_id: int=current_class(world)
	if class_id<=0 or class_id not in spec.get("source_class_domain",[]) or whole(spec.get("original_reward",{}).get("row",{}).get("CharacterClassID")) not in [0,class_id]:return _failure("원문 선택 보상의 실제 직업 조건 불일치")
	var requirements: Dictionary=spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or not str(requirements.get("service_region_code","")).is_empty():return _failure("원문 선택 보상 사용 대상·서비스 조건 미지원")
	var choices: Array=[]
	for reward: Dictionary in spec.get("rewards",[]):
		if reward.get("class_ids",[]).is_empty() or class_id in reward.class_ids:choices.append(reward.duplicate(true))
	if choices.is_empty():return _failure("원문 직업에 맞는 선택 보상이 없습니다")
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1}
	request["quest_reward_receipt" if owned.get("ownership_kind")=="quest" else RECEIPT]=owned.receipt.duplicate(true)
	var result: Dictionary=_failure("원본 UI에서 보상을 선택하세요 · 선택 전 아이템과 잔량 보존")
	result.merge({"requires_original_selection":true,"original_item":NATIVE_FIELDS.full(record).source_original_item.duplicate(true),"ownership_request":request,"select_reward_id":spec.select_reward_id,"reward_id":spec.reward_id,"source_entities":spec.source_entities.duplicate(true),"choices":choices,"claim_method":"consumable_service.claim_owned_original_selection","entity_id_namespace":"SelectRewardEntity.ID","new_ui_created":false})
	return result

static func quote_original_selection(world: Node,original_item: Dictionary,request: Dictionary) -> Dictionary:
	if not integer(original_item.get("ID")):return _failure("원문 ItemClass.ID 필요")
	var definition: Dictionary=D.definition_id(str(int(original_item.ID)))
	if definition.get("original_item")!=original_item or NATIVE_FIELDS.full(definition.get("native_record",{})).get("source_use_spec",{}).get("kind")!="source_selectable_reward":return _failure("원문 선택 보상 정의가 아닙니다")
	return use_owned_original(world,original_item,request)

static func claim_original_selection(world: Node,original_item: Dictionary,request: Dictionary,entity_id: int) -> Dictionary:
	# Validate selection kind BEFORE calling the use entrypoint: a non-selection
	# item must never be consumed by a request aimed at a different UI action.
	if request.size()!=5 or not request.get("physical_id") is String or not integer(entity_id) or entity_id<=0:return _failure("선택 개체·원문 선택 행 ID 요청 불일치")
	var uid: String=request.physical_id;var owned: Dictionary={}
	if request.has("quest_reward_receipt"):
		var quest: Dictionary=QUEST_OWN.proof(world,uid)
		if not quest.get("ok",false):return _failure("선택 보상 퀘스트 소유 증명 불일치")
		var definition: Dictionary=D.definition_id(str(int(quest.item_class_id)))
		owned={"record":D.variant_item(definition.get("native_record",{}),int(quest.bless_code_id)),"remaining":quest.quantity,"receipt":request.quest_reward_receipt,"ownership_kind":"quest"}
	else:owned=proof(world,uid)
	if owned.is_empty() or NATIVE_FIELDS.full(owned.get("record",{})).get("source_use_spec",{}).get("kind")!="source_selectable_reward":return _failure("원문 선택 보상 소유 개체가 아닙니다")
	var pending: Dictionary=use_owned_original(world,original_item,request)
	if not pending.get("requires_original_selection",false):return pending
	var choices: Array=[]
	for reward: Dictionary in pending.choices:
		if reward.get("source_entity_id")==entity_id:choices.append(reward.duplicate(true))
	if choices.size()!=1:return _failure("현재 원문 직업·SelectRewardEntity.ID 선택 불일치")
	var selected: Dictionary=choices[0];var record: Dictionary=owned.record
	var executor: Script=load("res://scripts/loot/patch523_item_use.gd")
	record=executor.call("action_record",world,record)
	var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
	var output: Dictionary=D.definition_id(str(int(selected.get("item_class_id",0))))
	var item: Dictionary=D.variant_item(output.get("native_record",{}),int(selected.get("bless_raw",0)))
	if item.is_empty() or output.get("original_item",{}).get("TestItem")!=false or output.get("excluded",false) or not NATIVE_FIELDS.field(item,"source_condition_pending",[]).is_empty():return _failure("선택한 원문 보상 공급 정체·조건 연결 대기")
	var deadline: String=D.deadline_problem(item,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
	if not deadline.is_empty():return _failure(deadline)
	var local_initial: bool=selected.get("enchant")==null and D.equipment(item)
	if local_initial and not world.ui_preferences.get("patch523_select_reward_initial_zero_enabled",true):return _failure("선택 장비 초기 +0 자체 규칙 사용 안함 · 상자 보존")
	selected["original_initial_enchant"]=selected.get("enchant")
	selected["initial_enchant_origin"]="twilight_configured_default_zero" if local_initial else "not_equipment_initial_enchant"
	selected["enchant"]=0 # Original Reward has no initial enchant field; policy is explicit above.
	var candidate_rng:=RandomNumberGenerator.new();candidate_rng.seed=world.rng.seed;candidate_rng.state=world.rng.state
	var origin: Dictionary={"kind":"current_original_selected_reward","reward_id":spec.reward_id,"select_reward_id":spec.select_reward_id,"selection_entity_id":entity_id,"initial_enchant_origin":selected.initial_enchant_origin,"original_initial_enchant":selected.original_initial_enchant}
	var evidence: Dictionary={"original_reward":spec.original_reward.duplicate(true),"original_select_reward":spec.original_select_reward.duplicate(true),"class_id":current_class(world),"selection_entity_id":entity_id,"initial_enchant_origin":selected.initial_enchant_origin,"original_initial_enchant":selected.original_initial_enchant}
	return commit_owned_rewards(world,uid,owned,record,spec,[selected],candidate_rng,origin,evidence)

static func commit_owned_rewards(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary,rewards: Array,candidate_rng: RandomNumberGenerator,origin: Dictionary,evidence: Dictionary) -> Dictionary:
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}
	var is_quest: bool=owned.get("ownership_kind")=="quest"
	var paid: Dictionary={}
	if is_quest:
		request.erase("source_native_stack_receipt");request["quest_reward_receipt"]=owned.receipt.duplicate(true)
		paid=QUEST_CONSUME.stage(world,[request],str(SOURCE.identity().source_sha256))
	else:paid=stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","원본 상자 입력 차감 소유자 연결 필요"))))
	var view:=SupplierView.new();view.host=world;view.inventory=paid.overrides.inventory;view.item_instances=paid.overrides.item_instances;view.gold=world.gold
	var grants: Array=[]
	for reward: Dictionary in rewards:grants.append({"item_class_id":int(reward.item_class_id),"amount":int(reward.amount),"bless_raw":int(reward.bless_raw),"enchant":int(reward.enchant)})
	origin=origin.duplicate(true)
	origin.merge({"source_definition_archive":SOURCE.identity(),"input_physical_id":uid,"input_receipt":owned.receipt.duplicate(true),"input_ownership_kind":"quest" if is_quest else "native","source_rewards":rewards.duplicate(true)})
	var supplier: Script=load("res://scripts/loot/patch523_item_inventory.gd")
	var awarded: Dictionary=supplier.call("stage",view,grants,origin)
	view.free()
	if not awarded.get("ok",false):return _failure(str(awarded.get("error","원본 상자 결과 지급 후보 연결 실패")))
	var payload: Dictionary=awarded.overrides
	var weight: int=world._inventory_total_weight();var keys: Dictionary={}
	for key: String in world.inventory:keys[key]=true
	for key: String in payload.inventory:keys[key]=true
	for key: String in keys:weight+=(int(payload.inventory.get(key,0))-int(world.inventory.get(key,0)))*maxi(0,int(world.item_weight_index.get(key,3)))
	if weight>world._carrying_capacity():return _failure("기존 소지 무게 한도 초과 · 상자와 전체 결과 보존")
	var state: Dictionary=paid.overrides.get("consumable_state",world.consumable_service.export_state())
	var journal: Variant=state.get(BAG_USES,{})
	if not journal is Dictionary:return _failure("기존 원본 상자 사용 장부 형식 보존")
	journal=journal.duplicate(true);var receipt_id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while journal.has(receipt_id):receipt_id=Crypto.new().generate_random_bytes(16).hex_encode()
	var outcome: Dictionary=evidence.duplicate(true)
	outcome.merge({"schema":1,"input":paid.selections.duplicate(true),"kind":origin.kind,"source_definition_archive":SOURCE.identity(),"selected_rewards":rewards.duplicate(true),"rng_before":{"seed":str(world.rng.seed),"state":str(world.rng.state)},"rng_after":{"seed":str(candidate_rng.seed),"state":str(candidate_rng.state)}})
	journal[receipt_id]=outcome
	state[BAG_USES]=journal;payload["consumable_state"]=state
	var executor: Script=load("res://scripts/loot/patch523_item_use.gd")
	payload["item_use_cooldowns"]=executor.call("next_cooldowns",world,record,spec)
	payload["patch523_transaction_rng"]={"schema":1,"seed":str(candidate_rng.seed),"state":str(candidate_rng.state)}
	if is_quest:
		payload["quest_state"]=paid.overrides.quest_state
		if not QUEST_CONSUME.matches_payload(world,paid,payload):return _failure("원본 상자의 실제 지급 후보와 선택 사용 영수증 불일치")
	busy=true;_candidate_kind="bag_use";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind=""
	if saved!=OK:
		world.patch523_owner_state_problem="원본 상자 저장 실패·결과 미확정 · 정상 저장 불러오기 전 재개봉 중지";busy=false;return _failure(world.patch523_owner_state_problem)
	if is_quest and not world.quest_service.import_state(payload.quest_state):
		world.patch523_owner_state_problem="원본 상자 저장 후 퀘스트 영수증 채택 미확정 · 정상 저장 불러오기 필요";busy=false;return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.gold=int(payload.gold);world.item_use_cooldowns=payload.item_use_cooldowns;world.consumable_service.import_state(state)
	world.rng.seed=candidate_rng.seed;world.rng.state=candidate_rng.state;world.deferred_save.cancel();busy=false
	var sprite: int=int(spec.get("consume_effect_sprite_id",0))
	if sprite>0:world.option_awakening.combat.emit_sprite(sprite,world.player)
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"source_bag_receipt_id":receipt_id,"rewards":rewards,"message":"원본 선택 보상을 지급했습니다" if spec.kind=="source_selectable_reward" else "원본 상자 보상을 지급했습니다"}
	return committed_use_context(result,record,sprite,sprite>0,"current523_native_stack.commit_owned_rewards")


## The one registered collection card for an original BuffCard ID, bound the
## way the owned-ticket service binds pool members (deck, source ID, grade,
## merge/swap flags and registration in the card owner); {} otherwise.
static func card_binding(world: Node,category: String,card_id: int) -> Dictionary:
	var original: Dictionary=SOURCE.row("BuffCard",card_id);var found: Array=[]
	if original.is_empty():return {}
	var suffix: String=str(int(original.get("BuffCardDeckID",0)))+":"+str(card_id)
	for card: Variant in world.catalog_db.get(category,[]):
		if not card is Dictionary or int(card.get("source_card_id",0))!=card_id:continue
		if card.get("source") not in ["lineagem_base508","lineagem_patch523"] or str(card.get("sourceId","")) not in ["m508:"+suffix,"m523:"+suffix] or int(card.get("source_deck_id",0))!=int(original.BuffCardDeckID):continue
		if int(card.get("source_grade_id",0))!=int(original.GradeID) or card.get("source_merge_out_disabled",false)!=original.get("IsNoMergeOut") or card.get("source_swap_out_disabled",false)!=original.get("IsNoSwapOut"):continue
		found.append(card)
	if found.size()!=1:return {}
	var identity: String=world.card_draw_fusion.card_id(found[0])
	if not world.card_draw_fusion.known_ids.get(category,{}).has(identity):return {}
	return found[0]

## The owned physical stack of an original bless scroll, ready for one debit:
## {} when the name is not one; {"error"} when its conditions refuse it.
static func bless_scroll_owned(world: Node,scroll_name: String) -> Dictionary:
	var named: Dictionary=world._find_catalog_item_record(scroll_name)
	if profile(named).get("kind")!="bless":return {}
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return {"error":"원본 소비 저장 보호 중 · 물리 수량 보존"}
	for id: String in world.item_instances:
		var entry: Variant=world.item_instances[id]
		if not entry is Dictionary or entry.get("name")!=scroll_name or not entry.has(RECEIPT) or world._item_locked(scroll_name,id):continue
		var owned: Dictionary=proof(world,id)
		if owned.is_empty():return {"error":"원본 물리 소유·최초량·잔량 증명 불일치"}
		var problem: String=str(load("res://scripts/loot/patch523_item_use.gd").call("eligibility",world,owned.record))
		if not problem.is_empty():return {"error":problem}
		var spec: Dictionary=profile(owned.record).get("spec",{})
		if spec.get("kind")!="equipment_bless":return {"error":"원본 축복 주문서 정의 연결 필요"}
		return {"uid":id,"owned":owned,"record":owned.record,"spec":spec,"request":{"physical_id":id,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}}
	return {"error":"선택 물리 개체·잠금·소지 수량 확인 필요"}

## A weapon mastery point item: the existing mastery owner plans the original
## points for the normalized weapon type and saves them together with the
## one-unit physical debit.
static func use_mastery_points(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	if spec.get("kind")!="weapon_mastery_points" or spec.get("activation_status")!="unrestricted":return _failure("원본 숙련 아이템 정의 연결 필요")
	var requirements: Dictionary=spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or not str(requirements.get("service_region_code","")).is_empty():return _failure("원본 숙련 아이템 사용 대상·서비스 조건 미지원")
	var runtime: Variant=world.get("weapon_mastery")
	if runtime==null or not bool(runtime.enabled):return _failure("무기 숙련 원본 팩을 확인할 수 없습니다 · 아이템 보존")
	var weapon: int=int(runtime.core.normalize_weapon(int(spec.get("weapon_type",0))))
	if weapon<=0:return _failure("원본 무기 종류를 숙련에 연결할 수 없습니다 · 아이템 보존")
	var plan: Dictionary=runtime.core.plan_points(runtime.state,weapon,str(int(spec.get("points",0))),runtime._receipt("native_mastery_point_item"))
	if not plan.get("ok",false):return _failure(str(runtime.reason_text(str(plan.get("reason",""))))+" · 아이템 보존")
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}
	var paid: Dictionary=stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","원본 숙련 아이템 차감 소유자 연결 필요"))))
	var resources: Dictionary=paid.overrides.duplicate(true)
	resources["item_use_cooldowns"]=load("res://scripts/loot/patch523_item_use.gd").call("next_cooldowns",world,record,spec)
	busy=true
	var committed: Dictionary=runtime._commit(plan,resources)
	busy=false
	if not committed.get("ok",false):
		if committed.get("committed",false):world.patch523_owner_state_problem="원본 숙련 아이템 저장 후 적용 미확정 · 정상 불러오기 전 재사용 중지"
		return _failure(str(runtime.reason_text(str(committed.get("reason",""))))+" · 아이템 보존")
	world.consumable_service.import_state(resources.consumable_state);world.item_use_cooldowns=resources.item_use_cooldowns;world.deferred_save.cancel()
	var message: String="%s 사용 · 무기 숙련치 +%d" % [str(NATIVE_FIELDS.field(record,"source_display_name",record.get("name",""))),int(spec.points)]
	world.hud.append_log(message)
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"weapon_type":weapon,"points":int(spec.points),"message":message}
	return committed_use_context(result,record,0,false,"current523_native_stack.use_mastery_points")

## A card item: one physical unit is debited through its grant receipt and the
## exact original card is credited to the existing card owner in one save.
static func use_fixed_card(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	if spec.get("kind")!="fixed_card" or spec.get("activation_status")!="unrestricted":return _failure("원본 카드 아이템 정의 연결 필요")
	var requirements: Dictionary=spec.get("item_requirements",{})
	if requirements.get("targetting_type_id")!=1 or not str(requirements.get("service_region_code","")).is_empty():return _failure("원본 카드 아이템 사용 대상·서비스 조건 미지원")
	var server: Dictionary=SERVER.allows(world,spec.get("server_limit_set_id",0))
	if not server.ok:return _failure(str(server.reason)+" · 아이템 보존")
	if world.hud.has_method("is_card_reveal_busy") and world.hud.is_card_reveal_busy():return _failure("카드 결과 연출 중 · 아이템 보존")
	var category: String=str(spec.get("card_kind",""));var card_id: int=int(spec.get("card_id",0))
	if SOURCE.row("BuffCard",card_id)!=spec.get("original_card"):return _failure("원본 카드 정의 변경 감지 · 아이템 보존")
	var card: Dictionary=card_binding(world,category,card_id)
	if card.is_empty():return _failure("지급할 원본 카드 자료가 미설치 상태입니다 · 아이템 보존")
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1,"source_native_stack_receipt":owned.receipt.duplicate(true)}
	var paid: Dictionary=stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason",paid.get("error","원본 카드 아이템 차감 소유자 연결 필요"))))
	var scratch: Object=preload("res://scripts/card_draw_fusion.gd").new()
	scratch.configure(world.catalog_db);scratch.import_state(world.card_draw_fusion.export_state())
	var outcome: Dictionary=scratch.receive_source_card(category,card,{"source_snapshot":"patch523","item_class_id":int(record.source_item_class_id),"card_id":card_id,"buff_card_cannot_swap":bool(spec.get("buff_card_cannot_swap",false)),"bless":int(record.get("source_bless_raw",1)),"input_physical_id":uid,"input_receipt":owned.receipt.duplicate(true)})
	if not outcome.get("ok",false):return _failure(str(outcome.get("error","원본 카드 지급 실패"))+" · 아이템 보존")
	var payload: Dictionary=paid.overrides.duplicate(true)
	payload["card_draw_fusion"]=scratch.export_state()
	payload["item_use_cooldowns"]=load("res://scripts/loot/patch523_item_use.gd").call("next_cooldowns",world,record,spec)
	busy=true
	var saved: Error=world._save_game(true,payload)
	busy=false
	if saved!=OK:
		world.patch523_owner_state_problem="원본 카드 아이템 저장 결과 미확정 · 정상 불러오기 전 재사용 중지";return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.item_use_cooldowns=payload.item_use_cooldowns;world.consumable_service.import_state(payload.consumable_state)
	world.card_draw_fusion.import_state(payload.card_draw_fusion);world.deferred_save.cancel()
	world._invalidate_equipment_static()
	if world.get("card_collections")!=null:world.card_collections.invalidate()
	var message: String="원본 지정 카드 지급 · %s (%s)" % [str(card.get("name","")),category]
	world.hud.append_log(message)
	var sprite: int=int(spec.get("consume_effect_sprite_id",0))
	if sprite>0:world.option_awakening.combat.emit_sprite(sprite,world.player)
	world.hud.set_card_draw_fusion_result(category,message)
	world.hud.present_card_reveal(category,outcome,false)
	var result: Dictionary={"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"category":category,"card_id":card_id,"results":outcome.results,"message":message}
	return committed_use_context(result,record,sprite,sprite>0,"current523_native_stack.use_fixed_card")

static func native_ammo(record: Dictionary) -> bool:
	return profile(record).get("kind")=="ammo"

# A consumer view only. A raw quest record is never renamed, registered as a
# native physical grant or copied over its original saved instance.
static func ammo_owned(world: Node,uid: String) -> Dictionary:
	var owned: Dictionary=proof(world,uid)
	if not owned.is_empty() and native_ammo(owned.record):
		owned["inventory_key"]=str(owned.record.name);owned["ownership_kind"]="native";return owned
	var quest: Dictionary=QUEST_OWN.proof(world,uid)
	if not quest.get("ok",false) or quest.get("source_use_immediately",true) or quest.get("source_sha256")!=SOURCE.identity().get("source_sha256") or quest.source_item!=SOURCE.row("ItemClass",int(quest.item_class_id)):return {}
	var definition: Dictionary=D.definition_id(str(int(quest.item_class_id)))
	var record: Dictionary=D.variant_item(definition.get("native_record",{}),int(quest.bless_code_id))
	if not native_ammo(record):return {}
	return {"record":record,"remaining":int(quest.quantity),"receipt":world.item_instances[uid].quest_reward_receipt.duplicate(true),"inventory_key":str(quest.inventory_key),"ownership_kind":"quest"}

static func ammo_record(world: Node,name_value: String) -> Dictionary:
	var selected: Variant=world.consumable_service.export_state().get(AMMO_EQUIPPED,{})
	if selected is Dictionary and selected.get("name")==name_value and selected.get("ownership_kind")=="quest":
		var owned: Dictionary=ammo_owned(world,str(selected.get("physical_id","")))
		if not owned.is_empty() and owned.inventory_key==name_value and owned.receipt==selected.get("receipt"):return owned.record
		return {} # Invalid selected raw ownership cannot fall through to a legacy alias.
	return world._find_catalog_item_record(name_value)

static func quest_ammo_state_error(instances: Dictionary,state: Dictionary,selected: Dictionary) -> String:
	if selected.size()!=4 or not selected.get("physical_id") is String or not selected.get("name") is String or not selected.get("receipt") is Dictionary:return "퀘스트 탄약 선택 증명 형식 확인 필요"
	var uid: String=selected.physical_id;var physical: Variant=instances.get(uid)
	if not physical is Dictionary:return "착용한 원본 퀘스트 탄약 소지 개체가 없습니다"
	var receipt: Dictionary=selected.receipt;var record: Variant=physical.get("record")
	if not record is Dictionary or physical.get("quest_reward_receipt")!=receipt or physical.get("name")!=selected.name or record.get("name")!=selected.name or physical.get("level",0)!=0 or record.get("source_pending_use")!=true or record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523" or record.get("source_use_immediately")!=false:return "원본 퀘스트 탄약 소지 키·출처·영수증 보존 필요"
	var id: Variant=receipt.get("item_class_id");var remaining: Variant=physical.get("source_reward_quantity")
	if not integer(id) or int(id)<=0 or receipt.get("schema")!=1 or receipt.get("source_sha256")!=SOURCE.identity().get("source_sha256") or record.get("source_item_class_id")!=id or record.get("sourceId")!="m523:item:"+str(int(id)) or receipt.get("reward_id")!=record.get("source_reward_id") or receipt.get("bless_code_id")!=record.get("source_bless_code_id") or not integer(receipt.get("quantity")) or not integer(remaining) or int(remaining)<1 or int(remaining)>int(receipt.quantity):return "원본 퀘스트 탄약 지급량·잔량·품목 정체 불일치"
	var definition: Dictionary=D.definition_id(str(int(id)))
	if NATIVE_FIELDS.full(record).get("source_original_item")!=definition.get("original_item") or not native_ammo(D.variant_item(definition.get("native_record",{}),int(receipt.get("bless_code_id",0)))):return "원본 퀘스트 탄약 전체 행·효과 계약 불일치"
	# Complete claimed/reward ancestry and item_grants.used_quantity remain the
	# common quest save owner, and are rechecked by ammo_owned at each action.
	return ""

static func ammo_worn(world: Node,name_value: String) -> bool:
	var selected: Variant=world.consumable_service.export_state().get(AMMO_EQUIPPED,{})
	if not selected is Dictionary or selected.is_empty() or world.equipped_ammo!=name_value or world.ammo_unequipped or selected.get("name")!=name_value:return false
	var owned: Dictionary=ammo_owned(world,str(selected.get("physical_id","")))
	return not owned.is_empty() and native_ammo(owned.record) and owned.inventory_key==name_value and owned.receipt==selected.get("receipt") and not world._item_locked(name_value) and not world._item_locked(name_value,str(selected.physical_id))

static func equip_ammo(world: Node,name_value: String,selected_id: String="") -> Dictionary:
	var record: Dictionary=world._find_catalog_item_record(name_value)
	var state: Dictionary=world.consumable_service.export_state();var previous: Variant=state.get(AMMO_EQUIPPED,{})
	if not selected_id.is_empty():
		var requested: Dictionary=ammo_owned(world,selected_id)
		if not requested.is_empty() and requested.inventory_key==name_value:record=requested.record
	elif previous is Dictionary and previous.get("name")==name_value and previous.get("ownership_kind")=="quest":
		selected_id=str(previous.get("physical_id",""));record=ammo_record(world,name_value)
	var native: bool=native_ammo(record)
	if not native and previous=={}:return {"handled":false}
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty():return _failure("원본 탄약 저장 보호 중")
	if not previous is Dictionary or not world._is_ammo_record(record) or not integer(world.inventory.get(name_value,0)) or int(world.inventory.get(name_value,0))<1:return _failure("실제 소지 탄약 정체·수량 불일치")
	var next_name: String="" if world.equipped_ammo==name_value else name_value
	var next: Dictionary={}
	if native:
		var candidates: Array=[]
		for uid: String in world.item_instances:
			if not selected_id.is_empty() and selected_id!=uid:continue
			var owned: Dictionary=ammo_owned(world,uid)
			if not owned.is_empty() and owned.inventory_key==name_value and native_ammo(owned.record):candidates.append({"id":uid,"owned":owned})
		if candidates.size()!=1:return _failure("착용할 원본 탄약의 실제 물리 개체를 선택하세요 · 자동 대체하지 않습니다")
		var chosen: Dictionary=candidates[0];var owned: Dictionary=chosen.owned
		if world._item_locked(name_value) or world._item_locked(name_value,str(chosen.id)):return _failure("원본 탄약 잠금 상태")
		var issue: String=load("res://scripts/loot/patch523_item_use.gd").call("eligibility",world,owned.record)
		if not issue.is_empty():return _failure(issue)
		if world.equipped_ammo!=name_value or previous.get("physical_id")!=chosen.id:
			next_name=name_value;next={"physical_id":chosen.id,"name":name_value,"receipt":owned.receipt.duplicate(true)}
			if owned.ownership_kind=="quest":next["ownership_kind"]="quest"
	state[AMMO_EQUIPPED]=next
	var payload: Dictionary={"consumable_state":state,"equipped_ammo":next_name,"ammo_unequipped":next_name.is_empty()}
	busy=true;_candidate_kind="ammo_equip";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:
		world.patch523_owner_state_problem="원본 탄약 착용 저장 결과 미확정 · 정상 불러오기 전 재시도 중지";return _failure(world.patch523_owner_state_problem)
	world.equipped_ammo=next_name;world.ammo_unequipped=next_name.is_empty();world.consumable_service.import_state(state);world.deferred_save.cancel()
	return {"handled":true,"ok":true,"saved":true,"consumed":0,"message":"원본 탄약 착용 해제" if next_name.is_empty() else next_name+" 착용 · 실제 소지 개체 선택 보존"}

# Existing shots/skills supply their established ammo cost; no new hit/cost
# formulas. MP and the exact selected physical remainder share this save.
static func consume_ammo(world: Node,name_value: String,quantity: int,mp_cost: int=0,target: Node=null,roll_damage: bool=false,additional_cost: Dictionary={}) -> Dictionary:
	if not native_ammo(ammo_record(world,name_value)):
		var claimed: Variant=world.consumable_service.export_state().get(AMMO_EQUIPPED,{})
		var raw: Dictionary=world._find_catalog_item_record(name_value)
		if (claimed is Dictionary and not claimed.is_empty() and claimed.get("name")==name_value) or (raw.get("source_projection")=="current523_original_typed_game_dto_v1" and NATIVE_FIELDS.field(raw,"source_category_name") in ["Arrow","Bullet","Sting"]):return _failure("선택한 원본 탄약의 현재 소유·정체가 미확인입니다 · 이름 기반 차감으로 대체하지 않습니다")
		return {"handled":false}
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty() or world.hp<=0 or not world._patch523_item_allowed():return _failure("원본 탄약 사용·저장 보호 중")
	var hp_cost: int=0;var legacy_spent: Dictionary={}
	if not additional_cost.is_empty():
		if additional_cost.size() not in [3,4,5] or (additional_cost.size()>=4 and not additional_cost.get("material_requests") is Array) or (additional_cost.size()==5 and not additional_cost.get("resolved_skill") is Dictionary) or not integer(additional_cost.get("hp_cost")) or not additional_cost.get("legacy_spent") is Dictionary or not additional_cost.get("skill_id") is String or str(additional_cost.skill_id).is_empty() or roll_damage:return _failure("기존 스킬 비용 공동 후보 형식 불일치")
		hp_cost=int(additional_cost.hp_cost);legacy_spent=additional_cost.legacy_spent
		if additional_cost.has("resolved_skill"):
			var actual: Dictionary=additional_cost.resolved_skill
			if world.original_skills==null or actual.get("id")!=additional_cost.skill_id or actual.get("mp",0)!=mp_cost or actual.get("hp",0)!=hp_cost:return _failure("실제 기존 스킬 비용 정체 변경")
			var fresh: Dictionary=world.original_skills.material_plan(actual)
			if not str(fresh.get("reason","")).is_empty() or fresh.get("spent")!=legacy_spent or fresh.get("physical_materials",[])!=additional_cost.get("material_requests",[]) or fresh.get("physical_ammo",{}).get("inventory_key")!=name_value or fresh.physical_ammo.get("quantity")!=quantity:return _failure("스킬의 현재 실제 재료·탄약 견적 변경 · 비용 보존")
	if world.hp<=hp_cost:return _failure("스킬 HP 부족 · 탄약과 MP 보존")
	if quantity<1 or mp_cost<0 or world.mp<mp_cost or not ammo_worn(world,name_value) or world._current_ammo_name()!=name_value:return _failure("선택한 원본 탄약·MP·착용 조건 불일치")
	var selected: Dictionary=world.consumable_service.export_state()[AMMO_EQUIPPED]
	var uid: String=selected.physical_id;var owned: Dictionary=ammo_owned(world,uid)
	if owned.is_empty() or int(owned.remaining)<quantity:return _failure("선택한 물리 탄약 잔량 부족 · 다른 개체를 대신 소비하지 않습니다")
	var issue: String=load("res://scripts/loot/patch523_item_use.gd").call("eligibility",world,owned.record)
	if not issue.is_empty():return _failure(issue)
	var is_quest: bool=owned.get("ownership_kind")=="quest"
	var request: Dictionary={"physical_id":uid,"quantity":quantity,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-quantity}
	request["quest_reward_receipt" if is_quest else RECEIPT]=owned.receipt.duplicate(true)
	var requests: Array=[request];requests.append_array(additional_cost.get("material_requests",[]))
	var paid: Dictionary=stage_owned_debits(world,requests)
	if not paid.get("ok",false):return _failure(str(paid.get("reason","원본 탄약 공동 차감 후보 연결 대기")))
	var private_before: Variant=world.consumable_service.export_state().get(AMMO_RNG,{})
	if not private_before is Dictionary:return _failure("원본 탄약 독립 난수 저장 형식 보존 필요")
	var candidate_rng:=RandomNumberGenerator.new()
	if private_before.is_empty():
		# Host implementation stream, not a native probability/seed claim.
		candidate_rng.seed=(str(world.rng.seed)+":current523.ammunition.v1").sha256_text().substr(0,15).hex_to_int()
	else:
		if private_before.get("schema")!=1 or not private_before.get("seed") is String or not private_before.get("state") is String or not str(private_before.seed).is_valid_int() or not str(private_before.state).is_valid_int():return _failure("원본 탄약 독립 난수 상태 불일치")
		candidate_rng.seed=int(private_before.seed);candidate_rng.state=int(private_before.state)
	var damage: int=0;var size_class: String="";var policy: String=str(world.ui_preferences.get("patch523_ammo_damage_rule","uniform"))
	if roll_damage:
		if not is_instance_valid(target):return _failure("원본 탄약 발사 대상 없음 · 수량 보존")
		size_class=str(target.get_meta("size_class","small")).to_lower()
		var ammo: Dictionary=profile(owned.record).spec
		var maximum: int=int(ammo.get("large_damage" if size_class=="large" else "small_damage",0))
		if policy=="maximum":damage=maximum
		elif policy!="disabled":damage=candidate_rng.randi_range(1,maximum) if maximum>0 else 0
	var payload: Dictionary=paid.overrides;var state: Dictionary=payload.get("consumable_state",world.consumable_service.export_state())
	payload["consumable_state"]=state
	# Additional existing skill materials are debited from the already paid
	# ammo candidate, never merged from another whole inventory snapshot.
	for key: String in legacy_spent:
		var amount: Variant=legacy_spent[key]
		if key==name_value or not integer(amount) or int(amount)<1 or not integer(payload.inventory.get(key,0)) or int(payload.inventory.get(key,0))<int(amount) or world._item_locked(key):return _failure("스킬 기존 재료 수량·잠금·중복 차감 조건 불일치")
		for physical: Variant in world.item_instances.values():
			if physical is Dictionary and physical.get("name")==key and (physical.has(RECEIPT) or physical.has("quest_reward_receipt")):return _failure("이 스킬 재료는 별도의 정확한 물리 개체 소비 계약 필요 · 비용 보존")
		payload.inventory[key]=int(payload.inventory[key])-int(amount)
		if payload.inventory[key]==0:payload.inventory.erase(key)
	payload["hp"]=int(world.hp)-hp_cost
	if int(owned.remaining)==quantity:
		state[AMMO_EQUIPPED]={};payload["equipped_ammo"]="";payload["ammo_unequipped"]=true
	var journal: Variant=state.get(AMMO_USES,{})
	if not journal is Dictionary:return _failure("기존 원본 탄약 발사 장부 보존")
	journal=journal.duplicate(true);var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while journal.has(id):id=Crypto.new().generate_random_bytes(16).hex_encode()
	var recorded_cost: Dictionary=additional_cost.duplicate(true)
	if recorded_cost.has("resolved_skill"):
		recorded_cost["resolved_skill_quote_sha256"]=JSON.stringify(recorded_cost.resolved_skill,"",true,true).sha256_text();recorded_cost.erase("resolved_skill")
	journal[id]={"schema":1,"input":paid.selections.duplicate(true),"source_definition_archive":SOURCE.identity(),"quantity":quantity,"mp_cost":mp_cost,"additional_existing_skill_cost":recorded_cost,"damage_bonus":damage,"damage_origin":"existing_TWILIGHT_ammo_damage_policy" if roll_damage else "skill_does_not_add_new_ammo_damage","damage_policy":policy,"target_size":size_class,"rng_domain":"TWILIGHT_source_native_ammo_independent_v1","rng_before":private_before.duplicate(true),"rng_after":{"seed":str(candidate_rng.seed),"state":str(candidate_rng.state)}}
	state[AMMO_USES]=journal;payload["mp"]=int(world.mp)-mp_cost
	if roll_damage:state[AMMO_RNG]={"schema":1,"seed":str(candidate_rng.seed),"state":str(candidate_rng.state)}
	if not paid.quest_step.is_empty() and not QUEST_CONSUME.matches_payload(world,paid.quest_step,payload):return _failure("퀘스트 탄약 잔량·최초 사용 증명·MP 결과 공동 후보 불일치")
	busy=true;_candidate_kind="ammo_consume";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:
		world.patch523_owner_state_problem="원본 탄약 발사 저장 실패·결과 미확정 · 정상 불러오기 전 재발사 중지";return _failure(world.patch523_owner_state_problem)
	if payload.has("quest_state") and not world.quest_service.import_state(payload.quest_state):
		world.patch523_owner_state_problem="퀘스트 탄약 저장 후 장부 채택 미확정 · 정상 불러오기 전 재시도 중지";return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.mp=int(payload.mp);world.hp=int(payload.hp);world.consumable_service.import_state(state)
	if payload.has("equipped_ammo"):world.equipped_ammo=payload.equipped_ammo;world.ammo_unequipped=payload.ammo_unequipped
	world.deferred_save.cancel() # Ordinary combat/draw RNG is not advanced by this owner.
	return {"handled":true,"ok":true,"saved":true,"consumed":quantity,"physical_id":uid,"remaining_quantity":int(owned.remaining)-quantity,"source_ammo_receipt_id":id,"damage_bonus":damage,"message":"원본 물리 탄약·MP·발사 기록 저장"}


static func learn_skill_book(world: Node,uid: String,owned: Dictionary,record: Dictionary,spec: Dictionary) -> Dictionary:
	# Existing skill catalog/engine owns execution. Only exact known current
	# learning can be joined with this quantity owner's selected physical debit.
	if spec.get("kind")!="source_skill_book" or spec.get("activation_status")!="unrestricted" or world.original_skills==null:return _failure("현재 원문 스킬서·학습 소유자 연결 필요")
	var server: Dictionary=SERVER.allows(world,spec.get("server_limit_set_id",0))
	if not server.ok:return _failure(str(server.reason)+" · 스킬서 보존")
	if current_class(world)<=0:return _failure("원문 스킬서의 실제 현재 직업 정체 연결 필요")
	var book: Script=load("res://scripts/loot/patch523_skill_book.gd")
	var issue: String=book.call("source_limit_problem",world,spec)
	if not issue.is_empty():return _failure(issue+" · 현재 학습/실행 의존 미충족")
	var catalog: Object=world.original_skills.catalog;var adapter: Object=book.call("_adapter",catalog)
	if adapter==null or adapter.get_script()!=preload("res://scripts/skills/player_skills523.gd"):return _failure("현재 원문 스킬 프로필 소유자 미설치")
	var evidence: Dictionary={}
	if adapter.get("source_mode")=="original_bound_profiles":
		var original: Variant=adapter.get("source_identity")
		if not original is Dictionary or original.get("source_snapshot")!="patch523" or original.get("source_sha256")!=SOURCE.identity().get("source_sha256") or original.get("source_bytes")!=25031173:return _failure("실제 원문 스킬 프로필 출처 불일치")
		evidence={"kind":"original_bound_profiles","source_sha256":SOURCE.identity().source_sha256,"source_identity":original.duplicate(true)}
	else:
		# No old card/monster input is used; this is the already reviewed new
		# original441-profile skill input, kept distinct from an archive reader.
		if adapter.get("source_mode")!="compiled_pack" or adapter.get("active_sha256")!="256f0ba0944e05b86134b40ed3aea97c71e1073b3947ea6e46cb018b6179926a":return _failure("정확한 새 원문 스킬 프로필 입력 필요")
		evidence={"kind":"compiled_pack","source_sha256":SOURCE.identity().source_sha256,"skill_pack_sha256":str(adapter.get("active_sha256"))}
	var bindings_sha: String=FileAccess.get_file_as_string("res://data/skills/player_skills523_bindings.json").sha256_text()
	if bindings_sha!="497a594e7312ce98dd966b737b1bfb4555072af3c0d5b63d61b8ee2c33075346":return _failure("기존 공개 스킬 바인딩 정체 변경 · 스킬서 보존")
	evidence["binding_sha256"]=bindings_sha;evidence["item_definition_archive"]=SOURCE.identity()
	var identity: Dictionary=book.call("resolve",adapter,spec)
	if identity.is_empty() or identity.get("profile",{}).get("row")!=SOURCE.row("SpellClass",int(spec.spell_class_id)):return _failure("정확한 SpellClass ID·원문 행 SHA·기존 학습 ID 연결 필요")
	var key: String=str(identity.local_skill_id);var skill: Dictionary=catalog.record_for(key)
	if skill.get("id")!=key:return _failure("기존 등록 스킬 정체 불일치")
	var reference: Script=load("res://scripts/quests/quest_reference_learning.gd")
	var learning_only: bool=reference.call("matches",int(record.source_item_class_id),int(spec.spell_class_id),key,str(spec.source_spell_row_sha256))
	if learning_only:
		if catalog.learned.has(key) and catalog.learned[key]!=0:return _failure("이미 학습 기록이 있습니다")
		if not catalog.permitted(skill) or world.level<catalog.minimum_level_for(skill):return _failure("기존 스킬 직업·학습 레벨 조건 미충족")
		for required: String in catalog.relations.get(key,{}).get("requires_skill",[]):
			if int(catalog.learned.get(required,0))<int(catalog.relations[key].get("requires_skill_level",{}).get(required,1)):return _failure("기존 선행 스킬 조건 미충족")
	else:
		if skill.get("runtime_blocked",false):return _failure("현재 주문 실행 소유자 미지원 · 스킬서 보존")
		issue=catalog.reason(skill,true)
		if not issue.is_empty():return _failure(issue)
	var is_quest: bool=owned.get("ownership_kind")=="quest"
	var request: Dictionary={"physical_id":uid,"quantity":1,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-1}
	request["quest_reward_receipt" if is_quest else RECEIPT]=owned.receipt.duplicate(true)
	var paid: Dictionary=QUEST_CONSUME.stage(world,[request],str(SOURCE.identity().source_sha256)) if is_quest else stage_debit(world,[request])
	if not paid.get("ok",false):return _failure(str(paid.get("reason","선택 원문 스킬서 차감 후보 연결 대기")))
	var state: Dictionary=paid.overrides.get("consumable_state",world.consumable_service.export_state())
	var receipts: Variant=state.get("source_skill_book_receipts",[])
	if not receipts is Array:return _failure("기존 스킬서 학습 영수증 보존 필요")
	var learned: Dictionary=catalog.export_state();learned.learned[key]=1
	var learning_record: Dictionary={}
	if learning_only:
		learning_record=reference.call("make_record",world,int(record.source_item_class_id),evidence)
		if not learned.has("source_quest_knowledge"):learned["source_quest_knowledge"]={}
		learned.source_quest_knowledge[key]=learning_record.duplicate(true)
	receipts=receipts.duplicate(true)
	var input_proof: Dictionary={"physical_id":uid,"remaining_before":owned.remaining,"ownership_kind":"quest" if is_quest else "native"}
	input_proof["quest_reward_receipt" if is_quest else RECEIPT]=owned.receipt.duplicate(true)
	var receipt: Dictionary={"source_snapshot":"patch523","source_sha256":SOURCE.identity().source_sha256,"item_definition_archive":SOURCE.identity(),"item_class_id":int(record.source_item_class_id),"bless_raw":int(record.source_bless_raw),"card_id":int(spec.card_id),"spell_class_id":int(spec.spell_class_id),"spell_row_sha256":str(spec.source_spell_row_sha256),"local_skill_id":key,"skill_source_evidence":evidence,"cannot_swap":bool(spec.get("buff_card_cannot_swap",false)),"cannot_stack_card":bool(spec.get("cannot_stack_card",false)),"input":input_proof}
	if learning_only:receipt["source_learning_record"]=learning_record.duplicate(true)
	receipts.append(receipt);state["source_skill_book_receipts"]=receipts
	var payload: Dictionary=paid.overrides;payload["consumable_state"]=state;payload["original_skill_state"]=learned;payload["item_use_cooldowns"]=load("res://scripts/loot/patch523_item_use.gd").call("next_cooldowns",world,record,spec)
	# Learning/profiles were only quoted above. The shared existing skill
	# catalog state is changed after the exact physical/debit save succeeds.
	if is_quest and not QUEST_CONSUME.matches_payload(world,paid,payload):return _failure("퀘스트 스킬서의 실제 잔량·학습·사용 장부 후보 불일치")
	busy=true;_candidate_kind="skill_book_use";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:
		world.patch523_owner_state_problem="원문 스킬서 저장 결과 미확정 · 정상 불러오기 전 재학습 중지";return _failure(world.patch523_owner_state_problem)
	if is_quest and not world.quest_service.import_state(payload.quest_state):
		world.patch523_owner_state_problem="퀘스트 스킬서 저장 후 장부 채택 미확정 · 정상 불러오기 전 재학습 중지";return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.item_use_cooldowns=payload.item_use_cooldowns;world.consumable_service.import_state(state)
	catalog.source_quest_knowledge=learned.get("source_quest_knowledge",{}).duplicate(true);catalog.learned=learned.learned.duplicate(true);catalog.revision+=1
	world.original_skills.refresh_buffs_after_learning(key);world._refresh_speed_modifiers();world.deferred_save.cancel()
	return {"handled":true,"ok":true,"saved":true,"consumed":1,"physical_id":uid,"remaining_quantity":int(owned.remaining)-1,"local_skill_id":key,"learning_only":learning_only,"execution_allowed":not learning_only,"message":str(skill.get("name",key))+" 원문 학습 완료 · 실행 대기" if learning_only else str(skill.get("name",key))+" 습득"}


# The existing skill items keys distinguish arrow/bullet cost roles. Their
# selected actual physical item still needs the current gameplay category and
# immutable ownership proof; no spell material or source ID is inferred by name.
static func original_skill_ammo(world: Node,cost_key: String,quantity: int) -> Dictionary:
	if cost_key not in ["화살","총알"] or quantity==0:return {"handled":false}
	var selected: Variant=world.consumable_service.export_state().get(AMMO_EQUIPPED,{})
	if selected=={}:return {"handled":false}
	if not selected is Dictionary or quantity<1:return _failure("선택한 원문 스킬 탄약 증명 형식 불일치")
	var key: String=str(selected.get("name",""));var owned: Dictionary=ammo_owned(world,str(selected.get("physical_id","")))
	var category: String="Arrow" if cost_key=="화살" else "Bullet"
	if owned.is_empty() or owned.inventory_key!=key or owned.receipt!=selected.get("receipt") or NATIVE_FIELDS.field(owned.record,"source_category_name")!=category or not ammo_worn(world,key) or world._current_ammo_name()!=key or quantity>int(owned.remaining):return _failure("선택 원문 탄약의 실제 개체·종류·잔량·착용 조건 미충족")
	return {"handled":true,"ok":true,"inventory_key":key,"physical_id":selected.physical_id,"quantity":quantity,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-quantity,"receipt":owned.receipt.duplicate(true),"ownership_kind":owned.ownership_kind,"cost_role":cost_key}


static func spell_material_profile(record: Dictionary) -> Dictionary:
	if record.get("source_m_native_item")!=true or record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523" or not D.currency_identity_name(record).is_empty():return {} # Currency wallets keep their existing separate owner.
	if record.get("source_projection")!="current523_original_typed_game_dto_v1" or record.get("source_definition_archive")!=SOURCE.identity() or record.get("source_test_item")!=false or record.get("source_bless_raw")!=1 or D.equipment(record) or not record.get("source_condition_pending",[]).is_empty() or record.get("source_delete_time_unresolved",false):return {}
	var text: String=FileAccess.get_file_as_string("res://data/skills/player_skills523_bindings.json")
	if text.sha256_text()!="497a594e7312ce98dd966b737b1bfb4555072af3c0d5b63d61b8ee2c33075346":return {}
	var bindings: Variant=JSON.parse_string(text)
	if not bindings is Dictionary or not bindings.get("material_inventory_keys") is Dictionary:return {}
	var definition: Dictionary=D.current_original_definition(record)
	if definition.is_empty():return {}
	var matches: Array=[]
	for type_id: String in bindings.material_inventory_keys:
		var bridge: Variant=bindings.material_inventory_keys[type_id]
		if not bridge is Dictionary or bridge.get("native_item_id")!=record.get("source_item_class_id"):continue
		for row: Dictionary in definition.get("item_bonus",[]):
			if row.get("IsPossession")==false and row.get("bonus",{}).get("BonusTypeID")==89 and row.bonus.get("BonusApplicationTypeID")==0 and row.bonus.get("BonusApplicationTargetID")==0 and integer(row.bonus.get("Value")) and str(int(row.bonus.Value))==type_id:matches.append(type_id)
	return {"kind":"spell_material","spell_material_type_ids":matches,"standalone_effect_complete":false} if not matches.is_empty() else {}

static func material_owned(world: Node,uid: String) -> Dictionary:
	var owned: Dictionary=proof(world,uid)
	if not owned.is_empty():
		owned["inventory_key"]=str(owned.record.name);owned["ownership_kind"]="native";return owned
	var quest: Dictionary=QUEST_OWN.proof(world,uid)
	if not quest.get("ok",false) or quest.get("source_use_immediately",true) or quest.get("source_sha256")!=SOURCE.identity().get("source_sha256") or quest.source_item!=SOURCE.row("ItemClass",int(quest.item_class_id)):return {}
	var definition: Dictionary=D.definition_id(str(int(quest.item_class_id)));var record: Dictionary=D.variant_item(definition.get("native_record",{}),int(quest.bless_code_id))
	if supply_profile(record).is_empty():return {}
	return {"record":record,"remaining":int(quest.quantity),"receipt":world.item_instances[uid].quest_reward_receipt.duplicate(true),"inventory_key":str(quest.inventory_key),"ownership_kind":"quest"}

static func plan_spell_material(world: Node,skill: Dictionary,cost_key: String,quantity: int) -> Dictionary:
	if quantity<1 or not skill.get("source523",{}).get("applied",[]).has("materials") or world.original_skills==null:return {"handled":false}
	var adapter: Object=world.original_skills.catalog.source523
	var text: String=FileAccess.get_file_as_string("res://data/skills/player_skills523_bindings.json")
	var public: Variant=JSON.parse_string(text)
	if text.sha256_text()!="497a594e7312ce98dd966b737b1bfb4555072af3c0d5b63d61b8ee2c33075346" or not public is Dictionary or adapter.bindings!=public or not adapter._source_materials(public):return _failure("원문 스킬 재료의 실제 공개 연결·전체 원문 정체 확인 필요")
	var ids: Array=[]
	for bridge: Variant in public.get("material_inventory_keys",{}).values():
		if bridge is Dictionary and bridge.get("inventory_key")==cost_key and bridge.get("native_item_id") not in ids:ids.append(bridge.get("native_item_id"))
	if ids.size()!=1:return {"handled":false}
	var remaining: int=quantity;var requests: Array=[];var physical_ids: Array=world.item_instances.keys();physical_ids.sort()
	# Deterministic host custody selection, not native material/odds semantics.
	# Every chosen ID is recorded with exact proof/remaining and consumed as quoted.
	for uid: String in physical_ids:
		var owned: Dictionary=material_owned(world,uid)
		if owned.is_empty() or owned.record.get("source_item_class_id")!=ids[0] or owned.record.get("source_bless_raw")!=1 or spell_material_profile(owned.record).is_empty():continue
		if world._item_locked(str(owned.inventory_key)) or world._item_locked(str(owned.inventory_key),uid):continue
		if not str(load("res://scripts/loot/patch523_item_use.gd").call("eligibility",world,owned.record)).is_empty():continue
		var amount: int=mini(remaining,int(owned.remaining))
		var request: Dictionary={"physical_id":uid,"quantity":amount,"expected_quantity":owned.remaining,"expected_remaining":int(owned.remaining)-amount}
		request["quest_reward_receipt" if owned.ownership_kind=="quest" else RECEIPT]=owned.receipt.duplicate(true)
		requests.append(request);remaining-=amount
		if remaining==0:break
	if remaining>0:return _failure("정확한 원문 스킬 재료 소지 개체·잔량 부족 · 기존 비용 보존")
	return {"handled":true,"ok":true,"requests":requests,"native_item_id":ids[0],"cost_role":cost_key,"quantity":quantity,"selection_policy":"TWILIGHT_exact_proven_physical_id_order"}

static func stage_owned_debits(world: Node,requests: Array) -> Dictionary:
	var native_requests: Array=[];var quest_requests: Array=[];var seen: Dictionary={}
	for request: Variant in requests:
		if not request is Dictionary or request.size()!=5 or not request.get("physical_id") is String or seen.has(request.physical_id):return _failure("공동 스킬 재료 물리 요청·중복 정체 불일치")
		seen[request.physical_id]=true
		if request.has("quest_reward_receipt"):quest_requests.append(request)
		else:native_requests.append(request)
	var native: Dictionary=stage_debit(world,native_requests) if not native_requests.is_empty() else {}
	if not native_requests.is_empty() and not native.get("ok",false):return native
	var quest: Dictionary=QUEST_CONSUME.stage(world,quest_requests,str(SOURCE.identity().source_sha256)) if not quest_requests.is_empty() else {}
	if not quest_requests.is_empty() and not quest.get("ok",false):return _failure(str(quest.get("reason","공동 퀘스트 재료 차감 증명 불일치")))
	var bag: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true);var selected: Array=[]
	# Join only the exact selected physical edits. Never merge two full owner
	# inventory candidates over each other or consume an unquoted legacy object.
	for request: Dictionary in requests:
		var uid: String=request.physical_id;var name_value: String=str(world.item_instances[uid].name)
		if not integer(bag.get(name_value,0)) or int(bag[name_value])<int(request.quantity):return _failure("공동 재료 인벤토리 차감 수량 불일치")
		bag[name_value]=int(bag[name_value])-int(request.quantity)
		if bag[name_value]==0:bag.erase(name_value)
		var branch: Dictionary=quest if request.has("quest_reward_receipt") else native
		if branch.overrides.item_instances.has(uid):instances[uid]=branch.overrides.item_instances[uid].duplicate(true)
		else:instances.erase(uid)
	selected.append_array(native.get("selections",[]));selected.append_array(quest.get("selections",[]))
	var result: Dictionary={"inventory":bag,"item_instances":instances,"consumable_state":native.get("overrides",{}).get("consumable_state",world.consumable_service.export_state())}
	if not quest.is_empty():result["quest_state"]=quest.overrides.quest_state
	return {"ok":true,"overrides":result,"selections":selected,"quest_step":quest,"use_authorized":false}

static func spend_original_skill_materials(world: Node,skill: Dictionary,plan: Dictionary) -> Dictionary:
	var requests: Array=plan.get("physical_materials",[])
	if requests.is_empty():return {"handled":false}
	if world.original_skills==null or world.original_skills.material_plan(skill)!=plan:return _failure("현재 실제 스킬 재료 견적·소지 선택 변경")
	if not plan.get("physical_ammo",{}).is_empty():return _failure("스킬 탄약과 원문 재료 공동 비용은 탄약 소비 소유자로 전달해야 합니다")
	if busy or world.quest_service.save_blocked or not str(world.patch523_owner_state_problem).is_empty() or world.hp<=0 or not world._patch523_item_allowed():return _failure("원문 스킬 재료 소비 저장 보호 중")
	var mp_cost: Variant=skill.get("mp",0);var hp_cost: Variant=skill.get("hp",0)
	if not integer(mp_cost) or not integer(hp_cost) or world.mp<int(mp_cost) or world.hp<=int(hp_cost):return _failure("기존 스킬 MP·HP 비용 미충족")
	var paid: Dictionary=stage_owned_debits(world,requests)
	if not paid.get("ok",false):return paid
	var payload: Dictionary=paid.overrides
	for key: String in plan.get("spent",{}):
		var amount: Variant=plan.spent[key]
		if not integer(amount) or int(amount)<1 or not integer(payload.inventory.get(key,0)) or int(payload.inventory.get(key,0))<int(amount) or world._item_locked(key):return _failure("기존 스킬 일반 재료 공동 비용 불일치")
		for physical: Variant in world.item_instances.values():
			if physical is Dictionary and physical.get("name")==key and (physical.has(RECEIPT) or physical.has("quest_reward_receipt")):return _failure("다른 물리 재료의 이름 기반 차감 금지")
		payload.inventory[key]=int(payload.inventory[key])-int(amount)
		if payload.inventory[key]==0:payload.inventory.erase(key)
	var state: Dictionary=payload.consumable_state;var journal: Variant=state.get(SKILL_MATERIAL_USES,{})
	if not journal is Dictionary:return _failure("기존 원문 스킬 재료 사용 기록 보존 필요")
	journal=journal.duplicate(true);var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while journal.has(id):id=Crypto.new().generate_random_bytes(16).hex_encode()
	journal[id]={"schema":1,"source_definition_archive":SOURCE.identity(),"skill_id":str(skill.get("id","")),"source_skill_input":skill.get("source523",{}).duplicate(true),"selected_inputs":paid.selections.duplicate(true),"legacy_spent":plan.spent.duplicate(true),"mp_cost":int(mp_cost),"hp_cost":int(hp_cost),"selection_policy":"TWILIGHT_exact_proven_physical_id_order"}
	state[SKILL_MATERIAL_USES]=journal;payload["mp"]=int(world.mp)-int(mp_cost);payload["hp"]=int(world.hp)-int(hp_cost)
	if not paid.quest_step.is_empty() and not QUEST_CONSUME.matches_payload(world,paid.quest_step,payload):return _failure("스킬 원문 재료의 실제 잔량·퀘스트 사용 장부 공동 후보 불일치")
	busy=true;_candidate_kind="skill_material_use";_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear();_candidate_kind="";busy=false
	if saved!=OK:
		world.patch523_owner_state_problem="원문 스킬 재료 저장 결과 미확정 · 정상 불러오기 전 재시전 중지";return _failure(world.patch523_owner_state_problem)
	if payload.has("quest_state") and not world.quest_service.import_state(payload.quest_state):
		world.patch523_owner_state_problem="원문 스킬 재료 저장 후 장부 채택 미확정 · 정상 불러오기 전 재시전 중지";return _failure(world.patch523_owner_state_problem)
	world.inventory=payload.inventory;world.item_instances=payload.item_instances;world.mp=int(payload.mp);world.hp=int(payload.hp);world.consumable_service.import_state(state);world.deferred_save.cancel()
	var consumed_units: int=0
	for input: Dictionary in paid.selections:consumed_units+=int(input.quantity)
	return {"handled":true,"ok":true,"saved":true,"consumed":consumed_units,"physical_input_count":paid.selections.size(),"selected_inputs":paid.selections.duplicate(true),"source_material_receipt_id":id}


# A post-confirmation data handoff, never an extra sprite/emission trigger.
# The existing one call site remains the sole dispatch owner until the visual
# owner publishes its exact compatible source-item API.
static func committed_use_context(result: Dictionary,record: Dictionary,sprite: int,dispatch_attempted: bool,dispatch_owner: String) -> Dictionary:
	if not result.get("ok",false) or not result.get("saved",false) or int(result.get("consumed",0))<1:return result
	result["source_use_context"]={"original_item":NATIVE_FIELDS.full(record).get("source_original_item",{}).duplicate(true),"source_definition_archive":SOURCE.identity(),"physical_id":str(result.get("physical_id","")),"remaining_quantity":result.get("remaining_quantity"),"effect_sprite_id":sprite,"commit_key":JSON.stringify([str(result.get("physical_id","")),result.get("remaining_quantity"),str(result.get("source_bag_receipt_id",""))]).sha256_text(),"visual_dispatch_owner":dispatch_owner,"visual_dispatch_attempted":dispatch_attempted,"render_observed":false}
	return result
