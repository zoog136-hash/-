extends RefCounted
## World-owned domination stone (지배석) state: the three original slots, the
## active set ("권능"), merging and the weekly tower quest board.
## Slot 1 is the existing equipment slot equipped_items["domination_stone"]
## (its item stats already count there); slots 2 and 3 are physical stones
## kept here by instance ID. A stone in a slot stays in the bag (as all
## equipment does) and counts as equipped for selling, storing and merging.
## Rules the original tables do not hold are refused, not guessed (see
## domination_stone_source.gd and the report on the PR).
const SRC = preload("res://scripts/domination/domination_stone_source.gd")
const SCHEMA := "domination-stone-v1"
const SAVE_KEY := "domination_stone523"
const DIAMOND := "다이아"
## TWILIGHT's one calendar: Korea time, 05:00 boundary (quest_service), the
## week starting Wednesday 05:00 like the original weekly notice of the 523
## shop ("주간 수요일 05시").
const WEEK_START_WEEKDAY: int = 3

var state: Dictionary = fresh()
var save_blocked: bool = false
var problem: String = ""
var rng := RandomNumberGenerator.new()
var _world: WeakRef
var _contract: Dictionary = {}
## Test hook: overrides load_contract() and the clock.
var contract_override: Dictionary = {}
var now_override: int = -1
var _blocked_raw: Variant = null

static func fresh() -> Dictionary:
	return {"schema":SCHEMA,"slots":["",""],"week":-1,"board":{},"rerolls":0,"accepted":{},"merges":0}

func configure(world: Object) -> void:
	_world = weakref(world)
	rng.randomize()

func _w() -> Object:
	return _world.get_ref() if _world != null else null

func contract() -> Dictionary:
	if not contract_override.is_empty(): return contract_override
	if _contract.get("ok",false): return _contract
	_contract = SRC.load_contract()
	return _contract

func available() -> bool:
	return contract().get("ok",false)

func _now() -> int:
	return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())

static func week_key(unix_time: int) -> int:
	var day: int = floori(float(unix_time + 4 * 3600) / 86400.0)
	# KST day 0 (1970-01-01 05:00 KST) is a Thursday (weekday 4).
	var weekday: int = posmod(4 + day, 7)
	return day - posmod(weekday - WEEK_START_WEEKDAY, 7)

## --- Save ---------------------------------------------------------------

static func validate(value: Variant) -> String:
	if value == null: return ""
	if not value is Dictionary: return "지배석 저장 형식 오류"
	if (value as Dictionary).is_empty(): return ""
	if value.get("schema") != SCHEMA: return "지배석 저장 버전 불일치"
	if not value.get("slots") is Array or (value.slots as Array).size() != 2: return "지배석 슬롯 저장 오류"
	for id: Variant in value.slots:
		if not id is String: return "지배석 슬롯 저장 오류"
	if not value.get("board") is Dictionary or not value.get("accepted") is Dictionary: return "지배석 퀘스트 저장 오류"
	return ""

func export_state() -> Variant:
	# A blocked (unreadable) entry is written back exactly as it was read.
	return _blocked_raw if save_blocked else state.duplicate(true)

func import_state(value: Variant) -> void:
	var error: String = validate(value)
	if not error.is_empty():
		# An unreadable entry is kept unchanged for the next save, not reset.
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
		for key: String in loaded:
			if (value as Dictionary).has(key): loaded[key] = value[key]
		loaded.week = int(loaded.week)
		loaded.rerolls = int(loaded.rerolls)
		loaded.merges = int(loaded.merges)
		var board: Dictionary = {}
		for floor_key: Variant in loaded.board:
			var slots: Dictionary = {}
			for slot_key: Variant in loaded.board[floor_key]: slots[str(slot_key)] = int(loaded.board[floor_key][slot_key])
			board[str(floor_key)] = slots
		loaded.board = board
		var accepted: Dictionary = {}
		for key: Variant in loaded.accepted: accepted[str(key)] = int(loaded.accepted[key])
		loaded.accepted = accepted
	state = loaded
	_drop_missing_slots()

