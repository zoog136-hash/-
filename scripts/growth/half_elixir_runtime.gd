extends RefCounted
## Staged transactions use the production save writer before live wallets change.
const Source = preload("res://scripts/growth/half_elixir_source.gd")
const KEY := "half_elixir523"
const ROOT := "user://half_elixir523/packs/"
var world
var state: Dictionary = fresh()
var policy: Dictionary = {}
var source
var sources: Dictionary = {}
var busy: bool = false
var save_blocked: bool = false
var serial: int = 0
var rolls: Dictionary = {}
var rng := RandomNumberGenerator.new()

static func fresh() -> Dictionary:
	return {"schema":1, "revision":0, "source_sha256":"", "context":"", "points":0, "extension":0, "allocations":{}, "receipts":[]}

func configure(host: Node) -> void:
	world = host
	policy = JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/half_elixir_policy.json"))
	rng.randomize()

static func integer(value: Variant, minimum: int = 0, maximum: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

func source_for(value: Dictionary):
	var sha: String = str(value.get("source_sha256", ""))
	if sha.is_empty(): return null
	if sources.has(sha): return sources[sha]
	var path: String = ROOT + sha + ".zip"
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != sha: return null
	var candidate = Source.new()
	if not candidate.load_zip(path): return null
	sources[sha] = candidate
	return candidate

func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("schema") != 1: return "하프 엘릭서 저장 버전이 잘못됐습니다."
	for key: String in ["revision", "points", "extension"]:
		if not integer(value.get(key)): return "하프 엘릭서 저장 숫자가 잘못됐습니다."
	if int(value.extension) % 5 != 0 or int(value.extension) > 50: return "원문 비용으로 도달할 수 없는 확장입니다."
	if not value.get("source_sha256") is String or not value.get("context") is String or not value.get("allocations") is Dictionary or not value.get("receipts") is Array: return "하프 엘릭서 저장 구조가 잘못됐습니다."
	var sha: String = value.source_sha256
	if not sha.is_empty() and (sha.length() != 64 or not sha.is_valid_hex_number(false)): return "하프 엘릭서 원본 식별자가 잘못됐습니다."
	if value.receipts.size() > 128 or value.allocations.size() > 142: return "하프 엘릭서 저장 범위를 벗어났습니다."
	var seen: Dictionary = {}
	for receipt: Variant in value.receipts:
		if not receipt is Dictionary or not receipt.get("nonce") is String or receipt.nonce.is_empty() or seen.has(receipt.nonce) or not receipt.get("request_hash") is String or not receipt.get("result") is Dictionary: return "하프 엘릭서 처리 이력이 잘못됐습니다."
		seen[receipt.nonce] = true
	for id: Variant in value.allocations:
		if not id is String or not integer(value.allocations[id], 1): return "하프 엘릭서 투자 저장이 잘못됐습니다."
	var data = source_for(value)
	if data == null:
		if sha.is_empty() and (value.points != 0 or value.extension != 0 or not value.allocations.is_empty()): return "원본 없는 하프 엘릭서 진행입니다."
		return "" # Missing owner input stays intact and inactive, never reset.
	if value.context.is_empty():
		return "" if value.points == 0 and value.extension == 0 and value.allocations.is_empty() else "서버 문맥이 없는 투자입니다."
	if not data.pairs.has(value.context): return "원문에 없는 서버 문맥입니다."
	var selected: Dictionary = data.profile(value.context)
	var used: int = 0
	for id: String in value.allocations:
		if not selected.has(id): return "다른 서버의 투자 규칙이 섞였습니다."
		var spent: int = int(value.allocations[id]) * int(selected[id].raw.Cost)
		if spent > data.cap(id, int(value.extension)): return "능력치별 투자 한도를 벗어났습니다."
		used += spent
	if used > int(value.points) or value.points > capacity(value, data): return "사용 포인트 또는 전체 용량이 잘못됐습니다."
	if value.extension > 0 and not data.enabled("ElixirExtend", value.context): return "확장 불가 서버의 저장입니다."
	return ""

func capacity(value: Dictionary, data) -> int:
	var base: int = data.constant("DefaultHalfElixirMaxPoint", value.context)
	return base + (int(value.extension) if bool(policy.get("global_cap_adds_extension_coordinate", true)) else 0)

func accept(value: Dictionary) -> void:
	state = value.duplicate(true)
	source = source_for(state)
	save_blocked = false
	if world != null: world._invalidate_equipment_static()

func points_used(value: Dictionary = {}) -> int:
	if value.is_empty(): value = state
	var data = source_for(value)
	if data == null: return 0
	var total: int = 0
	for id: String in value.allocations: total += int(value.allocations[id]) * int(data.rules[id].raw.Cost)
	return total

func request(action: String, id: String = "", count: int = 1) -> Dictionary:
	serial += 1
	return {"action":action, "id":id, "count":count, "revision":int(state.revision), "nonce":"%s_%s" % [Time.get_ticks_usec(), serial]}

func failure(message: String) -> Dictionary:
	return {"ok":false, "message":message}

func install(path: String) -> Dictionary:
	if busy or save_blocked: return failure("다른 처리가 진행 중이거나 저장 보호 중입니다.")
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size() > 64000000: return failure("원본 ZIP의 크기가 올바르지 않습니다.")
	var candidate = Source.new()
	if not candidate.load_zip(path): return failure(candidate.problem)
	if not str(state.source_sha256).is_empty() and state.source_sha256 != candidate.sha: return failure("기존 포인트의 원본과 다릅니다. 기존 진행을 보존했습니다.")
	DirAccess.make_dir_recursive_absolute(ROOT)
	var destination: String = ROOT + candidate.sha + ".zip"
	if not FileAccess.file_exists(destination) or FileAccess.get_sha256(destination) != candidate.sha:
		var temporary: String = destination + ".installing"
		if DirAccess.copy_absolute(path, temporary) != OK or FileAccess.get_sha256(temporary) != candidate.sha: return failure("원본 설치 검증에 실패했습니다.")
		if DirAccess.rename_absolute(temporary, destination) != OK: return failure("원본 설치를 활성화하지 못했습니다.")
	sources[candidate.sha] = candidate
	var next: Dictionary = state.duplicate(true)
	next.source_sha256 = candidate.sha
	next.revision += 1
	busy = true
	var error: Error = world._save_game(true, {KEY:next})
	busy = false
	if error != OK: return failure("저장 실패로 원본 연결을 활성화하지 않았습니다.")
	accept(next)
	return {"ok":true, "message":"523 원본을 설치하고 저장했습니다."}

func owned_stack(name: String, inventory: Dictionary) -> int:
	if name.is_empty() or not integer(inventory.get(name, 0)): return -1
	# Stack-name compatibility is explicit. Never consume a named physical or locked item.
	for row: Dictionary in world.item_instances.values():
		if str(row.get("name", "")) == name: return -1
	return int(inventory.get(name, 0))

func execute(command: Dictionary) -> Dictionary:
	if busy or save_blocked: return failure("다른 처리가 진행 중이거나 저장 보호 중입니다.")
	if not command.get("action") is String or not command.get("id") is String or not command.get("nonce") is String or command.nonce.is_empty() or command.nonce.length() > 128 or not integer(command.get("count"), 1, 100) or not integer(command.get("revision")): return failure("요청 형식이 잘못됐습니다.")
	var request_hash: String = JSON.stringify(command, "", true).sha256_text()
	for receipt: Dictionary in state.receipts:
		if receipt.nonce == command.nonce:
			if receipt.request_hash != request_hash: return failure("같은 요청 번호의 내용이 다릅니다.")
			var duplicate: Dictionary = receipt.result.duplicate(true); duplicate["duplicate"] = true
			return duplicate
	if int(command.revision) != int(state.revision): return failure("상태가 바뀌었습니다. 다시 확인해 주세요.")
	var problem: String = validate(state)
	if not problem.is_empty(): save_blocked = true; return failure(problem)
	source = source_for(state)
	if source == null: return failure("사용자 소유 523 원본 ZIP을 먼저 설치해 주세요.")
	var next: Dictionary = state.duplicate(true)
	var inventory: Dictionary = world.inventory.duplicate(true)
	var gold: int = int(world.gold)
	var action: String = command.action
	var id: String = command.id
	var count: int = int(command.count)
	var message: String = ""
	if action == "context":
		if not source.pairs.has(id) or not next.allocations.is_empty(): return failure("서버 문맥이 잘못됐거나 투자 초기화가 먼저 필요합니다.")
		next.context = id
		if next.points > capacity(next, source) or (next.extension > 0 and not source.enabled("ElixirExtend", id)): return failure("새 서버의 용량이나 확장 조건과 맞지 않습니다.")
		message = "서버 문맥을 선택했습니다."
	else:
		if not source.pairs.has(next.context): return failure("지역과 월드를 먼저 선택해 주세요.")
		match action:
			"charge", "reset":
				var entries: Dictionary = source.charges if action == "charge" else source.resets
				if not entries.has(id): return failure("해당 동작의 원본 아이템이 아닙니다.")
				var item: Dictionary = entries[id]
				if int(world.level) < int(item.raw.LevelLimitMin) or (int(item.raw.LevelLimitMax) > 0 and int(world.level) > int(item.raw.LevelLimitMax)): return failure("아이템의 원본 레벨 조건을 충족하지 못했습니다.")
				if item.get("blocked", false): return failure("만료 또는 테스트 아이템의 실행 조건이 확인되지 않았습니다.")
				var quantity: int = count if action == "charge" else 1
				if owned_stack(item.name, inventory) < quantity: return failure("정확한 소유 재료가 부족하거나 물리 아이템과 충돌합니다.")
				if action == "charge":
					if int(item.amount) <= 0 or next.points + int(item.amount) * count > capacity(next, source): return failure("전체 사용 포인트 용량을 초과합니다.")
					next.points += int(item.amount) * count
					message = "포인트를 충전했습니다."
				else:
					if not source.enabled("HalfElixirInitialize", next.context) or next.allocations.is_empty(): return failure("초기화 조건을 충족하지 못했습니다.")
					next.allocations.clear()
					message = "투자 포인트를 돌려받았습니다. 물약이나 재화를 환불한 것은 아닙니다."
				inventory[item.name] = int(inventory.get(item.name, 0)) - quantity
			"invest":
				var selected: Dictionary = source.profile(next.context)
				if not selected.has(id): return failure("현재 서버에 없는 투자 규칙입니다.")
				var cost: int = int(selected[id].raw.Cost) * count
				var purchases: int = int(next.allocations.get(id, 0)) + count
				if points_used(next) + cost > next.points or purchases * int(selected[id].raw.Cost) > source.cap(id, next.extension): return failure("미사용 포인트가 부족하거나 능력치 한도를 초과합니다.")
				next.allocations[id] = purchases
				message = "능력치 투자를 저장했습니다."
			"extend":
				if not source.enabled("ElixirExtend", next.context) or not source.costs.has(int(next.extension)): return failure("이 서버 또는 다음 단계는 확장할 수 없습니다.")
				if next.points < source.constant("HalfElixirMinimumPointForExtend", next.context): return failure("확장에 필요한 사용 포인트가 부족합니다.")
				var row: Dictionary = source.costs[int(next.extension)]
				var currency: Dictionary = source.currencies[int(row.CurrencyID)]
				var material: String = ""
				if str(currency.raw.get("Name", "")) != "Adena":
					for member: Dictionary in currency.members:
						if int(member.UnitID) == 4 and not bool(member.ForGive):
							if not material.is_empty() and material != str(member.get("name", "")): return failure("확장 재화가 모호합니다.")
							material = str(member.get("name", ""))
					if material.is_empty(): return failure("지원하지 않는 확장 재화입니다.")
				if material.is_empty() and gold < int(row.Cost): return failure("아데나가 부족합니다.")
				if not material.is_empty() and owned_stack(material, inventory) < int(row.Cost): return failure("퓨어 엘릭서 재료가 부족합니다.")
				var divisor: float = float(policy.get("probability_divisor", 0))
				if divisor <= 0 or float(row.Probability) < 0 or float(row.Probability) > divisor: return failure("자체 확률 정책의 분모가 올바르지 않습니다.")
				if not rolls.has(command.nonce): rolls[command.nonce] = rng.randf()
				var won: bool = float(rolls[command.nonce]) < float(row.Probability) / divisor
				if won: next.extension = int(row.AfterExtendPoint)
				if won or bool(policy.get("failure_consumes_cost", true)):
					if material.is_empty(): gold -= int(row.Cost)
					else: inventory[material] = int(inventory[material]) - int(row.Cost)
				message = "확장 성공" if won else "확장 실패 · TWILIGHT 실패 차감 정책을 적용했습니다."
			_: return failure("알 수 없는 하프 엘릭서 동작입니다.")
	next.revision += 1
	var result: Dictionary = {"ok":true, "message":message, "revision":int(next.revision)}
	next.receipts.append({"nonce":command.nonce, "request_hash":request_hash, "result":result.duplicate(true)})
	while next.receipts.size() > int(policy.get("receipt_limit", 64)): next.receipts.pop_front()
	problem = validate(next)
	if not problem.is_empty(): return failure(problem)
	busy = true
	var error: Error = world._save_game(true, {KEY:next, "inventory":inventory, "gold":gold})
	busy = false
	if error != OK: return failure("저장 실패 · 재료, 재화와 포인트를 변경하지 않았습니다.")
	world.inventory = inventory; world.gold = gold
	accept(next)
	rolls.erase(command.nonce)
	world.hp = mini(world.hp, world._effective_max_hp())
	world._update_hud()
	return result

func effects() -> Array:
	var data = source_for(state)
	var result: Array = []
	if data == null: return result
	for id: String in state.allocations: result.append(data.effect(id, int(state.allocations[id])))
	return result

func value(type_name: String, target: String = "") -> float:
	var total: float = 0
	for effect: Dictionary in effects():
		if effect.type == type_name and effect.target == target: total += float(effect.value)
	return total

func stat_record() -> Dictionary:
	var result: Dictionary = {}
	for effect: Dictionary in effects():
		var type_name: String = effect.type
		var key: String = str(Source.DIRECT.get(type_name, ""))
		if type_name in ["SpecialResistance", "HitSpecialResistance"]:
			key = str(effect.target).to_lower() + ("_resistance" if type_name == "SpecialResistance" else "_accuracy")
		if not key.is_empty(): result[key] = float(result.get(key, 0)) + float(effect.value)
	return result

func incoming(amount: int, kind: String, elemental: bool, pvp: bool = false, poison: bool = false) -> int:
	var flat: float = value("PVPDamageReduction" if pvp else "PVEDamageReduction")
	if kind in ["magic", "poison"]: flat += value("DamageReduction")
	if elemental: flat += value("ElementalDamageReduction")
	var names: Dictionary = {"melee":"MeleeDamageReductionPercent", "ranged":"RangeDamageReductionPercent", "magic":"MagicDamageReductionPercent"}
	var percent: float = value(str(names.get(kind, "")))
	if pvp: percent += value("PVPDamageReductionPercent")
	if poison: percent += value("PoisonDamageReductionPercent")
	return maxi(1, int(round(maxf(1, amount - flat) * (1.0 - clampf(percent, 0, float(policy.get("maximum_damage_reduction_percent", 90))) / 100.0))))

func status_chance(base: float, name: String) -> float:
	return clampf(base * (1.0 - clampf(value("SpecialResistance", name), 0, 100) / 100.0), 0, 1)

func shield_damage(amount: int, shield_percent: float) -> int:
	return maxi(1, int(round(amount * (1.0 - clampf(shield_percent - value("PierceMagicShieldPercent"), 0, 100) / 100.0))))

func item_action(name: String) -> Dictionary:
	var data = source_for(state)
	if data == null: return {}
	for kind: String in ["charge", "reset"]:
		var entries: Dictionary = data.charges if kind == "charge" else data.resets
		for id: String in entries:
			if entries[id].name == name: return {"action":kind, "id":id}
	return {}

func storable(name: String) -> bool:
	var action := item_action(name)
	if action.is_empty(): return true
	var data = source_for(state)
	return bool((data.charges if action.action == "charge" else data.resets)[action.id].raw.IsStorable)

func pvp_evasion(kind: String, ignore: bool = false) -> float:
	if kind not in ["melee", "ranged"]: return 0
	return value("PVPPierce" + ("Melee" if kind == "melee" else "Range") + "Evasion") if ignore else value("PVP" + ("Melee" if kind == "melee" else "Range") + "Evasion")
