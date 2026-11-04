extends RefCounted
signal changed
## Exact source catalog plus confirmed per-character progress transactions.
## Credit attribution, reset schedule, stage accumulation and bonus stacking
## belong to the host's reviewed authority adapter, never inferred from enums.
const SCHEMA := "twilight.monsterbook523.v1"
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const TABLES := ["MonsterBook", "MonsterBookLevel", "MonsterBookLevelBonus", "MonsterBookLevelReward", "NpcClassForNpcGroup", "Bonus", "BonusType", "Reward", "RewardType", "Currency", "DateTimes_Korean", "Unit", "ItemClass", "DescData_Korean"]
var _tables: Dictionary = {}
var _indexes: Dictionary = {}
var _state: Dictionary = {"schema": 1, "books": {}}
var pack_sha: String = ""
var last_error: String = ""
var _busy: bool = false

func _fail(reason: String) -> bool:
	last_error = reason
	return false

func load_pack(path: String, expected_sha: String) -> bool:
	if _busy:
		return _fail("transaction_in_progress")
	if expected_sha.length() != 64 or not FileAccess.file_exists(path):
		return _fail("missing_pack_or_digest")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16 * 1024 * 1024:
		return _fail("pack_size")
	var data := file.get_buffer(file.get_length())
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(data)
	if digest.finish().hex_encode() != expected_sha:
		return _fail("pack_digest")
	var parser := JSON.new()
	if parser.parse(data.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _fail("pack_json")
	var model: Dictionary = parser.data
	if model.get("schema") != SCHEMA or model.get("source_sha256") != SOURCE_SHA or not model.get("tables") is Dictionary:
		return _fail("pack_source")
	var tables: Dictionary = model.tables
	var indexes: Dictionary = {}
	for table: String in TABLES:
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
	pack_sha = expected_sha
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
	for level: Dictionary in _tables.get("MonsterBookLevel", []):
		if int(level.MonsterBookID) == book_id:
			var view := level.duplicate(true)
			view["bonuses"] = _linked("MonsterBookLevelBonus", int(level.ID), "BonusID", "Bonus")
			view["rewards"] = _linked("MonsterBookLevelReward", int(level.ID), "RewardID", "Reward")
			result.append(view)
	return result

func _linked(table: String, level_id: int, field: String, target: String) -> Array:
	var result: Array = []
	for link: Dictionary in _tables.get(table, []):
		if int(link.MonsterBookLevelID) == level_id:
			result.append(row(target, int(link[field])))
	return result

func raw_period(book_id: int) -> Dictionary:
	var book := row("MonsterBook", book_id)
	var result: Dictionary = {}
	for key: String in ["StartDateTimeID", "CountingEndDateTimeID", "EndDateTimeID"]:
		result[key] = row("DateTimes_Korean", int(book.get(key, 0)))
	return result

func export_state() -> Dictionary:
	return _state.duplicate(true)

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
	for book: Dictionary in _state.books.values():
		book.sequence = int(book.sequence)
		for progress_value: Dictionary in book.epochs.values():
			for id: Variant in progress_value.counts:
				progress_value.counts[id] = int(progress_value.counts[id])
			for field: String in ["registered", "claimed", "effective_levels"]:
				var canonical: Array = []
				for id: Variant in progress_value[field]: canonical.append(int(id))
				progress_value[field] = canonical
	changed.emit()
	return true

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 1 or not value.get("books") is Dictionary:
		return false
	for key: Variant in value.books:
		if not str(key).is_valid_int() or int(str(key)) <= 0:
			return false
		var book: Variant = value.books[key]
		if not book is Dictionary or not _integer(book.get("sequence")) or not book.get("epochs") is Dictionary or not book.get("current_epoch") is String:
			return false
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
			for field: String in ["registered", "claimed", "effective_levels"]:
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
	if clock.length() != 12 or not clock.is_valid_int(): return false
	var year := int(clock.substr(0,4))
	var month := int(clock.substr(4,2))
	var day := int(clock.substr(6,2))
	var hour := int(clock.substr(8,2))
	var minute := int(clock.substr(10,2))
	if year <= 0 or month < 1 or month > 12 or hour > 23 or minute > 59: return false
	var days: Array = [31,29 if year % 400 == 0 or (year % 4 == 0 and year % 100 != 0) else 28,31,30,31,30,31,31,30,31,30,31]
	return day >= 1 and day <= int(days[month-1])

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
			if not matches or not receipt.get("level_ids") is Array or receipt.level_ids.is_empty():
				return _fail("count_target_or_stages")
			var seen: Dictionary = {}
			for id: Variant in receipt.level_ids:
				if not _level_belongs(id, book_id) or seen.has(int(id)):
					return _fail("count_stage_identity")
				seen[int(id)] = true
				var key := str(int(id))
				stage.counts[key] = int(stage.counts.get(key, 0)) + 1
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
		_: return _fail("unknown_transition")
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
