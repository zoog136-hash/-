extends RefCounted
## Private patch-523 source. No original content is embedded in this script.
## Tables and their rows become read-only once loaded. One source per session.
## Existing reader reused from PR269 f11fcbab (blob7aa63ea8); only the default
## load_zip input selection changes here. Domain/transaction owners are separate.

const SOURCE_PATH := "user://unconfirmed523/source.zip"
const SOURCE_BYTES := 25031173
const SOURCE_SHA256 := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const TABLE_COUNT := 1065
const PROBABILITY_DENOMINATOR := 1000000
const MAX_REWARD_DEPTH := 24
const MAX_REWARD_LEAVES := 4096
const COMMON = preload("res://scripts/resources/current523_definition_rows.gd")
## Tables at least this large are read through the shared column-packed store
## instead of a second full Dictionary copy here (Bonus alone is 217,916 rows;
## this reader held ~1.3 GB with the original installed).
const SHARED_ROW_THRESHOLD := 20000

var last_error: String = ""
var problem: String:
	get:
		return last_error
var _reader: ZIPReader
var _directory: String = ""
var _paths: Dictionary = {}
var _tables: Dictionary = {}
var _indices: Dictionary = {}
var _joins: Dictionary = {}
var _loaded: bool = false
var _source_path: String = ""
var _metadata: Dictionary = {}

func ready() -> bool:
	return _loaded

func is_ready() -> bool:
	return _loaded

func status() -> Dictionary:
	return {"ready": _loaded, "path": _source_path, "table_count": _paths.size(), "cached_tables": _tables.size(), "error": last_error, "test_source": not _directory.is_empty()}

func _fail(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message, "rewards": [], "restart_required": message == "restart_required"}

func _validate_zip(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("source_zip_missing")
	if file.get_length() != SOURCE_BYTES:
		return _fail("source_zip_size_mismatch")
	file.close()
	if FileAccess.get_sha256(path) != SOURCE_SHA256:
		return _fail("source_zip_sha256_mismatch")
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return _fail("source_zip_unreadable")
	var paths: Dictionary = {}
	for entry in zip.get_files():
		if entry.begins_with("/") or "\\" in entry or ".." in entry.split("/"):
			zip.close()
			return _fail("source_zip_unsafe_path")
		if not entry.begins_with("content/") or not entry.ends_with(".json"):
			continue
		var name: String = entry.trim_prefix("content/").trim_suffix(".json")
		if "/" in name or paths.has(name):
			zip.close()
			return _fail("source_zip_duplicate_table")
		paths[name] = entry
	if paths.size() != TABLE_COUNT:
		zip.close()
		return _fail("source_zip_table_count_mismatch")
	for required in ["ItemClass", "BuffClass", "CurrencyUnitClass", "Reward", "RewardType", "Bonus", "BonusType", "Unit", "DateTimes_Korean", "ServerLimit"]:
		if not paths.has(required):
			zip.close()
			return _fail("source_zip_missing_table:" + required)
	var manifest: Variant = JSON.parse_string(zip.read_file("index.json").get_string_from_utf8().trim_prefix("\ufeff"))
	if not manifest is Array or manifest.size() != TABLE_COUNT:
		zip.close()
		return _fail("source_zip_invalid_index")
	var metadata: Dictionary = {}
	for member in manifest:
		if not member is Dictionary:
			zip.close()
			return _fail("source_zip_invalid_index_entry")
		var member_path: String = str(member.get("path", ""))
		var table: String = member_path.trim_prefix("content/").trim_suffix(".json")
		if not paths.has(table) or str(paths[table]) != member_path or metadata.has(table) or int(member.get("version",0)) != 523 or int(member.get("bytes",0)) <= 0 or str(member.get("sha256","")).length() != 64:
			zip.close()
			return _fail("source_zip_invalid_index_entry")
		metadata[table] = member
	zip.close()
	return {"ok": true, "paths": paths, "metadata": metadata}

func install_zip(path: String) -> Dictionary:
	if _loaded:
		return _fail("restart_required")
	var validation: Dictionary = _validate_zip(path)
	if not validation.ok:
		return validation
	var destination: String = ProjectSettings.globalize_path(SOURCE_PATH)
	if ProjectSettings.globalize_path(path) != destination:
		if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK:
			return _fail("source_install_directory_failed")
		var temporary: String = destination + ".installing"
		var input: FileAccess = FileAccess.open(path, FileAccess.READ)
		var output: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
		if input == null or output == null:
			return _fail("source_install_copy_failed")
		while input.get_position() < input.get_length():
			output.store_buffer(input.get_buffer(1024 * 1024))
		output.flush()
		var write_error: Error = output.get_error()
		input.close()
		output.close()
		if write_error != OK or not bool(_validate_zip(temporary).ok):
			DirAccess.remove_absolute(temporary)
			return _fail("source_install_copy_verification_failed")
		# Same-directory rename publishes only a complete, verified file.
		if DirAccess.rename_absolute(temporary, destination) != OK:
			DirAccess.remove_absolute(temporary)
			return _fail("source_install_publish_failed")
	return load_zip(SOURCE_PATH)

func load_zip(path: Variant = null) -> Dictionary:
	# UNVERIFIED input delta for the existing owner: its no-argument call runs
	# before domain.setup(). Explicit strings, including empty ones, remain
	# authoritative; no failed explicit selection is replaced by another source.
	var implicit: bool = path == null
	if not implicit and not path is String:
		return _fail("source_zip_path_type_invalid")
	if _loaded:
		if implicit or path == _source_path:
			return {"ok": true, "already_loaded": true}
		return _fail("restart_required")
	var selected_path: String = SOURCE_PATH if implicit else path
	if implicit:
		var default_file: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.READ)
		var default_error: Error = FileAccess.get_open_error()
		if default_file != null:
			default_file.close()
		elif default_error == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(SOURCE_PATH):
			# Reuse the held original path only for actual default-file absence.
			# This is no installation/copy, model digest or supply receipt.
			var common_path: String = preload("res://scripts/resources/current523_definition_rows.gd").archive_path()
			if not common_path.is_empty(): selected_path = common_path
	# The same pinned archive/index guards own admission for either input.
	var validation: Dictionary = _validate_zip(selected_path)
	if not validation.ok:
		return validation
	_reader = ZIPReader.new()
	if _reader.open(selected_path) != OK:
		return _fail("source_zip_unreadable")
	_paths = validation.paths
	_metadata = validation.metadata
	_loaded = true
	_source_path = selected_path
	last_error = ""
	return {"ok": true, "table_count": _paths.size(), "sha256": SOURCE_SHA256}

