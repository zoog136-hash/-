extends SceneTree
## Opt-in owned-input verification. Not a synthetic CI substitute. Invoke with
## TWILIGHT_PATCH523_CONTENT set to the exact original 523 definition archive.
const CATALOG = preload("res://scripts/characters/class_catalog.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CHARACTER_SOURCE_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty(),"explicit owned original archive required")
	var catalog = CATALOG.new()
	check(catalog.configure(),"verified original catalog configure: " + catalog.problem)
	check(catalog.source_identity.get("source_sha256") == DEFINITIONS.SOURCE_SHA,"exact archive SHA identity")
	check(catalog.source_identity.get("source_bytes") == 25031173,"exact archive byte count")
	check(catalog.classes.size() == 13,"13 original CanCreateClient classes")
	var source_classes: Array[Dictionary] = DEFINITIONS.rows("Class")
	var source_assets: Array[Dictionary] = DEFINITIONS.rows("ClassAssets")
	var eligible: Dictionary = {}
	for row: Dictionary in source_classes:
		if row.get("CanCreateClient") == true: eligible[int(row.ID)] = row
	check(eligible.size() == catalog.classes.size(),"catalog exactly matches eligible source classes")
	var combinations: int = 0
	var witnessed: Dictionary = {}
	for entry: Dictionary in catalog.classes:
		check(eligible.has(int(entry.id)),"class eligibility #" + str(entry.id))
		check(entry.source == eligible[int(entry.id)],"full source class retained #" + str(entry.id))
		for gender: int in entry.genders:
			combinations += 1
			var profile: Dictionary = catalog.profile(int(entry.id),gender)
			var exact: Array[Dictionary] = []
			for asset: Dictionary in source_assets:
				if asset.ClassID == entry.id and asset.GenderID == gender: exact.append(asset)
			check(exact.size() == 1 and profile.class_assets == exact[0],"unique original class/gender assets %s/%s" % [entry.id,gender])
			witnessed["%d:%d" % [entry.id,gender]] = true
			for field: String in CATALOG.STAT_FIELDS:
				check(profile.stats[field] == eligible[int(entry.id)][CATALOG.STAT_FIELDS[field]],"exact initial stat %s class %d" % [field,entry.id])
	check(combinations == 25,"25 declared playable class/gender combinations")
	for asset: Dictionary in source_assets:
		if eligible.has(int(asset.ClassID)):
			check(witnessed.has("%d:%d" % [int(asset.ClassID),int(asset.GenderID)]),"every eligible ClassAssets pair represented")
	check(catalog.account_slots == DEFINITIONS.rows("AccountSlot"),"original AccountSlot retained without equating Value to class count")
	for id: int in [1,2,98]: check(catalog.deck_scope.get(id) == false,"account-owned card deck " + str(id))
	check(catalog.deck_scope.get(41) == true,"character-owned Spell deck")
	print("CHARACTER_CATALOG523_SOURCE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"classes":catalog.classes.size(),"class_gender_combinations":combinations,"source":catalog.source_identity,"scope":"VERIFIED_OWNED_523_TABLES_NOT_ART_RENDERING"}))
	quit(0 if failures.is_empty() else 1)
