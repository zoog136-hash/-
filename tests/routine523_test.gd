extends SceneTree
## 523 루틴(미션) and 할 일 목록 rules on synthetic rows (no original table
## values are embedded): goal-link proof, per-goal progress, MissionComplete
## counting, period resets (KST 05:00, Wednesday week, 1st of month, clock
## moved back), atomic reward claims, ToDoList filters/registration/status
## and the save round trip.
const SRC = preload("res://scripts/routine523/routine523_source.gd")
const RUNTIME = preload("res://scripts/routine523/routine523_runtime.gd")
var failures: Array[String] = []

class Ain:
	var blessing: int = 10
	func export_state() -> Dictionary: return {"blessing":blessing}
	func import_state(value: Dictionary) -> void: blessing = int(value.blessing)

class Quests:
	var index: Dictionary = {"m523:quest:900":{}}
	var claimed: Dictionary = {}

class FakeWorld extends Node:
	var level: int = 50
	var gold: int = 0
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var ain_service = Ain.new()
	var quest_service = Quests.new()
	var loot_catalog: Dictionary = {"by_name":{"시험 코인":{"name":"시험 코인","slot":"currency"}}}
	var hud = null
	var saves: Array = []
	var fail_save: bool = false
	func _save_game(_quiet: bool, overrides: Dictionary = {}) -> int:
		if fail_save: return ERR_CANT_CREATE
		saves.append(overrides.duplicate(true))
		return OK
	func _catalog_item_from_source_id(_id: String) -> Dictionary: return {}
	func _request_deferred_save() -> void: pass
	func _update_hud() -> void: pass

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

const OFFSET := SRC.GOAL_ID_OFFSET

