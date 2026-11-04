extends RefCounted
## Real single-slot checkpoints and a persistent high-water game day.
const Day = preload("res://scripts/quests/quest_service.gd")
static var policy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/symbol_history_policy.json"))
var owner_ref: WeakRef
var runtime:
	get: return owner_ref.get_ref()
var test_now: Callable # Test-local clock input; never changes the game's clock.

func configure(owner) -> void:
	owner_ref = weakref(owner)

func today() -> int:
	return Day.korean_daily_key(int(test_now.call()) if test_now.is_valid() else int(Time.get_unix_time_from_system()))

func policy_error() -> String:
	if not policy.get("history_enabled") is bool or not policy.get("restore_uses_reset_quota") is bool: return "문양 자체 정책 설정 오류"
	for key: String in ["save_fee_points","restore_fee_points","daily_reset_limit_per_emblem"]:
		if not runtime.integer(policy.get(key)): return "문양 자체 정책 수치 오류"
	return ""

static func fingerprint(value: Dictionary) -> String:
	# JSON round-trip numbers before comparison, so reload's int/float decoding
	# cannot mint another ticket for the identical recorded progression.
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)),"",true,true)

func validate(state: Dictionary) -> String:
	var history: Variant = state.get("symbol_history",{})
	if not history is Dictionary: return "문양 강화 보관 형식 오류"
	if not history.is_empty():
		if not runtime.integer(history.get("sequence")) or not history.get("records") is Dictionary: return "문양 강화 보관 구조 오류"
		var tickets: Array = []
		for id: Variant in history.records:
			var row: Variant = history.records[id]
			if not id is String or runtime.emblem(id).is_empty() or not row is Dictionary: return "문양 강화 보관 대상 오류"
			if not runtime.integer(row.get("ticket"),1,int(history.sequence)) or tickets.has(int(row.ticket)): return "문양 복구권 식별 오류"
			tickets.append(int(row.ticket))
			if not runtime.integer(row.get("revision"),0,int(state.revision)) or not row.get("used") is bool: return "문양 복구권 이력 오류"
			if not runtime.progress_error(id,row.get("progress")).is_empty(): return "문양 보관 진행 오류"
			if int(row.progress.stage)<=0 or int(row.progress.stage)>=30 or int(row.progress.attempts)<=0: return "보관 가능한 실제 문양 강화 기록 없음"
	var daily: Variant = state.get("symbol_daily",{})
	if not daily is Dictionary: return "문양 일일 이력 형식 오류"
	if not daily.is_empty():
		if not runtime.integer(daily.get("day")) or not daily.get("counts") is Dictionary: return "문양 일일 이력 구조 오류"
		for id: Variant in daily.counts:
			if not id is String or runtime.emblem(id).is_empty() or not runtime.integer(daily.counts[id]): return "문양 일일 횟수 오류"
	return ""

func daily_offer(id: String, consume: bool = true) -> Dictionary:
	var invalid: String=policy_error()
	if not invalid.is_empty():return runtime.fail(invalid)
	var day: int = today()
	var saved: Dictionary = runtime.state.get("symbol_daily",{})
	if day<0 or day<int(saved.get("day",day)): return runtime.fail("게임 일자가 이전 기록보다 과거입니다 · 기록 보존, 날짜 확인 후 재시도")
	var used: int = int(saved.get("counts",{}).get(id,0)) if day==int(saved.get("day",day)) else 0
	var limit: int = int(policy.daily_reset_limit_per_emblem)
	if consume and limit>0 and used>=limit: return runtime.fail("일일 문양 초기화 횟수 초과 · 자체 한도 문양별 %d회" % limit)
	return {"ok":true,"day":day,"used":used,"limit":limit}

func record(id: String) -> Dictionary:
	return runtime.state.get("symbol_history",{}).get("records",{}).get(id,{}).duplicate(true)

func status(id: String) -> String:
	var d: Dictionary = daily_offer(id,false)
	var daily: String = "%d/%s" % [int(d.used),str(d.limit) if int(d.limit)>0 else "무제한"] if d.ok else str(d.message)
	var saved: Dictionary = record(id)
	var checkpoint: String = "보관 기록 없음" if saved.is_empty() else "%d단계/%d회 · %d포인트 · 복구권#%d %s" % [int(saved.progress.stage),int(saved.progress.attempts),int(saved.progress.spent),int(saved.ticket),"사용 완료" if saved.used else "사용 가능"]
	return "자체 일일 정책 · 기존 게임05시 기준 · 문양별 초기화 %s\n강화 기록 보관: %s" % [daily,checkpoint]

