extends RefCounted
## Exact crafting qualifications; the offline reset clock is a labelled host policy.

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and float(value)==float(int(value)) and int(value)>=minimum and int(value)<=maximum

static func valid_window(value: Variant) -> bool:
	if not value is Dictionary or value.get("boundary")!="start_inclusive_end_exclusive" or not value.get("clock_origin") is String or value.clock_origin.is_empty():return false
	if not integer(value.get("start_unix"),0,4102444800) or not integer(value.get("end_unix"),1,4102444800) or value.start_unix>=value.end_unix or not integer(value.get("utc_offset_minutes"),-840,840):return false
	for pair: Array in [["source_start","start_unix"],["source_end","end_unix"]]:
		var row: Variant=value.get(pair[0])
		if not row is Dictionary or not integer(row.get("ID"),1,2147483647):return false
		for part: Array in [["Year",1970,2099],["Month",1,12],["Day",1,31],["Hour",0,23],["Minute",0,59]]:
			if not integer(row.get(part[0]),part[1],part[2]):return false
		var date: Dictionary={"year":int(row.Year),"month":int(row.Month),"day":int(row.Day),"hour":int(row.Hour),"minute":int(row.Minute),"second":0}
		var raw: int=Time.get_unix_time_from_datetime_dict(date)
		var canonical: Dictionary=Time.get_datetime_dict_from_unix_time(raw)
		for key: String in date:
			if date[key]!=canonical[key]:return false
		if raw-int(value.utc_offset_minutes)*60!=int(value[pair[1]]):return false
	return true

static func window_text(window: Dictionary) -> String:
	var first: Dictionary=window.source_start;var last: Dictionary=window.source_end
	var offset: int=int(window.utc_offset_minutes)
	var label: String="%s%02d:%02d" % ["+" if offset>=0 else "-",int(absi(offset)/60),absi(offset)%60]
	return "원본 기간 %04d-%02d-%02d %02d:%02d ~ %04d-%02d-%02d %02d:%02d · UTC%s/게임 시각 설정" % [int(first.Year),int(first.Month),int(first.Day),int(first.Hour),int(first.Minute),int(last.Year),int(last.Month),int(last.Day),int(last.Hour),int(last.Minute),label]

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema")!="patch523-craft-conditions-v1": return false
	if not integer(value.get("min_level"),0,1000) or not integer(value.get("max_level"),0,1000): return false
	if int(value.max_level)>0 and int(value.max_level)<int(value.min_level): return false
	if value.has("active_window") and not valid_window(value.active_window):return false
	if not value.has("quota"): return true
	var quota: Variant=value.quota
	if not quota is Dictionary or not integer(quota.get("limit"),1,1000000) or not integer(quota.get("anchor_unix"),0,2147483647):return false
	var source: Variant=quota.get("source_restriction")
	if not source is Dictionary or not integer(source.get("ID"),1,2147483647) or int(source.get("Value",-1))!=int(quota.limit) or source.get("ServiceTypeID")!=13 or not quota.get("clock_origin") is String or str(quota.clock_origin).is_empty():return false
	if quota.get("mode")=="bounded_lifetime":return quota.get("period_seconds")==0 and source.get("RefreshUnitID")==111 and source.get("isMultiCount")==false
	return integer(quota.get("period_seconds"),604800,604800) and source.get("isMultiCount")==true and source.get("RefreshUnitID")==71

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

