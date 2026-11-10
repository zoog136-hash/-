extends RefCounted

## Read-only source catalogue. Static eligibility never authorizes execution.
const SCHEMA = "twilight.expedition523.v1"
const SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const P = "MagicDollExpedition"
const MAX_BYTES = 8 * 1024 * 1024
const SOURCE_ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BAKE_NAME := "expedition523_tables"
## Lineage M style: the validated tables live in a device record bake and are
## read on demand (whole table by "T|name", first row per ID by
## "R|name|id"); only a small LRU of recently read tables stays resident.
const RECORDS_BAKE_NAME := "expedition523_records"
const RECORDS_SCHEMA := "twilight.expedition523.records.v1"
const TABLE_CACHE_LIMIT: int = 4
const TABLE_NAMES = ["MagicDollExpeditionSpot","MagicDollExpeditionSpotAsset","MagicDollExpeditionGroup","MagicDollExpeditionSpotReward","MagicDollExpeditionSpotRewardType","MagicDollExpeditionCompleteRewardView","MagicDollExpeditionSpotEvent","MagicDollExpeditionEventView","MagicDollExpeditionBonus","MagicDollExpeditionBonusType","MagicDollExpeditionBuff","MagicDollExpeditionMonster","BuffCardExpeditionSynergy","BuffCardExpeditionSynergyCards","BuffCardExpeditionSynergyBonus","Grade","BuffCard","ConstantData","Reward","LuckyBagClass","LuckyBagEntityView","ItemClass","ItemBonus","Bonus","BonusType","Currency","CurrencyUnitClass"]
const ORIGINAL_CORE_SUFFIXES = ["Spot","SpotAsset","Group","SpotReward","SpotRewardType",
	"CompleteRewardView","SpotEvent","EventView","Bonus","BonusType","Buff","Monster"]
const ORIGINAL_SYNERGY = ["BuffCardExpeditionSynergy","BuffCardExpeditionSynergyCards","BuffCardExpeditionSynergyBonus"]
var _tables: Dictionary = {}
## Record bake of the loaded original tables (null: tables are resident).
var _stored_rows: RefCounted = null
var _stored_names: Dictionary = {}
var _table_cache: Dictionary = {}
var pack_sha256: String = ""
var error: String = "원본 탐험 데이터 팩을 설치하지 않았습니다."
var source_mode: String = ""
var source_identity: Dictionary = {}
var source_status: Dictionary = {}

func configure_arguments() -> bool:
	var path: String = ""
	var expected: String = ""
	var explicit_input := false
	for argument: String in OS.get_cmdline_user_args():
		if argument in ["--expedition523-pack","--expedition523-sha256"]: explicit_input = true
		if argument.begins_with("--expedition523-pack="):
			explicit_input = true; path = argument.trim_prefix("--expedition523-pack=")
		elif argument.begins_with("--expedition523-sha256="):
			explicit_input = true; expected = argument.trim_prefix("--expedition523-sha256=")
	# Explicit invalid/empty input is rejected by the original installer; it
	# cannot silently select a different raw source or replace a live catalogue.
	return install(path,expected) if explicit_input else load_original()

static func _source_selection(rows: Array, field: String, ids: Dictionary) -> Array:
	var selected: Array = []
	for row: Dictionary in rows:
		if ids.has(int(row.get(field,-1))): selected.append(row)
	return selected

## Rows of `table` whose `field` (as int()) is a key of `ids`, in original
## table order: exactly _source_selection(source.rows(table), field, ids),
## without building every row of the table as a Dictionary first.
## Bounded cost: one cached packed column of `field` (8 bytes per row for a
## numeric column; current523_definition_rows keeps it while the table is
## open) plus the selected rows. No relation index is built (no related()).
static func _select(source: Variant, table: String, field: String, ids: Dictionary) -> Array:
	var selected: Array = []
	if source.integer_field(table, field):
		# Every value is an integer, so the reader's _integer()+int() match is
		# the same predicate as int(row.get(field,-1)) over the same rows.
		selected.append_array(source.rows_matching(table, field, ids))
		return selected
	var count: int = source.row_count(table)
	var values: Variant = source.column(table, field)
	if values.size() == count:
		# Every row has the field; same int() of the same value per row.
		for index: int in count:
			if ids.has(int(values[index])): selected.append(source.row_at(table, index))
		return selected
	# Some row lacks the field (-1 like before): one row at a time.
	for index: int in count:
		var row: Dictionary = source.row_at(table, index)
		if ids.has(int(row.get(field,-1))): selected.append(row)
	return selected

