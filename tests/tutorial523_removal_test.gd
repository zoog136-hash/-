extends SceneTree
## 사용자 결정 2026-11-16 "튜토리얼 관련은 전부 삭제" (docs/TUTORIAL523_REMOVAL.md,
## scripts/content523/tutorial523.gd). Synthetic checks always run; with the
## original definition ZIP the sets are re-derived from the tables, and Main
## proves: tutorial Lands never open, tutorial quests never start and each
## class's first post-tutorial quest becomes its start, tutorial items are
## refused, a save in a tutorial Land moves to the start village (Giran town,
## 사용자 결정 2026-11-17) with tutorial items
## removed (amounts recorded), and the class skill book grant happens once.
const TUTORIAL = preload("res://scripts/content523/tutorial523.gd")
const DUMMY = preload("res://scripts/quests/source_dummy523.gd")
const QUESTS = preload("res://scripts/quests/source_quest523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const PACK = preload("res://scripts/maps/current523_source_pack.gd")
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const START_VILLAGE = preload("res://scripts/maps/current523_start_village.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("TUTORIAL523_REMOVAL_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func quest_row(id: int, prerequisites: Array) -> Dictionary:
	return {"id":"m523:quest:"+str(id),"source_id":id,"definition":{"TypeID":1},"prerequisites":prerequisites,"goals":[],"source_rewards":[],"enhancements":[],
		"blockers":[],"excluded_reasons":[],"starts_at":0,"ends_at":4102444800}

func synthetic() -> void:
	check(TUTORIAL.LAND_IDS.size() == 46 and TUTORIAL.QUEST_IDS.size() == 108 and TUTORIAL.ITEM_IDS.size() == 50, "46 Lands · 108 quests · 50 items")
	check(TUTORIAL.land(44502) and TUTORIAL.land(44502.0) and not TUTORIAL.land(4) and TUTORIAL.land_declaration({"ID":999999,"Name":"[튜토리얼] 새 땅"}) and not TUTORIAL.land_declaration({"ID":4,"Name":"아덴"}), "Land identification")
	check(TUTORIAL.quest(74792) and not TUTORIAL.quest(74802) and TUTORIAL.item(138531) and TUTORIAL.item(6171) and not TUTORIAL.item(26), "quest / item identification")
	# Quest gates.
	var quests = QUESTS.new()
	check(quests.gate(quest_row(74792,[]),{"class_id":52,"level":1},{},1000) == TUTORIAL.DECISION, "a tutorial quest never starts")
	var after: Dictionary = quest_row(74802,[{"type_name":"Quest","Value":74792}])
	check(quests.gate(after,{"class_id":52,"level":1},{},1000) == "", "the first quest after the 암흑기사 tutorial is its start quest")
	check(quests.gate(after,{"class_id":1,"level":1},{},1000) == "직업 조건 미충족", "it stays the tutorial chain's class only")
	check(quests.gate(quest_row(5,[{"type_name":"Quest","Value":4}]),{"class_id":1,"level":1},{},1000).contains("선행 퀘스트 4"), "other prerequisites unchanged")
	# Items.
	check(not DUMMY.item_id_evidence(138531).is_empty() and DUMMY.item_id_evidence(26).is_empty(), "tutorial items are cut from every grant/use path")
	check(DUMMY.reason({"source_snapshot":"patch523","source":"lineagem_patch523","source_item_class_id":6171}).contains("튜토리얼"), "the refusal names the decision")
	# Save migration.
	var save: Dictionary = {"character_source_cursor":{"native_land_id":44502,"source_position":[10,20]},
		"inventory":{"[퀘스트] 퀘스트 이동 주문서 · 원본#138531":3,"빨간 물약":5,"[튜토리얼][화폐] 뽑기용 화폐 · 원본#6171":2},
		"item_instances":{"7":{"name":"x","record":{"source_item_class_id":155701}},"8":{"name":"검 · 원본#4681","record":{"source_item_class_id":4681}}}}
	check(TUTORIAL.needed(save), "a save in a tutorial Land needs the migration")
	var moved: Dictionary = TUTORIAL.migrate_save(save)
	check(moved.character_source_cursor == {"native_land_id":4,"source_position":[33441.5,32813.5]} and moved.character_source_cursor == START_VILLAGE.cursor(), "moved to Giran town (Locations473 리스타트 좌표 기란 마을)")
	check(moved.tutorial523.relocated.to_source_position == [33441.5,32813.5] and moved.tutorial523.relocated.to_village == "기란 마을", "the Giran destination is recorded")
	check(moved.inventory == {"빨간 물약":5} and moved.item_instances.keys() == ["8"], "tutorial items removed, others kept")
	check(moved.tutorial523.removed_items == {"138531":3,"6171":2} and moved.tutorial523.relocated.from_native_land_id == 44502, "amounts and origin recorded")
	check(not TUTORIAL.needed(moved) and save.inventory.size() == 3, "migration is one-shot and does not touch the input")
	check(not TUTORIAL.needed({"character_source_cursor":{"native_land_id":4,"source_position":[]},"inventory":{"빨간 물약":1}}), "an ordinary save is untouched")
	check(TUTORIAL.start_grants(52,{}).size() == 3 and TUTORIAL.start_grants(81,{}).size() == 2 and TUTORIAL.start_grants(1,{}).is_empty() and TUTORIAL.start_grants(52,{"start_grant":{}}).is_empty(), "class book grant once")

func derived() -> void:
	# Re-derive every set from the original tables.
	var land_ids: Array = SOURCE.column("Land","ID"); var land_names: Array = SOURCE.column("Land","Name")
	var lands: Dictionary = {}
	for i: int in land_ids.size():
		if str(land_names[i]).contains("[튜토리얼]"): lands[int(land_ids[i])] = true
	var expected_lands: Array = lands.keys(); expected_lands.sort()
	check(expected_lands == Array(TUTORIAL.LAND_IDS), "Land set re-derived (%d)" % expected_lands.size())
	var territories: Dictionary = {}
	var t_ids: Array = SOURCE.column("Territories","ID"); var t_lands: Array = SOURCE.column("Territories","LandID")
	for i: int in t_ids.size():
		if lands.has(int(t_lands[i])): territories[int(t_ids[i])] = true
	var quests: Dictionary = {}
	var q_ids: Array = SOURCE.column("QuestView","ID"); var q_teleports: Array = SOURCE.column("QuestView","TeleportTerritoriesID")
	for i: int in q_ids.size():
		if territories.has(int(q_teleports[i])): quests[int(q_ids[i])] = true
	var expected_quests: Array = quests.keys(); expected_quests.sort()
	check(expected_quests == Array(TUTORIAL.QUEST_IDS), "quest set re-derived (%d)" % expected_quests.size())
	evidence["territories"] = territories.size()
	for id: int in TUTORIAL.ITEM_IDS:
		var name: String = str(SOURCE.row("ItemClass",id).get("Name",""))
		check(name.contains("[튜토리얼]") or name.contains("이동 주문서"), "tutorial item %d: %s" % [id,name])

func actual_main() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for frame: int in 10: await process_frame
	# Lands: the pack marks them, a field never opens.
	var options: Dictionary = OPTIONS.read()
	var catalog = PACK.new()
	if check(catalog.load_catalog(str(options.raw_root),str(options.source_manifest_sha256)), "map catalog loads: "+str(catalog.problem)):
		var cut: int = 0
		for row: Dictionary in catalog.catalog_lands():
			if (row.excluded_content as Array).has("tutorial"): cut += 1
		evidence["lands_cut"] = cut
		check(cut == 46, "46 tutorial Lands cut in the real pack (%d)" % cut)
		var field = FIELD.new()
		check(not field.configure_verified_catalog(catalog,str(options.source_manifest_sha256),44502), "a tutorial Land never opens")
		var aden = FIELD.new()
		check(aden.configure_verified_catalog(catalog,str(options.source_manifest_sha256),4), "Aden still opens: "+str(aden.problem))
		aden.close()
	# Quests in the real quest service.
	var service: Variant = world.quest_service
	var by_id: Dictionary = {}
	for quest: Dictionary in service.source.quests: by_id[int(quest.get("source_id",0))] = quest
	var tutorial_open: int = 0
	for id: int in TUTORIAL.QUEST_IDS:
		if by_id.has(id) and service.source.gate(by_id[id],{"class_id":52,"level":100},{},int(Time.get_unix_time_from_system())) != TUTORIAL.DECISION: tutorial_open += 1
	check(tutorial_open == 0, "no tutorial quest can start (%d)" % tutorial_open)
	var starts: Dictionary = {}
	for pair: Array in [[73662,5],[74802,52],[76971,81],[78571,7],[79754,94],[81881,111]]:
		if not by_id.has(pair[0]): starts[str(pair[0])] = "absent"; continue
		var reason: String = service.source.gate(by_id[pair[0]],{"class_id":pair[1],"level":1,"max_level":1},{},int(Time.get_unix_time_from_system()))
		starts[str(pair[0])] = reason
		check(not reason.begins_with("선행 퀘스트"), "quest %d is the class %d start (gate: %s)" % [pair[0],pair[1],reason])
	evidence["post_tutorial_start_gates"] = starts
	# Saves: a save file in a tutorial Land with tutorial items.
	check(world._save_game(true) == OK, "baseline save")
	world._load_game(true)
	var baseline: Dictionary = world.inventory.duplicate(true)
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	file["character_source_cursor"] = {"native_land_id":44502,"source_position":[100,200]}
	file["inventory"]["[퀘스트] 퀘스트 이동 주문서 (004) · 원본#138531"] = 3
	var writer := FileAccess.open(world.save_path(), FileAccess.WRITE); writer.store_string(JSON.stringify(file)); writer.close()
	world._load_game(true)
	evidence["cursor_after_load"] = world.character_source_cursor.duplicate(true)
	check(world.character_source_cursor == START_VILLAGE.cursor(), "load moves the character to Giran town")
	check(not world.inventory.has("[퀘스트] 퀘스트 이동 주문서 (004) · 원본#138531") and world.inventory == baseline, "tutorial items removed, others kept")
	check(int(world.tutorial523.get("removed_items",{}).get("138531",0)) == 3 and int(world.tutorial523.get("relocated",{}).get("from_native_land_id",0)) == 44502, "removed amount and origin recorded")
	var backups: int = 0
	for name: String in DirAccess.get_files_at(world.save_path().get_base_dir()):
		if name.contains(".pre-tutorial-523-"): backups += 1
	check(backups >= 1, "the original save is backed up")
	check(world._save_game(true) == OK, "saved after migration")
	world._load_game(true)
	check(int(world.tutorial523.get("removed_items",{}).get("138531",0)) == 3, "the record survives save/load")
	evidence["record"] = world.tutorial523.duplicate(true)
	# Class skill book grant (암흑기사).
	world.job_class = "암흑기사"
	world.tutorial523.erase("start_grant")
	var books: Array = []
	for id: int in TUTORIAL.CLASS_START_ITEMS[52]: books.append(str(world.source_item_record(id).get("name","")))
	var grants: Array = TUTORIAL.start_grants(52,{})
	evidence["grant_stage"] = preload("res://scripts/loot/patch523_item_inventory.gd").stage(world,grants,{"kind":"tutorial523_start_grant"}).get("error","ok")
	world._tutorial523_grant_retry_at = 0.0
	world._tutorial523_start_grant()
	var granted: int = 0
	for name: String in books:
		if not name.is_empty() and int(world.inventory.get(name,0)) >= 1: granted += 1
	evidence["books"] = books; evidence["granted"] = granted
	check(granted == 3, "암흑기사 receives its three 1단계 기술서 (%d)" % granted)
	var counts: Array = books.map(func(name: String) -> int: return int(world.inventory.get(name,0)))
	world._tutorial523_grant_retry_at = 0.0
	world._tutorial523_start_grant()
	check(books.map(func(name: String) -> int: return int(world.inventory.get(name,0))) == counts, "granted only once")
	world._load_game(true)
	check(world.tutorial523.get("start_grant") is Dictionary and books.map(func(name: String) -> int: return int(world.inventory.get(name,0))) == counts, "grant and books survive save/load")
	world.queue_free()
	await process_frame

func run() -> void:
	synthetic()
	if not SOURCE.not_installed():
		derived()
		await actual_main()
	print("TUTORIAL523_REMOVAL_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
