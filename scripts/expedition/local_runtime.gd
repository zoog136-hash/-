extends RefCounted

## Bounded local execution, not a claim about the original server protocol.
## Source conditions/cost/time run; event RNG and outcome settlement stay pending.
const KEY = "expedition523_local"
const SOURCE = preload("res://scripts/expedition/source_catalog.gd")
const MAX_INTEGER = 9007199254740000
var world: Node
var state: Dictionary = fresh()
var namespace_present: bool = false
var save_blocked: bool = false
var fraction: float = 0.0
var busy: bool = false

static func fresh() -> Dictionary:
	return {"version": 1, "source_sha256": SOURCE.SOURCE_SHA256, "revision": 0, "jobs": [], "attempts": {}}

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func validate(value: Variant) -> String:
	if not value is Dictionary or not integer(value.get("version")) or value.get("version") != 1 or value.get("source_sha256") != SOURCE.SOURCE_SHA256:
		return "탐험 저장 형식·원본 버전 오류"
	if not integer(value.get("revision")) or value.revision < 0 or value.revision >= MAX_INTEGER or not value.get("jobs") is Array or not value.get("attempts") is Dictionary:
		return "탐험 저장 진행 형식 오류"
	if value.jobs.size() > 15:
		return "탐험 동시 기록 범위 오류"
	var seen := {}
	var cards := {}
	var spots := {}
	var counts := {}
	for job in value.jobs:
		if not job is Dictionary:
			return "탐험 기록 형식 오류"
		for field in ["id", "spot_id", "group_id", "deck_id", "cost", "duration", "remaining", "completion_reward_id"]:
			if not integer(job.get(field)) or job[field] < 0 or job[field] >= MAX_INTEGER:
				return "탐험 기록 정수 오류"
		if job.id < 1 or job.id > value.revision or job.spot_id < 1 or job.group_id < 1 or int(job.duration) != 28800 or job.remaining > job.duration or int(job.deck_id) not in [2, 98] or job.cost < 1 or job.completion_reward_id < 1:
			return "탐험 기록 범위 오류"
		if not job.get("identity") is String or not job.identity.begins_with("source:m508:%d:" % int(job.deck_id)) or job.get("status") not in ["running", "awaiting_outcome"]:
			return "탐험 카드·상태 오류"
		var parts: PackedStringArray = job.identity.split(":")
		if parts.size() != 4 or not parts[3].is_valid_int() or int(parts[3]) < 1 or str(int(parts[3])) != parts[3]:
			return "탐험 카드 ID 정규형 오류"
		if (job.status == "awaiting_outcome") != (job.remaining == 0):
			return "탐험 시간·상태 불일치"
		if seen.has(job.id) or cards.has(job.identity) or spots.has(job.spot_id):
			return "탐험 기록 중복"
		seen[job.id] = true
		cards[job.identity] = true
		spots[job.spot_id] = true
		var deck := str(int(job.deck_id))
		counts[deck] = int(counts.get(deck, 0)) + 1
	for deck in value.attempts:
		if deck not in ["2", "98"] or not integer(value.attempts[deck]) or value.attempts[deck] < int(counts.get(deck, 0)) or value.attempts[deck] > 15:
			return "탐험 횟수 기록 오류"
	for deck in counts:
		if int(counts[deck]) > 5 or not value.attempts.has(deck):
			return "탐험 동시·횟수 기록 오류"
	return ""

func check_load(data: Dictionary) -> String:
	return validate(data[KEY]) if data.has(KEY) else ""

func restore(data: Dictionary) -> void:
	namespace_present = data.has(KEY)
	state = data.get(KEY, fresh()).duplicate(true)
	save_blocked = false
	busy = false
	fraction = 0.0

func export_state() -> Dictionary:
	return state.duplicate(true)

func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _constant(catalog: RefCounted, name: String) -> int:
	for row: Dictionary in catalog.rows("ConstantData"):
		if row.Name == name:
			return int(row.Value)
	return 0