## A slot whose physical stone no longer exists is emptied (the stone itself
## was never removed from the bag by equipping).
func _drop_missing_slots() -> void:
	var world: Object = _w()
	if world == null: return
	for index: int in range(2):
		var id: String = str(state.slots[index])
		if id.is_empty(): continue
		# Without the original tables the kind is unknown: keep the slot.
		if not world.item_instances.has(id) or (available() and stone_info(_record_of(id)).is_empty()): state.slots[index] = ""

## --- Stones -------------------------------------------------------------

func _record_of(instance_id: String) -> Dictionary:
	var world: Object = _w()
	if world == null or not world.item_instances.has(instance_id): return {}
	var physical: Dictionary = world.item_instances[instance_id]
	var record: Variant = physical.get("record",{})
	if not record is Dictionary or (record as Dictionary).is_empty(): record = world._find_catalog_item_record(str(physical.get("name","")))
	return record

## {id, group, grade, name, merge_price} of an original domination stone record.
func stone_info(record: Dictionary) -> Dictionary:
	if record.is_empty() or str(record.get("slot","")) != "domination_stone" or not record.get("source_m_native_item",false): return {}
	return contract().get("items",{}).get(int(record.get("source_item_class_id",-1)),{})

func slot_count() -> int:
	return SRC.SLOT_LEVELS.size()

func slot_unlocked(index: int) -> bool:
	var world: Object = _w()
	return world != null and index >= 0 and index < SRC.SLOT_LEVELS.size() and int(world.level) >= SRC.SLOT_LEVELS[index]

func is_extra_equipped(instance_id: String) -> bool:
	return not instance_id.is_empty() and instance_id in state.slots

## {instance_id, record, info} of slot `index` (0..2) or {}.
func slot(index: int) -> Dictionary:
	var world: Object = _w()
	if world == null: return {}
	var id: String = ""
	if index == 0:
		var equipped: Variant = world.equipped_items.get("domination_stone",{})
		if equipped is Dictionary and not (equipped as Dictionary).is_empty(): id = str(equipped.get("instance_id",""))
		if id.is_empty() and equipped is Dictionary and not (equipped as Dictionary).is_empty():
			return {"instance_id":"","record":equipped,"info":stone_info(equipped)}
	elif index in [1,2]: id = str(state.slots[index-1])
	if id.is_empty(): return {}
	var record: Dictionary = world.equipped_items.get("domination_stone",{}) if index == 0 else _record_of(id)
	return {"instance_id":id,"record":record,"info":stone_info(record)}

## Catalog records of slots 2 and 3 (slot 1 is counted by the equipment slot).
func bonus_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var world: Object = _w()
	if world == null: return result
	for index: int in [1,2]:
		var entry: Dictionary = slot(index)
		if entry.is_empty() or entry.info.is_empty(): continue
		result.append(world._source_catalog_record("아이템",entry.record))
	return result

## Unequipped original stones in the bag: [{instance_id, record, info}].
func bag_stones() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var world: Object = _w()
	if world == null: return result
	var ids: Array = world.item_instances.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a).naturalnocasecmp_to(str(b)) < 0)
	for raw: Variant in ids:
		var id: String = str(raw)
		var physical: Dictionary = world.item_instances[raw]
		if int(world.inventory.get(str(physical.get("name","")),0)) <= 0 or world._is_instance_equipped(id): continue
		var record: Dictionary = _record_of(id)
		var info: Dictionary = stone_info(record)
		if info.is_empty(): continue
		result.append({"instance_id":id,"record":record,"info":info,"locked":world._item_locked(str(physical.get("name","")),id)})
	return result