## int(row.ID) of every row of `table` sorted, from the ID column only.
static func _sorted_ids(source: Variant, table: String) -> PackedInt64Array:
	var count: int = source.row_count(table)
	var values: Variant = source.column(table, "ID")
	var ids := PackedInt64Array()
	if values.size() == count:
		ids.resize(count)
		for index: int in count: ids[index] = int(values[index])
	else:
		for index: int in count: ids.append(int(source.row_at(table, index).ID))
	ids.sort()
	return ids

func _original_projection(source: Variant = SOURCE_ROWS) -> Dictionary:
	# Same source-order projection as build_expedition523_pack.py. This reads
	# MagicDoll expedition data; it introduces no pet aliases or new eligibility.
	# Cold path (no record bake): the large shared tables (ItemBonus, Bonus,
	# BonusType, ItemClass, LuckyBag*, Reward, Currency*) are never built as
	# whole Dictionary arrays; only the rows reachable from Spot/Reward are
	# read, by ID column (_select). Results, order and every rejection are
	# the same as the former whole-table filter (tests/expedition523_cold_
	# selection_test.gd compares both on synthetic tables).
	var t: Dictionary = {}
	for suffix: String in ORIGINAL_CORE_SUFFIXES: t[P+suffix] = source.rows(P+suffix)
	for name: String in ORIGINAL_SYNERGY + ["Grade","BuffCard"]: t[name] = source.rows(name)
	var constants: Array = []
	var constant_names: Variant = source.column("ConstantData", "Name")
	if constant_names.size() == source.row_count("ConstantData"):
		for index: int in constant_names.size():
			var constant_name: Variant = constant_names[index]
			if str(constant_name).contains("Expedition") or constant_name=="PolymorphDispatchLevel": constants.append(source.row_at("ConstantData", index))
	else:
		for row: Dictionary in source.rows("ConstantData"):
			if str(row.Name).contains("Expedition") or row.Name=="PolymorphDispatchLevel": constants.append(row)
	t["ConstantData"] = constants
	var reward_ids: Dictionary = {}
	var completion_reward_ids: Dictionary = {}
	for row: Dictionary in t[P+"SpotReward"]: reward_ids[int(row.RewardID)] = true
	for row: Dictionary in t[P+"CompleteRewardView"]:
		reward_ids[int(row.RewardID)] = true
		completion_reward_ids[int(row.RewardID)] = true
	t["Reward"] = _select(source,"Reward","ID",reward_ids)
	var item_ids: Dictionary = {}
	var completion_items: Dictionary = {}
	for row: Dictionary in t.Reward:
		if row.RewardTypeID==2: item_ids[int(row.RewardClassID)] = true
		if completion_reward_ids.has(int(row.ID)): completion_items[int(row.RewardClassID)] = true
	# Whole-table rule kept: any duplicate Bonus ID rejects the original. It
	# is checked over the ID column only (sorted int64), not over row objects.
	var all_bonus_ids: PackedInt64Array = _sorted_ids(source, "Bonus")
	for index: int in range(1, all_bonus_ids.size()):
		if all_bonus_ids[index] == all_bonus_ids[index - 1]:
			error = "원본 탐험 보너스 ID가 중복됩니다."
			return {}
	all_bonus_ids = PackedInt64Array()
	# Completion box links: ItemBonus rows of reward items that are also
	# completion items (the former loop skipped every other link), their
	# Bonus rows by ID (unique, checked above) and those bonuses' types.
	var completion_link_ids: Dictionary = {}
	for id: int in completion_items:
		if item_ids.has(id): completion_link_ids[id] = true
	var item_bonus: Array = _select(source,"ItemBonus","ItemClassID",completion_link_ids)
	var linked_bonus_ids: Dictionary = {}
	for link: Dictionary in item_bonus: linked_bonus_ids[int(link.BonusID)] = true
	var bonus_index: Dictionary = {}
	for row: Dictionary in _select(source,"Bonus","ID",linked_bonus_ids): bonus_index[int(row.ID)] = row
	var linked_type_ids: Dictionary = {}
	for row: Dictionary in bonus_index.values():
		if row.get("BonusTypeID") != null: linked_type_ids[int(row.BonusTypeID)] = true
	var bag_types: Dictionary = {}
	for row: Dictionary in _select(source,"BonusType","ID",linked_type_ids):
		if row.Name=="LuckyBagClassID" and row.UnitID==29: bag_types[int(row.ID)] = true
	var bag_ids: Dictionary = {}
	for link: Dictionary in item_bonus:
		if not completion_items.has(int(link.ItemClassID)): continue
		var bonus: Dictionary = bonus_index.get(int(link.BonusID),{})
		if bonus.is_empty():
			error = "원본 탐험 상자 보너스 연결이 없습니다."
			return {}
		if not bag_types.has(int(bonus.BonusTypeID)): continue
		var value: Variant = bonus.get("Value")
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value!=floorf(float(value)) or absf(float(value))>9007199254740991.0:
			error = "원본 탐험 상자 참조가 정수가 아닙니다."
			return {}
		bag_ids[int(value)] = true
	item_bonus = []
	bonus_index = {}
	t["LuckyBagClass"] = _select(source,"LuckyBagClass","ID",bag_ids)
	t["LuckyBagEntityView"] = _select(source,"LuckyBagEntityView","LuckyBagClassID",bag_ids)
	for row: Dictionary in t.LuckyBagEntityView: item_ids[int(row.ItemClassID)] = true
	t["ItemClass"] = _select(source,"ItemClass","ID",item_ids)
	t["ItemBonus"] = _select(source,"ItemBonus","ItemClassID",item_ids)
	var bonus_ids: Dictionary = {}
	for row: Dictionary in t.ItemBonus + t.BuffCardExpeditionSynergyBonus: bonus_ids[int(row.BonusID)] = true
	t["Bonus"] = _select(source,"Bonus","ID",bonus_ids)
	var type_ids: Dictionary = {}
	for row: Dictionary in t.Bonus: type_ids[int(row.BonusTypeID)] = true
	t["BonusType"] = _select(source,"BonusType","ID",type_ids)
	var currency_ids: Dictionary = {}
	for row: Dictionary in t[P+"Spot"]: currency_ids[int(row.ExpeditionCostCurrencyID)] = true
	for row: Dictionary in t[P+"Buff"]: currency_ids[int(row.CostCurrencyID)] = true
	t["Currency"] = _select(source,"Currency","ID",currency_ids)
	t["CurrencyUnitClass"] = _select(source,"CurrencyUnitClass","CurrencyID",currency_ids)
	return t

