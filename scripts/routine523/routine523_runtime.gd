extends RefCounted
## World-owned 523 루틴(일간/주간/월간/월드 주간 미션) and 할 일 목록(현황판)
## state: per-period goal progress, reward receipts, resets, and the board's
## registered contents. Rules come from routine523_source.gd only; a mission
## or board entry the tables cannot complete keeps its reason and is shown,
## never completed or paid.
##
## Calendar: TWILIGHT's one game calendar (user decision 2026-11-09): Korea
## time with the 05:00 boundary for the day (quest_service), the week from
## Wednesday 05:00 (domination_stone_runtime, the 523 shop's "주간 수요일 05시")
## and the month from the 1st 05:00. A clock moved backwards never resets.
const SRC = preload("res://scripts/routine523/routine523_source.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const QUESTS = preload("res://scripts/quests/quest_service.gd")
const DOMINATION = preload("res://scripts/domination/domination_stone_runtime.gd")
const SCHEMA := "routine523-v1"
const SAVE_KEY := "routine523"
const MAX_BLESSING: int = 999999
const PERIOD_NAMES: Array[String] = ["daily","weekly","monthly"]
## Original BuffCardDeck IDs of TWILIGHT's card categories (as world.gd's
## card_compose event): Polymorph 1, MagicDoll 2, HolyStuff 98.
const CARD_DECKS: Dictionary = {"변신":1,"마법인형":2,"성물":98}

var state: Dictionary = fresh()
var save_blocked: bool = false
var problem: String = ""
var _world: WeakRef
var _contract: Dictionary = {}
var _blocked_raw: Variant = null
var _pending_applied: bool = false
## Pending buckets kept at most (one per day the tables were not read).
const MAX_PENDING: int = 40
## Test hooks: contract and clock.
var contract_override: Dictionary = {}
var now_override: int = -1

static func fresh() -> Dictionary:
	return {"schema":SCHEMA,"periods":{"daily":-1,"weekly":-1,"monthly":-1},"progress":{},"claimed":{},"pending":{},"todo":{"mode":"recommend","custom":{"daily":[],"weekly":[]},"event_auto":false}}

func configure(world: Object) -> void:
	_world = weakref(world)

func _w() -> Object:
	return _world.get_ref() if _world != null else null

## The original tables are read on first use (a window, a claim), never on
## the boot or combat path: occurrences before that wait in state.pending.
func contract() -> Dictionary:
	if not contract_override.is_empty():
		if not _pending_applied: _apply_pending(contract_override)
		return contract_override
	if _contract.get("ok",false): return _contract
	_contract = SRC.load_contract()
	if _contract.get("ok",false): _apply_pending(_contract)
	return _contract

func tables_loaded() -> bool:
	return not contract_override.is_empty() or _contract.get("ok",false)

func available() -> bool:
	return contract().get("ok",false)

func now() -> int:
	return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())

## --- Calendar -------------------------------------------------------------

static func period_key(period: String, unix_time: int) -> int:
	match period:
		"daily": return QUESTS.korean_daily_key(unix_time)
		"weekly": return DOMINATION.week_key(unix_time)
		"monthly":
			# Korea time minus the 05:00 boundary (UTC+9-5 = UTC+4).
			var date: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time + 4 * 3600)
			return int(date.year) * 12 + int(date.month) - 1
	return -1

## Clears the progress and receipts of every period that moved forward.
func advance(at: int = -1) -> bool:
	# Without the original tables the periods stay put: their progress is
	# cleared only by a reset that knows which missions belong to the period.
	if save_blocked or not available(): return false
	var clock: int = at if at >= 0 else now()
	var c: Dictionary = contract()
	var changed: bool = false
	for period: String in PERIOD_NAMES:
		var key: int = period_key(period,clock)
		var old: int = int(state.periods.get(period,-1))
		if old < 0:
			state.periods[period] = key
			changed = true
		elif key > old:
			state.periods[period] = key
			changed = true
			for id: Variant in c.get("missions",{}):
				var mission: Dictionary = c.missions[id]
				if str(mission.get("period","")) != period: continue
				state.progress.erase(str(id))
				state.claimed.erase(str(id))
	return changed

## --- Missions ---------------------------------------------------------------

func mission(id: int) -> Dictionary:
	return contract().get("missions",{}).get(id,{})