func equip(instance_id: String, index: int) -> Dictionary:
	if save_blocked: return _fail("지배석 저장을 읽지 못해 변경을 막았습니다: "+problem)
	var world: Object = _w()
	if world == null: return _fail("월드 없음")
	if not available(): return _fail(str(contract().get("problem","원본 지배석 표 없음")))
	if index < 0 or index >= slot_count(): return _fail("지배석 슬롯 번호 오류")
	if not slot_unlocked(index): return _fail("지배석 슬롯 %d은 %d레벨에 해금됩니다" % [index+1,SRC.SLOT_LEVELS[index]])
	var record: Dictionary = _record_of(instance_id)
	var info: Dictionary = stone_info(record)
	if info.is_empty(): return _fail("원본 지배석이 아닙니다")
	if world._is_instance_equipped(instance_id): return _fail("이미 장착한 지배석입니다")
	if int(world.inventory.get(str(world.item_instances[instance_id].get("name","")),0)) <= 0: return _fail("가방에 없는 지배석입니다")
	var rejection: String = world.LOOT_DROP.PATCH523_DROPS.equipment_error(record, world.job_class, world.level, int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540)))
	if not rejection.is_empty(): return _fail(rejection)
	if not slot(index).is_empty(): unequip(index)
	if index == 0:
		world._equip_or_acquire_item(record,false,instance_id,"domination_stone")
		if str(world.equipped_items.get("domination_stone",{}).get("instance_id","")) != instance_id: return _fail("기존 장착 규칙이 장착을 거부했습니다")
	else:
		state.slots[index-1] = instance_id
		world._invalidate_equipment_static()
	_after_change()
	return {"ok":true,"slot":index,"instance_id":instance_id,"set":active_set()}

func unequip(index: int) -> Dictionary:
	if save_blocked: return _fail("지배석 저장을 읽지 못해 변경을 막았습니다: "+problem)
	var world: Object = _w()
	if world == null: return _fail("월드 없음")
	if index == 0:
		var current: Variant = world.equipped_items.get("domination_stone",{})
		if not current is Dictionary or (current as Dictionary).is_empty(): return _fail("빈 슬롯")
		world.equipped_items["domination_stone"] = {}
	elif index in [1,2]:
		if str(state.slots[index-1]).is_empty(): return _fail("빈 슬롯")
		state.slots[index-1] = ""
	else: return _fail("지배석 슬롯 번호 오류")
	world._invalidate_equipment_static()
	_after_change()
	return {"ok":true,"slot":index}

func _after_change() -> void:
	var world: Object = _w()
	if world == null: return
	if world.has_method("_refresh_speed_modifiers"): world._refresh_speed_modifiers()
	world.hp = mini(int(world.hp), int(world._effective_max_hp()))
	world.mp = mini(int(world.mp), int(world._effective_max_mp()))
	if world.get("hud") != null:
		world.hud.refresh_inventory(world.inventory)
	world._update_hud()
	world._request_deferred_save()

## The set of the three equipped stones: {active, set_id, name, title, grade,
## entries, desc, kinds} — a set needs one kind in all three slots; its grade
## is the highest SetBonus grade every one of the three stones reaches.
func active_set() -> Dictionary:
	var c: Dictionary = contract()
	var groups: Array[int] = []
	var grades: Array[int] = []
	for index: int in range(slot_count()):
		var entry: Dictionary = slot(index)
		if entry.is_empty() or entry.info.is_empty(): return {"active":false,"equipped":groups.size()}
		groups.append(int(entry.info.group))
		grades.append(int(entry.info.grade))
	if groups.min() != groups.max(): return {"active":false,"equipped":3,"mixed":true}
	var set_id: int = int(c.get("set_of_group",{}).get(groups[0],-1))
	var set_row: Dictionary = c.get("sets",{}).get(set_id,{})
	if set_row.is_empty(): return {"active":false,"equipped":3}
	var lowest: int = grades.min()
	var grade: int = -1
	for g: Variant in set_row.bonuses:
		if int(g) <= lowest and int(g) > grade: grade = int(g)
	var result: Dictionary = {"active":grade > 0,"equipped":3,"set_id":set_id,"name":str(set_row.name),"title":str(set_row.title),"grade":grade,"lowest_grade":lowest,"entries":(set_row.bonuses.get(grade,[]) as Array).duplicate(true) if grade > 0 else [],"desc":str(set_row.desc.get(grade,""))}
	return result

