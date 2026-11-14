extends RefCounted
## Offline transactions. Source policies remain separate from local adapters.
const Source = preload("res://scripts/tj/source523.gd")
const KEY = "tj_coupons523"
const DECK = {"변신":1, "마법인형":2, "성물":98, "스킬":41}
var definitions: Dictionary = {}
var state: Dictionary = empty_state()
var blocked := false
var problem := ""
var busy := false
# These are explicitly TWILIGHT settings, not recovered native enums/timezones.
var settings := {"utc_offset_minutes":540, "owner_scope":{"1":"account", "2":"character"}, "account":"offline-account", "character":"offline-character", "legacy_time_mode":"blocked", "retry_gold_cost":0, "allow_no_season":false, "allow_unknown_expiry":false}
static func empty_state() -> Dictionary:
	return {"version":1, "revision":0, "coupons":{}, "history":[], "used":{}, "receipts":[], "last_time":0}
func validate(value: Variant) -> String:
	if not value is Dictionary: return "TJ 저장 형식 오류"
	if int(value.get("version",0)) != 1 or not value.get("revision") is float and not value.get("revision") is int: return "TJ 저장 버전 오류"
	for key: String in ["coupons", "used"]:
		if not value.get(key) is Dictionary: return "TJ 저장 사전 오류"
	for key: String in ["history", "receipts"]:
		if not value.get(key) is Array or value[key].size()>10000: return "TJ 저장 기록 오류"
	if int(value.revision)<0 or int(value.get("last_time",-1))<0: return "TJ 저장 값 오류"
	for id: Variant in value.coupons:
		var n: Variant=value.coupons[id]
		if not str(id).is_valid_int() or not (n is int or n is float) or float(n)!=int(n) or int(n)<0 or int(n)>10000: return "TJ 쿠폰 수량 오류"
	for receipt: Variant in value.receipts:
		if not receipt is Dictionary:return "TJ 거래 영수증 형식 오류"
	var ids: Dictionary={}
	for event: Variant in value.history:
		if not event is Dictionary: return "TJ 실패 기록 오류"
		for key: String in ["id","history_type","deck","grade","time","account","character","context","success_candidates","fail_candidates"]:
			if not event.has(key):return "TJ 실패 기록 필드 오류"
		if str(event.id).is_empty() or ids.has(str(event.id)) or not event.context is Dictionary or not event.success_candidates is Array or not event.fail_candidates is Array:return "TJ 중복 또는 손상 기록"
		for key: String in ["history_type","deck","grade","time"]:
			var number: Variant=event[key]
			if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=int(number) or int(number)<0:return "TJ 실패 기록 수치 오류"
		for key: String in ["id","account","character"]:
			if not event[key] is String or str(event[key]).is_empty() or str(event[key]).length()>256:return "TJ 실패 기록 소유자 오류"
		for key: String in ["success_candidates","fail_candidates"]:
			if event[key].size()>10000:return "TJ 후보 한도 오류"
			var unique: Dictionary={}
			for id: Variant in event[key]:
				if not id is String or not str(id).is_valid_int() or int(id)<=0 or unique.has(id):return "TJ 후보 식별자 오류"
				unique[id]=true
		ids[str(event.id)]=true
	for id: Variant in value.used:
		if not ids.has(str(id)) or str(value.used[id]).is_empty():return "TJ 사용 기록 오류"
	return ""
func import_state(value: Variant) -> bool:
	var error: String=validate(value)
	if not error.is_empty():blocked=true;problem=error;return false
	state=value.duplicate(true)
	for key: String in ["version","revision","last_time"]:state[key]=int(state[key])
	for id: String in state.coupons:state.coupons[id]=int(state.coupons[id])
	if state.has("server_context"):state.server_context.world_no=int(state.server_context.world_no)
	for event: Dictionary in state.history:
		for key: String in ["history_type","deck","grade","time"]:event[key]=int(event[key])
		if event.context.has("world_no"):event.context.world_no=int(event.context.world_no)
	for receipt: Dictionary in state.receipts:
		for key: String in ["revision","time"]:
			if receipt.has(key):receipt[key]=int(receipt[key])
	blocked=false;problem="";return true
func export_state() -> Dictionary: return state.duplicate(true)
func clock() -> int: return int(Time.get_unix_time_from_system())
func wall(epoch: int) -> int:
	var d: Dictionary=Time.get_datetime_dict_from_unix_time(epoch+int(settings.utc_offset_minutes)*60)
	return int(d.year)*100000000+int(d.month)*1000000+int(d.day)*10000+int(d.hour)*100+int(d.minute)
func date_value(id: int) -> int:
	var d: Dictionary=definitions.get("dates",{}).get(str(id),{})
	return int(d.get("Year",0))*100000000+int(d.get("Month",0))*1000000+int(d.get("Day",0))*10000+int(d.get("Hour",0))*100+int(d.get("Minute",0))
