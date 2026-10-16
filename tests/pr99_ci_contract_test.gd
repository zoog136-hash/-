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
