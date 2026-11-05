extends RefCounted
## Exact source-currency stacks and deterministic Nemesis ticket crafting/use.
## Existing TWILIGHT name-only coins are preserved without source backfill.
const DATA=preload("res://scripts/cards/patch523_slot_data.gd")
const RECIPE: int=258482
const COIN: int=3252
const TICKET: int=370562
const CARD: String="source:m523:2:25152"
const QUANTITY: String="source_card_currency_quantity"
const REQUIRED: int=3000000
static func source() -> Dictionary:return DATA.card_acquisition.get("guaranteed_nemesis",{})
static func integer(value: Variant) -> bool:return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))
static func exact(record: Dictionary,item_id: int) -> bool:
	return record.get("source","")=="lineagem_patch523" and record.get("source_snapshot","")=="patch523" and record.get("sourceId","")=="m523:item:"+str(item_id) and record.get("source_item_class_id",0)==item_id
static func recognized(record: Dictionary) -> bool:
	return (exact(record,COIN) or exact(record,TICKET)) and not str(record.get("name","")).is_empty()
static func record(item_id: int=TICKET) -> Dictionary:
	if source().is_empty():return {}
	var node: Dictionary=source().inputs[0].item_definition if item_id==COIN else source().outputs[0].item_definition
	var item: Dictionary=node.item.raw
	return {"name":str(item.Name),"source":"lineagem_patch523","source_snapshot":"patch523","source_item_class_id":item_id,"sourceId":"m523:item:"+str(item_id),"type":"화폐" if item_id==COIN else "소모품","slot":"currency" if item_id==COIN else "consumable","grade":"일반" if item_id==COIN else "영웅","source_grade_id":int(item.GradeID),"weight":float(item.Weight)/100.0,"stackable":bool(node.category.raw.IsStackable),"droppable":bool(item.IsDroppable),"storable":bool(item.IsStorable),"sellable":false,"source_item":item.duplicate(true),"desc":"원본 마법인형 제작 코인 · 네메시스 카드 제작 재료" if item_id==COIN else "사용 시 네메시스 마법인형 카드 1장 획득","source_image_status":"original_icon_not_installed"}
static func install(catalog: Dictionary) -> void:
	if not catalog.get("아이템") is Array:return
	for item_id: int in [COIN,TICKET]:
		if record(item_id).is_empty():continue
		var found: bool=false
		for entry: Dictionary in catalog["아이템"]:
			if exact(entry,item_id):found=true;break
		if not found:catalog["아이템"].append(record(item_id))
static func rules_valid() -> bool:
	var data: Dictionary=source()
	if data.is_empty():return false
	var view: Dictionary=data.view.raw
	if int(view.ItemCraftID)!=RECIPE or int(view.AlwaysSuccess)!=1 or int(view.ServerLimitSetID)!=0 or bool(view.IsBelowLevelLimit) or int(view.LevelLimitValue)!=0 or bool(view.NoRepeat) or not data.restrictions.is_empty() or data.inputs.size()!=1 or data.outputs.size()!=1:return false
	var input: Dictionary=data.inputs[0].link.raw;var output: Dictionary=data.outputs[0].link.raw
	if int(input.ItemClassID)!=COIN or int(input.Amount)!=REQUIRED or int(input.Enchant)!=0 or int(input.ItemBlessCodeID)!=1 or int(input.ItemHoningEpithetID)!=0:return false
	if int(output.ItemClassID)!=TICKET or int(output.Amount)!=1 or int(output.Probability)!=1000000 or int(output.Enchant)!=0 or int(output.ItemBlessCodeID)!=1 or int(output.ClanItemClassID)!=0 or int(output.ClanAmount)!=0:return false
	var effects: Array=data.outputs[0].item_definition.effects
	return effects.size()==1 and effects[0].type.raw.Name=="BuffCardID" and effects[0].unit.raw.Name=="BuffCardID" and int(effects[0].bonus.raw.Value)==25152 and int(effects[0].bonus.raw.BonusApplicationTypeID)==0 and int(effects[0].bonus.raw.BonusApplicationTargetID)==0 and not bool(effects[0].link.raw.IsPossession) and int(data.card.raw.BuffCardDeckID)==2