static func source_recipe(recipe: Dictionary, views: Array, restrictions: Array) -> Dictionary:
	# UNVERIFIED: join the existing projected qualification to its original
	# ItemCraftView/ItemCraftRestriction rows. No new clock or server eligibility.
	if views.is_empty(): return {"ok":false,"reason":"원본 제작 자격 행이 없습니다 · 재료 보존"}
	var condition: Dictionary = recipe.get("craft_conditions",{})
	if not condition.is_empty() and not valid(condition): return {"ok":false,"reason":"제작 자격 구조를 확인하세요 · 재료 보존"}
	var fields: Array[String] = ["ServerLimitSetID","IsCoalitionItem","NoRepeat","IsBelowLevelLimit","LevelLimitValue","CraftTimeTypeID","EffectiveFrom","EffectiveTo","PopupText","AlwaysSuccess"]
	var first: Dictionary = views[0]
	for view: Variant in views:
		if not view is Dictionary: return {"ok":false,"reason":"원본 제작 자격 형식이 다릅니다"}
		for key: String in fields:
			if not view.has(key) or view[key] != first.get(key): return {"ok":false,"reason":"제작 결과별 원본 자격이 다릅니다 · 재료 보존"}
	if first.get("ServerLimitSetID") != 0 or first.get("IsCoalitionItem") != false or first.get("NoRepeat") != false or first.get("IsBelowLevelLimit") != false or first.get("CraftTimeTypeID") != 1 or not integer(first.get("LevelLimitValue"),0,1000):
		return {"ok":false,"reason":"원본 제작의 별도 서버·자격 소유자 확인이 필요합니다 · 재료 보존"}
	if int(condition.get("min_level",0)) != int(first.LevelLimitValue) or int(condition.get("max_level",0)) != 0 or int(recipe.get("popup_text_id",-1)) != int(first.PopupText):
		return {"ok":false,"reason":"제작 레벨·재료 손실 안내의 원본 관계가 다릅니다 · 재료 보존"}
	var permanent: bool = first.get("EffectiveFrom") == 1 and first.get("EffectiveTo") == 3
	if permanent and condition.has("active_window"): return {"ok":false,"reason":"제작 원본 기간 관계가 다릅니다 · 재료 보존"}
	if not permanent:
		var window: Dictionary = condition.get("active_window",{})
		if window.is_empty() or window.get("source_start",{}).get("ID") != first.get("EffectiveFrom") or window.get("source_end",{}).get("ID") != first.get("EffectiveTo"):
			return {"ok":false,"reason":"제작 기간의 원본 DateTimes 참조가 필요합니다 · 재료 보존"}
	if restrictions.is_empty():
		return {"ok":not condition.has("quota"),"reason":"제작 횟수 제한의 원본 관계가 다릅니다 · 재료 보존" if condition.has("quota") else ""}
	if restrictions.size() != 1 or not condition.has("quota") or condition.quota.get("source_restriction") != restrictions[0]:
		return {"ok":false,"reason":"제작 횟수 제한의 원본 행 관계가 다릅니다 · 재료 보존"}
	return {"ok":true}

