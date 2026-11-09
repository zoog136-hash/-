extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const Rules = preload("res://scripts/fishing/fishing_rules.gd")
const Session = preload("res://scripts/fishing/fishing_session.gd")
const CARD_ITEMS: Dictionary = {"306611":"23801", "306621":"23811", "306631":"23821", "306641":"23831"}
var world
## The original fishing model is loaded on first use and released when the
## fishing window closes (Lineage M style); nothing at boot reads it. Any
## access to `rules` loads it.
var _rules: RefCounted = null
var _rules_loaded: bool = false
var _policy_file_keys: Array = []
var rules:
	get: return _loaded_rules()
	set(value):
		_rules = value
		_rules_loaded = value != null
var state: Dictionary = fresh_state()
var busy: bool = false
var blocked: bool = false
var policy_invalid: bool = false
var session = Session.new()
var active_territory: int = 0
var previous_pause: bool = false
var previous_hud_process: int = Node.PROCESS_MODE_INHERIT
var pending_token: String = ""
var finish_error: bool = false
# These are explicitly host simulation policies, not original map coordinates.
var policy: Dictionary = {"host_equipment_exchange":false, "simulate_opponents":true, "game_hour":12, "contest_seconds":300, "exchange_denominator":10000000, "independent_extras":true, "cast_cost":1, "length_min_coefficient":900, "length_max_coefficient":1100, "gauge_rate_scale":10, "auto_power_probability_step":10000, "minigame_timeout_seconds":120}

static func fresh_state() -> Dictionary:
	return {"version":1, "revision":0, "host_options":{}, "items":{}, "fishing_experience":0, "journal":{}, "receipts":{}, "contest":{}, "pending":{}}

func configure(host: Node) -> void:
	world = host
	_rules = null
	_rules_loaded = false
	_policy_file_keys = []
	# The owner policy file is validated now (save protection depends on it);
	# coefficients it does not set come from the model when it loads.
	var policy_path: String = "user://private_content/fishing_policy.json"
	if FileAccess.file_exists(policy_path):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(policy_path)) != OK or not parser.data is Dictionary:
			blocked = true
			policy_invalid = true
			return
		for key: String in policy:
			if parser.data.has(key):
				policy[key] = parser.data[key]
				_policy_file_keys.append(key)
	if not valid_policy():
		policy_invalid = true
		blocked = true
		return

func _loaded_rules() -> RefCounted:
	if _rules_loaded: return _rules
	_rules_loaded = true
	if _rules == null: _rules = Rules.new()
	var default_path: String="user://private_content/fishing523.json"
	if OS.has_environment("TWILIGHT_FISHING523_PACK"):
		_rules.load_pack(OS.get_environment("TWILIGHT_FISHING523_PACK"))
	elif FileAccess.file_exists(default_path):_rules.load_pack(default_path)
	else:_rules.load_original()
	if policy_invalid: return _rules
	for pair: Array in [["length_min_coefficient","FishMinLengthCoefficient",900],["length_max_coefficient","FishMaxLengthCoefficient",1100]]:
		if not pair[0] in _policy_file_keys: policy[pair[0]] = _rules.constant(pair[1], pair[2])
	if not valid_policy():
		policy_invalid = true
		blocked = true
		return _rules
	_rules.exchange_denominator = int(policy.exchange_denominator)
	_rules.independent_extras = bool(policy.independent_extras)
	return _rules

## Drops the loaded model when no fishing is in progress (window closed).
func release_rules() -> void:
	if busy or active_territory != 0 or session.phase in ["waiting", "bite", "playing", "caught"]: return
	_rules = null
	_rules_loaded = false
	session = Session.new()

func valid_policy() -> bool:
	for key: String in ["host_equipment_exchange", "simulate_opponents", "independent_extras"]:
		if not policy[key] is bool: return false
	if not integer(policy.game_hour) or int(policy.game_hour) > 23: return false
	if not integer(policy.contest_seconds, 60) or int(policy.contest_seconds) > 86400: return false
	if not integer(policy.exchange_denominator, 10000000) or int(policy.exchange_denominator) > 2147483647: return false
	if not integer(policy.gauge_rate_scale, 1) or int(policy.gauge_rate_scale) > 1000: return false
	if not integer(policy.auto_power_probability_step) or int(policy.auto_power_probability_step) > 1000000: return false
	if not integer(policy.minigame_timeout_seconds, 5) or int(policy.minigame_timeout_seconds) > 3600: return false
	if not integer(policy.cast_cost, 1) or int(policy.cast_cost) > 1000000: return false
	if not integer(policy.length_min_coefficient, 1) or not integer(policy.length_max_coefficient, int(policy.length_min_coefficient)): return false
	return int(policy.length_max_coefficient) <= 1000000

func integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= 100000000000

func check_state(value: Variant) -> bool:
	if not value is Dictionary or not integer(value.get("version")) or int(value.version) != 1 or not integer(value.get("revision")): return false
	if not integer(value.get("fishing_experience", 0)): return false
	if not value.get("host_options", {}) is Dictionary: return false
	for key: Variant in value.get("host_options", {}):
		if key == "host_equipment_exchange":
			if not value.host_options[key] is bool: return false
			continue
		if key not in ["game_hour", "contest_seconds"] or not integer(value.host_options[key]): return false
		if key == "game_hour" and int(value.host_options[key]) > 23: return false
		if key == "contest_seconds" and (int(value.host_options[key]) < 60 or int(value.host_options[key]) > 86400): return false
	for key: String in ["items", "journal", "receipts", "contest", "pending"]:
		if not value.get(key) is Dictionary: return false
	for key: Variant in value.items:
		if not str(key).is_valid_int() or not integer(value.items[key]): return false
	for key: Variant in value.journal:
		var entry: Variant = value.journal[key]
		if not str(key).is_valid_int() or not entry is Dictionary: return false
		if not integer(entry.get("count")) or not integer(entry.get("max_length")): return false
	for key: Variant in value.receipts:
		if not key is String or not value.receipts[key] is Dictionary: return false
	if not value.pending.is_empty():
		if not value.pending.get("id") is String: return false
		for key: String in ["territory", "rod", "fish"]:
			if not integer(value.pending.get(key), 1): return false
	if not value.contest.is_empty():
		for key: String in ["contest_id", "rule_id", "fish_id", "range", "score", "ends_at"]:
			if not integer(value.contest.get(key)): return false
		if not value.contest.get("best_lengths", []) is Array or value.contest.get("best_lengths", []).size() > int(value.contest.range): return false
		for score: Variant in value.contest.get("best_lengths", []):
			if not integer(score, 1): return false
		if not value.contest.get("opponent_lengths", []) is Array: return false
		if value.contest.get("opponent_lengths", []).size() > 99: return false
		for score: Variant in value.contest.get("opponent_lengths", []):
			if not integer(score): return false
		if not value.contest.get("claimed") is bool or str(value.contest.get("mode", "")) != "twilight_solo": return false
	return true

func restore(value: Variant) -> bool:
	if policy_invalid or not check_state(value):
		blocked = true
		return false
	state = value.duplicate(true)
	policy.merge(state.get("host_options", {}), true)
	# Interrupted casts never award fish or refund a consumed rod after restart.
	session = Session.new()
	active_territory = 0
	blocked = false
	return true

func request_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func fail(message: String) -> Dictionary:
	return {"ok":false, "message":message}

