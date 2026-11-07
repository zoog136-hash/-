extends RefCounted
## Source-backed state machine. Plans are immutable until the host saves them.
## Official guide: option1 name/value, option2 name/value are four lockable fields.
const SAVE_KEY := "weapon_mastery523"
const MAX_POINT_TEXT := "9223372036854775807"
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const RESET_TICKET = preload("res://scripts/mastery/mastery_reset_ticket.gd")
const ORIGINAL_CORE_TABLES := ["MasteryWeaponType","MasteryWeaponStep","MasteryWeaponLevelView",
	"MasteryBonusView","MasteryGradeView","MasteryGradeMatchingBonus","MasteryPointPayment",
	"MasteryPointPurchaseView","MasteryResetCost","ClassChangeMasteryLevelCost",
	"ClassChangeMasteryWeaponType","MasteryChangeLevelCost"]
const RESET_COLOR_TEXT_KEYS := [
	"MASTERY_POPUP_HELP\\ND_MASTERY_HELP01\\ND_STEP_3\\ND_TEXT\\TEXT_HELP",
	"MASTERY_POPUP_HELP\\ND_MASTERY_HELP02\\ND_STEP_7\\ND_TEXT\\TEXT_HELP"]
var tables: Dictionary = {}
var levels: Dictionary = {}
var options: Dictionary = {}
var bonuses: Dictionary = {}
var types: Dictionary = {}
var problem: String = ""
var operations: Dictionary = {}
var source_mode: String = ""
var source_identity: Dictionary = {}
var source_status: Dictionary = {}
var model_pack_sha256: String = ""

static func fresh() -> Dictionary:
	return {"version":1,"weapons":{},"receipts":{}}

static func fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}

static func point_text(value: Variant) -> bool:
	if not value is String or value.is_empty(): return false
	if value != "0" and value.begins_with("0"): return false
	for c: String in value:
		if c < "0" or c > "9": return false
	return value.length() < MAX_POINT_TEXT.length() or (value.length() == MAX_POINT_TEXT.length() and value <= MAX_POINT_TEXT)

func load_pack(path: String, sha256: String) -> bool:
	if sha256.length() != 64 or not FileAccess.file_exists(path):
		problem = "숙련 원본 팩 해시 또는 경로 오류"
		return false
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: problem = "숙련 팩 읽기 실패"; return false
	var size: int = file.get_length()
	if size > 8 * 1024 * 1024:
		file.close()
		problem = "숙련 팩 크기 초과"
		return false
	var bytes: PackedByteArray = file.get_buffer(size)
	file.close()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	if bytes.size() != size or context.finish().hex_encode() != sha256:
		problem = "숙련 원본 팩 해시 오류"; return false
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		problem = "숙련 팩 형식 오류"
		return false
	if not configure(parser.data): return false
	source_mode = "compiled_pack"
	model_pack_sha256 = sha256
	source_identity = {}
	source_status = {}
	return true

static func _first_original(rows: Array, field: String, value: Variant) -> Dictionary:
	for row: Dictionary in rows:
		if row.get(field) == value: return row
	return {}

static func _one_original(rows: Array) -> Dictionary:
	return rows[0] if rows.size()==1 else {}

static func _constant_id(row: Dictionary) -> int:
	var value: Variant = row.get("Value")
	if not value is String or not value.is_valid_int(): return -1
	var id: int = int(value)
	return id if str(id)==value else -1

static func _project_original(table: String, field: String, ids: Dictionary) -> Array:
	var result: Array = []
	# Preserve the compiler's original table order and complete projected rows.
	# Only matching rows are built (Bonus alone has 217,916 rows).
	for row: Dictionary in SOURCE.rows_matching(table,field,ids): result.append(row)
	return result

func _original_reset_ticket(projected: Dictionary, constants: Array) -> Dictionary:
	var constant: Dictionary = _first_original(constants,"Name","MasteryResetTicketCurrencyID")
	var currency: Dictionary = _first_original(projected.Currency,"ID",_constant_id(constant))
	var link: Dictionary = _first_original(projected.CurrencyUnitClass,"CurrencyID",currency.get("ID",-1))
	var item: Dictionary = SOURCE.row("ItemClass",int(link.get("ClassID",-1)))
	if currency.get("ID")!=1814 or link.get("UnitID")!=4 or item.get("ID")!=184652 or item.get("TestItem")!=false: return {}
	if not SOURCE.declared_exclusion("ItemClass",item).is_empty(): return {}
	# UNVERIFIED: this single original label is required by the existing ticket
	# fingerprint. Do not require an old monster-pack sidecar or use a same-name
	# host record when the new original definition is unavailable.
	var description_id: Variant = item.get("IdentifiedDescID")
	if typeof(description_id) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(description_id)) or float(description_id)!=floorf(float(description_id)) or absf(float(description_id))>9007199254740991.0: return {}
	var description: Dictionary = SOURCE.row("DescData_Korean",int(description_id))
	if description.get("ID")!=description_id or not description.get("Description") is String or str(description.Description).is_empty(): return {}
	var definition: Dictionary = {"constant":constant,"currency":currency,"currency_link":link,
		"item":item,"category":SOURCE.row("ItemCategory",int(item.CategoryID)),
		"grade":SOURCE.row("Grade",int(item.GradeID)),
		"bonuses":SOURCE.related("ItemBonus","ItemClassID",184652),
		"bless_codes":SOURCE.rows("ItemBlessCode"),"label":description.Description}
	var operation: Dictionary = {"definition":definition,
		"definition_sha256":JSON.stringify(RESET_TICKET.canonical(definition),"",true).sha256_text(),
		"source_input_identity":SOURCE.identity()}
	var reader = RESET_TICKET.new()
	return operation if reader.configure(operation) else {}