## --- Merge (합성) --------------------------------------------------------

## Preview of a merge of these physical stones: price, grade odds, kind odds.
func merge_quote(ids: Array) -> Dictionary:
	if save_blocked: return _fail("지배석 저장을 읽지 못해 변경을 막았습니다: "+problem)
	var c: Dictionary = contract()
	if not c.get("ok",false): return _fail(str(c.get("problem","원본 지배석 표 없음")))
	if ids.size() < SRC.MERGE_MIN: return _fail("합성은 최소 %d개의 지배석이 필요합니다" % SRC.MERGE_MIN)
	if ids.size() > SRC.MERGE_MAX: return _fail("합성 슬롯은 %d개입니다" % SRC.MERGE_MAX)
	var world: Object = _w()
	if world == null: return _fail("월드 없음")
	var seen: Dictionary = {}
	var price: int = 0
	var groups: Dictionary = {}
	var grades: Dictionary = {}
	var min_grade: int = 99
	for raw: Variant in ids:
		var id: String = str(raw)
		if seen.has(id): return _fail("같은 지배석을 두 번 등록했습니다")
		seen[id] = true
		if world._is_instance_equipped(id): return _fail("장착 중인 지배석은 합성 재료가 될 수 없습니다")
		var record: Dictionary = _record_of(id)
		var info: Dictionary = stone_info(record)
		if info.is_empty(): return _fail("원본 지배석이 아닙니다")
		if int(info.merge_price) <= 0: return _fail("원본 합성 재료(DominationStoneMergeInput)가 아닌 지배석입니다")
		var name: String = str(world.item_instances[id].get("name",""))
		if int(world.inventory.get(name,0)) <= 0: return _fail("가방에 없는 지배석입니다")
		if world._item_locked(name,id): return _fail("잠금된 지배석입니다")
		price += int(info.merge_price)
		groups[int(info.group)] = true
		grades[int(info.grade)] = true
		min_grade = mini(min_grade,int(info.grade))
	var band: Dictionary = SRC.grade_band(c,price)
	if band.is_empty(): return _fail("원본 합성 등급 구간이 없습니다: %d" % price)
	var same: int = -1
	if groups.size() == 1 and grades.size() == 1 and ids.size() == SRC.MERGE_MAX:
		same = int(c.same_group.get(int(groups.keys()[0]),-1))
	return {"ok":true,"price":price,"grades":(band.grades as Array).duplicate(true),"base_groups":(c.base_groups as Array).duplicate(true),"same_group":int(groups.keys()[0]) if same >= 0 else -1,"same_group_probability_raw":same,"min_grade":min_grade,"count":ids.size()}