func quote(action: String, id: String) -> Dictionary:
	if runtime.development or not bool(policy.history_enabled): return runtime.fail("현재 프로필의 문양 기록 보관/복구는 꺼져 있습니다")
	if runtime.emblem(id).is_empty(): return runtime.fail("알 수 없는 문양")
	var current: Dictionary = runtime.progress(id)
	if int(current.stage)>=30: return runtime.fail("완성한30단계 문양은 강화 정보 저장/복구 불가")
	var consume: bool = action=="restore_emblem" and bool(policy.restore_uses_reset_quota)
	var d: Dictionary = daily_offer(id,consume)
	if not d.ok: return d
	var saved: Dictionary = record(id)
	var points: int = 0
	var message: String = ""
	if action=="save_emblem":
		if int(current.attempts)<=0: return runtime.fail("보관할 실제 문양 강화 기록이 없습니다")
		if not saved.is_empty() and fingerprint(saved.progress)==fingerprint(current): return runtime.fail("동일한 강화 기록이 이미 보관되어 있습니다 · 재사용권을 생성하지 않습니다")
		points=int(policy.save_fee_points)
		message="현재 %d단계/%d회 실제 기록 %s · 자체 보관료 %d 축복 포인트\n보관 슬롯1개, 복구권1회. 포인트·아이템 잔고를 복사하지 않습니다." % [int(current.stage),int(current.attempts),"덮어쓰기" if not saved.is_empty() else "보관",points]
	else:
		if saved.is_empty() or bool(saved.used): return runtime.fail("사용 가능한 실제 강화 복구 기록이 없습니다")
		if fingerprint(saved.progress)==fingerprint(current): return runtime.fail("현재 강화 정보가 보관 기록과 같습니다")
		points=maxi(0,int(saved.progress.spent)+int(policy.restore_fee_points)-int(current.spent))
		message="보관된 %d단계/%d회로 복구 · 복구권#%d 1회 소비\n현재 강화 %d포인트 반환 → 보관 강화 %d포인트 재지출 + 자체 수수료 %d포인트\n추가 필요 %d 축복 포인트 · %s\n지갑·아이템·다른 문양은 현재 상태를 유지합니다." % [int(saved.progress.stage),int(saved.progress.attempts),int(saved.ticket),int(current.spent),int(saved.progress.spent),int(policy.restore_fee_points),points,"문양별 일일 초기화1회 사용" if consume else "일일 횟수 별도"]
	return {"ok":true,"message":message,"points":points,"costs":{},"revision":runtime.state.revision,"consume_instance":"","day":d.day}

func stage_day(next: Dictionary, id: String, day: int, consume: bool) -> void:
	var d: Dictionary = next.get("symbol_daily",{})
	if d.is_empty() or day>int(d.day): d={"day":day,"counts":{}}
	if consume:d.counts[id]=int(d.counts.get(id,0))+1
	next.symbol_daily=d

func stage(next: Dictionary, action: String, id: String, offer: Dictionary) -> String:
	var history: Dictionary = next.get("symbol_history",{"sequence":0,"records":{}})
	if history.is_empty():history={"sequence":0,"records":{}}
	if action=="save_emblem":
		history.sequence+=1
		history.records[id]={"ticket":history.sequence,"revision":int(next.revision)+1,"progress":runtime.progress(id),"used":false}
		next.points-=int(offer.points);runtime._ledger(next,"history_save_fees",int(offer.points))
	else:
		var row: Dictionary=history.records[id]
		var returned: int=int(runtime.progress(id).spent)
		var principal: int=int(row.progress.spent)
		next.points+=returned-principal-int(policy.restore_fee_points)
		runtime._ledger(next,"history_current_refunded",returned)
		runtime._ledger(next,"history_principal_spent",principal)
		runtime._ledger(next,"history_restore_fees",int(policy.restore_fee_points))
		next.emblems[id]=row.progress.duplicate(true);row.used=true
	next.symbol_history=history
	stage_day(next,id,int(offer.day),action=="restore_emblem" and bool(policy.restore_uses_reset_quota))
	return "실제 문양 강화 기록 보관 완료" if action=="save_emblem" else "보관된 실제 강화 기록 복구 완료 · 복구권 사용 완료"
