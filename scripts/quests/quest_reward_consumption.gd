extends RefCounted
## Shared selected-reward debit/ledger staging. The effect owner must validate
## its own source data, exact quote, costs/results/RNG, then save one candidate.
## This module never applies a live change, saves, or authorizes an effect.
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const KIND="twilight.quest523.consumption.v1"
static func same(a: Variant,b: Variant)->bool:
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
static func nonnegative(value: Variant)->int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<0 or value>9007199254740991:return -1
	return int(value)
static func digest(value: Variant)->bool:
	return value is String and value.length()==64 and value.is_valid_hex_number(false) and value==value.to_lower()
static func fail(reason: String)->Dictionary:return {"ok":false,"reason":reason,"use_authorized":false}
static func available(world: Node)->bool:
	var service: Variant=world.get("quest_service")
	return service is Object and service.has_method("export_state") and service.has_method("validate_saved_state") and service.get("item_grants") is Dictionary and service.get("source")!=null and world.get("inventory") is Dictionary and world.get("item_instances") is Dictionary
static func stage(world: Node,requests: Array,consumer_data_sha256: String)->Dictionary:
	if requests.is_empty() or requests.size()>128 or not digest(consumer_data_sha256):return fail("소비 선택·소비자 자료 SHA 확인 필요")
	var service: Variant=world.get("quest_service")
	if not available(world):return fail("PR262 원본 소유·사용 장부 계약 미설치")
	var state: Dictionary=service.export_state()
	if not service.validate_saved_state(state).is_empty():return fail("기존 사용 장부 보존 · 형식 확인 필요")
	var stamp: String=OWN.stamp(world)
	var inventory: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	var selected: Dictionary={};var receipts: Array=[]
	for request: Variant in requests:
		if not request is Dictionary or request.size()!=5:return fail("정확한 선택 소비 요청 형식 필요")
		for key: String in ["physical_id","quantity","expected_quantity","expected_remaining","quest_reward_receipt"]:
			if not request.has(key):return fail("소비 선택 증명 필드 누락")
		var id: Variant=request.physical_id
		if not id is String or id.is_empty() or selected.has(id):return fail("같은 물리 개체 중복 선택 · 합산 후 한 번 요청 필요")
		var amount: int=OWN.positive(request.quantity);var before: int=OWN.positive(request.expected_quantity);var after: int=nonnegative(request.expected_remaining)
		if amount<=0 or before<=0 or after<0 or amount>before or after!=before-amount or not request.quest_reward_receipt is Dictionary:return fail("소비량·기대 잔량 불일치")
		var prepared: Dictionary=OWN.prepare_debit(world,id,amount)
		if not prepared.get("ok",false):return fail(str(prepared.get("reason","원본 소유 검증 실패")))
		var owned: Dictionary=prepared.ownership;var actual: Dictionary=world.item_instances[id]
		if int(owned.quantity)!=before or not same(actual.quest_reward_receipt,request.quest_reward_receipt):return fail("선택 이후 잔량·원본 지급 영수증 변경")
		# pack_sha256 identifies the first consumer-data proof. Keep it immutable
		# on later cross-owner use; the current owner records its own rule digest
		# in its transaction log (also returned here). Never relabel prior proof.
		var first_pack: String=consumer_data_sha256
		for row: Dictionary in service.item_grants.get(owned.quest_id,[]):
			if int(row.reward_id)==int(owned.reward_id):
				if int(row.item_class_id)!=int(owned.item_class_id) or int(row.bless_raw)!=int(owned.bless_code_id):return fail("이전 사용 장부의 품목·축복 정체 불일치")
				if not digest(row.get("pack_sha256")):return fail("최초 소비 자료 영수증 손상")
				first_pack=str(row.pack_sha256)
		var use: Dictionary=OWN.use_state(world,prepared,first_pack)
		if not use.get("ok",false):return fail(str(use.get("reason","원본 사용 장부 불일치")))
		var updated: Dictionary={}
		for row: Dictionary in use.state.item_grants[owned.quest_id]:
			if int(row.reward_id)==int(owned.reward_id):updated=row.duplicate(true)
		if updated.is_empty():return fail("사용 장부 후보 없음")
		if not state.has("item_grants"):state["item_grants"]={}
		if not state.item_grants.has(owned.quest_id):state.item_grants[owned.quest_id]=[]
		var rows: Array=state.item_grants[owned.quest_id];var replaced: bool=false
		for index: int in range(rows.size()):
			if int(rows[index].reward_id)==int(owned.reward_id):rows[index]=updated;replaced=true;break
		if not replaced:rows.append(updated)
		var key: String=owned.inventory_key;var total: int=OWN.positive(inventory.get(key))
		if total<amount:return fail("공동 인벤토리 잔량 불일치")
		if total==amount:inventory.erase(key)
		else:inventory[key]=total-amount
		if after==0:instances.erase(id)
		else:instances[id].source_reward_quantity=after
		selected[id]=true
		receipts.append({"physical_id":id,"quantity":amount,"remaining_before":before,"remaining_after":after,"quest_id":owned.quest_id,"reward_id":int(owned.reward_id),"item_class_id":int(owned.item_class_id),"bless_raw":int(owned.bless_code_id),"original_quantity":int(owned.original_quantity),"source_sha256":owned.source_sha256,"first_consumer_pack_sha256":first_pack,"consumer_data_sha256":consumer_data_sha256,"quest_reward_receipt":actual.quest_reward_receipt.duplicate(true)})
	if not service.validate_saved_state(state).is_empty() or OWN.stamp(world)!=stamp:return fail("공동 소비 후보 생성 중 원본 상태 변경")
	return {"ok":true,"kind":KIND,"base_stamp":stamp,"requests":requests.duplicate(true),"consumer_data_sha256":consumer_data_sha256,"overrides":{"inventory":inventory,"item_instances":instances,"quest_state":state},"selections":receipts,"use_authorized":false}
