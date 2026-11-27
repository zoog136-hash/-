extends SceneTree
## 2026-11-19 일반 퀘스트 591개 중 수락 가능 0 (기간 종료 463, QuestResetType
## 11/21 "원본 반복/초기화 규칙 확인 필요" 117). Policy: original windows are
## removed (기한 없음, same as the 2026-11-16 craft decision) and the reset
## types get a TWILIGHT 근사 (11 = daily 05:00 KST, 21 = weekly Wednesday
## 05:00 KST, MaxDailyRepeat = completions per period). A repeat never grants
## a second per-grant receipt: quests whose rewards hold original items stay
## one-time. Without the original ZIP (CI): the rules, calendar, ledger,
## save validation and staged transaction guard on synthetic rows. With the
## original ZIP, in actual Main: common quests open for a new character, a
## daily receipt-free quest is accepted from the quest window, refused again
## in the same period, accepted again after the reset, a held-reward
## repeatable stays one-time, and save/load keeps the ledger.
const SERVICE = preload("res://scripts/quests/quest_service.gd")
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
const DOMINATION = preload("res://scripts/domination/domination_stone_runtime.gd")
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("QUEST_REPEAT_RESET523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

## 2026-11-18 (Wednesday) hh:mm KST as unix time.
static func kst(day: int, hour: int, minute: int = 0) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year":2026,"month":11,"day":day,"hour":hour,"minute":minute,"second":0})) - 9*3600

func _row(id: int, reset_type: int, max_daily: int, ends_at: int = 0) -> Dictionary:
	return {"id":"m523:quest:"+str(id),"source_id":id,"title":"Synthetic "+str(id),"category":"common",
		"definition":{"ID":id,"Name":"Synthetic","TypeID":3,"QuestResetType":reset_type,"MaxDailyRepeat":max_daily,"LimitHours":0,"LimitWeeklyOpenTimeGroup":0},
		"prerequisites":[],"goals":[],"source_rewards":[{"ID":id,"CharacterClassID":0,"ClanOnly":false,"RewardEnhancementTypeID":1,"Amount":100,"RewardClassID":0,"type_name":"Exp","source_item":{}}],
		"enhancements":[],"blockers":[],"excluded_reasons":[],"starts_at":0,"ends_at":ends_at,"description":"","objective":{"kind":"source","count":1,"target":""},"rewards":{},"min_level":1}

func synthetic() -> void:
	# Rules: compact and complete rows read the same (reset, max) pair.
	var daily: Dictionary = _row(1,11,1)
	var many: Dictionary = _row(2,11,999)
	var weekly: Dictionary = _row(3,21,0)
	var other: Dictionary = _row(4,32,0)
	var once: Dictionary = _row(5,0,0)
	check(SOURCE.repeat_rule(daily) == {"period":"daily","limit":1,"reset_type":11}, "11 = daily, MaxDailyRepeat 1")
	check(SOURCE.repeat_rule(many).limit == 999 and SOURCE.repeat_rule(weekly) == {"period":"weekly","limit":1,"reset_type":21}, "MaxDailyRepeat = per-period count, 0 = once; 21 = weekly")
	check(SOURCE.repeat_rule(other).is_empty() and SOURCE.repeat_rule(once).is_empty(), "other reset types and one-time quests have no repeat rule")
	var compact: Dictionary = SOURCE._compact(daily)
	check(compact.get(SOURCE.LAZY_KEY,{}).get("repeat") == [11,1] and SOURCE.repeat_rule(compact) == SOURCE.repeat_rule(daily) and str(compact[SOURCE.LAZY_KEY].after).is_empty(), "compact row keeps the repeat rule and opens")
	check(SOURCE.RECORDS_SCHEMA == 3, "record bake schema covers the compact startup reward field")
	var source = SOURCE.new()
	var context: Dictionary = {"level":1,"max_level":1,"class_id":1}
	var ended: int = kst(18,12)
	for row: Dictionary in [daily, many, weekly, once]:
		check(source.gate(row,context,{},ended).is_empty(), "ended original window does not close quest %s (기한 없음)" % row.id)
		check(source.gate(SOURCE._compact(row),context,{},ended).is_empty(), "compact gate equal for %s" % row.id)
	check(source.gate(other,context,{},ended) == SOURCE.REPEAT_UNKNOWN and source.gate(SOURCE._compact(other),context,{},ended) == SOURCE.REPEAT_UNKNOWN, "unknown reset type 32 stays closed")
	# Calendar: the same week as domination_stone_runtime; boundaries at 05:00 KST.
	var same: bool = true
	for step: int in range(0, 21*24):
		var at: int = kst(10,0) + step*3600 + 1800
		if SERVICE.korean_week_key(at) != DOMINATION.week_key(at): same = false
	check(same, "week key equals domination week_key (Wednesday 05:00 KST)")
	check(SERVICE.korean_daily_key(kst(19,4,59)) == SERVICE.korean_daily_key(kst(18,5)) and SERVICE.korean_daily_key(kst(19,5)) == SERVICE.korean_daily_key(kst(18,5))+1, "day turns at 05:00 KST")
	check(SERVICE.korean_week_key(kst(25,4,59)) == SERVICE.korean_week_key(kst(18,5)) and SERVICE.korean_week_key(kst(25,5)) > SERVICE.korean_week_key(kst(18,5)), "week turns on Wednesday 05:00 KST (2026-11-25)")
	# Ledger through the service.
	var service = SERVICE.new()
	for row: Dictionary in [daily, many, weekly, other, once]:
		service.quests.append(row); service.index[row.id] = row
	var plan_ok: Dictionary = {"ok":true,"items":[{"record":{"name":"아데나"},"quantity":5,"stack_only":true}],"adena":0,"exp":100}
	var plan_held: Dictionary = {"ok":true,"items":[{"record":{"name":"[원본 보상] X","source_pending_use":true},"quantity":1}],"adena":0,"exp":0}
	check(SERVICE.repeat_reward_problem(plan_ok).is_empty() and SERVICE.repeat_reward_problem(plan_held) == SERVICE.REPEAT_REWARD_PROBLEM, "repeat grants only receipt-free rewards")
	var t0: int = kst(18,12)
	service.claimed[daily.id] = true
	service.repeats[daily.id] = service.repeat_after(daily.id,t0,{},plan_ok)
	check(service.repeats[daily.id] == {"period":SERVICE.korean_daily_key(t0),"count":1,"again":true}, "first completion opens the period ledger")
	check(service.done(daily.id,kst(19,4,59)) and not service.done(daily.id,kst(19,5)), "daily repeat opens at the next 05:00, not before")
	check(service.done(daily.id,t0-86400), "a clock moved backwards does not open a repeat")
	service.claimed[many.id] = true
	var ledger: Dictionary = {}
	for n: int in 3: ledger[many.id] = service.repeat_after(many.id,t0+n,ledger,plan_ok)
	service.repeats[many.id] = ledger[many.id]
	check(int(ledger[many.id].count) == 3 and not service.done(many.id,t0+10), "MaxDailyRepeat 999: still open after 3 in the same day")
	service.repeats[many.id] = {"period":SERVICE.korean_daily_key(t0),"count":999,"again":true}
	check(service.done(many.id,t0+10) and not service.done(many.id,kst(19,6)), "MaxDailyRepeat reached: closed until the reset")
	service.claimed[weekly.id] = true
	service.repeats[weekly.id] = service.repeat_after(weekly.id,t0,{},plan_ok)
	check(service.done(weekly.id,kst(24,23)) and service.done(weekly.id,kst(25,4,59)) and not service.done(weekly.id,kst(25,5)), "weekly repeat opens on Wednesday 05:00")
	service.claimed[once.id] = true
	check(service.repeat_after(once.id,t0,{},plan_ok).is_empty() and service.done(once.id,kst(30,12)), "one-time quest never reopens")
	service.claimed[other.id] = true
	check(service.done(other.id,kst(30,12)), "unknown reset type never reopens")
	service.repeats[daily.id] = service.repeat_after(daily.id,t0,{},plan_held)
	check(service.done(daily.id,kst(20,12)), "held-reward repeatable stays one-time after the reset")
	var page: Dictionary = service.text_page(1,"common",0,60,"","all",kst(20,12),1)
	var status: Dictionary = {}
	for row: Dictionary in page.rows: status[row.id] = row
	check(status[daily.id].completed and str(status[daily.id].status).contains(SERVICE.REPEAT_REWARD_PROBLEM), "quest window names a one-time repeat: "+str(status[daily.id].status))
	check(status[weekly.id].completed and str(status[weekly.id].status).contains("다음 초기화 주간 수요일 05시 (1/1)"), "quest window shows the weekly reset: "+str(status[weekly.id].status))
	# Save: export/import/validate.
	var state: Dictionary = service.export_state()
	check(state.has("repeats") and SERVICE.validate_saved_state(state).is_empty(), "ledger saved and valid")
	var broken: Dictionary = state.duplicate(true); broken.claimed.erase(weekly.id)
	check(not SERVICE.validate_saved_state(broken).is_empty(), "ledger entry without its claim is refused")
	broken = state.duplicate(true); broken.repeats[weekly.id].count = 0
	check(not SERVICE.validate_saved_state(broken).is_empty(), "ledger count 0 is refused")
	var reload = SERVICE.new()
	for row: Dictionary in [daily, many, weekly, other, once]:
		reload.quests.append(row); reload.index[row.id] = row
	check(reload.import_state(JSON.parse_string(JSON.stringify(state)),t0) and reload.repeats == service.repeats, "ledger round trip through JSON")
	# An older save with a claimed repeatable and no ledger: done for this period.
	var legacy: Dictionary = {"schema_version":2,"claimed":{daily.id:true},"progress":{},"unlocked":{},"day_key":0,"ui_requests":{}}
	var seeded = SERVICE.new()
	seeded.quests.append(daily); seeded.index[daily.id] = daily
	check(seeded.import_state(legacy,t0) and seeded.done(daily.id,t0+60) and not seeded.done(daily.id,kst(19,5)), "claimed without ledger: done until the next reset")

func acceptable(world: Node, category: String) -> Array[String]:
	var service: Variant = world.quest_service
	var class_id: int = int(service.source.class_ids.get(str(world.job_class),-1))
	var found: Array[String] = []
	var pages: int = int(service.text_page(int(world.level),category,0,60,"","all",-1,class_id).pages)
	for index: int in pages:
		for row: Dictionary in service.text_page(int(world.level),category,index,60,"","all",-1,class_id).rows:
			if bool(row.can_accept): found.append(str(row.id))
	return found

## [수락] of `target` in the actual quest window (found with its search box).
func accept_in_window(world: Node, target: String) -> bool:
	var hud: Node = world.hud
	hud.open_quests()
	for frame: int in 2: await process_frame
	var view: Node = hud.quest_view
	if not check(is_instance_valid(view), "quest window opens"): return false
	view.search.text = str(int(world.quest_service.index.get(target,{}).get("source_id",0)))
	view.selected = "common"
	view.refresh()
	for frame: int in 2: await process_frame
	var button: Button = null
	for row: Node in view.listing.get_children():
		for child: Node in row.get_children():
			if child is Button and not (child as Button).disabled: button = child
	view.search.text = ""
	if button == null: return false
	world.quest_auto.last_completed = [] as Array[String]
	button.pressed.emit()
	for frame: int in 3: await process_frame
	return world.quest_auto.last_completed.has(target)

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main new character (기사)")
	for frame: int in 10: await process_frame
	var service: Variant = world.quest_service
	check(service.quests.size() == 3621, "original quests loaded")
	world.quest_auto.refresh_context(world)
	var class_id: int = int(service.source.class_ids.get(str(world.job_class),-1))
	var now: int = int(Time.get_unix_time_from_system())
	# Why each common quest is closed for this character (level 1).
	var reasons: Dictionary = {}
	var kinds: Dictionary = {"one_time":0,"daily":0,"weekly":0}
	for quest: Dictionary in service.source.quests:
		if str(quest.get("category","")) != "common": continue
		var gate: String = service.source.gate(quest,service.source_context,service.claimed,now)
		reasons[gate] = int(reasons.get(gate,0))+1
		var rule: Dictionary = SOURCE.repeat_rule(quest)
		kinds["one_time" if rule.is_empty() else str(rule.period)] += 1
	evidence["common_gate_level1"] = reasons
	evidence["common_rules"] = kinds
	check(not reasons.has("기간 종료") and not reasons.has(SOURCE.REPEAT_UNKNOWN), "no common quest closed by its ended window or reset type 11/21")
	var open_common: Array[String] = acceptable(world,"common")
	var by_category: Dictionary = {}
	for category: String in ["main","achievement","other"]: by_category[category] = acceptable(world,category).size()
	by_category["common"] = open_common.size()
	evidence["acceptable_by_category_level1"] = by_category
	evidence["common_acceptable_level1"] = open_common.size()
	check(open_common.size() > 0, "common quests acceptable for a new character (was 0)")
	# Pick a receipt-free daily repeatable and a held-reward daily repeatable.
	var free_id: String = ""
	var held_id: String = ""
	var context: Dictionary = service.source_context.duplicate()
	for id: String in open_common:
		var quest: Dictionary = service.index[id]
		var rule: Dictionary = SOURCE.repeat_rule(quest)
		if rule.is_empty() or rule.period != "daily" or int(rule.limit) != 1: continue
		var plan: Dictionary = service.source.reward_plan(service.full(quest),context)
		if not plan.ok: continue
		if SERVICE.repeat_reward_problem(plan).is_empty() and int(plan.exp) > 0 and free_id.is_empty(): free_id = id
		elif not SERVICE.repeat_reward_problem(plan).is_empty() and held_id.is_empty(): held_id = id
	evidence["free_daily"] = free_id
	evidence["held_daily"] = held_id
	if not check(not free_id.is_empty() and not held_id.is_empty(), "daily repeatables of both kinds acceptable"): return
	var growth: Callable = func() -> Array: return [int(world.level), int(world.experience)]
	var before: Array = growth.call()
	check(await accept_in_window(world, free_id), "accepted daily %s from the quest window" % free_id)
	var after_first: Array = growth.call()
	check(after_first != before, "first completion grants its EXP %s -> %s" % [str(before),str(after_first)])
	var entry: Dictionary = service.repeats.get(free_id,{})
	check(entry.get("count") == 1 and entry.get("again") == true and int(entry.get("period",-1)) == SERVICE.korean_daily_key(int(Time.get_unix_time_from_system())), "ledger records today's completion: "+str(entry))
	# Same period: refused (window and direct transaction), nothing granted.
	check(not acceptable(world,"common").has(free_id) and service.done(free_id), "same day: not acceptable again")
	check(not world.quest_auto.complete(world,[free_id] as Array[String]) and growth.call() == after_first, "same day: the transaction refuses a second grant")
	# After the reset (the ledger's period is yesterday): accepted again once.
	service.repeats[free_id].period = int(service.repeats[free_id].period) - 1
	check(acceptable(world,"common").has(free_id), "after the 05:00 reset the daily quest is acceptable again")
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var receipts_before: String = JSON.stringify([service.item_grants, service.claimed.size()])
	check(await accept_in_window(world, free_id), "repeat accepted from the quest window")
	var after_repeat: Array = growth.call()
	check(after_repeat != after_first, "repeat grants its EXP again %s -> %s" % [str(after_first),str(after_repeat)])
	check(JSON.stringify([service.item_grants, service.claimed.size()]) == receipts_before and world.inventory.keys() == inventory_before.keys(), "repeat adds no receipt, claim or item key")
	check(not world.quest_auto.complete(world,[free_id] as Array[String]), "repeat cannot be granted twice in its period")
	# Held-reward repeatable: first completion only.
	check(await accept_in_window(world, held_id), "held-reward daily %s accepted once" % held_id)
	var grants: String = JSON.stringify(service.item_grants)
	var instances: int = world.item_instances.size()
	service.repeats[held_id].period = int(service.repeats[held_id].period) - 1
	check(service.repeats[held_id].again == false and service.done(held_id) and not acceptable(world,"common").has(held_id), "held-reward repeatable stays done after the reset")
	check(not world.quest_auto.complete(world,[held_id] as Array[String]) and JSON.stringify(service.item_grants) == grants and world.item_instances.size() == instances, "held reward is never granted a second time")
	# Save/load keeps the ledger.
	var saved_ledger: Dictionary = service.repeats.duplicate(true)
	check(world._save_game(true) == OK, "save")
	world._load_game(true)
	for frame: int in 3: await process_frame
	check(JSON.stringify(service.repeats) == JSON.stringify(saved_ledger) and service.done(free_id) and service.done(held_id), "save/load keeps the repeat ledger")
	evidence["ledger"] = saved_ledger
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	synthetic()
	if not ROWS.not_installed(): await runtime()
	print("QUEST_REPEAT_RESET523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
