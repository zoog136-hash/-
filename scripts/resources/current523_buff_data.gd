extends RefCounted
## Original buff relationships for existing item/spell data readers only.
## No timer, probability, status, priority or replacement behavior is executed.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const BONUSES = preload("res://scripts/resources/current523_bonus_data.gd")

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func _reference(blockers: Array[String], table: String, value: Variant) -> Dictionary:
	if not _integer(value) or float(value) < 0:
		blockers.append("invalid_source_reference:"+table)
		return {}
	var row: Dictionary = SOURCE.row(table,int(value))
	if row.is_empty(): blockers.append("missing_source_reference:"+table+":"+str(int(value)))
	return row

static func _fields(row: Dictionary, names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for field: String in names:
		if row.has(field): result[field] = row[field]
	return result

static func _status(detail: Dictionary, blockers: Array[String]) -> Dictionary:
	if detail.get("type",{}).get("Name") != "StatusEffectID" or detail.get("unit",{}).get("Name") != "StatusEffectID": return {}
	var value: Variant = detail.get("bonus",{}).get("Value")
	if not _integer(value) or float(value) < 0:
		blockers.append("invalid_source_reference:StatusEffectAttr.StatusEffectID")
		return {}
	var id: int = int(value)
	return {"id":id,"buff_bonus":detail.get("link",{}),"bonus":detail.get("bonus",{}),
		"attributes":SOURCE.related("StatusEffectAttr","StatusEffectID",id),
		"reference_only":true,"can_execute":false}

static func _invoke(detail: Dictionary, blockers: Array[String]) -> Dictionary:
	if detail.get("type",{}).get("Name") != "InvokeOption": return {}
	# The existing NPC catalog joins this exact bonus through its application
	# target. Its Value is retained as raw probability, never used as an ID.
	var option: Dictionary = _reference(blockers,"InvokeOption",detail.get("bonus",{}).get("BonusApplicationTargetID"))
	var type: Dictionary = _reference(blockers,"InvokeOptionType",option.get("InvokeOptionTypeID")) if not option.is_empty() else {}
	return {"edge":detail,"source":option,"type":type,"reference_only":true,"can_execute":false}

static func describe(buff_id: int) -> Dictionary:
	var identity: Dictionary = SOURCE.identity()
	var buff: Dictionary = SOURCE.row("BuffClass",buff_id) if buff_id >= 0 and not identity.is_empty() else {}
	var blockers: Array[String] = []
	var result: Dictionary = {
		"kind":"twilight.current523.buff-data.v1","ok":false,
		"reference_only":true,"can_execute":false,"activation_authorized":false,"ownership_authorized":false,
		"buff_class_id":buff_id,"source":identity,"buff_class":buff,"group":{},
		"bonuses":[],"statuses":[],"invokes":[],"lifecycle":{},"conditions":{},
		"test_declaration":{},"blockers":blockers}
	if buff.is_empty():
		blockers.append("source_buff_unavailable")
		result["problem"] = SOURCE.problem()
		return result
	var test: Variant = buff.get("TestBuff")
	result.test_declaration = {"field":"TestBuff","present":buff.has("TestBuff"),"value":test}
	if not buff.has("TestBuff"):
		result.test_declaration = {"field":"TestBuff","status":"not_declared","present":false}
	elif typeof(test) != TYPE_BOOL:
		result.test_declaration["status"] = "invalid"
		blockers.append("source_test_declaration_invalid:BuffClass.TestBuff")
	elif test:
		result.test_declaration["status"] = "declared"
		blockers.append("source_TestBuff_true")
		result["excluded"] = true
	else:
		result.test_declaration["status"] = "declared"
	result.group = _reference(blockers,"BuffGroup",buff.get("BuffGroupID"))
	for link: Dictionary in SOURCE.related("BuffBonus","BuffClassID",buff_id):
		var bonus_id: Variant = link.get("BonusID")
		var detail: Dictionary = {}
		if _integer(bonus_id) and float(bonus_id) >= 0:
			detail = BONUSES.describe(int(bonus_id))
		else:
			detail = {"bonus":{},"type":{},"unit":{},"application_type":{},"ui_units":[],
				"blockers":["invalid_source_reference:Bonus"],"ok":false,"reference_only":true,"can_execute":false}
		detail["link"] = link
		detail["conditions"] = _fields(link,["CharacterLevel","CharacterClass","MinSpellLevel"])
		result.bonuses.append(detail)
		for issue: String in detail.get("blockers",[]):
			blockers.append("BuffBonus:"+str(link.get("ID","unknown"))+":"+issue)
		var status: Dictionary = _status(detail,blockers)
		if not status.is_empty(): result.statuses.append(status)
		var invoke: Dictionary = _invoke(detail,blockers)
		if not invoke.is_empty(): result.invokes.append(invoke)
	# These are verbatim fields, not duration, overlap, overwrite or expiry rules.
	result.lifecycle = _fields(buff,["IsImmuneToCancellation","IsImmuneToDead","IsEraseOnTimeEnd","IsAbsoluteTimeBuff",
		"IsEraseOnAttack","IsEraseOnAttacked","IsEraseOnMove","IsEraseOnSpellCastAndShieldIt",
		"IsEraseOnSkillCastAndShieldIt","IsEraseOnItemUse","IsEraseOnSpellAttacked","IsEraseOnSkillAttacked",
		"IsEraseOnCast","IsEraseOnHealed","IsEraseOnTargetChanged","IsEraseOnAttackedLimitations",
		"IsDecreaseStackOnTimeEnd"])
	result.conditions = _fields(buff,["IsGood","IsBuffGroup","BuffGroupID","BuffGroupPriority","MaxHPPercent",
		"EraseOnLevel","MaxStackCount","MPCostPercent","MinMPCost","IsOverlapByPlayer","IsObtainItemBuff"])
	# DescData/DescID text is not read; its native references stay in buff_class.
	result.ok = blockers.is_empty()
	return result