func configure_directory(directory: String) -> Dictionary:
	# Explicit test harness only; production reads the verified private common ZIP.
	if OS.get_environment("TWILIGHT_523_ALLOW_TEST_SOURCE") != "1":
		return _fail("test_source_disabled")
	if _loaded:
		return _fail("restart_required")
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return _fail("test_source_missing")
	for filename in dir.get_files():
		if filename.ends_with(".json"):
			_paths[filename.trim_suffix(".json")] = directory.path_join(filename)
	_directory = directory
	_loaded = true
	_source_path = directory
	last_error = ""
	return {"ok": true, "test_source": true, "table_count": _paths.size()}

func _shared(table: String) -> bool:
	if not _loaded or not _metadata.has(table) or int(_metadata[table].get("row_count", 0)) < SHARED_ROW_THRESHOLD: return false
	return COMMON.identity().get("source_sha256") == SOURCE_SHA256 and not COMMON.table_metadata(table).is_empty()

static func _read_only(values: Array) -> Array:
	var result: Array = []
	for value: Dictionary in values:
		value.make_read_only()
		result.append(value)
	result.make_read_only()
	return result

func rows(table: String) -> Array:
	if _tables.has(table):
		return _tables[table]
	if _shared(table):
		# Same original bytes (whole-archive SHA verified by the shared reader).
		# Not cached: callers that need a subset keep only that subset.
		return _read_only(COMMON.rows(table))
	if not _loaded or not _paths.has(table):
		last_error = "missing_table:" + table
		return []
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(_paths[table]) if not _directory.is_empty() else _reader.read_file(_paths[table])
	if _metadata.has(table):
		var metadata: Dictionary = _metadata[table]
		var hash_context := HashingContext.new()
		hash_context.start(HashingContext.HASH_SHA256)
		hash_context.update(bytes)
		if bytes.size() != int(metadata.bytes) or hash_context.finish().hex_encode() != str(metadata.sha256):
			last_error = "source_table_integrity_failed:" + table
			return []
	var raw: String = bytes.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw.trim_prefix("\ufeff"))
	if not parsed is Dictionary or not parsed.get("rows") is Array:
		last_error = "invalid_table:" + table
		return []
	var result: Array = parsed.rows
	if _metadata.has(table) and result.size() != int(_metadata[table].get("row_count",-1)):
		last_error = "source_table_row_count_failed:" + table
		return []
	var index: Dictionary = {}
	for value in result:
		if not value is Dictionary:
			last_error = "invalid_table_row:" + table
			return []
		var record: Dictionary = value
		if record.has("ID"):
			var id: int = int(record.ID)
			# Null marks ambiguity. Never pick an arbitrary duplicate ID.
			index[id] = null if index.has(id) else record
		record.make_read_only()
	result.make_read_only()
	_tables[table] = result
	_indices[table] = index
	return result