func _original_operations(projected: Dictionary, deferred: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var constants: Array = SOURCE.rows("ConstantData")
	var reset: Dictionary = _first_original(constants,"Name","MasteryPointPurchaseResetScheduleType")
	var schedule: Dictionary = SOURCE.row("ContentsResetScheduleType",_constant_id(reset))
	var powder_link: Dictionary = _first_original(projected.CurrencyUnitClass,"CurrencyID",1682)
	var powder: Dictionary = SOURCE.row("ItemClass",int(powder_link.get("ClassID",-1)))
	if powder_link.get("UnitID")==4 and powder.get("ID")==117544 and powder.get("TestItem")!=true and not schedule.is_empty():
		result["point_purchase"] = {"material":powder,"currency_link":powder_link,
			"schedule_constant":reset,"schedule":schedule,"automatic_period_reset_verified":false}
	else: deferred["point_purchase"] = "source_material_or_reset_schedule_missing"
	var purchase: Dictionary = SOURCE.row("MarketPurchase_Korean",95441)
	var payment: Dictionary = SOURCE.row("MarketPayment_Korean",int(purchase.get("MarketPaymentID",-1)))
	var product_link: Dictionary = _one_original(SOURCE.related("MarketPurchaseProduct","MarketPurchaseID",95441))
	var product: Dictionary = SOURCE.row("MarketProduct",int(product_link.get("MarketProductID",-1)))
	var start: Dictionary = SOURCE.row("DateTimes_Korean",int(purchase.get("EffectiveFromId",-1)))
	var end: Dictionary = SOURCE.row("DateTimes_Korean",int(purchase.get("EffectiveToId",-1)))
	if payment.get("UnitID")==201 and payment.get("ClassID")==4 and purchase.get("AdditionalCurrencyID")==4 and product.get("UnitID")==281 and product.get("ClassID")==101 and product.get("Amount")==1 and not start.is_empty() and not end.is_empty():
		result["mastery_change"] = {"purchase":purchase,"payment":payment,"product_link":product_link,"product":product,
			"from":start,"to":end,"restrictions":SOURCE.related("MarketPurchaseRestriction","MarketPurchaseId",95441),
			"repeat_restriction_verified":false}
	else: deferred["mastery_change"] = "source_service_payment_or_product_missing"
	var color_text: Array = []
	for row: Dictionary in SOURCE.rows("UIStaticTextData_Korean"):
		if row.get("TextDesc","") in RESET_COLOR_TEXT_KEYS: color_text.append(row)
	result["reset_color_draws"] = color_text
	if color_text.is_empty(): deferred["reset_color_draws"] = "source_reset_color_help_missing"
	var ticket: Dictionary = _original_reset_ticket(projected,constants)
	if ticket.is_empty(): deferred["reset_ticket"] = "ticket_source_missing:original_label_or_definition_unavailable"
	else: result["reset_ticket"] = ticket
	return result

func load_original() -> bool:
	# A supported compiled/live snapshot is never overwritten by a raw bootstrap.
	if not tables.is_empty(): return true
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty():
		source_status = {"state":"unavailable","reason":SOURCE.problem()}
		return false
	var projected: Dictionary = {}
	for table: String in ORIGINAL_CORE_TABLES: projected[table] = SOURCE.rows(table)
	var bonus_ids: Dictionary = {}
	for table: String in ["MasteryBonusView","MasteryGradeMatchingBonus"]:
		for row: Dictionary in projected[table]: bonus_ids[int(row.BonusID)] = true
	projected["Bonus"] = _project_original("Bonus","ID",bonus_ids)
	var type_ids: Dictionary = {}
	for row: Dictionary in projected.Bonus: type_ids[int(row.BonusTypeID)] = true
	projected["BonusType"] = _project_original("BonusType","ID",type_ids)
	var unit_ids: Dictionary = {}
	for row: Dictionary in projected.BonusType: unit_ids[int(row.UnitID)] = true
	projected["UIUnit"] = _project_original("UIUnit","UnitID",unit_ids)
	for table: String in ["Class","WeaponType","Currency","CurrencyUnitClass"]: projected[table] = SOURCE.rows(table)
	var deferred: Dictionary = {}
	var original_operations: Dictionary = _original_operations(projected,deferred)
	var pack: Dictionary = {"schema":"twilight.mastery523.v1","source_sha256":identity.get("source_sha256"),
		"private_original_data":true,"tables":projected,"operations":original_operations}
	if not configure(pack):
		source_status = {"state":"rejected","reason":problem,"operations_deferred":deferred}
		return false
	source_mode = "original_tables"
	source_identity = identity.duplicate(true)
	source_status = {"state":"loaded","operations_deferred":deferred}
	# model_pack_sha256 remains a separate compiled-file fingerprint.
	return true

func configure(pack: Dictionary) -> bool:
	# Build in a separate instance so a rejected replacement cannot damage live data.
	var staged = get_script().new()
	if not staged._configure(pack):
		problem = staged.problem
		return false
	tables = staged.tables
	levels = staged.levels
	options = staged.options
	bonuses = staged.bonuses
	types = staged.types
	operations = staged.operations
	problem = ""
	return true

func _configure(pack: Dictionary) -> bool:
	if pack.get("schema") != "twilight.mastery523.v1" or not pack.get("tables") is Dictionary:
		problem = "숙련 팩 스키마 오류"
		return false
	tables = pack.tables.duplicate(true)
	if not pack.get("operations",{}) is Dictionary: problem = "숙련 실행 자료 형식 오류"; return false
	operations = pack.get("operations",{}).duplicate(true)
	for name: String in ["MasteryWeaponType","MasteryWeaponStep","MasteryWeaponLevelView","MasteryBonusView","MasteryGradeView","MasteryGradeMatchingBonus","MasteryPointPayment","MasteryPointPurchaseView","MasteryResetCost","ClassChangeMasteryLevelCost","ClassChangeMasteryWeaponType","MasteryChangeLevelCost","Bonus","BonusType","UIUnit","Class","WeaponType","Currency","CurrencyUnitClass"]:
		if not tables.get(name) is Array:
			problem = "숙련 원본 표 누락: " + name
			return false
		var seen: Dictionary = {}
		for row: Variant in tables[name]:
			if not row is Dictionary or not row.has("ID") or seen.has(int(row.ID)):
				problem = "숙련 원본 행 중복/형식 오류"
				return false
			seen[int(row.ID)] = true
	for row: Dictionary in tables.MasteryWeaponLevelView:
		for key: String in ["WeaponTypeID","WeaponStepID","Level","CumulativePoint"]:
			if not row.has(key): problem = "숙련 임계치 필드 누락"; return false
		var weapon: int = int(row.WeaponTypeID)
		if not levels.has(weapon): levels[weapon] = []
		levels[weapon].append(row)
	for weapon: int in levels:
		if levels[weapon].size() != 8: problem = "숙련 성장 단계 누락"; return false
		levels[weapon].sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Level) < int(b.Level))
		var last: int = 0
		for i: int in levels[weapon].size():
			var row: Dictionary = levels[weapon][i]
			if int(row.Level) != i+1 or int(row.CumulativePoint) <= last:
				problem = "숙련 임계치 순서 오류"; return false
			last = int(row.CumulativePoint)
	for row: Dictionary in tables.Bonus: bonuses[int(row.ID)] = row
	for row: Dictionary in tables.BonusType: types[int(row.ID)] = row
	var sums: Dictionary = {}
	var bucket_types: Dictionary = {}
	var signatures: Dictionary = {}
	for row: Dictionary in tables.MasteryBonusView:
		for key: String in ["MasteryWeaponLevelID","BonusID","Slot","ClassChangeMasteryBonusGroupID","Probability"]:
			if not row.has(key): problem = "숙련 옵션 필드 누락"; return false
		var level_row: Dictionary = find_row("MasteryWeaponLevelView",int(row.MasteryWeaponLevelID))
		if level_row.is_empty() or not bonuses.has(int(row.BonusID)):
			problem = "숙련 옵션 참조 오류"; return false
		var bonus: Dictionary = bonuses[int(row.BonusID)]
		if not bonus.has("Value") or not types.has(int(bonus.get("BonusTypeID",-1))):
			problem = "숙련 보너스 참조 오류"; return false
		var group: int = int(row.ClassChangeMasteryBonusGroupID)
		var weapon: int = int(level_row.WeaponTypeID)
		if not options.has(group): options[group] = {}
		if options[group].has(weapon): problem = "숙련 전환 대응 중복"; return false
		var enriched: Dictionary = row.duplicate(true)
		enriched["level"] = int(level_row.Level)
		enriched["weapon"] = weapon
		options[group][weapon] = enriched
		var signature: Array = [int(level_row.Level),int(row.Slot),int(bonus.Value),int(row.Probability)]
		if signatures.has(group) and signatures[group] != signature:
			problem = "숙련 전환 대응 불일치"; return false
		signatures[group] = signature
		var bucket := "%d:%d:%d" % [weapon,int(level_row.Level),int(row.Slot)]
		if int(row.Slot) not in [1,2] or int(row.Probability) <= 0: problem = "숙련 슬롯/확률 오류"; return false
		if bucket_types.has(bucket) and bucket_types[bucket] != int(bonus.BonusTypeID): problem = "숙련 종류 슬롯 변동 오류"; return false
		bucket_types[bucket] = int(bonus.BonusTypeID)
		sums[bucket] = int(sums.get(bucket,0)) + int(row.Probability)
	if levels.size() != 15 or tables.MasteryWeaponLevelView.size() != 120 or options.size() != 36 or sums.size() != 240:
		problem = "숙련 원본 범위 오류"; return false
	for group: int in options:
		if options[group].size() != levels.size(): problem = "숙련 무기 대응 누락"; return false
	for total: int in sums.values():
		if total != 1000000: problem = "숙련 옵션 확률 합계 오류"; return false
	var color_total: int = 0
	for grade: Dictionary in tables.MasteryGradeView:
		if int(grade.get("Probability",0)) <= 0: problem = "숙련 색상 확률 오류"; return false
		color_total += int(grade.Probability)
	if color_total != 1000000: problem = "숙련 색상 확률 합계 오류"; return false
	var matching_keys: Dictionary = {}
	for matching: Dictionary in tables.MasteryGradeMatchingBonus:
		var step: Dictionary = find_row("MasteryWeaponStep",int(matching.get("WeaponStepID",-1)))
		var known_grade: bool = false
		for grade: Dictionary in tables.MasteryGradeView:
			if int(grade.GradeID) == int(matching.get("GradeID",-1)): known_grade = true
		var key := "%d:%d" % [int(matching.get("WeaponStepID",-1)),int(matching.get("GradeID",-1))]
		if step.is_empty() or not levels.has(int(step.get("WeaponTypeID",-1))) or not known_grade or not bonuses.has(int(matching.get("BonusID",-1))) or matching_keys.has(key): problem = "숙련 매칭 참조/중복 오류"; return false
		var bonus: Dictionary = bonuses[int(matching.BonusID)]
		if not bonus.has("Value") or not types.has(int(bonus.get("BonusTypeID",-1))): problem = "숙련 매칭 보너스 오류"; return false
		matching_keys[key] = true
	if matching_keys.size() != tables.MasteryWeaponStep.size()*tables.MasteryGradeView.size(): problem = "숙련 매칭 범위 누락"; return false
	return true

