extends RefCounted
## UNVERIFIED: replace only already selected, exactly equal original rows.
## No selection, derived values, eligibility, ownership, effects, or persistence.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const INTERVAL_JOINS = ["bonus","bonus_type","unit","ui_unit","application_type","application_target"]

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 9007199254740991.0

static func _source_row(table: String, cached: Variant, foreign_key: String = "") -> Variant:
	if not cached is Dictionary or cached.is_empty() or table in SOURCE.EXCLUDED_TABLES: return null
	if cached.has("ID"):
		if not _integer(cached.ID): return null
		var original: Dictionary = SOURCE.row(table,int(cached.ID))
		return original if not original.is_empty() and original == cached else null
	# Compound membership/server/UI-unit rows have no invented primary ID.
	# Use only the compiler's declared FK, then compare the entire source row.
	if foreign_key.is_empty() or not _integer(cached.get(foreign_key)): return null
	var match: Variant = null
	for original: Dictionary in SOURCE.related(table,foreign_key,int(cached[foreign_key])):
		if original != cached: continue
		if match != null: return null
		match = original
	return match

static func _field(container: Dictionary, key: String, table: String, foreign_key: String = "") -> Variant:
	var original: Variant = _source_row(table,container.get(key),foreign_key)
	if original != null: container[key] = original
	return original

static func _target(container: Dictionary, bonus: Variant, application: Variant, wrapped: bool) -> void:
	if not bonus is Dictionary or not application is Dictionary: return
	if not _integer(bonus.get("BonusApplicationTypeID")) or not _integer(bonus.get("BonusApplicationTargetID")) or bonus.BonusApplicationTypeID != application.get("ID"): return
	var table: Variant = application.get("Name")
	if not table is String or not table.is_valid_identifier(): return
	var cached: Variant = container.get("application_target")
	if wrapped:
		if not cached is Dictionary or cached.get("target_table") != table or cached.get("BonusApplicationTypeID") != application.ID or cached.get("target_id") != bonus.BonusApplicationTargetID: return
		var raw: Variant = cached.get("target_row")
		if not raw is Dictionary or raw.get("ID") != bonus.BonusApplicationTargetID: return
		var original: Variant = _source_row(table,raw)
		if original != null: cached.target_row = original
	else:
		if not cached is Dictionary or cached.get("ID") != bonus.BonusApplicationTargetID: return
		var original: Variant = _source_row(table,cached)
		if original != null: container.application_target = original

static func _interval(cached: Dictionary) -> Dictionary:
	# build_collections adds exactly these six fields to IntervalBonus's raw
	# base row. Nothing else may be removed to manufacture an apparent match.
	var base: Dictionary = cached.duplicate()
	for field: String in INTERVAL_JOINS: base.erase(field)
	var original: Variant = _source_row("IntervalBonus",base,"IntervalBonusCategory")
	if original == null: return cached
	var result: Dictionary = original
	for field: String in INTERVAL_JOINS:
		if cached.has(field): result[field] = cached[field]
	var bonus: Variant = _field(result,"bonus","Bonus")
	_field(result,"bonus_type","BonusType")
	_field(result,"unit","Unit")
	_field(result,"ui_unit","UIUnit","UnitID")
	var application: Variant = _field(result,"application_type","BonusApplicationType")
	_target(result,bonus,application,false)
	return result

static func _effect(effect: Dictionary, collection_id: Variant) -> void:
	var original: Variant = effect.get("source_original")
	if not original is Dictionary: return
	var link: Variant = original.get("link")
	if link is Dictionary and link.get("BuffCardCollectionID") == collection_id:
		_field(original,"link","BuffCardCollectionBonus","BuffCardCollectionID")
	var bonus: Variant = _field(original,"bonus","Bonus")
	_field(original,"bonus_type","BonusType")
	var unit: Variant = _field(original,"unit","Unit")
	_field(original,"ui_unit","UIUnit","UnitID")
	var application: Variant = _field(original,"application_type","BonusApplicationType")
	_target(original,bonus,application,true)
	if not bonus is Dictionary or not unit is Dictionary or unit.get("Name") != "IntervalBonusCategoryID" or not original.get("nested_intervals") is Array: return
	var intervals: Array = original.nested_intervals
	for index: int in range(intervals.size()):
		var interval: Variant = intervals[index]
		if interval is Dictionary and interval.get("IntervalBonusCategory") == bonus.get("Value"):
			intervals[index] = _interval(interval)

static func _selected_rows(data: Dictionary, key: String, table: String, foreign_key: String = "") -> void:
	if not data.get(key) is Array: return
	var rows: Array = data[key]
	for index: int in range(rows.size()):
		var original: Variant = _source_row(table,rows[index],foreign_key)
		if original != null: rows[index] = original

static func adopt_selected(data: Dictionary) -> Dictionary:
	if data.get("source_snapshot") != "patch523" or data.get("source_zip_sha256") != SOURCE.SOURCE_SHA: return data
	if SOURCE.identity().get("source_sha256") != SOURCE.SOURCE_SHA: return data
	var result: Dictionary = data.duplicate(true)
	if result.get("collections") is Array:
		for collection: Variant in result.collections:
			if not collection is Dictionary: continue
			var cached: Variant = collection.get("source_original")
			var collection_id: Variant = cached.get("ID") if cached is Dictionary else null
			_field(collection,"source_original","BuffCardCollection")
			_field(collection,"source_grade","Grade")
			_field(collection,"source_deck","BuffCardDeck")
			if collection.get("requirements") is Array:
				for requirement: Variant in collection.requirements:
					if not requirement is Dictionary: continue
					var member: Variant = requirement.get("source_original")
					if member is Dictionary and member.get("BuffCardCollectionID") == collection_id:
						_field(requirement,"source_original","BuffCardForCollection","BuffCardCollectionID")
			if collection.get("effects") is Array:
				for effect: Variant in collection.effects:
					if effect is Dictionary: _effect(effect,collection_id)
	# Preserve exact selected array size, order, multiplicity, and empty sets.
	# Date rows here are the compiler's selected complete BuffCard source rows.
	_selected_rows(result,"source_server_limits","ServerLimit","ServerLimitSetID")
	_selected_rows(result,"source_card_date_rows","BuffCard")
	return result