## One column of a large table read through the shared reader, in table order
## (the same values rows(table) would carry); null when the table is read here.
## Lets owners scan a large table without materializing every row.
func shared_column(table: String, field: String) -> Variant:
	if _tables.has(table) or not _shared(table): return null
	var values: Variant = COMMON.column(table, field)
	if not (values is Array or values is PackedFloat64Array or values is PackedStringArray): return null
	if values.size() != COMMON.row_count(table) or values.size() == 0: return null
	return values

## The read-only row at `index` of a large shared table (same row rows() gives).
func shared_row_at(table: String, index: int) -> Dictionary:
	var value: Dictionary = COMMON.row_at(table, index)
	value.make_read_only()
	return value

func row(table: String, id: int) -> Dictionary:
	if not _tables.has(table) and _shared(table) and COMMON.integer_field(table, "ID"):
		var matches: Array = _read_only(COMMON.related(table, "ID", id))
		if matches.size() > 1:
			last_error = "duplicate_id:%s:%d" % [table, id]
			return {}
		if matches.is_empty():
			last_error = "missing_row:%s:%d" % [table, id]
			return {}
		return matches[0]
	rows(table)
	var index: Dictionary = _indices.get(table, {})
	if index.has(id) and index[id] == null:
		last_error = "duplicate_id:%s:%d" % [table, id]
		return {}
	var found: Dictionary = index.get(id, {})
	if found.is_empty():
		last_error = "missing_row:%s:%d" % [table, id]
	return found

func find_rows(table: String, field: String, value: Variant) -> Array:
	var key: String = table + ":" + field
	if not _tables.has(table) and not _joins.has(key) and _shared(table) and typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) == floorf(float(value)) and COMMON.integer_field(table, field):
		return _read_only(COMMON.related(table, field, int(value)))
	if not _joins.has(key):
		var index: Dictionary = {}
		for record: Dictionary in rows(table):
			if not record.has(field):
				continue
			var field_value: Variant = record[field]
			if field_value is float and float(field_value) == float(int(field_value)):
				field_value = int(field_value)
			if not index.has(field_value):
				index[field_value] = []
			index[field_value].append(record)
		for group: Array in index.values():
			group.make_read_only()
		_joins[key] = index
	if value is float and float(value) == float(int(value)):
		value = int(value)
	return _joins[key].get(value, [])

func _offset(context: Dictionary) -> int:
	var policy: Dictionary = context.get("time_policy", {})
	return int(policy.get("utc_offset_minutes", Time.get_time_zone_from_system().get("bias", 0)))

func timestamp(date_id: int, context: Dictionary = {}) -> int:
	if date_id == 0:
		return 0
	var date: Dictionary = row("DateTimes_Korean", date_id)
	if date.is_empty():
		return -1
	return _date_timestamp(date, context)

func _date_timestamp(date: Dictionary, context: Dictionary) -> int:
	var year: int = int(date.get("Year", 0))
	var month: int = int(date.get("Month", 0))
	var day: int = int(date.get("Day", 0))
	var hour: int = int(date.get("Hour", 0))
	var minute: int = int(date.get("Minute", 0))
	if year < 1970 or month < 1 or month > 12 or day < 1 or day > 31 or hour < 0 or hour > 23 or minute < 0 or minute > 59:
		last_error = "invalid_source_date"
		return -1
	var days: Array = [31,29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28,31,30,31,30,31,31,30,31,30,31]
	if day > int(days[month - 1]):
		last_error = "invalid_source_date"
		return -1
	var unix: int = Time.get_unix_time_from_datetime_dict({"year":year,"month":month,"day":day,"hour":hour,"minute":minute,"second":0})
	var check: Dictionary = Time.get_datetime_dict_from_unix_time(unix)
	if int(check.day) != day or int(check.month) != month:
		last_error = "invalid_source_date"
		return -1
	return unix - _offset(context) * 60

func region_allowed(server_limit_set_id: int, context: Dictionary = {}) -> bool:
	if server_limit_set_id == 0:
		return true
	var region: String = str(context.get("service_region", context.get("service_region_code", "KR")))
	var world_no: int = int(context.get("world_no", 1))
	for limit: Dictionary in find_rows("ServerLimit", "ServerLimitSetID", server_limit_set_id):
		if str(limit.get("ServiceRegionCode", "")) == region and int(limit.get("WorldNo", -1)) == world_no:
			return true
	return false

