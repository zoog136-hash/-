extends RefCounted
## Local single-save progression. Unknown source values fail closed, never become zero costs.
const Stats = preload("res://scripts/collections/equipment_collection_stats.gd")
const DATA = "res://data/growth/lineage_growth.json"
const GuardianSource = preload("res://scripts/growth/guardian_source.gd")
var guardian_source = GuardianSource.new()
var legacy_guardians: Array = []
const Combat=preload("res://scripts/growth/guardian_combat.gd")
var combat=Combat.new()
var guardian_local_rules: Dictionary={}
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
	guardian_local_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/guardian_local_rules.json"))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is Dictionary: config = parsed
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
	else:
		legacy_guardians = config.get("guardians",[]).duplicate(true)
		config.guardians = guardian_source.data.get("guardians",[])
	combat.configure(self)
	rng.randomize()

func empty_state() -> Dictionary:
	var result: Dictionary = fresh()
	if development: result["profile"] = "development"
	return result

func configure(host: Node) -> void:
	world = host
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
	# Preserve pre-523 save IDs without guessing a correspondence to source slots.
	for group: Dictionary in legacy_guardians:
		for row: Dictionary in group.nodes:
			if row.id == id: return row
	return {}

func progress(id: String) -> Dictionary:
	return state.emblems.get(id,{"stage":0,"attempts":0,"spent":0,"guaranteed":false,"absolute":0}).duplicate(true)