func progress(id: int) -> int:
	var m: Dictionary = mission(id)
	if m.is_empty() or not m.has("goal"): return 0
	var amount: int = int(m.goal.amount)
	if int(m.type) == SRC.COMPLETE_TYPE:
		var done: int = 0
		for other: int in contract().get("by_type",{}).get(int(m.get("counts_type",-1)),[]):
			if achieved(other): done += 1
		return mini(done,amount)
	return mini(int(state.progress.get(str(id),0)),amount)

func achieved(id: int) -> bool:
	var m: Dictionary = mission(id)
	return not m.is_empty() and (m.reasons as Array).is_empty() and m.has("goal") and progress(id) >= int(m.goal.amount)

func claimed(id: int) -> bool:
	return bool(state.claimed.get(str(id),false))

func receivable(id: int) -> bool:
	return achieved(id) and not claimed(id)

## {id, title, goal_text, progress, amount, status, reason, rewards} rows of
## one RoutineType in table order.
func missions_of(type_id: int) -> Array[Dictionary]:
	advance()
	var result: Array[Dictionary] = []
	for id: int in contract().get("by_type",{}).get(type_id,[]):
		result.append(view(id))
	return result

func view(id: int) -> Dictionary:
	var m: Dictionary = mission(id)
	var amount: int = int(m.get("goal",{}).get("amount",0))
	var status: String = "claimed" if claimed(id) else ("receivable" if achieved(id) else ("refused" if not (m.get("reasons",[]) as Array).is_empty() else "progress"))
	return {"id":id,"type":int(m.get("type",0)),"title":str(m.get("title","")),"scenario":str(m.get("scenario","")),"goal_text":str(m.get("goal",{}).get("text","")),"goal_type":str(m.get("goal",{}).get("type","")),"progress":progress(id),"amount":amount,"status":status,"reason":reason_text(m.get("reasons",[])),"rewards":(m.get("rewards",[]) as Array).duplicate(true)}

static func reason_text(reasons: Array) -> String:
	if reasons.is_empty(): return ""
	var first: String = str(reasons[0])
	if first.begins_with("goal_unsupported:"): return str(SRC.UNSUPPORTED_GOALS.get(first.get_slice(":",1),"원본 목표 집계 규칙 없음"))
	match first:
		"goal_missing": return "원본 목표(Goal) 행이 연결되지 않아 집계하지 않습니다"
		"npc_group_missing": return "원본 몬스터 그룹 구성이 없어 집계하지 않습니다"
		"level_reward_unsupported": return "레벨 보상 규칙(혈맹 전용)이 없어 보류합니다"
	if first.begins_with("reward_"): return "원본 보상 지급 규칙 미확인 · 보류 ("+first+")"
	return "원본 규칙 미확인 · 보류 ("+first+")"

## One authoritative game occurrence. Kills come with the original NpcClass
## ID; other kinds with {amount} and their own keys (deck, challenge_id).
func record(kind: String, payload: Dictionary = {}) -> bool:
	if save_blocked: return false
	var amount: int = int(payload.get("amount",1))
	if amount < 1: return false
	if not tables_loaded(): return _buffer(kind,payload,amount)
	advance()
	return _apply(kind,payload,amount,{})

## Counts one occurrence for later: bucketed by the periods it happened in.
func _buffer(kind: String, payload: Dictionary, amount: int) -> bool:
	var clock: int = now()
	var bucket: String = "%d:%d:%d" % [period_key("daily",clock),period_key("weekly",clock),period_key("monthly",clock)]
	if not state.pending.has(bucket):
		if state.pending.size() >= MAX_PENDING: return false
		state.pending[bucket] = {}
	var key: String = "%s:%d:%d:%d" % [kind,int(payload.get("npc_id",0)),int(payload.get("deck",0)),int(payload.get("challenge_id",0))]
	if not state.pending[bucket].has(key) and (state.pending[bucket] as Dictionary).size() >= 5000: return false
	state.pending[bucket][key] = int(state.pending[bucket].get(key,0)) + amount
	if kind != "kill": _dirty()
	return true