static func current(world: Node,candidate: Dictionary)->bool:
	if not available(world):return false
	if candidate.get("kind")!=KIND or candidate.get("base_stamp")!=OWN.stamp(world) or not candidate.get("requests") is Array or not candidate.get("consumer_data_sha256") is String:return false
	var fresh: Dictionary=stage(world,candidate.requests,candidate.consumer_data_sha256)
	return fresh.get("ok",false) and same(fresh,candidate)
static func matches_payload(world: Node,candidate: Dictionary,payload: Dictionary)->bool:
	if not current(world,candidate) or not payload.get("inventory") is Dictionary or not payload.get("item_instances") is Dictionary or not payload.get("quest_state") is Dictionary:return false
	if not same(payload.quest_state,candidate.overrides.quest_state):return false
	var selected: Dictionary={};var keys: Dictionary={}
	for row: Dictionary in candidate.selections:
		var id: String=row.physical_id;selected[id]=true
		keys[str(world.item_instances[id].name)]=true
		if int(row.remaining_after)==0:
			if payload.item_instances.has(id):return false
		elif not same(payload.item_instances.get(id),candidate.overrides.item_instances.get(id)):return false
	# This owner cannot consume another quest grant by sorted ID, or turn an
	# output into a newly invented quest receipt. Other effect-owned canonical
	# gear/output/legacy records remain the caller's verified responsibility.
	for id: Variant in world.item_instances:
		if not id is String or not world.item_instances[id] is Dictionary:return false
		if world.item_instances[id].has("quest_reward_receipt") and not selected.has(id) and not same(payload.item_instances.get(id),world.item_instances[id]):return false
	for id: Variant in payload.item_instances:
		if not id is String or not payload.item_instances[id] is Dictionary:return false
		if payload.item_instances[id].has("quest_reward_receipt") and not world.item_instances.has(id):return false
	for key: String in keys:
		var total: int=0
		for physical: Variant in payload.item_instances.values():
			if not physical is Dictionary:return false
			if physical.get("name")!=key:continue
			var amount: int=OWN.positive(physical.get("source_reward_quantity"))
			if amount==0 or total>9007199254740991-amount:return false
			total+=amount
		if nonnegative(payload.inventory.get(key,0))!=total:return false
	return true
