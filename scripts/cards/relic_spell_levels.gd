extends RefCounted
## Passive source declarations, separate from both kinds of card awakening.
## The source does not define a purchasable transcendence operation.
const BASE = preload("res://scripts/lineagem_base508.gd")
const CARDS = preload("res://scripts/card_draw_fusion.gd")
const CONDITIONS = preload("res://scripts/cards/source_collection_conditions.gd")
const EFFECTS = preload("res://scripts/cards/relic_spell_effects.gd")
const ROWS = preload("res://scripts/resources/zip_table_rows.gd")
const SOURCE_SHA256: String = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const SOURCE_BYTES: int = 25031173
const INSTALLED: String = "user://source_rules/relic-patch523.zip"
static var _rules: Dictionary = {}
static var _default_checked: bool = false
static var _catalog: Dictionary = {}
static var _conditions = CONDITIONS.new()
static var revision: int = 0
static var last_error: String = "source_missing"

const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BAKE_NAME := "relic_spell_levels"
const BAKE_CODE: Array[String] = ["res://scripts/cards/relic_spell_levels.gd", "res://scripts/cards/relic_spell_effects.gd", "res://scripts/resources/zip_table_rows.gd"]
static var bake_enabled: bool = true

static func _table(archive: ZIPReader, name_value: String) -> Array:
	var path: String = "content/" + name_value + ".json"
	if not archive.file_exists(path): return []
	var value: Variant = JSON.parse_string(archive.read_file(path).get_string_from_utf8().trim_prefix("\ufeff"))
	return value.get("rows", []) if value is Dictionary and value.get("rows") is Array else []

## _indexed() of a windowed scan: {} when the whole table is empty or any row
## lacks or repeats its ID, else the kept rows by ID.
static func _indexed_scan(scanned: Dictionary) -> Dictionary:
	if not scanned.get("ok", false) or int(scanned.count) == 0 or scanned.duplicate or scanned.missing: return {}
	var out: Dictionary = {}
	for raw: Dictionary in scanned.rows: out[int(raw.ID)] = raw
	return out