## Applies the buffered occurrences once the tables are read: a bucket only
## counts for the periods still current.
func _apply_pending(c: Dictionary) -> void:
	_pending_applied = true
	if save_blocked or state.pending.is_empty(): return
	advance()
	for bucket: String in state.pending:
		var keys: PackedStringArray = bucket.split(":")
		if keys.size() != 3: continue
		var current: Dictionary = {"daily":int(keys[0]) == int(state.periods.daily),"weekly":int(keys[1]) == int(state.periods.weekly),"monthly":int(keys[2]) == int(state.periods.monthly)}
		for key: String in state.pending[bucket]:
			var parts: PackedStringArray = key.split(":")
			if parts.size() != 4: continue
			_apply(parts[0],{"npc_id":int(parts[1]),"deck":int(parts[2]),"challenge_id":int(parts[3])},int(state.pending[bucket][key]),current,c)
	state.pending = {}
	_dirty()

func _apply(kind: String, payload: Dictionary, amount: int, periods: Dictionary, given: Dictionary = {}) -> bool:
	var c: Dictionary = given if not given.is_empty() else contract()
	var changed: bool = false
	for id: Variant in c.missions:
		var m: Dictionary = c.missions[id]
		if not (m.reasons as Array).is_empty() or int(m.type) == SRC.COMPLETE_TYPE or bool(state.claimed.get(str(id),false)): continue
		if not periods.is_empty() and not bool(periods.get(str(m.period),false)): continue
		if not _matches(m.goal,kind,payload,c): continue
		var before: int = int(state.progress.get(str(id),0))
		var after: int = mini(int(m.goal.amount),before+amount)
		if after != before:
			state.progress[str(id)] = after
			changed = true
	if changed and kind != "kill":
		var world: Object = _w()
		if world != null and world.has_method("_request_deferred_save"): world._request_deferred_save()
	return changed

static func _matches(goal: Dictionary, kind: String, payload: Dictionary, c: Dictionary) -> bool:
	var class_id: int = int(goal.class_id)
	match str(goal.type):
		"AnyNpcKill": return kind == "kill"
		"NpcGroupKill":
			if kind != "kill": return false
			var members: Dictionary = c.get("group_members",{}).get(class_id,{})
			var npc: int = int(payload.get("npc_id",0))
			# A member row limited to some servers is not counted (no rule for
			# the offline world beyond ServerLimitSetID 0 here).
			return members.has(npc) and int(members[npc]) == 0
		"ChallengeCompleteCount": return kind == "challenge_complete" and (class_id == 0 or class_id == int(payload.get("challenge_id",0)))
		"BuffCardBuy": return kind == "card_buy" and class_id == int(payload.get("deck",0))
		"BuffCardCompose": return kind == "card_compose" and class_id == int(payload.get("deck",0))
		"TryItemCraft": return kind == "craft_try" and class_id == 0
		"ItemEnchantSuccess": return kind == "enchant_success" and class_id == 0
	return false

## --- Rewards ---------------------------------------------------------------

func claim(id: int) -> Dictionary:
	return _claim([id])

## Every receivable mission of one type (the original 모두 받기).
func claim_all(type_id: int) -> Dictionary:
	advance()
	var ids: Array = []
	for id: int in contract().get("by_type",{}).get(type_id,[]):
		if receivable(id): ids.append(id)
	if ids.is_empty(): return _refuse("받을 수 있는 미션 보상이 없습니다")
	return _claim(ids)