func load_original() -> bool:
	if ready(): return true
	var identity: Dictionary = SOURCE_ROWS.identity()
	if identity.is_empty():
		source_status = {"state":"unavailable","reason":SOURCE_ROWS.problem()}
		return false
	if identity.get("source_sha256")!=SOURCE_SHA256:
		error = "누적523 탐험 원본 정체가 다릅니다."
		return false
	# The projection is a pure function of the verified original and this
	# code; a later start reads this device's baked tables (still validated
	# and fingerprinted below) instead of reading whole Bonus/ItemBonus/
	# ItemClass/LuckyBagEntityView tables again (~0.6 GB transient).
	var records_key: String = BAKE.producer_key(RECORDS_BAKE_NAME, "expedition523", SCHEMA + "|" + RECORDS_SCHEMA, SOURCE_ROWS.verified_key())
	if _open_stored(records_key):
		source_mode = "original_rows"
		source_identity = identity.duplicate(true)
		source_status = {"state":"loaded","model_identity":"actual_in_memory_catalogue_payload"}
		error = ""
		return true
	var bake_key: String = BAKE.producer_key(BAKE_NAME, "expedition523", SCHEMA, SOURCE_ROWS.verified_key())
	var baked: Variant = BAKE.read(BAKE_NAME, bake_key)
	var from_bake: bool = baked is Dictionary and not (baked as Dictionary).is_empty()
	var candidate: Dictionary = baked if from_bake else _original_projection()
	if candidate.is_empty():
		source_status = {"state":"rejected","reason":error}
		return false
	if not _valid_tables(candidate):
		error = "탐험 원본 표 또는 참조가 기존 카탈로그 계약과 다릅니다."
		source_status = {"state":"rejected","reason":error}
		return false
	# Fingerprint the actual in-memory catalogue payload, not the source archive
	# and not an absent compiled file. No file, receipt or cache is generated.
	var payload: String = JSON.stringify({"schema":SCHEMA,"source_sha256":SOURCE_SHA256,
		"input_kind":"twilight.expedition523.original-rows.v1","tables":candidate},"",true,true)
	if payload.to_utf8_buffer().size()>MAX_BYTES:
		error = "탐험 원본 카탈로그 크기 초과"
		source_status = {"state":"rejected","reason":error}
		return false
	pack_sha256 = payload.sha256_text()
	payload = ""
	_release_stored()
	if _store_records(records_key, candidate):
		# The record bake now holds the same tables; the whole-table bake is
		# no longer read (a missing record bake rebuilds both).
		BAKE.clear(BAKE_NAME)
	else:
		# Storage fallback, bounded: the one validated candidate (fixed table
		# sizes checked by _valid_tables, JSON payload <= MAX_BYTES checked
		# above) stays resident as is. It is a private fresh value (bake read
		# or projection rows), so the former deep copy only doubled the peak;
		# rows()/record() still hand out copies.
		if not from_bake: BAKE.write(BAKE_NAME, bake_key, candidate)
		_tables = candidate
	source_mode = "original_rows"
	source_identity = identity.duplicate(true)
	source_status = {"state":"loaded","model_identity":"actual_in_memory_catalogue_payload"}
	error = ""
	return true

