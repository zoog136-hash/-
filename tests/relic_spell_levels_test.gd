extends SceneTree
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
const BASE = preload("res://scripts/lineagem_base508.gd")
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("RELIC_LEVEL_FAIL ", message)
func _initialize() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-zip="): path = arg.trim_prefix("--source-zip=")
	if path.is_empty(): printerr("Explicit authorized patch523 source ZIP required"); quit(2); return
	check(not RULES.ensure_loaded(), "absent optional rules are inert")
	var original_hash: String = FileAccess.get_sha256(path)
	check(RULES.load_source(path).get("cards") == 59, "verified current ZIP loads all59 declarations")
	var archive := ZIPReader.new()
	check(archive.open(path) == OK, "independent source reader")
	var raw: Dictionary = JSON.parse_string(archive.read_file("content/BuffCardTranscendence.json").get_string_from_utf8().trim_prefix("\ufeff"))
	var mappings: Dictionary = {}
	for row: Dictionary in raw.rows: mappings[int(row.BuffCardID)] = row
	archive.close()
	var matched: int = 0
	var hero: Dictionary = {}
	var legendary: Dictionary = {}
	var myth: Dictionary = {}
	var unique: Dictionary = {}
	var limited: Dictionary = {}
	var event: Dictionary = {}
	for record: Dictionary in BASE.cards().catalog["성물"]:
		var snapshot: Dictionary = RULES.view(record, true, record)
		if not mappings.has(int(record.source_card_id)):
			check(snapshot.ok and snapshot.code == "no_source_mapping" and snapshot.bonus_by_grade.is_empty(), "unmapped relic grants no boost " + str(record.sourceId))
			continue
		matched += 1
		check(snapshot.ok and snapshot.mapping == mappings[int(record.source_card_id)], "exact independent card/group join " + str(record.sourceId))
		check(snapshot.effects.all(func(effect: Dictionary) -> bool: return effect.type.Name == "SpellLevelUp" and effect.unit.Name == "Value" and effect.application.Name == "Grade" and int(effect.bonus.Value) == 1), "source type/unit/target preserved " + str(record.sourceId))
		check(snapshot.active == (int(snapshot.card.ServerLimitSetID) == 0 and int(snapshot.card.StartDateTimeID) == 0 and int(snapshot.card.EndDateTimeID) == 0), "unknown conditions never activate " + str(record.sourceId))
		if int(record.source_card_id) == 21428: hero = record
		if int(record.source_card_id) == 21488: legendary = record
		if int(record.source_card_id) == 21518: myth = record
		if int(record.source_card_id) == 23531: unique = record
		if int(snapshot.card.ServerLimitSetID) == 772: limited = record
		if int(snapshot.card.StartDateTimeID) != 0: event = record
	check(matched == 58 and mappings.has(25162), "58 existing identities, new World Tree card retained without a grant")
	check(RULES.view(hero, true, hero).bonus_by_grade == {1:1}, "hero boosts only common source grade")
	check(RULES.view(legendary, true, legendary).bonus_by_grade == {1:1, 4:1}, "legendary exact target grades")
	check(RULES.view(myth, true, myth).bonus_by_grade == {1:1, 4:1, 5:1}, "myth exact target grades")
	check(RULES.view(unique, true, unique).bonus_by_grade == {1:1, 4:1, 5:1, 32:1}, "unique exact target grades")
	check(not RULES.view(hero, false, hero).active and RULES.view(hero, false, hero).code == "not_owned", "equipment alone cannot grant permanent ownership")
	check(not RULES.view(hero, true, legendary).active, "previewing another card does not activate its group")
	check(RULES.view(limited, true, limited).code == "server_context_missing", "restricted source card requires explicit context")
	var server: Dictionary = {}
	for row: Dictionary in RULES._rules.server_rows:
		if int(row.ServerLimitSetID) == 772: server = row; break
	var context: Dictionary = {"source_snapshot":"base508", "ServiceRegionCode":server.ServiceRegionCode, "WorldNo":int(server.WorldNo)}
	check(RULES.view(limited, true, limited, context).active, "exact original server row enables its existing card")
	context.WorldNo = -1
	check(not RULES.view(limited, true, limited, context).active, "malformed context is inert")
	check(RULES.view(event, true, event).code == "time_condition_unresolved", "event dates not inherited from collection-only override")
	var tampered: Dictionary = hero.duplicate(true)
	tampered.source_deck_id = 2
	check(not RULES.view(tampered, true, tampered).ok, "same integer in another deck is rejected")
	tampered = hero.duplicate(true); tampered.sourceId = "m508:98:021428"
	check(not RULES.view(tampered, true, tampered).ok, "noncanonical identity rejected")
	var preview: Dictionary = RULES.view(hero, true, hero)
	preview.effects[0].bonus.Value = 999
	preview.mapping.TranscendenceGroupID = -1
	check(RULES.view(hero, true, hero).bonus_by_grade == {1:1}, "mutable previews cannot corrupt active rules")
	var before: int = hash(RULES.view(hero, true, hero))
	var bad_path: String = "user://bad-relic-source.zip"
	var file: FileAccess = FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("invalid test ZIP"); file.close()
	check(not RULES.load_source(bad_path).ok and hash(RULES.view(hero, true, hero)) == before, "failed load preserves active source")
	check(not RULES.install_source(bad_path).ok and hash(RULES.view(hero, true, hero)) == before, "failed installation preserves active source")
	var sentinel: String = "user://twilight_v20_save.json"
	file = FileAccess.open(sentinel, FileAccess.WRITE); file.store_string("preserve-exact-save-bytes"); file.close()
	check(RULES.install_source(path).ok, "validated archive installs outside Git")
	check(FileAccess.get_sha256(RULES.INSTALLED) == original_hash and FileAccess.get_sha256(path) == original_hash, "installed source and original source are byte-identical")
	check(FileAccess.get_file_as_string(sentinel) == "preserve-exact-save-bytes", "rule installation never rewrites player save")
	check(not RULES.view(hero, true, hero).has("cost") and not RULES.view(hero, true, hero).has("success_chance"), "no invented paid or free upgrade operation")
	print("RELIC_SPELL_LEVEL_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "existing_mappings":matched}))
	quit(0 if failures.is_empty() else 1)