func _claim(ids: Array) -> Dictionary:
	if save_blocked: return _refuse("루틴 저장을 읽지 못해 보상 수령을 막았습니다: "+problem)
	if not available(): return _refuse(str(contract().get("problem","원본 루틴 표 없음")))
	var world: Object = _w()
	if world == null: return _refuse("월드 없음")
	advance()
	var grants: Array = []
	var coins: Dictionary = {}
	var blessing: int = 0
	for raw: Variant in ids:
		var id: int = int(raw)
		var m: Dictionary = mission(id)
		if m.is_empty(): return _refuse("원본 미션이 없습니다")
		if not (m.reasons as Array).is_empty(): return _refuse(reason_text(m.reasons))
		if claimed(id): return _refuse("이미 받은 미션 보상입니다")
		if not achieved(id): return _refuse("미션 목표를 아직 달성하지 않았습니다 (%d/%d)" % [progress(id),int(m.goal.amount)])
		for reward: Dictionary in m.rewards:
			if reward.kind == "item" and not str(reward.get("currency_name","")).is_empty():
				# Coin stacks: the existing currency item of the same name, as
				# the original quest rewards grant them (source_quest523).
				var coin: String = str(reward.currency_name)
				var record: Variant = world.get("loot_catalog").get("by_name",{}).get(coin) if world.get("loot_catalog") is Dictionary else null
				if not record is Dictionary or str(record.get("slot","")) != "currency": return _refuse("원본 화폐 보상(%s)의 게임 화폐가 없어 보존합니다" % coin)
				coins[str(record.get("name",coin))] = int(coins.get(str(record.get("name",coin)),0)) + int(reward.amount)
			elif reward.kind == "item": grants.append({"item_class_id":int(reward.item_class_id),"amount":int(reward.amount),"bless_raw":int(reward.bless_raw),"enchant":0})
			elif reward.kind == "blessing": blessing += int(reward.amount)
	var next: Dictionary = state.duplicate(true)
	for raw: Variant in ids: next.claimed[str(int(raw))] = true
	var overrides: Dictionary = {SAVE_KEY:next}
	if not grants.is_empty():
		var view := STACK.SupplierView.new()
		view.host = world; view.inventory = world.inventory.duplicate(true); view.item_instances = world.item_instances.duplicate(true); view.gold = int(world.gold)
		var staged: Dictionary = SUPPLY.stage(view,grants,{"kind":"source523_routine_reward","table":"RoutineReward","routine_ids":ids.duplicate()})
		view.free()
		if not staged.get("ok",false): return _refuse(str(staged.get("error","보상 지급 준비 실패"))+" · 미션 보상 보존")
		overrides.merge(staged.overrides,true)
	if not coins.is_empty():
		if not overrides.has("inventory"):
			overrides["inventory"] = world.inventory.duplicate(true)
			overrides["item_instances"] = world.item_instances.duplicate(true)
			overrides["gold"] = int(world.gold)
		for coin: String in coins: overrides.inventory[coin] = int(overrides.inventory.get(coin,0)) + int(coins[coin])
	var ain: Dictionary = {}
	if blessing > 0:
		ain = world.ain_service.export_state().duplicate(true)
		ain.blessing = mini(MAX_BLESSING,int(ain.get("blessing",0))+blessing)
		overrides["ainhasad_state"] = ain
	if world._save_game(true,overrides) != OK: return _refuse("루틴 보상 저장 실패 · 보상과 진행 보존")
	state = next
	if overrides.has("inventory"):
		world.inventory = overrides.inventory
		world.item_instances = overrides.item_instances
		world.gold = int(overrides.gold)
	if not ain.is_empty(): world.ain_service.import_state(ain)
	var hud: Variant = world.get("hud")
	if hud != null and is_instance_valid(hud) and hud.has_method("refresh_inventory"): hud.refresh_inventory(world.inventory)
	if world.has_method("_update_hud"): world._update_hud()
	return {"ok":true,"claimed":ids.duplicate(),"items":grants,"coins":coins,"blessing":blessing,"detail":"미션 보상 %d건 수령" % ids.size()}

static func _refuse(message: String) -> Dictionary:
	return {"ok":false,"error":message}

## --- 할 일 목록 (현황판) -----------------------------------------------------

func _level() -> int:
	var world: Object = _w()
	return int(world.get("level")) if world != null and world.get("level") != null else 1

## Clan contents (혈맹 퀘스트·기부, the Clan board category) are online-only
## and out of TWILIGHT's scope (user decision): never listed.
func todo_offline(entry: Dictionary) -> bool:
	if str(entry.get("type_name","")).begins_with("Clan"): return false
	for category: Dictionary in contract().get("todo",{}).get("categories",[]):
		if int(category.id) == int(entry.get("category",0)): return str(category.name) != "Clan"
	return false

## Entries open now for this character (table filters only).
func todo_visible(entry: Dictionary, level: int, clock: int) -> bool:
	return todo_offline(entry) and (entry.reasons as Array).is_empty() and bool(entry.server_allowed) and SRC.level_open(int(entry.add_level),int(entry.remove_level),level) and clock >= int(entry.start) and clock < int(entry.end)

func todo_limit() -> int:
	return int(contract().get("todo",{}).get("limit",0))

