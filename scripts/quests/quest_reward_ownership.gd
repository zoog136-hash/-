extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Ownership/debit contract for consumer-owned effects. Never applies an effect,
## converts a stack name, changes a claim or commits a save on its own.
const NUMBERS = preload("res://scripts/quests/quest_item_bindings.gd")
static func denied(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
static func positive(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<1 or value>9007199254740991: return 0
	return int(value)
static func proof(world: Node, physical_id: String) -> Dictionary:
	var service: Variant = world.quest_service
	if service.save_blocked: return denied("퀘스트 저장 보호 중")
	var physical: Variant = world.item_instances.get(physical_id)
	if not physical is Dictionary: return denied("소지 개체 없음")
	var record: Variant = physical.get("record")
	var receipt: Variant = physical.get("quest_reward_receipt")
	if not record is Dictionary or not receipt is Dictionary: return denied("원본 지급 영수증 없음 · 기존 개체 보존")
	if record.get("source_pending_use")!=true or record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523": return denied("퀘스트 보관 개체가 아님")
	var id: int = NUMBERS.item_id(record.get("source_item_class_id"))
	var quest_id: String = str(receipt.get("quest_id",""))
	var reward_id: int = NUMBERS.item_id(receipt.get("reward_id"))
	if id<=0 or reward_id<=0 or record.get("sourceId")!="m523:item:"+str(id) or receipt.get("source_sha256")!=service.source.SOURCE_SHA or receipt.get("schema")!=1 or receipt.get("item_class_id")!=id: return denied("원본 지급 정체 불일치")
	if not service.claimed.get(quest_id) is bool or service.claimed.get(quest_id)!=true: return denied("완료 지급 이력 없음")
	var quest: Dictionary = service.index.get(quest_id,{})
	if service.has_method("full"): quest = service.full(quest)
	if quest.is_empty() or not quest.blockers.is_empty() or not quest.excluded_reasons.is_empty(): return denied("원본 퀘스트 관계/제외 확인 필요")
	var matches: Array[Dictionary] = []
	for reward: Dictionary in quest.source_rewards:
		if int(reward.ID)==reward_id: matches.append(reward)
	if matches.size()!=1: return denied("원본 보상 관계가 유일하지 않음")
	var original: Dictionary = matches[0]
	if original.type_name!="Item" or int(original.RewardClassID)!=id or int(original.RewardEnhancementTypeID)!=1 or original.ClanOnly: return denied("원본 일반 보상 관계 불일치")
	var item: Dictionary = original.get("source_item",{})
	var name_value: String = "[원본 보상] "+str(item.get("Name",""))
	if item.is_empty() or int(item.get("ID",0))!=id or NATIVE_FIELDS.full(record).get("source_original_item")!=item or record.get("name")!=name_value or physical.get("name")!=name_value or physical.get("level",0)!=0: return denied("원본 행/소지 키 불일치")
	if receipt.get("bless_code_id")!=original.ItemBlessCodeID or record.get("source_bless_code_id")!=original.ItemBlessCodeID or record.get("source_reward_id")!=reward_id or record.get("source_use_immediately")!=original.UseImmediately: return denied("원본 축복/사용/보상 상태 불일치")
	var quantity: int = positive(physical.get("source_reward_quantity"))
	var granted: int = positive(receipt.get("quantity"))
	if quantity<=0 or granted!=positive(original.Amount) or quantity>granted: return denied("원본 지급/잔여 수량 불일치")
	var same_grant: int = 0
	var total: int = 0
	for candidate: Variant in world.item_instances.values():
		if not candidate is Dictionary: continue
		var other_receipt: Variant = candidate.get("quest_reward_receipt",{})
		if other_receipt is Dictionary and other_receipt.get("quest_id")==quest_id and other_receipt.get("reward_id")==reward_id: same_grant+=1
		if candidate.get("name")==name_value:
			var remaining: int = positive(candidate.get("source_reward_quantity"))
			if remaining<=0 or total>9007199254740991-remaining: return denied("동일 소지 키의 개체 수량 불일치")
			total+=remaining
	if same_grant!=1 or total!=positive(world.inventory.get(name_value)): return denied("중복 영수증/인벤토리 합계 불일치")
	return {"ok":true,"kind":"twilight.quest523.owned-reward.v1","physical_id":physical_id,"inventory_key":name_value,"item_class_id":id,"bless_code_id":int(original.ItemBlessCodeID),"quantity":quantity,"original_quantity":granted,"quest_id":quest_id,"reward_id":reward_id,"source_sha256":service.source.SOURCE_SHA,"source_use_immediately":bool(original.UseImmediately),"source_item":item.duplicate(true),"record":record.duplicate(true),"use_authorized":false}

static func stamp(world: Node) -> String:
	# Key ordering changes may conservatively stale a quote, never authorize it.
	return JSON.stringify([world.quest_service.claimed,world.quest_service.item_grants,world.inventory,world.item_instances]).sha256_text()

static func prepare_debit(world: Node, physical_id: String, quantity: int) -> Dictionary:
	var owned: Dictionary = proof(world,physical_id)
	if not owned.ok: return owned
	if world._item_locked(str(owned.inventory_key),physical_id) or world._item_locked(str(owned.inventory_key),""): return denied("잠긴 원본 보상은 소비하지 않습니다")
	if owned.source_use_immediately or owned.source_item.get("TestItem",false): return denied("원본 즉시 사용/시험 아이템은 소비자 별도 연결 필요")
	if quantity<1 or quantity>int(owned.quantity): return denied("원본 소지 수량 부족")
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	var remaining: int = int(owned.quantity)-quantity
	if remaining==0: instances.erase(physical_id)
	else: instances[physical_id].source_reward_quantity=remaining
	inventory[owned.inventory_key]=int(inventory[owned.inventory_key])-quantity
	if int(inventory[owned.inventory_key])==0: inventory.erase(owned.inventory_key)
	return {"ok":true,"kind":"twilight.quest523.reward-debit.v1","physical_id":physical_id,"quantity":quantity,"base_stamp":stamp(world),"ownership":owned,"override":{"inventory":inventory,"item_instances":instances},"use_authorized":false}

static func current(world: Node, prepared: Dictionary) -> bool:
	if prepared.get("kind")!="twilight.quest523.reward-debit.v1" or prepared.get("base_stamp")!=stamp(world): return false
	var quantity: int = positive(prepared.get("quantity"))
	if quantity<=0: return false
	var fresh: Dictionary = prepare_debit(world,str(prepared.get("physical_id","")),quantity)
	return fresh.get("ok",false) and fresh.ownership==prepared.get("ownership") and fresh.override==prepared.get("override")

static func use_state(world: Node, prepared: Dictionary, pack_sha: String) -> Dictionary:
	if not current(world,prepared):return denied("원본 보상 사용 후보가 변경되었습니다")
	var owned: Dictionary=prepared.ownership
	var state: Dictionary=world.quest_service.export_state()
	if not state.has("item_grants"):state["item_grants"]={}
	if not state.item_grants.has(owned.quest_id):state.item_grants[owned.quest_id]=[]
	var rows: Array=state.item_grants[owned.quest_id]
	var used: int=int(owned.original_quantity)-int(owned.quantity)
	var existing: Dictionary={}
	for receipt: Dictionary in rows:
		if int(receipt.reward_id)==int(owned.reward_id):existing=receipt
	if not existing.is_empty():
		if existing.get("origin")!="held_use" or int(existing.get("used_quantity",0))!=used or int(existing.quantity)!=int(owned.original_quantity) or existing.inventory_key!=owned.inventory_key or existing.get("source_sha256")!=owned.source_sha256 or existing.get("pack_sha256")!=pack_sha:return denied("원본 보상 사용 영수증 불일치")
	elif used!=0:return denied("원본 보상 잔여 수량의 이전 사용 영수증 없음")
	else:
		existing={"schema":1,"origin":"held_use","source_sha256":owned.source_sha256,"reward_id":int(owned.reward_id),"item_class_id":int(owned.item_class_id),"quantity":int(owned.original_quantity),"bless_raw":int(owned.bless_code_id),"inventory_key":str(owned.inventory_key),"pack_sha256":pack_sha}
		rows.append(existing)
	existing["used_quantity"]=used+int(prepared.quantity)
	if not world.quest_service.validate_saved_state(state).is_empty():return denied("원본 보상 사용 영수증 형식 오류")
	return {"ok":true,"state":state}
