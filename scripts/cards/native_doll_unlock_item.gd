extends RefCounted
## Exact source item-to-buff use. Display names never establish ownership.
const DATA=preload("res://data/cards/base508_option_extensions.json")
const FIELD: String="native_doll_unlock"
const ITEM: int=346901
const BUFF: int=91531
const BONUS: int=2171301
static func marker() -> Dictionary:
	return {"source_snapshot":"base508","source_item_class_id":ITEM,"source_buff_class_id":BUFF,"source_bonus_id":BONUS}
static func validate(state: Dictionary) -> String:
	if not state.has(FIELD):return ""
	var value: Variant=state[FIELD]
	if not value is Dictionary:return "추가 인형 해금 저장 형식 오류"
	for key: String in marker():
		if not value.has(key) or value[key]!=marker()[key]:return "추가 인형 해금 원본 연결 오류"
	return ""
static func unlocked(state: Dictionary) -> bool:return state.has(FIELD) and validate(state).is_empty()
static func record() -> Dictionary:
	var source: Dictionary=DATA.data.subslot_unlock_item
	return {"name":str(source.name),"source":"lineagem_base508","source_snapshot":"base508","source_item_class_id":ITEM,"sourceId":"m508:item:"+str(ITEM),"type":"소모품","slot":"consumable","grade":str(source.grade.Name),"source_grade_id":int(source.item.GradeID),"weight":1,"stackable":true,"source_item":source.item.duplicate(true),"desc":"추가 마법인형 소환 해금 · 95레벨 필요 · 원본 아이템 사용","source_image_status":"original_icon_not_installed"}
static func exact(value: Dictionary) -> bool:
	return value.get("source","")=="lineagem_base508" and value.get("source_snapshot","")=="base508" and value.get("sourceId","")=="m508:item:"+str(ITEM) and value.get("source_item_class_id",0)==ITEM
static func install(catalog: Dictionary) -> Dictionary:
	var target: Dictionary=record()
	if not catalog.get("아이템",[]) is Array:return {"ok":false,"reason":"item_catalog"}
	for entry: Dictionary in catalog.get("아이템",[]):
		if exact(entry):return {"ok":true,"existing":true}
		if entry.get("name","")==target.name:return {"ok":false,"reason":"unverified_same_name_no_alias"}
	if not catalog.has("아이템"):catalog["아이템"]=[]
	catalog["아이템"].append(target)
	return {"ok":true}
static func source_rules_valid() -> bool:
	var source: Dictionary=DATA.data.subslot_unlock_item
	if int(source.item.ID)!=ITEM or not bool(source.category.IsConsumable) or int(source.item.MaxStackAmount)!=1:return false
	var link: bool=false;var unlock: bool=false;var permanent: bool=false
	for effect: Dictionary in source.effects:
		if int(effect.bonus.ID)==BONUS and effect.type.Name=="BuffClassID" and int(effect.bonus.Value)==BUFF and not bool(effect.link.IsPossession):link=true
	for effect: Dictionary in source.buff_effects:
		if effect.type.Name=="MagicDollSubSlotOpened" and int(effect.bonus.Value)==1:unlock=true
		if effect.type.Name=="SaveDB" and int(effect.bonus.Value)==1:permanent=true
	return link and unlock and permanent
static func prepare(state: Dictionary,inventory: Dictionary,instances: Dictionary,level: int) -> Dictionary:
	if not source_rules_valid():return {"ok":false,"code":"source_rules","error":"원본 해금 아이템 정의 검증 실패"}
	if not validate(state).is_empty():return {"ok":false,"code":"state","error":validate(state)}
	if unlocked(state):return {"ok":false,"code":"already_unlocked","error":"이미 에바의 부름을 습득했습니다 · 아이템 보존"}
	if level<95:return {"ok":false,"code":"level","error":"추가 인형 해금은 95레벨부터 가능합니다"}
	var selected: String="";var name_value: String=str(record().name)
	for key: String in instances:
		var physical: Variant=instances[key]
		if not physical is Dictionary or physical.get("name","")!=name_value or not physical.get("record") is Dictionary:continue
		if exact(physical.record):selected=key;break
	if selected.is_empty():return {"ok":false,"code":"source_ownership","error":"원본 ItemClass346901의 물리 소유권 확인 필요 · 이름만으로 소모하지 않습니다"}
	var count: Variant=inventory.get(name_value,0)
	if not (count is int or count is float) or not is_finite(float(count)) or float(count)!=floorf(float(count)) or int(count)<1:return {"ok":false,"code":"quantity","error":"해금 아이템 보유 수량 오류"}
	var physical_count: int=0
	for entry: Variant in instances.values():
		if entry is Dictionary and entry.get("name","")==name_value:physical_count+=1
	if physical_count>int(count):return {"ok":false,"code":"source_ownership_count","error":"아이템 수량과 물리 소유권 수 불일치 · 기존 아이템 보존"}
	var next: Dictionary=state.duplicate(true);next[FIELD]=marker();next.revision=int(next.revision)+1
	var bag: Dictionary=inventory.duplicate(true);var physical: Dictionary=instances.duplicate(true)
	if int(count)==1:bag.erase(name_value)
	else:bag[name_value]=int(count)-1
	physical.erase(selected)
	return {"ok":true,"state":next,"inventory":bag,"item_instances":physical,"consumed_item_class_id":ITEM,"consumed_quantity":1,"consumed_instance_id":selected}