func find_row(table: String, id: int) -> Dictionary:
	for row: Dictionary in tables.get(table,[]):
		if int(row.get("ID",-1)) == id: return row.duplicate(true)
	return {}

func normalize_weapon(actual: int) -> int:
	for row: Dictionary in tables.get("MasteryWeaponType",[]):
		if int(row.ActualType) == actual: return int(row.BaseType)
	return 0

func record(state: Dictionary, weapon: int) -> Dictionary:
	return state.get("weapons",{}).get(str(weapon),{"points":"0","options":[],"colors":{},"locks":{}}).duplicate(true)

func achieved_level(weapon: int, points: String) -> int:
	if not point_text(points): return 0
	var result: int = 0
	for row: Dictionary in levels.get(weapon,[]):
		if int(points) >= int(row.CumulativePoint): result = int(row.Level)
	return result

func validate_state(state: Variant) -> String:
	if not state is Dictionary or state.get("version") != 1 or not state.get("weapons") is Dictionary or not state.get("receipts") is Dictionary:
		return "숙련 저장 형식 오류"
	if state.receipts.size() > 10000: return "숙련 영수증 수 초과"
	var purchases: int = 0
	for receipt: Variant in state.receipts:
		if not receipt is String or receipt.is_empty() or receipt.length() > 160 or not state.receipts[receipt] is Dictionary:
			return "숙련 영수증 형식 오류"
		if state.receipts[receipt].get("kind") == "point_purchase": purchases += 1
	var count: Variant = state.get("purchase_count",purchases)
	if purchases > 0 and not state.has("purchase_count"): return "숙련 구매 횟수 누락"
	if (not count is int and not count is float) or count != int(count) or count < 0 or int(count) != purchases: return "숙련 구매 이력 오류"
	for field: String in ["purchase_epoch","legacy_purchase_period"]:
		if state.has(field) and (not (state[field] is int or state[field] is float) or state[field] != int(state[field]) or state[field] < 0 or state[field] > 10000000): return "숙련 구매 주기 오류"
	for past: Dictionary in state.receipts.values():
		if past.get("kind") == "point_purchase" and past.has("period") and (not (past.period is int or past.period is float) or past.period != int(past.period) or past.period < 0 or past.period > 10000000): return "숙련 구매 영수증 주기 오류"
	if state.has("rng_state") and not (point_text(state.rng_state) or (state.rng_state is String and state.rng_state.begins_with("-") and (point_text(state.rng_state.substr(1)) or state.rng_state == "-9223372036854775808"))): return "숙련 난수 저장 오류"
	for key: Variant in state.weapons:
		if not key is String or not key.is_valid_int() or str(int(key)) != key or not levels.has(int(key)):
			return "숙련 무기 ID 오류"
		var entry: Variant = state.weapons[key]
		if not entry is Dictionary or not point_text(entry.get("points")) or not entry.get("options") is Array or not entry.get("colors") is Dictionary or not entry.get("locks") is Dictionary:
			return "숙련 진행도 형식 오류"
		if entry.options.size() > 16: return "숙련 옵션 수 초과"
		var seen: Dictionary = {}
		for option: Variant in entry.options:
			if not option is Dictionary or not option.get("group_id") is float and not option.get("group_id") is int: return "숙련 옵션 형식 오류"
			var group: int = int(option.group_id)
			if option.group_id != group or not options.has(group) or not options[group].has(int(key)): return "숙련 옵션 그룹 오류"
			var row: Dictionary = options[group][int(key)]
			var slot := "%d:%d" % [int(row.level),int(row.Slot)]
			if seen.has(slot): return "숙련 옵션 슬롯 중복"
			seen[slot] = true
		# Preserve partial legacy records; actions validate complete ownership.
		for section: String in ["colors","locks"]:
			for level_key: Variant in entry[section]:
				if not level_key is String or str(int(level_key)) != level_key or int(level_key) < 1 or int(level_key) > 8: return "숙련 색상 레벨 오류"
				var values: Variant = entry[section][level_key]
				if not values is Array or values.size() != 4: return "숙련 색상 슬롯 형식 오류"
				for value: Variant in values:
					if section == "locks":
						if not value is bool: return "숙련 잠금 형식 오류"
					else:
						var known: bool = false
						for grade: Dictionary in tables.MasteryGradeView:
							if value == grade.GradeID: known = true
						if not known: return "숙련 색상 ID 오류"
	return ""

