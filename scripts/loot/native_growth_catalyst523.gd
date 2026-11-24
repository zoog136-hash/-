extends RefCounted
## The active original Araukia dose has two steps: immediate EXP with its
## authored buff, then the original physical material only on expiry.
## No historic growth catalyst, reward substitution, or wallet conversion.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const FIELDS=preload("res://scripts/loot/current523_native_fields.gd")
const ITEM_ID:=371558
const REWARD_ID:=216053
const BUFF_ID:=98978
const KEY:="source_growth_catalyst523_expiry"
const ACTIVE_KEY:="아우라키아의 성장 물약"
const ITEM_LINKS:Dictionary={
	818738:[2403238,"DeleteTime","Time",0,298,283348],
	818748:[2403248,"ItemConsumeDelay","MilliSeconds",5000,0,0],
	818758:[2403258,"BuffClassID","BuffClassID",98978,0,0],
	818768:[2403268,"BuffDuration","Seconds",3600,0,0],
	818778:[2403278,"ItemConsumeEffectSpriteID","SpriteID",751,0,0],
	818788:[2403288,"IgnoreUseItemDuringBuff","TrueFalse",1,0,0],
	818798:[2403298,"Experience","Value",20000000,0,0],
	818808:[2403308,"CannotUseBuffGroup","BuffGroupID",624,0,0],
}
const BUFF_LINKS:Dictionary={
	410168:[2403318,"HPPotionIncreasePercent","Percentage",100000,0,0],
	410178:[2403328,"ExperienceAdditionPercent","Percentage",700000,0,0],
	410188:[2403338,"PVEDamageReduction","Value",3,0,0],
	410198:[2403348,"RewardGroupTypeID","RewardGroupTypeID",478,0,0],
	410208:[2403358,"RangeDamageReductionPercent","Percentage",10000,0,0],
	410218:[2403368,"MagicDamageReductionPercent","Percentage",10000,0,0],
}
const EFFECTS:Dictionary={"xp":70,"potion_heal_pct":10,"pve_damage_reduction":3,"source_371558_ranged_reduction":1,"source_371558_magic_reduction":1}
const HOLD_REASONS:Array=["unsupported_item_bonus:Experience","unsupported_buff_effect:RewardGroupTypeID","unsupported_buff_effect:RangeDamageReductionPercent","unsupported_buff_effect:MagicDamageReductionPercent"]

static func matched(rows:Array, expected:Dictionary, possession:bool) -> bool:
	if rows.size()!=expected.size():return false
	var remaining:Dictionary=expected.duplicate()
	for row:Dictionary in rows:
		var id:int=int(row.get("ID",0))
		if not remaining.has(id):return false
		var v:Array=remaining[id]
		var b:Dictionary=row.get("bonus",{})
		if b.get("ID")!=v[0] or row.get("bonus_type",{}).get("Name")!=v[1] or row.get("unit",{}).get("Name")!=v[2] or b.get("Value")!=v[3] or b.get("BonusApplicationTypeID")!=v[4] or b.get("BonusApplicationTargetID")!=v[5]:return false
		if possession:
			if row.get("IsPossession")!=false:return false
		elif row.get("CharacterLevel")!=0 or row.get("CharacterClass")!=0 or row.get("MinSpellLevel")!=0:return false
		remaining.erase(id)
	return remaining.is_empty()

## Only this newly wired active product has this exact original issue end.
## Do not inherit the generic offline rotation of older event selections.
static func before_issue_end(unix_seconds:float,source_offset_minutes:int)->bool:
	var expiry:int=Time.get_unix_time_from_datetime_string("2027-03-24T05:00:00")-clampi(source_offset_minutes,-720,840)*60
	return unix_seconds<expiry

static func reward() -> Dictionary:
	var group:Array[Dictionary]=SOURCE.related("RewardGroup","RewardGroupTypeID",478)
	if group.size()!=1 or group[0].get("ID")!=638 or group[0].get("RewardID")!=431448:return {}
	var row:Dictionary=SOURCE.row("Reward",431448)
	var item:Dictionary=SOURCE.row("ItemClass",REWARD_ID)
	if row.get("RewardTypeID")!=2 or row.get("RewardClassID")!=REWARD_ID or row.get("Amount")!=15 or row.get("RewardGetTimeTypeID")!=2 or row.get("CharacterClassID")!=0 or row.get("UseImmediately")!=false or row.get("ClanOnly")!=false or row.get("RewardEnhancementTypeID")!=1 or row.get("ItemBlessCodeID")!=1 or row.get("Ranking")!=0:return {}
	if item.get("TestItem")!=false or item.get("CategoryID")!=10 or item.get("IsCraftable")!=true or not SOURCE.declared_exclusion("ItemClass",item).is_empty():return {}
	return {"item_class_id":REWARD_ID,"amount":15,"bless_raw":1,"enchant":0}

static func profile(record:Dictionary,definition:Dictionary) -> Dictionary:
	if record.get("source_item_class_id")!=ITEM_ID:return {}
	var raw:Dictionary=definition.get("original_item",{})
	var spec:Dictionary=FIELDS.field(record,"source_use_spec",{})
	var buff:Dictionary=spec.get("source_buff_class",{})
	var group:Dictionary=spec.get("source_buff_group",{})
	if raw.get("ID")!=ITEM_ID or raw.get("TestItem")!=false or raw.get("CategoryID")!=3 or raw.get("CanUseWhenInvisible")!=true or raw.get("ServiceRegionCode")!="" or raw.get("TargettingTypeID")!=1:return {}
	if spec.get("kind")!="source_timed_buff" or spec.get("blocked_reasons")!=HOLD_REASONS or spec.get("typed_effects")!={"potion_heal_pct":10,"xp":70,"pve_damage_reduction":3}:return {}
	if buff.get("ID")!=BUFF_ID or buff.get("BuffGroupID")!=624 or buff.get("IsImmuneToCancellation")!=true or buff.get("IsImmuneToDead")!=true or buff.get("IsEraseOnTimeEnd")!=true or buff.get("IsAbsoluteTimeBuff")!=false or group.get("ID")!=624 or group.get("IsAllowOverlap")!=false:return {}
	if not matched(definition.get("item_bonus",[]),ITEM_LINKS,true) or not matched(spec.get("source_buff_bonus",[]),BUFF_LINKS,false):return {}
	var date:Dictionary=SOURCE.row("DateTimes_Korean",283348)
	if date.get("Year")!=2027 or date.get("Month")!=3 or date.get("Day")!=24 or date.get("Hour")!=5 or date.get("Minute")!=0 or reward().is_empty():return {}
	return {"source_exp":20000000,"minimum_level":0,"can_use_when_invisible":true,"consume_delay_ms":5000,"consume_effect_sprite_id":751,
		"duration_seconds":3600,"source_buff_class":buff,"source_buff_group":group,"buff_class_id":BUFF_ID,
		"ignore_use_during_buff":true,"cannot_use_buff_groups":[624],"growth_catalyst":true}