func item_eligibility(item_id: int, context: Dictionary = {}) -> Dictionary:
	var item: Dictionary = row("ItemClass", item_id)
	if item.is_empty():
		return {"ok":false,"error":"unknown_item"}
	if bool(item.get("TestItem", false)) and not bool(context.get("allow_test_items", false)):
		return {"ok":false,"error":"test_item"}
	var region: String = str(item.get("ServiceRegionCode", ""))
	if not region.is_empty() and region != str(context.get("service_region", context.get("service_region_code", "KR"))):
		return {"ok":false,"error":"item_region_limit"}
	if bool(context.get("enforce_item_use_limits", false)):
		var level: int = int(context.get("level", 1))
		if level < int(item.get("LevelLimitMin", 0)) or (int(item.get("LevelLimitMax", 0)) > 0 and level > int(item.LevelLimitMax)):
			return {"ok":false,"error":"item_level_limit"}
		var limits: Array = find_rows("ItemClassLimit", "ItemClassID", item_id)
		if not limits.is_empty():
			var matched: bool = false
			for limit: Dictionary in limits:
				matched = matched or int(limit.ClassID) == int(context.get("class_id", 0))
			if not matched:
				return {"ok":false,"error":"item_class_limit"}
	for link: Dictionary in find_rows("ItemBonus", "ItemClassID", item_id):
		var bonus: Dictionary = row("Bonus", int(link.get("BonusID", 0)))
		if bonus.is_empty():
			return {"ok":false,"error":"item_bonus_missing"}
		var type: Dictionary = row("BonusType", int(bonus.get("BonusTypeID", 0)))
		var name: String = str(type.get("Name", ""))
		if name not in ["DeleteTime", "DeleteLevel", "UesItemServerLimitSetID"]:
			continue
		if name == "DeleteTime" and int(bonus.get("BonusApplicationTypeID",0)) == 298:
			var application: Dictionary = row("BonusApplicationType",298)
			var target_id: int = int(bonus.get("BonusApplicationTargetID",0))
			if str(application.get("Name","")) != "DateTime" or target_id <= 0 or int(bonus.get("Value",0)) != 0:
				return {"ok":false,"error":"item_delete_datetime_unsupported"}
			var expiry: int = timestamp(target_id,context)
			if expiry < 0 or int(context.get("now",Time.get_unix_time_from_system())) >= expiry:
				return {"ok":false,"error":"item_expired"}
			continue
		if int(bonus.get("BonusApplicationTypeID", 0)) != 0 or int(bonus.get("BonusApplicationTargetID", 0)) != 0:
			return {"ok":false,"error":"conditional_item_limit_unsupported"}
		var value: int = int(bonus.get("Value", 0))
		if value == 0:
			continue
		if name == "DeleteTime":
			# Unit162 Time is packed YYYYMMDDHH, not a DateTimes row ID.
			var packed: String = str(value)
			if packed.length() != 10:
				return {"ok":false,"error":"item_delete_time_unsupported"}
			var expiry: int = _date_timestamp({"Year":packed.substr(0,4).to_int(),"Month":packed.substr(4,2).to_int(),"Day":packed.substr(6,2).to_int(),"Hour":packed.substr(8,2).to_int()}, context)
			if expiry < 0 or int(context.get("now", Time.get_unix_time_from_system())) >= expiry:
				return {"ok":false,"error":"item_expired"}
		elif name == "DeleteLevel" and int(context.get("level", 1)) >= value:
			return {"ok":false,"error":"item_delete_level"}
		elif name == "UesItemServerLimitSetID" and not region_allowed(value, context):
			return {"ok":false,"error":"item_server_limit"}
	return {"ok":true}

func can_own_item(item_id: int, context: Dictionary = {}) -> bool:
	return bool(item_eligibility(item_id, context).ok)

