extends RefCounted
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
# Existing host timing policy, separate from native ItemConsumeDelay.
const HOST_COOLDOWN_SECONDS: float=0.5
const HOST_REGEN_INTERVAL: float=30.0
const ORIGIN: String="원본 SP+2·MP회복+2·300초 · TWILIGHT 기존 30초 회복 틱/0.5초 사용 대기"
static var source_identity: Dictionary={}
static var source_problem: String=""
static var _source_spec: Dictionary={}

static func _spec() -> Dictionary:
	var identity: Dictionary=SOURCE.identity()
	if identity.is_empty():source_problem=SOURCE.problem();return {}
	if not _source_spec.is_empty():source_problem="";return _source_spec
	var item: Dictionary=SOURCE.row("ItemClass",376)
	var buff: Dictionary=SOURCE.row("BuffClass",39)
	if item.is_empty() or buff.is_empty():source_problem="원본 지혜 물약의 ItemClass/BuffClass 입력이 없습니다.";return {}
	if item.get("TestItem")!=false or item.get("GradeID")!=1 or not SOURCE.declared_exclusion("ItemClass",item).is_empty() or not SOURCE.declared_exclusion("BuffClass",buff).is_empty():source_problem="원본 지혜 물약이 제외되었거나 기존 일반 물약 계약과 다릅니다.";return {}
	var item_input: Dictionary=_values("ItemBonus","ItemClassID",376)
	var buff_input: Dictionary=_values("BuffBonus","BuffClassID",39)
	if item_input.has("error") or buff_input.has("error"):source_problem=str(item_input.get("error",buff_input.get("error","")));return {}
	var values: Dictionary=item_input.get("values",{})
	var buff_values: Dictionary=buff_input.get("values",{})
	if values.size()!=4 or buff_values.size()!=2:source_problem="원본 지혜 물약의 지원 효과 집합이 다릅니다.";return {}
	for kind: String in ["BuffClassID","BuffDuration","ItemConsumeDelay","ItemConsumeEffectSpriteID"]:
		if not values.has(kind):source_problem="원본 지혜 물약 효과가 없습니다: "+kind;return {}
	if values.BuffClassID!=39 or not buff_values.has("SpellPower") or not buff_values.has("RegenMP"):source_problem="원본 지혜 물약 버프 참조·수치 계약이 다릅니다.";return {}
	for field: String in ["IsEraseOnAttack","IsEraseOnAttacked","IsEraseOnMove","IsEraseOnSpellCastAndShieldIt","IsEraseOnSkillCastAndShieldIt","IsEraseOnItemUse","IsEraseOnSpellAttacked","IsEraseOnSkillAttacked","IsEraseOnCast","IsEraseOnHealed","IsAbsoluteTimeBuff","IsImmuneToDead"]:
		if not buff.get(field) is bool or buff.get(field):source_problem="원본 지혜 물약 버프의 미지원 유지 조건: "+field;return {}
	if buff.get("IsEraseOnTimeEnd")!=true or not _integer(buff.get("BuffGroupID")):source_problem="원본 지혜 물약의 만료·버프 그룹 계약이 다릅니다.";return {}
	var label: Dictionary=SOURCE.row("DescData_Korean",int(item.get("DescID",0)))
	if not label.get("Description") is String or str(label.Description).is_empty():source_problem="원본 지혜 물약 이름 입력이 없습니다.";return {}
	_source_spec={"schema":"twilight.source523.wisdom.v1","item_id":376,"name":str(label.Description),"buff_id":39,"group":buff.BuffGroupID,"duration":values.BuffDuration,"sp":buff_values.SpellPower,"mp_regen":buff_values.RegenMP,"source_consume_delay_raw":values.ItemConsumeDelay,"host_cooldown_seconds":HOST_COOLDOWN_SECONDS,"host_regen_interval":HOST_REGEN_INTERVAL,"origin":ORIGIN}
	# Archive provenance is not a generated model hash or a gameplay observation.
	source_identity=identity.duplicate(true)
	source_problem=""
	return _source_spec

