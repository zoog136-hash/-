extends RefCounted
## Source-backed state machine. Plans are immutable until the host saves them.
## Native four-color/Slot1/2 coupling and server point conversion remain unknown.
const SAVE_KEY := "weapon_mastery523"
const MAX_POINT_TEXT := "9223372036854775807"
var tables: Dictionary = {}
var levels: Dictionary = {}
var options: Dictionary = {}
var bonuses: Dictionary = {}
var types: Dictionary = {}
var problem: String = ""

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
	if sha256.length() != 64 or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != sha256:
		problem = "숙련 원본 팩 해시 또는 경로 오류"
		return false
	if FileAccess.get_file_as_bytes(path).size() > 8 * 1024 * 1024:
		problem = "숙련 팩 크기 초과"
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		problem = "숙련 팩 형식 오류"
		return false
	return configure(parser.data)

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
	problem = ""
	return true

func _configure(pack: Dictionary) -> bool:
	if pack.get("schema") != "twilight.mastery523.v1" or not pack.get("tables") is Dictionary:
		problem = "숙련 팩 스키마 오류"
		return false
	tables = pack.tables.duplicate(true)
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
		sums[bucket] = int(sums.get(bucket,0)) + int(row.Probability)
	if levels.size() != 15 or tables.MasteryWeaponLevelView.size() != 120 or options.size() != 36 or sums.size() != 240:
		problem = "숙련 원본 범위 오류"; return false
	for group: int in options:
		if options[group].size() != levels.size(): problem = "숙련 무기 대응 누락"; return false
	for total: int in sums.values():
		if total != 1000000: problem = "숙련 옵션 확률 합계 오류"; return false
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
	for receipt: Variant in state.receipts:
		if not receipt is String or receipt.is_empty() or receipt.length() > 160 or not state.receipts[receipt] is Dictionary:
			return "숙련 영수증 형식 오류"
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
		# Colors and locks are independent original four-slot information. No
		# unproven relationship to BonusView Slot1/2 is manufactured.
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
	# Lookup only: the native four-color matching activation rule is unknown.
	for step: Dictionary in tables.MasteryWeaponStep:
		if int(step.WeaponTypeID) != weapon: continue
		for row: Dictionary in tables.MasteryGradeMatchingBonus:
			if int(row.WeaponStepID) == int(step.ID) and int(row.GradeID) == grade_id:
				return bonuses.get(int(row.BonusID),{}).duplicate(true)
	return {}

func reset_quote(state: Dictionary, weapon: int) -> Dictionary:
	if not levels.has(weapon): return {}
	var locks: int = 0
	for values: Array in record(state,weapon).locks.values():
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
	# The caller supplies a confirmed outcome. Independent color and option
	# probability tables do not establish which reroll consumes each lock.
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

func plan_class_change(state: Dictionary, from_weapon: int, to_weapon: int, to_class: int, prefix_level: int, confirmed_points: String, receipt: String) -> Dictionary:
	if not validate_state(state).is_empty() or from_weapon == to_weapon or not levels.has(from_weapon) or not levels.has(to_weapon): return fail("invalid_transfer")
	var allowed: bool = false
	for target: Dictionary in tables.ClassChangeMasteryWeaponType:
		if int(target.ToCharacterClass) == to_class and int(target.ToWeaponType) == to_weapon: allowed = true
	if not allowed: return fail("class_destination_not_allowed")
	if not point_text(confirmed_points): return fail("point_conversion_unconfirmed")
	var source: Dictionary = record(state,from_weapon)
	var target: Dictionary = record(state,to_weapon)
	if prefix_level < 0 or prefix_level > achieved_level(from_weapon,source.points) or source.points == "0": return fail("option_prefix_not_acquired")
	if prefix_level == 0 and (not target.options.is_empty() or not target.colors.is_empty() or not target.locks.is_empty()): return fail("target_option_policy_unconfirmed")
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
	target.locks = {}
	var after: Dictionary = state.duplicate(true)
	after.weapons[str(to_weapon)] = target
	after.weapons[str(from_weapon)] = {"points":"0","options":[],"colors":{},"locks":{}}
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
