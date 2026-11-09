extends RefCounted
## Existing offline kill credit + existing Korean 05:00 playtest calendar.
## This adapter is explicitly TWILIGHT behavior, not a native server enum claim.
const QuestCalendar = preload("res://scripts/quests/quest_service.gd")
var _runtime: WeakRef
var runtime: RefCounted:
	get: return _runtime.get_ref() if _runtime != null else null
var world: Node
var unix_clock: Callable
var credited_lives: Dictionary = {}

func configure(owner_runtime: RefCounted, owner_world: Node) -> void:
	_runtime = weakref(owner_runtime)
	world = owner_world

func now() -> int:
	return int(unix_clock.call()) if unix_clock.is_valid() else int(Time.get_unix_time_from_system())

func source_clock() -> String:
	# Same fixed Korean offset as QuestCalendar.korean_daily_key; no server TZ inferred.
	var date := Time.get_datetime_dict_from_unix_time(now() + 9 * 3600)
	return "%04d%02d%02d%02d%02d" % [date.year,date.month,date.day,date.hour,date.minute]

func epoch(book_id: int) -> String:
	var book: Dictionary = runtime.catalog.row("MonsterBook", book_id)
	if book.is_empty(): return ""
	if book_id == 6013 and int(book.ResetType) == 1:
		return "korean-day:" + str(QuestCalendar.korean_daily_key(now()))
	if int(book.ResetType) == 0:
		# A local rotation is a new season: progress restarts, earlier seasons stay saved.
		var turn: int = runtime.catalog.rotation(book_id, source_clock())
		return "source-season:" + str(int(book.StartDateTimeID)) + ("" if turn == 0 else ":r" + str(turn))
	return ""

func receipt(action: String, book_id: int) -> Dictionary:
	var state: Dictionary = runtime.catalog.export_state()
	var saved: Dictionary = state.books.get(str(book_id), {})
	return {"action":action,"book_id":book_id,"sequence":int(saved.get("sequence",0))+1,"epoch":epoch(book_id),"authority":"twilight_existing_credited_death_and_korean_playtest_calendar","approved":true,"server_allowed":true,"clock_locale":"Korean","source_clock":source_clock(),"protect_clock":true,"progression_policy":runtime.economy.settings.get("natural_counter_mode","per_stage"),"bonus_policy":runtime.economy.settings.get("bonus_mode","cumulative")}

func window_problem(book_id: int) -> String:
	var book: Dictionary = runtime.catalog.row("MonsterBook", book_id)
	if book.is_empty() or int(book.NpcGroupID) == 0: return "현재 대상 연결 없음"
	if int(book.ServerLimitSetID) != 0: return "원본 서버 조건 확인 필요"
	if epoch(book_id).is_empty(): return "원본 초기화 유형 확인 필요"
	match runtime.catalog.current_period(book_id, source_clock()):
		"not_started": return "도감 시작 전"
		"options_only": return "처치 집계 종료 · 옵션 적용 기간"
		"ended": return "도감 기간 종료"
		"unknown": return "원본 기간 확인 필요"
	var saved: Dictionary = runtime.catalog.export_state().books.get(str(book_id), {})
	if str(saved.get("max_clock", "")) > source_clock(): return "이전 시각으로 되돌린 진행은 보존합니다"
	return ""

func first_level(book_id: int) -> Dictionary:
	for level: Dictionary in runtime.catalog.levels(book_id):
		if int(level.Level) == 1: return level
	return {}

func credit(npc_id: int, life_id: int, actor_id: int, state: Dictionary) -> Dictionary:
	var actor: Object = instance_from_id(actor_id)
	if not is_instance_valid(actor) or not bool(actor.get("dead")) or int(actor.get_meta("rewarded_life_id", -1)) != life_id: return {}
	var key := str(actor_id) + ":" + str(life_id)
	if credited_lives.has(key): return {}
	for book: Dictionary in runtime.catalog.target_books(npc_id):
		var id := int(book.ID)
		if not window_problem(id).is_empty(): continue
		var out := receipt("count", id)
		out["npc_class_id"] = npc_id
		out["level_ids"] = []
		out["track_only"] = true
		out["reset_approved"] = true
		var saved: Dictionary = state.books.get(str(id), {})
		out["start_epoch"] = saved.get("current_epoch", "") != out.epoch
		var first := first_level(id)
		if not first.is_empty() and (out.start_epoch or not runtime.catalog.progress(id).get("registered",[]).has(int(first.ID))):
			out.level_ids = [int(first.ID)]
			out["achieve_level_id"] = int(first.ID)
		out["local_life_key"] = key
		return out
	return {}