func active_options(state: Dictionary, weapon: int) -> Array:
	var entry: Dictionary = record(state,weapon)
	var level: int = achieved_level(weapon,entry.points)
	var out: Array = []
	for option: Dictionary in entry.options:
		var row: Dictionary = options[int(option.group_id)][weapon]
		if int(row.level) <= level:
			var bonus: Dictionary = bonuses[int(row.BonusID)].duplicate(true)
			bonus["type_name"] = str(types[int(bonus.BonusTypeID)].Name)
			bonus["source_option_id"] = int(row.ID)
			out.append(bonus)
	return out

func matching_bonus(weapon: int, grade_id: int) -> Dictionary:
	# NC's 2021-05-26 table grants the flat bonus at each matched level.
	for step: Dictionary in tables.MasteryWeaponStep:
		if int(step.WeaponTypeID) != weapon: continue
		for row: Dictionary in tables.MasteryGradeMatchingBonus:
			if int(row.WeaponStepID) == int(step.ID) and int(row.GradeID) == grade_id:
				return bonuses.get(int(row.BonusID),{}).duplicate(true)
	return {}

func active_matching_bonuses(state: Dictionary, weapon: int) -> Array:
	var entry: Dictionary = record(state,weapon)
	var achieved: int = achieved_level(weapon,entry.points)
	var out: Array = []
	for key: String in entry.colors:
		var level: int = int(key)
		if level > achieved or _owned_slots(entry,weapon,level).size() != 2: continue
		var colors: Array = entry.colors[key]
		if colors[0] != colors[1] or colors[0] != colors[2] or colors[0] != colors[3]: continue
		var bonus: Dictionary = matching_bonus(weapon,int(colors[0]))
		if bonus.is_empty(): continue
		bonus["type_name"] = str(types[int(bonus.BonusTypeID)].Name)
		bonus["mastery_level"] = level
		bonus["grade_id"] = int(colors[0])
		out.append(bonus)
	return out

