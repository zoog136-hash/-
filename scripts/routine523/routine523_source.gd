extends RefCounted
## Original 523 루틴(일간/주간/월간 미션) and 할 일 목록(ToDoList, 현황판) rules,
## read only from the installed original definition archive.
##
## Only what the tables state is used. Rules the tables do not give are
## refused (a mission/entry keeps a reason and is never completed or paid)
## and listed in docs/routine_todo523_missing_rules.md:
##  - Missions: RoutineView rows of RoutineType MissionDaily(4),
##    MissionWeekly(5), MissionMonthly(21), MissionWorldWeekly(31) and
##    MissionComplete(6). RoutineView has no goal column and no routine-goal
##    table exists; every mission's goal is the Goal row whose ID is the
##    routine ID + GOAL_ID_OFFSET. The offset is not assumed: it must pair the
##    three MissionComplete routines with the three RoutineCompleteCount goals
##    (GoalClassID = RoutineType 4/5/21) or no goal is linked at all. A routine
##    without a Goal row at that ID keeps "goal_missing".
##  - Rewards: RoutineReward -> Reward rows of RewardType Item(2) and
##    Einasad(5). LevelRewardID/IgnorePercent (clan quests only) are not used;
##    another reward type, ClanOnly, a class limit or an enhancement type
##    other than 1 refuses the mission's claim.
##  - ClanQuest(3) routines (online clan content, out of scope) and the
##    Random* mission types (no RoutineView rows; only the slot-count
##    constants exist) are not shown.
##  - ToDoList: rows filtered by AddLevel/RemoveLevel, ServerLimitsetID (the
##    offline Korean world 1 profile, as the 523 shop uses), the
##    DateTimes_Korean start/end window and their ToDoListResetType; the
##    recommended set is TodoListRecommend (its own level window) and the
##    registration limit is ConstantData TodoStatusBoardMaxRegistedContents.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
## Goal.ID - RoutineView.ID for every linked mission (proven by the
## MissionComplete anchors at load, never trusted on its own).
const GOAL_ID_OFFSET: int = 84870
const COMPLETE_TYPE: int = 6
## RoutineType -> reset period. MissionWorldWeekly resets with the week.
const PERIODS: Dictionary = {4:"daily",5:"weekly",21:"monthly",31:"weekly"}
const TYPE_ORDER: Array[int] = [4,5,21,31]
const REWARD_ITEM: int = 2
const REWARD_EINASAD: int = 5
## Goal types with a TWILIGHT event owner (scripts/routine523/routine523_runtime.gd).
const SUPPORTED_GOALS: Dictionary = {
	"AnyNpcKill":"kill","NpcGroupKill":"kill","ChallengeCompleteCount":"challenge_complete",
	"BuffCardBuy":"card_buy","BuffCardCompose":"card_compose","TryItemCraft":"craft_try",
	"ItemEnchantSuccess":"enchant_success","RoutineCompleteCount":"routine_complete",
}
## Goal types the tables define but TWILIGHT has no rule/owner for.
const UNSUPPORTED_GOALS: Dictionary = {
	"PartyDungeonComplete":"파티 던전(온라인 파티 콘텐츠)이 로컬 게임에 없어 집계하지 않습니다",
	"ItemPay":"아이템 제출(지불) 시점·차감 규칙이 표에 없어 집계하지 않습니다",
}
const TODO_TABLES: Array[String] = ["ToDoList","ToDoListType","ToDoListUICategory","ToDoListUISubCategory","ToDoListResetType","TodoListRecommend"]
const ROUTINE_TABLES: Array[String] = ["RoutineType","RoutineView","RoutineReward"]
const OFFLINE_WORLD_NO: int = 1
const OFFLINE_REGION: String = "KR"
const KST_OFFSET: int = 9 * 3600

static var _cache: Dictionary = {}
static var _cache_key: String = ""

static func _int(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value))

