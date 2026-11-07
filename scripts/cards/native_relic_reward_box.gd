extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Explicit deterministic box opening, independent of unresolved quest claims.
const DATA=preload("res://scripts/cards/patch523_slot_data.gd")
const Unlock=preload("res://scripts/cards/native_relic_unlock_item.gd")
const ITEM: int=346921
const SCROLL: int=365758

static func definition(item_id: int) -> Dictionary:
	if DATA.relic_acquisition.is_empty():return {}
	if item_id==ITEM:return DATA.relic_acquisition.box
	for entry: Dictionary in DATA.relic_acquisition.get("box",{}).get("contents",[]):
		if int(entry.entity.raw.ItemClassID)==item_id:return entry.item_definition
	return {}

static func record(item_id: int=ITEM) -> Dictionary:
	if item_id==Unlock.ITEM:return Unlock.record()
	var source: Dictionary=definition(item_id)
	if source.is_empty():return {}
	var item: Dictionary=source.item.raw
	return {"name":str(item.Name),"source":"lineagem_patch523","source_snapshot":"patch523","source_item_class_id":item_id,"sourceId":"m523:item:"+str(item_id),"type":"소모품","slot":"consumable","grade":str(source.grade.raw.Name),"source_grade_id":int(item.GradeID),"weight":float(item.Weight)/100.0,"stackable":bool(source.category.raw.IsStackable),"droppable":bool(item.IsDroppable),"storable":bool(item.IsStorable),"sellable":false,"source_item":item.duplicate(true),"desc":"에바의 계시 · 특별한 성물 소환 주문서 각 1개 확정" if item_id==ITEM else "추가 성물 소환 주문서 · 원본 사용 조건 확인 필요","source_image_status":"original_icon_not_installed"}

static func exact(value: Dictionary,item_id: int=ITEM) -> bool:
	return value.get("source","")=="lineagem_patch523" and value.get("source_snapshot","")=="patch523" and value.get("sourceId","")=="m523:item:"+str(item_id) and value.get("source_item_class_id",0)==item_id

static func recognized(value: Dictionary) -> bool:
	return (exact(value) or exact(value,SCROLL)) and not str(value.get("name","")).is_empty()

static func install(catalog: Dictionary) -> void:
	if not catalog.get("아이템") is Array:return
	for item_id: int in [ITEM,SCROLL]:
		if record(item_id).is_empty():continue
		var exists: bool=false
		for entry: Dictionary in catalog["아이템"]:
			if exact(entry,item_id):exists=true;break
		# Exact source IDs distinguish same-name variants; no legacy aliasing.
		if not exists:catalog["아이템"].append(record(item_id))

static func rules_valid() -> bool:
	var box: Dictionary=DATA.relic_acquisition.get("box",{})
	if box.is_empty():return false
	if int(box.item.raw.ID)!=ITEM or bool(box.item.raw.TestItem) or box.category.raw.Name!="LuckyBag" or not bool(box.category.raw.IsConsumable) or not box.class_limits.is_empty():return false
	for key: String in ["LevelLimitMin","LevelLimitMax","MaxLevelLimitMin","MaxLevelLimitMax"]:
		if int(box.item.raw[key])!=0:return false
	if str(box.item.raw.ServiceRegionCode)!="" or box.effects.size()!=1 or int(box.lucky_bag.raw.ID)!=81612:return false
	var effect: Dictionary=box.effects[0]
	if bool(effect.link.raw.IsPossession) or effect.type.raw.Name!="LuckyBagClassID" or effect.unit.raw.Name!="LuckyBagClassID" or int(effect.bonus.raw.Value)!=81612 or int(effect.bonus.raw.BonusApplicationTypeID)!=0 or int(effect.bonus.raw.BonusApplicationTargetID)!=0:return false
	if box.contents.size()!=2:return false
	var found: Dictionary={}
	for entry: Dictionary in box.contents:
		var row: Dictionary=entry.entity.raw
		if int(row.ItemClassID) not in [Unlock.ITEM,SCROLL] or found.has(int(row.ItemClassID)) or int(row.LuckyBagClassID)!=81612 or entry.type.raw.Name!="IsGiven" or int(row.Probability)!=0 or int(row.ItemAmount)!=1 or int(row.ItemBlessCodeID)!=1 or int(row.ItemEnchant)!=0 or not entry.class_limits.is_empty():return false
		found[int(row.ItemClassID)]=true
	return found.size()==2

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value))

static func prepare(inventory: Dictionary,instances: Dictionary,next_id: int,selected: String="",locks: Dictionary={}) -> Dictionary:
	if not rules_valid():return {"ok":false,"code":"source_rules","error":"상자 원본 연결 검증 실패 · 아이템 보존"}
	var name_value: String=str(record().name)
	var choice: String=""
	for id: String in instances:
		if not selected.is_empty() and selected!=id:continue
		var entry: Variant=instances[id]
		if not entry is Dictionary or entry.get("name","")!=name_value or not entry.get("record") is Dictionary or not exact(entry.record) or entry.record.get("name","")!=name_value:continue
		if bool(locks.get(id,false)) or bool(locks.get(name_value+"@@@"+id,false)):continue
		choice=id;break
	if choice.is_empty():return {"ok":false,"code":"source_ownership","error":"선택한 상자의 원본 연결·잠금을 확인하세요 · 아이템 보존"}
	var count: Variant=inventory.get(name_value,0)
	if not integer(count) or int(count)<1:return {"ok":false,"code":"quantity","error":"상자 수량 오류 · 아이템 보존"}
	var physical_count: int=0
	for entry: Variant in instances.values():
		if entry is Dictionary and entry.get("name","")==name_value:physical_count+=1
	if physical_count>int(count) or next_id<1:return {"ok":false,"code":"quantity","error":"상자 물리 보유 정보 오류 · 아이템 보존"}
	var bag: Dictionary=inventory.duplicate(true)
	var physicals: Dictionary=instances.duplicate(true)
	if int(count)==1:bag.erase(name_value)
	else:bag[name_value]=int(count)-1
	physicals.erase(choice)
	var candidate: int=next_id
	# Do not reuse the consumed identity even when an old counter is stale.
	for id: String in instances:
		if id.is_valid_int():candidate=maxi(candidate,int(id)+1)
	var rewards: Array[Dictionary]=[]
	for content: Dictionary in DATA.relic_acquisition.get("box",{}).get("contents",[]):
		var item_id: int=int(content.entity.raw.ItemClassID)
		var reward: Dictionary=record(item_id)
		var current: Variant=bag.get(str(reward.name),0)
		if not integer(current) or int(current)<0 or int(current)>=2147483647:return {"ok":false,"code":"reward_quantity","error":"보상 아이템 수량 오류 · 상자 보존"}
		while physicals.has(str(candidate)):candidate+=1
		physicals[str(candidate)]={"name":str(reward.name),"level":0,"record":NATIVE_FIELDS.full(reward).duplicate(true),"source_reward_entity_id":int(content.entity.raw.ID),"source_reward_bless_code_id":1}
		bag[str(reward.name)]=int(current)+1
		rewards.append({"item_class_id":item_id,"name":str(reward.name),"instance_id":str(candidate),"quantity":1})
		candidate+=1
	return {"ok":true,"inventory":bag,"item_instances":physicals,"next_item_instance_id":candidate,"rewards":rewards,"consumed_instance_id":choice,"consumed_quantity":1}