func install(path: String, expected_sha256: String) -> bool:
	# Validate a replacement independently; failure leaves the old catalogue alive.
	if expected_sha256.length() != 64 or not expected_sha256.is_valid_hex_number(false):
		error = "탐험 팩 SHA256이 필요합니다."
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		error = "탐험 팩 파일을 읽을 수 없습니다."
		return false
	var bytes := file.get_buffer(file.get_length())
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	if hash.finish().hex_encode() != expected_sha256.to_lower():
		error = "탐험 팩 SHA256이 다릅니다."
		return false
	var value = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary or value.get("schema") != SCHEMA or value.get("source_sha256") != SOURCE_SHA256:
		error = "누적523 탐험 팩 형식이 아닙니다."
		return false
	var candidate = value.get("tables")
	if not candidate is Dictionary or not _valid_tables(candidate):
		error = "탐험 팩의 표 또는 참조가 손상되었습니다."
		return false
	_release_stored()
	_tables = candidate.duplicate(true)
	pack_sha256 = expected_sha256.to_lower()
	source_mode = "compiled_pack"
	source_identity = {}
	source_status = {}
	error = ""
	return true

func _valid_tables(t: Dictionary) -> bool:
	for name in [P+"Spot", P+"SpotAsset", P+"Group", P+"SpotReward", P+"SpotRewardType", P+"CompleteRewardView", P+"SpotEvent", P+"EventView", P+"Bonus", P+"BonusType", P+"Buff", P+"Monster", "BuffCardExpeditionSynergy", "BuffCardExpeditionSynergyCards", "BuffCardExpeditionSynergyBonus", "Grade", "BuffCard", "ConstantData", "Reward", "LuckyBagClass", "LuckyBagEntityView", "ItemClass", "ItemBonus", "Bonus", "BonusType", "Currency", "CurrencyUnitClass"]:
		if not t.get(name) is Array:
			return false
		var ids := {}
		for row in t[name]:
			if not row is Dictionary:
				return false
			if row.has("ID"):
				var key := str(int(row.ID))
				if ids.has(key):
					return false
				ids[key] = true
	if t[P+"Spot"].size() != 29 or t[P+"Group"].size() != 30 or t[P+"SpotReward"].size() != 4487 or t[P+"CompleteRewardView"].size() != 290:
		return false
	var pools := {}
	var completion_pairs := {}
	for row: Dictionary in t[P+"SpotReward"] + t[P+"CompleteRewardView"]:
		var spot := _find(t, P+"Spot", int(row.get(P+"SpotID", -1)))
		var group := _find(t, P+"Group", int(row.get(P+"GroupID", -1)))
		if spot.is_empty() or group.is_empty() or spot.BuffCardDeckID != group.BuffCardDeckID or _find(t, "Reward", int(row.get("RewardID", -1))).is_empty():
			return false
		var pair := "%d:%d" % [int(spot.ID), int(group.ID)]
		if row.has("Probability"):
			if not row.Probability is float and not row.Probability is int:
				return false
			if float(row.Probability) < 0 or float(row.Probability) != floor(float(row.Probability)):
				return false
			pools[pair] = int(pools.get(pair, 0)) + int(row.Probability)
		else:
			if completion_pairs.has(pair) or row.get("GradeID") != group.GradeID or row.get("GroupMinLevel") != group.MinLevel or row.get("GroupMaxLevel") != group.MaxLevel:
				return false
			completion_pairs[pair] = true
	if pools.size() != 284 or completion_pairs.size() != 290:
		return false
	for weight in pools.values():
		if weight != 100000000:
			return false
	return true