static func _fail(code: String, detail: String = "") -> Dictionary:
	return {"ok":false,"code":code,"problem":detail if not detail.is_empty() else code}

static func reset() -> void:
	_cache = {}
	_cache_key = ""

## The verified contract, or {ok:false, problem}. Cached per archive identity.
static func load_contract() -> Dictionary:
	if SOURCE.not_installed(): return _fail("source_not_installed","원본523 정의 ZIP이 설치되지 않아 루틴·할 일 목록 표를 읽을 수 없습니다.")
	var key: String = SOURCE.verified_key()
	if key.is_empty(): return _fail("source_unavailable",SOURCE.problem())
	if _cache_key == key and not _cache.is_empty(): return _cache
	var tables: Dictionary = {}
	for table: String in ROUTINE_TABLES + TODO_TABLES:
		var rows: Array[Dictionary] = SOURCE.rows(table)
		if rows.is_empty(): return _fail("table_missing","원본 루틴·할 일 표가 없습니다: "+table)
		tables[table] = rows
	var routine_ids: Dictionary = {}
	for row: Dictionary in tables.RoutineView:
		if PERIODS.has(int(row.get("Type",0))) or int(row.get("Type",0)) == COMPLETE_TYPE:
			routine_ids[int(row.ID)] = true
	var goal_ids: Dictionary = {}
	for id: int in routine_ids: goal_ids[id + GOAL_ID_OFFSET] = true
	tables["Goal"] = SOURCE.rows_matching("Goal","ID",goal_ids)
	tables["GoalType"] = SOURCE.rows("GoalType")
	var reward_ids: Dictionary = {}
	for row: Dictionary in tables.RoutineReward:
		if routine_ids.has(int(row.get("RoutineID",0))): reward_ids[int(row.get("RewardID",0))] = true
	tables["Reward"] = SOURCE.rows_matching("Reward","ID",reward_ids)
	tables["RewardType"] = SOURCE.rows("RewardType")
	var item_ids: Dictionary = {}
	for reward: Dictionary in tables.Reward:
		if int(reward.get("RewardTypeID",0)) == REWARD_ITEM: item_ids[int(reward.get("RewardClassID",0))] = true
	tables["ItemClass"] = SOURCE.rows_matching("ItemClass","ID",item_ids)
	tables["CurrencyUnitClass"] = SOURCE.rows_matching("CurrencyUnitClass","ClassID",item_ids)
	var group_ids: Dictionary = {}
	for goal: Dictionary in tables.Goal:
		if int(goal.get("GoalTypeID",0)) > 0: group_ids[int(goal.get("GoalClassID",0))] = true
	tables["NpcClassForNpcGroup"] = SOURCE.rows_matching("NpcClassForNpcGroup","NpcGroupID",group_ids)
	var limit_ids: Dictionary = {}
	var date_ids: Dictionary = {}
	var desc_ids: Dictionary = {}
	for row: Dictionary in tables.ToDoList:
		if int(row.get("ServerLimitsetID",0)) > 0: limit_ids[int(row.ServerLimitsetID)] = true
		date_ids[int(row.get("StartDateTimeID",0))] = true
		date_ids[int(row.get("EndDateTimeID",0))] = true
		desc_ids[int(row.get("DescID",0))] = true
	tables["ServerLimit"] = SOURCE.rows_matching("ServerLimit","ServerLimitSetID",limit_ids) if not limit_ids.is_empty() else []
	tables["DateTimes_Korean"] = SOURCE.rows_matching("DateTimes_Korean","ID",date_ids)
	for row: Dictionary in tables.RoutineView:
		if routine_ids.has(int(row.ID)):
			desc_ids[int(row.get("TitleDescID",0))] = true
			desc_ids[int(row.get("ScenarioDescID",0))] = true
	for goal: Dictionary in tables.Goal: desc_ids[int(goal.get("DescID",0))] = true
	for row: Dictionary in tables.RoutineType: desc_ids[int(row.get("DescID",0))] = true
	for row: Dictionary in tables.ToDoListUISubCategory: desc_ids[int(row.get("DescID",0))] = true
	tables["DescData_Korean"] = SOURCE.rows_matching("DescData_Korean","ID",desc_ids)
	tables["ConstantData"] = SOURCE.rows("ConstantData")
	var built: Dictionary = build(tables)
	if built.get("ok",false):
		_cache = built
		_cache_key = key
	return built