func tables() -> Dictionary:
	var views: Array = []
	var goals: Array = []
	var links: Array = []
	var rewards: Array = []
	var descs: Array = [{"ID":1,"Description":"일간"},{"ID":2,"Description":"주간"},{"ID":3,"Description":"월간"},{"ID":4,"Description":"주간 (월드 던전)"},{"ID":5,"Description":"임시"},{"ID":50,"Description":"일간 미션 달성"},{"ID":51,"Description":"주간 미션 달성"}]
	# id, type, goal type, class, amount, reward [type, class, amount]
	var spec: Array = [
		[10,4,1,0,3,[2,700,5]],      # daily: any kill x3, item reward
		[20,4,2,77,2,[5,0,30]],      # daily: npc group 77 kill x2, blessing
		[30,4,3,0,1,[5,0,40]],       # daily: challenge x1
		[40,4,4,1,1,[5,0,10]],       # daily: polymorph card buy
		[50,4,9,0,1,[5,0,10]],       # daily: party dungeon (unsupported)
		[60,6,8,4,3,[5,0,300]],      # daily complete: 3 daily missions
		[70,5,5,2,4,[5,0,20]],       # weekly: doll compose x4
		[80,5,6,0,2,[5,0,20]],       # weekly: craft try x2
		[90,6,8,5,1,[5,0,100]],      # weekly complete
		[100,21,7,0,1,[5,0,50]],     # monthly: enchant success
		[110,6,8,21,1,[5,0,500]],    # monthly complete
		[120,31,2,77,1,[5,0,60]],    # world weekly: group kill
		[130,4,1,0,1,[5,0,1]],       # daily without a goal row
		[140,4,1,0,1,[2,800,7]],     # daily: coin reward (giveable currency)
	]
	for row: Array in spec:
		views.append({"ID":row[0],"Type":row[1],"TitleDescID":50 if row[0]==60 else (51 if row[0]==90 else 0),"ScenarioDescID":0,"RoutineSymbolID":2,"IsLucky":false})
		if row[0] != 130: goals.append({"ID":row[0]+OFFSET,"GoalTypeID":row[2],"GoalClassID":row[3],"Amount":row[4],"DescID":0,"CharacterClassID":0})
		var reward: Array = row[5]
		rewards.append({"ID":row[0]*10,"RewardTypeID":reward[0],"RewardClassID":reward[1],"Amount":reward[2],"ClanOnly":false,"CharacterClassID":0,"RewardEnhancementTypeID":1,"UseImmediately":false,"ItemBlessCodeID":1})
		links.append({"RoutineID":row[0],"RewardID":row[0]*10,"LevelRewardID":0,"IgnorePercent":false})
	views.append({"ID":999,"Type":3,"TitleDescID":0,"ScenarioDescID":0})
	return {
		"RoutineType":[{"ID":3,"Name":"ClanQuest","DescID":0},{"ID":4,"Name":"MissionDaily","DescID":1},{"ID":5,"Name":"MissionWeekly","DescID":2},{"ID":21,"Name":"MissionMonthly","DescID":3},{"ID":31,"Name":"MissionWorldWeekly","DescID":4},{"ID":6,"Name":"MissionComplete","DescID":5}],
		"RoutineView":views,"RoutineReward":links,"Reward":rewards,"Goal":goals,
		"GoalType":[{"ID":1,"Name":"AnyNpcKill"},{"ID":2,"Name":"NpcGroupKill"},{"ID":3,"Name":"ChallengeCompleteCount"},{"ID":4,"Name":"BuffCardBuy"},{"ID":5,"Name":"BuffCardCompose"},{"ID":6,"Name":"TryItemCraft"},{"ID":7,"Name":"ItemEnchantSuccess"},{"ID":8,"Name":"RoutineCompleteCount"},{"ID":9,"Name":"PartyDungeonComplete"}],
		"RewardType":[{"ID":2,"Name":"Item"},{"ID":5,"Name":"Einasad"}],
		"ItemClass":[{"ID":700,"Name":"시험 상자"},{"ID":800,"Name":"[화폐] 시험 코인"}],
		"CurrencyUnitClass":[{"ClassID":800,"CurrencyID":5,"UnitID":4,"ForGive":true}],
		"NpcClassForNpcGroup":[{"NpcGroupID":77,"NpcClassID":5001,"ServerLimitSetID":0},{"NpcGroupID":77,"NpcClassID":5002,"ServerLimitSetID":9}],
		"DescData_Korean":descs,
		"ConstantData":[{"Name":"TodoStatusBoardMaxRegistedContents","Value":"2"}],
		"ToDoListResetType":[{"ID":2,"Name":"Daily"},{"ID":12,"Name":"Weekly"}],
		"ToDoListType":[{"ID":2,"Name":"Quest"},{"ID":12,"Name":"DailyMission"},{"ID":62,"Name":"CommonDungeon"},{"ID":72,"Name":"ClanQuest"}],
		"ToDoListUICategory":[{"ID":2,"Name":"Dungeon","Priority":4},{"ID":22,"Name":"Quest","Priority":0}],
		"ToDoListUISubCategory":[{"ID":2,"Name":"미션"},{"ID":52,"Name":"일반 던전"}],
		"ToDoList":[
			{"ID":1,"ToDoListType":12,"ToDoListUICategory":22,"ToDoListUISubCategory":2,"ToDoListTargetType":12,"Value":0,"Count":0,"AddLevel":1,"RemoveLevel":0,"ToDoListResetType":2,"ServerLimitsetID":0,"DescID":50,"IsEvent":false,"StartDateTimeID":1,"EndDateTimeID":3,"Priority":2},
			{"ID":2,"ToDoListType":2,"ToDoListUICategory":22,"ToDoListUISubCategory":2,"ToDoListTargetType":2,"Value":900,"Count":1,"AddLevel":1,"RemoveLevel":0,"ToDoListResetType":2,"ServerLimitsetID":0,"DescID":0,"IsEvent":false,"StartDateTimeID":1,"EndDateTimeID":3,"Priority":1},
			{"ID":3,"ToDoListType":62,"ToDoListUICategory":2,"ToDoListUISubCategory":52,"ToDoListTargetType":12,"Value":41,"Count":0,"AddLevel":60,"RemoveLevel":0,"ToDoListResetType":2,"ServerLimitsetID":0,"DescID":0,"IsEvent":false,"StartDateTimeID":1,"EndDateTimeID":3,"Priority":3},
			{"ID":4,"ToDoListType":62,"ToDoListUICategory":2,"ToDoListUISubCategory":52,"ToDoListTargetType":12,"Value":41,"Count":0,"AddLevel":1,"RemoveLevel":0,"ToDoListResetType":2,"ServerLimitsetID":44,"DescID":0,"IsEvent":false,"StartDateTimeID":1,"EndDateTimeID":3,"Priority":4},
			{"ID":5,"ToDoListType":62,"ToDoListUICategory":2,"ToDoListUISubCategory":52,"ToDoListTargetType":12,"Value":41,"Count":0,"AddLevel":1,"RemoveLevel":0,"ToDoListResetType":2,"ServerLimitsetID":0,"DescID":0,"IsEvent":true,"StartDateTimeID":1,"EndDateTimeID":2,"Priority":5},
			{"ID":7,"ToDoListType":72,"ToDoListUICategory":22,"ToDoListUISubCategory":2,"ToDoListTargetType":12,"Value":0,"Count":3,"AddLevel":1,"RemoveLevel":0,"ToDoListResetType":2,"ServerLimitsetID":0,"DescID":0,"IsEvent":false,"StartDateTimeID":1,"EndDateTimeID":3,"Priority":0},
			{"ID":6,"ToDoListType":62,"ToDoListUICategory":2,"ToDoListUISubCategory":52,"ToDoListTargetType":12,"Value":41,"Count":0,"AddLevel":1,"RemoveLevel":0,"ToDoListResetType":2,"ServerLimitsetID":0,"DescID":0,"IsEvent":true,"StartDateTimeID":1,"EndDateTimeID":3,"Priority":6},
		],
		"TodoListRecommend":[{"ID":1,"ToDoListID":1,"AddLevel":1,"RemoveLevel":0},{"ID":2,"ToDoListID":3,"AddLevel":60,"RemoveLevel":0},{"ID":3,"ToDoListID":2,"AddLevel":1,"RemoveLevel":60}],
		"ServerLimit":[{"ServerLimitSetID":44,"WorldNo":2,"ServiceRegionCode":"KR"}],
		"DateTimes_Korean":[{"ID":1,"Year":2016,"Month":1,"Day":1,"Hour":0,"Minute":0},{"ID":2,"Year":2020,"Month":1,"Day":1,"Hour":0,"Minute":0},{"ID":3,"Year":2099,"Month":12,"Day":31,"Hour":23,"Minute":59}],
	}

