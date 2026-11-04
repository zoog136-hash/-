extends RefCounted
## Narrow source-ID adapter for expedition fixed-card rewards. No draw pool or art data.
const CATEGORIES={1:"변신",2:"마법인형",98:"성물"}
const GRADES={1:"일반",2:"고급",3:"희귀",4:"영웅",5:"전설",32:"신화",52:"유일"}

static func identity_shape(identity:String,deck:int)->bool:
	var fields:=identity.split(":")
	return fields.size()==4 and fields[0]=="source" and fields[1] in ["m508","m523"] and fields[2]==str(deck) and fields[3].is_valid_int() and str(int(fields[3]))==fields[3] and int(fields[3])>0

static func fixed_target(source:RefCounted,item_id:int)->Dictionary:
	if not source.ready():return {}
	var targets:Array=[]
	for link:Dictionary in source.rows("ItemBonus"):
		if int(link.ItemClassID)!=item_id:continue
		var bonus:Dictionary=source.record("Bonus",int(link.BonusID))
		var type:Dictionary=source.record("BonusType",int(bonus.get("BonusTypeID",0)))
		if type.get("Name")!="BuffCardID":continue
		if bool(link.IsPossession) or int(type.UnitID)!=33 or int(bonus.BonusApplicationTypeID)!=0 or int(bonus.BonusApplicationTargetID)!=0:return {}
		targets.append(source.record("BuffCard",int(bonus.Value)))
	if targets.size()!=1 or targets[0].is_empty() or not CATEGORIES.has(int(targets[0].BuffCardDeckID)):return {}
	return targets[0]

static func registered(catalog:Dictionary,raw:Dictionary)->Dictionary:
	var deck:int=int(raw.get("BuffCardDeckID",0))
	for record:Dictionary in catalog.get(CATEGORIES.get(deck,""),[]):
		var identity:String="source:"+str(record.get("sourceId",""))
		if int(record.get("source_card_id",0))!=int(raw.get("ID",-1)) or int(record.get("source_deck_id",0))!=deck or not identity_shape(identity,deck):continue
		if record.get("source") not in ["lineagem_base508","lineagem_patch523"] or int(record.get("source_grade_id",0))!=int(raw.GradeID):return {}
		var card_namespace:String="m523" if record.get("source")=="lineagem_patch523" else "m508"
		if record.get("sourceId")!="%s:%d:%d"%[card_namespace,deck,int(raw.ID)]:return {}
		if record.get("source")=="lineagem_patch523" and record.get("source_original_card",{})!=raw:return {}
		return record
	return {}

static func supplement(catalog:Dictionary,source:RefCounted)->void:
	if not source.ready():return
	for item:Dictionary in source.rows("ItemClass"):
		var raw:Dictionary=fixed_target(source,int(item.ID))
		if raw.is_empty() or not registered(catalog,raw).is_empty():continue
		var category:String=CATEGORIES[int(raw.BuffCardDeckID)]
		# An existing conflicting identity is never overwritten or renamed.
		if catalog.get(category,[]).any(func(r:Dictionary)->bool:return int(r.get("source_card_id",0))==int(raw.ID)):continue
		var display:String=str(raw.Name).get_slice("] ",1)
		if display.is_empty():display=str(raw.Name)
		catalog[category].append({"name":display,"grade":GRADES.get(int(raw.GradeID),"미확인"),"type":"공통","source":"lineagem_patch523","source_snapshot":"patch523","source_content_snapshot":"patch523","sourceId":"m523:%d:%d"%[int(raw.BuffCardDeckID),int(raw.ID)],"source_card_id":int(raw.ID),"source_deck_id":int(raw.BuffCardDeckID),"source_grade_id":int(raw.GradeID),"source_grade_tier_id":int(raw.GradeTierID),"source_original_card":raw.duplicate(true),"source_internal_name":str(raw.Name),"source_merge_out_disabled":bool(raw.IsNoMergeOut),"source_swap_out_disabled":bool(raw.IsNoSwapOut),"source_draw_pool_pending":true,"source_visual_status":"patch523_original_pack_required","source_expedition_definition_only":true,"image_path":"","desc":"탐험 보상 원본 카드 · 원본 이미지 미설치 · 장착 효과는 카드 기능 통합 필요"})

static func register_profiles(host:Node,source:RefCounted)->void:
	if not source.ready():return
	var core:RefCounted=host.skill_awakening.core
	core.cards=core.cards.duplicate(true)
	for category:String in CATEGORIES.values():
		for record:Dictionary in host.catalog_db.get(category,[]):
			var raw:Dictionary=source.record("BuffCard",int(record.get("source_card_id",0)))
			if raw.is_empty() or registered(host.catalog_db,raw).is_empty():continue
			var identity:String="source:"+str(record.sourceId)
			if core.cards.has(identity):continue
			core.cards[identity]={"id":identity,"category":category,"name":record.name,"grade":record.grade,"source_card":raw.duplicate(true)}

static func item_conditions(source:RefCounted,item_id:int)->String:
	var item:Dictionary=source.record("ItemClass",item_id)
	if item.is_empty() or bool(item.get("TestItem",true)) or str(item.get("ServiceRegionCode","?")).is_empty()==false:return "원본 아이템 활성 조건 확인 필요"
	for field in ["LevelLimitMin","LevelLimitMax","MaxLevelLimitMin","MaxLevelLimitMax","EinasadLevel"]:
		if int(item.get(field,0))!=0:return "원본 아이템 레벨 조건은 전용 소비자 확인 필요"
	var raw:Dictionary=fixed_target(source,item_id)
	if raw.is_empty():return "원본 지정 카드 연결 없음"
	if int(raw.ServerLimitSetID)!=0 or int(raw.StartDateTimeID)!=0 or int(raw.EndDateTimeID)!=0:return "원본 카드 서버·기간 조건 확인 필요"
	return ""
