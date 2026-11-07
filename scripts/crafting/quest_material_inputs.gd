extends RefCounted
## Typed selected quest materials for the existing compiled recipe executor.
## Source row selection and physical ownership selection are separate inputs.
const Own=preload("res://scripts/quests/quest_reward_ownership.gd")
const Consume=preload("res://scripts/quests/quest_reward_consumption.gd")
const Same=preload("res://scripts/equipment523/native_catalog.gd")
const Dummy=preload("res://scripts/quests/source_dummy523.gd")
const Drops=preload("res://scripts/loot/patch523_monster_drops.gd")
const Stock=preload("res://scripts/loot/current523_native_stack.gd")
const FIELD="source_quest_craft_receipts"

static func fail(reason: String) -> Dictionary:return {"ok":false,"reason":reason}

static func review(world: Node,book: RefCounted,recipe_id: String,batches: int,choices: Dictionary,selections: Array) -> Dictionary:
	if selections.is_empty():return {"ok":true,"requests":[],"native_requests":[],"allocations":[],"rows":{},"keys":{}}
	if not str(world.get("patch523_owner_state_problem")).is_empty() or world.hp<=0:return fail("저장 보호·생존 상태 확인 필요 · 선택 재료 보존")
	if selections.size()>128 or batches<1 or batches>20 or not Consume.digest(book.get("digest")):return fail("원본 재료·제작 소유자 입력 확인 필요")
	var selected: Dictionary=book.material_selection(recipe_id,choices)
	if not selected.get("ok",false):return selected
	var rows: Dictionary={}
	for material: Dictionary in selected.recipe.get("materials",[]):
		var row_id: int=Own.positive(material.get("row_id"))
		if row_id>0:rows[str(row_id)]=material
	var requests: Array=[];var native_requests: Array=[];var allocations: Array=[];var keys: Dictionary={};var used_ids: Dictionary={};var totals: Dictionary={}
	for selection: Variant in selections:
		if not selection is Dictionary or selection.size()!=6:return fail("선택 재료는 소비 요청5필드와 material_allocations가 필요합니다")
		var is_native: bool=selection.has("source_native_stack_receipt")
		var receipt_field: String="source_native_stack_receipt" if is_native else "quest_reward_receipt"
		for field: String in ["physical_id","quantity","expected_quantity","expected_remaining",receipt_field,"material_allocations"]:
			if not selection.has(field):return fail("선택 재료 증명 필드 누락")
		var id: Variant=selection.physical_id
		if not id is String or id.is_empty() or used_ids.has(id):return fail("같은 물리 재료는 한 요청의 allocations로 합산하세요")
		var request: Dictionary=selection.duplicate(true);request.erase("material_allocations")
		var quantity: int=Own.positive(request.quantity)
		var before: int=Own.positive(request.expected_quantity)
		var remaining: int=Consume.nonnegative(request.expected_remaining)
		if quantity<1 or before<quantity or remaining!=before-quantity or not request[receipt_field] is Dictionary:return fail("선택 수량·예상 잔량 불일치")
		var owned: Dictionary={}
		if is_native:
			var physical: Dictionary=Stock.proof(world,id)
			if physical.is_empty() or physical.receipt!=request[receipt_field] or int(physical.remaining)!=before:return fail("원본 공급 재료의 물리 수량·불변 영수증 불일치")
			if world._item_locked(str(physical.record.name),id) or world._item_locked(str(physical.record.name)):return fail("잠긴 원본 물리 재료 보존")
			owned={"quantity":physical.remaining,"bless_code_id":physical.record.source_bless_raw,"source_item":physical.receipt.source_original_item,"inventory_key":str(physical.record.name),"record":physical.record}
		else:
			if not Consume.available(world):return fail("원본 퀘스트 소비 소유자 미연결 · 보상 보존")
			var prepared: Dictionary=Own.prepare_debit(world,id,quantity)
			if not prepared.get("ok",false):return prepared
			owned=prepared.ownership
			if int(owned.quantity)!=before or not Consume.same(world.item_instances[id].quest_reward_receipt,request.quest_reward_receipt):return fail("원본 선택 재료의 지급·잔량 증명 불일치")
		if not Dummy.item_evidence(owned.source_item).is_empty():return fail("원본 선언 더미 재료 제외")
		var split: Variant=selection.material_allocations
		if not split is Array or split.is_empty() or split.size()>128:return fail("원본 재료 행별 수량 배분 필요")
		var sum: int=0;var seen_rows: Dictionary={}
		for allocation: Variant in split:
			if not allocation is Dictionary or allocation.size()!=2:return fail("재료 배분은 material_row_id와 quantity만 허용합니다")
			var row_id: int=Own.positive(allocation.get("material_row_id"))
			var amount: int=Own.positive(allocation.get("quantity"))
			if row_id<1 or amount<1 or seen_rows.has(row_id) or not rows.has(str(row_id)) or sum>9007199254740991-amount:return fail("현재 선택 제작식의 재료 행·수량 불일치")
			var material: Dictionary=rows[str(row_id)]
			var entry: Dictionary=book.item_entry(str(material.get("source_id","")))
			if material.get("physical",true) or material.get("wallet",false) or int(material.get("level",-1))!=0 or int(material.get("bless_code",0))!=int(owned.bless_code_id) or not Same.same(entry.get("item_class"),owned.source_item):return fail("원본 행·품목·축복·강화가 같은 비장비 재료만 선택할 수 있습니다")
			var canonical: Dictionary=book.record(str(material.source_id),int(material.bless_code))
			if canonical.is_empty():return fail("원본 재료의 현재 제작 카탈로그 정체 확인 필요")
			if is_native and not Drops.matches(owned.record,canonical):return fail("원본 물리 재료와 제작 카탈로그 정체 불일치")
			var deadline: String=Drops.deadline_problem(canonical,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
			if not deadline.is_empty():return fail(deadline)
			if not is_native and str(book.ownership_key(material))==str(owned.inventory_key):return fail("원본 재료 소지 이름공간 충돌 · 변환하지 않고 보존")
			var required: int=Own.positive(material.get("quantity"))*batches
			var key: String=str(row_id)
			if required<1 or int(totals.get(key,0))>required-amount:return fail("선택 재료 수량이 원본 제작 비용을 초과합니다")
			totals[key]=int(totals.get(key,0))+amount
			allocations.append({"material_row_id":row_id,"physical_id":id,"inventory_key":str(owned.inventory_key),"quantity":amount,"source_id":str(material.source_id)})
			sum+=amount;seen_rows[row_id]=true
		if sum!=quantity:return fail("행별 배분 합계와 물리 개체 소비량 불일치")
		var key: String=str(owned.inventory_key)
		if not keys.has(key):keys[key]={"amount":0,"record":owned.record.duplicate(true),"carried_weight":maxi(0,int(world.item_weight_index.get(key,3))) if is_native else 0,"quest_material":true}
		if int(keys[key].amount)>9007199254740991-quantity:return fail("선택 원본 재료 합계 범위 초과")
		keys[key].amount=int(keys[key].amount)+quantity
		if is_native:native_requests.append(request)
		else:requests.append(request)
		used_ids[id]=true
	return {"ok":true,"requests":requests,"native_requests":native_requests,"allocations":allocations,"rows":rows,"keys":keys}

static func owned(material: Dictionary,context: Dictionary) -> Dictionary:
	var checked: Variant=context.get("quest_material_review",{})
	if not checked is Dictionary or not checked.get("ok",false):return {}
	var row_id: int=Own.positive(material.get("row_id"))
	var pools: Dictionary={}
	for allocation: Dictionary in checked.get("allocations",[]):
		if int(allocation.material_row_id)!=row_id:continue
		var key: String=allocation.inventory_key
		if not pools.has(key):pools[key]=checked["keys"][key].duplicate(true);pools[key]["row_limit"]=0
		pools[key].row_limit=int(pools[key].row_limit)+int(allocation.quantity)
	return pools

static func quote_problem(approval: Dictionary,context: Dictionary) -> String:
	var checked: Variant=context.get("quest_material_review",{})
	if not checked is Dictionary:return "선택 원본 재료 검토 형식 오류"
	if checked.is_empty():return ""
	if not checked.get("ok",false):return str(checked.get("reason","선택 원본 재료 검토 필요"))
	var quoted: Dictionary={}
	for row: Dictionary in approval.get("material_rows",[]):
		if not row.get("quest_material",false):continue
		var key: String=str(int(row.get("material_row_id",0)))+":"+str(row.key)
		quoted[key]=int(quoted.get(key,0))+int(row.quantity)
	var expected: Dictionary={}
	for allocation: Dictionary in checked.get("allocations",[]):
		var key: String=str(int(allocation.material_row_id))+":"+str(allocation.inventory_key)
		expected[key]=int(expected.get(key,0))+int(allocation.quantity)
	return "" if Same.same(quoted,expected) else "지정한 원본 재료 행·수량이 실제 견적에 모두 선택되지 않았습니다"

static func join(world: Node,book: RefCounted,transaction: Dictionary,context: Dictionary) -> Dictionary:
	var checked: Variant=context.get("quest_material_review",{})
	if checked is Dictionary and checked.is_empty():return transaction
	if not checked is Dictionary or not checked.get("ok",false):return fail(str(checked.get("reason","선택 원본 재료 검토 필요")) if checked is Dictionary else "선택 원본 재료 형식 오류")
	if checked.get("requests",[]).is_empty() and checked.get("native_requests",[]).is_empty():return transaction
	var problem: String=quote_problem(transaction,context)
	if not problem.is_empty():return fail(problem)
	# Existing failure policy may explicitly retain all quoted materials. Never
	# apply a debit solely because a pre-roll quote had selected those inputs.
	if transaction.has("quoted_materials") and transaction.get("materials",{}).is_empty():return transaction
	var step: Dictionary={"ok":true,"selections":[]}
	if not checked.get("requests",[]).is_empty():
		step=Consume.stage(world,checked.requests,book.digest)
		if not step.get("ok",false):return step
	# A declared failure return can retain the exact selected native units.
	# It never creates a new origin or rewrites an immutable grant receipt.
	var output: Dictionary=transaction.get("selected_output",{})
	var native_requests: Array=[];var native_refunds: Array=[];var gross_by_key: Dictionary={}
	var refund_left: int=int(transaction.get("result_quantity",0)) if str(output.get("label",""))=="실패" and not output.get("physical",false) and int(output.get("level",-1))==0 else 0
	for request: Dictionary in checked.get("native_requests",[]):
		var owned: Dictionary=Stock.proof(world,str(request.physical_id))
		if owned.is_empty():return fail("선택 원본 재료가 변경됐습니다")
		var key: String=str(owned.record.name)
		gross_by_key[key]=int(gross_by_key.get(key,0))+int(request.quantity)
		if not Same.same(transaction.item_instances.get(str(request.physical_id)),world.item_instances.get(str(request.physical_id))):return fail("실행기가 원본 물리 재료를 별도로 변경했습니다")
		var returned: int=0
		if refund_left>0 and str(owned.record.source_item_class_id)==str(output.get("source_id")) and int(owned.record.source_bless_raw)==int(output.get("bless_code",0)) and key==str(transaction.get("result_name","")):
			returned=mini(refund_left,int(request.quantity));refund_left-=returned
		if returned>0:native_refunds.append({"physical_id":str(request.physical_id),"quantity":returned,"source_native_stack_receipt":owned.receipt.duplicate(true),"source_id":str(output.source_id),"bless_code":int(output.bless_code),"level":0})
		var net: int=int(request.quantity)-returned
		if net>0:
			var adjusted: Dictionary=request.duplicate(true);adjusted.quantity=net;adjusted.expected_remaining=int(request.expected_quantity)-net
			native_requests.append(adjusted)
	var native: Dictionary=Stock.stage_debit(world,native_requests)
	if not native.get("ok",false):return fail(str(native.get("reason","원본 물리 재료 차감 확인 필요")))
	var all_inputs: Array=step.selections.duplicate(true);all_inputs.append_array(native.selections)
	for row: Dictionary in step.selections:
		var key: String=str(world.item_instances[str(row.physical_id)].name)
		gross_by_key[key]=int(gross_by_key.get(key,0))+int(row.quantity)
	for key: String in gross_by_key:
		var output_credit: int=int(transaction.get("result_quantity",0)) if key==str(transaction.get("result_name","")) and not output.get("physical",false) and not output.get("wallet_currency",false) else 0
		if int(transaction.get("materials",{}).get(key,0))!=int(gross_by_key[key]) or int(transaction.inventory.get(key,0))!=int(world.inventory.get(key,0))-int(gross_by_key[key])+output_credit:return fail("실행기의 실제 재료 차감·반환과 선택 수량 불일치")
	var retained: int=0
	for row: Dictionary in native_refunds:retained+=int(row.quantity)
	transaction["source_native_material_refunds"]=native_refunds
	transaction["source_native_retained_output_quantity"]=retained
	for row: Dictionary in all_inputs:
		var id: String=row.physical_id
		if not Same.same(transaction.item_instances.get(id),world.item_instances.get(id)):return fail("실행기가 선택 원본 개체를 별도로 변경했습니다 · 중복 차감 금지")
		var staged_instances: Dictionary=native.overrides.item_instances if row.has("source_native_stack_receipt") else step.overrides.item_instances
		if int(row.remaining_after)==0:transaction.item_instances.erase(id)
		else:transaction.item_instances[id]=staged_instances[id].duplicate(true)
	if not checked.get("requests",[]).is_empty():
		transaction["quest_state"]=step.overrides.quest_state
		var payload: Dictionary={"inventory":transaction.inventory,"item_instances":transaction.item_instances,"quest_state":transaction.quest_state}
		if not Consume.matches_payload(world,step,payload):return fail("최종 제작 후보와 원본 선택 사용 장부 불일치")
	var state: Dictionary=native.overrides.consumable_state
	var receipts: Variant=state.get(FIELD,{})
	if not receipts is Dictionary:return fail("기존 원본 제작 소비 영수증 형식 보존")
	var uid: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while receipts.has(uid):uid=Crypto.new().generate_random_bytes(16).hex_encode()
	if output.is_empty():return fail("실행기가 선택한 원본 제작 결과 정체 누락")
	var output_ids: Array=[]
	for id: String in transaction.item_instances:
		if world.item_instances.has(id):continue
		output_ids.append(id)
		var physical: Dictionary=transaction.item_instances[id]
		if physical.get("record",{}).get("source_m_native_item")==true:
			if physical.has("source_m_reward_proof"):return fail("신규 제작 결과에 별도 공급 증명이 이미 있습니다")
			physical["source_m_reward_proof"]={"source_snapshot":"patch523","item_class_id":int(output.source_id),"source_item_class_id":int(output.source_id),"bless":int(output.bless_code),"enchant":int(output.level),"supplier":{"kind":"source523_compiled_craft","recipe_id":str(context.get("source_recipe_id","")),"rules_sha256":book.digest,"quest_craft_receipt_id":uid}}
	var receipt: Dictionary={"schema":1,"recipe_id":str(context.get("source_recipe_id","")),"rules_sha256":book.digest,"inputs":all_inputs.duplicate(true),"gross_native_requests":checked.get("native_requests",[]).duplicate(true),"retained_native_refunds":native_refunds.duplicate(true),"material_allocations":checked.allocations.duplicate(true),"selected_output":output.duplicate(true),"output_name":str(transaction.result_name),"output_quantity":int(transaction.result_quantity),"output_physical_ids":output_ids,"outcome":str(transaction.get("outcome_label","완료"))}
	receipts=receipts.duplicate(true);receipts[uid]=receipt;state[FIELD]=receipts
	transaction["consumable_state"]=state
	if not checked.get("requests",[]).is_empty():transaction["quest_step"]=step
	transaction["source_craft_receipt_id"]=uid
	return transaction
