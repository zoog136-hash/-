extends RefCounted
## Local single-save progression. Unknown source values fail closed, never become zero costs.
const Stats = preload("res://scripts/collections/equipment_collection_stats.gd")
const DATA = "res://data/growth/lineage_growth.json"
const Source523 = preload("res://scripts/growth/symbol_source523.gd")
const Travel = preload("res://scripts/growth/symbol_travel.gd")
const Combat = preload("res://scripts/growth/symbol_combat.gd")
const History = preload("res://scripts/growth/symbol_history.gd")
var source523 = Source523.new()
var travel = Travel.new()
var combat = Combat.new()
var history = History.new()
var world
var development: bool = OS.is_debug_build() and "--growth-lab" in OS.get_cmdline_user_args()
var lab: Dictionary = {}
var config: Dictionary = {}
var state: Dictionary = fresh()
var totals: Dictionary = {}
var rerolls: Dictionary = {} # Session only: leaving the screen restores base odds.
var busy: bool = false
var rng := RandomNumberGenerator.new()

static func fresh() -> Dictionary:
	return {"schema":1,"revision":0,"points":0,"emblems":{},"nodes":[],"representative":"","pending":{},"searches":{}}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is Dictionary: config = parsed
	if not development: source523.apply(config)
	if development:
		lab = JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/lab_profile.json"))
		state["profile"] = "development"
		config.guardian_switch_seconds = int(lab.representative_switch_seconds)
		for group: Dictionary in config.guardians:
			var previous: String = ""
			for row: Dictionary in group.nodes:
				row.prerequisites = [] if previous.is_empty() else [previous]
				row.cost = int(lab.node_cost)
				row.cards = int(lab.node_cards)
				row.card_rule = "single_winner_without_replacement"
				row.effects = {"max_hp:flat":int(lab.node_bonus_hp)}
				previous = row.id
	rng.randomize()

func empty_state() -> Dictionary:
	var result: Dictionary = fresh()
	if development: result["profile"] = "development"
	return result

func configure(host: Node) -> void:
	world = host
	travel.configure(self)
	combat.configure(self)
	history.configure(self)
	_rebuild()

func seed_lab() -> void:
	if not development: return
	state.points = int(lab.initial_points)
	for material: String in ["수호석","문양 초기화 두루마리","축복의 성수(중)"]:
		world.inventory[material] = int(lab.initial_material_count)
	world.inventory["축복의 열쇠"] = 5000

func cost_for(id: String, attempt: int) -> Variant:
	if development:
		var costs: Array = lab.costs_shilen if id == "shilen" else lab.costs_advanced if id in ["grankain","einhasad"] else lab.enhancement_costs
		return costs[attempt]
	var configured: Variant = config.enhancement_costs[attempt]
	return configured if configured != null else emblem(id).get("verified_costs",{}).get(str(attempt+1))

func emblem(id: String) -> Dictionary:
	for row: Dictionary in config.get("emblems",[]):
		if row.id == id: return row
	return {}

func node(id: String) -> Dictionary:
	for group: Dictionary in config.get("guardians",[]):
		for row: Dictionary in group.nodes:
			if row.id == id: return row
	return {}

func progress(id: String) -> Dictionary:
	return state.emblems.get(id,{"stage":0,"attempts":0,"spent":0,"guaranteed":false,"absolute":0}).duplicate(true)