func reset_quote(state: Dictionary, weapon: int, level_scope: Array = []) -> Dictionary:
	if not levels.has(weapon): return {}
	var locks: int = 0
	var entry: Dictionary = record(state,weapon)
	for key: String in entry.locks:
		if not level_scope.is_empty() and int(key) not in level_scope: continue
		var values: Array = entry.locks[key]
		for locked: bool in values:
			if locked: locks += 1
	for row: Dictionary in tables.MasteryResetCost:
		if int(row.Step) == 1 and int(row.LockSlotCount) == locks: return row.duplicate(true)
	return {}

func transfer_cost(level: int, route: String) -> Dictionary:
	if route not in ["class_change","mastery_change"]: return {}
	var table: String = "ClassChangeMasteryLevelCost" if route == "class_change" else "MasteryChangeLevelCost"
	var field: String = "MasteryWeaponLevel" if route == "class_change" else "MasteryLevel"
	for row: Dictionary in tables.get(table,[]):
		if int(row[field]) == level:
			var out: Dictionary = row.duplicate(true)
			out["currency_resolved"] = false
			return out
	return {}

func _plan(before: Dictionary, after: Dictionary, receipt: String, kind: String, charge: Dictionary = {}) -> Dictionary:
	if receipt.is_empty() or receipt.length() > 160 or before.receipts.has(receipt): return fail("duplicate_or_missing_receipt")
	after.receipts[receipt] = {"kind":kind}
	var error: String = validate_state(after)
	if not error.is_empty(): return fail(error)
	return {"ok":true,"before":before.duplicate(true),"after":after,"charge":charge.duplicate(true),"kind":kind,"receipt_id":receipt}

func plan_points(state: Dictionary, weapon: int, amount: String, receipt: String) -> Dictionary:
	if not validate_state(state).is_empty() or not levels.has(weapon) or not point_text(amount) or amount == "0": return fail("invalid_points")
	var entry: Dictionary = record(state,weapon)
	if int(amount) > int(MAX_POINT_TEXT)-int(entry.points): return fail("point_overflow")
	entry.points = str(int(entry.points)+int(amount))
	var after: Dictionary = state.duplicate(true)
	after.weapons[str(weapon)] = entry
	return _plan(state,after,receipt,"confirmed_point_credit")

func plan_reset(state: Dictionary, weapon: int, confirmed: Dictionary, receipt: String) -> Dictionary:
	if not validate_state(state).is_empty() or not levels.has(weapon): return fail("invalid_state")
	# Legacy externally supplied outcomes lack field-level draw provenance.
	# Locked gameplay resets use plan_reroll, with the verified field mapping.
	var old: Dictionary = record(state,weapon)
	for values: Array in old.locks.values():
		if true in values: return fail("locked_reset_mapping_unconfirmed")
	if confirmed.get("points") != old.points or confirmed.get("locks") != old.locks: return fail("reset_changed_points_or_locks")
	for level_key: String in old.locks:
		for i: int in 4:
			if old.locks[level_key][i] and (not confirmed.get("colors",{}).has(level_key) or not old.colors.has(level_key) or confirmed.colors[level_key][i] != old.colors[level_key][i]): return fail("reset_changed_locked_color")
	var after: Dictionary = state.duplicate(true)
	after.weapons[str(weapon)] = confirmed.duplicate(true)
	return _plan(state,after,receipt,"confirmed_reset",reset_quote(state,weapon))

func plan_lock(state: Dictionary, weapon: int, level: int, slot: int, locked: bool, receipt: String) -> Dictionary:
	if not validate_state(state).is_empty() or not levels.has(weapon) or slot < 0 or slot >= 4: return fail("invalid_lock")
	var entry: Dictionary = record(state,weapon)
	var key: String = str(level)
	if not entry.colors.has(key): return fail("color_not_owned")
	if not entry.locks.has(key): entry.locks[key] = [false,false,false,false]
	entry.locks[key][slot] = locked
	var after: Dictionary = state.duplicate(true)
	after.weapons[str(weapon)] = entry
	return _plan(state,after,receipt,"color_lock")

func plan_class_change(state: Dictionary, from_weapon: int, to_weapon: int, to_class: int, prefix_level: int, confirmed_points: String, receipt: String, target_policy: String = "block_unverified") -> Dictionary:
	if not validate_state(state).is_empty() or from_weapon == to_weapon or not levels.has(from_weapon) or not levels.has(to_weapon): return fail("invalid_transfer")
	var allowed: bool = false
	for target: Dictionary in tables.ClassChangeMasteryWeaponType:
		if int(target.ToCharacterClass) == to_class and int(target.ToWeaponType) == to_weapon: allowed = true
	if not allowed: return fail("class_destination_not_allowed")
	if not point_text(confirmed_points): return fail("point_conversion_unconfirmed")
	var source: Dictionary = record(state,from_weapon)
	var target: Dictionary = record(state,to_weapon)
	if prefix_level < 0 or prefix_level > achieved_level(from_weapon,source.points) or source.points == "0": return fail("option_prefix_not_acquired")
	if target_policy not in ["block_unverified","preserve_existing","clear_existing"]: return fail("unknown_target_option_policy")
	if prefix_level == 0 and (not target.options.is_empty() or not target.colors.is_empty() or not target.locks.is_empty()):
		if target_policy == "block_unverified": return fail("target_option_policy_unconfirmed")
		if target_policy == "clear_existing": target.options = []; target.colors = {}; target.locks = {}
	if prefix_level > 0:
		target.options = []
		for option: Dictionary in source.options:
			var group: int = int(option.group_id)
			if int(options[group][from_weapon].level) <= prefix_level:
				# Keep group/value, resolve a different BonusID/BonusType at use time.
				target.options.append(option.duplicate(true))
		target.colors = {}
		for level_key: String in source.colors:
			if int(level_key) <= prefix_level: target.colors[level_key] = source.colors[level_key].duplicate()
	target.points = confirmed_points
	if prefix_level > 0 or target_policy != "preserve_existing": target.locks = {}
	var after: Dictionary = state.duplicate(true)
	after.weapons[str(to_weapon)] = target
	# Retire known source progress without dropping opaque future/user fields.
	source.points = "0"
	source.options = []; source.colors = {}; source.locks = {}
	after.weapons[str(from_weapon)] = source
	var plan: Dictionary = _plan(state,after,receipt,"class_change",transfer_cost(prefix_level,"class_change") if prefix_level > 0 else {})
	if plan.ok: plan["service_confirmation_required"] = true
	return plan

