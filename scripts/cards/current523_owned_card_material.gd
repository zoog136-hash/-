extends RefCounted
## Selected physical input only. The calling effect owner commits once.
## Definition origin and persisted m508/m523 identity are separate proofs.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const OWN=preload("res://scripts/quests/quest_reward_ownership.gd")
const C=preload("res://scripts/quests/quest_reward_consumption.gd")
const SUPPLY=preload("res://scripts/cards/native_awakening_supply.gd")

static func fail(reason: String) -> Dictionary:
	return {"ok":false,"code":"source_material","error":reason,"use_authorized":false}

static func eligibility(world: Node,raw: Dictionary) -> String:
	if raw.is_empty() or raw.get("TestItem")!=false or SOURCE.row("ItemClass",int(raw.get("ID",0)))!=raw or not SOURCE.declared_exclusion("ItemClass",raw).is_empty():return "정확한 현재 원본 아이템 행 필요"
	if int(world.get("hp"))<=0 or (world.has_method("_patch523_item_allowed") and not world._patch523_item_allowed()):return "현재 상태에서는 아이템을 사용할 수 없습니다"
	if raw.get("CanUseWhenInvisible")==false and world.has_method("is_player_concealed") and world.is_player_concealed():return "원본 은신 중 사용 제한"
	for prefix: String in ["LevelLimit","MaxLevelLimit"]:
		var minimum: Variant=raw.get(prefix+"Min",0);var maximum: Variant=raw.get(prefix+"Max",0)
		if C.nonnegative(minimum)<0 or C.nonnegative(maximum)<0:return "원본 레벨 조건 형식 확인 필요"
		if int(world.get("level"))<int(minimum) or (int(maximum)>0 and int(world.get("level"))>int(maximum)):return "원본 레벨 조건 불일치"
	# These contexts require an explicit consumer; zero is not a guessed clock.
	for field: String in ["StartDateTimeID","EndDateTimeID","ServerLimitSetID","ServerLimitsetID"]:
		if raw.has(field) and C.nonnegative(raw[field])!=0:return "원본 기간·서버 사용 조건 연결 필요"
	if not str(raw.get("ServiceRegionCode","")).is_empty():return "원본 서비스 지역 조건 연결 필요"
	var limits: Array[Dictionary]=SOURCE.related("ItemClassLimit","ItemClassID",int(raw.ID))
	if not limits.is_empty():
		var matches: Array=[]
		for entry: Dictionary in preload("res://scripts/lineagem_base508.gd").cards().get("classes",[]):
			if entry.get("name")==world.get("job_class") and entry.get("source_original") is Dictionary and SOURCE.row("Class",int(entry.source_original.get("ID",0)))==entry.source_original:matches.append(entry.source_original)
		if matches.size()!=1:return "정확한 현재 원본 직업 정체 연결 필요"
		var allowed: bool=false
		for link: Dictionary in limits:
			if int(link.get("ClassID",0))==int(matches[0].ID) and SOURCE.declared_exclusion("ItemClassLimit",link).is_empty():allowed=true
		if not allowed:return "원본 직업 사용 조건 불일치"
	return ""

