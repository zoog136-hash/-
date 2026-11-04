extends RefCounted
## Source values are loaded from an owner-installed private 523 pack.
## Execution choices absent from the client tables remain explicit host policy.
var tables: Dictionary = {}
var rods: Dictionary = {}
var item_effects: Dictionary = {}
var items: Dictionary = {}
var exchange_denominator: int = 10000000
var independent_extras: bool = true
var failure: String = "원본 523 낚시 팩이 필요합니다."

func load_pack(path: String) -> bool:
	var parser := JSON.new()
	if not FileAccess.file_exists(path) or parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	return configure(parser.data)

func configure(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("version", 0)) != 523 or not data.get("tables") is Dictionary:
		return false
	for key: String in ["Fish", "FishDistribution", "FishPoolProbability", "FishTerritory", "FishMiniGameDifficulty", "ExchangeSystemRule", "ExchangeSystemInput", "ExchangeSystemOutput", "ItemClass"]:
		if not data.tables.get(key) is Array: return false
	tables = data.tables.duplicate(true)
	rods = data.get("rods", {}).duplicate(true)
	item_effects = data.get("item_effects", {}).duplicate(true)
	items.clear()
	for row: Dictionary in tables.ItemClass: items[str(int(row.ID))] = row
	failure = ""
	return true

func rows(name_value: String) -> Array:
	return tables.get(name_value, [])

func row(name_value: String, id: int) -> Dictionary:
	for entry: Dictionary in rows(name_value):
		if int(entry.get("ID", -1)) == id: return entry
	return {}

func distribution(territory: int, rod: int, hour: int) -> Dictionary:
	var candidates: Array = []
	for entry: Dictionary in rows("FishDistribution"):
		if int(entry.FishTerritoryID) != territory: continue
		if int(entry.FishingRodID) not in [0, rod]: continue
		var start: int = int(entry.GameTimeFrom)
		var end: int = int(entry.GameTimeTo)
		var in_time: bool = (hour >= start and hour < end) if start < end else (hour >= start or hour < end)
		if in_time: candidates.append(entry)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.TimePriority) != int(b.TimePriority): return int(a.TimePriority) < int(b.TimePriority)
		return int(a.FishingRodPriority) < int(b.FishingRodPriority))
	return candidates[0] if not candidates.is_empty() else {}

func choose_fish(pool: int, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	var eligible: Array = []
	for entry: Dictionary in rows("FishPoolProbability"):
		if int(entry.FishPoolID) != pool or int(entry.Probability) <= 0: continue
		eligible.append(entry)
		total += int(entry.Probability)
	if total <= 0: return {}
	# Fish pool weights are relative within this pool. Exchange outputs are NOT.
	var roll: int = rng.randi_range(0, total - 1)
	for entry: Dictionary in eligible:
		roll -= int(entry.Probability)
		if roll < 0: return row("Fish", int(entry.FishID))
	return {}

func exchange_rule(grade: int) -> Dictionary:
	for rule: Dictionary in rows("ExchangeSystemRule"):
		if int(rule.SystemTypeID) != 1: continue
		var input: Dictionary = row("ExchangeSystemInput", int(rule.InputID))
		if int(input.get("Type", 0)) == 1 and int(input.get("Value", 0)) == grade: return rule
	return {}

func exchange_outputs(system_type: int, rule_id: int) -> Array:
	var rule: Dictionary = row("ExchangeSystemRule", rule_id)
	if int(rule.get("SystemTypeID", -1)) != system_type: return []
	return rows("ExchangeSystemOutput").filter(func(r: Dictionary) -> bool: return int(r.RuleID) == rule_id)

func exchange_rewards(grade: int, rng: RandomNumberGenerator) -> Dictionary:
	var rule: Dictionary = exchange_rule(grade)
	var result: Dictionary = {}
	if rule.is_empty(): return result
	var shared_roll: int = rng.randi_range(0, exchange_denominator - 1)
	for entry: Dictionary in exchange_outputs(1, int(rule.ID)):
		# Host policy: independent extra rolls, denominator 10,000,000.
		# Guaranteed amounts always apply, irrespective of any extra roll.
		var wins: bool = bool(entry.IsGuaranteed)
		if not wins:
			if independent_extras: wins = rng.randi_range(0, exchange_denominator - 1) < int(entry.Probability)
			else:
				wins = shared_roll >= 0 and shared_roll < int(entry.Probability)
				shared_roll -= int(entry.Probability)
		if wins:
			var key: String = str(int(entry.ItemClassID))
			result[key] = int(result.get(key, 0)) + int(entry.AmountGuaranteed)
	return result

func item_name(id: String) -> String:
	return str(items.get(id, {}).get("Name", "아이템 #" + id))

func constant(name_value: String, fallback: int) -> int:
	for entry: Dictionary in rows("FishConstant"):
		if str(entry.Name) == name_value: return int(entry.Value)
	return fallback