func server_choice(source: Dictionary, destination: Dictionary, confirmed_comparison: int) -> Dictionary:
	# Comparison is supplied by the service adapter: the native comparison key
	# is not established. A tie selects the departure state. Never add values.
	if confirmed_comparison not in [-1,0,1]: return fail("server_comparison_unconfirmed")
	return {"ok":true,"record":(source if confirmed_comparison >= 0 else destination).duplicate(true),"origin":"departure" if confirmed_comparison >= 0 else "destination"}

func plan_server_import(destination: Dictionary, departure: Dictionary, comparisons: Dictionary, receipt: String) -> Dictionary:
	if not validate_state(destination).is_empty() or not validate_state(departure).is_empty(): return fail("invalid_server_state")
	if departure.receipts.has(receipt): return fail("duplicate_server_receipt")
	var after: Dictionary = destination.duplicate(true)
	for id: String in departure.receipts:
		if after.receipts.has(id) and after.receipts[id] != departure.receipts[id]: return fail("server_receipt_conflict")
		after.receipts[id] = departure.receipts[id].duplicate(true)
	for key: String in departure.weapons:
		if not comparisons.has(key) or comparisons[key] not in [-1,0,1]: return fail("server_comparison_unconfirmed")
		var selected: Dictionary = server_choice(departure.weapons[key],record(destination,int(key)),int(comparisons[key]))
		after.weapons[key] = selected.record
	# This is a two-sided plan. The service adapter must retire the departure
	# record durably; the single-player host must not pretend to be two servers.
	var plan: Dictionary = _plan(destination,after,receipt,"server_import")
	if plan.ok:
		plan["departure_before"] = departure.duplicate(true)
		plan["departure_after"] = departure.duplicate(true)
		plan.departure_after.weapons = {}
		plan.departure_after.receipts[receipt] = {"kind":"server_departure"}
		plan["requires_two_sided_commit"] = true
	return plan

func purchase_usage(state: Dictionary, period: int) -> Dictionary:
	var epoch: int = maxi(period,int(state.get("purchase_epoch",period)))
	for past: Dictionary in state.receipts.values():
		if past.get("kind") == "point_purchase" and past.has("period"): epoch = maxi(epoch,int(past.period))
	var legacy: int = int(state.get("legacy_purchase_period",epoch))
	var count: int = 0
	for past: Dictionary in state.receipts.values():
		if past.get("kind") == "point_purchase" and int(past.get("period",legacy)) == epoch: count += 1
	return {"period":epoch,"count":count,"legacy_period":legacy}

func plan_purchase(state: Dictionary, weapon: int, receipt: String, period: int = -1) -> Dictionary:
	if not validate_state(state).is_empty(): return fail("invalid_state")
	if not operations.get("point_purchase") is Dictionary: return fail("operation_source_missing")
	var usage: Dictionary = purchase_usage(state,period) if period >= 0 else {"count":int(state.get("purchase_count",0))}
	var count: int = int(usage.count)
	var payment: Dictionary = {}
	for row: Dictionary in tables.MasteryPointPayment:
		if int(row.Count) == count+1: payment = row
	if payment.is_empty(): return fail("daily_purchase_limit" if period >= 0 else "purchase_reset_boundary_unverified")
	if tables.MasteryPointPurchaseView.size() != 1: return fail("point_amount_ambiguous")
	var plan: Dictionary = plan_points(state,weapon,str(int(tables.MasteryPointPurchaseView[0].PointAmount)),receipt)
	if not plan.ok: return plan
	plan.kind = "point_purchase"
	plan.after.receipts[receipt] = {"kind":"point_purchase","payment_id":int(payment.ID)}
	plan.after.purchase_count = int(state.get("purchase_count",0))+1
	if period >= 0:
		plan.after.receipts[receipt].period = usage.period
		plan.after.purchase_epoch = usage.period
		plan.after.legacy_purchase_period = usage.legacy_period
	plan.charge = payment.duplicate(true)
	return plan

func fixed_reset_availability(state: Dictionary, weapon: int) -> Dictionary:
	if not validate_state(state).is_empty() or not levels.has(weapon): return fail("invalid_state")
	if not operations.get("reset_color_draws") is Array or operations.reset_color_draws.size() != 2: return fail("color_draw_source_missing")
	var entry: Dictionary = record(state,weapon)
	if entry.colors.is_empty() or entry.options.is_empty(): return fail("owned_options_required")
	for locks: Array in entry.locks.values():
		if true in locks: return fail("locked_value_mapping_unverified")
	var known_levels: Dictionary = {}
	for option: Dictionary in entry.options:
		var row: Dictionary = options[int(option.group_id)][weapon]
		if int(row.Probability) != 1000000: return fail("variable_value_mapping_unverified")
		known_levels[str(row.level)] = true
	for key: String in entry.colors:
		if not known_levels.has(key): return fail("color_value_ownership_unverified")
		if _owned_slots(entry,weapon,int(key)).size() != 2: return fail("partial_owned_level")
	var charge: Dictionary = reset_quote(state,weapon)
	if charge.is_empty() or int(charge.CurrencyID) != 1: return fail("reset_currency_unverified")
	return {"ok":true,"charge":charge}