static func _indexed(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for raw: Variant in rows:
		if not raw is Dictionary or not raw.has("ID") or out.has(int(raw.ID)): return {}
		out[int(raw.ID)] = raw
	return out

static func _checked(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok":false, "error":"source_missing"}
	var input: FileAccess = FileAccess.open(path, FileAccess.READ)
	if input == null: return {"ok":false, "error":"source_unreadable"}
	var bytes: int = input.get_length()
	input.close()
	if bytes != SOURCE_BYTES or FileAccess.get_sha256(path) != SOURCE_SHA256:
		return {"ok":false, "error":"source_hash_mismatch"}
	# The result is a pure function of the pinned archive and these scripts.
	# Building it parses whole original tables (about 800 MB of temporary
	# memory), so this device keeps the result of the same inputs.
	var key: String = BAKE.key(["relic_spell_levels.v1", SOURCE_SHA256, BAKE.code_key(BAKE_CODE)]) if bake_enabled else ""
	var baked: Variant = BAKE.read(BAKE_NAME, key) if not key.is_empty() else null
	if baked is Dictionary and baked.get("ok") == true and baked.get("rows") is Dictionary and baked.get("source_sha256") == SOURCE_SHA256: return baked
	var built: Dictionary = _build(path)
	if built.get("ok", false) and not key.is_empty(): BAKE.write(BAKE_NAME, key, built)
	return built

static func _build(path: String) -> Dictionary:
	var archive := ZIPReader.new()
	if archive.open(path) != OK: return {"ok":false, "error":"source_zip_invalid"}
	var cards: Dictionary = _indexed(_table(archive, "BuffCard"))
	var types: Dictionary = _indexed(_table(archive, "BonusType"))
	var units: Dictionary = _indexed(_table(archive, "Unit"))
	var applications: Dictionary = _indexed(_table(archive, "BonusApplicationType"))
	var grades: Dictionary = _indexed(_table(archive, "Grade"))
	var mappings: Array = _table(archive, "BuffCardTranscendence")
	var links: Array = _table(archive, "BuffCardTranscendenceBonus")
	# Bonus (33 MB) and DescData_Korean (53 MB) are read window by window and
	# only the rows this rule and its spell effects look up are kept: Bonus
	# rows referenced by these links, SpellBonus and BuffBonus; descriptions of
	# these grades. Whole-table checks (empty, duplicate or missing IDs) are
	# kept as before.
	var bonus_ids: Dictionary = {}
	for link: Variant in links:
		if link is Dictionary and link.get("BonusID") != null: bonus_ids[int(link.BonusID)] = true
	for owner: String in ["SpellBonus", "BuffBonus"]:
		for id: int in ROWS.scan(archive, owner, "ID", {}, "BonusID").values: bonus_ids[id] = true
	var bonuses: Dictionary = _indexed_scan(ROWS.scan(archive, "Bonus", "ID", bonus_ids))
	var desc_ids: Dictionary = {}
	for grade: Variant in grades.values():
		if grade is Dictionary and grade.get("DescID") != null: desc_ids[int(grade.DescID)] = true
	var descriptions: Dictionary = _indexed_scan(ROWS.scan(archive, "DescData_Korean", "ID", desc_ids))
	var server_rows: Array = _table(archive, "ServerLimit")
	var spell_profiles: Dictionary = EFFECTS.build(archive, cards, bonuses, types, units)
	archive.close()
	if spell_profiles.size() != 119: return {"ok":false, "error":"source_spell_join_invalid"}
	if cards.is_empty() or bonuses.is_empty() or types.is_empty() or units.is_empty() or applications.is_empty() or grades.is_empty() or descriptions.is_empty() or server_rows.is_empty() or mappings.size() != 59 or links.size() != 13:
		return {"ok":false, "error":"source_join_invalid"}
	var groups: Dictionary = {}
	var link_ids: Dictionary = {}
	for link: Dictionary in links:
		if link_ids.has(int(link.ID)) or not bonuses.has(int(link.BonusID)): return {"ok":false, "error":"source_join_invalid"}
		link_ids[int(link.ID)] = true
		var bonus: Dictionary = bonuses[int(link.BonusID)]
		var type_row: Dictionary = types.get(int(bonus.BonusTypeID), {})
		var unit: Dictionary = units.get(int(type_row.get("UnitID", -1)), {})
		var application: Dictionary = applications.get(int(bonus.BonusApplicationTypeID), {})
		var grade: Dictionary = grades.get(int(bonus.BonusApplicationTargetID), {})
		if type_row.get("Name") != "SpellLevelUp" or unit.get("Name") != "Value" or application.get("Name") != "Grade" or grade.is_empty() or int(bonus.Value) != 1:
			return {"ok":false, "error":"source_semantics_changed"}
		var group_id: int = int(link.TranscendenceGroupID)
		if not groups.has(group_id): groups[group_id] = []
		groups[group_id].append({"link":link, "bonus":bonus, "type":type_row, "unit":unit, "application":application, "grade":grade, "label":str(descriptions.get(int(grade.DescID), {}).get("Description", ""))})
	var rows: Dictionary = {}
	var mapping_ids: Dictionary = {}
	for mapping: Dictionary in mappings:
		var card_id: int = int(mapping.BuffCardID)
		if mapping_ids.has(int(mapping.ID)) or rows.has(card_id) or not cards.has(card_id) or not groups.has(int(mapping.TranscendenceGroupID)) or int(cards[card_id].BuffCardDeckID) != 98:
			return {"ok":false, "error":"source_join_invalid"}
		mapping_ids[int(mapping.ID)] = true
		rows[card_id] = {"mapping":mapping, "card":cards[card_id], "effects":groups[int(mapping.TranscendenceGroupID)]}
	return {"ok":true, "rows":rows, "groups":groups, "server_rows":server_rows, "source_sha256":SOURCE_SHA256, "spell_profiles":spell_profiles}

static func load_source(path: String) -> Dictionary:
	var candidate: Dictionary = _checked(path)
	_default_checked = true
	if not candidate.ok:
		last_error = str(candidate.error)
		return candidate
	_rules = candidate
	_conditions.configure(candidate.server_rows)
	last_error = ""
	revision += 1
	return {"ok":true, "cards":_rules.rows.size(), "groups":_rules.groups.size(), "source_sha256":SOURCE_SHA256}

static func ensure_loaded() -> bool:
	if not _default_checked:
		_default_checked = true
		load_source(INSTALLED)
	return not _rules.is_empty()

static func install_source(path: String) -> Dictionary:
	# Validate before writing; a rejected replacement keeps the active rules.
	var candidate: Dictionary = _checked(path)
	if not candidate.ok: return candidate
	var destination: String = ProjectSettings.globalize_path(INSTALLED)
	if path.simplify_path() != destination.simplify_path():
		var folder: String = destination.get_base_dir()
		if DirAccess.make_dir_recursive_absolute(folder) != OK: return {"ok":false, "error":"install_directory_failed"}
		var temporary: String = destination + ".pending-" + str(Time.get_ticks_usec())
		var error: Error = DirAccess.copy_absolute(path, temporary)
		if error == OK and FileAccess.get_sha256(temporary) != SOURCE_SHA256: error = ERR_FILE_CORRUPT
		if error == OK: error = DirAccess.rename_absolute(temporary, destination)
		if error != OK:
			if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
			return {"ok":false, "error":"install_write_failed"}
	# Use the validated candidate only after durable installation succeeds.
	_rules = candidate
	_conditions.configure(candidate.server_rows)
	_default_checked = true
	last_error = ""
	revision += 1
	return {"ok":true, "cards":_rules.rows.size(), "groups":_rules.groups.size()}

static func _canonical(record: Dictionary) -> Dictionary:
	if not BASE.native(record) or int(record.get("source_deck_id", -1)) != 98: return {}
	if _catalog.is_empty():
		for row: Dictionary in BASE.cards().get("catalog", {}).get("성물", []): _catalog[str(row.sourceId)] = row
	var key: String = str(record.get("sourceId", ""))
	var current: Dictionary = _catalog.get(key, {})
	if current.is_empty() or record.get("source") != current.get("source") or int(current.get("source_deck_id", -1)) != 98 or int(record.get("source_card_id", -1)) != int(current.source_card_id): return {}
	return current

static func view(record: Dictionary, acquired: bool = false, equipped: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if not ensure_loaded(): return {"ok":false, "code":last_error, "active":false, "effects":[], "bonus_by_grade":{}}
	var canonical: Dictionary = _canonical(record)
	if canonical.is_empty(): return {"ok":false, "code":"catalog_identity_missing", "active":false, "effects":[], "bonus_by_grade":{}}
	var row: Dictionary = _rules.rows.get(int(canonical.source_card_id), {})
	if row.is_empty(): return {"ok":true, "code":"no_source_mapping", "active":false, "effects":[], "bonus_by_grade":{}}
	for field: String in ["ID", "BuffCardDeckID", "BuffClassID", "GradeID", "ServerLimitSetID", "StartDateTimeID", "EndDateTimeID"]:
		if canonical.source_original_card.get(field) != row.card.get(field):
			return {"ok":false, "code":"catalog_source_changed", "active":false, "effects":[], "bonus_by_grade":{}}
	var eligibility: Dictionary = _conditions.evaluate(int(row.card.ServerLimitSetID), context)
	var code: String = "ready"
	if eligibility.status not in ["unrestricted", "eligible"]: code = "server_" + str(eligibility.status)
	# Preserve the event's dates; the collection-only time override is not
	# silently reused as authority for this separate passive mechanic.
	if int(row.card.StartDateTimeID) != 0 or int(row.card.EndDateTimeID) != 0: code = "time_condition_unresolved"
	if code == "ready" and not acquired: code = "not_owned"
	var applied: Dictionary = _canonical(equipped)
	if code == "ready" and (applied.is_empty() or str(applied.sourceId) != str(canonical.sourceId)): code = "not_equipped"
	var amounts: Dictionary = {}
	for effect: Dictionary in row.effects:
		var target: int = int(effect.bonus.BonusApplicationTargetID)
		amounts[target] = int(amounts.get(target, 0)) + int(effect.bonus.Value)
	return {"ok":true, "code":code, "active":code == "ready", "effects":row.effects.duplicate(true), "bonus_by_grade":amounts, "mapping":row.mapping.duplicate(true), "card":row.card.duplicate(true), "eligibility":eligibility, "source_snapshot":"patch523", "combat_values_connected":true}

static func for_world(world: Node, record: Dictionary) -> Dictionary:
	var identity: String = CARDS.card_id(record)
	var acquired: bool = world.card_draw_fusion.owned.get("성물", {}).get(identity, false) == true
	return view(record, acquired, world.equipped_catalog.get("성물", {}), world.card_collections.source_server_context())

static func level_for(world: Node, source_grade_id: int, base_level: int) -> Dictionary:
	var snapshot: Dictionary = for_world(world, world.equipped_catalog.get("성물", {}))
	var bonus: int = int(snapshot.bonus_by_grade.get(source_grade_id, 0)) if snapshot.active and base_level >= 0 else 0
	return {"base_level":base_level, "bonus":bonus, "effective_level":base_level + bonus, "source_grade_id":source_grade_id, "code":snapshot.code, "combat_values_connected":ensure_loaded()}

static func state_key(world: Node) -> int:
	ensure_loaded()
	return hash([revision, world.equipped_catalog.get("성물", {}), world.card_draw_fusion.owned.get("성물", {}), world.card_collections.source_server_context()])

static func project(world: Node, record: Dictionary, identity: Dictionary, enabled: bool) -> Dictionary:
	if not ensure_loaded(): return record
	var profile: Dictionary = _rules.spell_profiles.get(str(identity.get("id", "")), {})
	if profile.is_empty() or not EFFECTS.identity_matches(identity, profile): return record
	if bool(record.get("runtime_blocked", false)) or not str(record.get("source523_block_reason", "")).is_empty(): enabled = false
	# learned=1 is ownership in this host, not native spell level progression.
	return EFFECTS.project(record, profile, level_for(world, int(profile.binding.grade_id), 0), int(world.level), enabled)