## Registrable entries of a reset period (and category, 0 = all), with
## {entry, open, lock_level, registered} in priority order.
func todo_catalog(reset: String, category: int = 0) -> Array[Dictionary]:
	var t: Dictionary = contract().get("todo",{})
	var level: int = _level()
	var clock: int = now()
	var result: Array[Dictionary] = []
	var registered: Array = state.todo.custom.get(reset,[])
	for id: Variant in t.get("entries",{}):
		var entry: Dictionary = t.entries[id]
		if entry.reset != reset or (category != 0 and int(entry.category) != category) or not todo_offline(entry): continue
		if not (entry.reasons as Array).is_empty() or not bool(entry.server_allowed) or clock < int(entry.start) or clock >= int(entry.end): continue
		var open: bool = SRC.level_open(int(entry.add_level),int(entry.remove_level),level)
		# Entries the character has already outgrown are not offered.
		if not open and int(entry.remove_level) > 0 and level >= int(entry.remove_level): continue
		result.append({"entry":entry,"open":open,"lock_level":int(entry.add_level),"registered":int(id) in registered})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.entry.priority) < int(b.entry.priority) if int(a.entry.priority) != int(b.entry.priority) else int(a.entry.id) < int(b.entry.id))
	return result

## The board of one period in the current mode: [{entry, status}].
func todo_board(reset: String) -> Array[Dictionary]:
	advance()
	var t: Dictionary = contract().get("todo",{})
	var level: int = _level()
	var clock: int = now()
	var ids: Array = []
	if str(state.todo.mode) == "recommend":
		for row: Dictionary in t.get("recommend",[]):
			if SRC.level_open(int(row.add_level),int(row.remove_level),level) and int(row.todo_id) not in ids: ids.append(int(row.todo_id))
	else:
		ids = (state.todo.custom.get(reset,[]) as Array).duplicate()
		if bool(state.todo.event_auto):
			for id: Variant in t.get("entries",{}):
				if bool(t.entries[id].is_event) and int(id) not in ids: ids.append(int(id))
	var result: Array[Dictionary] = []
	for id: Variant in ids:
		var entry: Dictionary = t.get("entries",{}).get(int(id),{})
		if entry.is_empty() or entry.reset != reset or not todo_visible(entry,level,clock): continue
		result.append({"entry":entry,"status":todo_status(entry)})
	if str(state.todo.mode) == "recommend":
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.entry.priority) < int(b.entry.priority))
	return result

## {known, done, current, total} from the source the row itself names.
func todo_status(entry: Dictionary) -> Dictionary:
	var link: Dictionary = entry.get("link",{})
	match str(link.get("kind","")):
		"routine_complete":
			var id: int = int(link.routine_id)
			var m: Dictionary = mission(id)
			if m.is_empty() or not (m.reasons as Array).is_empty(): return {"known":false}
			return {"known":true,"done":achieved(id),"current":progress(id),"total":int(m.goal.amount)}
		"quest":
			var world: Object = _w()
			var service: Variant = world.get("quest_service") if world != null else null
			if service == null: return {"known":false}
			var key: String = "m523:quest:%d" % int(link.quest_id)
			if not service.index.has(key): return {"known":false}
			var done: bool = bool(service.claimed.get(key,false))
			return {"known":true,"done":done,"current":1 if done else 0,"total":1}
	return {"known":false}

func todo_set_mode(mode: String) -> Dictionary:
	if save_blocked: return _refuse("루틴 저장 보호 중")
	if mode not in ["recommend","custom"]: return _refuse("현황판 모드 오류")
	state.todo.mode = mode
	_dirty()
	return {"ok":true,"mode":mode}

func todo_register(id: int) -> Dictionary:
	if save_blocked: return _refuse("루틴 저장 보호 중")
	var entry: Dictionary = contract().get("todo",{}).get("entries",{}).get(id,{})
	if entry.is_empty(): return _refuse("원본 할 일 항목이 없습니다")
	var list: Array = state.todo.custom.get(entry.reset,[])
	if id in list:
		list.erase(id)
		_dirty()
		return {"ok":true,"registered":false,"count":list.size()}
	var visible_catalog: bool = false
	for row: Dictionary in todo_catalog(entry.reset):
		if int(row.entry.id) == id and bool(row.open): visible_catalog = true
	if not visible_catalog: return _refuse("등록할 수 없는 컨텐츠입니다 (레벨·기간·서버 조건)")
	if list.size() >= todo_limit(): return _refuse("등록 가능한 컨텐츠는 %d개까지입니다" % todo_limit())
	list.append(id)
	state.todo.custom[entry.reset] = list
	_dirty()
	return {"ok":true,"registered":true,"count":list.size()}