static func time_available(now: int=-1) -> bool:
	if source().is_empty():return false
	var instant: int=now if now>=0 else int(Time.get_unix_time_from_system())
	# Without a locale selection, accept only the interior common to every
	# supplied calendar with a full day margin. Never guess a boundary offset.
	var found: bool=false
	for calendar: Dictionary in source().dates.values():
		if calendar.EffectiveFrom==null and calendar.EffectiveTo==null:continue
		if not calendar.EffectiveFrom is Dictionary or not calendar.EffectiveTo is Dictionary:return false
		var times: Array[int]=[]
		for entry: Dictionary in [calendar.EffectiveFrom,calendar.EffectiveTo]:
			var raw: Dictionary=entry.raw
			times.append(Time.get_unix_time_from_datetime_dict({"year":int(raw.Year),"month":int(raw.Month),"day":int(raw.Day),"hour":int(raw.Hour),"minute":int(raw.Minute),"second":0}))
		if instant<times[0]+86400 or instant>times[1]-86400:return false
		found=true
	return found
static func next_safe_id(instances: Dictionary,next_id: int) -> int:
	var result: int=maxi(1,next_id)
	for key: String in instances:
		if key.is_valid_int():result=maxi(result,int(key)+1)
	return result
static func prepare_coin_pickup(drop: Dictionary,instances: Dictionary,next_id: int) -> Dictionary:
	var unchanged: Dictionary={"item_instances":instances,"next_item_instance_id":next_id,"created":0}
	if source().is_empty():return unchanged
	if drop.has("physical_item") or not drop.get("item_record") is Dictionary or not exact(drop.item_record,COIN) or drop.get("item_name","")!=str(record(COIN).name) or not integer(drop.get("quantity",0)) or int(drop.quantity)<1 or int(drop.quantity)>1500000000:return unchanged
	var staged: Dictionary=instances.duplicate(true);var identity: int=next_safe_id(instances,next_id)
	staged[str(identity)]={"name":str(record(COIN).name),"level":0,"record":record(COIN),QUANTITY:int(drop.quantity)}
	return {"item_instances":staged,"next_item_instance_id":identity+1,"created":int(drop.quantity)}
static func available_coins(inventory: Dictionary,instances: Dictionary,locks: Dictionary={}) -> int:
	if source().is_empty():return 0
	var name_value: String=str(record(COIN).name);var owned: Variant=inventory.get(name_value,0)
	if not integer(owned) or int(owned)<0:return 0
	var total: int=0;var available: int=0
	for id: String in instances:
		var entry: Variant=instances[id]
		if not entry is Dictionary or entry.get("name","")!=name_value or not entry.get("record") is Dictionary or not exact(entry.record,COIN):continue
		var amount: Variant=entry.get(QUANTITY,0)
		if not integer(amount) or int(amount)<1 or int(amount)>1500000000:return 0
		total+=int(amount)
		if not bool(locks.get(id,false)) and not bool(locks.get(name_value+"@@@"+id,false)) and not bool(locks.get(name_value,false)):available+=int(amount)
	return available if total<=int(owned) else 0