func prepare(spot_id: int, identities: Array) -> Dictionary:
	if world == null or busy or save_blocked or not validate(state).is_empty():
		return _fail("탐험 저장 보호 또는 거래 처리 중")
	if not world.pending_map_save_record.is_empty():
		return _fail("진행 중인 저장 이전을 먼저 완료한 뒤 출발하세요")
	var catalog: RefCounted = world.get_expedition_catalog()
	if not catalog.ready():
		return _fail(catalog.error)
	var inspection: Dictionary = world.inspect_expedition(spot_id, identities)
	if not inspection.get("static_conditions_met", false):
		return _fail("원본 카드 수·소유·계열·등급·스킬각성 조건 미충족")
	var spot: Dictionary = inspection.spot
	if int(spot.CardCount) != 1 or int(spot.BuffCardDeckID) not in [2, 98] or identities.size() != 1:
		return _fail("변신4장의 대표 보상 그룹·시너지 판정은 미확정")
	var card: Dictionary = catalog.record("BuffCard", int(inspection.cards[0].source_id))
	if int(spot.ServerLimitsetID) != 0 or int(card.ServerLimitSetID) != 0 or int(card.StartDateTimeID) != 0 or int(card.EndDateTimeID) != 0:
		return _fail("해당 장소·카드의 서버·기간 조건 확인 필요")
	if int(spot.ExpeditionCostCurrencyID) != 1 or int(spot.ExpeditionCost) < 1 or int(spot.TimeLimitSecond) != 28800:
		return _fail("실행 가능한 원본 비용·시간 연결 없음")
	if inspection.completion.size() != 1 or int(inspection.completion[0].reward.get("RewardTypeID", 0)) != 2:
		return _fail("완주 보상의 명시적 연결 없음")
	var deck := str(int(spot.BuffCardDeckID))
	var prefix := "MagicDoll" if int(spot.BuffCardDeckID) == 2 else "HolyStuff"
	var concurrent := _constant(catalog, prefix+"ExpeditionMaxCount")
	var limit := _constant(catalog, prefix+"ExpeditionDailyLimit")
	if concurrent != 5 or limit != 15:
		return _fail("원본 동시·횟수 상수 연결 없음")
	var count := 0
	for job: Dictionary in state.jobs:
		if job.identity == identities[0] or int(job.spot_id) == spot_id:
			return _fail("이미 탐험 기록에 사용 중인 카드 또는 장소")
		if str(int(job.deck_id)) == deck: count += 1
	if count >= concurrent:
		return _fail("해당 계열 동시5곳 한도 · 정산 대기 포함")
	# No timezone/reset policy is fabricated. Retain the source15 ceiling across
	# saved attempts until an explicit reset contract exists.
	if int(state.attempts.get(deck, 0)) >= limit:
		return _fail("15회 기록 상한 · 일일 초기화 시간대 판정 미연결")
	if int(world.gold) < int(spot.ExpeditionCost):
		return _fail("아데나 부족")
	return {"ok": true, "inspection": inspection, "cost": int(spot.ExpeditionCost), "identity": str(identities[0]), "deck": deck}

func _backup_before_first_start() -> bool:
	if namespace_present:
		return true
	var path: String = world.save_path()
	if not FileAccess.file_exists(path):
		return true
	var sha := FileAccess.get_sha256(path)
	var backup := path+".pre-expedition523-"+sha
	if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path, backup) != OK:
		return false
	return FileAccess.get_sha256(backup) == sha

func start(spot_id: int, identities: Array) -> Dictionary:
	var prepared := prepare(spot_id, identities)
	if not prepared.ok:
		return prepared
	if not _backup_before_first_start():
		return _fail("출발 전 기존 저장 원본 백업 실패")
	busy = true
	var staged := state.duplicate(true)
	staged.revision = int(staged.revision)+1
	var inspection: Dictionary = prepared.inspection
	staged.jobs.append({"id": int(staged.revision), "spot_id": spot_id, "group_id": int(inspection.group_id), "deck_id": int(inspection.spot.BuffCardDeckID), "cost": int(prepared.cost), "identity": prepared.identity, "duration": int(inspection.spot.TimeLimitSecond), "remaining": int(inspection.spot.TimeLimitSecond), "status": "running", "completion_reward_id": int(inspection.completion[0].reward.ID)})
	staged.attempts[prepared.deck] = int(staged.attempts.get(prepared.deck, 0))+1
	var error: Error = world._save_game(true, {KEY: staged, "gold": int(world.gold)-int(prepared.cost)})
	if error != OK:
		busy = false
		return _fail("저장 실패 · 아데나·탐험·횟수 보존")
	state = staged
	namespace_present = true
	world.gold -= int(prepared.cost)
	busy = false
	world.call_deferred("_update_hud")
	return {"ok": true, "cost": int(prepared.cost), "status": "running", "message": "출발 저장 완료 · 접속 중 시간 진행 · 종료 후 성공·보상 정산 대기"}

func tick(delta: float) -> void:
	if state.jobs.is_empty() or save_blocked or busy or world == null or not world.get_expedition_catalog().ready():
		return
	fraction += delta
	var seconds := floori(fraction)
	if seconds < 1: return
	fraction -= seconds
	advance(seconds)

func advance(seconds: int) -> void:
	if seconds <= 0 or save_blocked or world == null or not world.get_expedition_catalog().ready():
		return
	var changed := false
	for job: Dictionary in state.jobs:
		if job.status != "running": continue
		job.remaining = maxi(0, int(job.remaining)-seconds)
		if job.remaining == 0: job.status = "awaiting_outcome"
		changed = true
	if changed:
		state.revision = int(state.revision)+1
		world._request_deferred_save()

func jobs_view() -> Array:
	return state.jobs.duplicate(true)