static func integer(value: Variant, low: int = 0, high: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func progress_error(id: String, p: Variant) -> String:
	if not p is Dictionary: return "문양 저장 구조 오류"
	if not integer(p.get("stage"),0,30) or not integer(p.get("attempts"),0,20) or not integer(p.get("spent")) or not p.get("guaranteed") is bool: return "문양 진행 값 오류"
	if not integer(p.get("absolute",0),0,5) or (p.get("absolute",0)>0 and p.stage!=30): return "절대 옵션 단계 오류"
	if not development and p.get("absolute",0)>0: return "미검증 절대 옵션 저장"
	var grades: Variant = p.get("absolute_grades",[])
	if not grades is Array: return "절대 옵션 개방 목록 오류"
	var seen_grades: Array = []
	for grade: Variant in grades:
		if not integer(grade,1,5) or seen_grades.has(int(grade)) or p.stage != 30: return "절대 옵션 개방 목록 오류"
		if source523.absolute(id,int(grade)).is_empty(): return "알 수 없는 절대 옵션"
		seen_grades.append(int(grade))
	# The official Symbol guide confirms sequential activation; source
	# definitions alone did not. Preserve owned unsupported rewards as data.
	for grade: int in seen_grades:
		for prerequisite: int in range(1,grade):
			if not seen_grades.has(prerequisite): return "절대 옵션 선행 등급 누락"
	if p.stage < p.attempts or p.stage > p.attempts*3: return "문양 단계/횟수 불일치"
	return ""

func validate(value: Variant) -> String:
	if not value is Dictionary: return "성장 저장 형식 오류"
	if value.get("profile","verified") != ("development" if development else "verified"): return "일반/개발용 성장 저장을 혼용할 수 없습니다"
	if value.get("schema") != 1: return "지원하지 않는 성장 저장 버전"
	for key: String in ["points","revision"]:
		if not integer(value.get(key)): return "성장 저장 숫자 오류"
	if not value.get("emblems") is Dictionary or not value.get("nodes") is Array or not value.get("pending") is Dictionary or not value.get("searches") is Dictionary: return "성장 저장 구조 오류"
	for id: Variant in value.emblems:
		if not id is String or emblem(id).is_empty(): return "알 수 없는 문양 저장"
		var problem: String = progress_error(id,value.emblems[id])
		if not problem.is_empty(): return problem
	var history_error: String = history.validate(value)
	if not history_error.is_empty(): return history_error
	if not value.get("economy",{}) is Dictionary: return "성장 재화 이력 오류"
	var travel_error: String=Travel.validate(value.get("teleport_bookmarks",[]))
	if not travel_error.is_empty(): return travel_error
	for amount: Variant in value.get("economy",{}).values():
		if not integer(amount): return "성장 재화 이력 오류"
	var unique: Array = []
	for id: Variant in value.nodes:
		if not id is String or node(id).is_empty() or unique.has(id): return "수호성 슬롯 저장 오류"
		unique.append(id)
	if not value.get("representative") is String or (not value.representative.is_empty() and not value.nodes.has(value.representative)): return "대표 수호성 저장 오류"
	for id: Variant in value.searches:
		var search: Variant = value.searches[id]
		if not id is String or node(id).is_empty() or not search is Dictionary: return "수호성 시도 이력 오류"
		if not integer(search.get("cards"),2,100) or not integer(search.get("winner"),0,int(search.cards)-1) or not integer(search.get("attempts")) or not search.get("failed") is Array: return "수호성 카드 이력 오류"
		var seen: Array = []
		for card: Variant in search.failed:
			if not integer(card,0,int(search.cards)-1) or card == search.winner or seen.has(card): return "수호성 실패 카드 오류"
			seen.append(card)
	var pending: Dictionary = value.pending
	if not pending.is_empty():
		if not pending.get("node") is String or node(pending.node).is_empty() or value.nodes.has(pending.node) or not integer(pending.get("cards"),2,100) or not value.searches.has(pending.node) or pending.cards != value.searches[pending.node].cards: return "수호성 선택 저장 오류"
	return ""

func restore(value: Dictionary) -> void:
	state = value.duplicate(true)
	combat.last_hit_ms=-1
	# JSON numbers are floats; Array.has uses strict type identity in Godot.
	# Normalize card IDs so reloading cannot make a failed card selectable again.
	for search: Dictionary in state.searches.values():
		var failed: Array = []
		for card: Variant in search.failed: failed.append(int(card))
		search.failed = failed
	for p: Dictionary in state.emblems.values():
		var grades: Array = []
		for grade: Variant in p.get("absolute_grades",[]): grades.append(int(grade))
		if p.has("absolute_grades"): p.absolute_grades = grades
	rerolls.clear()
	_rebuild()

func _rebuild() -> void:
	totals.clear()
	for id: String in state.emblems:
		_add_effects(emblem(id).get("effects",[])[int(progress(id).stage)])
		if development: totals["max_hp:flat"] = float(totals.get("max_hp:flat",0))+5*int(progress(id).get("absolute",0))
		else: _add_effects(source523.absolute_effects(id,progress(id).get("absolute_grades",[])))
	# Official guide: only the representative guardian's option effects apply.
	var representative: String = str(state.representative)
	if not representative.is_empty():
		for group: Dictionary in config.get("guardians",[]):
			var belongs: bool = false
			for row: Dictionary in group.nodes:
				if row.id == representative: belongs = true
			if belongs:
				for row: Dictionary in group.nodes:
					if state.nodes.has(row.id) and row.get("effects") is Dictionary: _add_effects(row.effects)

func _add_effects(effects: Dictionary) -> void:
	for key: String in effects:
		if key.begins_with("local_"):
			if Combat.estimates(): totals[key]=float(totals.get(key,0))+float(effects[key])
			continue
		if key in Stats.SUPPORTED or key in ["potion_flat:flat","potion_percent:percent","potion_cooldown:percent","blessing_consumption:percent","incoming_reduction:percent","mp_regeneration:flat","blessing_charge:percent","magic_heal:percent","hp_drain:flat","life:flat","critical_reduction:flat","stunned_reduction:flat","low_hp_reduction:percent","fear_resistance:percent","teleport_control:flag","pve_damage_reduction:percent"]:
			totals[key] = float(totals.get(key,0))+float(effects[key])
		elif key in ["veil_proc:percent","melee_reduction_ignore:flat","ranged_reduction_ignore:flat","magic_reduction_ignore:flat","pve_reduction_ignore:flat","melee_evasion_ignore:flat","ranged_evasion_ignore:flat"]:
			totals[key] = float(totals.get(key,0))+float(effects[key])

func bonus(key: String) -> float:
	var additional: float = world.growth96.bonus(key) if is_instance_valid(world) and world.get("growth96") != null else 0.0
	return float(totals.get(key,0)) + additional

func catalog_bonus(key: String) -> int:
	if key == "potionHealFlat": return int(bonus("potion_flat:flat"))
	if key == "potionHealPct": return int(bonus("potion_percent:percent"))
	if key == "pve_damage_reduction_pct": return int(bonus("pve_damage_reduction:percent"))
	if key == "damage_reduction_ignore": return int(bonus("pve_reduction_ignore:flat"))
	return Stats.catalog_bonus(totals,key)

func stat_record() -> Dictionary:
	var record: Dictionary = Stats.record(totals)
	record["blessing_consumption_reduction_pct"] = bonus("blessing_consumption:percent")
	record["fear_resistance"] = bonus("fear_resistance:percent")
	return record

func probabilities(id: String) -> Array:
	var p: Dictionary = progress(id)
	if p.guaranteed: return [0.0,0.0,100.0]
	if rerolls.has(id): return rerolls[id].duplicate()
	return config.probabilities_by_target_stage[mini(29,int(p.stage))].duplicate()

func fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func quote(action: String, id: String = "", count: int = 1) -> Dictionary:
	if config.is_empty(): return fail("성장 설정을 읽을 수 없습니다")
	if world == null: return fail("월드 연결 없음")
	var costs: Dictionary = {}
	var points: int = 0
	var text: String = ""
	var consume_instance: String = ""
	var transaction_day: int = -1
	if action in ["save_emblem","restore_emblem"]:
		var offer: Dictionary=history.quote(action,id)
		if offer.ok and int(offer.points)>int(state.points):return fail("축복 포인트 부족 · 필요 %d / 보유 %d" % [int(offer.points),int(state.points)])
		return offer
	match action:
		"enhance":
			if emblem(id).is_empty() or count not in [1,5]: return fail("잘못된 강화 요청")
			var p: Dictionary = progress(id)
			if p.stage >= 30 or p.attempts+count > 20: return fail("30단계 또는 20회 강화 한도")
			for i: int in range(int(p.attempts),int(p.attempts)+count):
				var cost: Variant = cost_for(id,i)
				if not integer(cost,1): return fail("%d회차 강화 비용 미확인 · 강화 보류" % (i+1))
				points += int(cost)
			text = "문양 강화 %d회 · 최대 %d 축복 포인트\n30단계 도달 시 종료, 미사용 비용은 차감하지 않습니다." % [count,points]
		"reroll":
			if emblem(id).is_empty() or progress(id).stage >= 30 or progress(id).attempts >= 20 or progress(id).guaranteed: return fail("확률 변경 불가")
			if not integer(config.get("reroll_cost"),1): return fail("확률 변경 비용 미확인")
			if not development and source523.probability_rows(int(progress(id).stage)).is_empty(): return fail("원본 확률 범위 없음")
			points = int(config.reroll_cost)
			text = "확률 변경 · 축복 포인트 %d (초기화 환급 제외)" % points
		"reset":
			if emblem(id).is_empty() or progress(id).attempts == 0: return fail("초기화할 강화 기록이 없습니다")
			if progress(id).stage >= 30: return fail("완성한 30단계 문양은 초기화할 수 없습니다")
			if not integer(config.get("reset_cost"),1): return fail("초기화 두루마리 필요 수량 미확인 · 초기화 보류")
			if development: costs["문양 초기화 두루마리"] = int(config.reset_cost)
			else:
				for instance_id: String in world.item_instances:
					var instance: Dictionary = world.item_instances[instance_id]
					if source523.reset_material(instance) and int(world.inventory.get(str(instance.name),0))>0:
						consume_instance = instance_id
						costs[str(instance.name)] = 1
						break
				if consume_instance.is_empty(): return fail("원본 ID가 확인된 기간 없는 문양 초기화 두루마리가 필요합니다")
			text = "초기화 · 강화 포인트 %d 환급, 확률 변경 비용 제외" % int(progress(id).spent)
			if not development:
				var daily: Dictionary=history.daily_offer(id)
				if not daily.ok:return daily
				transaction_day=int(daily.day)
				text+="\n자체 일일 한도 · 문양별 %d/%s회 · 기존 게임05시 기준" % [int(daily.used),str(daily.limit) if int(daily.limit)>0 else "무제한"]
		"buy_key":
			points = int(config.blessing_key_point_cost)
			text = "축복의 열쇠 1개 · 1,000 축복 포인트 (상점 지출은 강화 환급 제외)"
		"absolute", "absolute_chance":
			if emblem(id).is_empty() or progress(id).stage<30: return fail("30단계 문양이 필요합니다")
			if development:
				var tier: int = int(progress(id).get("absolute",0))
				if tier>=5: return fail("절대 옵션 V 달성")
				costs["축복의 열쇠"] = int(emblem(id).absolute_key_costs[tier])
				text = "절대 옵션 %d 확정 · 열쇠 %d개\n개발용 효과: HP +5 / 원작 효과 아님" % [tier+1,int(costs["축복의 열쇠"])]
			else:
				if count not in [1,2,3,4,5]: return fail("절대 옵션 등급 오류")
				if progress(id).get("absolute_grades",[]).has(count): return fail("이미 개방한 절대 옵션")
				# Same official sequential requirement for point and key routes.
				for prerequisite: int in range(1,count):
					if not progress(id).get("absolute_grades",[]).has(prerequisite): return fail("절대 옵션 %d을 먼저 개방하세요" % prerequisite)
				var block: String = source523.absolute_block(id,count)
				if not block.is_empty(): return fail(block)
				var payment: Dictionary = source523.absolute(id,count).payment
				if action == "absolute": costs["축복의 열쇠"] = int(payment.ForceOpenCost)
				else: points = int(payment.OpenCost)
				text = "절대 옵션 %d · %s\n확률 강화 비용은 일반 강화 초기화 환급에 포함되지 않습니다." % [count,"열쇠 %d개 확정" % int(payment.ForceOpenCost) if action == "absolute" else "%d 축복 포인트 · 성공률 %.1f%%" % [points,float(payment.OpenProbability)/10000.0]]
		"recharge":
			var instance: Dictionary = world.item_instances.get(id,{}) if world != null else {}
			var definition: Dictionary = source523.recharge(instance)
			if definition.is_empty(): return fail("충전 아이템의 원본 식별·사용 조건을 확인할 수 없습니다")
			costs[definition.name] = 1
			consume_instance = id
			text = "%s 1개 → 축복 포인트 %d" % [str(definition.name),int(definition.amount)]
		"holy_water":
			if not development: return fail("원본 충전 아이템을 인벤토리에서 선택하세요 · 이름만으로 이관하지 않습니다")
			costs["축복의 성수(중)"] = 1
			text = "축복의 성수(중) 1개 → 축복 포인트 100"
		"craft_stone", "craft_stone_engraved":
			costs["축복 부여 주문서" if action == "craft_stone" else "축복 부여 주문서(각인)"] = 2
			costs["마력의 돌"] = 100
			text = "수호석 1개 제작 · 축복 부여 주문서 2장 + 마력의 돌 100개"
		"activate":
			var row: Dictionary = node(id)
			if row.is_empty(): return fail("알 수 없는 슬롯")
			if not state.pending.is_empty(): return fail("진행 중인 카드 선택을 먼저 완료하세요")
			if state.nodes.has(id): return fail("이미 열린 슬롯")
			if not row.get("prerequisites") is Array or not integer(row.get("cost"),1) or not integer(row.get("cards"),2,100) or row.get("card_rule") != "single_winner_without_replacement" or not row.get("effects") is Dictionary: return fail("선행 슬롯·비용·카드 수·선택 규칙·효과 미확인 · 활성화 보류")
			for prerequisite: String in row.prerequisites:
				if not state.nodes.has(prerequisite): return fail("선행 슬롯 미개방: "+prerequisite)
			costs["수호석"] = int(row.cost)
			var failed: Array = state.searches.get(id,{}).get("failed",[])
			text = "수호석 %d개 · 남은 카드 %d장\n실패 카드는 제거되며 매 시도 재료를 소모합니다." % [int(row.cost),int(row.cards)-failed.size()]
		"choose":
			if state.pending.is_empty() or count < 0 or count >= int(state.pending.cards): return fail("유효하지 않은 카드 선택")
			if state.searches[state.pending.node].failed.has(count): return fail("이미 실패한 카드입니다")
			text = "선택한 카드 결과 확인"
		"representative":
			if not state.nodes.has(id) or node(id).get("kind") == "stat": return fail("개방된 스킬 슬롯을 선택하세요")
			if state.representative == id: return fail("이미 대표로 설정됨")
			# Unknown official cooldown must not be silently turned into free repeated switching.
			if not state.representative.is_empty() and config.get("guardian_switch_seconds") == null: return fail("대표 변경 대기시간 미확인 · 변경 보류")
			text = "대표 수호성 설정 · 미확인 스킬 피해/회복량은 발동하지 않습니다."
		_: return fail("지원하지 않는 요청")
	if world == null: return fail("월드 연결 없음")
	if points > int(state.points): return fail("축복 포인트 부족 · 필요 %d / 보유 %d" % [points,int(state.points)])
	for item: String in costs:
		if int(world.inventory.get(item,0)) < int(costs[item]): return fail("%s 부족 · 필요 %d / 보유 %d" % [item,int(costs[item]),int(world.inventory.get(item,0))])
	return {"ok":true,"message":text,"costs":costs,"points":points,"revision":state.revision,"consume_instance":consume_instance,"day":transaction_day}

func execute(action: String, id: String, count: int, revision: int, quote_day: int = -1) -> Dictionary:
	if busy or revision != int(state.revision): return fail("중복 또는 오래된 요청 · 다시 확인하세요")
	var offer: Dictionary = quote(action,id,count)
	if not offer.ok: return offer
	if quote_day>=0 and int(offer.get("day",-1))!=quote_day:return fail("게임 일자가 바뀌었습니다 · 비용과 횟수를 다시 확인하세요")
	busy = true
	var next: Dictionary = state.duplicate(true)
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true) if not str(offer.consume_instance).is_empty() else {}
	for item: String in offer.costs:
		inventory[item] = int(inventory.get(item,0))-int(offer.costs[item])
	var message: String = "완료"
	var rolled: Array = []
	match action:
		"enhance":
			var p: Dictionary = progress(id)
			var jumps: Array = []
			for i: int in range(count):
				if p.stage >= 30: break
				var odds: Array = probabilities(id) if count == 1 else config.probabilities_by_target_stage[mini(29,int(p.stage))].duplicate()
				if p.guaranteed: odds = [0.0,0.0,100.0]
				var roll: float = rng.randf()*100.0
				var jump: int = 1 if roll < float(odds[0]) else 2 if roll < float(odds[0])+float(odds[1]) else 3
				var cost: int = int(cost_for(id,int(p.attempts)))
				var previous_stage: int = int(p.stage)
				p.stage = mini(30,int(p.stage)+jump)
				p.attempts += 1
				p.spent += cost
				next.points -= cost
				# Preserve TWILIGHT's existing event order, but never invent a 1%
				# route where the actual source stage explicitly supplies zero.
				var special: float = 0.01 if development else source523.special_rate(previous_stage,jump)
				p.guaranteed = jump >= 2 and rng.randf() < special
				_ledger(next,"enhancement_spent",cost)
				jumps.append(jump)
			next.emblems[id] = p
			message = "강화 결과 %s → %d단계 (%d/20회)" % [str(jumps),int(p.stage),int(p.attempts)]
		"reroll":
			var base: Array = config.probabilities_by_target_stage[mini(29,int(progress(id).stage))]
			var two: float = maxf(0,float(base[1])+float(rng.randi_range(-10,10))/10.0)
			var three: float = maxf(0,float(base[2])+float(rng.randi_range(-10,10))/10.0)
			if not development:
				# Explicit local sampler: inclusive 0.1 percentage-point grid.
				# This derives candidate counts from each row; no fixed 21.
				two = 0.0; three = 0.0
				for row: Dictionary in source523.probability_rows(int(progress(id).stage)):
					var delta: int = int(row.DeltaEnchant)
					if delta not in [2,3]: continue
					var candidates: int = int((int(row.MaxProbability)-int(row.MinProbability))/1000)
					var chance: float = float(int(row.MinProbability)+rng.randi_range(0,candidates)*1000)/10000.0
					if delta == 2: two = chance
					else: three = chance
			rolled = [100.0-two-three,two,three]
			next.points -= int(offer.points)
			_ledger(next,"probability_spent",int(offer.points))
			message = "확률 변경 완료 · 문양 화면을 닫으면 기본 확률로 복귀"
		"save_emblem", "restore_emblem":
			message=history.stage(next,action,id,offer)
		"reset":
			if not development:history.stage_day(next,id,int(offer.day),true)
			next.points += int(progress(id).spent)
			_ledger(next,"refunded",int(progress(id).spent))
			next.emblems.erase(id)
			if not str(offer.consume_instance).is_empty(): instances.erase(str(offer.consume_instance))
			message = "강화 초기화 · 사용한 강화 포인트 환급 완료"
		"buy_key":
			next.points -= int(offer.points)
			_ledger(next,"shop_spent",int(offer.points))
			inventory["축복의 열쇠"] = int(inventory.get("축복의 열쇠",0))+1
		"absolute", "absolute_chance":
			var p: Dictionary = progress(id)
			if development:
				p.absolute = int(p.get("absolute",0))+1
				message = "개발용 절대 옵션 %d · HP +5 (원작 효과 아님)" % p.absolute
			else:
				next.points -= int(offer.points)
				_ledger(next,"absolute_spent",int(offer.points))
				var success: bool = action == "absolute" or rng.randf()*1000000.0 < float(source523.absolute(id,count).payment.OpenProbability)
				if success:
					var grades: Array = p.get("absolute_grades",[]).duplicate()
					grades.append(count)
					p["absolute_grades"] = grades
				message = "절대 옵션 %d 개방" % count if success else "절대 옵션 강화 실패"
			next.emblems[id] = p
		"holy_water":
			next.points += 100
			_ledger(next,"recharged",100)
		"recharge":
			var definition: Dictionary = source523.recharge(instances[id])
			next.points += int(definition.amount)
			_ledger(next,"recharged",int(definition.amount))
			instances.erase(id)
		"craft_stone", "craft_stone_engraved": inventory["수호석"] = int(inventory.get("수호석",0))+1
		"activate":
			var row: Dictionary = node(id)
			if not next.searches.has(id):
				next.searches[id] = {"cards":int(row.cards),"winner":rng.randi_range(0,int(row.cards)-1),"failed":[],"attempts":0}
			next.searches[id].attempts += 1
			next.pending = {"node":id,"cards":int(row.cards)}
			message = "카드를 선택하세요 · 선택 대기 상태 저장됨"
		"choose":
			var search: Dictionary = next.searches[next.pending.node]
			var won: bool = count == int(search.winner)
			if won: next.nodes.append(str(next.pending.node))
			else: search.failed.append(count)
			message = "수호성 찾기 성공 · 슬롯 개방" if won else "수호성 찾기 실패 · 다시 도전할 수 있습니다"
			next.pending = {}
		"representative": next.representative = id
	next.revision += 1
	if not validate(next).is_empty():
		busy = false
		return fail("성장 상태 검증 실패")
	var overrides: Dictionary = {"inventory":inventory,"growth":next}
	if not str(offer.consume_instance).is_empty(): overrides["item_instances"] = instances
	var error: Error = world._save_game(true,overrides)
	if error != OK:
		busy = false
		return fail("저장 실패 · 재료와 성장 상태를 변경하지 않았습니다 (%d)" % error)
	state = next
	world.inventory = inventory
	if not str(offer.consume_instance).is_empty(): world.item_instances = instances
	if action == "reroll": rerolls[id] = rolled
	elif action in ["enhance","reset","restore_emblem"]: rerolls.erase(id)
	_rebuild()
	world._invalidate_equipment_static()
	world.hp = mini(world.hp,world._effective_max_hp())
	world.mp = mini(world.mp,world._effective_max_mp())
	world._update_hud()
	busy = false
	return {"ok":true,"message":message}

func _ledger(next: Dictionary, key: String, amount: int) -> void:
	if not next.has("economy"): next["economy"] = {}
	next.economy[key] = int(next.economy.get(key,0))+amount

func magic_healing(amount: int) -> int:
	return maxi(0,int(round(float(amount)*(1.0+bonus("magic_heal:percent")/100.0))))

func incoming_damage(damage: int, critical: bool = false, stunned: bool = false, hp_before: int = -1, maximum_hp: int = -1, context: Dictionary = {}) -> int:
	var flat: int = int(bonus("critical_reduction:flat")) if critical else 0
	if stunned: flat += int(bonus("stunned_reduction:flat"))
	var percent: float = bonus("incoming_reduction:percent")
	# IntervalBonus42/category12 plus the official guide: HP<=30%, not
	# regeneration. Compare exact proportions, never floor 30.9% into range.
	if maximum_hp>0 and hp_before>=0 and hp_before*100<=maximum_hp*30:
		percent += bonus("low_hp_reduction:percent")
	return combat.incoming(damage,flat,percent,context)
