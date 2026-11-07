extends RefCounted
## Native monster floor -> exact source ownership + removed floor + receipt.
## Uses existing data/physical suppliers and the existing full save writer.
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const Transfer=preload("res://scripts/loot/inventory_ground_transfer.gd")
const Supply=preload("res://scripts/cards/source_awakening_items.gd")
const Identity=preload("res://scripts/equipment523/native_catalog.gd")
const Dummy=preload("res://scripts/quests/source_dummy523.gd")
const FIELD="source_ground_acquisitions"
var _busy: bool=false
var _candidate: Dictionary={}

class PhysicalView extends Node:
	var item_instances: Dictionary
	var next_item_instance_id: int

func authorizes(payload: Dictionary) -> bool:
	return not _candidate.is_empty() and Identity.same(_candidate,payload)

static func _integer(value: Variant,minimum: int=0) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<minimum or value>9007199254740991:return -1
	return int(value)

static func _fail(reason: String) -> Dictionary:
	return {"handled":true,"ok":false,"reason":reason}

static func _source(pending: Dictionary) -> Dictionary:
	var item: Variant=pending.get("item_record")
	if pending.get("player_dropped",false) or not item is Dictionary or item.get("source_m_native_item")!=true or item.get("source_snapshot")!="patch523":return {}
	var proof: Variant=item.get("source_m_drop_proof")
	return {"item":item,"proof":proof if proof is Dictionary else {}} if item.has("source_m_item_id") else {}

static func _proof_problem(item: Dictionary,proof: Dictionary,quantity: int) -> String:
	var id: int=_integer(item.get("source_item_class_id"),1)
	if _integer(item.get("source_m_item_id"),1)!=id or _integer(proof.get("bless_raw"),1) not in [1,2,3]:return "원본 드랍 품목·축복 식별 불일치"
	if quantity!=1 or proof.get("quantity_policy")!="host_one" or proof.get("selection_policy")!="host_uniform_distinct_items_then_distinct_variants":return "기존 원본 드랍 수량·선택 정책 확인 필요"
	if id<1 or proof.get("source_snapshot")!="patch523" or _integer(proof.get("source_item_class_id"),1)!=id or _integer(proof.get("bless_raw"),1)!=_integer(item.get("source_bless_raw"),1) or _integer(proof.get("required_quest_id"))!=0:return "정확한 원본 드랍 정체·축복·퀘스트 조건 확인 필요"
	var definition: Dictionary=D.item_definition(item)
	var raw: Dictionary=definition.get("original_item",{})
	if definition.is_empty() or raw.get("TestItem")!=false or not Dummy.item_evidence(raw).is_empty():return "시험·더미 또는 미확인 원본 아이템은 신규 습득 연결에서 제외"
	var document: Dictionary=D.data()
	var npc_id: int=_integer(proof.get("source_npc_id"),1)
	var npc: Dictionary=document.get("npcs",{}).get(str(npc_id),{})
	if npc_id<1 or npc.get("test_npc",true) or not npc.get("attackable",false):return "원본 드랍 몬스터 제공 조건 확인 필요"
	if not Dummy.evidence("NpcClass",{"ID":npc_id,"Name":npc.get("source_name","")}).is_empty():return "원본 더미 선언 몬스터의 신규 습득 연결 제외"
	var rows: Variant=proof.get("source_rows")
	if not rows is Array or rows.is_empty():return "원본 드랍 행 증명 누락"
	for row: Variant in rows:
		if not row is Dictionary or _integer(row.get("ItemClassID"),1)!=id or _integer(row.get("Bless"),1)!=_integer(proof.get("bless_raw"),1) or int(row.get("RequiredQuestID",-1))!=0:return "원본 드랍 행 관계 불일치"
		var matched: bool=false
		for original: Dictionary in document.get("drops",{}).get(str(npc_id),[]):
			if Identity.same(original,row):matched=true;break
		if not matched:return "현재 원본 팩에 없는 드랍 행 · 바닥과 기존 소유 보존"
	return ""