func plan_fixed_reset(state: Dictionary, weapon: int, rng: RandomNumberGenerator, receipt: String) -> Dictionary:
	var availability: Dictionary = fixed_reset_availability(state,weapon)
	if not availability.ok: return availability
	var entry: Dictionary = record(state,weapon)
	for key: String in entry.colors:
		for slot: int in 4:
			var roll: int = rng.randi_range(0,999999)
			var found: bool = false
			for grade: Dictionary in tables.MasteryGradeView:
				roll -= int(grade.Probability)
				if roll < 0: entry.colors[key][slot] = int(grade.GradeID); found = true; break
			if not found: return fail("color_probability_invalid")
	var after: Dictionary = state.duplicate(true)
	after.weapons[str(weapon)] = entry
	after.rng_state = str(rng.state)
	# Every existing value in this path has exactly one 100% source outcome.
	# Values remain the same without guessing four-color/Slot1/2 coupling.
	return _plan(state,after,receipt,"fixed_value_color_reset",availability.charge)

func plan_local_change(state: Dictionary, source: int, target: int, class_id: int, prefix: int, receipt: String, year: int, target_policy: String = "block_unverified") -> Dictionary:
	if not validate_state(state).is_empty(): return fail("invalid_state")
	var service: Dictionary = operations.get("mastery_change",{})
	if service.is_empty(): return fail("operation_source_missing")
	if int(service.purchase.get("ID",0)) != 95441: return fail("unsupported_mastery_service")
	if not bool(service.purchase.OnSale) or year <= int(service.from.Year) or year >= int(service.to.Year): return fail("service_sale_boundary_unverified")
	# Official 2024-12-04 product notice explicitly permits unlimited purchases.
	# Generic restriction12 remains raw evidence, not a decoded daily cap.
	if not point_text(record(state,source).points) or not point_text(record(state,target).points): return fail("invalid_points")
	var source_points: int = int(record(state,source).points)
	var target_points: int = int(record(state,target).points)
	if source_points > int(MAX_POINT_TEXT)-target_points: return fail("point_overflow")
	if prefix > 0:
		var owned: Dictionary = record(state,source)
		for level: int in range(1,prefix+1):
			if _owned_slots(owned,source,level).size() != 2 or not owned.colors.has(str(level)): return fail("option_prefix_not_acquired")
	# TWILIGHT stores the source raw cumulative integer, so the documented sum
	# is exact. No level copy, scaling, rounding or invented cap is applied.
	var plan: Dictionary = plan_class_change(state,source,target,class_id,prefix,str(source_points+target_points),receipt,target_policy)
	if not plan.ok: return plan
	var additional: int = 0
	if prefix > 0:
		var fee: Dictionary = transfer_cost(prefix,"mastery_change")
		if fee.is_empty(): return fail("additional_cost_missing")
		additional = int(fee.CurrencyCost)
	var currency: int = int(service.payment.ClassID)
	if int(service.payment.UnitID) != 201 or currency != int(service.purchase.AdditionalCurrencyID): return fail("additional_currency_unresolved")
	plan.kind = "local_mastery_change"
	plan.after.receipts[receipt] = {"kind":"local_mastery_change","purchase_id":int(service.purchase.ID),"point_policy":"raw_cumulative_integer_sum"}
	if prefix == 0:
		plan.after.receipts[receipt]["custom_point_only_target_policy"] = target_policy
	plan.service_confirmation_required = false
	plan.charge = {"CurrencyID":currency,"Cost":int(service.payment.Amount)+additional,"BaseCost":int(service.payment.Amount),"AdditionalCost":additional,"MarketPurchaseID":int(service.purchase.ID)}
	return plan

func _owned_slots(entry: Dictionary, weapon: int, level: int) -> Dictionary:
	var slots: Dictionary = {}
	for index: int in entry.options.size():
		var row: Dictionary = options[int(entry.options[index].group_id)][weapon]
		if int(row.level) == level: slots[int(row.Slot)] = index
	return slots

func acquire_availability(state: Dictionary, weapon: int, level: int, charge: Dictionary) -> Dictionary:
	if not validate_state(state).is_empty() or not levels.has(weapon): return fail("invalid_state")
	var entry: Dictionary = record(state,weapon)
	if level < 1 or level > achieved_level(weapon,entry.points): return fail("level_not_reached")
	if not _owned_slots(entry,weapon,level).is_empty() or entry.colors.has(str(level)) or entry.locks.has(str(level)): return fail("level_already_or_partly_owned")
	return {"ok":true,"charge":charge.duplicate(true)}

func partial_status(state: Dictionary, weapon: int) -> Dictionary:
	if not validate_state(state).is_empty() or not levels.has(weapon): return fail("invalid_state")
	var entry: Dictionary = record(state,weapon)
	var owned_levels: Dictionary = {}
	for option: Dictionary in entry.options: owned_levels[int(options[int(option.group_id)][weapon].level)] = true
	for section: String in ["colors","locks"]:
		for key: String in entry[section]: owned_levels[int(key)] = true
	var complete: Array = []
	var frozen: Array = []
	var repairs: Array = []
	for level: int in owned_levels:
		var slots: Dictionary = _owned_slots(entry,weapon,level)
		if slots.size() == 2 and entry.colors.has(str(level)): complete.append(level); continue
		frozen.append(level)
		# At least one original option plus all four existing colors establishes
		# a partial owned level. Only an absent, unique100% value can be inferred.
		# Never draw an unknown variable value, color, lock or entire empty level.
		if slots.size() != 1 or not entry.colors.has(str(level)): continue
		for slot: int in [1,2]:
			if slots.has(slot): continue
			var candidates: Array = []
			for group: int in options:
				var row: Dictionary = options[group][weapon]
				if int(row.level) == level and int(row.Slot) == slot: candidates.append(row)
			if candidates.size() == 1 and int(candidates[0].Probability) == 1000000:
				repairs.append({"level":level,"slot":slot,"group_id":int(candidates[0].ClassChangeMasteryBonusGroupID)})
	complete.sort(); frozen.sort()
	return {"ok":true,"complete":complete,"frozen":frozen,"repairs":repairs}

