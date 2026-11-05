extends RefCounted
## Explicit configurable TWILIGHT fallback, separate from exact source costs.
const BALANCE = preload("res://data/monsterbook523_balance.json")
var settings: Dictionary = BALANCE.data.duplicate(true)
var _runtime: WeakRef
var runtime: RefCounted:
	get: return _runtime.get_ref() if _runtime != null else null
var world: Node

func configure(owner_runtime: RefCounted, owner_world: Node) -> void:
	_runtime = weakref(owner_runtime)
	world = owner_world

func configured() -> bool:
	for key: String in ["adena_per_internal_gem","exp_numerator","exp_denominator"]:
		if not runtime.catalog._integer(BALANCE.data.get(key)) or int(BALANCE.data[key]) <= 0: return false
	return true

func wallet(state: Dictionary) -> Dictionary:
	return state.get("local_economy",{"schema":1,"gems":0,"acquired":0,"spent":0,"provenance":"twilight_custom_internal_gems_v1"}).duplicate(true)

func gems() -> int:
	return int(wallet(runtime.catalog.export_state()).gems)

func exchange(amount: int) -> Dictionary:
	if runtime.transaction_busy or runtime.catalog._busy: return {"ok":false,"message":"도감 거래 처리 중"}
	runtime.transaction_busy = true
	var result := _exchange(amount)
	runtime.transaction_busy = false
	return result

func _exchange(amount: int) -> Dictionary:
	if not configured() or amount <= 0 or amount > 10000 or runtime.save_blocked or not runtime.catalog.loaded(): return {"ok":false,"message":"도감 다이아 교환 조건 확인 필요"}
	# Do not sell an internal currency for an already closed event.
	if runtime.catalog.books().all(func(book: Dictionary) -> bool: return not runtime.local.window_problem(int(book.ID)).is_empty()): return {"ok":false,"message":"현재 진행 가능한 도감 기간이 없습니다"}
	var cost: int = amount * int(BALANCE.data.adena_per_internal_gem)
	if int(world.gold) < cost: return {"ok":false,"message":"아데나 부족"}
	var proposed: Dictionary = runtime.catalog.export_state()
	var stock := wallet(proposed)
	stock.gems = int(stock.gems) + amount
	stock.acquired = int(stock.acquired) + amount
	proposed["local_economy"] = stock
	if not runtime.catalog.valid_state(proposed) or not runtime.persist(proposed,{"gold":int(world.gold)-cost}): return {"ok":false,"message":"저장 실패 · 아데나와 다이아 유지"}
	world.gold -= cost
	runtime.catalog.import_state(proposed)
	world._update_hud()
	return {"ok":true,"message":"게임 다이아 %d개 교환 완료 · 자체 설정 %d 아데나" % [amount,cost]}

func experience_amount(reward: Dictionary) -> int:
	if not configured() or int(reward.get("RewardTypeID",0)) != 1 or int(reward.get("RewardClassID",0)) != 281 or int(reward.get("Amount",0)) <= 0: return -1
	return maxi(1,int(round(float(reward.Amount)*float(BALANCE.data.exp_numerator)/float(BALANCE.data.exp_denominator))))

func experience_state(amount: int) -> Dictionary:
	# Project the existing world's level-up rule without mutating live state.
	var projected: Dictionary = {}
	for key: String in ["experience","exp_need","level","max_hp","max_mp","hp","mp","attack_power","defense","stat_points"]: projected[key] = int(world.get(key))
	projected.experience += amount
	var gained: bool = false
	while int(projected.experience) >= int(projected.exp_need):
		projected.experience -= int(projected.exp_need)
		projected.level += 1
		projected.exp_need = world.EXP_PROGRESSION.required_for_level(int(projected.level),int(projected.exp_need))
		projected.max_hp += 45
		projected.max_mp += 9
		projected.attack_power += 2
		projected.defense += 1
		projected.stat_points += world._stat_points_for_level_up(int(projected.level))
		gained = true
	if gained:
		projected.hp = world._effective_max_hp(int(projected.max_hp))
		projected.mp = int(projected.max_mp)
	return projected