func todo_reset(reset: String) -> Dictionary:
	if save_blocked: return _refuse("루틴 저장 보호 중")
	state.todo.custom[reset] = []
	_dirty()
	return {"ok":true}

func todo_set_event_auto(on: bool) -> Dictionary:
	if save_blocked: return _refuse("루틴 저장 보호 중")
	state.todo.event_auto = on
	_dirty()
	return {"ok":true,"event_auto":on}

func _dirty() -> void:
	var world: Object = _w()
	if world != null and world.has_method("_request_deferred_save"): world._request_deferred_save()

## --- Save -------------------------------------------------------------------

static func validate(value: Variant) -> String:
	if value == null: return ""
	if not value is Dictionary: return "루틴 저장 형식 오류"
	if (value as Dictionary).is_empty(): return ""
	if value.get("schema") != SCHEMA: return "루틴 저장 버전 불일치"
	if not value.get("periods") is Dictionary or not value.get("progress") is Dictionary or not value.get("claimed") is Dictionary or not value.get("todo") is Dictionary: return "루틴 저장 구조 오류"
	for period: String in PERIOD_NAMES:
		if not SRC._int(value.periods.get(period)): return "루틴 기간 저장 오류"
	for id: Variant in value.progress:
		if not str(id).is_valid_int() or not SRC._int(value.progress[id]) or int(value.progress[id]) < 0 or int(value.progress[id]) > 100000000: return "루틴 진행도 저장 오류"
	for id: Variant in value.claimed:
		if not str(id).is_valid_int() or not value.claimed[id] is bool: return "루틴 수령 기록 오류"
	var pending: Variant = value.get("pending",{})
	if not pending is Dictionary or (pending as Dictionary).size() > MAX_PENDING: return "루틴 대기 기록 오류"
	for bucket: Variant in pending:
		if not pending[bucket] is Dictionary or (pending[bucket] as Dictionary).size() > 5000: return "루틴 대기 기록 오류"
		for key: Variant in pending[bucket]:
			if not SRC._int(pending[bucket][key]) or int(pending[bucket][key]) < 0: return "루틴 대기 기록 오류"
	var todo: Dictionary = value.todo
	if str(todo.get("mode","")) not in ["recommend","custom"] or not todo.get("custom") is Dictionary or not todo.get("event_auto") is bool: return "현황판 저장 오류"
	for reset: String in ["daily","weekly"]:
		var list: Variant = todo.custom.get(reset,[])
		if not list is Array or (list as Array).size() > 1000: return "현황판 등록 목록 오류"
		for id: Variant in list:
			if not SRC._int(id): return "현황판 등록 항목 오류"
	return ""

func export_state() -> Variant:
	# An unreadable entry is written back exactly as it was read.
	return _blocked_raw if save_blocked else state.duplicate(true)

func import_state(value: Variant) -> void:
	var error: String = validate(value)
	if not error.is_empty():
		save_blocked = true
		_blocked_raw = value
		problem = error
		state = fresh()
		return
	save_blocked = false
	_blocked_raw = null
	problem = ""
	var loaded: Dictionary = fresh()
	if value is Dictionary and not (value as Dictionary).is_empty():
		for period: String in PERIOD_NAMES: loaded.periods[period] = int(value.periods[period])
		for id: Variant in value.progress: loaded.progress[str(int(str(id)))] = int(value.progress[id])
		for id: Variant in value.claimed:
			if bool(value.claimed[id]): loaded.claimed[str(int(str(id)))] = true
		for bucket: Variant in value.get("pending",{}):
			var counts: Dictionary = {}
			for key: Variant in value.pending[bucket]: counts[str(key)] = int(value.pending[bucket][key])
			loaded.pending[str(bucket)] = counts
		loaded.todo.mode = str(value.todo.mode)
		loaded.todo.event_auto = bool(value.todo.event_auto)
		for reset: String in ["daily","weekly"]:
			var ids: Array = []
			for id: Variant in value.todo.custom.get(reset,[]):
				if int(id) not in ids: ids.append(int(id))
			loaded.todo.custom[reset] = ids
	state = loaded
	# Resets owed by the time the game was away happen on first use (the
	# tables are not read on load); occurrences already pending stay pending.
	_pending_applied = false
	if tables_loaded(): _apply_pending(contract())