func merge(ids: Array) -> Dictionary:
	var quote: Dictionary = merge_quote(ids)
	if not quote.get("ok",false): return quote
	var c: Dictionary = contract()
	var world: Object = _w()
	var grade_roll: int = rng.randi_range(0,SRC.PROBABILITY_SCALE-1)
	var grade: int = SRC.pick(quote.grades,grade_roll)
	var group: int = -1
	var kept: bool = false
	if int(quote.same_group) > 0:
		var keep_roll: int = rng.randi_range(0,SRC.PROBABILITY_SCALE-1)
		if keep_roll < int(quote.same_group_probability_raw):
			group = int(quote.same_group); kept = true
	if group < 0:
		group = SRC.pick(quote.base_groups,rng.randi_range(0,SRC.PROBABILITY_SCALE-1))
	var output_id: int = int(c.output_item.get("%d:%d" % [group,grade],-1))
	if output_id <= 0: return _fail("합성 결과 아이템이 원본 표에 없습니다")
	var output: Dictionary = world._catalog_item_from_source_id("m523:item:%d" % output_id)
	if output.is_empty() or stone_info(output).is_empty(): return _fail("합성 결과 아이템이 게임 도감에 없습니다: %d" % output_id)
	# Inputs are removed only after the result is known to be grantable.
	var consumed: Array[String] = []
	for raw: Variant in ids:
		var id: String = str(raw)
		var name: String = str(world.item_instances[id].get("name",""))
		world.item_instances.erase(id)
		var left: int = int(world.inventory.get(name,0)) - 1
		if left > 0: world.inventory[name] = left
		else: world.inventory.erase(name)
		consumed.append(name)
	var output_name: String = str(output.get("name",""))
	var before: Dictionary = {}
	for key: Variant in world.item_instances: before[str(key)] = true
	world.inventory[output_name] = int(world.inventory.get(output_name,0)) + 1
	world._sync_item_instances()
	var new_id: String = ""
	for key: Variant in world.item_instances:
		if not before.has(str(key)) and str(world.item_instances[key].get("name","")) == output_name: new_id = str(key)
	if not new_id.is_empty() and not world.item_instances[new_id].has("record"): world.item_instances[new_id]["record"] = output.duplicate(true)
	state.merges = int(state.merges) + 1
	var divination: int = divination_grade(grade,int(quote.min_grade))
	_after_change()
	return {"ok":true,"item_class_id":output_id,"name":output_name,"instance_id":new_id,"grade":grade,"group":group,"kept_kind":kept,"price":int(quote.price),"consumed":consumed,"divination_grade":divination}

## UIDominationStoneMergeDivinationProb: the grade the roulette shows before
## the result (presentation only), -1 when the table has no row for it.
func divination_grade(result_grade: int, min_input_grade: int) -> int:
	var pairs: Array = contract().get("divination",{}).get("%d:%d" % [result_grade,min_input_grade],[])
	if pairs.is_empty(): return -1
	return SRC.pick(pairs,rng.randi_range(0,SRC.pair_total(pairs)-1))

## --- Weekly tower quests ----------------------------------------------

func _roll_week() -> void:
	var week: int = week_key(_now())
	if int(state.week) == week: return
	state.week = week
	state.rerolls = 0
	state.accepted = {}
	state.board = {}

## {floor_id: {slot: quest}} of the current week (defaults until rerolled).
func board() -> Array[Dictionary]:
	_roll_week()
	var c: Dictionary = contract()
	var result: Array[Dictionary] = []
	if not c.get("ok",false): return result
	var floor_ids: Array = c.floors.keys()
	floor_ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var fa: Dictionary = c.floors[a]; var fb: Dictionary = c.floors[b]
		var ta: int = int(c.towers[int(fa.tower)].priority); var tb: int = int(c.towers[int(fb.tower)].priority)
		return ta > tb if ta != tb else int(fa.floor) < int(fb.floor))
	for floor_id: Variant in floor_ids:
		var floor: Dictionary = c.floors[floor_id]
		var slots: Array[Dictionary] = []
		var keys: Array = floor.slots.keys()
		keys.sort()
		for slot_index: Variant in keys:
			var group: Dictionary = c.quest_groups[int(floor.slots[slot_index])]
			slots.append({"slot":int(slot_index),"group":int(group.id),"quest":_board_quest(int(floor_id),int(slot_index),group)})
		result.append({"floor_id":int(floor_id),"tower":int(floor.tower),"floor":int(floor.floor),"slots":slots})
	return result

