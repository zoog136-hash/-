extends RefCounted
signal changed
## Exact source catalog plus confirmed per-character progress transactions.
## Credit attribution, reset schedule, stage accumulation and bonus stacking
## belong to the host's reviewed authority adapter, never inferred from enums.
const SCHEMA := "twilight.monsterbook523.v1"
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const Definitions = preload("res://scripts/resources/current523_definition_rows.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BAKE_NAME := "monsterbook523_payload"
const MAX_PACK_BYTES := 16 * 1024 * 1024
const TABLES := ["MonsterBook", "MonsterBookLevel", "MonsterBookLevelBonus", "MonsterBookLevelReward", "NpcClassForNpcGroup", "Bonus", "BonusType", "Reward", "RewardType", "Currency", "DateTimes_Korean", "Unit", "ItemClass", "DescData_Korean"]
const OPTIONAL_TABLES := ["ItemCategory", "Grade", "ItemBonus", "UIUnit", "BonusApplicationType", "SpecialResistanceType", "SelectReward", "SelectRewardEntity", "MarketPurchase_Korean", "MarketPurchaseProduct", "MarketProduct", "MarketProductAdditional", "MarketBonusForPurchase", "GotChaEntityView", "BuffCard", "IntangibleItemClass"]
var _tables: Dictionary = {}
var _indexes: Dictionary = {}
var _level_ids: Dictionary = {}
var _link_ids: Dictionary = {}
var _state: Dictionary = {"schema": 1, "books": {}}
var pack_sha: String = ""
var model_input_identity: Dictionary = {}
var last_error: String = ""
var _busy: bool = false

func _fail(reason: String) -> bool:
	last_error = reason
	return false

static func pack_arguments() -> Dictionary:
	var result: Dictionary = {"explicit":false,"path":"","sha256":""}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--monsterbook523-pack"):
			result.explicit = true
			if argument.begins_with("--monsterbook523-pack="): result.path = argument.trim_prefix("--monsterbook523-pack=")
		if argument.begins_with("--monsterbook523-sha256"):
			result.explicit = true
			if argument.begins_with("--monsterbook523-sha256="): result.sha256 = argument.trim_prefix("--monsterbook523-sha256=")
	return result

func load_pack(path: String, expected_sha: String) -> bool:
	if _busy:
		return _fail("transaction_in_progress")
	if expected_sha.length() != 64 or not FileAccess.file_exists(path):
		return _fail("missing_pack_or_digest")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_PACK_BYTES:
		return _fail("pack_size")
	var data := file.get_buffer(file.get_length())
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(data)
	if digest.finish().hex_encode() != expected_sha:
		return _fail("pack_digest")
	return _load_payload(data,expected_sha,{"kind":"twilight.monsterbook523.pack-input.v1","payload_sha256":expected_sha,"payload_bytes":data.size(),"declared_source_sha256":SOURCE_SHA})

func _source_rows(table: String, cache: Dictionary, evidence: Dictionary, issues: Array[String]) -> Array:
	if cache.has(table): return cache[table]
	var metadata: Dictionary = Definitions.table_metadata(table)
	var sha: Variant = metadata.get("sha256")
	if metadata.get("path") != "content/"+table+".json" or metadata.get("version") != 523 or not _integer(metadata.get("bytes")) or not _integer(metadata.get("row_count")) or not sha is String:
		issues.append("source_table_identity:"+table)
		return []
	if sha.length()!=64 or not sha.is_valid_hex_number(false):
		issues.append("source_table_digest:"+table)
		return []
	var values: Array = Definitions.rows(table)
	if values.size()!=int(metadata.row_count):
		issues.append("source_table_rows:"+table)
		return []
	cache[table] = values
	evidence[table] = {"bytes":metadata.bytes,"sha256":sha,"rows":values.size()}
	return values

func _source_ids(values: Array, field: String, issues: Array[String], omit_zero: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for value: Dictionary in values:
		if not _integer(value.get(field)):
			issues.append("source_integer:"+field)
			continue
		var id: int = int(value[field])
		if not omit_zero or id!=0: result[id] = true
	return result

func _source_filter(values: Array, field: String, ids: Dictionary) -> Array:
	var result: Array = []
	for value: Dictionary in values:
		if _integer(value.get(field)) and ids.has(int(value[field])): result.append(value)
	return result

func _source_select(table: String, ids: Dictionary, cache: Dictionary, evidence: Dictionary, issues: Array[String]) -> Array:
	var values: Array = _source_rows(table,cache,evidence,issues)
	var result: Array = _source_filter(values,"ID",ids)
	if _source_ids(result,"ID",issues).size()!=ids.size(): issues.append("source_missing_reference:"+table)
	return result

func _source_index(values: Array, issues: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for value: Dictionary in values:
		if not _integer(value.get("ID")):
			issues.append("source_integer:ID")
			continue
		result[int(value.ID)] = value
	return result

func load_original() -> bool:
	if loaded(): return true
	if _busy: return _fail("transaction_in_progress")
	if pack_arguments().explicit: return _fail("explicit_pack_input_required")
	var identity: Dictionary = Definitions.identity()
	if identity.is_empty() or identity.get("source_sha256") != SOURCE_SHA:
		return _fail("original_source_unavailable:"+Definitions.problem())
	# The projection is a pure function of the verified original and this code:
	# a later start loads the same payload bytes from this device's bake.
	var bake_key: String = BAKE.projection_key(BAKE_NAME, SOURCE_SHA)
	var baked: Dictionary = BAKE.read_payload(BAKE_NAME, bake_key)
	if not baked.is_empty() and baked.identity.get("archive") == identity:
		return _load_payload(baked.bytes, baked.sha256, baked.identity)
	# Exact full projection from tools/monsterbook523/build_pack.py. This builds
	# the existing model in memory; it does not reinterpret source authority.
	var cache: Dictionary = {}
	var evidence: Dictionary = {}
	var issues: Array[String] = []
	var tables: Dictionary = {}
	for table: String in ["MonsterBook","MonsterBookLevel","MonsterBookLevelBonus","MonsterBookLevelReward"]:
		tables[table] = _source_rows(table,cache,evidence,issues)
	var books: Array = tables.MonsterBook
	var groups: Dictionary = _source_ids(books,"NpcGroupID",issues,true)
	tables.NpcClassForNpcGroup = _source_filter(_source_rows("NpcClassForNpcGroup",cache,evidence,issues),"NpcGroupID",groups)
	var reward_ids: Dictionary = _source_ids(tables.MonsterBookLevelReward,"RewardID",issues)
	var reward_rows: Array = _source_rows("Reward",cache,evidence,issues)
	var rewards: Dictionary = _source_index(reward_rows,issues)
	var item_ids: Dictionary = {}
	for reward: Dictionary in reward_rows:
		if int(reward.RewardTypeID)==2 and reward_ids.has(int(reward.ID)): item_ids[int(reward.RewardClassID)] = true
	var current_books: Dictionary = _source_ids(_source_filter(books,"NpcGroupID",groups),"ID",issues)
	var current_levels: Array = _source_filter(tables.MonsterBookLevel,"MonsterBookID",current_books)
	var current_level_ids: Dictionary = _source_ids(current_levels,"ID",issues)
	var current_reward_ids: Dictionary = _source_ids(_source_filter(tables.MonsterBookLevelReward,"MonsterBookLevelID",current_level_ids),"RewardID",issues)
	var action_roots: Dictionary = {}
	for id: int in current_reward_ids:
		var reward: Dictionary = rewards.get(id,{})
		if reward.is_empty(): return _fail("source_missing_reference:Reward")
		if int(reward.RewardTypeID)==2: action_roots[int(reward.RewardClassID)] = true
	var bonuses: Dictionary = _source_index(_source_rows("Bonus",cache,evidence,issues),issues)
	var types: Dictionary = _source_index(_source_rows("BonusType",cache,evidence,issues),issues)
	var pending: Array = action_roots.keys()
	var visited: Dictionary = {}
	var select_ids: Dictionary = {}
	var market_ids: Dictionary = {}
	var intangible_ids: Dictionary = {}
	while not pending.is_empty():
		var item_id: int = int(pending.pop_back())
		if visited.has(item_id): continue
		visited[item_id] = true
		for link: Dictionary in _source_rows("ItemBonus",cache,evidence,issues):
			if int(link.ItemClassID)!=item_id: continue
			var bonus: Dictionary = bonuses.get(int(link.BonusID),{})
			var type: Dictionary = types.get(int(bonus.get("BonusTypeID",-1)),{})
			if bonus.is_empty() or type.is_empty(): return _fail("source_missing_reference:ItemBonus")
			var kind: String = str(type.Name)
			if kind not in ["MarketPurchaseID","IntangibleItemClassID","SelectRewardClassID"]: continue
			if not _integer(bonus.get("Value")): return _fail("source_integer:Bonus.Value")
			var target: int = int(bonus.Value)
			if kind=="MarketPurchaseID": market_ids[target] = true
			elif kind=="IntangibleItemClassID": intangible_ids[target] = true
			else:
				var parent: Dictionary = rewards.get(target,{})
				if parent.is_empty() or int(parent.RewardTypeID)!=111: return _fail("source_selection_reward_type")
				reward_ids[int(parent.ID)] = true
				select_ids[int(parent.RewardClassID)] = true
				for entity: Dictionary in _source_rows("SelectRewardEntity",cache,evidence,issues):
					if int(entity.SelectRewardID)!=int(parent.RewardClassID): continue
					var child: Dictionary = rewards.get(int(entity.RewardID),{})
					if child.is_empty(): return _fail("source_missing_reference:Reward")
					reward_ids[int(child.ID)] = true
					if int(child.RewardTypeID)==2:
						item_ids[int(child.RewardClassID)] = true
						pending.append(int(child.RewardClassID))
	tables.SelectReward = _source_select("SelectReward",select_ids,cache,evidence,issues)
	tables.SelectRewardEntity = _source_filter(_source_rows("SelectRewardEntity",cache,evidence,issues),"SelectRewardID",select_ids)
	tables.MarketPurchase_Korean = _source_select("MarketPurchase_Korean",market_ids,cache,evidence,issues)
	tables.MarketPurchaseProduct = _source_filter(_source_rows("MarketPurchaseProduct",cache,evidence,issues),"MarketPurchaseID",market_ids)
	var product_ids: Dictionary = _source_ids(tables.MarketPurchaseProduct,"MarketProductID",issues)
	tables.MarketProduct = _source_select("MarketProduct",product_ids,cache,evidence,issues)
	tables.MarketProductAdditional = _source_filter(_source_rows("MarketProductAdditional",cache,evidence,issues),"MarketProductID",product_ids)
	tables.MarketBonusForPurchase = _source_filter(_source_rows("MarketBonusForPurchase",cache,evidence,issues),"MarketPurchaseID",market_ids)
	var gotcha_ids: Dictionary = {}
	for product: Dictionary in tables.MarketProduct:
		if int(product.UnitID)==35: gotcha_ids[int(product.ClassID)] = true
	tables.GotChaEntityView = _source_filter(_source_rows("GotChaEntityView",cache,evidence,issues),"GotChaClassID",gotcha_ids)
	var card_ids: Dictionary = {}
	for entity: Dictionary in tables.GotChaEntityView:
		if int(entity.UnitID)==33: card_ids[int(entity.ClassID)] = true
	tables.BuffCard = _source_select("BuffCard",card_ids,cache,evidence,issues)
	tables.IntangibleItemClass = _source_select("IntangibleItemClass",intangible_ids,cache,evidence,issues)
	tables.ItemBonus = _source_filter(_source_rows("ItemBonus",cache,evidence,issues),"ItemClassID",item_ids)
	var bonus_ids: Dictionary = _source_ids(tables.MonsterBookLevelBonus,"BonusID",issues)
	bonus_ids.merge(_source_ids(tables.ItemBonus,"BonusID",issues),true)
	tables.Bonus = _source_select("Bonus",bonus_ids,cache,evidence,issues)
	tables.BonusType = _source_select("BonusType",_source_ids(tables.Bonus,"BonusTypeID",issues),cache,evidence,issues)
	tables.BonusApplicationType = _source_select("BonusApplicationType",_source_ids(tables.Bonus,"BonusApplicationTypeID",issues),cache,evidence,issues)
	var resistance_ids: Dictionary = {}
	for bonus: Dictionary in tables.Bonus:
		if int(bonus.BonusApplicationTypeID)==2: resistance_ids[int(bonus.BonusApplicationTargetID)] = true
	tables.SpecialResistanceType = _source_select("SpecialResistanceType",resistance_ids,cache,evidence,issues)
	tables.Reward = _source_select("Reward",reward_ids,cache,evidence,issues)
	tables.RewardType = _source_select("RewardType",_source_ids(tables.Reward,"RewardTypeID",issues),cache,evidence,issues)
	var unit_ids: Dictionary = _source_ids(tables.BonusType,"UnitID",issues)
	unit_ids.merge(_source_ids(tables.MarketProduct,"UnitID",issues),true)
	unit_ids.merge(_source_ids(tables.GotChaEntityView,"UnitID",issues),true)
	tables.Unit = _source_select("Unit",unit_ids,cache,evidence,issues)
	tables.UIUnit = _source_filter(_source_rows("UIUnit",cache,evidence,issues),"UnitID",_source_ids(tables.Unit,"ID",issues))
	tables.ItemClass = _source_select("ItemClass",item_ids,cache,evidence,issues)
	tables.ItemCategory = _source_select("ItemCategory",_source_ids(tables.ItemClass,"CategoryID",issues),cache,evidence,issues)
	var grade_ids: Dictionary = _source_ids(tables.ItemClass,"GradeID",issues)
	grade_ids.merge(_source_ids(tables.BuffCard,"GradeID",issues),true)
	tables.Grade = _source_select("Grade",grade_ids,cache,evidence,issues)
	tables.Currency = _source_select("Currency",_source_ids(tables.MonsterBookLevel,"CurrencyID",issues,true),cache,evidence,issues)
	var date_ids: Dictionary = {}
	for field: String in ["StartDateTimeID","CountingEndDateTimeID","EndDateTimeID"]:
		date_ids.merge(_source_ids(books,field,issues,true),true)
	for bonus: Dictionary in tables.Bonus:
		if int(bonus.BonusApplicationTypeID)==298 and int(bonus.BonusApplicationTargetID)!=0: date_ids[int(bonus.BonusApplicationTargetID)] = true
	tables.DateTimes_Korean = _source_select("DateTimes_Korean",date_ids,cache,evidence,issues)
	var desc_ids: Dictionary = {}
	for table: String in ["BonusType","RewardType","Currency","ItemClass","ItemCategory","Grade","SpecialResistanceType","IntangibleItemClass","BuffCard"]:
		for row: Dictionary in tables[table]:
			if row.get("DescID"):
				if not _integer(row.DescID): return _fail("source_integer:DescID")
				desc_ids[int(row.DescID)] = true
	tables.DescData_Korean = _source_select("DescData_Korean",desc_ids,cache,evidence,issues)
	if not issues.is_empty(): return _fail(issues[0])
	if current_levels.size()!=97: return _fail("source_stage_count")
	var model: Dictionary = {"schema":SCHEMA,"source_sha256":SOURCE_SHA,"source_tables":evidence,"tables":tables}
	var data: PackedByteArray = JSON.stringify(model,"",false,true).to_utf8_buffer()
	if data.size()>MAX_PACK_BYTES: return _fail("pack_size")
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(data)
	var actual: String = digest.finish().hex_encode()
	var input_identity: Dictionary = {"kind":"twilight.monsterbook523.original-input.v1","archive":identity,"payload_sha256":actual,"payload_bytes":data.size(),"projection":"tools/monsterbook523/build_pack.py"}
	BAKE.write(BAKE_NAME, bake_key, {"bytes":data,"sha256":actual,"identity":input_identity})
	return _load_payload(data,actual,input_identity)

func _load_payload(data: PackedByteArray, expected_sha: String, input_identity: Dictionary) -> bool:
	var parser := JSON.new()
	if parser.parse(data.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _fail("pack_json")
	var model: Dictionary = parser.data
	if model.get("schema") != SCHEMA or model.get("source_sha256") != SOURCE_SHA or not model.get("tables") is Dictionary:
		return _fail("pack_source")
	var tables: Dictionary = model.tables
	var indexes: Dictionary = {}
	for table: String in TABLES + OPTIONAL_TABLES:
		if table in OPTIONAL_TABLES and not tables.has(table): continue
		if not tables.get(table) is Array:
			return _fail("missing_table:" + table)
		var index: Dictionary = {}
		for raw: Variant in tables[table]:
			if not raw is Dictionary:
				return _fail("invalid_row:" + table)
			if table != "NpcClassForNpcGroup":
				if not _integer(raw.get("ID")) or index.has(int(raw.ID)):
					return _fail("invalid_identity:" + table)
				index[int(raw.ID)] = raw
		indexes[table] = index
	if not _validate_catalog(tables, indexes):
		return _fail("catalog_relationships")
	_tables = tables.duplicate(true)
	_indexes = indexes.duplicate(true)
	_level_ids.clear()
	_link_ids.clear()
	for level: Dictionary in _tables.MonsterBookLevel:
		var book_id: int = int(level.MonsterBookID)
		if not _level_ids.has(book_id): _level_ids[book_id] = []
		_level_ids[book_id].append(int(level.ID))
	for pair: Array in [["MonsterBookLevelBonus","BonusID"],["MonsterBookLevelReward","RewardID"]]:
		var links: Dictionary = {}
		for link: Dictionary in _tables[pair[0]]:
			var level_id: int = int(link.MonsterBookLevelID)
			if not links.has(level_id): links[level_id] = []
			links[level_id].append(int(link[pair[1]]))
		_link_ids[pair[0]] = links
	pack_sha = expected_sha
	model_input_identity = input_identity.duplicate(true)
	last_error = ""
	changed.emit()
	return true

func _validate_catalog(tables: Dictionary, ix: Dictionary) -> bool:
	var current: int = 0
	var groups: Dictionary = {}
	for book: Dictionary in tables.MonsterBook:
		for key: String in ["NpcGroupID", "ResetType", "CountConditionTypeID", "ServerLimitSetID", "StartDateTimeID", "EndDateTimeID", "CountingEndDateTimeID"]:
			if not _integer(book.get(key)):
				return false
		for key: String in ["StartDateTimeID", "EndDateTimeID", "CountingEndDateTimeID"]:
			if int(book[key]) != 0 and not ix.DateTimes_Korean.has(int(book[key])):
				return false
		if int(book.NpcGroupID) != 0:
			current += 1
			groups[int(book.NpcGroupID)] = true
	for level: Dictionary in tables.MonsterBookLevel:
		if not ix.MonsterBook.has(int(level.get("MonsterBookID", -1))) or not _integer(level.get("Amount")) or not _integer(level.get("CurrencyCost")) or not _integer(level.get("CurrencyID")):
			return false
		if int(level.CurrencyID) != 0 and not ix.Currency.has(int(level.CurrencyID)):
			return false
	for pair: Array in [["MonsterBookLevelBonus", "BonusID", "Bonus"], ["MonsterBookLevelReward", "RewardID", "Reward"]]:
		for link: Dictionary in tables[pair[0]]:
			if not ix.MonsterBookLevel.has(int(link.get("MonsterBookLevelID", -1))) or not ix[pair[2]].has(int(link.get(pair[1], -1))):
				return false
	for member: Dictionary in tables.NpcClassForNpcGroup:
		if not _integer(member.get("NpcClassID")) or not _integer(member.get("ServerLimitSetID")) or not groups.has(int(member.get("NpcGroupID", -1))):
			return false
	return tables.MonsterBook.size() == 557 and current == 33 and tables.NpcClassForNpcGroup.size() == 944

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0.0 and float(value) <= 9007199254740991.0

func loaded() -> bool:
	return not _tables.is_empty()

func books(current_only: bool = true) -> Array:
	var result: Array = []
	for book: Dictionary in _tables.get("MonsterBook", []):
		if not current_only or int(book.NpcGroupID) != 0:
			result.append(book.duplicate(true))
	return result

func row(table: String, id: int) -> Dictionary:
	return _indexes.get(table, {}).get(id, {}).duplicate(true)

func target_books(npc_class_id: int) -> Array:
	var groups: Dictionary = {}
	for member: Dictionary in _tables.get("NpcClassForNpcGroup", []):
		if int(member.NpcClassID) == npc_class_id:
			groups[int(member.NpcGroupID)] = true
	var result: Array = []
	for book: Dictionary in books():
		if groups.has(int(book.NpcGroupID)):
			result.append(book)
	return result

func levels(book_id: int) -> Array:
	var result: Array = []
	for id: int in _level_ids.get(book_id,[]):
		var view := row("MonsterBookLevel",id)
		view["bonuses"] = _linked("MonsterBookLevelBonus",id,"BonusID","Bonus")
		view["rewards"] = _linked("MonsterBookLevelReward",id,"RewardID","Reward")
		result.append(view)
	return result

func _linked(table: String, level_id: int, _field: String, target: String) -> Array:
	var result: Array = []
	for id: int in _link_ids.get(table,{}).get(level_id,[]): result.append(row(target,id))
	return result

func raw_period(book_id: int) -> Dictionary:
	var book := row("MonsterBook", book_id)
	var result: Dictionary = {}
	for key: String in ["StartDateTimeID", "CountingEndDateTimeID", "EndDateTimeID"]:
		result[key] = row("DateTimes_Korean", int(book.get(key, 0)))
	return result

func export_state() -> Dictionary:
	return _state.duplicate(true)

func source_items() -> Dictionary:
	return _state.get("source_items",{}).duplicate(true)

## Validate independently of pack availability; preserve historical/unknown IDs,
## epochs and extension fields. Never erase state because an optional pack is absent.
func import_state(value: Variant) -> bool:
	if _busy or not valid_state(value):
		return _fail("invalid_state")
	_state = value.duplicate(true)
	# Godot JSON numbers are floats. Canonicalize only this schema's integral
	# fields so registered/claimed IDs still match integer UI/receipt IDs after
	# a real save round trip; preserve all unknown extension fields untouched.
	_state.schema = 1
	if _state.has("item_actions"):
		for id: Variant in _state.item_actions.get("used",{}): _state.item_actions.used[id] = int(_state.item_actions.used[id])
		for field: String in ["schema","sequence","last_source_item"]:
			if _state.item_actions.has(field): _state.item_actions[field] = int(_state.item_actions[field])
		for result: Dictionary in _state.item_actions.get("last_results",[]):
			for field: String in ["card_id","amount"]:
				if result.has(field): result[field] = int(result[field])
	for record: Dictionary in _state.get("expired_items",{}).values(): record.quantity = int(record.quantity)
	if _state.has("local_economy"):
		for field: String in ["schema","gems","acquired","spent"]: _state.local_economy[field] = int(_state.local_economy[field])
	for record: Dictionary in _state.get("source_items",{}).values():
		for field: String in ["source_item_class_id","weight","price"]:
			record[field] = int(record[field])
	for book: Dictionary in _state.books.values():
		book.sequence = int(book.sequence)
		for progress_value: Dictionary in book.epochs.values():
			for conversion: Dictionary in progress_value.get("reward_conversions",{}).values():
				for field: String in ["source_amount","local_exp","numerator","denominator"]: conversion[field] = int(conversion[field])
			for field: String in ["kill_count", "first_stage_kill_count"]:
				if progress_value.has(field): progress_value[field] = int(progress_value[field])
			for id: Variant in progress_value.counts:
				progress_value.counts[id] = int(progress_value.counts[id])
			for field: String in ["registered", "claimed", "effective_levels", "reward_claims"]:
				if not progress_value.has(field): continue
				var canonical: Array = []
				for id: Variant in progress_value[field]: canonical.append(int(id))
				progress_value[field] = canonical
	changed.emit()
	return true

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 1 or not value.get("books") is Dictionary:
		return false
	if value.has("item_actions"):
		var ledger: Variant = value.item_actions
		if not ledger is Dictionary or ledger.get("schema") != 1 or not _integer(ledger.get("sequence")) or not ledger.get("last_results") is Array or ledger.last_results.size() > 100: return false
		if ledger.has("rng_state") and (not ledger.rng_state is String or not ledger.rng_state.is_valid_int()): return false
		if ledger.has("last_source_item") and not _integer(ledger.last_source_item): return false
		if ledger.has("last_clock") and (not ledger.last_clock is String or not valid_clock(ledger.last_clock)): return false
		if ledger.has("used"):
			if not ledger.used is Dictionary: return false
			for id: Variant in ledger.used:
				if not str(id).is_valid_int() or int(str(id)) <= 0 or not _integer(ledger.used[id]): return false
		for result: Variant in ledger.last_results:
			if not result is Dictionary: return false
			for field: String in ["card_id","amount"]:
				if result.has(field) and not _integer(result[field]): return false
	if value.has("expired_items"):
		if not value.expired_items is Dictionary: return false
		for name: Variant in value.expired_items:
			var archived: Variant = value.expired_items[name]
			if not name is String or not archived is Dictionary or not _integer(archived.get("quantity")) or not archived.get("sourceId") is String or not archived.get("delete_clock") is String or not valid_clock(archived.delete_clock): return false
	if value.has("local_economy"):
		var wallet: Variant = value.local_economy
		if not wallet is Dictionary or wallet.get("schema") != 1 or wallet.get("provenance") != "twilight_custom_internal_gems_v1": return false
		for field: String in ["gems","acquired","spent"]:
			if not _integer(wallet.get(field)): return false
		if int(wallet.gems) + int(wallet.spent) != int(wallet.acquired): return false
	if value.has("source_items"):
		if not value.source_items is Dictionary: return false
		for name: Variant in value.source_items:
			if not name is String or not preload("res://scripts/monsterbook/monsterbook523_items.gd").valid_record(name,value.source_items[name]): return false
	for key: Variant in value.books:
		if not str(key).is_valid_int() or int(str(key)) <= 0:
			return false
		var book: Variant = value.books[key]
		if not book is Dictionary or not _integer(book.get("sequence")) or not book.get("epochs") is Dictionary or not book.get("current_epoch") is String:
			return false
		if book.has("max_clock") and (not book.max_clock is String or not valid_clock(book.max_clock)): return false
		if not book.epochs.has(book.current_epoch):
			return false
		for epoch: Variant in book.epochs:
			if not epoch is String or epoch.is_empty():
				return false
			var progress: Variant = book.epochs[epoch]
			if not progress is Dictionary or not progress.get("counts") is Dictionary:
				return false
			for id: Variant in progress.counts:
				if not str(id).is_valid_int() or int(str(id)) <= 0 or not _integer(progress.counts[id]):
					return false
			for optional: String in ["kill_count", "first_stage_kill_count"]:
				if progress.has(optional) and not _integer(progress[optional]): return false
			if progress.has("counter_policy") and progress.counter_policy not in ["manual","per_stage","cumulative"]: return false
			if progress.has("bonus_policy") and progress.bonus_policy not in ["manual","cumulative","latest"]: return false
			if progress.has("reward_conversions"):
				if not progress.reward_conversions is Dictionary: return false
				for id: Variant in progress.reward_conversions:
					if not str(id).is_valid_int() or int(str(id)) <= 0: return false
					var conversion: Variant = progress.reward_conversions[id]
					if not conversion is Dictionary or not conversion.get("provenance") is String: return false
					for field: String in ["source_amount","local_exp","numerator","denominator"]:
						if not _integer(conversion.get(field)) or int(conversion[field]) <= 0: return false
			for field: String in ["registered", "claimed", "effective_levels", "reward_claims"]:
				if field == "reward_claims" and not progress.has(field): continue
				if not progress.get(field) is Array:
					return false
				var seen: Dictionary = {}
				for id: Variant in progress[field]:
					if not _integer(id) or int(id) <= 0 or seen.has(int(id)):
						return false
					seen[int(id)] = true
			for id: Variant in progress.claimed + progress.effective_levels:
				if not progress.registered.has(id):
					return false
	return true

func progress(book_id: int) -> Dictionary:
	var saved: Dictionary = _state.books.get(str(book_id), {})
	return saved.get("epochs", {}).get(saved.get("current_epoch", ""), {}).duplicate(true)

func _clock(date: Dictionary) -> String:
	if date.is_empty():
		return ""
	return "%04d%02d%02d%02d%02d" % [date.Year, date.Month, date.Day, date.Hour, date.Minute]

static func valid_clock(clock: String) -> bool:
	return preload("res://scripts/monsterbook/monsterbook523_clock.gd").valid(clock)

func _within(book_id: int, clock: String, end_key: String) -> bool:
	if not valid_clock(clock):
		return false
	var period := raw_period(book_id)
	var start := _clock(period.StartDateTimeID)
	var end := _clock(period[end_key])
	return not start.is_empty() and not end.is_empty() and clock >= start and clock < end

## commit(before, proposed, raw_quote) must durably settle the quoted original
## cost/rewards AND the proposed state atomically. False leaves this service intact.
## No default authority or economy conversion is provided for unconfirmed rules.
func apply_confirmed(receipt: Dictionary, commit: Callable) -> bool:
	if _busy or not loaded() or not commit.is_valid():
		return _fail("adapter_unavailable")
	if receipt.get("authority", "") == "" or receipt.get("approved") != true or receipt.get("server_allowed") != true or receipt.get("clock_locale") != "Korean":
		return _fail("authority_required")
	if not _integer(receipt.get("book_id")) or not _integer(receipt.get("sequence")):
		return _fail("receipt_identity")
	var book_id := int(receipt.book_id)
	var book := row("MonsterBook", book_id)
	if book.is_empty() or int(book.NpcGroupID) == 0:
		return _fail("unresolved_target_group")
	var proposed := export_state()
	var saved: Dictionary = proposed.books.get(str(book_id), {"sequence": 0, "current_epoch": "", "epochs": {}})
	if int(receipt.sequence) != int(saved.sequence) + 1:
		return _fail("receipt_sequence")
	var epoch: String = str(receipt.get("epoch", ""))
	var action: String = str(receipt.get("action", ""))
	var clock: String = str(receipt.get("source_clock", ""))
	if not valid_clock(clock): return _fail("source_clock_required")
	if epoch.is_empty():
		return _fail("epoch_required")
	if receipt.get("protect_clock", false) and str(saved.get("max_clock", "")) > clock: return _fail("clock_rollback")
	if action in ["count","instant_complete"] and receipt.get("start_epoch", false):
		if receipt.get("reset_approved") != true or saved.epochs.has(epoch): return _fail("reset_not_confirmed")
		saved.epochs[epoch] = {"counts": {}, "registered": [], "claimed": [], "effective_levels": [], "reward_claims": [], "kill_count": 0}
		saved.current_epoch = epoch
	if action == "begin_epoch":
		if receipt.get("reset_approved") != true or saved.epochs.has(epoch) or not _within(book_id, clock, "CountingEndDateTimeID"):
			return _fail("reset_not_confirmed")
		saved.epochs[epoch] = {"counts": {}, "registered": [], "claimed": [], "effective_levels": []}
		saved.current_epoch = epoch
	elif saved.current_epoch != epoch:
		return _fail("inactive_epoch")
	var stage: Dictionary = saved.epochs.get(epoch, {})
	var quote: Dictionary = {"action": action, "book_id": book_id, "epoch": epoch, "pack_sha256": pack_sha, "authority": receipt.authority, "source_clock": clock}
	match action:
		"begin_epoch": pass
		"count":
			if not _within(book_id, clock, "CountingEndDateTimeID") or not _integer(receipt.get("npc_class_id")):
				return _fail("count_period_or_identity")
			var matches: bool = false
			for candidate: Dictionary in target_books(int(receipt.npc_class_id)):
				matches = matches or int(candidate.ID) == book_id
			if not matches or not receipt.get("level_ids") is Array or (receipt.level_ids.is_empty() and receipt.get("track_only") != true):
				return _fail("count_target_or_stages")
			var supplied: Dictionary = {}
			for id: Variant in receipt.level_ids:
				if not _level_belongs(id,book_id) or supplied.has(int(id)): return _fail("count_stage_identity")
				supplied[int(id)] = true
			stage["kill_count"] = int(stage.get("kill_count", 0)) + 1
			if receipt.get("progression_policy") in ["per_stage","cumulative"]:
				_apply_progression(stage,book_id,receipt)
				quote["progression_policy"] = stage.counter_policy
			else:
				var seen: Dictionary = {}
				for id: Variant in receipt.level_ids:
					if not _level_belongs(id, book_id) or seen.has(int(id)):
						return _fail("count_stage_identity")
					seen[int(id)] = true
					var key := str(int(id))
					stage.counts[key] = int(stage.counts.get(key, 0)) + 1
				# Existing host credited deaths can complete the unambiguous first stage.
				# The original CurrencyCost is preserved; no Gem payment is inferred.
				var achieved: int = int(receipt.get("achieve_level_id", 0))
				if achieved > 0 and _level_belongs(achieved, book_id) and int(row("MonsterBookLevel", achieved).get("Level", 0)) == 1 and int(stage.counts.get(str(achieved), 0)) >= int(row("MonsterBookLevel", achieved).Amount) and not stage.registered.has(achieved):
					stage.registered.append(achieved)
					if stage.effective_levels.is_empty(): stage.effective_levels = [achieved]
					stage["first_stage_kill_count"] = int(stage.kill_count)
					quote["auto_achieved"] = achieved
		"achieve":
			var level_id: Variant = receipt.get("level_id")
			if not _level_belongs(level_id, book_id) or not _within(book_id, clock, "CountingEndDateTimeID") or int(stage.counts.get(str(int(level_id)), 0)) < int(row("MonsterBookLevel", int(level_id)).Amount) or stage.registered.has(level_id): return _fail("achievement_not_eligible")
			if int(row("MonsterBookLevel",int(level_id)).Level) > 1 and receipt.get("progression_policy") not in ["per_stage","cumulative"]: return _fail("progression_policy_required")
			for prior: Dictionary in levels(book_id):
				if int(prior.Level) < int(row("MonsterBookLevel",int(level_id)).Level) and not stage.registered.has(int(prior.ID)): return _fail("prior_stage_required")
			stage.registered.append(int(level_id))
			if stage.effective_levels.is_empty(): stage.effective_levels = [int(level_id)]
			_apply_bonus_policy(stage,book_id,receipt)
		"instant_complete":
			var level_id: Variant = receipt.get("level_id")
			if not _level_belongs(level_id,book_id) or stage.registered.has(level_id) or not _within(book_id,clock,"CountingEndDateTimeID"): return _fail("instant_not_eligible")
			var level := row("MonsterBookLevel",int(level_id))
			# Complete exactly the paid stage. Never fabricate kill credit.
			for prior: Dictionary in levels(book_id):
				if int(prior.Level) < int(level.Level) and not stage.registered.has(int(prior.ID)): return _fail("prior_stage_required")
			var wallet: Dictionary = proposed.get("local_economy",{})
			if int(level.CurrencyID) != 4 or row("Currency",int(level.CurrencyID)).get("Name") != "Gem" or int(level.CurrencyCost) <= 0 or int(wallet.get("gems",0)) < int(level.CurrencyCost): return _fail("instant_gems_required")
			wallet.gems = int(wallet.gems) - int(level.CurrencyCost)
			wallet.spent = int(wallet.spent) + int(level.CurrencyCost)
			proposed.local_economy = wallet
			stage.registered.append(int(level_id))
			quote["level"] = level
			quote["currency"] = row("Currency",int(level.CurrencyID))
			_apply_bonus_policy(stage,book_id,receipt)
		"claim_rewards":
			var level_id: Variant = receipt.get("level_id")
			if not _level_belongs(level_id, book_id) or not stage.registered.has(level_id) or stage.claimed.has(level_id) or receipt.get("claim_window_approved") != true or not receipt.get("reward_ids") is Array or receipt.reward_ids.is_empty(): return _fail("claim_not_eligible")
			var all_rewards := _linked("MonsterBookLevelReward", int(level_id), "RewardID", "Reward")
			var requested: Dictionary = {}
			var paid: Array = stage.get("reward_claims", []).duplicate()
			var rewards: Array = []
			for id: Variant in receipt.reward_ids:
				if not _integer(id) or requested.has(int(id)) or paid.has(int(id)): return _fail("reward_already_claimed")
				requested[int(id)] = true
			for reward: Dictionary in all_rewards:
				if requested.has(int(reward.ID)):
					rewards.append(reward)
					paid.append(int(reward.ID))
			if rewards.size() != requested.size(): return _fail("reward_identity")
			stage["reward_claims"] = paid
			var complete: bool = true
			for reward: Dictionary in all_rewards: complete = complete and paid.has(int(reward.ID))
			if complete: stage.claimed.append(int(level_id))
			quote["level"] = row("MonsterBookLevel", int(level_id))
			quote["rewards"] = rewards
			if receipt.has("reward_conversions"):
				if not receipt.reward_conversions is Dictionary: return _fail("reward_conversion_identity")
				var conversions: Dictionary = stage.get("reward_conversions",{}).duplicate(true)
				for key: String in receipt.reward_conversions:
					var conversion: Dictionary = receipt.reward_conversions[key]
					var reward := row("Reward",int(key))
					if not requested.has(int(key)) or int(reward.get("RewardTypeID",0)) != 1 or conversion.get("source_amount") != reward.Amount or not _integer(conversion.get("local_exp")) or int(conversion.local_exp) <= 0: return _fail("reward_conversion_identity")
					conversions[key] = conversion.duplicate(true)
				stage["reward_conversions"] = conversions
			if receipt.has("source_item_records"):
				if not receipt.source_item_records is Dictionary: return _fail("source_item_identity")
				var records: Dictionary = proposed.get("source_items",{}).duplicate(true)
				for name: String in receipt.source_item_records:
					var record: Variant = receipt.source_item_records[name]
					if not preload("res://scripts/monsterbook/monsterbook523_items.gd").valid_record(name,record): return _fail("source_item_identity")
					var matches: bool = false
					for reward: Dictionary in rewards:
						if int(reward.RewardTypeID) == 2 and int(reward.RewardClassID) == int(record.source_item_class_id) and record.source_reward == reward and record.source_original == row("ItemClass",int(record.source_item_class_id)): matches = true
					if not matches: return _fail("source_item_reward_identity")
					if records.has(name) and records[name].get("sourceId") != record.sourceId: return _fail("source_item_collision")
					records[name] = record.duplicate(true)
				proposed["source_items"] = records
		"register", "claim":
			var level_id: Variant = receipt.get("level_id")
			if not _level_belongs(level_id, book_id):
				return _fail("stage_identity")
			var level := row("MonsterBookLevel", int(level_id))
			quote["level"] = level
			if action == "register":
				if not _within(book_id, clock, "EndDateTimeID") or receipt.get("registration_approved") != true or int(stage.counts.get(str(int(level_id)), 0)) < int(level.Amount) or stage.registered.has(level_id):
					return _fail("registration_not_eligible")
				quote["currency"] = row("Currency", int(level.CurrencyID))
				stage.registered.append(int(level_id))
			else:
				# Claim windows cannot be inferred from CountingEnd/End alone.
				if receipt.get("claim_window_approved") != true or not stage.registered.has(level_id) or stage.claimed.has(level_id):
					return _fail("claim_not_eligible")
				quote["rewards"] = _linked("MonsterBookLevelReward", int(level_id), "RewardID", "Reward")
				stage.claimed.append(int(level_id))
		"effects":
			if not _within(book_id, clock, "EndDateTimeID") or not receipt.get("effective_levels") is Array:
				return _fail("effect_period_or_selection")
			var selected: Array = []
			for id: Variant in receipt.effective_levels:
				if not _level_belongs(id, book_id) or not stage.registered.has(id) or selected.has(id):
					return _fail("effect_not_registered")
				selected.append(int(id))
			stage.effective_levels = selected
			if receipt.get("bonus_policy") in ["manual","cumulative","latest"]: stage["bonus_policy"] = receipt.bonus_policy
		_: return _fail("unknown_transition")
	if receipt.get("protect_clock", false): saved["max_clock"] = clock
	saved.sequence = int(receipt.sequence)
	proposed.books[str(book_id)] = saved
	if not valid_state(proposed):
		return _fail("proposed_state")
	_busy = true
	var accepted: Variant = commit.call(export_state(), proposed.duplicate(true), quote.duplicate(true))
	_busy = false
	if accepted != true:
		return _fail("transaction_not_committed")
	_state = proposed
	last_error = ""
	changed.emit()
	return true

func _apply_progression(stage: Dictionary, book_id: int, receipt: Dictionary) -> void:
	# Explicit configurable TWILIGHT compatibility policy, never a source enum.
	var mode: String = str(stage.get("counter_policy",receipt.progression_policy))
	stage["counter_policy"] = mode
	var ordered := levels(book_id)
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Level) < int(b.Level))
	var assigned: int = 0
	for level: Dictionary in ordered: assigned += mini(int(level.Amount),int(stage.counts.get(str(int(level.ID)),0)))
	var available: int = maxi(0,int(stage.kill_count)-assigned)
	for level: Dictionary in ordered:
		var id: int = int(level.ID)
		if mode == "manual" and int(level.Level) > 1: break
		if stage.registered.has(id): continue
		var key := str(id)
		var count: int = int(stage.counts.get(key,0))
		if mode == "cumulative": count = maxi(count,int(stage.kill_count))
		else:
			var credited: int = mini(available,maxi(0,int(level.Amount)-count))
			count += credited
			available -= credited
		stage.counts[key] = count
		if count < int(level.Amount): break
		stage.registered.append(id)
		if int(level.Level) == 1 and not stage.has("first_stage_kill_count"): stage["first_stage_kill_count"] = int(stage.kill_count)
	_apply_bonus_policy(stage,book_id,receipt)

func _apply_bonus_policy(stage: Dictionary, book_id: int, receipt: Dictionary) -> void:
	var mode: String = str(stage.get("bonus_policy",receipt.get("bonus_policy","manual")))
	if mode not in ["manual","cumulative","latest"]: return
	stage["bonus_policy"] = mode
	if mode == "manual": return
	var selected: Array = []
	var ordered := levels(book_id)
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Level) < int(b.Level))
	for level: Dictionary in ordered:
		if stage.registered.has(int(level.ID)):
			if mode == "latest": selected.clear()
			selected.append(int(level.ID))
	stage.effective_levels = selected

