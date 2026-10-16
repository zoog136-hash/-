extends SceneTree
## Real catalog/placement contracts; no synthetic monsters or changed assertions.
const CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
var failures: Array[String] = []
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("PR99_CI_CONTRACT_FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var original: Array = db["몬스터"]
	var before: String = JSON.stringify(original)
	CATALOG.expand(original)
	check(JSON.stringify(original) == before, "expansion never mutates the source DB")
	# These are the actual locally authored special kinds in the current
	# production catalog. Cone is a supported real geometry, not a fallback.
	var expected_specials: Dictionary = {"흑장로":"beam", "데스나이트":"cone"}
	for name: String in expected_specials:
		var record: Dictionary = CATALOG.records_by_name.get(name, {})
		check(not record.is_empty() and bool(record.get("is_boss", false)), "dedicated boss identity " + name)
		var special: Dictionary = record.get("ai", {}).get("special", {})
		var explicit: Dictionary = CATALOG.catalog.overlays.get(name, {}).get("ai", {}).get("special", {})
		var expected_kind: String = str(expected_specials[name]) if not explicit.is_empty() else str(CATALOG.DEDICATED_BOSS_SPECIALS[name].kind)
		check(str(special.get("kind", "")) == expected_kind, "exact existing authored or dedicated attack kind " + name)
		if not explicit.is_empty():
			check(special == explicit, "dedicated fallback never replaces any explicit boss skill parameter " + name)
		check(float(special.get("cooldown", 0)) > 0 and float(special.get("windup", 0)) > 0, "bounded readable special " + name)
		check(str(special.get("evidence", "")) == "local_adaptation_not_verified_original_skill", "no invented original-skill claim " + name)
		for raw: Dictionary in original:
			if str(raw.name) == name:
				check(record.get("hp") == raw.get("hp") and record.get("drop") == raw.get("drop"), "base HP and drops retained " + name)
		# Exercise main's original fallback on a temporary in-memory fixture,
		# then restore the exact explicit catalog before all real map checks.
		var saved_overlay: Dictionary = CATALOG.catalog.overlays[name].duplicate(true)
		var without_special: Dictionary = saved_overlay.duplicate(true)
		(without_special.get("ai", {}) as Dictionary).erase("special")
		CATALOG.catalog.overlays[name] = without_special
		CATALOG.expand(original)
		var fallback_record: Dictionary = CATALOG.records_by_name[name]
		var expected_fallback: Dictionary = CATALOG.DEDICATED_BOSS_SPECIALS[name].duplicate(true)
		expected_fallback.element = str(fallback_record.get("attack_element", "physical"))
		check(fallback_record.ai.special == expected_fallback, "complete original dedicated fallback installs when explicit skill is absent " + name)
		CATALOG.catalog.overlays[name] = saved_overlay
		CATALOG.expand(original)
		check(CATALOG.records_by_name[name].ai.special == special, "explicit real boss skill restored after isolated fallback probe " + name)
	check(JSON.stringify(original) == before, "fallback probes retain source DB bytes")
	var profiles_before: String = JSON.stringify(CATALOG.spawn_profiles)
	var paths: Array[String] = ["res://data/maps/aden_field.json"]
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")):
		paths.append(str(entry.path))
	var bosses: int = 0
	for path: String in paths:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var source_before: String = JSON.stringify(source)
		var definition: Dictionary = CATALOG.apply_map(source)
		check(JSON.stringify(source) == source_before, "source map unchanged " + str(definition.map_id))
		check(JSON.stringify(CATALOG.apply_map(definition)) == JSON.stringify(definition), "schema completion is idempotent " + str(definition.map_id))
		for spawn: Dictionary in definition.monster_spawn:
			if str(spawn.get("mode", "normal")) != "boss": continue
			bosses += 1
			check(str(spawn.get("map_id", "")) == str(definition.map_id), "boss map linkage " + str(spawn.id))
			check(spawn.has("patrol_region"), "bounded boss patrol " + str(spawn.id))
			check(str(spawn.get("verification_status", {}).get("exact_spawn_area", "")) == "unverified", "explicit coordinate uncertainty " + str(spawn.id))
	check(paths.size() == 25 and bosses == 28, "all 25 maps and 28 distinct boss encounters")
	check(JSON.stringify(CATALOG.spawn_profiles) == profiles_before, "historical profiles unchanged")
	print("PR99_CI_CONTRACT_OK " if failures.is_empty() else "PR99_CI_CONTRACT_FAILED ", checks)
	quit(0 if failures.is_empty() else 1)