static func _index(rows: Array, field: String = "ID") -> Dictionary:
	var result: Dictionary = {}
	for row: Variant in rows:
		if row is Dictionary and _int(row.get(field)): result[int(row[field])] = row
	return result

static func _desc(index: Dictionary, id: Variant) -> String:
	if not _int(id) or int(id) <= 0: return ""
	return str(index.get(int(id),{}).get("Description","")).strip_edges()

## KST calendar row -> unix seconds (DateTimes_Korean is Korea time).
static func date_unix(row: Dictionary) -> int:
	if row.is_empty(): return -1
	for field: String in ["Year","Month","Day","Hour","Minute"]:
		if not _int(row.get(field)): return -1
	return int(Time.get_unix_time_from_datetime_dict({"year":int(row.Year),"month":int(row.Month),"day":int(row.Day),"hour":int(row.Hour),"minute":int(row.Minute),"second":0})) - KST_OFFSET

## Pure contract from table rows (tests pass synthetic rows).
static func build(tables: Dictionary) -> Dictionary:
	var desc: Dictionary = _index(tables.get("DescData_Korean",[]))
	var types: Dictionary = {}
	var type_labels: Dictionary = {}
	for row: Dictionary in tables.get("RoutineType",[]):
		types[int(row.ID)] = str(row.get("Name",""))
		type_labels[int(row.ID)] = _desc(desc,row.get("DescID"))
	for id: int in [4,5,21,31,COMPLETE_TYPE]:
		if not types.has(id): return _fail("routine_type_missing","원본 RoutineType 행이 없습니다: %d" % id)
	if types[4]!="MissionDaily" or types[5]!="MissionWeekly" or types[21]!="MissionMonthly" or types[31]!="MissionWorldWeekly" or types[COMPLETE_TYPE]!="MissionComplete":
		return _fail("routine_type_changed","원본 RoutineType 이름이 예상과 다릅니다")
	var goal_types: Dictionary = {}
	for row: Dictionary in tables.get("GoalType",[]): goal_types[int(row.ID)] = str(row.get("Name",""))
	var goals: Dictionary = _index(tables.get("Goal",[]))
	var reward_types: Dictionary = {}
	for row: Dictionary in tables.get("RewardType",[]): reward_types[int(row.ID)] = str(row.get("Name",""))
	var rewards: Dictionary = _index(tables.get("Reward",[]))
	var item_names: Dictionary = {}
	for row: Dictionary in tables.get("ItemClass",[]): item_names[int(row.ID)] = str(row.get("Name",""))
	# Giveable currency items (CurrencyUnitClass UnitID 4, ForGive), the same
	# rows the original quest rewards use for coin stacks.
	var giveable: Dictionary = {}
	var adena: Dictionary = {}
	for row: Dictionary in tables.get("CurrencyUnitClass",[]):
		if int(row.get("CurrencyID",0)) == 1: adena[int(row.get("ClassID",0))] = true
		elif int(row.get("UnitID",0)) == 4 and bool(row.get("ForGive",false)): giveable[int(row.get("ClassID",0))] = true
	var routine_rewards: Dictionary = {}
	for row: Dictionary in tables.get("RoutineReward",[]):
		var rid: int = int(row.get("RoutineID",0))
		if not routine_rewards.has(rid): routine_rewards[rid] = []
		routine_rewards[rid].append(row)
	var views: Array = []
	for row: Dictionary in tables.get("RoutineView",[]):
		var type_id: int = int(row.get("Type",0))
		if PERIODS.has(type_id) or type_id == COMPLETE_TYPE: views.append(row)
	views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.ID) < int(b.ID))
	# Anchor: each MissionComplete routine's offset goal is RoutineCompleteCount
	# of a distinct mission type. Otherwise the offset is not proven.
	var anchors: Dictionary = {}
	for row: Dictionary in views:
		if int(row.Type) != COMPLETE_TYPE: continue
		var goal: Dictionary = goals.get(int(row.ID) + GOAL_ID_OFFSET,{})
		var counted: int = int(goal.get("GoalClassID",-1))
		if goal.is_empty() or goal_types.get(int(goal.get("GoalTypeID",0)),"") != "RoutineCompleteCount" or not PERIODS.has(counted) or counted == 31 or anchors.has(counted):
			return _fail("routine_goal_link_unproven","루틴-목표(Goal) 연결 근거(미션 달성 행)가 표와 맞지 않아 미션을 연결하지 않습니다")
		anchors[counted] = int(row.ID)
	if anchors.size() != 3: return _fail("routine_goal_link_unproven","미션 달성 루틴 3종(일간·주간·월간)이 표에 없습니다")
	var group_members: Dictionary = {}
	for link: Dictionary in tables.get("NpcClassForNpcGroup",[]):
		var group: int = int(link.get("NpcGroupID",0))
		if not group_members.has(group): group_members[group] = {}
		group_members[group][int(link.get("NpcClassID",0))] = int(link.get("ServerLimitSetID",0))
	var missions: Dictionary = {}
	var by_type: Dictionary = {4:[],5:[],21:[],31:[],COMPLETE_TYPE:[]}
	var refused: Array = []
	for row: Dictionary in views:
		var id: int = int(row.ID)
		var type_id: int = int(row.Type)
		var mission: Dictionary = {"id":id,"type":type_id,"type_name":types[type_id],"title":_desc(desc,row.get("TitleDescID")),"scenario":_desc(desc,row.get("ScenarioDescID")),"symbol":int(row.get("RoutineSymbolID",0)),"lucky":bool(row.get("IsLucky",false)),"reasons":[],"rewards":[]}
		var goal: Dictionary = goals.get(id + GOAL_ID_OFFSET,{})
		if goal.is_empty():
			mission.reasons.append("goal_missing")
		else:
			var type_name: String = goal_types.get(int(goal.get("GoalTypeID",0)),"")
			mission["goal"] = {"id":int(goal.ID),"type":type_name,"class_id":int(goal.get("GoalClassID",0)),"amount":int(goal.get("Amount",0)),"text":_desc(desc,goal.get("DescID")),"character_class_id":int(goal.get("CharacterClassID",0))}
			if int(goal.get("Amount",0)) < 1: mission.reasons.append("goal_amount_invalid")
			elif int(goal.get("CharacterClassID",0)) != 0: mission.reasons.append("goal_class_limit")
			elif UNSUPPORTED_GOALS.has(type_name): mission.reasons.append("goal_unsupported:"+type_name)
			elif not SUPPORTED_GOALS.has(type_name): mission.reasons.append("goal_unknown:"+type_name)
			elif type_name == "NpcGroupKill" and not group_members.has(int(goal.GoalClassID)): mission.reasons.append("npc_group_missing")
			elif type_name == "RoutineCompleteCount" and type_id != COMPLETE_TYPE: mission.reasons.append("goal_unknown:"+type_name)
		if type_id == COMPLETE_TYPE:
			var counted: int = int(mission.get("goal",{}).get("class_id",-1))
			mission["period"] = PERIODS.get(counted,"")
			mission["counts_type"] = counted
		else:
			mission["period"] = PERIODS[type_id]
		for link: Dictionary in routine_rewards.get(id,[]):
			if int(link.get("LevelRewardID",0)) != 0 or bool(link.get("IgnorePercent",false)):
				mission.reasons.append("level_reward_unsupported")
				continue
			var reward: Dictionary = rewards.get(int(link.get("RewardID",0)),{})
			if reward.is_empty():
				mission.reasons.append("reward_missing:%d" % int(link.get("RewardID",0)))
				continue
			var kind: int = int(reward.get("RewardTypeID",0))
			var amount: int = int(reward.get("Amount",0))
			if bool(reward.get("ClanOnly",false)): mission.reasons.append("reward_clan_only")
			elif int(reward.get("CharacterClassID",0)) != 0: mission.reasons.append("reward_class_limit")
			elif int(reward.get("RewardEnhancementTypeID",1)) != 1: mission.reasons.append("reward_enhancement")
			elif bool(reward.get("UseImmediately",false)): mission.reasons.append("reward_use_immediately")
			elif amount < 1: mission.reasons.append("reward_amount")
			elif kind == REWARD_ITEM and reward_types.get(kind,"") == "Item":
				var item_id: int = int(reward.get("RewardClassID",0))
				var item: Dictionary = {"reward_id":int(reward.ID),"kind":"item","item_class_id":item_id,"amount":amount,"bless_raw":int(reward.get("ItemBlessCodeID",1)),"name":item_names.get(item_id,"")}
				if giveable.has(item_id) and not adena.has(item_id): item["currency_name"] = str(item_names.get(item_id,"")).trim_prefix("[화폐] ")
				mission.rewards.append(item)
			elif kind == REWARD_EINASAD and reward_types.get(kind,"") == "Einasad":
				mission.rewards.append({"reward_id":int(reward.ID),"kind":"blessing","amount":amount})
			else: mission.reasons.append("reward_type_unsupported:%d" % kind)
		if routine_rewards.get(id,[]).is_empty(): mission.reasons.append("reward_rows_missing")
		missions[id] = mission
		by_type[type_id].append(id)
		if not mission.reasons.is_empty(): refused.append({"id":id,"title":mission.title,"reasons":mission.reasons.duplicate()})
	var constants: Dictionary = {}
	for row: Dictionary in tables.get("ConstantData",[]):
		var name: String = str(row.get("Name",""))
		if name.begins_with("Todo") or name.begins_with("Routine") or name.begins_with("RandomMission"): constants[name] = str(row.get("Value",""))
	var todo: Dictionary = _build_todo(tables,desc,missions,anchors,constants)
	if not todo.get("ok",false): return todo
	return {"ok":true,"missions":missions,"by_type":by_type,"type_labels":type_labels,"complete_by_type":anchors,"group_members":group_members,"refused":refused,"constants":constants,"todo":todo}

