extends SceneTree
## The source bank reads the shared column-packed original tables instead of
## keeping its own row dictionaries. Every lookup and every card/class
## selection must give exactly the same result as the dictionary path.
## Needs the owned original tables ZIP (TWILIGHT_PATCH523_CONTENT) and a bank
## manifest (--bank-manifest=, --bank-manifest-sha256=); without them it only
## checks that nothing is claimed.
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const BASE = preload("res://scripts/lineagem_base508.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 40: failures.append(label)

func arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _finish(extra: Dictionary) -> void:
	var result: Dictionary = {"checks":checks,"failures":failures}
	result.merge(extra)
	print("CURRENT523_SOURCE_BANK_SHARED_TABLES_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _context(tables: String, manifest: String, manifest_sha: String) -> Dictionary:
	return {"current523_source_bank":{"schema":1,"enabled":true,"source_snapshot":"patch523","tables_zip":tables,"manifest_path":manifest,"manifest_sha256":manifest_sha}}

func _force(shared: bool) -> void:
	SOURCE._table_path = ""
	SOURCE._table_sha = ""
	SOURCE._table_stamp = ""
	SOURCE._rows.clear()
	SOURCE._by_id.clear()
	SOURCE._shared = false
	SOURCE._shared_tables.clear()
	SOURCE.shared_tables_enabled = shared

func _snapshot(context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var loaded: Dictionary = SOURCE.source_tables(context, ["ItemClass","ItemBonus","InvokeOption","Class","Gender"])
	result["loaded"] = loaded.get("ok", false)
	result["shared"] = SOURCE._shared
	var rows: Dictionary = {}
	for table: String in SOURCE.TABLES + SOURCE.OPTIONAL_TABLES:
		var ids: Array = []
		var all: Array = SOURCE.table_rows(table) if table in ["ListSprAction","ConstantData","BuffCardAwakenEffect","StatusEffectAttr","Class","Gender","BuffCardDeck","Unit","BonusType","BonusApplicationType","PolymorphSet","SpriteRun","SpriteSeparatedWalk"] else []
		if not all.is_empty(): rows[table + ":all"] = all
		var count: int = DEF.row_count(table)
		var step: int = maxi(1, count / 400)
		for index: int in range(0, count, step):
			var value: Variant = DEF.row_at(table, index).get("ID")
			if value != null: ids.append(int(value))
		ids.append(-1)
		ids.append(999999999)
		var lookups: Array = []
		for id: int in ids: lookups.append(SOURCE.table_row(table, id))
		rows[table] = lookups
	for spec: Array in [["BuffBonus","BuffClassID"],["PolymorphEntityForSet","PolymorphSetID"],["SpriteRun","WalkSpriteID"],["SpriteSeparatedWalk","SpriteId"],["ItemBonus","ItemClassID"]]:
		var column: Variant = DEF.column(spec[0], spec[1])
		var values: Array = []
		var size: int = column.size() if column is Array or column is PackedFloat64Array else 0
		for index: int in range(0, size, maxi(1, size / 300)): values.append(int(column[index]))
		values.append(-5)
		var found: Array = []
		for value: int in values: found.append(SOURCE.table_where(spec[0], spec[1], value))
		rows[spec[0] + "." + spec[1]] = found
	result["rows"] = rows
	var selections: Dictionary = {}
	for class_id: int in range(1, 12):
		for gender_id: int in [1, 2]:
			for weapon: int in [0, 1, 4, 5, 11]:
				var value: Dictionary = context.duplicate(true)
				value.merge({"class_id":class_id,"gender_id":gender_id,"source_weapon_type":weapon})
				selections["class:%d:%d:%d" % [class_id, gender_id, weapon]] = SOURCE.select_class(value)
	var catalog: Dictionary = BASE.cards().get("catalog", {})
	for category: String in {"변신":"transform","마법인형":"doll","성물":"relic"}:
		var consumer: String = {"변신":"transform","마법인형":"doll","성물":"relic"}[category]
		var records: Array = catalog.get(category, [])
		for index: int in range(0, records.size(), maxi(1, records.size() / 120)):
			var key: String = consumer + ":" + str(records[index].get("sourceId", ""))
			var value: Dictionary = context.duplicate(true)
			value.merge({"class_id":1,"gender_id":1,"source_weapon_type":0})
			selections[key] = SOURCE.select_card(key, value)
	result["selections"] = selections
	return result

func _initialize() -> void:
	var tables: String = OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	var manifest: String = arg("--bank-manifest=")
	var manifest_sha: String = arg("--bank-manifest-sha256=")
	if tables.is_empty() or manifest.is_empty() or not FileAccess.file_exists(tables):
		# No owned input: the shared path must never claim tables it cannot read.
		_force(true)
		var missing: Dictionary = SOURCE.source_tables(_context("user://absent.zip", "user://absent.json", "0".repeat(64)))
		check(not missing.get("ok", true) and not SOURCE._shared, "absent tables are not reported as loaded")
		_finish({"real_input_checked":false})
		return
	var context: Dictionary = _context(tables, manifest, manifest_sha)
	_force(false)
	var dictionaries: Dictionary = _snapshot(context)
	var dictionary_memory: int = OS.get_static_memory_usage()
	_force(true)
	var shared: Dictionary = _snapshot(context)
	check(dictionaries.loaded and shared.loaded, "both paths load the pinned tables")
	check(not dictionaries.shared and shared.shared, "each path used the intended storage")
	for key: String in dictionaries.rows:
		check(dictionaries.rows[key] == shared.rows.get(key), "same rows: " + key)
	var selected: int = 0
	for key: String in dictionaries.selections:
		check(dictionaries.selections[key] == shared.selections.get(key), "same selection: " + key)
		if dictionaries.selections[key].get("ok", false): selected += 1
	check(selected > 20, "real selections were compared, not only failures")
	_finish({"real_input_checked":true,"selections":dictionaries.selections.size(),"selected":selected,"row_groups":dictionaries.rows.size(),"static_mb_after_dictionaries":dictionary_memory / 1048576})
