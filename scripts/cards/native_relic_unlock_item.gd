extends RefCounted
## Typed523 item -> infinite buff -> saved HolyStuffSubSlotOpened declaration.
## The reward's display name does not establish a numeric use-level gate.
const DATA=preload("res://scripts/cards/patch523_slot_data.gd")
const FIELD: String="native_relic_unlock"
const ITEM: int=365748
const BUFF: int=95648
const BONUS: int=2357388

static func marker() -> Dictionary:
	return {"source_snapshot":"patch523","source_item_class_id":ITEM,"source_buff_class_id":BUFF,"source_bonus_id":BONUS}

static func validate(state: Dictionary) -> String:
	if not state.has(FIELD):return ""
	var value: Variant=state[FIELD]
	if not value is Dictionary:return "추가 성물 해금 저장 형식 오류"
	for key: String in marker():
		if not value.has(key) or value[key]!=marker()[key]:return "추가 성물 해금 원본 연결 오류"
	return ""

static func unlocked(state: Dictionary) -> bool:
	return state.has(FIELD) and validate(state).is_empty()

static func record() -> Dictionary:
	var source: Dictionary=DATA.relic_unlock_item()
	if source.is_empty():return {}
	return {"name":str(source.name),"source":"lineagem_patch523","source_snapshot":"patch523","source_item_class_id":ITEM,"sourceId":"m523:item:"+str(ITEM),"type":"소모품","slot":"consumable","grade":str(source.grade.Name),"source_grade_id":int(source.item.GradeID),"weight":1,"stackable":true,"droppable":bool(source.item.IsDroppable),"storable":bool(source.item.IsStorable),"sellable":false,"source_item":source.item.duplicate(true),"desc":"추가 성물 소환 해금 · 원본 에바의 계시 사용","source_image_status":"original_icon_not_installed"}

static func exact(value: Dictionary) -> bool:
	return value.get("source","")=="lineagem_patch523" and value.get("source_snapshot","")=="patch523" and value.get("sourceId","")=="m523:item:"+str(ITEM) and value.get("source_item_class_id",0)==ITEM

static func install(catalog: Dictionary) -> Dictionary:
	var target: Dictionary=record()
	if target.is_empty():return {"ok":false,"reason":"slot_pack_missing"}
	if not catalog.get("아이템",[]) is Array:return {"ok":false,"reason":"item_catalog"}
	for entry: Dictionary in catalog.get("아이템",[]):
		if exact(entry):return {"ok":true,"existing":true}
		if entry.get("name","")==target.name:return {"ok":false,"reason":"unverified_same_name_no_alias"}
	if not catalog.has("아이템"):catalog["아이템"]=[]
	catalog["아이템"].append(target)
	return {"ok":true}

static func source_rules_valid() -> bool:
	var source: Dictionary=DATA.relic_unlock_item()
	if source.is_empty():return false
	if int(source.item.ID)!=ITEM or int(source.buff.ID)!=BUFF or not bool(source.category.IsConsumable) or int(source.item.MaxStackAmount)!=1:return false
	var link: bool=false;var unlock: bool=false;var permanent: bool=false;var infinite: bool=false
	for effect: Dictionary in source.effects:
		if int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0 or bool(effect.link.IsPossession):return false
		if int(effect.bonus.ID)==BONUS and effect.type.Name=="BuffClassID" and int(effect.bonus.Value)==BUFF and int(effect.type.UnitID)==16:link=true
		if effect.type.Name=="BuffDurationInfinite" and int(effect.bonus.Value)==1:infinite=true
	for effect: Dictionary in source.buff_effects:
		if int(effect.link.CharacterLevel)!=0 or int(effect.link.CharacterClass)!=0 or int(effect.link.MinSpellLevel)!=0 or int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0:return false
		if effect.type.Name=="HolyStuffSubSlotOpened" and int(effect.bonus.Value)==1:unlock=true
		if effect.type.Name=="SaveDB" and int(effect.bonus.Value)==1:permanent=true
	return link and unlock and permanent and infinite

static func prepare(state: Dictionary,inventory: Dictionary,instances: Dictionary,_level: int=0,locked: Dictionary={}) -> Dictionary:
	if not source_rules_valid():return {"ok":false,"code":"source_rules","error":"원본 성물 해금 아이템 정의 검증 실패"}
	if not validate(state).is_empty():return {"ok":false,"code":"state","error":validate(state)}
	if unlocked(state):return {"ok":false,"code":"already_unlocked","error":"이미 에바의 계시를 습득했습니다 · 아이템 보존"}
	var selected: String="";var name_value: String=str(record().name)
	var matched_locked: bool=false
	for key: String in instances:
		var physical: Variant=instances[key]
		if not physical is Dictionary or physical.get("name","")!=name_value or not physical.get("record") is Dictionary:continue
		if not exact(physical.record):continue
		# Runtime checks the global name lock. Physical locks can use the
		# production name@@@instance reference or an already normalized ID map.
		if bool(locked.get(name_value+"@@@"+key,false)) or bool(locked.get(key,false)):
			matched_locked=true;continue
		selected=key;break
	if selected.is_empty():
		if matched_locked:return {"ok":false,"code":"item_locked","error":"해금 아이템이 잠겨 있습니다 · 아이템 보존"}
		return {"ok":false,"code":"source_ownership","error":"아이템의 원본 연결을 확인할 수 없습니다 · 아이템 보존"}
	var count: Variant=inventory.get(name_value,0)
	if not (count is int or count is float) or not is_finite(float(count)) or float(count)!=floorf(float(count)) or int(count)<1:return {"ok":false,"code":"quantity","error":"해금 아이템 보유 수량 오류"}
	var physical_count: int=0
	for entry: Variant in instances.values():
		if entry is Dictionary and entry.get("name","")==name_value:physical_count+=1
	if physical_count>int(count):return {"ok":false,"code":"source_ownership_count","error":"아이템 보유 정보가 일치하지 않습니다 · 아이템 보존"}
	var next: Dictionary=state.duplicate(true);next[FIELD]=marker()
	if DATA.loaded_schema=="twilight.card-slots523.v2":next["native_relic_summon_time"]={"schema":1,"item_class_id":365758,"identity":"","slot_index":11,"expires_utc":0}
	next.revision=int(next.get("revision",0))+1
	var bag: Dictionary=inventory.duplicate(true);var physical: Dictionary=instances.duplicate(true)
	if int(count)==1:bag.erase(name_value)
	else:bag[name_value]=int(count)-1
	physical.erase(selected)
	return {"ok":true,"state":next,"inventory":bag,"item_instances":physical,"consumed_item_class_id":ITEM,"consumed_quantity":1,"consumed_instance_id":selected}
