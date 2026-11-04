extends RefCounted
## Exact crafting qualifications; the offline reset clock is a labelled host policy.

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and float(value)==float(int(value)) and int(value)>=minimum and int(value)<=maximum

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema")!="patch523-craft-conditions-v1": return false
	if not integer(value.get("min_level"),0,1000) or not integer(value.get("max_level"),0,1000): return false
	if int(value.max_level)>0 and int(value.max_level)<int(value.min_level): return false
	if not value.has("quota"): return true
	var quota: Variant=value.quota
	if not quota is Dictionary or not integer(quota.get("limit"),1,1000000) or not integer(quota.get("period_seconds"),604800,604800) or not integer(quota.get("anchor_unix"),0,2147483647): return false
	var source: Variant=quota.get("source_restriction")
	return source is Dictionary and integer(source.get("ID"),1,2147483647) and int(source.get("Value",-1))==int(quota.limit) and source.get("isMultiCount")==true and source.get("ServiceTypeID")==13 and source.get("RefreshUnitID")==71 and quota.get("clock_origin") is String and not str(quota.clock_origin).is_empty()

static func restore(value: Variant) -> Dictionary:
	# Preserve damaged state rather than turn a failed import into free quota.
	return value.duplicate(true) if value is Dictionary else {"blocked":true,"original":value}

static func valid_usage(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if int(value.get("schema",0))!=1 or not value.get("recipes") is Dictionary or value.get("blocked",false): return false
	for entry: Variant in value.recipes.values():
		if not entry is Dictionary or not integer(entry.get("bucket"),-1000000,1000000) or not integer(entry.get("used"),0,1000000) or not entry.get("schedule") is String: return false
	return true

static func stage(recipe: Dictionary, count: int, context: Dictionary) -> Dictionary:
	if not recipe.has("craft_conditions"): return {"ok":true}
	var condition: Variant=recipe.craft_conditions
	if not valid(condition): return {"ok":false,"reason":"원본 제작 자격 구조를 확인하세요"}
	if int(context.get("level",0))<int(condition.min_level): return {"ok":false,"reason":"원본 제작 조건 · 레벨 %d 이상 필요" % int(condition.min_level)}
	if int(condition.max_level)>0 and int(context.get("level",0))>int(condition.max_level): return {"ok":false,"reason":"원본 제작 조건 · 레벨 %d 이하 필요" % int(condition.max_level)}
	if not condition.has("quota"): return {"ok":true}
	if not context.has("usage") or not valid_usage(context.usage) or not integer(context.get("now"),0,4102444800): return {"ok":false,"reason":"제작 제한 저장·시각 확인 필요 · 재료 보존"}
	var quota: Dictionary=condition.quota
	var ledger: Dictionary=context.usage.duplicate(true)
	if ledger.is_empty(): ledger={"schema":1,"recipes":{}}
	var bucket: int=int(floor(float(int(context.now)-int(quota.anchor_unix))/float(quota.period_seconds)))
	var schedule: String="%d:%d" % [int(quota.period_seconds),int(quota.anchor_unix)]
	var previous: Dictionary=ledger.recipes.get(recipe.id,{})
	if not previous.is_empty() and (previous.schedule!=schedule or bucket<int(previous.bucket)): return {"ok":false,"reason":"제작 제한 시각·일정 변경 확인 필요 · 이전 횟수 보존"}
	var used: int=int(previous.get("used",0)) if int(previous.get("bucket",bucket))==bucket else 0
	if count<1 or used+count>int(quota.limit): return {"ok":false,"reason":"원본 주간 제작 제한 · 이번 주 %d/%d회" % [used,int(quota.limit)],"quota_used":used,"quota_limit":int(quota.limit)}
	ledger.recipes[recipe.id]={"bucket":bucket,"used":used+count,"schedule":schedule}
	return {"ok":true,"usage_after":ledger,"quota_used":used,"quota_limit":int(quota.limit)}

static func brief(recipe: Dictionary, context: Dictionary) -> String:
	if not recipe.has("craft_conditions"): return ""
	var condition: Variant=recipe.craft_conditions
	if not valid(condition): return "원본 제작 자격 미확인"
	if condition.has("quota"):
		var quote: Dictionary=stage(recipe,1,context)
		var clock: Dictionary=Time.get_datetime_dict_from_unix_time(int(condition.quota.anchor_unix)+32400)
		var used: String=str(int(quote.quota_used)) if quote.has("quota_used") else "?"
		return "원본 주간 제한 %s/%d회 · 초기화 %s %02d:%02d KST (게임 설정)" % [used,int(condition.quota.limit),["일","월","화","수","목","금","토"][int(clock.weekday)],int(clock.hour),int(clock.minute)]
	return "원본 제작 조건 · 레벨 %d 이상" % int(condition.min_level) if int(condition.min_level)>0 else ""

static func summary(recipe: Dictionary, context: Dictionary) -> String:
	if not recipe.has("craft_conditions"): return ""
	var condition: Variant=recipe.craft_conditions
	if not valid(condition): return "원본 제작 자격 미확인"
	var lines: PackedStringArray=[]
	if int(condition.min_level)>0: lines.append("원본 제작 조건 · 레벨 %d 이상" % int(condition.min_level))
	if int(condition.max_level)>0: lines.append("원본 제작 조건 · 레벨 %d 이하" % int(condition.max_level))
	if condition.has("quota"):
		lines.append(str(condition.get("origin","원본 제작 횟수 제한")))
		var quote: Dictionary=stage(recipe,1,context)
		lines.append("이번 주 %d/%d회" % [int(quote.quota_used),int(quote.quota_limit)] if quote.get("ok",false) else str(quote.get("reason","횟수 확인 필요")))
		lines.append(str(condition.quota.clock_origin))
	return "\n".join(lines)