func _board_quest(floor_id: int, slot_index: int, group: Dictionary) -> Dictionary:
	var chosen: int = int(state.board.get(str(floor_id),{}).get(str(slot_index),-1))
	for quest: Dictionary in group.quests:
		if (chosen < 0 and quest.default) or int(quest.quest_id) == chosen: return quest
	return {}

## Cost of the next reroll ({count, currency_id, amount}) or {} past the table.
func next_reroll_cost() -> Dictionary:
	_roll_week()
	var costs: Array = contract().get("reroll",[])
	var index: int = int(state.rerolls)
	return (costs[index] as Dictionary).duplicate() if index < costs.size() else {}

func _balance(currency_id: int) -> int:
	var world: Object = _w()
	if world == null: return 0
	return int(world.gold) if currency_id == 1 else int(world.inventory.get(DIAMOND,0))

func _pay(currency_id: int, amount: int) -> void:
	var world: Object = _w()
	if currency_id == 1: world.gold = int(world.gold) - amount
	else: world.inventory[DIAMOND] = int(world.inventory.get(DIAMOND,0)) - amount

## Rerolls every slot of one floor by the original quest probabilities.
func reroll(floor_id: int) -> Dictionary:
	if save_blocked: return _fail("지배석 저장을 읽지 못해 변경을 막았습니다: "+problem)
	_roll_week()
	var c: Dictionary = contract()
	if not c.get("ok",false): return _fail(str(c.get("problem","원본 지배석 표 없음")))
	if not c.floors.has(floor_id): return _fail("원본 층이 아닙니다")
	if not (state.accepted as Dictionary).is_empty(): return _fail("이번 주 퀘스트를 이미 수락했습니다")
	var cost: Dictionary = next_reroll_cost()
	if cost.is_empty(): return _fail("이번 주 새로고침 횟수를 모두 사용했습니다 (원본 %d회)" % (c.reroll as Array).size())
	if _balance(int(cost.currency_id)) < int(cost.amount): return _fail("%s이(가) 부족합니다 (%d 필요)" % [str(SRC.CURRENCY_NAMES[int(cost.currency_id)]),int(cost.amount)])
	_pay(int(cost.currency_id),int(cost.amount))
	state.rerolls = int(state.rerolls) + 1
	var floor: Dictionary = c.floors[floor_id]
	var slots: Dictionary = {}
	for slot_index: Variant in floor.slots:
		var group: Dictionary = c.quest_groups[int(floor.slots[slot_index])]
		var pairs: Array = []
		for quest: Dictionary in group.quests: pairs.append([int(quest.quest_id),int(quest.probability_raw)])
		slots[str(slot_index)] = SRC.pick(pairs,rng.randi_range(0,SRC.pair_total(pairs)-1))
	state.board[str(floor_id)] = slots
	_after_change()
	return {"ok":true,"floor_id":floor_id,"cost":cost,"slots":slots}

func accept(floor_id: int, slot_index: int) -> Dictionary:
	if save_blocked: return _fail("지배석 저장을 읽지 못해 변경을 막았습니다: "+problem)
	_roll_week()
	var c: Dictionary = contract()
	if not c.get("ok",false): return _fail(str(c.get("problem","원본 지배석 표 없음")))
	if not (state.accepted as Dictionary).is_empty(): return _fail("이번 주 퀘스트를 이미 수락했습니다 (주중 변경·포기 불가)")
	if not c.floors.has(floor_id) or not c.floors[floor_id].slots.has(slot_index): return _fail("원본 퀘스트 슬롯이 아닙니다")
	var quest: Dictionary = _board_quest(floor_id,slot_index,c.quest_groups[int(c.floors[floor_id].slots[slot_index])])
	if quest.is_empty(): return _fail("퀘스트가 없습니다")
	state.accepted = {"floor_id":floor_id,"slot":slot_index,"quest_id":int(quest.quest_id)}
	_after_change()
	return {"ok":true,"accepted":state.accepted.duplicate(),"title":str(quest.title)}

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}