## Unix time of a KST wall clock.
func kst(year: int, month: int, day: int, hour: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year":year,"month":month,"day":day,"hour":hour,"minute":0,"second":0})) - 9*3600

func _initialize() -> void:
	var c: Dictionary = SRC.build(tables())
	check(c.get("ok",false), "contract builds: "+str(c.get("problem","")))
	if not c.get("ok",false):
		print("ROUTINE523_RESULT ", JSON.stringify({"failures":failures}))
		quit(1)
		return
	check(not c.missions.has(999), "clan quests are not missions")
	check(c.complete_by_type == {4:60,5:90,21:110}, "MissionComplete anchors")
	check(str(c.missions[50].reasons[0]).begins_with("goal_unsupported:PartyDungeonComplete"), "party dungeon refused")
	check(c.missions[130].reasons == ["goal_missing"], "missing goal row kept")
	check(c.type_labels[31] == "주간 (월드 던전)", "type labels from RoutineType DescID")
	# A broken anchor refuses every link.
	var broken: Dictionary = tables()
	for goal: Dictionary in broken.Goal:
		if int(goal.ID) == 90+OFFSET: goal.GoalClassID = 4
	check(not SRC.build(broken).get("ok",true), "unproven goal offset refused")
	var world := FakeWorld.new()
	var runtime = RUNTIME.new()
	runtime.contract_override = c
	runtime.configure(world)
	runtime.now_override = kst(2026,11,11,12) # Wednesday
	runtime.advance()
	# Progress.
	for i: int in range(5): runtime.record("kill",{"npc_id":1234})
	check(runtime.progress(10) == 3, "any kill capped at goal")
	runtime.record("kill",{"npc_id":5001})
	runtime.record("kill",{"npc_id":5002})
	check(runtime.progress(20) == 1 and runtime.progress(120) == 1, "group kill counts members of ServerLimitSetID 0 only")
	runtime.record("kill",{"npc_id":5001})
	check(runtime.achieved(20) and runtime.achieved(120), "group kill goals")
	runtime.record("card_buy",{"deck":2})
	check(runtime.progress(40) == 0, "doll purchase is not a polymorph purchase")
	runtime.record("card_buy",{"deck":1})
	runtime.record("challenge_complete",{"challenge_id":7})
	runtime.record("card_compose",{"deck":2,"amount":3})
	runtime.record("craft_try",{"amount":2})
	runtime.record("enchant_success",{})
	check(runtime.achieved(30) and runtime.achieved(40) and runtime.progress(70) == 3 and runtime.achieved(80) and runtime.achieved(100), "event goals")
	check(runtime.progress(60) == 3 and runtime.achieved(60), "daily complete counts achieved daily missions (party dungeon never)")
	check(runtime.progress(90) == 1, "weekly complete counts")
	# Claims: an item reward needs the original item supplier (absent here):
	# refused, nothing saved, state unchanged.
	var before: Dictionary = runtime.state.duplicate(true)
	check(not runtime.claim(10).get("ok",true) and world.saves.is_empty() and runtime.state == before, "item claim refused and preserved without supplier")
	check(not runtime.claim(70).get("ok",true), "unfinished mission not claimable")
	var claimed: Dictionary = runtime.claim(20)
	check(claimed.get("ok",false) and world.ain_service.blessing == 40 and runtime.claimed(20) and world.saves.size() == 1 and world.saves[0].has(RUNTIME.SAVE_KEY), "blessing claim saved atomically")
	check(not runtime.claim(20).get("ok",true), "no double claim")
	check(runtime.claim(140).get("ok",false) and int(world.inventory.get("시험 코인",0)) == 7 and world.saves[-1].inventory.get("시험 코인") == 7, "coin reward stacks the existing currency item")
	world.fail_save = true
	check(not runtime.claim(30).get("ok",true) and not runtime.claimed(30) and world.ain_service.blessing == 40, "failed save keeps reward")
	world.fail_save = false
	var all: Dictionary = runtime.claim_all(4)
	check(not all.get("ok",true), "claim all refused while one item reward has no supplier")
	check(runtime.claim(30).get("ok",false) and runtime.claim(40).get("ok",false) and runtime.claim(60).get("ok",false) and world.ain_service.blessing == 40+40+10+300, "daily claims")
	# Resets: same day before 05:00 next day keeps, after resets daily only.
	runtime.now_override = kst(2026,11,12,4)
	runtime.advance()
	check(runtime.claimed(30) and runtime.progress(10) == 3, "before 05:00 KST nothing resets")
	runtime.now_override = kst(2026,11,12,5)
	runtime.advance()
	check(not runtime.claimed(30) and runtime.progress(10) == 0 and runtime.progress(70) == 3 and runtime.achieved(120), "daily reset at 05:00 KST keeps weekly")
	runtime.now_override = kst(2026,11,11,12)
	runtime.record("kill",{"npc_id":1})
	runtime.advance()
	check(runtime.progress(10) == 1, "clock moved back does not reset again")
	runtime.now_override = kst(2026,11,18,4)
	runtime.advance()
	check(runtime.progress(70) == 3, "week runs to Wednesday 05:00")
	runtime.now_override = kst(2026,11,18,5)
	runtime.advance()
	check(runtime.progress(70) == 0 and runtime.progress(120) == 0 and runtime.achieved(100), "weekly reset on Wednesday keeps monthly")
	runtime.now_override = kst(2026,12,1,5)
	runtime.advance()
	check(not runtime.achieved(100), "monthly reset on the 1st 05:00")
	# 할 일 목록.
	runtime.now_override = kst(2026,11,11,12)
	var catalog: Array = runtime.todo_catalog("daily")
	var ids: Array = catalog.map(func(row: Dictionary) -> int: return int(row.entry.id))
	check(ids == [2,1,3,6], "catalog filters clan, server limit and ended event, priority order")
	check(not catalog[2].open and catalog[2].lock_level == 60, "level locked entry shown with its level")
	var board: Array = runtime.todo_board("daily")
	check(board.map(func(row: Dictionary) -> int: return int(row.entry.id)) == [2,1], "recommended board by level")
	check(board[1].status.known and board[1].status.total == 3, "daily mission entry linked to MissionComplete")
	world.quest_service.claimed["m523:quest:900"] = true
	check(runtime.todo_board("daily")[0].status.done, "quest entry status from quest claims")
	world.level = 60
	check(runtime.todo_board("daily").map(func(row: Dictionary) -> int: return int(row.entry.id)) == [1,3], "level 60 adds and removes recommendations")
	runtime.todo_set_mode("custom")
	check(runtime.todo_board("daily").is_empty(), "custom board starts empty")
	check(runtime.todo_register(3).get("ok",false) and runtime.todo_register(1).get("ok",false), "register two")
	check(not runtime.todo_register(6).get("ok",true), "registration limit from ConstantData")
	check(not runtime.todo_register(4).get("ok",true), "server-limited entry not registrable")
	check(runtime.todo_register(3).get("registered",true) == false and runtime.todo_register(3).get("registered",false) == true, "toggle")
	runtime.todo_set_event_auto(true)
	check(6 in runtime.todo_board("daily").map(func(row: Dictionary) -> int: return int(row.entry.id)), "event auto registration")
	# Before the tables are read (boot/combat path) occurrences wait in
	# state.pending and count only for the periods still current.
	var lazy = RUNTIME.new()
	lazy.configure(world)
	lazy.import_state(JSON.parse_string(JSON.stringify(RUNTIME.fresh())))
	lazy.now_override = kst(2026,11,11,12)
	for i: int in range(2): lazy.record("kill",{"npc_id":5001})
	lazy.record("card_compose",{"deck":2,"amount":1})
	lazy.now_override = kst(2026,11,12,6)
	lazy.record("card_compose",{"deck":2,"amount":2})
	lazy.record("kill",{"npc_id":7})
	check(not lazy.tables_loaded() and lazy.state.pending.size() == 2, "occurrences buffered without reading tables")
	var buffered: Variant = JSON.parse_string(JSON.stringify(lazy.export_state()))
	check(RUNTIME.validate(buffered).is_empty(), "pending saves validly")
	var later = RUNTIME.new()
	later.configure(world)
	later.import_state(buffered)
	later.now_override = kst(2026,11,12,7)
	later.contract_override = c
	later.contract()
	check(later.state.pending.is_empty() and later.progress(10) == 1 and later.progress(20) == 0 and later.progress(120) == 1 and later.progress(70) == 3, "pending applied only to current periods (yesterday's daily kills dropped, weekly kept)")
	# Save round trip and a broken save.
	var saved: Variant = JSON.parse_string(JSON.stringify(runtime.export_state()))
	var reloaded = RUNTIME.new()
	reloaded.contract_override = c
	reloaded.configure(world)
	reloaded.now_override = runtime.now_override
	reloaded.import_state(saved)
	check(reloaded.state == runtime.state, "save round trip")
	var bad = RUNTIME.new()
	bad.contract_override = c
	bad.configure(world)
	bad.import_state({"schema":"other"})
	check(bad.save_blocked and bad.export_state() == {"schema":"other"} and not bad.claim(30).get("ok",true) and not bad.record("kill",{}), "unreadable save is kept and blocks changes")
	world.free()
	print("ROUTINE523_RESULT ", JSON.stringify({"failures":failures,"missions":c.missions.size()}))
	quit(0 if failures.is_empty() else 1)