func server_matches(id: int, context: Dictionary) -> bool:
	if context.is_empty():return false
	if id==0:return true
	for row: Dictionary in definitions.get("servers",[]):
		if int(row.ServerLimitSetID)==id and str(row.ServiceRegionCode)==str(context.get("service_region_code","")) and int(row.WorldNo)==int(context.get("world_no",-1)):return true
	return false
func resolve(item: String, context: Dictionary, now: int) -> Dictionary:
	if blocked:return {"ok":false,"error":problem}
	if definitions.is_empty():return {"ok":false,"error":"최신 523 원본 ZIP을 먼저 설치하세요"}
	if now<int(state.last_time):return {"ok":false,"error":"이전 거래보다 시간이 앞섭니다. 시계를 바꾸지 말고 확인하세요"}
	var coupon: Dictionary=definitions.coupons.get(item,{})
	if coupon.is_empty():return {"ok":false,"error":"카드 재도전 쿠폰이 아닙니다. 장비 복구는 별도 어댑터가 필요합니다"}
	if bool(coupon.item.get("TestItem",false)) and not preload("res://scripts/boot/build_flags.gd").playtest():return {"ok":false,"error":"원본 테스트 아이템은 일반 실행에서 사용할 수 없습니다"}
	var policy: Dictionary=coupon.profile
	var history: Dictionary={}
	for row: Dictionary in definitions.histories:
		if int(row.HistoryType)==int(policy.TJCouponHistoryType):history=row
	if history.is_empty() or int(history.OwnerType)!=int(policy.OwnerTypeID):return {"ok":false,"error":"원본 이력 종류 또는 소유 범위가 일치하지 않습니다"}
	var mapped := false
	for row: Dictionary in definitions.mappings:
		if int(row.HistoryType)==int(history.HistoryType) and int(row.UnitID)==31 and int(row.Value)==int(policy.BuffCardDeckID):mapped=true
	if not mapped:return {"ok":false,"error":"덱 이력 매핑을 확인할 수 없습니다"}
	var season: int=-1
	var expiry: int=-1
	for effect: Dictionary in coupon.effects:
		if int(effect.BonusTypeID) not in [6604,11551,492,125]:return {"ok":false,"error":"지원 여부를 확인하지 못한 쿠폰 효과입니다"}
		if int(effect.BonusTypeID)==125 and int(effect.Value)!=int(policy.BuffCardDeckID):return {"ok":false,"error":"추가 덱 효과가 재도전 정책과 일치하지 않습니다"}
		if int(effect.BonusTypeID)==11551:season=int(effect.Value)
		if int(effect.BonusTypeID)==492:
			if int(effect.Value)==0 and int(effect.BonusApplicationTypeID)==298:expiry=date_value(int(effect.BonusApplicationTargetID))
			elif str(settings.legacy_time_mode)=="calendar_yyyymmddhh" and int(effect.Value)>0 and int(effect.BonusApplicationTypeID)==0 and int(effect.BonusApplicationTargetID)==0:
				var raw: String=str(int(effect.Value))
				if raw.length()!=10:return {"ok":false,"error":"설정한 구형 날짜 형식과 맞지 않습니다"}
				expiry=int(raw)*100
			else:return {"ok":false,"error":"구형 소멸 시간 인코딩의 실행 해석이 확인되지 않았습니다"}
	if expiry<0 and not bool(settings.allow_unknown_expiry):return {"ok":false,"error":"소멸 조건이 없는 쿠폰의 실행 정책은 확인 대기입니다"}
	if expiry>=0 and (expiry==0 or wall(now)>=expiry):return {"ok":false,"error":"쿠폰 소멸일이 지났거나 날짜가 손상됐습니다"}
	var window: Dictionary={}
	if season<0:
		if not bool(settings.allow_no_season):return {"ok":false,"error":"시즌 없는 쿠폰의 이력 기간은 확인 대기입니다"}
	else:
		for row: Dictionary in definitions.seasons:
			if int(row.HistoryType)==int(history.HistoryType) and int(row.Season)==season and server_matches(int(row.ServerLimitSetID),context):
				if not window.is_empty():return {"ok":false,"error":"서버와 시즌에 둘 이상의 기간이 연결됩니다"}
				window=row
		if window.is_empty():return {"ok":false,"error":"현재 지역과 월드에 맞는 시즌이 없습니다"}
	return {"ok":true,"coupon":coupon,"policy":policy,"history":history,"window":window,"season":season}
