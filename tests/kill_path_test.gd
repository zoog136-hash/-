extends SceneTree
## Work taken out of every kill/attack with the same results:
## the drop bindings' catalog sourceId indexes (built once per catalog, rebuilt
## on replacement/resize/in-place change) and the skill ownership order
## (unlearned records answer before the other AND checks).
##   godot --headless --path <repo> --script res://tests/kill_path_test.gd
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const SKILL_CATALOG = preload("res://scripts/skills/skill_catalog.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("KILL_PATH_FAIL: " + label)

func _scan(unique: Dictionary, host: bool) -> Dictionary:
	# The per-kill loops as they were.
	var by_id: Dictionary = {}
	for item: Variant in unique.values():
		if not item is Dictionary: continue
		var source_id: String = str(item.get("sourceId",""))
		if host:
			if item.get("source") != "inven" or item.get("source_m_native_item",false) or item.get("source_legacy_catalog_alias",false): continue
			if not source_id.is_valid_int() or int(source_id) <= 0 or source_id != str(int(source_id)): continue
		if not by_id.has(source_id): by_id[source_id] = []
		by_id[source_id].append(item)
	return by_id

func _initialize() -> void:
	var catalog: Dictionary = {
		"검": {"name":"검","source":"inven","sourceId":"11"},
		"검2": {"name":"검2","source":"inven","sourceId":"11"},
		"방패": {"name":"방패","source":"inven","sourceId":"012"},
		"원본": {"name":"원본","source":"lineagem_patch523","sourceId":"m523:item:7","source_m_native_item":true},
		"별칭": {"name":"별칭","source":"inven","sourceId":"5","source_legacy_catalog_alias":true},
		"음수": {"name":"음수","source":"inven","sourceId":"-3"},
		"x": 3}
	check(DROPS._catalog_index(catalog, "host") == _scan(catalog, true), "host index equals the per-kill scan")
	check(DROPS._catalog_index(catalog, "source") == _scan(catalog, false), "sourceId index equals the per-kill scan")
	var first: Dictionary = DROPS._catalog_index(catalog, "host")
	check(is_same(first, DROPS._catalog_index(catalog, "host")), "the same catalog reuses its index")
	catalog["창"] = {"name":"창","source":"inven","sourceId":"11"}
	check(DROPS._catalog_index(catalog, "host") == _scan(catalog, true) and DROPS._catalog_index(catalog, "host")["11"].size() == 3, "a grown catalog is reindexed")
	var replaced: Dictionary = {"name":"검","source":"inven","sourceId":"11","grade":"new"}
	catalog["검"] = replaced
	var listed: Array = DROPS._catalog_index(catalog, "host")["11"]
	check(not DROPS._index_current(catalog, listed), "an in-place replacement is noticed")
	check(DROPS._catalog_index(catalog, "host")["11"].has(replaced) and DROPS._catalog_index(catalog, "host") == _scan(catalog, true), "and the index is rebuilt with the new entry")
	var other: Dictionary = catalog.duplicate()
	check(DROPS._catalog_index(other, "source") == _scan(other, false), "another catalog dictionary gets its own index")
	var catalog_source: String = FileAccess.get_file_as_string("res://scripts/skills/skill_catalog.gd")
	var owned_at: int = catalog_source.find("func owned(record: Dictionary) -> bool:")
	var learned_at: int = catalog_source.find("if int(learned.get(str(record.get(\"id\", \"\")), 0)) <= 0: return false", owned_at)
	var status_at: int = catalog_source.find("if not source_learning_status(record).is_empty():return false", owned_at)
	check(owned_at >= 0 and learned_at > owned_at and status_at > learned_at, "owned() answers unlearned records before the other checks")
	var skills := SKILL_CATALOG.new()
	var attack: Dictionary = {"id":"test_attack", "mode":"attack"}
	var mark: Dictionary = {"id":"test_mark", "mode":"mark"}
	var stack: Dictionary = {"id":"test_stack", "mode":"stack_attack"}
	var equipment: Dictionary = {"id":"test_equipment", "mode":"attack", "equipment_spell523":1}
	skills.records = [attack, mark, stack, equipment]
	skills.learned = {"test_stack":1, "test_attack":0}
	var candidates: Array[Dictionary] = skills.combat_proc_records()
	check(candidates == [mark, stack] and is_same(candidates, skills.combat_proc_records()),
		"the cached proc records keep catalog order and include as-yet unlearned procs")
	skills.records.append({"id":"test_skill", "mode":"attack"})
	check(skills.combat_proc_records() == [mark, stack] and not is_same(candidates, skills.combat_proc_records()),
		"the proc filter rebuilds when the catalog grows")
	check(skills.possible_owned_records() == [stack, equipment],
		"the ownership prefilter retains equipment grants for live checks")
	skills.learned["test_attack"] = 1
	skills.learned.erase("test_stack")
	check(skills.possible_owned_records() == [attack, equipment],
		"learning changes within the same catalog revision update candidates in order")
	attack.mode = "proc"
	skills.revision += 1
	check(skills.combat_proc_records() == [attack, mark, stack], "a new catalog revision refreshes proc membership")
	print("KILL_PATH_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
