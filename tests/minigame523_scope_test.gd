extends SceneTree
## Original 523 minigame / roulette-display decision guard
## (docs/minigame523_missing_rules.md). Nothing is implemented on purpose:
## every MiniGame* row belongs to the one LuckyDefence minigame, whose
## ContentsControl is off and whose wave spawns / in-game currency amounts /
## enum names are not in the tables. Without the original definition ZIP only
## the document check runs. With it the facts the decision rests on are read
## back from the rows, and actual Main is entered to confirm that no route
## reaches the defence Land, that the save carries no minigame state and that
## save -> reload keeps working.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const DOC := "res://docs/minigame523_missing_rules.md"
const DEFENCE_LAND := 49788
const MINIGAME_TABLES := ["MiniGameCellGroup","MiniGameComponent","MiniGameFinishCondition","MiniGameReward",
	"MiniGameTicketCost","MiniGameTreasure","MiniGameTreasureProbability","MiniGameTreasureRerollCost","MiniGameWaveTime"]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("MINIGAME523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func document() -> void:
	var text: String = FileAccess.get_file_as_string(DOC)
	check(text.contains("## 1. 판정표") and text.contains("LuckyDefence") and text.contains("RouletteDisplayTypeID"), "decision document lists the judgement table")
	check(text.contains("구현 안 함") and text.contains("FishMiniGame"), "document records the not-implemented decision and the fishing exclusion")

func table() -> void:
	var games: Array[Dictionary] = SOURCE.rows("MiniGame")
	if not check(games.size()==1 and str(games[0].Name)=="LuckyDefence", "MiniGame has exactly one row, LuckyDefence"): return
	var game: Dictionary = games[0]
	var control: Dictionary = SOURCE.row("ContentsControl",int(game.ContentsControlID))
	check(str(control.get("Name",""))=="LuckyDefence" and control.get("Enable")==false, "LuckyDefence ContentsControl is disabled in 523")
	var counts: Dictionary = {}
	for table_name: String in MINIGAME_TABLES:
		var foreign: int = 0
		for row: Dictionary in SOURCE.rows(table_name):
			if int(row.MiniGameID)!=int(game.ID): foreign += 1
		counts[table_name] = SOURCE.rows(table_name).size()
		check(foreign==0, "%s rows all belong to LuckyDefence" % table_name)
	evidence["rows"] = counts
	check(int(counts.MiniGameTreasure)==118 and int(counts.MiniGameWaveTime)==26, "MiniGameTreasure 118 / MiniGameWaveTime 26 rows")
	# Missing rule #4: the in-game currency drop has no amount column.
	var drop: Dictionary = SOURCE.rows("NpcItemDropView")[0]
	check(not drop.has("Amount") and not drop.has("Count") and not drop.has("MinAmount"), "NpcItemDropView has no amount column")
	# Missing rule #2: the spawn packs hold only the wave-0 currency NPCs.
	var spawn_npcs: Dictionary = {}
	for row: Dictionary in SOURCE.rows("NpcSpawnPackNpcClassView"):
		var npc: Dictionary = SOURCE.row("NpcClass",int(row.NpcClassID))
		if str(npc.get("Name","")).begins_with("[디펜스]"): spawn_npcs[str(npc.Name)] = true
	evidence["defence_spawn_npcs"] = spawn_npcs.keys()
	check(spawn_npcs.size()==1 and spawn_npcs.has("[디펜스] Wave0 시작 재화 지급"), "no wave monster spawn table for the defence")
	# Roulette display: probability rows exist, the display-type meaning does not.
	check(SOURCE.rows("RouletteDisplayOfGachaProbability").size()==56 and SOURCE.rows("RouletteDisplayOfMergeProbability").size()==95, "roulette display rows 56 + 95")
	var reached: Array = []
	for table_name: String in ["LandTeleportTerritories","LandTimeLimit","SpecialDungeonType","SeasonDungeon"]:
		for row: Dictionary in SOURCE.rows(table_name):
			for key: Variant in row:
				if str(key).to_lower().contains("land") and typeof(row[key]) in [TYPE_INT,TYPE_FLOAT] and int(row[key])==DEFENCE_LAND: reached.append([table_name,int(row.get("ID",0))])
	check(reached.is_empty(), "no teleport/dungeon row reaches the defence Land: "+str(reached))

func _mentions_defence(value: Variant) -> bool:
	match typeof(value):
		TYPE_DICTIONARY:
			for key: Variant in value:
				var lower: String = str(key).to_lower()
				if lower.contains("minigame") or lower.contains("luckydefence"): return true
				if lower.contains("land") and typeof(value[key]) in [TYPE_INT,TYPE_FLOAT] and int(value[key])==DEFENCE_LAND: return true
				if _mentions_defence(value[key]): return true
		TYPE_ARRAY:
			for item: Variant in value:
				if _mentions_defence(item): return true
	return false

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	if not check(QA.enter_game(world), "actual Main map entry"): world.queue_free(); await process_frame; return
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	var dungeons: Dictionary = world.source_dungeons.data
	evidence["dungeon_projection_loaded"] = not dungeons.is_empty()
	check(not _mentions_defence(dungeons), "Main dungeon projection has no defence Land / minigame entry")
	check(world._save_game(true)==OK, "Main save")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved is Dictionary and not _mentions_defence(saved), "save carries no minigame state")
	var before: Array = [int(world.gold),int(world.level)]
	world.gold += 523; world.level += 1
	world._load_game(true)
	await process_frame
	evidence["reload"] = {"before":before,"after":[int(world.gold),int(world.level)]}
	check(world.player!=null and [int(world.gold),int(world.level)]==before, "save -> reload restores gold and level")
	world.queue_free(); await process_frame

func run() -> void:
	document()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("MINIGAME523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
