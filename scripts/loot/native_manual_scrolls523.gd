extends RefCounted
## Reviewed manual-use owners for exact original scrolls. A manual weight
## scroll does not unlock a new automation/refresh policy; old events stay out.
const FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const WEIGHT:=2992
const IRON_SKIN:=3032
const ORACLE:=352334
const GROWTH:=355213
const ORACLE_KEY="아인하사드의 신탁서"
const RULES:Dictionary={
	2992:[4,21,1001,2170,false,["unsupported_item_bonus:AutoBuffOverlapDuration"],{"carry":180},{17:[350,"CarryPlus","Weight",18000]}],
	3032:[4,34,5,15902,true,["source_buff_timer_semantics_unresolved"],{"def":10},{36:[441,"ArmorClassBonus","Value",10]}],
	352334:[10511,93524,5514,751,true,["unsupported_buff_effect:PVEDamageReductionPercent","unsupported_buff_effect:PVEPierceDamageReductionPercent"],{"xp":15,"source_manual_pve_guard_pct":2,"source_manual_pve_amp_pct":2},{368264:[2221084,"ExperienceAdditionPercent","Percentage",150000],368284:[2221104,"PVEDamageReductionPercent","Percentage",20000],368294:[2221114,"PVEPierceDamageReductionPercent","Percentage",20000]}],
	355213:[10511,93993,5683,751,true,["unsupported_buff_effect:EinasadBlessAbsolutePercent"],{"xp":3,"source_manual_blessing_charge_pct":5},{376853:[2249133,"ExperienceAdditionPercent","Percentage",30000],376863:[2249143,"EinasadBlessAbsolutePercent","ValuePercent",5]}],
}

static func profile(record:Dictionary,definition:Dictionary)->Dictionary:
	var id:int=int(record.get("source_item_class_id",0))
	if not RULES.has(id) or record.get("source_m_native_item")!=true or record.get("source_definition_archive")!=SOURCE.identity():return {}
	var rule:Array=RULES[id]
	var raw:Dictionary=definition.get("original_item",{})
	if raw.get("ID")!=id or raw.get("TestItem")!=false or raw.get("CategoryID")!=rule[0] or raw.get("TargettingTypeID")!=1 or raw.get("CanUseWhenInvisible")!=true or raw.get("ServiceRegionCode")!="" or raw.get("LevelLimitMin")!=0 or raw.get("LevelLimitMax")!=0:return {}
	var duration: int = 960 if id==IRON_SKIN else 1800
	var expected:Dictionary={"BuffClassID":["BuffClassID",rule[1]],"ItemConsumeEffectSpriteID":["SpriteID",rule[3]],"ItemConsumeDelay":["MilliSeconds",500],"BuffDuration":["Seconds",duration]}
	if id==WEIGHT:expected["AutoBuffOverlapDuration"]=["MilliSeconds",5000]
	var rows:Array=definition.get("item_bonus",[])
	if rows.size()!=expected.size():return {}
	for row:Dictionary in rows:
		var kind:String=str(row.get("bonus_type",{}).get("Name",""))
		if not expected.has(kind) or row.get("IsPossession")!=false or not _matches(row,expected[kind][0],expected[kind][1]):return {}
		expected.erase(kind)
	var spec:Dictionary=FIELDS.field(record,"source_use_spec",{})
	if spec.get("kind")!="source_timed_buff" or spec.get("blocked_reasons")!=rule[5] or spec.get("duration_seconds")!=duration or spec.get("consume_delay_ms")!=500:return {}
	var buff:Dictionary=spec.get("source_buff_class",{});var group:Dictionary=spec.get("source_buff_group",{})
	if buff.get("ID")!=rule[1] or buff.get("BuffGroupID")!=rule[2] or group.get("ID")!=rule[2] or group.get("IsAllowOverlap")!=(id==IRON_SKIN) or group.get("IsAllowPriority")!=false or buff.get("IsEraseOnTimeEnd")!=(id!=IRON_SKIN) or buff.get("IsImmuneToCancellation")!=rule[4] or buff.get("IsImmuneToDead")!=rule[4]:return {}
	var links:Dictionary=rule[7].duplicate()
	var effects:Array=spec.get("source_buff_bonus",[])
	if effects.size()!=links.size():return {}
	for row:Dictionary in effects:
		var link:int=int(row.get("ID",0))
		if not links.has(link) or row.get("CharacterLevel")!=0 or row.get("CharacterClass")!=0 or row.get("MinSpellLevel")!=0:return {}
		var authored:Array=links[link]
		if row.get("bonus",{}).get("ID")!=authored[0] or row.get("bonus_type",{}).get("Name")!=authored[1] or not _matches(row,authored[2],authored[3]):return {}
		links.erase(link)
	var ready:Dictionary=spec.duplicate(true)
	ready["activation_status"]="unrestricted";ready["blocked_reasons"]=[]
	ready["typed_effects"]=rule[6].duplicate()
	if id==WEIGHT:ready["manual_only_auto_overlap_ms"]=5000
	# The original ItemBonus sets 960 seconds. This host expires the buff
	# at that duration because the separate source erase flag is false.
	if id==IRON_SKIN:ready["local_timer_policy"]="expire_at_original_item_duration"
	return ready

static func _matches(row:Dictionary,unit:String,value:int)->bool:
	var bonus:Dictionary=row.get("bonus",{})
	return row.get("unit",{}).get("Name")==unit and bonus.get("Value")==value and bonus.get("BonusApplicationTypeID")==0 and bonus.get("BonusApplicationTargetID")==0

## Original display name, independent of the receipted grade/storage suffix.
static func active_key(record:Dictionary,spec:Dictionary,fallback_name:String)->String:
	if record.get("source_item_class_id")==ORACLE and spec.get("typed_effects",{}).get("source_manual_pve_amp_pct")==2:return ORACLE_KEY
	return fallback_name

## Single active original title: no extra scan/array allocation per hit.
static func oracle_damage_percent(active:Dictionary,is_player:bool,field:String="source_manual_pve_amp_pct")->int:
	if is_player:return 0
	var buff:Variant=active.get(ORACLE_KEY)
	return 2 if buff is Dictionary and buff.get("source_item_class_id")==ORACLE and buff.get(field)==2 and float(buff.get("remaining",0.0))>0 else 0