static func _build_todo(tables: Dictionary, desc: Dictionary, missions: Dictionary, anchors: Dictionary, constants: Dictionary) -> Dictionary:
	var resets: Dictionary = {}
	for row: Dictionary in tables.get("ToDoListResetType",[]): resets[int(row.ID)] = str(row.get("Name",""))
	if resets.get(2,"") != "Daily" or resets.get(12,"") != "Weekly": return _fail("todo_reset_type_changed","원본 ToDoListResetType(Daily 2 / Weekly 12)이 예상과 다릅니다")
	var limit: String = str(constants.get("TodoStatusBoardMaxRegistedContents",""))
	if not limit.is_valid_int() or int(limit) < 1: return _fail("todo_limit_missing","원본 현황판 등록 상한(TodoStatusBoardMaxRegistedContents)이 없습니다")
	var type_names: Dictionary = {}
	for row: Dictionary in tables.get("ToDoListType",[]): type_names[int(row.ID)] = str(row.get("Name",""))
	var categories: Array = []
	for row: Dictionary in tables.get("ToDoListUICategory",[]): categories.append({"id":int(row.ID),"name":str(row.get("Name","")),"priority":int(row.get("Priority",0))})
	categories.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.priority < b.priority)
	var subs: Dictionary = {}
	for row: Dictionary in tables.get("ToDoListUISubCategory",[]): subs[int(row.ID)] = str(row.get("Name",""))
	var allowed_limits: Dictionary = {}
	for row: Dictionary in tables.get("ServerLimit",[]):
		if int(row.get("WorldNo",0)) == OFFLINE_WORLD_NO and str(row.get("ServiceRegionCode","")) == OFFLINE_REGION: allowed_limits[int(row.get("ServerLimitSetID",0))] = true
	var dates: Dictionary = _index(tables.get("DateTimes_Korean",[]))
	# A DailyMission/WeeklyMission entry names the MissionComplete routine whose
	# title is the same original text ("일간 미션 달성" / "주간 미션 달성").
	var complete_titles: Dictionary = {}
	for counted: int in anchors:
		var mission: Dictionary = missions.get(int(anchors[counted]),{})
		if not str(mission.get("title","")).is_empty(): complete_titles[str(mission.title)] = int(anchors[counted])
	var entries: Dictionary = {}
	for row: Dictionary in tables.get("ToDoList",[]):
		var id: int = int(row.ID)
		var reset: int = int(row.get("ToDoListResetType",0))
		var type_id: int = int(row.get("ToDoListType",0))
		var entry: Dictionary = {"id":id,"type":type_id,"type_name":type_names.get(type_id,""),"category":int(row.get("ToDoListUICategory",0)),"sub":int(row.get("ToDoListUISubCategory",0)),"sub_name":subs.get(int(row.get("ToDoListUISubCategory",0)),""),"target_type":int(row.get("ToDoListTargetType",0)),"value":int(row.get("Value",0)),"count":int(row.get("Count",0)),"add_level":int(row.get("AddLevel",0)),"remove_level":int(row.get("RemoveLevel",0)),"reset":"daily" if reset == 2 else ("weekly" if reset == 12 else ""),"server_limit":int(row.get("ServerLimitsetID",0)),"text":str(desc.get(int(row.get("DescID",0)),{}).get("Description","")).strip_edges(),"is_event":bool(row.get("IsEvent",false)),"priority":int(row.get("Priority",0)),"weekly_open_group":int(row.get("WeeklyOpenTImeGroupID",0)),"shortcut_type":int(row.get("ShortcutType",0)),"start":date_unix(dates.get(int(row.get("StartDateTimeID",0)),{})),"end":date_unix(dates.get(int(row.get("EndDateTimeID",0)),{})),"reasons":[]}
		if entry.reset.is_empty(): entry.reasons.append("reset_type_unknown")
		if entry.start < 0 or entry.end < 0: entry.reasons.append("date_missing")
		entry["server_allowed"] = entry.server_limit == 0 or allowed_limits.has(entry.server_limit)
		# Progress source: only links the tables themselves name.
		var link: Dictionary = {}
		if entry.type_name in ["DailyMission","WeeklyMission"] and complete_titles.has(entry.text):
			link = {"kind":"routine_complete","routine_id":int(complete_titles[entry.text])}
		elif entry.type_name == "Quest" and entry.target_type == 2 and entry.value > 0:
			link = {"kind":"quest","quest_id":entry.value}
		entry["link"] = link
		entries[id] = entry
	var recommend: Array = []
	for row: Dictionary in tables.get("TodoListRecommend",[]):
		if entries.has(int(row.get("ToDoListID",0))): recommend.append({"id":int(row.get("ID",0)),"todo_id":int(row.ToDoListID),"add_level":int(row.get("AddLevel",0)),"remove_level":int(row.get("RemoveLevel",0))})
	return {"ok":true,"entries":entries,"categories":categories,"recommend":recommend,"limit":int(limit)}

## Level window of the original rows: AddLevel <= level and (RemoveLevel 0 or
## level < RemoveLevel).
static func level_open(add_level: int, remove_level: int, level: int) -> bool:
	return level >= add_level and (remove_level <= 0 or level < remove_level)