## Writes `tables` (already validated) as a record bake and serves it from
## storage; false (tables stay resident) when storage is unavailable.
func _store_records(records_key: String, tables: Dictionary) -> bool:
	if records_key.is_empty(): return false
	var writer: RefCounted = BAKE.record_writer(RECORDS_BAKE_NAME, records_key)
	if writer == null: return false
	var names: Array = []
	for name: String in tables:
		if not tables[name] is Array: continue
		names.append(name)
		writer.add("T|" + name, tables[name])
		var seen: Dictionary = {}
		for row: Variant in tables[name]:
			if not row is Dictionary: continue
			# Same row record() found by its linear scan: the first one per ID.
			var id: String = str(int((row as Dictionary).get("ID", -1)))
			if seen.has(id): continue
			seen[id] = true
			writer.add("R|" + name + "|" + id, row)
	writer.add("M", {"schema":RECORDS_SCHEMA,"pack_sha256":pack_sha256,"tables":names})
	if not BAKE.finish_records(writer): return false
	return _open_stored(records_key)

## Serves the tables from a verified record bake; false when absent/stale.
func _open_stored(records_key: String) -> bool:
	if records_key.is_empty(): return false
	var records: RefCounted = BAKE.open_records(RECORDS_BAKE_NAME, records_key)
	if records == null: return false
	var meta: Variant = records.read("M")
	if not meta is Dictionary or meta.get("schema") != RECORDS_SCHEMA or not meta.get("pack_sha256") is String or (meta.pack_sha256 as String).length() != 64 or not meta.get("tables") is Array: return false
	var names: Dictionary = {}
	for name: Variant in meta.tables:
		if not name is String or not records.has("T|" + name): return false
		names[name] = true
	for name: String in TABLE_NAMES:
		if not names.has(name): return false
	_tables = {}
	_table_cache.clear()
	_stored_rows = records
	_stored_names = names
	pack_sha256 = meta.pack_sha256
	return true

func _release_stored() -> void:
	_stored_rows = null
	_stored_names = {}
	_table_cache.clear()

## The stored table (shared cache instance; callers copy it).
func _stored_table(name: String) -> Array:
	if not _stored_names.has(name): return []
	if _table_cache.has(name):
		var hit: Array = _table_cache[name]
		_table_cache.erase(name)
		_table_cache[name] = hit
		return hit
	var value: Variant = _stored_rows.read("T|" + name)
	var table: Array = value if value is Array else []
	_table_cache[name] = table
	while _table_cache.size() > TABLE_CACHE_LIMIT: _table_cache.erase(_table_cache.keys()[0])
	return table

## Drops the resident table cache (rows stay on storage).
func release() -> void:
	_table_cache.clear()

func ready() -> bool:
	return not _tables.is_empty() or _stored_rows != null

func rows(name: String) -> Array:
	if _stored_rows != null: return _stored_table(name).duplicate(true)
	return _tables.get(name, []).duplicate(true)

func _find(t: Dictionary, name: String, id: int) -> Dictionary:
	for row: Dictionary in t.get(name, []):
		if int(row.get("ID", -1)) == id:
			return row
	return {}