static func prepare(world: Node,raw: Dictionary,archive: Dictionary,rule: Dictionary,selected: String="") -> Dictionary:
	if archive.is_empty() or archive!=SOURCE.identity():return fail("각성 재료 정의 출처 불일치")
	var issue: String=eligibility(world,raw)
	if not issue.is_empty():return fail(issue)
	var id: int=int(raw.ID);var candidates: Array[Dictionary]=[]
	for uid: String in world.item_instances:
		if not selected.is_empty() and uid!=selected:continue
		var physical: Variant=world.item_instances[uid]
		if not physical is Dictionary or not physical.get("record") is Dictionary:continue
		var record: Dictionary=physical.record
		if int(record.get("source_item_class_id",0))!=id:continue
		if physical.get("level",0)!=0 or physical.get("locked",false) or record.get("source_bless_raw",1)!=1 or record.get("source_bless_code_id",1)!=1 or record.get("source_enchant",0)!=0 or (world.has_method("_is_instance_equipped") and world._is_instance_equipped(uid)) or world._item_locked(str(physical.get("name","")),uid) or world._item_locked(str(physical.get("name",""))):continue
		if physical.has("quest_reward_receipt"):
			var owned: Dictionary=OWN.proof(world,uid)
			if owned.get("ok",false) and owned.source_item==raw and int(owned.bless_code_id)==1 and not owned.source_use_immediately:
				candidates.append({"kind":"quest","id":uid,"owned":owned})
			continue
		# Existing typed supply is already issued ownership, not a definition
		# fallback. Its full original item must still match the current source.
		var supplied: Dictionary=SUPPLY.proof(world,uid,id)
		if supplied.get("ok",false) and SUPPLY.definition(id).get("original_item") == raw:
			candidates.append({"kind":"supply","id":uid,"owned":supplied});continue
		var origin: Variant=record.get("source_definition_archive",record.get("source_input_identity",{}))
		if record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523" or origin!=archive or record.get("source_item")!=raw:continue
		if record.get("sourceId") not in ["m508:item:"+str(id),"m523:item:"+str(id)] or record.get("source_bless_raw",1)!=1 or record.get("source_pending_use",false):continue
		if physical.get("name")!=record.get("name") or str(physical.get("name","")).is_empty():continue
		# Plain catalog-issued physical objects represent one unit each. Never
		# interpret an unfamiliar quantity namespace as a one-unit object.
		if physical.has("source_reward_quantity") or physical.has("source_awakening_quantity") or physical.has("source_card_currency_quantity"):continue
		var count: int=0
		for other: Variant in world.item_instances.values():
			if other is Dictionary and other.get("name")==physical.name:count+=1
		if C.nonnegative(world.inventory.get(physical.name,0))!=count:continue
		candidates.append({"kind":"current_physical","id":uid,"name":physical.name})
	if candidates.size()!=1:return fail("정확한 소지 개체 선택 필요 · 잠금·정체·수량을 보존합니다")
	var candidate: Dictionary=candidates[0];var chosen_id: String=candidate.id
	if candidate.kind=="quest":
		var owned: Dictionary=candidate.owned
		var digest: String=JSON.stringify({"archive":archive,"item":raw,"rule":rule}).sha256_text()
		var step: Dictionary=C.stage(world,[{"physical_id":chosen_id,"quantity":1,"expected_quantity":int(owned.quantity),"expected_remaining":int(owned.quantity)-1,"quest_reward_receipt":world.item_instances[chosen_id].quest_reward_receipt.duplicate(true)}],digest)
		if not step.get("ok",false):return fail(str(step.get("reason","원본 소비 영수증 연결 필요")))
		return {"ok":true,"overrides":step.overrides,"quest_step":step,"consumed":[{"physical_id":chosen_id,"item_class_id":id,"quantity":1,"origin":"quest"}],"use_authorized":false}
	if candidate.kind=="supply":return SUPPLY.prepare_debit(world,id,1,chosen_id)
	var bag: Dictionary=world.inventory.duplicate(true);var instances: Dictionary=world.item_instances.duplicate(true)
	if int(bag[candidate.name])==1:bag.erase(candidate.name)
	else:bag[candidate.name]=int(bag[candidate.name])-1
	instances.erase(chosen_id)
	return {"ok":true,"overrides":{"inventory":bag,"item_instances":instances},"quest_step":{},"consumed":[{"physical_id":chosen_id,"item_class_id":id,"quantity":1,"origin":"current_original_physical"}],"use_authorized":false}

static func matches(world: Node,paid: Dictionary,payload: Dictionary) -> bool:
	if not paid.get("ok",false) or not C.same(paid.get("overrides",{}).get("inventory"),payload.get("inventory")) or not C.same(paid.get("overrides",{}).get("item_instances"),payload.get("item_instances")):return false
	var step: Variant=paid.get("quest_step",{})
	return step is Dictionary and (step.is_empty() or C.matches_payload(world,step,payload))

static func publish(world: Node,paid: Dictionary) -> bool:
	var overrides: Dictionary=paid.overrides
	world.inventory=overrides.inventory;world.item_instances=overrides.item_instances
	if overrides.has("quest_state"):
		world.quest_service.import_state(overrides.quest_state)
		if world.quest_service.save_blocked or not C.same(world.quest_service.export_state(),overrides.quest_state):return false
	return true