func candidates(item: String, context: Dictionary, now: int) -> Dictionary:
	var result: Dictionary=resolve(item,context,now)
	if not result.ok:return result
	var found: Array=[]
	for event: Dictionary in state.history:
		if state.used.has(str(event.id)) or int(event.history_type)!=int(result.history.HistoryType) or int(event.deck)!=int(result.policy.BuffCardDeckID):continue
		if int(event.grade)<int(result.history.MinGrade):continue
		if str(event.account)!=str(settings.account):continue
		var scope: String=str(settings.owner_scope.get(str(int(result.policy.OwnerTypeID)),""))
		if scope.is_empty() or scope=="character" and str(event.character)!=str(settings.character):continue
		if event.context!=context:continue
		if not result.window.is_empty():
			var t: int=wall(int(event.time))
			if t<date_value(int(result.window.StartDateTimeID)) or t>=date_value(int(result.window.EndDateTimeID)):continue
		if event.success_candidates.is_empty() or event.fail_candidates.is_empty():continue
		found.append(event.duplicate(true))
	result["events"]=found
	if found.is_empty():result["error"]="이 쿠폰에 해당하는 실제 실패 이력이 없습니다"
	return result
## bag_units: physical original coupons of this ItemClass in the bag (user
## decision 2026-11-13). This record's own coupons are spent first; when it has
## none, the result says `bag_debit` and the caller debits one bag unit in the
## same save. Exactly one unit of one source is spent per use.
func prepare(item: String, event_id: String, context: Dictionary, now: int, revision: int, success_ids: Array, fail_ids: Array, bag_units: int = 0) -> Dictionary:
	if busy or blocked or revision!=int(state.revision):return {"ok":false,"error":"이미 처리했거나 선택 후 상태가 바뀌었습니다"}
	var own: int=int(state.coupons.get(item,0))
	if own<1 and bag_units<1:return {"ok":false,"error":"소유한 쿠폰이 부족합니다"}
	var view: Dictionary=candidates(item,context,now)
	if not view.ok:return view
	var event: Dictionary={}
	for row: Dictionary in view.events:
		if str(row.id)==event_id:event=row
	if event.is_empty():return {"ok":false,"error":"사용 가능한 실패 이력이 아닙니다"}
	# Unknown native output/awakening/skill rules are not guessed from the catalog.
	if str(event.get("adapter","")) not in ["fusion","awakening"]:return {"ok":false,"error":"이 이력의 실제 실행 어댑터 연결이 필요합니다. 쿠폰은 유지됩니다"}
	var count: int=int(view.policy.ChoiceFailCardCount)
	var expected_fail: int=count if count>0 else 1
	if success_ids.size()!=1 or fail_ids.size()!=expected_fail:return {"ok":false,"error":"성공 후보 한 개와 원본 정책 수의 실패 후보를 선택하세요"}
	for pair: Array in [[success_ids,event.success_candidates],[fail_ids,event.fail_candidates]]:
		var unique: Dictionary={}
		for id: Variant in pair[0]:
			if unique.has(str(id)) or not pair[1].has(str(id)):return {"ok":false,"error":"기록에 없거나 중복된 후보입니다"}
			var card: Dictionary=definitions.cards.get(str(id),{})
			if card.is_empty() or int(card.BuffCardDeckID)!=int(view.policy.BuffCardDeckID) or int(card.GradeID)<int(view.policy.BuffCardMinGrade):return {"ok":false,"error":"쿠폰의 덱 또는 최소 등급과 맞지 않습니다"}
			if not server_matches(int(card.get("ServerLimitSetID",0)),context):return {"ok":false,"error":"선택 카드의 서버 조건이 맞지 않습니다"}
			var start: int=int(card.get("StartDateTimeID",0))
			var end: int=int(card.get("EndDateTimeID",0))
			if start!=0 and (date_value(start)==0 or wall(now)<date_value(start)):return {"ok":false,"error":"선택 카드의 시작 기간 조건이 맞지 않습니다"}
			if end!=0 and (date_value(end)==0 or wall(now)>=date_value(end)):return {"ok":false,"error":"선택 카드의 종료 기간 조건이 맞지 않습니다"}
			unique[str(id)]=true
	var next: Dictionary=export_state()
	next.revision=int(next.revision)+1;next.last_time=now
	if own>=1:next.coupons[item]=own-1
	next.used[event_id]=str(next.revision)
	return {"ok":true,"state":next,"event":event,"success_ids":success_ids.duplicate(),"fail_ids":fail_ids.duplicate(),"item":item,"bag_debit":own<1}
func record_failure(event: Dictionary) -> bool:
	if blocked or state.history.size()>=10000:return false
	var next: Dictionary=export_state()
	var copy: Dictionary=event.duplicate(true)
	copy["id"]="failure-"+str(int(next.revision)+1)
	copy["account"]=str(settings.account);copy["character"]=str(settings.character)
	next.history.append(copy);next.revision=int(next.revision)+1
	if not validate(next).is_empty():return false
	state=next
	return true