func status(action: String, book_id: int, level_id: int) -> String:
	var saved: Dictionary = runtime.catalog.progress(book_id)
	if action in ["effects","auto_effects"]:
		var phase: String = runtime.catalog.current_period(book_id,source_clock())
		if phase not in ["counting","options_only"]: return "옵션 적용 기간 아님"
		if not saved.get("registered",[]).has(level_id): return "단계 달성 필요"
		if action == "auto_effects": return "" if runtime.economy.settings.get("bonus_mode") in ["cumulative","latest"] else "자동 옵션 설정 필요"
		if saved.get("effective_levels",[]) == [level_id]: return "선택 적용 중"
		var supported: bool = false
		for level: Dictionary in runtime.catalog.levels(book_id):
			if int(level.ID) != level_id: continue
			for bonus: Dictionary in level.bonuses:
				if runtime.bonus_status(bonus).is_empty(): supported = true
		if not supported: return "전투에 연결 가능한 옵션 없음"
		return ""
	if action == "register" and saved.get("registered", []).has(level_id): return "등록 완료"
	if action == "claim" and saved.get("claimed", []).has(level_id): return "보상 수령 완료"
	var problem := window_problem(book_id)
	if not problem.is_empty(): return problem
	if action == "instant":
		var level: Dictionary = runtime.catalog.row("MonsterBookLevel",level_id)
		if int(level.get("MonsterBookID",0)) != book_id: return "도감 단계 확인 필요"
		if saved.get("registered",[]).has(level_id): return "달성 완료"
		if int(level.CurrencyID) != 4 or int(level.CurrencyCost) <= 0: return "즉시 완료 대상 아님"
		for prior: Dictionary in runtime.catalog.levels(book_id):
			if int(prior.Level) < int(level.Level) and not saved.get("registered",[]).has(int(prior.ID)): return "이전 단계 달성 필요"
		if runtime.economy.gems() < int(level.CurrencyCost): return "게임 다이아 부족 · 아데나 교환 가능"
		return ""
	var book_save: Dictionary = runtime.catalog.export_state().books.get(str(book_id), {})
	if book_save.get("current_epoch", "") != epoch(book_id): return "이번 기간의 인정 처치가 필요합니다"
	if action == "register":
		var level: Dictionary = runtime.catalog.row("MonsterBookLevel", level_id)
		if int(level.get("Level",0)) != 1 and runtime.economy.settings.get("natural_counter_mode") == "manual": return "후속 단계 누적·초기화 규칙 확인 필요 · 총처치는 보존됩니다"
		if int(saved.get("counts", {}).get(str(level_id),0)) < int(level.Amount): return "필요 처치 수 미달"
		return ""
	if not saved.get("registered", []).has(level_id): return "단계 달성 필요"
	var pending: bool = false
	for level: Dictionary in runtime.catalog.levels(book_id):
		if int(level.ID) != level_id: continue
		for reward: Dictionary in level.rewards:
			if runtime.catalog.reward_claimed(book_id,level_id,int(reward.ID)): continue
			pending = true
			if runtime.items.reward_problem(reward).is_empty(): return ""
	return "아이템 수령 완료 · 남은 보상 환산 확인 필요" if pending else "보상 수령 완료"

func action_receipt(action: String, book_id: int, level_id: int, _state: Dictionary) -> Dictionary:
	if not status(action,book_id,level_id).is_empty(): return {}
	var out := receipt("effects" if action in ["effects","auto_effects"] else ("instant_complete" if action == "instant" else ("achieve" if action == "register" else "claim_rewards")),book_id)
	out["level_id"] = level_id
	if action == "effects":
		out["effective_levels"] = [level_id]
		out["bonus_policy"] = "manual"
	if action == "auto_effects":
		out["effective_levels"] = []
		var ordered: Array = runtime.catalog.levels(book_id)
		ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Level) < int(b.Level))
		for level: Dictionary in ordered:
			if runtime.catalog.progress(book_id).get("registered",[]).has(int(level.ID)):
				if out.bonus_policy == "latest": out.effective_levels.clear()
				out.effective_levels.append(int(level.ID))
	if action == "instant":
		out["reset_approved"] = true
		out["start_epoch"] = runtime.catalog.export_state().books.get(str(book_id),{}).get("current_epoch","") != out.epoch
	if action == "claim":
		out["claim_window_approved"] = true
		out["reward_ids"] = []
		for level: Dictionary in runtime.catalog.levels(book_id):
			if int(level.ID) != level_id: continue
			for reward: Dictionary in level.rewards:
				if not runtime.catalog.reward_claimed(book_id,level_id,int(reward.ID)) and runtime.items.reward_problem(reward).is_empty(): out.reward_ids.append(int(reward.ID))
	return out