func resolve_reward(reward_id: int, context: Dictionary, selection: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	var state: Dictionary = {"leaves":0,"assumptions":[],"no_reward_ids":[]}
	var initial_rng_state: int = rng.state if rng != null else 0
	var result: Dictionary = _resolve(reward_id, context, selection, rng, [], state)
	if not result.ok:
		if rng != null:
			rng.state = initial_rng_state
		return result
	result["assumptions"] = state.assumptions
	result["no_reward_ids"] = state.no_reward_ids
	return result

func _resolve(id: int, context: Dictionary, selection: Dictionary, rng: RandomNumberGenerator, chain: Array, state: Dictionary) -> Dictionary:
	if id in chain or chain.size() >= MAX_REWARD_DEPTH:
		return _fail("reward_cycle_or_depth_limit")
	var reward: Dictionary = row("Reward", id)
	if reward.is_empty():
		return _fail("unknown_reward:%d" % id)
	if bool(reward.get("ClanOnly", false)):
		return _fail("clan_reward_excluded")
	if bool(reward.get("UseImmediately", false)):
		return _fail("immediate_reward_requires_consumer")
	var character_class: int = int(reward.get("CharacterClassID", 0))
	if character_class != 0 and character_class != int(context.get("class_id", 0)):
		return _fail("reward_character_class_limit")
	var type_id: int = int(reward.get("RewardTypeID", 0))
	var type: Dictionary = row("RewardType", type_id)
	var expected: Dictionary = {1:"Exp",2:"Item",5:"Einasad",6:"Gem",91:"NoReward",101:"RandomReward",111:"SelectReward",124:"ComplexReward",172:"PassSystemSeasonPassExp",184:"Bonus"}
	if not expected.has(type_id) or str(type.get("Name", "")) != str(expected[type_id]):
		return _fail("unsupported_reward_type:%d" % type_id)
	var amount: int = int(reward.get("Amount", 0))
	var class_id: int = int(reward.get("RewardClassID", 0))
	if amount < 0:
		return _fail("invalid_reward_amount")
	if (type_id == 101 and amount != 1) or (type_id in [111,124] and amount not in [0,1]):
		return _fail("nested_reward_amount_unsupported")
	if int(reward.get("RewardEnhancementTypeID", 1)) != 1:
		return _fail("reward_enhancement_requires_material_rule")
	if type_id == 91:
		# This source type explicitly delivers no reward, including rows whose
		# ClassID is a display reference. Never turn that reference into an item.
		state.no_reward_ids.append(id)
		return {"ok":true,"error":"","rewards":[]}
	var next_chain: Array = chain.duplicate()
	next_chain.append(id)
	if type_id == 101:
		var pool: Array = find_rows("RandomRewardEntityView", "RandomRewardID", class_id)
		if pool.is_empty() or row("RandomReward", class_id).is_empty():
			return _fail("random_reward_pool_missing")
		var weighted: bool = true
		for entry: Dictionary in pool:
			weighted = weighted and entry.has("Probability")
		if not weighted:
			var policy: Dictionary = context.get("twilight_policy", {})
			if str(policy.get("random_reward_weight_mode", "")) != "equal_estimate":
				return _fail("missing_random_probabilities")
			if rng == null:
				return _fail("rng_required")
			var candidates: Array = []
			for entry: Dictionary in pool:
				candidates.append(int(entry.RewardID))
			state.assumptions.append({"policy":"TWILIGHT","rule":"equal_estimate","random_reward_id":class_id,"candidate_reward_ids":candidates,"official_probabilities":false})
			return _resolve(int(pool[rng.randi_range(0,pool.size()-1)].RewardID),context,selection,rng,next_chain,state)
		return _resolve_weighted(pool,context,selection,rng,next_chain,state)
	if type_id == 111:
		var definition: Dictionary = row("SelectReward", class_id)
		if definition.is_empty():
			return _fail("selection_definition_missing")
		return _resolve_selection(find_rows("SelectRewardEntity","SelectRewardID",class_id),int(definition.get("SelectMaxCount",0)),id,context,selection,rng,next_chain,state)
	if type_id == 124:
		if row("ComplexRewardGroup",class_id).is_empty():
			return _fail("complex_group_missing")
		var groups: Array = find_rows("ComplexReward","ComplexRewardGroupID",class_id)
		if groups.is_empty():
			return _fail("complex_group_empty")
		var rewards: Array = []
		for group: Dictionary in groups:
			var entities: Array = find_rows("ComplexRewardEntity","ComplexRewardID",int(group.ID))
			var maximum: int = int(group.get("MaxCount",0))
			var branch: Dictionary
			match int(group.get("ComplexRewardTypeID",0)):
				4:
					if entities.size() != maximum or maximum <= 0:
						return _fail("complex_guaranteed_count_ambiguous")
					branch = _resolve_entities(entities,context,selection,rng,next_chain,state)
				14:
					branch = _resolve_selection(entities,maximum,int(group.ID),context,selection,rng,next_chain,state)
				24:
					# The content proves a single weighted draw. Multiple-draw
					# replacement semantics are not specified by these tables.
					if maximum != 1:
						return _fail("complex_multi_draw_policy_unknown")
					branch = _resolve_weighted(entities,context,selection,rng,next_chain,state)
				_:
					return _fail("unsupported_complex_reward_type")
			if not branch.ok:
				return branch
			rewards.append_array(branch.rewards)
		return {"ok":true,"error":"","rewards":rewards}
	if type_id == 2:
		var eligibility: Dictionary = item_eligibility(class_id,context)
		if not eligibility.ok:
			return _fail(str(eligibility.error))
	if type_id == 5 and (amount <= 0 or not find_rows("RewardAttribute","RewardID",id).is_empty()):
		return _fail("blessing_reward_rule_unsupported")
	if type_id == 184:
		if row("Bonus",class_id).is_empty() or int(context.get("pass_id",0)) <= 0 or int(context.get("pass_expires_at",0)) <= int(context.get("now",Time.get_unix_time_from_system())):
			return _fail("bonus_reward_requires_active_pass")
		if amount != 1:
			return _fail("bonus_reward_amount_unsupported")
	if amount <= 0:
		return _fail("invalid_leaf_reward_amount")
	state.leaves = int(state.leaves) + 1
	if int(state.leaves) > MAX_REWARD_LEAVES:
		return _fail("reward_leaf_limit")
	var kinds: Dictionary = {1:"experience",2:"item",5:"blessing",6:"currency",172:"pass_exp",184:"bonus"}
	var leaf: Dictionary = {"kind":kinds[type_id],"id":2 if type_id == 6 else class_id,"amount":amount,"source_reward_id":id,"reward_enhancement_type_id":int(reward.get("RewardEnhancementTypeID",1)),"source_attributes":reward.duplicate(true)}
	if type_id == 2:
		leaf["bless_code"] = int(reward.get("ItemBlessCodeID",1))
		if reward.has("ItemEnchant"):
			leaf["enchant"] = int(reward.ItemEnchant)
		elif reward.has("Enchant"):
			leaf["enchant"] = int(reward.Enchant)
	if type_id == 184:
		leaf["pass_id"] = int(context.pass_id)
		leaf["expires_at"] = int(context.pass_expires_at)
	return {"ok":true,"error":"","rewards":[leaf]}

func _resolve_entities(entities: Array, context: Dictionary, selection: Dictionary, rng: RandomNumberGenerator, chain: Array, state: Dictionary) -> Dictionary:
	if entities.is_empty():
		return _fail("empty_reward_entities")
	var rewards: Array = []
	for entity: Dictionary in entities:
		var child: Dictionary = _resolve(int(entity.get("RewardID",0)),context,selection,rng,chain,state)
		if not child.ok:
			return child
		rewards.append_array(child.rewards)
	return {"ok":true,"error":"","rewards":rewards}

func reward_choices(reward_id: int, context: Dictionary = {}, selection: Dictionary = {}) -> Dictionary:
	# A preview never rolls RNG or requests choices from an unselected branch.
	var result: Dictionary = {"ok":true,"error":"","choices":[],"deferred_random":[],"walk_count":0}
	var error: String = _choice_walk(reward_id,context,selection,[],result)
	if not error.is_empty():
		return {"ok":false,"error":error,"choices":[],"deferred_random":[]}
	result.erase("walk_count")
	return result

func _choice_walk(id: int, context: Dictionary, selection: Dictionary, chain: Array, result: Dictionary) -> String:
	result.walk_count = int(result.walk_count)+1
	if int(result.walk_count) > MAX_REWARD_LEAVES:
		return "reward_preview_limit"
	if id in chain or chain.size() >= MAX_REWARD_DEPTH:
		return "reward_cycle_or_depth_limit"
	var reward: Dictionary = row("Reward",id)
	if reward.is_empty():
		return "unknown_reward:%d" % id
	if bool(reward.get("ClanOnly",false)):
		return "clan_reward_excluded"
	var character_class: int = int(reward.get("CharacterClassID",0))
	if character_class != 0 and context.has("class_id") and character_class != int(context.class_id):
		return "reward_character_class_limit"
	var next_chain: Array = chain.duplicate()
	next_chain.append(id)
	var type_id: int = int(reward.get("RewardTypeID",0))
	var class_id: int = int(reward.get("RewardClassID",0))
	if type_id == 101:
		var candidates: Array = []
		for entity: Dictionary in find_rows("RandomRewardEntityView","RandomRewardID",class_id):
			candidates.append(int(entity.get("RewardID",0)))
		if candidates.is_empty() or row("RandomReward",class_id).is_empty():
			return "random_reward_pool_missing"
		result.deferred_random.append({"reward_id":id,"candidate_reward_ids":candidates})
	elif type_id == 111:
		var definition: Dictionary = row("SelectReward",class_id)
		if definition.is_empty():
			return "selection_definition_missing"
		return _choice_group(find_rows("SelectRewardEntity","SelectRewardID",class_id),int(definition.get("SelectMaxCount",0)),id,context,selection,next_chain,result)
	elif type_id == 124:
		var groups: Array = find_rows("ComplexReward","ComplexRewardGroupID",class_id)
		if row("ComplexRewardGroup",class_id).is_empty() or groups.is_empty():
			return "complex_group_missing"
		for group: Dictionary in groups:
			var entities: Array = find_rows("ComplexRewardEntity","ComplexRewardID",int(group.ID))
			var maximum: int = int(group.get("MaxCount",0))
			match int(group.get("ComplexRewardTypeID",0)):
				4:
					if maximum <= 0 or entities.size() != maximum:
						return "complex_guaranteed_count_ambiguous"
					for entity: Dictionary in entities:
						var error: String = _choice_walk(int(entity.get("RewardID",0)),context,selection,next_chain,result)
						if not error.is_empty(): return error
				14:
					var error: String = _choice_group(entities,maximum,int(group.ID),context,selection,next_chain,result)
					if not error.is_empty(): return error
				24:
					if maximum != 1: return "complex_multi_draw_policy_unknown"
					result.deferred_random.append({"reward_id":id,"complex_reward_id":int(group.ID),"candidate_reward_ids":entities.map(func(entity: Dictionary) -> int: return int(entity.get("RewardID",0)))})
				_:
					return "unsupported_complex_reward_type"
	return ""

func _choice_group(entities: Array, maximum: int, key: int, context: Dictionary, selection: Dictionary, chain: Array, result: Dictionary) -> String:
	if maximum <= 0 or entities.is_empty(): return "invalid_selection_count"
	var chosen: Variant = selection.get(key,selection.get(str(key),null))
	var options: Array = []
	for entity: Dictionary in entities:
		options.append({"value":int(entity.get("ID",0)),"reward_id":int(entity.get("RewardID",0))})
	if chosen == null:
		result.choices.append({"key":"selection.%d" % key,"selection_key":key,"options":options,"count":maximum,"min_count":1,"max_count":maximum})
		return ""
	if not chosen is Array or chosen.is_empty() or chosen.size() > maximum: return "invalid_selection_count"
	var seen: Dictionary = {}
	for entity_id: Variant in chosen:
		if (not entity_id is int and not entity_id is float) or float(entity_id) != float(int(entity_id)) or seen.has(int(entity_id)):
			return "duplicate_or_invalid_selection"
		seen[int(entity_id)] = true
		var found: bool = false
		for entity: Dictionary in entities:
			if int(entity.get("ID",0)) == int(entity_id):
				found = true
				var error: String = _choice_walk(int(entity.get("RewardID",0)),context,selection,chain,result)
				if not error.is_empty(): return error
		if not found: return "selection_entity_outside_group"
	return ""

func _resolve_selection(entities: Array, maximum: int, key: int, context: Dictionary, selection: Dictionary, rng: RandomNumberGenerator, chain: Array, state: Dictionary) -> Dictionary:
	var chosen: Variant = selection.get(key,selection.get(str(key),null))
	if not chosen is Array or chosen.is_empty():
		return _fail("selection_required:%d" % key)
	if maximum <= 0 or chosen.size() > maximum:
		return _fail("invalid_selection_count")
	var seen: Dictionary = {}
	var picked: Array = []
	for entity_id in chosen:
		if not entity_id is int and not entity_id is float:
			return _fail("invalid_selection_entity")
		if float(entity_id) != float(int(entity_id)) or seen.has(int(entity_id)):
			return _fail("duplicate_or_invalid_selection")
		seen[int(entity_id)] = true
		var found: bool = false
		for entity: Dictionary in entities:
			if int(entity.get("ID",-1)) == int(entity_id):
				picked.append(entity)
				found = true
		if not found:
			return _fail("selection_entity_outside_group")
	return _resolve_entities(picked,context,selection,rng,chain,state)

func _resolve_weighted(pool: Array, context: Dictionary, selection: Dictionary, rng: RandomNumberGenerator, chain: Array, state: Dictionary) -> Dictionary:
	var total: int = 0
	for entity: Dictionary in pool:
		if not entity.has("Probability") or float(entity.Probability) != float(int(entity.Probability)) or int(entity.Probability) < 0:
			return _fail("invalid_reward_probability")
		total += int(entity.Probability)
	if total > PROBABILITY_DENOMINATOR or pool.is_empty():
		return _fail("reward_probability_overflow")
	if rng == null:
		return _fail("rng_required")
	var roll: int = rng.randi_range(1,PROBABILITY_DENOMINATOR)
	var cumulative: int = 0
	for entity: Dictionary in pool:
		cumulative += int(entity.Probability)
		if roll <= cumulative:
			return _resolve(int(entity.get("RewardID",0)),context,selection,rng,chain,state)
	# Unfilled probability remains a no-reward outcome, never renormalized.
	return {"ok":true,"error":"","rewards":[],"empty_roll":true}

func bonus_stats(bonus_ids: Array, context: Dictionary = {}) -> Dictionary:
	var stats: Dictionary = {}
	var conditional_stats: Dictionary = {"undead":{},"pvp":{}}
	var effects: Array = []
	var unsupported: Array = []
	var flat: Dictionary = {"MeleeDamage":"melee_damage","MeleeHit":"melee_hit","MagicDamage":"magic_damage","MagicHit":"magic_hit","RangeDamage":"ranged_damage","RangeHit":"ranged_hit","HPPlus":"max_hp","MPPlus":"max_mp","ArmorClass":"ac","ArmorClassBonus":"ac","Strength":"str","Intelligence":"int","Wisdom":"wis","Dexterity":"dex","Constitution":"con","Charisma":"cha","RegenMP":"mp_regeneration","SpellPower":"sp","MagicResist":"mr","DamageReduction":"damage_reduction","PVEDamageReduction":"pve_damage_reduction","PierceDamageReduction":"damage_reduction_ignore","HPPotionIncreaseStatic":"potion_flat","CarryPlus":"weight_bonus","MaxCarryPlus":"weight_bonus","RangeEvasion":"er","CriticalMeleeDamage":"melee_critical_damage","CriticalRangeDamage":"ranged_critical_damage","CriticalMagicDamage":"magic_critical_damage"}
	var percent: Dictionary = {"ExperienceAdditionPercent":"experience_bonus","AbsoluteExperienceAdditionPercent":"experience_bonus","AttackSpeedBonus":"attack_speed","MoveSpeedBonus":"movement_speed","CastSpeedBonus":"cast_speed","HPPotionIncreasePercent":"potion_percent","MeleeCritical":"melee_critical_rate","RangeCritical":"ranged_critical_rate","DamageReductionPercent":"incoming_reduction","IgnoreMeleeDamageReductionPercent":"ignore_melee_damage_reduction","IgnoreRangeDamageReductionPercent":"ignore_ranged_damage_reduction","IgnoreMagicDamageReductionPercent":"ignore_magic_damage_reduction"}
	var conditional_flat: Dictionary = {"UndeadAdditionalMaxDamage":["undead","undead_additional_max_damage"],"PVPDamageReduction":["pvp","pvp_damage_reduction"],"PVPMeleeAdditionDamage":["pvp","pvp_melee_damage"],"PVPRangeAdditionDamage":["pvp","pvp_ranged_damage"],"PVPMagicAdditionDamage":["pvp","pvp_magic_damage"]}
	var conditional_percent: Dictionary = {"PVPDamageReductionPercent":["pvp","pvp_damage_reduction"],"PVPPierceDamageReductionPercent":["pvp","pvp_damage_reduction_ignore"]}
	for bonus_id in bonus_ids:
		var bonus: Dictionary = row("Bonus",int(bonus_id))
		var type: Dictionary = row("BonusType",int(bonus.get("BonusTypeID",-1))) if not bonus.is_empty() else {}
		var unit: Dictionary = row("Unit",int(type.get("UnitID",-1))) if not type.is_empty() else {}
		var effect: Dictionary = {"bonus_id":int(bonus_id),"bonus_type_id":int(type.get("ID",-1)),"name":str(type.get("Name","")),"unit_id":int(unit.get("ID",-1)),"unit":str(unit.get("Name","")),"raw_value":bonus.get("Value",0),"application_type_id":int(bonus.get("BonusApplicationTypeID",0)),"application_target_id":int(bonus.get("BonusApplicationTargetID",0))}
		if bonus.is_empty() or type.is_empty() or unit.is_empty():
			effect["reason"] = "missing_bonus_namespace"
			unsupported.append(effect)
			continue
		var name: String = effect.name
		var raw: float = float(effect.raw_value)
		effect["applied"] = false
		if effect.unit in ["Percentage","ValuePercent","MillionPercentage"]:
			effect["percentage_points"] = raw / 10000.0
			effect["ratio"] = raw / 1000000.0
		var application: bool = int(effect.application_type_id) != 0 or int(effect.application_target_id) != 0
		var conditional_mapping: Array = []
		var conditional_value: float = raw
		var suffix: String = ":flat"
		if not application and conditional_flat.has(name) and effect.unit == "Value":
			conditional_mapping = conditional_flat[name]
		elif not application and conditional_percent.has(name) and effect.unit in ["Percentage","ValuePercent","MillionPercentage"]:
			conditional_mapping = conditional_percent[name]
			conditional_value = raw / 10000.0
			suffix = ":percent"
		if not conditional_mapping.is_empty():
			var condition: String = str(conditional_mapping[0])
			var conditional_key: String = str(conditional_mapping[1])+suffix
			conditional_stats[condition][conditional_key] = float(conditional_stats[condition].get(conditional_key,0.0))+conditional_value
			effect.merge({"condition":condition,"stat_key":conditional_key,"value":conditional_value,"reason":"target_context_required"})
			effects.append(effect)
			continue
		var conditional: bool = application or name.begins_with("PVP") or "Undead" in name or "By" in name or "OnTarget" in name
		if conditional:
			effect["reason"] = "conditional_effect_requires_consumer"
			effects.append(effect)
			unsupported.append(effect.duplicate(true))
			continue
		var key: String = ""
		var value: float = raw
		if flat.has(name) and effect.unit in ["Value","Weight"]:
			key = str(flat[name]) + ":flat"
			if name in ["ArmorClass","ArmorClassBonus"]:
				value = -raw
		elif percent.has(name) and effect.unit in ["Percentage","ValuePercent","MillionPercentage"]:
			key = str(percent[name]) + ":percent"
			value = raw / 10000.0
		elif name == "None":
			continue
		else:
			effect["reason"] = "unsupported_effect"
			unsupported.append(effect)
			continue
		stats[key] = float(stats.get(key,0.0)) + value
		effect["stat_key"] = key
		effect["value"] = value
		effect["applied"] = true
		effects.append(effect)
	return {"stats":stats,"conditional_stats":conditional_stats,"effects":effects,"unsupported":unsupported}