static func stage(recipe: Dictionary, count: int, context: Dictionary) -> Dictionary:
	if not recipe.has("craft_conditions"): return {"ok":true}
	var condition: Variant=recipe.craft_conditions
	if not valid(condition): return {"ok":false,"reason":"원본 제작 자격 구조를 확인하세요"}
	if condition.has("active_window"):
		if not integer(context.get("now"),0,4102444800):return {"ok":false,"reason":"원본 제작 기간 시각 확인 필요 · 재료 보존"}
		if int(context.now)<int(condition.active_window.start_unix) or int(context.now)>=int(condition.active_window.end_unix):return {"ok":false,"reason":"원본 제작 기간 밖 · "+window_text(condition.active_window)}
	if int(context.get("level",0))<int(condition.min_level): return {"ok":false,"reason":"원본 제작 조건 · 레벨 %d 이상 필요" % int(condition.min_level)}
	if int(condition.max_level)>0 and int(context.get("level",0))>int(condition.max_level): return {"ok":false,"reason":"원본 제작 조건 · 레벨 %d 이하 필요" % int(condition.max_level)}
	if not condition.has("quota"): return {"ok":true}
	if not context.has("usage") or not valid_usage(context.usage) or not integer(context.get("now"),0,4102444800): return {"ok":false,"reason":"제작 제한 저장·시각 확인 필요 · 재료 보존"}
	var quota: Dictionary=condition.quota
	var ledger: Dictionary=context.usage.duplicate(true)
	if ledger.is_empty(): ledger={"schema":1,"recipes":{}}
	var bounded: bool=quota.get("mode")=="bounded_lifetime"
	var bucket: int=0 if bounded else int(floor(float(int(context.now)-int(quota.anchor_unix))/float(quota.period_seconds)))
	var schedule: String="bounded_lifetime:13:111:false" if bounded else "%d:%d" % [int(quota.period_seconds),int(quota.anchor_unix)]
	var previous: Dictionary=ledger.recipes.get(recipe.id,{})
	if not previous.is_empty() and (previous.schedule!=schedule or bucket<int(previous.bucket)): return {"ok":false,"reason":"제작 제한 시각·일정 변경 확인 필요 · 이전 횟수 보존"}
	var used: int=int(previous.get("used",0)) if int(previous.get("bucket",bucket))==bucket else 0
	if count<1 or used+count>int(quota.limit): return {"ok":false,"reason":("원본 횟수 제한/TWILIGHT 평생 한도 · %d/%d회" if bounded else "원본 주간 제작 제한 · 이번 주 %d/%d회") % [used,int(quota.limit)],"quota_used":used,"quota_limit":int(quota.limit)}
	ledger.recipes[recipe.id]={"bucket":bucket,"used":used+count,"schedule":schedule}
	return {"ok":true,"usage_after":ledger,"quota_used":used,"quota_limit":int(quota.limit)}

static func brief(recipe: Dictionary, context: Dictionary) -> String:
	if not recipe.has("craft_conditions"): return ""
	var condition: Variant=recipe.craft_conditions
	if not valid(condition): return "원본 제작 자격 미확인"
	if condition.has("quota"):
		var quote: Dictionary=stage(recipe,1,context)
		if condition.quota.get("mode")=="bounded_lifetime":return "원본 횟수 %d회 · 주기 미해석/TWILIGHT 실패 포함 평생 한도" % int(condition.quota.limit)
		var clock: Dictionary=Time.get_datetime_dict_from_unix_time(int(condition.quota.anchor_unix)+32400)
		var used: String=str(int(quote.quota_used)) if quote.has("quota_used") else "?"
		return "원본 주간 제한 %s/%d회 · 초기화 %s %02d:%02d KST (게임 설정)" % [used,int(condition.quota.limit),["일","월","화","수","목","금","토"][int(clock.weekday)],int(clock.hour),int(clock.minute)]
	if condition.has("active_window"):return window_text(condition.active_window)
	return "원본 제작 조건 · 레벨 %d 이상" % int(condition.min_level) if int(condition.min_level)>0 else ""

static func summary(recipe: Dictionary, context: Dictionary) -> String:
	if not recipe.has("craft_conditions"): return ""
	var condition: Variant=recipe.craft_conditions
	if not valid(condition): return "원본 제작 자격 미확인"
	var lines: PackedStringArray=[]
	if condition.has("active_window"):
		lines.append(window_text(condition.active_window))
		lines.append(str(condition.active_window.clock_origin))
	if int(condition.min_level)>0: lines.append("원본 제작 조건 · 레벨 %d 이상" % int(condition.min_level))
	if int(condition.max_level)>0: lines.append("원본 제작 조건 · 레벨 %d 이하" % int(condition.max_level))
	if condition.has("quota"):
		lines.append(str(condition.get("origin","원본 제작 횟수 제한")))
		var quote: Dictionary=stage(recipe,1,context)
		lines.append((("평생 한도 %d/%d회(TWILIGHT 설정)" if condition.quota.get("mode")=="bounded_lifetime" else "이번 주 %d/%d회") % [int(quote.quota_used),int(quote.quota_limit)]) if quote.get("ok",false) else str(quote.get("reason","횟수 확인 필요")))
		lines.append(str(condition.quota.clock_origin))
	return "\n".join(lines)