func _level_belongs(id: Variant, book_id: int) -> bool:
	return _integer(id) and int(row("MonsterBookLevel", int(id)).get("MonsterBookID", -1)) == book_id

## Returns raw bonus rows selected by the authority, without stacking, scaling or
## currency/stat mapping. Expiration hides effects without deleting ownership.
func effective_bonuses(book_id: int, source_clock: String) -> Array:
	if not _within(book_id, source_clock, "EndDateTimeID"):
		return []
	var result: Array = []
	for id: Variant in progress(book_id).get("effective_levels", []):
		result.append_array(_linked("MonsterBookLevelBonus", int(id), "BonusID", "Bonus"))
	return result

func reward_claimed(book_id: int, level_id: int, reward_id: int) -> bool:
	var saved := progress(book_id)
	return saved.get("claimed", []).has(level_id) or saved.get("reward_claims", []).has(reward_id)

func current_period(book_id: int, clock: String) -> String:
	if not valid_clock(clock): return "unknown"
	var period := raw_period(book_id)
	var start := _clock(period.StartDateTimeID)
	var end := _clock(period.EndDateTimeID)
	var counting_end := _clock(period.CountingEndDateTimeID)
	if start.is_empty() or end.is_empty() or counting_end.is_empty(): return "unknown"
	if clock < start: return "not_started"
	if clock >= end: return "ended"
	if clock >= counting_end: return "options_only"
	return "counting"

func table_rows(table: String) -> Array:
	return _tables.get(table, []).duplicate(true)