func commit(next: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	if not world.pending_map_save_record.is_empty(): return fail("지도 저장 이전을 먼저 완료해 주세요. 비용을 차감하지 않았습니다.")
	if blocked or busy: return fail("저장 보호 중이거나 이전 작업을 처리 중입니다.")
	if not check_state(next): return fail("저장할 낚시 상태가 올바르지 않습니다.")
	# This ledger aggregates multiple stacks. MaxStackAmount limits a single
	# original inventory stack, not total ownership of an item ID.
	busy = true
	next.revision = int(state.revision) + 1
	overrides["fishing523"] = next
	var error: Error = world._save_game(true, overrides)
	busy = false
	if error != OK: return fail("저장 실패: 비용과 보상은 변경하지 않았습니다.")
	state = next
	if overrides.has("inventory"): world.inventory = overrides.inventory
	if overrides.has("item_instances"): world.item_instances = overrides.item_instances
	if overrides.has("next_item_instance_id"): world.next_item_instance_id = overrides.next_item_instance_id
	if overrides.has("card_draw_fusion"): world.card_draw_fusion.import_state(overrides.card_draw_fusion)
	world._update_hud()
	return {"ok":true, "message":"저장했습니다."}

func add_item(next: Dictionary, id: String, count: int) -> void:
	next.items[id] = int(next.items.get(id, 0)) + count

func equipment_reason(id: String) -> String:
	var physical: Dictionary = world.item_instances.get(id, {})
	if physical.is_empty(): return "실물 장비가 없습니다."
	var name_value: String = str(physical.get("name", ""))
	if world._is_instance_equipped(id): return "장착 중입니다."
	if world._item_locked(name_value, id) or world._item_locked(name_value) or bool(physical.get("locked", false)): return "잠긴 장비입니다."
	var record: Dictionary = physical.get("record", {})
	var identity: Dictionary = equipment_identity(physical)
	if identity.is_empty(): return "확정된 원본 ID 또는 명시적으로 허용한 호스트 장비가 아닙니다."
	if not bool(identity.tradable) or int(identity.grade) not in [2, 3, 4]: return "거래 가능한 고급~영웅 장비만 사용할 수 있습니다."
	for data: Dictionary in [physical, record]:
		if name_value.contains("각인") or bool(data.get("is_engraved", false)) or bool(data.get("bound", false)) or bool(data.get("quest_item", false)): return "각인 장비를 보호합니다."
		if str(data.get("bless_state", "")).to_lower() not in ["", "normal", "일반"]: return "축복 또는 저주 상태를 보호합니다."
		for key: String in ["expires_at", "expire_at", "expiration", "duration", "remaining_time", "period", "delete_time"]:
			if data.has(key) and str(data[key]) not in ["", "0", "-1"]: return "기간 장비를 보호합니다."
	var count: int = 0
	for item: Dictionary in world.item_instances.values():
		if str(item.get("name", "")) == name_value: count += 1
	if count != int(world.inventory.get(name_value, 0)): return "인벤토리와 실물 수량이 다릅니다."
	return ""

func exchange(ids: Array, token: String, revision: int) -> Dictionary:
	if rules.failure != "": return fail(rules.failure)
	if state.receipts.has(token): return fail("이미 처리한 교환입니다.")
	if token.is_empty() or revision != int(state.revision) or ids.is_empty() or ids.size() > 10: return fail("선택을 다시 확인해 주세요.")
	var seen: Dictionary = {}
	for value: Variant in ids:
		var id: String = str(value)
		if seen.has(id): return fail("같은 실물 장비를 중복 선택했습니다.")
		seen[id] = true
		var reason: String = equipment_reason(id)
		if not reason.is_empty(): return fail(reason)
	var next: Dictionary = state.duplicate(true)
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rewards: Dictionary = {}
	var consumed: Dictionary = {}
	for value: Variant in ids:
		var id: String = str(value)
		var physical: Dictionary = instances[id]
		var record: Dictionary = physical.get("record", {})
		var source: String = str(physical.get("sourceId", record.get("sourceId", "")))
		var earned: Dictionary = rules.exchange_rewards(int(equipment_identity(physical).grade), rng)
		for item: String in earned:
			rewards[item] = int(rewards.get(item, 0)) + int(earned[item])
			add_item(next, item, int(earned[item]))
		consumed[id] = physical.duplicate(true)
		var name_value: String = str(physical.name)
		inventory[name_value] = int(inventory[name_value]) - 1
		if int(inventory[name_value]) == 0: inventory.erase(name_value)
		instances.erase(id)
	next.receipts[token] = {"kind":"exchange", "consumed":consumed, "rewards":rewards}
	var result: Dictionary = commit(next, {"inventory":inventory, "item_instances":instances})
	if result.ok: result.message = "장비 교환 완료: " + JSON.stringify(rewards)
	return result

func enter(territory: int) -> Dictionary:
	if rules.row("FishTerritory", territory).is_empty(): return fail("낚시 지역 정보가 없습니다.")
	if session.phase in ["waiting", "bite", "playing"]: return fail("낚시를 먼저 종료해 주세요.")
	if active_territory == 0 and world.is_inside_tree():
		previous_pause = world.get_tree().paused
		previous_hud_process = world.hud.process_mode
		world.hud.process_mode = Node.PROCESS_MODE_ALWAYS
		world.get_tree().paused = true
	active_territory = territory
	return {"ok":true, "message":"TWILIGHT 자체 낚시 공간입니다. 원본 물 셀이나 좌표를 재현하지 않습니다."}

func cast(rod: int) -> Dictionary:
	if active_territory == 0: return fail("자체 낚시 공간에 먼저 입장해 주세요.")
	if session.phase in ["waiting", "bite", "playing", "caught"]: return fail("이전 낚시를 먼저 마쳐 주세요.")
	var id: String = str(rod)
	if int(state.items.get(id, 0)) < int(policy.cast_cost): return fail("낚싯대가 부족합니다.")
	var candidate = Session.new()
	candidate.auto_catch = session.auto_catch
	candidate.gauge_rate_scale = float(policy.gauge_rate_scale)
	candidate.auto_power_probability_step = int(policy.auto_power_probability_step)
	candidate.timeout_seconds = float(policy.minigame_timeout_seconds)
	if not candidate.start(rules, active_territory, rod, int(policy.game_hour)): return fail("유효한 낚시 풀을 찾지 못했습니다.")
	var next: Dictionary = state.duplicate(true)
	add_item(next, id, -int(policy.cast_cost))
	pending_token = request_id()
	next.pending = {"id":pending_token, "territory":active_territory, "rod":rod, "fish":int(candidate.fish.ID)}
	var result: Dictionary = commit(next)
	if result.ok:
		session = candidate
		finish_error = false
	return result

func finish() -> Dictionary:
	if session.phase not in ["caught", "failed"] or state.pending.is_empty(): return fail("완료할 낚시가 없습니다.")
	var next: Dictionary = state.duplicate(true)
	if session.phase == "caught":
		var fish: Dictionary = session.fish
		add_item(next, str(int(fish.ItemClassID)), 1)
		var key: String = str(int(fish.ID))
		var rod_stats: Dictionary = rules.rods.get(str(int(next.pending.rod)), {})
		var territory: Dictionary = rules.row("FishTerritory", int(next.pending.territory))
		# Host formula combines the retained territory range, source base range,
		# rod weighting and manual benefit. This is not a recovered server formula.
		var weighting: float = 1.0 + float(rod_stats.get("FishingCoefficientWeighting", 0)) / 100.0
		var fraction: float = pow(session.rng.randf(), 1.0 / maxf(0.01, weighting))
		var coefficient: float = lerpf(float(territory.MinCoefficient), float(territory.MaxCoefficient), fraction)
		var base: float = float(session.rng.randi_range(int(policy.length_min_coefficient), int(policy.length_max_coefficient)))
		var manual: float = 1.0 + (float(rod_stats.get("FishingLengthManualBenefit", 0)) / 1000000.0 if session.manual_play else 0.0)
		var length: int = maxi(1, int(base * coefficient * float(fish.StandardLength) * manual / 1000000.0))
		var journal: Dictionary = next.journal.get(key, {"count":0, "max_length":0})
		journal.count = int(journal.count) + 1
		journal.max_length = maxi(int(journal.max_length), length)
		if not bool(fish.get("NoMemory", false)): next.journal[key] = journal
		# Keep fishing experience separate from the host character leveling curve.
		var gain: int = int(float(fish.StandardExp) * float(session.difficulty.get("ExperienceCoefficient", 1000000)) / 1000000.0 * (1.0 + float(rod_stats.get("FishingExpAmplifier", 0)) / 1000000.0))
		next.fishing_experience = int(next.get("fishing_experience", 0)) + gain
		if not next.contest.is_empty() and not bool(next.contest.get("claimed", false)):
			if int(next.contest.fish_id) == int(fish.ID) and int(Time.get_unix_time_from_system()) < int(next.contest.ends_at):
				var lengths: Array = next.contest.get("best_lengths", []).duplicate()
				lengths.append(length)
				lengths.sort()
				lengths.reverse()
				lengths.resize(mini(lengths.size(), int(next.contest.range)))
				next.contest.best_lengths = lengths
				next.contest.score = 0
				for sample: Variant in lengths: next.contest.score += int(sample)
	next.pending = {}
	var result: Dictionary = commit(next)
	if result.ok:
		result.message = "물고기를 획득하고 저장했습니다." if session.phase == "caught" else "낚시에 실패했습니다."
		session.phase = "idle"
	return result

func buy_rod(goods_id: int, token: String, revision: int) -> Dictionary:
	if token.is_empty() or state.receipts.has(token) or revision != int(state.revision): return fail("구매 선택을 다시 확인해 주세요.")
	var goods: Dictionary = rules.row("MerchantGoods", goods_id)
	if goods.is_empty(): return fail("원본 판매 항목이 없습니다.")
	if int(world.level) < int(goods.LimitMinLevel): return fail("구매 레벨 조건이 부족합니다.")
	var id: String = str(int(goods.ItemClassID))
	var price: int = int(rules.items[id].Cost) * int(goods.Percentage) / 100
	if price <= 0 or int(state.items.get("303031", 0)) < price: return fail("낚시 주화가 부족합니다.")
	var next: Dictionary = state.duplicate(true)
	add_item(next, "303031", -price)
	add_item(next, id, int(goods.Amount))
	next.receipts[token] = {"kind":"rod_purchase", "goods":goods_id, "price":price}
	return commit(next)

func use_card(item: String, token: String, revision: int) -> Dictionary:
	if token.is_empty() or state.receipts.has(token) or revision != int(state.revision): return fail("사용 선택을 다시 확인해 주세요.")
	if not CARD_ITEMS.has(item) or int(state.items.get(item, 0)) <= 0: return fail("변신 카드 아이템이 없습니다.")
	var identity: String = ""
	var card_id: int = int(CARD_ITEMS[item])
	for record: Dictionary in world.catalog_db.get("변신", []):
		if int(record.get("source_card_id", -1)) != card_id: continue
		if record.get("source_original_card", {}) != rules.row("BuffCard", card_id): continue
		var expected_links: Array = rules.rows("CardBuffBonus").filter(func(link: Dictionary) -> bool: return int(link.BuffClassID) == int(record.source_original_card.BuffClassID))
		var bonuses_match: bool = expected_links.size() == record.get("source_bonuses", []).size()
		for link: Dictionary in record.get("source_bonuses", []):
			if rules.row("CardBuffBonus", int(link.buff_bonus.ID)) != link.buff_bonus or rules.row("CardBonus", int(link.bonus.ID)) != link.bonus: bonuses_match = false
		if bonuses_match: identity = "source:" + str(record.sourceId)
	if not world.card_draw_fusion.known_ids.get("변신", {}).has(identity): return fail("대상 변신의 정확한 ID가 현재 호스트에 없습니다. 아이템을 보존합니다.")
	var cards: Dictionary = world.card_draw_fusion.export_state()
	if bool(cards.owned["변신"].get(identity, false)):
		cards.spare["변신"][identity] = int(cards.spare["변신"].get(identity, 0)) + 1
	else: cards.owned["변신"][identity] = true
	var next: Dictionary = state.duplicate(true)
	add_item(next, item, -1)
	next.receipts[token] = {"kind":"card", "item":item, "card":str(CARD_ITEMS[item])}
	return commit(next, {"card_draw_fusion":cards})

func _contest_contract(contest_id: int,rule_id: int) -> Dictionary:
	if not rules.failure.is_empty():return fail(rules.failure)
	var contest: Dictionary=rules.row("FishContest",contest_id)
	var rule: Dictionary=rules.row("FishContestRule",rule_id)
	if contest.is_empty() or rule.is_empty():return fail("현재 원문에서 승인된 대회·규칙이 없습니다 · 이전 대회 보존")
	if not contest.get("TimeLimit") is bool or contest.TimeLimit or not integer(contest.get("WeeklyOpenTimeGroupID")) or int(contest.WeeklyOpenTimeGroupID)!=0:return fail("원본 대회 시간·주간 조건 소비자 연결 필요 · 정산 보존")
	if int(rule.get("FishContestID",0))!=contest_id or int(rule.get("RuleTypeID",0))!=11 or not integer(rule.get("Probability"),1) or not integer(rule.get("Range"),1):return fail("대회 원문 규칙·확률·수량 조건 확인 필요")
	var fish: Dictionary=rules.row("Fish",int(rule.get("FishID",0)))
	if fish.is_empty():return fail("대회 대상 물고기의 현재 원문 승인 없음")
	var ranks: Array=[];var links: Array=[];var rewards: Dictionary={};var items: Dictionary={}
	for rank: Dictionary in rules.rows("FishContestRank"):
		if int(rank.get("FishContestID",0))!=contest_id:continue
		ranks.append(rank.duplicate(true))
		for link: Dictionary in rules.rows("FishContestRankReward"):
			if int(link.get("FishContestRankID",0))!=int(rank.get("ID",0)):continue
			var reward: Dictionary=rules.row("Reward",int(link.get("RewardID",0)))
			if reward.is_empty() or reward.get("UseImmediately")!=false or reward.get("ClanOnly")!=false or int(reward.get("RewardTypeID",0))!=2 or int(reward.get("CharacterClassID",0))!=0 or not integer(reward.get("Amount"),1):return fail("현재 원문 대회 보상 승인 조건 확인 필요 · 정산 보존")
			var item: Dictionary=rules.items.get(str(int(reward.get("RewardClassID",0))),{})
			if item.is_empty() or item.get("TestItem")!=false:return fail("제외·미확인 대회 결과 아이템 · 정산 보존")
			links.append(link.duplicate(true));rewards[str(int(reward.ID))]=reward.duplicate(true);items[str(int(item.ID))]=item.duplicate(true)
	if ranks.is_empty() or links.is_empty():return fail("현재 원문 대회 순위·보상 관계 없음 · 정산 보존")
	return {"ok":true,"contract":{"schema":1,"input_identity":rules.model_input_identity.duplicate(true),"contest":contest.duplicate(true),"rule":rule.duplicate(true),"fish":fish.duplicate(true),"ranks":ranks,"reward_links":links,"rewards":rewards,"items":items}}

func start_contest(contest_id: int) -> Dictionary:
	if not rules.failure.is_empty():return fail(rules.failure)
	if active_territory == 0: return fail("자체 낚시 공간에 입장해 주세요.")
	if not state.contest.is_empty() and not bool(state.contest.get("claimed", false)): return fail("이전 대회를 먼저 정산해 주세요.")
	var contest: Dictionary = rules.row("FishContest", contest_id)
	if contest.is_empty(): return fail("대회 정의가 없습니다.")
	var territory: Dictionary = rules.row("FishTerritory", active_territory)
	var land: int = int(rules.row("Territories", int(territory.TerritoriesID)).get("LandID", -1))
	if land != int(rules.row("FishSite", int(contest.FishSiteID)).get("LandID", -2)): return fail("이 대회의 낚시터를 선택해 주세요.")
	var candidates: Array = []
	var total: int = 0
	for entry: Dictionary in rules.rows("FishContestRule"):
		if int(entry.FishContestID) == contest_id and int(entry.Probability) > 0 and int(entry.RuleTypeID) == 11:
			candidates.append(entry)
			total += int(entry.Probability)
	if total <= 0: return fail("지원되는 대회 규칙이 없습니다.")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll: int = rng.randi_range(0, total - 1)
	var chosen: Dictionary = {}
	for entry: Dictionary in candidates:
		roll -= int(entry.Probability)
		if roll < 0:
			chosen = entry
			break
	var source_contract: Dictionary=_contest_contract(contest_id,int(chosen.get("ID",0)))
	if not source_contract.get("ok",false):return source_contract
	var next: Dictionary = state.duplicate(true)
	next.contest = {"contest_id":contest_id, "rule_id":int(chosen.ID), "fish_id":int(chosen.FishID), "range":int(chosen.Range), "best_lengths":[], "score":0, "ends_at":int(Time.get_unix_time_from_system()) + int(policy.contest_seconds), "claimed":false, "mode":"twilight_solo"}
	next.contest["source_contract"]=source_contract.contract
	next.contest.opponent_lengths = []
	if bool(policy.simulate_opponents):
		var target_fish: Dictionary = rules.row("Fish", int(chosen.FishID))
		for index: int in range(maxi(0, int(contest.MaxRank) - 1)):
			var score: int = 0
			for sample: int in range(int(chosen.Range)):
				score += rng.randi_range(int(territory.MinCoefficient), int(territory.MaxCoefficient)) * int(target_fish.StandardLength) / 1000
			next.contest.opponent_lengths.append(score)
	return commit(next)

func contest_rank(contest: Dictionary) -> int:
	var rank: int = 1
	for score: Variant in contest.get("opponent_lengths", []):
		if int(score) > int(contest.get("score", 0)): rank += 1
	return rank

func claim_contest() -> Dictionary:
	if not rules.failure.is_empty():return fail(rules.failure)
	if state.contest.is_empty() or bool(state.contest.get("claimed", false)): return fail("정산할 대회가 없습니다.")
	var source_contract: Dictionary=_contest_contract(int(state.contest.contest_id),int(state.contest.rule_id))
	if not source_contract.get("ok",false):return source_contract
	# Earlier contests never recorded their full original definition. Preserve
	# them rather than award against a newly substituted model of the same ID.
	if not state.contest.get("source_contract") is Dictionary or not preload("res://scripts/quests/quest_reward_consumption.gd").same(state.contest.source_contract,source_contract.contract):return fail("저장된 대회의 원문 승인 증명 필요 · 이전 대회·보상 정산 보존")
	if int(state.contest.fish_id)!=int(source_contract.contract.rule.FishID) or int(state.contest.range)!=int(source_contract.contract.rule.Range):return fail("저장된 대회 대상·수량 불일치 · 정산 보존")
	if int(Time.get_unix_time_from_system()) < int(state.contest.ends_at): return fail("대회가 아직 진행 중입니다.")
	var next: Dictionary = state.duplicate(true)
	next.contest.claimed = true
	# Opponents are explicitly simulated host scores, never remote users.
	if int(next.contest.score) > 0:
		var rank_id: int = -1
		var rank: int = contest_rank(next.contest)
		var threshold: int = 0
		next.contest.rank = rank
		for entry: Dictionary in rules.rows("FishContestRank"):
			if int(entry.FishContestID) == int(next.contest.contest_id) and int(entry.RankRangeMin) <= rank and int(entry.RankRangeMin) > threshold:
				threshold = int(entry.RankRangeMin)
				rank_id = int(entry.ID)
		for entry: Dictionary in rules.rows("FishContestRankReward"):
			if int(entry.FishContestRankID) != rank_id: continue
			var reward: Dictionary = rules.row("Reward", int(entry.RewardID))
			if int(reward.get("RewardTypeID", 0)) != 2 or bool(reward.get("UseImmediately", false)) or int(reward.get("CharacterClassID", 0)) != 0 or bool(reward.get("ClanOnly", false)): return fail("직접 지급할 수 없는 대회 보상이 있습니다. 정산을 보존합니다.")
			add_item(next, str(int(reward.RewardClassID)), int(reward.Amount))
	return commit(next)

func tick(delta: float) -> void:
	session.tick(minf(delta, 0.1))
	if session.phase in ["caught", "failed"] and not finish_error:
		var result: Dictionary = finish()
		finish_error = not bool(result.ok)
		world.hud.show_message(str(result.message))

func transfer_to_inventory(item: String, token: String, revision: int) -> Dictionary:
	if token.is_empty() or state.receipts.has(token) or revision != int(state.revision): return fail("이동 선택을 다시 확인해 주세요.")
	if int(state.items.get(item, 0)) <= 0: return fail("보유 아이템이 없습니다.")
	var matches: Array = []
	for record: Dictionary in world.catalog_db.get("아이템", []):
		if str(record.get("sourceId", "")) == "m523:item:" + item and str(record.get("source_snapshot", "")) == "patch523" and int(record.get("source_item_class_id", 0)) == int(item): matches.append(record)
	if matches.size() != 1: return fail("현재 가방에서 원본 ID를 고유하게 확인할 수 없어 보관함에 유지합니다.")
	var record: Dictionary = matches[0]
	var name_value: String = str(record.name)
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	var overrides: Dictionary = {}
	if not str(world._enhancement_kind_for_record(record)).is_empty():
		var next_id: int = int(world.next_item_instance_id)
		while instances.has(str(next_id)): next_id += 1
		instances[str(next_id)] = {"name":name_value, "level":0, "sourceId":str(record.sourceId), "record":NATIVE_FIELDS.full(record).duplicate(true), "element":"", "element_level":0}
		overrides["next_item_instance_id"] = next_id + 1
	else:
		var identities: Dictionary = {}
		for candidate: Dictionary in world.catalog_db.get("아이템", []):
			if str(candidate.get("name", "")) == name_value: identities[str(candidate.get("sourceId", ""))] = true
		if identities.size() != 1: return fail("같은 이름의 다른 원본 ID와 합쳐질 수 있어 이동을 보류합니다.")
	inventory[name_value] = int(inventory.get(name_value, 0)) + 1
	var next: Dictionary = state.duplicate(true)
	add_item(next, item, -1)
	next.receipts[token] = {"kind":"inventory_transfer", "item":item}
	overrides["inventory"] = inventory
	overrides["item_instances"] = instances
	return commit(next, overrides)

func has_bag(item: String) -> bool:
	for effect: Dictionary in rules.item_effects.get(item, []):
		if str(effect.type) == "LuckyBagClassID": return true
	return false

func open_treasure(item: String, token: String, revision: int) -> Dictionary:
	if token.is_empty() or state.receipts.has(token) or revision != int(state.revision) or int(state.items.get(item, 0)) <= 0: return fail("상자 선택을 다시 확인해 주세요.")
	var bag: int = 0
	for effect: Dictionary in rules.item_effects.get(item, []):
		if str(effect.type) == "LuckyBagClassID": bag = int(effect.value)
	var entries: Array = []
	var total: int = 0
	var guaranteed: Dictionary = {}
	for entry: Dictionary in rules.rows("LuckyBagEntityView"):
		if int(entry.LuckyBagClassID) != bag: continue
		if int(entry.LuckyBagEntityTypeID) not in [0, 1] or int(entry.ItemAmount) <= 0 or int(entry.ItemEnchant) != 0 or int(entry.ItemBlessCodeID) != 1 or int(entry.LimitClass) != 10000: return fail("지원되지 않는 상자 지급 조건이 있어 원본 상자를 보존합니다.")
		if int(entry.LuckyBagEntityTypeID) == 1:
			var id: String = str(int(entry.ItemClassID))
			guaranteed[id] = int(guaranteed.get(id, 0)) + int(entry.ItemAmount)
		elif int(entry.Probability) > 0:
			entries.append(entry)
			total += int(entry.Probability)
	if entries.is_empty() and guaranteed.is_empty(): return fail("상자 내용이 없습니다.")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll: int = rng.randi_range(0, total - 1) if total > 0 else -1
	var next: Dictionary = state.duplicate(true)
	add_item(next, item, -1)
	for id: String in guaranteed: add_item(next, id, int(guaranteed[id]))
	next.receipts[token] = {"kind":"treasure", "guaranteed":guaranteed, "bag":bag}
	for entry: Dictionary in entries:
		roll -= int(entry.Probability)
		if roll < 0:
			add_item(next, str(int(entry.ItemClassID)), int(entry.ItemAmount))
			next.receipts[token]["extra"] = {"item":int(entry.ItemClassID), "amount":int(entry.ItemAmount)}
			break
	return commit(next)

func set_option(key: String, value: int) -> Dictionary:
	if key not in ["game_hour", "contest_seconds"]: return fail("지원되지 않는 자체 설정입니다.")
	if session.phase in ["waiting", "bite", "playing", "caught"]: return fail("낚시 중에는 설정을 바꿀 수 없습니다.")
	var next: Dictionary = state.duplicate(true)
	if not next.has("host_options"): next.host_options = {}
	next.host_options[key] = value
	var result: Dictionary = commit(next)
	if result.ok: policy[key] = value
	return result

func leave() -> void:
	if active_territory == 0: return
	if not world.is_inside_tree():
		active_territory = 0
		return
	if session.phase in ["waiting", "bite", "playing"]:
		session.phase = "failed"
		var result: Dictionary = finish()
		finish_error = not bool(result.ok)
	if world.is_inside_tree():
		world.get_tree().paused = previous_pause
		world.hud.process_mode = previous_hud_process
	active_territory = 0

func equipment_identity(physical: Dictionary) -> Dictionary:
	var record: Dictionary = physical.get("record", {})
	var name_value: String = str(physical.get("name", ""))
	if record.is_empty() and bool(policy.host_equipment_exchange):
		# Legacy equipment remains selected by physical ID. A unique host
		# catalog supplies only host grade/sell rules, never original identity.
		if int(world.catalog_item_variant_count.get(name_value, 0)) != 1: return {}
		record = world._find_catalog_item_record(name_value)
	var source: String = str(physical.get("sourceId", record.get("sourceId", "")))
	if source.is_empty() or record.is_empty() or str(record.get("name", "")) != name_value: return {}
	if str(record.get("sourceId", "")) != source: return {}
	if str(record.get("source", "")) == "lineagem_patch523" and str(record.get("source_snapshot", "")) == "patch523":
		var id: int = int(record.get("source_item_class_id", 0))
		if source != "m523:item:" + str(id) or not rules.items.has(str(id)): return {}
		var original: Dictionary = rules.items[str(id)]
		if int(original.CategoryID) not in [1, 2, 43] or bool(original.TestItem): return {}
		return {"grade":int(original.GradeID), "tradable":bool(original.IsTradable), "scope":"source523"}
	# Explicit opt-in compatibility policy: retain the host namespace and its
	# existing sell restrictions. Never reinterpret an Inven ID as ItemClassID.
	if not bool(policy.host_equipment_exchange): return {}
	var canonical: Dictionary = world._catalog_item_from_source_id(source)
	if canonical.is_empty() or str(canonical.get("source", "")) != str(record.get("source", "")) or str(canonical.get("name", "")) != str(record.name): return {}
	if str(world._enhancement_kind_for_record(canonical)).is_empty(): return {}
	if str(canonical.get("grade", "")) != str(record.get("grade", "")): return {}
	return {"grade":int({"고급":2, "희귀":3, "영웅":4}.get(str(canonical.grade), 0)), "tradable":bool(canonical.get("tradeable", true)) and not bool(canonical.get("bound", false)) and not bool(canonical.get("quest_item", false)), "scope":"host_policy"}

func set_host_equipment_policy(enabled: bool) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if not next.has("host_options"): next.host_options = {}
	next.host_options.host_equipment_exchange = enabled
	var result: Dictionary = commit(next)
	if result.ok: policy.host_equipment_exchange = enabled
	return result
