extends RefCounted
## Shared, exact source identity for ordinary and currently usable spirit
## smelting materials. Rule selection stays with SmithSmelt. Legacy dated
## effects still require their own proven active issue and expiry policy.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const D=preload("res://scripts/loot/patch523_monster_drops.gd")
const ORDINARY:=289162
const POOLS:Dictionary={
	359652:92,359662:82,359672:72,359682:62,
	372058:138,372068:148,372078:158,372088:168,
	374544:138,374554:148,374564:158,374574:168
}
const LIMITED:Dictionary={374544:true,374554:true,374564:true,374574:true}
const CUTOFF_ID:=254042

static func known(id:int)->bool:
	return id==ORDINARY or POOLS.has(id)

static func kind(record:Dictionary)->String:
	if record.get("source_m_native_item")!=true or record.get("source_definition_archive")!=SOURCE.identity():return ""
	var id:int=int(record.get("source_item_class_id",0))
	if not known(id):return ""
	var definition:Dictionary=D.item_definition(record)
	var raw:Dictionary=definition.get("original_item",{})
	if raw.get("ID")!=id or raw.get("TestItem")!=false or raw.get("CategoryID")!=10572 or raw.get("TargettingTypeID")!=8 or raw.get("ServiceRegionCode")!="":return ""
	var rows:Array=definition.get("item_bonus",[])
	if id==ORDINARY:return "smelt" if rows.is_empty() else ""
	if rows.size()!=(2 if LIMITED.has(id) else 1):return ""
	var pool_seen:bool=false
	var date_seen:bool=false
	for row:Dictionary in rows:
		var b:Dictionary=row.get("bonus",{})
		if row.get("IsPossession")!=false:return ""
		match str(row.get("bonus_type",{}).get("Name","")):
			"SpiritSmelt":
				if pool_seen or b.get("BonusApplicationTypeID")!=0 or b.get("BonusApplicationTargetID")!=0 or b.get("Value")!=POOLS[id] or row.get("unit",{}).get("Name")!="Value":return ""
				pool_seen=true
			"DeleteTime":
				if date_seen or not LIMITED.has(id) or b.get("BonusApplicationTypeID")!=298 or b.get("BonusApplicationTargetID")!=CUTOFF_ID or b.get("Value")!=0 or row.get("unit",{}).get("Name")!="Time":return ""
				var date:Dictionary=SOURCE.row("DateTimes_Korean",CUTOFF_ID)
				if date.get("Year")!=2027 or date.get("Month")!=2 or date.get("Day")!=24 or date.get("Hour")!=5 or date.get("Minute")!=0:return ""
				date_seen=true
			_:return ""
	return "spirit_smelt" if pool_seen and date_seen==LIMITED.has(id) else ""

static func period_allows(id:int,unix_seconds:int,source_offset_minutes:int)->bool:
	if not LIMITED.has(id):return true
	var expiry:int=Time.get_unix_time_from_datetime_string("2027-02-24T05:00:00")-clampi(source_offset_minutes,-720,840)*60
	return unix_seconds<expiry
