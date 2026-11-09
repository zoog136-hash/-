extends RefCounted
## Source values come from a selected private pack or held original definitions.
## Execution choices absent from the client tables remain explicit host policy.
const ORIGINAL = preload("res://scripts/fishing/current523_fishing_input.gd")
var tables: Dictionary = {}
var rods: Dictionary = {}
var item_effects: Dictionary = {}
var items: Dictionary = {}
var raw_tables: Dictionary = {}
var raw_rods: Dictionary = {}
var raw_item_effects: Dictionary = {}
var source_effect_rows: Dictionary = {}
var model_input_identity: Dictionary = {}
var loaded_sha256: String = ""
var unavailable_source_definitions: Array = []
var source_exclusion_evidence: Array = []
var input_problem: String = ""
var exchange_denominator: int = 10000000
var independent_extras: bool = true
var failure: String = "원본 523 낚시 팩이 필요합니다."

func load_pack(path: String) -> bool:
	if path.is_empty():
		failure = "선택한 낚시 523 파일 경로가 비어 있습니다."
		input_problem = "explicit_fishing_pack_path_empty"
		return false
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null:
		failure = "선택한 낚시 523 파일을 읽을 수 없습니다."
		input_problem = "fishing_pack_unreadable:"+str(FileAccess.get_open_error())
		return false
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		failure = "선택한 낚시 523 파일을 끝까지 읽지 못했습니다."
		input_problem = "fishing_pack_read_incomplete"
		return false
	var hash = HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(bytes) != OK:
		failure = "선택한 낚시 523 파일의 정체를 계산하지 못했습니다."
		input_problem = "fishing_pack_sha256_unavailable"
		return false
	var digest: String = hash.finish().hex_encode()
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		failure = "선택한 낚시 523 파일의 JSON을 읽을 수 없습니다."
		input_problem = "fishing_pack_json_invalid:"+parser.get_error_message()
		return false
	if not configure(parser.data): return false
	loaded_sha256 = digest
	model_input_identity = {"kind":"fishing_pack_file","file_payload_sha256":digest,
		"model_payload_sha256":model_input_identity.get("model_payload_sha256",""),"archive":{}}
	return true

const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BAKE_NAME := "fishing523_input"

func load_original() -> bool:
	# The built input is a pure function of the verified original and this
	# code; a later start reuses this device's baked build.
	var archive_sha: String = str(ORIGINAL.SOURCE.identity().get("source_sha256",""))
	var bake_key: String = BAKE.projection_key(BAKE_NAME, archive_sha) if not archive_sha.is_empty() else ""
	var baked: Variant = BAKE.read(BAKE_NAME, bake_key)
	var data: Dictionary = baked if baked is Dictionary and not (baked as Dictionary).is_empty() else {}
	var source = null
	if data.is_empty():
		source = ORIGINAL.new()
		data = source.build()
		if not data.is_empty(): BAKE.write(BAKE_NAME, bake_key, data)
	if data.is_empty():
		failure = "보유 원본523 낚시 입력을 연결할 수 없습니다: "+source.problem
		input_problem = source.problem
		unavailable_source_definitions = source.unavailable_source_definitions.duplicate(true)
		source_exclusion_evidence = source.source_exclusion_evidence.duplicate(true)
		return false
	if not configure(data): return false
	model_input_identity = data.input_identity.duplicate(true)
	loaded_sha256 = str(model_input_identity.model_payload_sha256)
	return true

func configure(data: Variant) -> bool:
	if not data is Dictionary or not ORIGINAL._integer(data.get("version")) or int(data.version) != 523 or not data.get("tables") is Dictionary:
		failure = "낚시 523 입력 형식이 다릅니다."
		input_problem = "fishing_model_schema_invalid"
		return false
	for key: String in ["Fish", "FishDistribution", "FishPoolProbability", "FishTerritory", "FishMiniGameDifficulty", "ExchangeSystemRule", "ExchangeSystemInput", "ExchangeSystemOutput", "ItemClass"]:
		if not data.tables.get(key) is Array:
			failure = "낚시 523 필수 표가 없습니다: "+key
			input_problem = "fishing_model_table_missing:"+key
			return false
	if not data.get("rods",{}) is Dictionary or not data.get("item_effects",{}) is Dictionary:
		failure = "낚시 523 낚싯대·아이템 입력 형식이 다릅니다."
		input_problem = "fishing_model_effect_shape_invalid"
		return false
	var staged_tables: Dictionary = data.tables.duplicate(true)
	for key: Variant in staged_tables:
		if not key is String or not staged_tables[key] is Array:
			failure = "낚시 523 표 배열 형식이 다릅니다."
			input_problem = "fishing_model_table_shape_invalid"
			return false
		for row: Variant in staged_tables[key]:
			if not row is Dictionary:
				failure = "낚시 523 원문 행 형식이 다릅니다."
				input_problem = "fishing_model_row_shape_invalid:"+str(key)
				return false
	var staged_items: Dictionary = {}
	for row: Dictionary in staged_tables.ItemClass:
		if not ORIGINAL._integer(row.get("ID")) or staged_items.has(str(int(row.ID))):
			failure = "낚시 523 아이템 정체가 없거나 중복됩니다."
			input_problem = "fishing_model_item_identity_invalid"
			return false
		staged_items[str(int(row.ID))] = row
	for key: String in ["raw_tables","raw_rods","raw_item_effects","source_effect_rows"]:
		if not data.get(key,{}) is Dictionary:
			failure = "낚시 523 원문 참조 형식이 다릅니다."
			input_problem = "fishing_model_raw_reference_invalid:"+key
			return false
	for key: String in ["unavailable_source_definitions","source_exclusion_evidence"]:
		if not data.get(key,[]) is Array:
			failure = "낚시 523 제외 근거 형식이 다릅니다."
			input_problem = "fishing_model_exclusion_shape_invalid:"+key
			return false
	# Shallow: only the top-level identity is left out of the hashed model.
	var payload: Dictionary = data.duplicate(false)
	payload.erase("input_identity")
	var hash = HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(JSON.stringify(payload).to_utf8_buffer()) != OK:
		failure = "낚시 523 모델 정체를 계산하지 못했습니다."
		input_problem = "fishing_model_payload_hash_unavailable"
		return false
	var digest: String = hash.finish().hex_encode()
	# Commit the complete candidate together; failures retain the prior registry.
	tables = staged_tables
	rods = data.get("rods",{}).duplicate(true)
	item_effects = data.get("item_effects",{}).duplicate(true)
	items = staged_items
	raw_tables = data.get("raw_tables",data.tables).duplicate(true)
	raw_rods = data.get("raw_rods",data.get("rods",{})).duplicate(true)
	raw_item_effects = data.get("raw_item_effects",data.get("item_effects",{})).duplicate(true)
	source_effect_rows = data.get("source_effect_rows",{}).duplicate(true)
	unavailable_source_definitions = data.get("unavailable_source_definitions",[]).duplicate(true)
	source_exclusion_evidence = data.get("source_exclusion_evidence",[]).duplicate(true)
	model_input_identity = {"kind":"direct_fishing_model","model_payload_sha256":digest,"archive":{},
		"model_payload_sha256_scope":"JSON.stringify(model_without_input_identity).to_utf8_buffer()"}
	loaded_sha256 = digest
	input_problem = ""
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