static func integer(value: Variant, low: int = 0, high: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func validate(value: Variant) -> String:
	if not value is Dictionary: return "성장 저장 형식 오류"
	if value.get("profile","verified") != ("development" if development else "verified"): return "일반/개발용 성장 저장을 혼용할 수 없습니다"
	if value.get("schema") != 1: return "지원하지 않는 성장 저장 버전"
	for key: String in ["points","revision"]:
		if not integer(value.get(key)): return "성장 저장 숫자 오류"
	if not value.get("emblems") is Dictionary or not value.get("nodes") is Array or not value.get("pending") is Dictionary or not value.get("searches") is Dictionary: return "성장 저장 구조 오류"
	for id: Variant in value.emblems:
		if not id is String or emblem(id).is_empty(): return "알 수 없는 문양 저장"
		var p: Variant = value.emblems[id]
		if not p is Dictionary: return "문양 저장 구조 오류"
		if not integer(p.get("stage"),0,30) or not integer(p.get("attempts"),0,20) or not integer(p.get("spent")) or not p.get("guaranteed") is bool: return "문양 진행 값 오류"
		if not integer(p.get("absolute",0),0,5) or (p.get("absolute",0)>0 and p.stage!=30): return "절대 옵션 단계 오류"
		if not development and p.get("absolute",0)>0: return "미검증 절대 옵션 저장"
		if p.stage < p.attempts or p.stage > p.attempts*3: return "문양 단계/횟수 불일치"
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
	var levels: Variant = value.get("guardian_levels",{})
	if not levels is Dictionary: return "수호성 강화 저장 오류"
	for id: Variant in levels:
		if not id is String or not guardian_source.has_node(id) or not value.nodes.has(id) or not integer(levels[id],0,int(node(id).max_level)): return "수호성 강화 단계 오류"
	var representatives: Variant = value.get("guardian_representatives",{})
	if not representatives is Dictionary: return "수호성 대표 저장 오류"
	for category: Variant in representatives:
		var id: Variant = representatives[category]
		if not category is String or not id is String or not guardian_source.has_node(id) or not value.nodes.has(id) or node(id).kind != "invoke" or category != str(int(node(id).category_id)): return "수호성 분류별 대표 오류"
	for id: String in value.nodes:
		if not guardian_source.has_node(id): continue
		for prerequisite: String in node(id).prerequisites:
			if not value.nodes.has(prerequisite): return "수호성 선행 저장 오류"
	for id: String in value.searches:
		if not guardian_source.has_node(id): continue
		var search: Dictionary = value.searches[id]
		if int(search.cards) != int(node(id).cards) or int(search.attempts) != search.failed.size() + (1 if value.nodes.has(id) else 0): return "수호성 원본 카드 이력 오류"
	for field: String in ["guardian_spent","guardian_wallet","guardian_enchant_attempts","guardian_switch_until","guardian_cast_until","guardian_legacy_refund_uncertain"]:
		if not value.get(field,{}) is Dictionary:return "수호성 거래 원장 오류"
		for key: Variant in value.get(field,{}):
			if not key is String:return "수호성 거래 식별자 오류"
			var amount: Variant=value[field][key]
			if field=="guardian_legacy_refund_uncertain":
				if not amount is bool:return "수호성 이전 원장 오류"
			elif field.ends_with("_until"):
				if not (amount is int or amount is float) or not is_finite(float(amount)) or amount<0 or amount>100000000000:return "수호성 대기시간 오류"
			elif not integer(amount):return "수호성 거래 금액 오류"
	var pending: Dictionary = value.pending
	if not pending.is_empty():
		if not pending.get("node") is String or node(pending.node).is_empty() or value.nodes.has(pending.node) or not integer(pending.get("cards"),2,100) or not value.searches.has(pending.node) or pending.cards != value.searches[pending.node].cards: return "수호성 선택 저장 오류"
	return ""

func restore(value: Dictionary) -> void:
	state = value.duplicate(true)
	# JSON numbers are floats; Array.has uses strict type identity in Godot.
	# Normalize card IDs so reloading cannot make a failed card selectable again.
	for search: Dictionary in state.searches.values():
		var failed: Array = []
		for card: Variant in search.failed: failed.append(int(card))
		search.failed = failed
	rerolls.clear()
	_rebuild()
	# Restored growth records must invalidate the host's cached stat records.
	if world != null:
		world._invalidate_equipment_static()
		if world.get("skill_cooldowns") is Dictionary:sync_guardian_cooldowns()

func _rebuild() -> void:
	totals.clear()
	for id: String in state.emblems:
		_add_effects(emblem(id).get("effects",[])[int(progress(id).stage)])
		if development: totals["max_hp:flat"] = float(totals.get("max_hp:flat",0))+5*int(progress(id).get("absolute",0))
	# 523 SKILLTREE_TOOLTIP PANEL_2: stats are always active; invoked skills
	# require a separate selection per category. Do not gate stats on that selection.
	if not development:
		for id: String in state.nodes:
			if guardian_source.has_node(id) and guardian_source.availability(node(id)).is_empty():
				_add_effects(guardian_source.effects(id,guardian_level(id)))
		return
	# Preserve the isolated development profile's existing behavior.
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
		if key in Stats.SUPPORTED or key in ["potion_flat:flat","potion_percent:percent","potion_cooldown:percent","blessing_consumption:percent","incoming_reduction:percent","mp_regeneration:flat","blessing_charge:percent"]:
			totals[key] = float(totals.get(key,0))+float(effects[key])

func guardian_group(id: String) -> Dictionary:
	for group: Dictionary in config.guardians:
		if group.id==id:return group
	return {}

func guardian_spent(category: int) -> int:
	var key: String=str(category)
	if state.get("guardian_spent",{}).has(key):return int(state.guardian_spent[key])
	var amount: int=0
	for id: String in guardian_source.nodes:
		var row: Dictionary=node(id)
		if int(row.category_id)!=category:continue
		amount+=int(state.searches.get(id,{}).get("attempts",0))*int(row.cost)
		for level: int in range(1,guardian_level(id)+1):amount+=int(guardian_source.upgrade(id,level).get("CurrencyCost",0))
	return amount # A lower bound; never invent unrecorded failed enchants.

func account_guardian(next: Dictionary,id: String,amount: int) -> void:
	var key: String=str(int(node(id).category_id))
	if not next.has("guardian_spent"):next.guardian_spent={}
	if not next.guardian_spent.has(key):
		if not next.has("guardian_legacy_refund_uncertain"):next.guardian_legacy_refund_uncertain={}
		var prior: bool=false
		for opened: String in state.nodes:
			if guardian_source.has_node(opened) and int(node(opened).category_id)==int(node(id).category_id):prior=true
		next.guardian_legacy_refund_uncertain[key]=prior
	next.guardian_spent[key]=guardian_spent(int(node(id).category_id))+amount

func guardian_refund(category: int) -> int:
	return int(floor(guardian_spent(category)*clampf(float(guardian_local_rules.get("reset",{}).get("refund_rate",1.0)),0,1)))

func guardian_level(id: String) -> int:
	return int(state.get("guardian_levels",{}).get(id,0))

func guardian_rewards(id: String) -> Array:
	return guardian_source.rewards(id,guardian_level(id)) if guardian_source.has_node(id) else []

func guardian_representative(category: int) -> String:
	return str(state.get("guardian_representatives",{}).get(str(category),""))

func bonus(key: String) -> float:
	return float(totals.get(key,0))

func catalog_bonus(key: String) -> int:
	if key == "potionHealFlat": return int(bonus("potion_flat:flat"))
	if key == "potionHealPct": return int(bonus("potion_percent:percent"))
	return Stats.catalog_bonus(totals,key)

func stat_record() -> Dictionary:
	var record: Dictionary = Stats.record(totals)
	record["blessing_consumption_reduction_pct"] = bonus("blessing_consumption:percent")
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
	var costs: Dictionary = {}
	var points: int = 0
	var gold_cost: int=0
	var debug_gem_cost: int=0
	var text: String = ""
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
			var base_odds: Array = config.probabilities_by_target_stage[mini(29,int(progress(id).stage))]
			if float(base_odds[1]) < 1.0 or float(base_odds[2]) < 1.0: return fail("확률 변경 경계값 처리 미확인 · 변경 보류")
			points = int(config.reroll_cost)
			text = "확률 변경 · 축복 포인트 %d (초기화 환급 제외)" % points
		"reset":
			if emblem(id).is_empty() or progress(id).attempts == 0: return fail("초기화할 강화 기록이 없습니다")
			if not integer(config.get("reset_cost"),1): return fail("초기화 두루마리 필요 수량 미확인 · 초기화 보류")
			costs["문양 초기화 두루마리"] = int(config.reset_cost)
			text = "초기화 · 강화 포인트 %d 환급, 확률 변경 비용 제외" % int(progress(id).spent)
		"buy_key":
			points = int(config.blessing_key_point_cost)
			text = "축복의 열쇠 1개 · 1,000 축복 포인트 (절대 옵션은 개발 모드에서만 검증 가능)"
		"absolute":
			if emblem(id).is_empty() or progress(id).stage<30: return fail("30단계 문양이 필요합니다")
			if not development: return fail("전체 절대 옵션 효과/초기화 규칙 미확인 · 일반 플레이 잠금")
			var tier: int = int(progress(id).get("absolute",0))
			if tier>=5: return fail("절대 옵션 V 달성")
			costs["축복의 열쇠"] = int(emblem(id).absolute_key_costs[tier])
			text = "절대 옵션 %d 확정 · 열쇠 %d개\n개발용 효과: HP +5 / 원작 효과 아님" % [tier+1,int(costs["축복의 열쇠"])]
		"holy_water":
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
			if guardian_source.has_node(id):
				var blocked: String = guardian_source.availability(row)
				if not blocked.is_empty(): return fail(blocked)
			else: costs["수호석"] = int(row.cost)
			var failed: Array = state.searches.get(id,{}).get("failed",[])
			text = ("수호석 %d개 · 남은 카드 %d장\n카드 선택 시 매 시도 재료를 소모합니다." if guardian_source.has_node(id) else "수호석 %d개 · 남은 카드 %d장\n실패 카드는 제거되며 매 시도 재료를 소모합니다.") % [int(row.cost),int(row.cards)-failed.size()]
			# Quote affordability now; actual source payment occurs on choose.
			if world != null and guardian_source.has_node(id) and int(world.inventory.get("수호석",0)) < int(row.cost): return fail("수호석 부족 · 필요 %d" % int(row.cost))
		"choose":
			if state.pending.is_empty() or count < 0 or count >= int(state.pending.cards): return fail("유효하지 않은 카드 선택")
			if state.searches[state.pending.node].failed.has(count): return fail("이미 실패한 카드입니다")
			var pending_id: String = str(state.pending.node)
			if guardian_source.has_node(pending_id):
				var blocked: String = guardian_source.availability(node(pending_id))
				if not blocked.is_empty(): return fail(blocked)
				costs["수호석"] = int(node(pending_id).cost)
			text = "수호석 %d개 소모 · 선택한 카드 결과 확인" % int(costs["수호석"]) if costs.has("수호석") else "선택한 카드 결과 확인"
		"guardian_enchant":
			if not guardian_source.has_node(id) or not state.nodes.has(id): return fail("개방된 원본 슬롯이 필요합니다")
			if not state.pending.is_empty(): return fail("진행 중인 카드 선택을 먼저 완료하세요")
			var row: Dictionary = node(id)
			var blocked: String = guardian_source.availability(row)
			if not blocked.is_empty(): return fail(blocked)
			var upgrade: Dictionary = guardian_source.upgrade(id,guardian_level(id)+1)
			if upgrade.is_empty(): return fail("강화할 수 없는 슬롯 또는 최대 단계")
			if int(upgrade.CurrencyID) != 822 or not integer(upgrade.CurrencyCost,1) or not integer(upgrade.Probability,0,1000000): return fail("강화 통화·확률 확인 필요")
			costs["수호석"] = int(upgrade.CurrencyCost)
			text = "수호성 Lv.%d → %d · 수호석 %d개 · 성공률 %.2f%%\n실패 시 재료만 소모하며 단계는 유지됩니다. 강화 단계의 효과로 교체됩니다." % [guardian_level(id),guardian_level(id)+1,int(upgrade.CurrencyCost),float(upgrade.Probability)/10000.0]
		"guardian_cast":
			if not guardian_source.has_node(id) or not state.nodes.has(id) or node(id).kind!="active":return fail("개방된 사용 스킬이 필요합니다")
			var blocked: String=guardian_source.availability(node(id))
			if not blocked.is_empty():return fail(blocked)
			if world==null or world.hp<=0:return fail("살아 있을 때 사용할 수 있습니다")
			var reward: Dictionary=guardian_rewards(id)[0]
			var spell: Dictionary=combat.profile(int(reward.spell.ID))
			if not combat.spell_allowed(int(reward.spell.ID),combat.current_groups()):return fail("현재 지역에서 사용할 수 없는 스킬")
			var remaining: float=float(state.get("guardian_cast_until",{}).get(str(int(reward.spell.CastGroupID)),0))-Time.get_unix_time_from_system()
			if remaining>0:return fail("재사용까지 %d초" % ceili(remaining))
			if world.hp>=world._effective_max_hp() and world.mp>=world._effective_max_mp():return fail("HP/MP가 가득 찼습니다")
			costs["명예 코인"]=int(reward.spell.SpellMaterialItemAmount)
			text="%s · 명예 코인 %d개 · HP %d / MP %d 회복" % [str(node(id).name),int(costs["명예 코인"]),int(spell.values.get("HPRestoration",0)),int(spell.values.get("MPRestoration",0))]
		"guardian_buy_coins":
			if world==null:return fail("월드 연결 없음")
			var prices: Dictionary=world.original_skills.catalog.current_official.local_design.get("reagent_prices",{})
			var price: int=int(prices.get("명예 코인",0))
			if price<=0:return fail("현재 게임의 재료 상점 가격을 확인할 수 없습니다")
			gold_cost=10*price
			if world.gold<gold_cost:return fail("아데나 부족 · 필요 %d" % gold_cost)
			text="명예 코인 10개 · %d 아데나 (TWILIGHT 재료 상점 가격)" % gold_cost
		"guardian_debug_gems":
			if not OS.is_debug_build():return fail("개발 빌드 전용 검증 재화")
			text="검증용 다이아 %d 추가 · 개발 편의 기능" % int(guardian_local_rules.development.gem_grant)
		"guardian_reset":
			var group: Dictionary=guardian_group(id)
			if group.is_empty():return fail("알 수 없는 수호성 분류")
			if not state.pending.is_empty():return fail("카드 선택을 먼저 완료하세요")
			if not guardian_source.availability(group).is_empty():return fail("서버별 제공 조건 확인 중")
			if guardian_spent(int(group.category_id))==0:return fail("초기화할 비용 기록이 없습니다")
			var price: int=int(guardian_source.constant("InitializeCost"))
			if price<=0:return fail("원본 초기화 비용 오류")
			var earned: int=maxi(0,int(world.inventory.get("다이아",0)))
			debug_gem_cost=maxi(0,price-earned)
			var debug_balance: int=int(state.get("guardian_wallet",{}).get("4",0)) if OS.is_debug_build() else 0
			if debug_gem_cost>debug_balance:return fail("다이아 부족 · 필요 %d / 게임 보유 %d" % [price,earned])
			if price>debug_gem_cost:costs["다이아"]=price-debug_gem_cost
			text="%s 분류 초기화 · 다이아 %d · 기록으로 확인되는 수호석 %d개 환급\n이 분류의 개방/강화를 초기화합니다. 재사용 대기시간 유지 · 분류/환급 범위는 TWILIGHT 자체 설정입니다." % [str(group.name),price,guardian_refund(int(group.category_id))]
			if debug_gem_cost>0:text+="\n개발 검증 다이아 %d 사용 · 출시 재화와 별도" % debug_gem_cost
			if not state.get("guardian_spent",{}).has(str(int(group.category_id))) or bool(state.get("guardian_legacy_refund_uncertain",{}).get(str(int(group.category_id)),false)):text+="\n이전 버전의 실패 강화 비용은 기록이 없어 환급액에 포함할 수 없습니다."
		"representative":
			if not state.nodes.has(id) or node(id).get("kind") == "stat": return fail("개방된 스킬 슬롯을 선택하세요")
			if guardian_source.has_node(id):
				if node(id).kind != "invoke": return fail("발동 스킬 슬롯을 선택하세요 · 능력치는 상시 적용됩니다")
				var blocked: String = guardian_source.availability(node(id))
				if not blocked.is_empty(): return fail(blocked)
				var current: String = guardian_representative(int(node(id).category_id))
				if current == id: return fail("이미 분류 대표로 설정됨")
				var remaining: float=float(state.get("guardian_switch_until",{}).get(str(int(node(id).category_id)),0))-Time.get_unix_time_from_system()
				if remaining>0:return fail("분류 대표 변경까지 %d초" % ceili(remaining))
				text = "분류별 발동 스킬 지정 · 변경 대기 %d초" % int(guardian_source.constant("CoolTimeSec"))
			else:
				if state.representative == id: return fail("이미 대표로 설정됨")
				# Unknown official cooldown must not be silently turned into free repeated switching.
				if not state.representative.is_empty() and config.get("guardian_switch_seconds") == null: return fail("대표 변경 대기시간 미확인 · 변경 보류")
				text = "대표 수호성 설정 · 미확인 스킬 피해/회복량은 발동하지 않습니다."
		_: return fail("지원하지 않는 요청")
	if world == null: return fail("월드 연결 없음")
	if points > int(state.points): return fail("축복 포인트 부족 · 필요 %d / 보유 %d" % [points,int(state.points)])
	for item: String in costs:
		if int(world.inventory.get(item,0)) < int(costs[item]): return fail("%s 부족 · 필요 %d / 보유 %d" % [item,int(costs[item]),int(world.inventory.get(item,0))])
	return {"ok":true,"message":text,"costs":costs,"points":points,"revision":state.revision,"gold_cost":gold_cost,"debug_gem_cost":debug_gem_cost}

func execute(action: String, id: String, count: int, revision: int) -> Dictionary:
	if busy or revision != int(state.revision): return fail("중복 또는 오래된 요청 · 다시 확인하세요")
	var offer: Dictionary = quote(action,id,count)
	if not offer.ok: return offer
	busy = true
	var next: Dictionary = state.duplicate(true)
	var inventory: Dictionary = world.inventory.duplicate(true)
	for item: String in offer.costs:
		inventory[item] = int(inventory.get(item,0))-int(offer.costs[item])
	var vital: Dictionary={}
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
				p.stage = mini(30,int(p.stage)+jump)
				p.attempts += 1
				p.spent += cost
				next.points -= cost
				p.guaranteed = jump >= 2 and rng.randf() < 0.01
				jumps.append(jump)
			next.emblems[id] = p
			message = "강화 결과 %s → %d단계 (%d/20회)" % [str(jumps),int(p.stage),int(p.attempts)]
		"reroll":
			var base: Array = config.probabilities_by_target_stage[mini(29,int(progress(id).stage))]
			var two: float = maxf(0,float(base[1])+float(rng.randi_range(-10,10))/10.0)
			var three: float = maxf(0,float(base[2])+float(rng.randi_range(-10,10))/10.0)
			rolled = [100.0-two-three,two,three]
			next.points -= int(offer.points)
			message = "확률 변경 완료 · 문양 화면을 닫으면 기본 확률로 복귀"
		"reset":
			next.points += int(progress(id).spent)
			next.emblems.erase(id)
			message = "강화 초기화 · 사용한 강화 포인트 환급 완료"
		"buy_key":
			next.points -= int(offer.points)
			inventory["축복의 열쇠"] = int(inventory.get("축복의 열쇠",0))+1
		"absolute":
			var p: Dictionary = progress(id)
			p.absolute = int(p.get("absolute",0))+1
			next.emblems[id] = p
			message = "개발용 절대 옵션 %d · HP +5 (원작 효과 아님)" % p.absolute
		"holy_water": next.points += 100
		"craft_stone", "craft_stone_engraved": inventory["수호석"] = int(inventory.get("수호석",0))+1
		"activate":
			var row: Dictionary = node(id)
			if not next.searches.has(id):
				next.searches[id] = {"cards":int(row.cards),"winner":rng.randi_range(0,int(row.cards)-1),"failed":[],"attempts":0}
			if not guardian_source.has_node(id): next.searches[id].attempts += 1
			next.pending = {"node":id,"cards":int(row.cards)}
			message = "카드를 선택하세요 · 선택 대기 상태 저장됨"
		"choose":
			var search: Dictionary = next.searches[next.pending.node]
			if guardian_source.has_node(str(next.pending.node)):
				account_guardian(next,str(next.pending.node),int(node(str(next.pending.node)).cost))
				search.attempts += 1
			var won: bool = count == int(search.winner)
			if won: next.nodes.append(str(next.pending.node))
			else: search.failed.append(count)
			message = "수호성 찾기 성공 · 슬롯 개방" if won else "수호성 찾기 실패 · 다시 도전할 수 있습니다"
			next.pending = {}
		"guardian_enchant":
			var upgrade: Dictionary = guardian_source.upgrade(id,guardian_level(id)+1)
			account_guardian(next,id,int(upgrade.CurrencyCost))
			if not next.has("guardian_enchant_attempts"):next.guardian_enchant_attempts={}
			next.guardian_enchant_attempts[id]=int(next.guardian_enchant_attempts.get(id,0))+1
			var success: bool = rng.randi_range(0,999999) < int(upgrade.Probability)
			if success:
				if not next.has("guardian_levels"): next.guardian_levels = {}
				next.guardian_levels[id] = guardian_level(id)+1
			message = "수호성 강화 성공 · Lv.%d" % (guardian_level(id)+1) if success else "수호성 강화 실패 · 단계 유지"
		"guardian_cast":
			var reward: Dictionary=guardian_rewards(id)[0]
			var spell: Dictionary=combat.profile(int(reward.spell.ID))
			if not next.has("guardian_cast_until"):next.guardian_cast_until={}
			next.guardian_cast_until[str(int(reward.spell.CastGroupID))]=Time.get_unix_time_from_system()+float(reward.spell.CastDelay)/1000
			vital={"hp":mini(world._effective_max_hp(),world.hp+int(spell.values.get("HPRestoration",0))),"mp":mini(world._effective_max_mp(),world.mp+int(spell.values.get("MPRestoration",0)))}
			message="%s · HP +%d / MP +%d" % [str(node(id).name),int(vital.hp)-world.hp,int(vital.mp)-world.mp]
		"guardian_buy_coins":
			inventory["명예 코인"]=int(inventory.get("명예 코인",0))+10
		"guardian_debug_gems":
			if not next.has("guardian_wallet"):next.guardian_wallet={}
			next.guardian_wallet["4"]=int(next.guardian_wallet.get("4",0))+int(guardian_local_rules.development.gem_grant)
		"guardian_reset":
			var group: Dictionary=guardian_group(id)
			var category: int=int(group.category_id)
			var key: String=str(category)
			inventory["수호석"]=int(inventory.get("수호석",0))+guardian_refund(category)
			if int(offer.debug_gem_cost)>0:next.guardian_wallet["4"]-=int(offer.debug_gem_cost)
			for row: Dictionary in group.nodes:
				next.nodes.erase(row.id);next.searches.erase(row.id)
				for field: String in ["guardian_levels","guardian_enchant_attempts"]:
					if next.has(field):next[field].erase(row.id)
			for field: String in ["guardian_spent","guardian_representatives","guardian_switch_until","guardian_legacy_refund_uncertain"]:
				if next.has(field):next[field].erase(key)
			message="수호성 분류 초기화 · 기록된 수호석 환급 완료"
		"representative":
			if guardian_source.has_node(id):
				if not next.has("guardian_representatives"): next.guardian_representatives = {}
				next.guardian_representatives[str(int(node(id).category_id))] = id
				if not next.has("guardian_switch_until"):next.guardian_switch_until={}
				next.guardian_switch_until[str(int(node(id).category_id))]=Time.get_unix_time_from_system()+float(guardian_source.constant("CoolTimeSec"))
			else: next.representative = id
	next.revision += 1
	if not validate(next).is_empty():
		busy = false
		return fail("성장 상태 검증 실패")
	var payload: Dictionary={"inventory":inventory,"growth":next}
	payload.merge(vital,true)
	if int(offer.get("gold_cost",0))>0:payload.gold=world.gold-int(offer.gold_cost)
	var error: Error = world._save_game(true,payload)
	if error != OK:
		busy = false
		return fail("저장 실패 · 재료와 성장 상태를 변경하지 않았습니다 (%d)" % error)
	state = next
	if world.get("skill_cooldowns") is Dictionary:sync_guardian_cooldowns()
	world.inventory = inventory
	if payload.has("gold"):world.gold=int(payload.gold)
	if vital.has("hp"):
		world.hp=int(vital.hp);world.mp=int(vital.mp)
		combat.visuals.emit_spell(guardian_rewards(id)[0].spell,world.player)
		world.player.show_status_text(message)
	if action == "reroll": rerolls[id] = rolled
	elif action in ["enhance","reset"]: rerolls.erase(id)
	_rebuild()
	world._invalidate_equipment_static()
	world.hp = mini(world.hp,world._effective_max_hp())
	world.mp = mini(world.mp,world._effective_max_mp())
	world._update_hud()
	busy = false
	return {"ok":true,"message":message}

func incoming_damage(damage: int) -> int:
	return maxi(1,int(round(float(damage)*(1.0-clampf(bonus("incoming_reduction:percent"),0,90)/100.0))))

func guardian_skill_record(key: String) -> Dictionary:
	if not key.begins_with("guardian:"):return {}
	var id: String=key.trim_prefix("guardian:")
	if not guardian_source.has_node(id) or not state.nodes.has(id) or node(id).kind!="active":return {}
	var reward: Dictionary=guardian_rewards(id)[0]
	var spell: Dictionary=combat.profile(int(reward.spell.ID))
	return {"id":key,"name":str(node(id).name),"class":"공용","origin":"TWILIGHT_GUARDIAN523","effect":"heal","activation":"active","mp":0,"cooldown":float(reward.spell.CastDelay)/1000,"heal":int(spell.values.get("HPRestoration",0)),"items":{"명예 코인":int(reward.spell.SpellMaterialItemAmount)}}

func sync_guardian_cooldowns() -> void:
	if world==null:return
	for id: String in state.nodes:
		var row: Dictionary=guardian_skill_record("guardian:"+id)
		if row.is_empty():continue
		var reward: Dictionary=guardian_rewards(id)[0]
		var left: float=maxf(0,float(state.get("guardian_cast_until",{}).get(str(int(reward.spell.CastGroupID)),0))-Time.get_unix_time_from_system())
		world.skill_cooldowns[str(row.id)]=left;world.skill_cooldowns[str(row.name)]=left