static func prepare_craft(inventory: Dictionary,instances: Dictionary,next_id: int,locks: Dictionary={},now: int=-1) -> Dictionary:
	if not rules_valid() or not time_available(now):return {"ok":false,"code":"source_condition","error":"원본 제작 규칙·기간 확인 필요"}
	if available_coins(inventory,instances,locks)<REQUIRED:return {"ok":false,"code":"source_currency","error":"잠기지 않은 원본 마법인형 제작 코인 3,000,000개 필요 · 기존 일반 코인 보존"}
	var bag: Dictionary=inventory.duplicate(true);var physicals: Dictionary=instances.duplicate(true);var remaining: int=REQUIRED
	var name_value: String=str(record(COIN).name)
	for id: String in instances:
		var entry: Variant=instances[id]
		if not entry is Dictionary or entry.get("name","")!=name_value or not entry.get("record") is Dictionary or not exact(entry.record,COIN) or bool(locks.get(id,false)) or bool(locks.get(name_value+"@@@"+id,false)) or bool(locks.get(name_value,false)):continue
		var used: int=mini(remaining,int(entry[QUANTITY]));remaining-=used
		if int(entry[QUANTITY])==used:physicals.erase(id)
		else:physicals[id][QUANTITY]=int(entry[QUANTITY])-used
		if remaining==0:break
	bag[name_value]=int(bag[name_value])-REQUIRED
	if int(bag[name_value])==0:bag.erase(name_value)
	var ticket: Dictionary=record();var count: Variant=bag.get(str(ticket.name),0)
	if not integer(count) or int(count)<0 or int(count)>=2147483647:return {"ok":false,"code":"quantity","error":"제작 결과 수량 오류 · 재료 보존"}
	var identity: int=next_safe_id(instances,next_id)
	physicals[str(identity)]={"name":str(ticket.name),"level":0,"record":ticket,"source_craft_id":RECIPE}
	bag[str(ticket.name)]=int(count)+1
	return {"ok":true,"inventory":bag,"item_instances":physicals,"next_item_instance_id":identity+1,"ticket_instance_id":str(identity),"consumed_source_coins":REQUIRED}
static func prepare_ticket(inventory: Dictionary,instances: Dictionary,cards: Dictionary,selected: String="",locks: Dictionary={}) -> Dictionary:
	if not rules_valid():return {"ok":false,"code":"source_rules","error":"카드권 원본 연결 오류"}
	var name_value: String=str(record().name);var choice: String="";var count: Variant=inventory.get(name_value,0);var physical_count: int=0
	for id: String in instances:
		var entry: Variant=instances[id]
		if not entry is Dictionary or entry.get("name","")!=name_value:continue
		physical_count+=1
		if not entry.get("record") is Dictionary or not exact(entry.record,TICKET) or (not selected.is_empty() and selected!=id) or bool(locks.get(id,false)) or bool(locks.get(name_value+"@@@"+id,false)) or bool(locks.get(name_value,false)):continue
		if choice.is_empty():choice=id
	if choice.is_empty() or not integer(count) or int(count)<physical_count or int(count)<1:return {"ok":false,"code":"source_ownership","error":"카드권의 원본 개체·잠금·보유 수량 확인 필요"}
	if not cards.get("owned") is Dictionary or not cards.owned.get("마법인형") is Dictionary or not cards.get("spare") is Dictionary or not cards.spare.get("마법인형") is Dictionary:return {"ok":false,"code":"card_state","error":"카드 저장 형식 오류"}
	var next: Dictionary=cards.duplicate(true);var duplicate: bool=next.owned["마법인형"].get(CARD,false)==true
	if duplicate:
		var spare: Variant=next.spare["마법인형"].get(CARD,0)
		if not integer(spare) or int(spare)<0 or int(spare)>=1000000:return {"ok":false,"code":"duplicate_limit","error":"중복 카드 수량 확인 필요 · 카드권 보존"}
		next.spare["마법인형"][CARD]=int(spare)+1
	else:next.owned["마법인형"][CARD]=true
	var bag: Dictionary=inventory.duplicate(true);var physicals: Dictionary=instances.duplicate(true);physicals.erase(choice)
	if int(count)==1:bag.erase(name_value)
	else:bag[name_value]=int(count)-1
	return {"ok":true,"inventory":bag,"item_instances":physicals,"card_state":next,"consumed_instance_id":choice,"card_identity":CARD,"new":not duplicate}