func collect(world: Node,view: Button,pending: Dictionary) -> Dictionary:
	var source: Dictionary=_source(pending)
	if source.is_empty():return {"handled":false}
	if _busy:return _fail("원본 습득 저장 중 · 중복 요청 보존")
	if not str(world.patch523_owner_state_problem).is_empty() or world.quest_service.save_blocked:return _fail("공동 소유 저장 보호 중 · 원본 바닥 보존")
	if not world.ground_loot.valid_view(view) or not Transfer.can_collect(world,pending) or world.hp<=0:return _fail("바닥 개체·생존·물리 소유 상태 확인 필요")
	var point: Variant=pending.get("position")
	if not point is Array or point.size()<2 or typeof(point[0]) not in [TYPE_INT,TYPE_FLOAT] or typeof(point[1]) not in [TYPE_INT,TYPE_FLOAT]:return _fail("바닥 좌표 구조 오류 · 원본 보존")
	var target:=Vector2(float(point[0]),float(point[1]))
	if not target.is_finite() or world.player.global_position.distance_to(target)>world.GROUND_PICKUP_RADIUS or Time.get_ticks_msec()-int(view.get("visible_since"))<world.ground_loot.MIN_VISIBLE_MS or not world._has_line_of_sight_world(world.player.global_position,target):return _fail("기존 습득 거리·표시 시간·시야 조건 미충족")
	var quantity: int=_integer(pending.get("quantity"),1)
	var problem: String=_proof_problem(source.item,source.proof,quantity)
	if not problem.is_empty():return _fail(problem)
	if source.item.get("name")!=pending.get("item_name"):return _fail("바닥 원본 소지 키 불일치")
	var equipment_uid: String=""
	if D.equipment(source.item) and source.item.get("slot")!="consumable":
		var envelope: Variant=pending.get("physical_item")
		if not envelope is Dictionary or not envelope.get("id") is String or str(envelope.id).is_empty() or not envelope.get("data") is Dictionary:return _fail("원본 장비의 실제 바닥 개체 증명 필요")
		var actual: Dictionary=envelope.data
		equipment_uid=str(envelope.id)
		if actual.get("name")!=pending.item_name or actual.get("record")!=source.item or actual.get("level")!=0 or actual.get("source_m_drop_proof")!=source.proof:return _fail("원본 드랍 장비와 실제 물리 개체·출처 불일치")
		if world.item_instances.has(equipment_uid) or world.warehouse.instances.has(equipment_uid):return _fail("이미 소유·보관 중인 장비 ID와 바닥 충돌 · 개체 보존")
		for previous: Dictionary in world._ground_drops_snapshot():
			if previous.get("id")==pending.get("id"):continue
			var other: Variant=previous.get("physical_item",{})
			if not other is Dictionary:return _fail("기존 바닥 물리 소유 구조 확인 필요")
			if other.get("id")==equipment_uid:return _fail("서로 다른 바닥 레코드의 장비 ID 중복 · 습득 보류")
	var pack: Dictionary=D.pack_identity()
	if pack.get("source_snapshot")!="patch523" or pack.get("schema") not in [3,4]:return _fail("원본 습득 입력 정체 확인 필요")
	if pack.get("schema")==4 and pack.get("source_definition_archive")!=preload("res://scripts/resources/current523_definition_rows.gd").identity():return _fail("새 원문 정의 출처 불일치 · 바닥 보존")
	var deadline: String=D.deadline_problem(source.item,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
	if not deadline.is_empty():return _fail(deadline)
	var id: String=str(pending.get("id",""))
	var state: Dictionary=world.consumable_service.export_state()
	var receipts: Variant=state.get(FIELD,{})
	if id.is_empty() or not receipts is Dictionary:return _fail("기존 원본 습득 영수증 형식 보존")
	if receipts.has(id):return _fail("이미 기록된 바닥 개체의 습득 영수증 · 중복 지급 중지")
	var wallet: String=D.wallet_name(source.item)
	var key: String=wallet if not wallet.is_empty() else str(pending.item_name)
	var inventory: Dictionary=world.inventory.duplicate(true)
	var gold: int=world.gold
	if wallet=="아데나":
		if gold<0 or gold>9007199254740991-quantity:return _fail("원본 재화 정수 범위 초과")
		gold+=quantity
	else:
		var before: int=_integer(inventory.get(key,0))
		if before<0 or before>9007199254740991-quantity:return _fail("원본 소지 수량 범위 초과")
		inventory[key]=before+quantity
		var unit_weight: int=world._indexed_item_weight(key,source.item)
		if world._inventory_total_weight()+quantity*unit_weight>world._carrying_capacity():return _fail("기존 소지 무게 한도 초과 · 바닥 아이템 보존")
	var physical:=PhysicalView.new()
	physical.item_instances=world.item_instances.duplicate(true);physical.next_item_instance_id=world.next_item_instance_id
	Transfer.restore_physical(physical,pending)
	var acquired: Dictionary=Supply.prepare_pickup(pending,physical.item_instances,physical.next_item_instance_id)
	var symbols: Dictionary=world.growth.source523.prepare_pickup(pending,acquired.item_instances,int(acquired.next_item_instance_id))
	var instances: Dictionary=symbols.item_instances
	var next_id: int=int(symbols.next_item_instance_id)
	var stock: Script=load("res://scripts/loot/current523_native_stack.gd")
	var native_issued: Array=[];var native_proofs: Array=[]
	if not stock.call("supply_profile",source.item).is_empty():
		# One ground quantity must not be granted by two physical suppliers.
		if instances!=world.item_instances:physical.free();return _fail("동일 드랍에 복수 물리 공급자가 응답했습니다 · 바닥·소유 보존")
		var origin: Dictionary={"kind":"source523_floor","floor_id":id,"drop":source.proof.duplicate(true)}
		var granted: Dictionary=stock.call("stage_grant",source.item,quantity,instances,origin)
		if not granted.get("ok",false):physical.free();return _fail("원본 물리 수량 영수증 생성 실패 · 바닥 보존")
		var issued: Dictionary=stock.call("issued_ids",source.item,quantity,instances,granted,origin,false)
		if not issued.get("ok",false):physical.free();return _fail(str(issued.get("reason","원본 물리 공급 결과 확인 필요")))
		for uid: String in issued.ids:
			if world.warehouse.instances.has(uid):physical.free();return _fail("신규 원본 개체 ID가 창고 소유와 충돌했습니다")
			for previous: Dictionary in world._ground_drops_snapshot():
				var other: Variant=previous.get("physical_item",{})
				if not other is Dictionary:physical.free();return _fail("기존 바닥 물리 소유 구조 확인 필요")
				if other.get("id")==uid:physical.free();return _fail("신규 원본 개체 ID가 기존 바닥 소유와 충돌했습니다")
			native_proofs.append({"physical_id":uid,"quantity":int(granted.item_instances[uid].source_native_stack_quantity),"source_native_stack_receipt":granted.item_instances[uid].source_native_stack_receipt.duplicate(true)})
		native_issued=issued.ids.duplicate(true);instances=granted.item_instances
	if not equipment_uid.is_empty() and instances.get(equipment_uid)!=pending.physical_item.data:
		physical.free();return _fail("장비 습득 공급자가 선택한 실제 바닥 개체를 변경했습니다")
	physical.free()
	var added: Array=[]
	for uid: String in instances:
		if not world.item_instances.has(uid):added.append(uid)
	var source_rows: Array=[]
	for row: Dictionary in source.proof.source_rows:source_rows.append(row.get("ID"))
	var receipt: Dictionary={"schema":1,"source_snapshot":"patch523","source_pack_sha256":str(pack.sha256),"source_npc_id":int(source.proof.source_npc_id),"item_class_id":int(source.item.source_item_class_id),"bless_raw":int(source.item.source_bless_raw),"quantity":quantity,"inventory_key":key,"physical_ids":added,"source_row_ids":source_rows,"drop_proof_sha256":JSON.stringify(source.proof,"",true,true).sha256_text()}
	if not native_issued.is_empty():
		if added!=native_issued:
			var sorted_added: Array=added.duplicate();var sorted_native: Array=native_issued.duplicate();sorted_added.sort();sorted_native.sort()
			if sorted_added!=sorted_native:return _fail("원본 습득 물리 ID 목록과 실제 공급 결과 불일치")
		receipt["native_physical_receipts"]=native_proofs
	if not equipment_uid.is_empty():receipt["source_equipment_physical_id"]=equipment_uid
	if pack.get("schema")==4:
		receipt.schema=2;receipt["source_input_marker"]=pack.duplicate(true);receipt["source_pack_sha256_scope"]="current_original_archive_not_legacy_bin"
	receipts=receipts.duplicate(true);receipts[id]=receipt;state[FIELD]=receipts
	var floor: Array=world._ground_drops_snapshot()
	var after: Array=[];var found: bool=false
	for entry: Dictionary in floor:
		if str(entry.get("id",""))==id:
			if found or not Identity.same(entry,pending):return _fail("선택 바닥 개체 변경 · 습득 취소")
			found=true
		else:after.append(entry)
	if not found:return _fail("선택 바닥 개체가 없습니다")
	var payload: Dictionary={"inventory":inventory,"item_instances":instances,"next_item_instance_id":next_id,"gold":gold,"ground_drops":after,"consumable_state":state}
	_busy=true;_candidate=payload.duplicate(true)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear()
	if saved!=OK:
		world.patch523_owner_state_problem="원본 습득 저장 실패·결과 미확정 · 다시 불러오기 전 저장·중복 지급 중지"
		_busy=false
		return _fail("원본 습득 저장 실패 또는 결과 미확정 · 바닥·소유 메모리 보존")
	var taken: Dictionary=world.ground_loot.take(view,world.player.global_position,world.GROUND_PICKUP_RADIUS)
	if taken.is_empty():
		world.patch523_owner_state_problem="원본 습득은 저장됐지만 바닥 상태 채택 미확정 · 다시 불러오기 필요"
		_busy=false
		return _fail(world.patch523_owner_state_problem)
	world.inventory=inventory;world.item_instances=instances;world.next_item_instance_id=next_id;world.gold=gold
	world.consumable_service.import_state(state)
	world.deferred_save.cancel();_busy=false
	return {"handled":true,"ok":true,"saved":true,"record":taken,"receipt":receipt}