static func _values(table: String,field: String,id: int) -> Dictionary:
	var values: Dictionary={}
	for link: Dictionary in SOURCE.related(table,field,id):
		var bonus: Dictionary=SOURCE.row("Bonus",int(link.get("BonusID",-1)))
		var type: Dictionary=SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1))) if not bonus.is_empty() else {}
		if bonus.is_empty() or type.is_empty():return {"error":"원본 지혜 물약 Bonus/BonusType 참조 없음: "+table}
		var kind: String=str(type.get("Name",""))
		if kind.is_empty() or values.has(kind) or bonus.get("BonusApplicationTypeID")!=0 or bonus.get("BonusApplicationTargetID")!=0 or link.get("IsPossession",false)!=false:return {"error":"원본 지혜 물약의 조건부·중복 효과: "+table}
		for condition: String in ["CharacterLevel","CharacterClass","MinSpellLevel"]:
			if link.get(condition,0)!=0:return {"error":"원본 지혜 물약의 미지원 조건: "+table+"."+condition}
		if not SOURCE.declared_exclusion(table,link).is_empty() or not SOURCE.declared_exclusion("Bonus",bonus).is_empty() or not SOURCE.declared_exclusion("BonusType",type).is_empty():return {"error":"원본 지혜 물약의 제외된 효과: "+table}
		if not _integer(bonus.get("Value")):return {"error":"원본 지혜 물약 효과 수치 입력 없음: "+table}
		values[kind]=bonus.Value
	return {"values":values}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func install(world,catalog) -> Dictionary:
	var spec: Dictionary=_spec()
	if spec.is_empty():return {}
	var item: Dictionary=catalog.record("ItemClass",int(spec.item_id))
	if item.is_empty() or item.get("TestItem",true) or catalog.label(int(item.get("DescID",0)))!=spec.name or int(item.get("GradeID",0))!=1:return {}
	var record: Dictionary=world._find_catalog_item_record(str(spec.name))
	if not record.is_empty() and (record.get("source")!="twilight-shop523-wisdom" or record.get("source_bless_raw")!=1):return {}
	if record.is_empty():
		record={"name":str(spec.name),"grade":"일반","slot":"consumable","type":"버프물약","source":"twilight-shop523-wisdom","source_item_class_id":int(spec.item_id),"source523_shop_item_id":int(spec.item_id),"source_bless_raw":1,"source523_shop_use_origin":str(spec.origin),"source_max_stack":int(item.get("MaxStackAmount",0)),"source_weight_raw":item.get("Weight",0),"droppable":item.get("IsDroppable",false),"storable":item.get("IsStorable",false),"weight":3,"desc":str(spec.origin)}
		world.item_db.append(record.duplicate(true));world.catalog_db["아이템"].append(record);world._index_item_weights()
	return {"4:376":{"name":str(spec.name),"record":record.duplicate(true)}}

static func try_use(world,name: String) -> bool:
	var record: Dictionary=world._find_catalog_item_record(name)
	if record.get("source")!="twilight-shop523-wisdom":return false
	var spec: Dictionary=_spec()
	if spec.is_empty():world.hud.show_message("지혜 물약 원문 입력 보류 · "+source_problem);return true
	if record.get("name")!=spec.name or int(record.get("source_item_class_id",0))!=int(spec.item_id) or record.get("source_bless_raw")!=1:
		world.hud.show_message("지혜 물약 원본 정체 불일치 · 보존");return true
	var count:int=int(world.inventory.get(name,0))
	if count<=0 or int(world.hp)<=0 or float(world.item_use_cooldowns.get(name,0.0))>0.0:
		world.hud.show_message("보유량·생존·물약 재사용 대기를 확인하세요");return true
	var old_buffs:Dictionary=world.active_item_buffs.duplicate(true)
	var old_cooldowns:Dictionary=world.item_use_cooldowns.duplicate(true)
	var group:String="source523:buffgroup:"+str(int(spec.group))
	for key:String in world.active_item_buffs.keys():
		var current:Variant=world.active_item_buffs[key]
		if current is Dictionary and current.get("group")==group:world.active_item_buffs.erase(key)
	world.inventory[name]=count-1
	world.item_use_cooldowns[name]=float(spec.host_cooldown_seconds)
	world.active_item_buffs[name]={"group":group,"source_buff_id":int(spec.buff_id),"source523_erase_on_dead":true,"duration":float(spec.duration),"remaining":float(spec.duration),"sp":int(spec.sp),"mp_regen_tick":int(spec.mp_regen),"tick_interval":float(spec.host_regen_interval),"tick_elapsed":0.0}
	if world._save_game(true)!=OK:
		world.inventory[name]=count;world.active_item_buffs=old_buffs;world.item_use_cooldowns=old_cooldowns
		world._update_hud();world.hud.show_message("지혜 물약 저장 실패 · 물약·버프 보존");return true
	world._update_hud();world.hud.show_message(str(spec.name)+" 사용 · "+str(spec.origin))
	return true

static func clear_on_death(world) -> void:
	for key:String in world.active_item_buffs.keys():
		var buff:Variant=world.active_item_buffs[key]
		if buff is Dictionary and buff.get("source523_erase_on_dead",false):world.active_item_buffs.erase(key)
