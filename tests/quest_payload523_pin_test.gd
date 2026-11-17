extends SceneTree
## 2026-11-17 "퀘스트는 다 없어짐": the original quest projection changed (#625
## reads the 8 아크 변신 카드 rows quest 60341 rewards as TestItem=false) while
## source_quest523.PAYLOAD_SHA still pinned the earlier bytes, so every quest
## was refused with an empty warning and the quest window listed nothing.
## Without the original ZIP (CI): a refused load names its reason in
## quest_service.problem and the quest window, and a stale received payload
## file does not stop the original fallback. With the original ZIP, in actual
## Main: the projection re-derives PAYLOAD_SHA, all 3,621 quests load, a new
## character sees acceptable main quests in the quest window and progresses
## (accept -> next chain quest), the tutorial-chain class start quests stay
## acceptable, and an existing save (with deleted tutorial claims) keeps its
## history and continues.
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
const SERVICE = preload("res://scripts/quests/quest_service.gd")
const PROJECTION = preload("res://scripts/quests/source_quest523_projection.gd")
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const TUTORIAL = preload("res://scripts/content523/tutorial523.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("QUEST_PAYLOAD523_PIN_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func _remove_user_payload() -> void:
	if FileAccess.file_exists(SOURCE.USER_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(SOURCE.USER_PATH))

func synthetic() -> void:
	# A stale/foreign received payload: refused by its fingerprint, the file is
	# kept, and the original tables are the fallback (none here without the ZIP).
	_remove_user_payload()
	var stale := FileAccess.open(SOURCE.USER_PATH, FileAccess.WRITE)
	stale.store_string("{\"quests\":[]}")
	stale.close()
	var stale_sha: String = FileAccess.get_sha256(SOURCE.USER_PATH)
	var source = SOURCE.new()
	var loaded: bool = source.load_pack()
	evidence["stale_file_problem"] = source.problem
	if ROWS.not_installed():
		check(not loaded and source.problem.contains("SHA-256 불일치"), "stale payload refused by fingerprint: "+source.problem)
	else:
		check(loaded and source.quests.size() == 3621 and source.loaded_path.is_empty(), "stale payload -> original tables fallback (%d quests, %s)" % [source.quests.size(),source.problem])
	check(FileAccess.get_sha256(SOURCE.USER_PATH) == stale_sha, "the received file itself is left untouched")
	_remove_user_payload()
	if ROWS.not_installed():
		var service = SERVICE.new()
		check(not service.configure([],[]) and service.problem.begins_with("원본 퀘스트 불러오기 실패: ") and service.problem.length() > "원본 퀘스트 불러오기 실패: ".length(), "a refused quest load names its reason: "+service.problem)
		evidence["service_problem"] = service.problem

func acceptable(world: Node) -> Array[String]:
	var service: Variant = world.quest_service
	var class_id: int = int(service.source.class_ids.get(str(world.job_class),-1))
	var found: Array[String] = []
	var pages: int = int(service.text_page(int(world.level),"main",0,60,"","waiting",-1,class_id).pages)
	for index: int in pages:
		for row: Dictionary in service.text_page(int(world.level),"main",index,60,"","waiting",-1,class_id).rows:
			if bool(row.can_accept): found.append(str(row.id))
	return found

## Accepts `target` with its [수락] button in the actual quest window (found
## with the window's own search box, as a player would page or search).
func accept_in_window(world: Node, target: String) -> bool:
	var hud: Node = world.hud
	hud.open_quests()
	for frame: int in 2: await process_frame
	var view: Node = hud.quest_view
	if not check(is_instance_valid(view), "quest window opens"): return false
	view.search.text = str(int(world.quest_service.index.get(target,{}).get("source_id",0)))
	view.refresh()
	for frame: int in 2: await process_frame
	var button: Button = null
	for row: Node in view.listing.get_children():
		for child: Node in row.get_children():
			if child is Button and not (child as Button).disabled: button = child
	if not check(button != null and view.listing.get_child_count() == 1, "%s has an enabled [수락] in the quest window" % target): return false
	button.pressed.emit()
	for frame: int in 3: await process_frame
	view.search.text = ""
	return world.quest_service.claimed.has(target)

func runtime() -> void:
	var projection = PROJECTION.new()
	var value: Dictionary = projection.build()
	var bytes: PackedByteArray = PROJECTION.encoded(value)
	evidence["projection_sha256"] = bytes.get_string_from_utf8().sha256_text()
	check(evidence.projection_sha256 == SOURCE.PAYLOAD_SHA, "original projection re-derives PAYLOAD_SHA (%s)" % evidence.projection_sha256)
	check((value.get("quests",[]) as Array).size() == 3621, "projection holds all 3,621 original quests")
	projection = null; value = {}; bytes = PackedByteArray()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main new character (기사)")
	for frame: int in 10: await process_frame
	var service: Variant = world.quest_service
	check(service.quests.size() == 3621 and service.problem.is_empty(), "actual Main loads all original quests (%d, %s)" % [service.quests.size(),service.problem])
	var counts: Dictionary = {}
	var class_id: int = int(service.source.class_ids.get(str(world.job_class),-1))
	for category: String in ["main","common","achievement","other"]:
		var page: Dictionary = service.text_page(int(world.level),category,0,60,"","all",-1,class_id)
		var acceptable: int = 0
		for index: int in page.pages:
			for row: Dictionary in service.text_page(int(world.level),category,index,60,"","all",-1,class_id).rows:
				if bool(row.can_accept): acceptable += 1
		counts[category] = {"listed":page.matches,"acceptable":acceptable}
	evidence["new_character"] = counts
	check(int(counts.main.listed) > 900 and int(counts.main.acceptable) >= 1, "main quests listed and acceptable: "+str(counts.main))
	check(int(counts.common.listed) > 500, "common quests listed: "+str(counts.common))
	# The window's first page shows acceptable quests (no paging needed).
	world.hud.open_quests()
	for frame: int in 2: await process_frame
	var shown: int = 0; var shown_open: int = 0
	for row: Node in world.hud.quest_view.listing.get_children():
		shown += 1
		for child: Node in row.get_children():
			if child is Button and not (child as Button).disabled: shown_open += 1
	evidence["window_first_page"] = {"rows":shown,"acceptable":shown_open,"summary":world.hud.quest_view.summary.text}
	check(shown == 30 and shown_open >= 1, "quest window first page lists quests with [수락]: "+str(evidence.window_first_page))
	# Accept the knight start quest, then follow what each acceptance unlocks.
	var chain: Array[String] = []
	var before: Array[String] = acceptable(world)
	check(before.has("m523:quest:59912"), "knight start quest 59912 acceptable for a new character")
	var target: String = "m523:quest:59912"
	for step: int in 3:
		if not check(await accept_in_window(world, target), "accepted %s from the quest window" % target): break
		chain.append(target)
		var after: Array[String] = acceptable(world)
		var unlocked: Array[String] = []
		for id: String in after:
			if not before.has(id): unlocked.append(id)
		if not check(not unlocked.is_empty(), "accepting %s unlocks the next quest" % target): break
		before = after
		target = unlocked[0]
	evidence["accepted_chain"] = chain
	# Tutorial-chain classes start after their (deleted) tutorial.
	var by_id: Dictionary = {}
	for quest: Dictionary in service.source.quests: by_id[int(quest.get("source_id",0))] = quest
	var starts: Dictionary = {}
	for pair: Array in [[73662,5],[74802,52],[76971,81],[78571,7],[79754,94],[81881,111]]:
		var reason: String = service.source.gate(by_id.get(pair[0],{"id":""}),{"class_id":pair[1],"level":1,"max_level":1},{},int(Time.get_unix_time_from_system())) if by_id.has(pair[0]) else "absent"
		starts[str(pair[0])] = reason
		check(reason.is_empty(), "class %d start quest %d acceptable at level 1 (%s)" % [pair[1],pair[0],reason])
	evidence["tutorial_chain_starts"] = starts
	var tutorial_open: int = 0
	for id: int in TUTORIAL.QUEST_IDS:
		if by_id.has(id) and service.source.gate(by_id[id],{"class_id":52,"level":100},{},int(Time.get_unix_time_from_system())) != TUTORIAL.DECISION: tutorial_open += 1
	check(by_id.size() == 3621 and tutorial_open == 0, "tutorial quests stay deleted (%d open)" % tutorial_open)
	# Existing save: written with deleted tutorial claims, reloaded.
	check(world._save_game(true) == OK, "save")
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	file.quest_state.claimed["m523:quest:74482"] = true
	var writer := FileAccess.open(world.save_path(), FileAccess.WRITE); writer.store_string(JSON.stringify(file)); writer.close()
	world._load_game(true)
	for frame: int in 3: await process_frame
	var kept: bool = true
	for id: String in chain: kept = kept and service.claimed.has(id)
	check(kept and service.claimed.has("m523:quest:74482") and service.quests.size() == 3621, "existing save keeps its quest history")
	var resumed: String = target
	check(acceptable(world).has(resumed) and await accept_in_window(world, resumed), "existing save continues its chain (%s)" % resumed)
	evidence["existing_save_next"] = resumed
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	check(SOURCE.PAYLOAD_SHA == "5ef91702b62e4fc5e1a4209eb040439fac6f4320723652ca8836542bbb94eded", "pinned projection fingerprint")
	synthetic()
	if not ROWS.not_installed(): await runtime()
	print("QUEST_PAYLOAD523_PIN_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