func plan_partial_repair(state: Dictionary, weapon: int, receipt: String, charge: Dictionary) -> Dictionary:
	var status: Dictionary = partial_status(state,weapon)
	if not status.ok: return status
	if status.repairs.is_empty(): return fail("no_fixed_partial_repair")
	var after: Dictionary = state.duplicate(true)
	var entry: Dictionary = record(state,weapon)
	for repair: Dictionary in status.repairs: entry.options.append({"group_id":int(repair.group_id)})
	after.weapons[str(weapon)] = entry
	var plan: Dictionary = _plan(state,after,receipt,"partial_option_repair",charge)
	if plan.ok: plan.after.receipts[receipt]["custom_repair"] = {"policy":"fixed_missing_values_only","restored":status.repairs.duplicate(true),"rerolled":false}
	return plan

func reroll_availability(state: Dictionary, weapon: int, partial_mode: String = "block_weapon") -> Dictionary:
	if not validate_state(state).is_empty() or not levels.has(weapon): return fail("invalid_state")
	var entry: Dictionary = record(state,weapon)
	if entry.options.is_empty() or entry.colors.is_empty(): return fail("owned_options_required")
	if partial_mode not in ["block_weapon","complete_levels_only"]: return fail("unknown_partial_reset_policy")
	var scope: Dictionary = partial_status(state,weapon)
	if not scope.frozen.is_empty() and partial_mode == "block_weapon": return fail("partial_owned_level")
	if scope.complete.is_empty(): return fail("partial_owned_level")
	var unlocked: bool = false
	for level: int in scope.complete:
		for lock: bool in entry.locks.get(str(level),[false,false,false,false]):
			if not lock: unlocked = true
	if not unlocked: return fail("all_fields_locked")
	var charge: Dictionary = reset_quote(state,weapon,scope.complete)
	if charge.is_empty() or int(charge.CurrencyID) not in [1,4]: return fail("reset_currency_unverified")
	return {"ok":true,"charge":charge,"levels":scope.complete,"frozen":scope.frozen}

func _draw_grade(rng: RandomNumberGenerator) -> int:
	var roll: int = rng.randi_range(0,999999)
	for grade: Dictionary in tables.MasteryGradeView:
		roll -= int(grade.Probability)
		if roll < 0: return int(grade.GradeID)
	return -1

func _draw_group(weapon: int, level: int, slot: int, rng: RandomNumberGenerator) -> int:
	var roll: int = rng.randi_range(0,999999)
	for group: int in options:
		var row: Dictionary = options[group][weapon]
		if int(row.level) != level or int(row.Slot) != slot: continue
		roll -= int(row.Probability)
		if roll < 0: return group
	return -1

func plan_acquire(state: Dictionary, weapon: int, level: int, rng: RandomNumberGenerator, receipt: String, charge: Dictionary, color_mode: String = "independent_fields") -> Dictionary:
	if color_mode not in ["independent_fields","shared_level"]: return fail("unknown_color_draw_policy")
	var available: Dictionary = acquire_availability(state,weapon,level,charge)
	if not available.ok: return available
	var entry: Dictionary = record(state,weapon)
	for slot: int in [1,2]: entry.options.append({"group_id":_draw_group(weapon,level,slot,rng)})
	entry.colors[str(level)] = []
	var shared_grade: int = _draw_grade(rng) if color_mode == "shared_level" else -1
	for field: int in 4: entry.colors[str(level)].append(shared_grade if color_mode == "shared_level" else _draw_grade(rng))
	entry.locks[str(level)] = [false,false,false,false]
	var after: Dictionary = state.duplicate(true)
	after.weapons[str(weapon)] = entry
	after.rng_state = str(rng.state)
	return _plan(state,after,receipt,"level_option_acquire",available.charge)

func plan_reroll(state: Dictionary, weapon: int, rng: RandomNumberGenerator, receipt: String, color_mode: String = "independent_fields", partial_mode: String = "block_weapon") -> Dictionary:
	if color_mode not in ["independent_fields","shared_level"]: return fail("unknown_color_draw_policy")
	var available: Dictionary = reroll_availability(state,weapon,partial_mode)
	if not available.ok: return available
	var entry: Dictionary = record(state,weapon)
	for key: String in entry.colors:
		if int(key) not in available.levels: continue
		var slots: Dictionary = _owned_slots(entry,weapon,int(key))
		var locks: Array = entry.locks.get(key,[false,false,false,false])
		var shared_grade: int = _draw_grade(rng) if color_mode == "shared_level" and false in locks else -1
		# Fixed BonusType in all240 buckets: name fields reroll only color;
		# numerical fields reroll their original Slot1/2 value and own color.
		for field: int in 4:
			if locks[field]: continue
			if field % 2 == 1:
				var slot: int = 1 if field == 1 else 2
				entry.options[int(slots[slot])] = {"group_id":_draw_group(weapon,int(key),slot,rng)}
			entry.colors[key][field] = shared_grade if color_mode == "shared_level" else _draw_grade(rng)
	var after: Dictionary = state.duplicate(true)
	after.weapons[str(weapon)] = entry
	after.rng_state = str(rng.state)
	var plan: Dictionary = _plan(state,after,receipt,"option_field_reset",available.charge)
	if plan.ok and not available.frozen.is_empty(): plan.after.receipts[receipt]["custom_partial_scope"] = {"rerolled_levels":available.levels.duplicate(),"preserved_levels":available.frozen.duplicate()}
	return plan