func record(name: String, id: int) -> Dictionary:
	if _stored_rows != null:
		if not _stored_names.has(name): return {}
		var value: Variant = _stored_rows.read("R|" + name + "|" + str(id))
		return value if value is Dictionary else {}
	return _find(_tables, name, id).duplicate(true)

func spots(deck: int = 0) -> Array:
	return rows(P+"Spot").filter(func(r: Dictionary) -> bool: return deck == 0 or int(r.BuffCardDeckID) == deck)

func _grade_value(id: int) -> int:
	return int(record("Grade", id).get("GradeValue", -1))

func inspect(spot_id: int, cards: Array = []) -> Dictionary:
	var spot := record(P+"Spot", spot_id)
	if spot.is_empty():
		return {"error": error if not ready() else "탐험 장소가 없습니다.", "can_start": false}
	var reasons: Array[String] = []
	var unknown: Array[String] = ["활성 조건·이벤트 추첨·진행/완료 처리가 미확정입니다."]
	if cards.size() != int(spot.CardCount):
		reasons.append("소유 카드 %d장이 필요합니다." % int(spot.CardCount))
	if int(spot.ServerLimitsetID) != 0:
		unknown.append("서버 제한 %d의 적용 여부가 미확정입니다." % int(spot.ServerLimitsetID))
	var group_id := 0
	var seen := {}
	for selection in cards:
		if not selection is Dictionary:
			reasons.append("카드 선택 형식이 잘못되었습니다.")
			continue
		var card_id := int(selection.get("source_id", 0))
		var card := record("BuffCard", card_id)
		if card.is_empty() or not bool(selection.get("owned", false)):
			reasons.append("소유가 확인된 원본 카드가 필요합니다.")
			continue
		if seen.has(card_id):
			reasons.append("같은 카드를 중복 선택할 수 없습니다.")
		seen[card_id] = true
		if int(card.BuffCardDeckID) != int(spot.BuffCardDeckID):
			reasons.append("카드 계열이 장소와 다릅니다.")
		if _grade_value(int(card.GradeID)) < _grade_value(int(spot.MinGrade)):
			reasons.append("장소의 최소 등급을 충족하지 않습니다.")
		if int(card.ServerLimitSetID) != 0 or int(card.StartDateTimeID) != 0 or int(card.EndDateTimeID) != 0:
			unknown.append("카드의 서버·기간 조건이 미확정입니다.")
		var level := int(selection.get("skill_awaken_level", 0))
		var match_id := 0
		for group: Dictionary in rows(P+"Group"):
			if int(group.BuffCardDeckID) == int(card.BuffCardDeckID) and int(group.GradeID) == int(card.GradeID) and level >= int(group.MinLevel) and level <= int(group.MaxLevel):
				match_id = int(group.ID)
		if match_id == 0:
			reasons.append("해당 원본 등급·스킬각성 레벨의 탐험 그룹이 없습니다.")
		if cards.size() == 1:
			group_id = match_id
	if cards.size() > 1:
		unknown.append("복수 카드의 대표 보상 그룹·시너지 판정 방식이 미확정입니다.")
	var detail := group_detail(spot_id, group_id)
	detail.merge({"spot": spot, "cards": cards.duplicate(true), "static_conditions_met": reasons.is_empty(), "reasons": reasons, "unknown": unknown, "can_start": false, "group_id": group_id}, true)
	return detail

func group_detail(spot_id: int, group_id: int) -> Dictionary:
	# Presence of these display rows is deliberately independent of eligibility.
	var event_rewards: Array = []
	var complete: Array = []
	var events: Array = []
	for row: Dictionary in rows(P+"SpotReward"):
		if int(row[P+"SpotID"]) == spot_id and int(row[P+"GroupID"]) == group_id:
			event_rewards.append(row)
	for row: Dictionary in rows(P+"CompleteRewardView"):
		if int(row[P+"SpotID"]) == spot_id and int(row[P+"GroupID"]) == group_id:
			var reward := record("Reward", int(row.RewardID))
			complete.append({"view": row, "reward": reward, "item": record("ItemClass", int(reward.get("RewardClassID", 0))), "box_candidates": completion_box_candidates(int(reward.get("RewardClassID", 0)))})
	for link: Dictionary in rows(P+"SpotEvent"):
		if int(link[P+"SpotID"]) == spot_id:
			var event := record(P+"EventView", int(link[P+"EventID"]))
			events.append({"link": link, "event": event, "bonus": record(P+"Bonus", int(event.get(P+"BonusID", 0)))})
	return {"event_rewards": event_rewards, "completion": complete, "events": events}

func completion_box_candidates(item_id: int) -> Array:
	var result: Array = []
	for item_bonus: Dictionary in rows("ItemBonus"):
		if int(item_bonus.ItemClassID) != item_id:
			continue
		var bonus := record("Bonus", int(item_bonus.BonusID))
		var kind := record("BonusType", int(bonus.get("BonusTypeID", 0)))
		if kind.get("Name") == "LuckyBagClassID" and int(kind.get("UnitID", 0)) == 29:
			for candidate: Dictionary in rows("LuckyBagEntityView"):
				if int(candidate.LuckyBagClassID) == int(bonus.Value):
					result.append(candidate)
	return result

func completion_contract(spot_id: int, group_id: int, expected_reward_id: int) -> Dictionary:
	var detail := group_detail(spot_id, group_id)
	if detail.completion.size() != 1:
		return {"ok": false, "error": "장소·출발 그룹의 완료 보상 연결이 없습니다."}
	var completion: Dictionary = detail.completion[0]
	var reward: Dictionary = completion.reward
	if int(reward.get("ID", 0)) != expected_reward_id or int(reward.get("RewardTypeID", 0)) != 2:
		return {"ok": false, "error": "출발 시 저장한 완료 RewardID와 원본 연결이 다릅니다."}
	var boxes: Array = []
	for link: Dictionary in rows("ItemBonus"):
		if int(link.ItemClassID) != int(reward.RewardClassID): continue
		var bonus := record("Bonus", int(link.BonusID))
		var kind := record("BonusType", int(bonus.get("BonusTypeID", 0)))
		if kind.get("Name") != "LuckyBagClassID" or int(kind.get("UnitID", 0)) != 29: continue
		var bag := record("LuckyBagClass", int(bonus.Value))
		var candidates: Array = []
		var raw_sum := 0
		for candidate: Dictionary in completion.box_candidates:
			if int(candidate.LuckyBagClassID) == int(bag.get("ID", -1)):
				candidates.append(candidate.duplicate(true))
				raw_sum += int(candidate.Probability)
		boxes.append({"item_bonus": link, "bonus": bonus, "bonus_type": kind, "bag": bag, "candidates": candidates, "raw_weight_sum": raw_sum})
	return {"ok": true, "completion_view": completion.view, "reward": reward, "item": completion.item, "boxes": boxes, "executable": false, "boundary": "완주 성공·지급 횟수·상자 개봉 실행 조건은 원본 정적 참조만으로 확정되지 않습니다."}

func synergy_evidence() -> Array:
	var result: Array = []
	for synergy: Dictionary in rows("BuffCardExpeditionSynergy"):
		var members: Array = []
		var effects: Array = []
		for card: Dictionary in rows("BuffCardExpeditionSynergyCards"):
			if int(card.BuffCardDispatchSynergyID) == int(synergy.ID):
				members.append(card)
		for link: Dictionary in rows("BuffCardExpeditionSynergyBonus"):
			if int(link.BuffCardDispatchSynergyID) == int(synergy.ID):
				var bonus := record("Bonus", int(link.BonusID))
				var buff := record(P+"Buff", int(bonus.get("Value", 0)))
				effects.append({"link": link, "bonus": bonus, "buff": buff, "effect": record(P+"Bonus", int(buff.get(P+"BonusID", 0)))})
		result.append({"synergy": synergy, "members": members, "effects": effects})
	return result

func request_start(_spot_id: int, _cards: Array) -> Dictionary:
	# No timer, currency transaction, reward, RNG, or save mutation is authorized
	# by a display table. Keep this gate explicit for future execution contracts.
	return {"ok": false, "reason": "원본 탐험의 활성·진행·추첨·완료 규칙이 미확정입니다."}
