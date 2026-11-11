extends RefCounted
## Original 523 domination stone (지배석) rules, read from the verified
## original definition archive (current523_definition_rows) and nothing else:
##  - DominationStoneGroup / ItemClass: the 15 stone kinds and their 90 item
##    classes (each kind in grades 3/4/5, a normal and a "[디펜스]" class);
##  - DominationStoneSet / SetGroup / SetBonus (+ Bonus, BonusType,
##    DescData_Korean) and UIDominationStoneSet: the set ("권능") of each kind;
##  - DominationStoneMergeInput / MergeOutputGrade / MergeOutputGroup and
##    UIDominationStoneMergeDivinationProb: merging (합성);
##  - DominationStoneTower / Floor / QuestGroup / Quest / QuestRerollCost
##    (+ QuestView titles, UITextData_Korean tower names): the weekly tower quests.
## The original client help (HelpBox_DominationStone) states the rules the
## tables leave implicit and that this module relies on: three slots unlocked
## at levels 68/80/92, a set needs three stones of the same kind, merging
## needs at least three registered stones, and one quest per week is chosen.
## Numbers stay exactly as read; build() is pure so it can be tested.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const TABLES: Array[String] = ["DominationStoneGroup","DominationStoneItemClass","DominationStoneMergeInput","DominationStoneMergeOutputGrade","DominationStoneMergeOutputGroup","DominationStoneQuest","DominationStoneQuestGroup","DominationStoneQuestRerollCost","DominationStoneSet","DominationStoneSetBonus","DominationStoneSetGroup","DominationStoneTower","DominationStoneFloor","DominationStoneConstant","UIDominationStoneMergeDivinationProb","UIDominationStoneSet"]
## Slot unlock levels of the original help text (HelpBox_DominationStone
## Panel_1: "지배석 슬롯은 68레벨, 80레벨, 92레벨에 해금 됩니다.").
const SLOT_LEVELS: Array[int] = [68,80,92]
## Original help (Panel_3): "최소 3개의 슬롯에 아이템이 등록되어 있어야 합니다";
## DominationStone_FusionBox has five original input slots.
const MERGE_MIN: int = 3
const MERGE_MAX: int = 5
## MergeOutputGroup.ProbabilityType: 3 = the kind distribution (sums to one
## million over all kinds); 23 = the chance the result keeps the registered
## kind when every slot holds the same kind and grade (help Panel_4).
const GROUP_BASE_TYPE: int = 3
const GROUP_SAME_TYPE: int = 23
const PROBABILITY_SCALE: int = 1000000
## Currency IDs of DominationStoneQuestRerollCost (Currency table: 1 Adena, 4 Gem).
const CURRENCY_NAMES: Dictionary = {1:"아데나",4:"다이아"}
const GRADE_NAMES: Dictionary = {3:"희귀",4:"영웅",5:"전설"}

static var _cache: Dictionary = {}
static var _cache_key: String = ""

static func _int(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value))

static func _fail(code: String, detail: String = "") -> Dictionary:
	return {"ok":false,"code":code,"problem":detail if not detail.is_empty() else code}

static func reset() -> void:
	_cache = {}
	_cache_key = ""

## The verified contract, or {ok:false, problem} (no original archive, or a
## table that does not have the expected shape). Cached per archive identity.
static func load_contract() -> Dictionary:
	var key: String = SOURCE.verified_key()
	if SOURCE.not_installed(): return _fail("source_not_installed","원본523 정의 ZIP이 설치되지 않아 지배석 규칙을 읽을 수 없습니다.")
	key = SOURCE.verified_key()
	if key.is_empty(): return _fail("source_unavailable",SOURCE.problem())
	if _cache_key == key and not _cache.is_empty(): return _cache
	var tables: Dictionary = {}
	for table: String in TABLES:
		var rows: Array[Dictionary] = SOURCE.rows(table)
		if rows.is_empty(): return _fail("table_missing","원본 지배석 표가 없습니다: "+table)
		tables[table] = rows
	# Joined original rows, read only for the IDs the tables name.
	var item_ids: Dictionary = {}
	for row: Dictionary in tables.DominationStoneItemClass: item_ids[int(row.get("ItemClassID",0))] = true
	tables["ItemClass"] = SOURCE.rows_matching("ItemClass","ID",item_ids)
	var bonus_ids: Dictionary = {}
	for row: Dictionary in tables.DominationStoneSetBonus: bonus_ids[int(row.get("BonusID",0))] = true
	var bonuses: Array[Dictionary] = SOURCE.rows_matching("Bonus","ID",bonus_ids)
	tables["Bonus"] = bonuses
	var type_ids: Dictionary = {}
	for row: Dictionary in bonuses: type_ids[int(row.get("BonusTypeID",0))] = true
	tables["BonusType"] = SOURCE.rows_matching("BonusType","ID",type_ids)
	var invoke_ids: Dictionary = {}
	for row: Dictionary in bonuses:
		if int(row.get("BonusApplicationTypeID",0)) == 10: invoke_ids[int(row.get("BonusApplicationTargetID",0))] = true
	tables["InvokeOption"] = SOURCE.rows_matching("InvokeOption","ID",invoke_ids) if not invoke_ids.is_empty() else []
	var quest_ids: Dictionary = {}
	for row: Dictionary in tables.DominationStoneQuest: quest_ids[int(row.get("QuestID",0))] = true
	tables["QuestView"] = SOURCE.rows_matching("QuestView","ID",quest_ids)
	# Goals and rewards of those quests (shown; progress is not connected).
	tables["QuestGoal"] = SOURCE.rows_matching("QuestGoal","QuestID",quest_ids)
	tables["QuestReward"] = SOURCE.rows_matching("QuestReward","QuestID",quest_ids)
	var goal_ids: Dictionary = {}
	for row: Dictionary in tables.QuestGoal: goal_ids[int(row.get("GoalID",0))] = true
	tables["Goal"] = SOURCE.rows_matching("Goal","ID",goal_ids)
	var reward_ids: Dictionary = {}
	for row: Dictionary in tables.QuestReward: reward_ids[int(row.get("RewardID",0))] = true
	tables["Reward"] = SOURCE.rows_matching("Reward","ID",reward_ids)
	var desc_ids: Dictionary = {}
	for row: Dictionary in tables.Goal: desc_ids[int(row.get("DescID",0))] = true
	for row: Dictionary in tables.QuestView:
		for field: String in ["TitleDescID","QuestLevelDescID"]: desc_ids[int(row.get(field,0))] = true
	for row: Dictionary in tables.DominationStoneSet: desc_ids[int(row.get("NameID",0))] = true
	for row: Dictionary in tables.UIDominationStoneSet: desc_ids[int(row.get("DescID",0))] = true
	for row: Dictionary in bonuses:
		if int(row.get("BonusApplicationTypeID",0)) == 0: desc_ids[int(row.get("Value",0))] = true
	tables["DescData_Korean"] = SOURCE.rows_matching("DescData_Korean","ID",desc_ids)
	var text_ids: Dictionary = {}
	for row: Dictionary in tables.DominationStoneTower: text_ids[int(row.get("NameID",0))] = true
	tables["UITextData_Korean"] = SOURCE.rows_matching("UITextData_Korean","ID",text_ids)
	var built: Dictionary = build(tables)
	if built.get("ok",false):
		_cache = built
		_cache_key = key
	return built

## Pure contract from original rows ({table: Array[row]}).
static func build(tables: Dictionary) -> Dictionary:
	var desc: Dictionary = {}
	for row: Dictionary in tables.get("DescData_Korean",[]): desc[int(row.get("ID",0))] = str(row.get("Description",""))
	var groups: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneGroup",[]):
		if not _int(row.get("ID")) or not _int(row.get("TowerID")) or not _int(row.get("FloorRank")): return _fail("group_shape")
		groups[int(row.ID)] = {"id":int(row.ID),"name":str(row.get("Name","")),"tower_contents_id":int(row.TowerID),"floor_rank":int(row.FloorRank)}
	var classes: Dictionary = {}
	for row: Dictionary in tables.get("ItemClass",[]): classes[int(row.get("ID",0))] = row
	var merge_price: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneMergeInput",[]):
		if not _int(row.get("ItemClassID")) or not _int(row.get("BasePrice")) or int(row.BasePrice) <= 0: return _fail("merge_input_shape")
		merge_price[int(row.ItemClassID)] = int(row.BasePrice)
	var items: Dictionary = {}
	var output_item: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneItemClass",[]):
		var id: int = int(row.get("ItemClassID",0))
		var group: int = int(row.get("DominationStoneGroupID",0))
		if not groups.has(group) or not classes.has(id): return _fail("item_class_join","원본 지배석 아이템 연결이 없습니다: %d" % id)
		var item: Dictionary = classes[id]
		if not _int(item.get("GradeID")) or item.get("TestItem") != false: return _fail("item_class_shape","원본 지배석 아이템 정의가 다릅니다: %d" % id)
		var grade: int = int(item.GradeID)
		items[id] = {"id":id,"group":group,"grade":grade,"name":str(item.get("Name","")),"merge_price":int(merge_price.get(id,-1))}
		if merge_price.has(id):
			var key: String = "%d:%d" % [group,grade]
			if output_item.has(key): return _fail("merge_output_ambiguous","합성 결과 아이템이 하나로 정해지지 않습니다: "+key)
			output_item[key] = id
	for id: int in merge_price:
		if not items.has(id): return _fail("merge_input_unknown")
	var bands: Array[Dictionary] = []
	var band_index: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneMergeOutputGrade",[]):
		for field: String in ["GradeID","PriceLow","PriceHigh","Probability"]:
			if not _int(row.get(field)): return _fail("merge_grade_shape")
		var key: String = "%d:%d" % [int(row.PriceLow),int(row.PriceHigh)]
		if not band_index.has(key):
			band_index[key] = bands.size()
			bands.append({"low":int(row.PriceLow),"high":int(row.PriceHigh),"grades":[]})
		(bands[band_index[key]].grades as Array).append([int(row.GradeID),int(row.Probability)])
	for band: Dictionary in bands:
		var total: int = 0
		for pair: Array in band.grades: total += int(pair[1])
		if total != PROBABILITY_SCALE: return _fail("merge_grade_sum","합성 등급 확률 합이 100%%가 아닙니다: %d~%d" % [int(band.low),int(band.high)])
	var base_groups: Array = []
	var same_group: Dictionary = {}
	var base_total: int = 0
	for row: Dictionary in tables.get("DominationStoneMergeOutputGroup",[]):
		if not _int(row.get("DominationStoneGroupID")) or not _int(row.get("ProbabilityType")) or not _int(row.get("Probability")): return _fail("merge_group_shape")
		if not groups.has(int(row.DominationStoneGroupID)): return _fail("merge_group_unknown")
		match int(row.ProbabilityType):
			GROUP_BASE_TYPE:
				base_groups.append([int(row.DominationStoneGroupID),int(row.Probability)])
				base_total += int(row.Probability)
			GROUP_SAME_TYPE: same_group[int(row.DominationStoneGroupID)] = int(row.Probability)
			_: return _fail("merge_group_type","합성 종류 확률 유형을 알 수 없습니다: %d" % int(row.ProbabilityType))
	if base_total != PROBABILITY_SCALE: return _fail("merge_group_sum","합성 종류 확률 합이 100%가 아닙니다")
	var divination: Dictionary = {}
	for row: Dictionary in tables.get("UIDominationStoneMergeDivinationProb",[]):
		var key: String = "%d:%d" % [int(row.get("ResultGrade",0)),int(row.get("MinInputGrade",0))]
		if not divination.has(key): divination[key] = []
		(divination[key] as Array).append([int(row.get("DivinationGrade",0)),int(row.get("Probability",0))])
	# Sets.
	var bonus_rows: Dictionary = {}
	for row: Dictionary in tables.get("Bonus",[]): bonus_rows[int(row.get("ID",0))] = row
	var bonus_types: Dictionary = {}
	for row: Dictionary in tables.get("BonusType",[]): bonus_types[int(row.get("ID",0))] = row
	var invokes: Dictionary = {}
	for row: Dictionary in tables.get("InvokeOption",[]): invokes[int(row.get("ID",0))] = row
	var sets: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneSet",[]):
		var name: String = str(desc.get(int(row.get("NameID",0)),""))
		sets[int(row.get("ID",0))] = {"id":int(row.get("ID",0)),"name":str(row.get("Name","")),"title":name,"groups":[],"bonuses":{},"desc":{}}
	var set_of_group: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneSetGroup",[]):
		var set_id: int = int(row.get("DominationStoneSetID",0))
		var group: int = int(row.get("DominationStoneGroupID",0))
		if not sets.has(set_id) or not groups.has(group): return _fail("set_group_join")
		(sets[set_id].groups as Array).append(group)
		if set_of_group.has(group) and int(set_of_group[group]) != set_id: return _fail("set_group_ambiguous")
		set_of_group[group] = set_id
	var bonus_list: Array = tables.get("DominationStoneSetBonus",[]).duplicate()
	bonus_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("Order",0)) < int(b.get("Order",0)))
	for row: Dictionary in bonus_list:
		var set_id: int = int(row.get("DominationStoneSetID",0))
		var bonus: Dictionary = bonus_rows.get(int(row.get("BonusID",0)),{})
		if not sets.has(set_id) or bonus.is_empty(): return _fail("set_bonus_join","원본 세트 보너스 연결이 없습니다: %d" % int(row.get("BonusID",0)))
		var type_name: String = str(bonus_types.get(int(bonus.get("BonusTypeID",0)),{}).get("Name",""))
		var entry: Dictionary = {"order":int(row.get("Order",0)),"bonus_id":int(bonus.get("ID",0)),"type":type_name,"value":int(bonus.get("Value",0)),"application":int(bonus.get("BonusApplicationTypeID",0)),"target":int(bonus.get("BonusApplicationTargetID",0))}
		match type_name:
			"FixedDesc": entry["text"] = str(desc.get(int(bonus.get("Value",0)),""))
			"InvokeOption":
				entry["probability_raw"] = int(bonus.get("Value",0))
				var option: Dictionary = invokes.get(int(bonus.get("BonusApplicationTargetID",0)),{})
				entry["spell_id"] = int(option.get("Param1",0))
				entry["invoke_type"] = int(option.get("InvokeOptionTypeID",0))
		var grade: int = int(row.get("GradeID",0))
		if not (sets[set_id].bonuses as Dictionary).has(grade): sets[set_id].bonuses[grade] = []
		(sets[set_id].bonuses[grade] as Array).append(entry)
	for row: Dictionary in tables.get("UIDominationStoneSet",[]):
		var set_id: int = int(row.get("DominationStoneSetID",0))
		if sets.has(set_id): sets[set_id].desc[int(row.get("GradeID",0))] = str(desc.get(int(row.get("DescID",0)),""))
	# Towers, floors and weekly quests.
	var ui_text: Dictionary = {}
	for row: Dictionary in tables.get("UITextData_Korean",[]): ui_text[int(row.get("ID",0))] = str(row.get("Description",""))
	var towers: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneTower",[]):
		towers[int(row.get("ID",0))] = {"id":int(row.get("ID",0)),"contents_id":int(row.get("ContentsControlID",0)),"priority":int(row.get("Priority",0)),"name":str(ui_text.get(int(row.get("NameID",0)),""))}
	var floors: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneFloor",[]):
		if not towers.has(int(row.get("TowerID",0))): return _fail("floor_tower_join")
		floors[int(row.get("ID",0))] = {"id":int(row.get("ID",0)),"tower":int(row.TowerID),"floor":int(row.get("Floor",0)),"slots":{}}
	var quest_views: Dictionary = {}
	for row: Dictionary in tables.get("QuestView",[]): quest_views[int(row.get("ID",0))] = row
	var goal_rows: Dictionary = {}
	for row: Dictionary in tables.get("Goal",[]): goal_rows[int(row.get("ID",0))] = row
	var goals: Dictionary = {}
	for row: Dictionary in tables.get("QuestGoal",[]):
		var goal: Dictionary = goal_rows.get(int(row.get("GoalID",0)),{})
		if goal.is_empty(): continue
		if not goals.has(int(row.get("QuestID",0))): goals[int(row.get("QuestID",0))] = []
		(goals[int(row.get("QuestID",0))] as Array).append({"text":str(desc.get(int(goal.get("DescID",0)),"")),"amount":int(goal.get("Amount",0)),"goal_type_id":int(goal.get("GoalTypeID",0))})
	var reward_rows: Dictionary = {}
	for row: Dictionary in tables.get("Reward",[]): reward_rows[int(row.get("ID",0))] = row
	var rewards: Dictionary = {}
	for row: Dictionary in tables.get("QuestReward",[]):
		var reward: Dictionary = reward_rows.get(int(row.get("RewardID",0)),{})
		# RewardType 2 = Item (RewardType table).
		if reward.is_empty() or int(reward.get("RewardTypeID",0)) != 2: continue
		if not rewards.has(int(row.get("QuestID",0))): rewards[int(row.get("QuestID",0))] = []
		(rewards[int(row.get("QuestID",0))] as Array).append({"item_class_id":int(reward.get("RewardClassID",0)),"amount":int(reward.get("Amount",0))})
	var quest_groups: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneQuestGroup",[]):
		var floor_id: int = int(row.get("FloorID",0))
		if not floors.has(floor_id): return _fail("quest_group_floor_join")
		var id: int = int(row.get("ID",0))
		quest_groups[id] = {"id":id,"floor":floor_id,"slot":int(row.get("SlotIndex",0)),"quests":[]}
		floors[floor_id].slots[int(row.get("SlotIndex",0))] = id
	for row: Dictionary in tables.get("DominationStoneQuest",[]):
		var group_id: int = int(row.get("GroupID",0))
		if not quest_groups.has(group_id) or not _int(row.get("Probability")) or not row.get("IsDefault") is bool: return _fail("quest_shape")
		var view: Dictionary = quest_views.get(int(row.get("QuestID",0)),{})
		(quest_groups[group_id].quests as Array).append({"quest_id":int(row.get("QuestID",0)),"probability_raw":int(row.Probability),"default":bool(row.IsDefault),"title":str(desc.get(int(view.get("TitleDescID",0)),"")),"level_text":str(desc.get(int(view.get("QuestLevelDescID",0)),"")),"type_id":int(view.get("TypeID",0)),"goals":goals.get(int(row.get("QuestID",0)),[]),"rewards":rewards.get(int(row.get("QuestID",0)),[])})
	for id: int in quest_groups:
		var defaults: int = 0
		for quest: Dictionary in quest_groups[id].quests: defaults += 1 if quest.default else 0
		if defaults != 1: return _fail("quest_default","퀘스트 그룹의 기본 퀘스트가 하나가 아닙니다: %d" % id)
	var reroll: Array = []
	for row: Dictionary in tables.get("DominationStoneQuestRerollCost",[]):
		reroll.append({"count":int(row.get("Count",0)),"currency_id":int(row.get("CurrencyID",0)),"amount":int(row.get("Amount",0))})
	reroll.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.count) < int(b.count))
	for index: int in range(reroll.size()):
		if int(reroll[index].count) != index+1 or not CURRENCY_NAMES.has(int(reroll[index].currency_id)): return _fail("reroll_shape")
	var constants: Dictionary = {}
	for row: Dictionary in tables.get("DominationStoneConstant",[]): constants[int(row.get("ConstantTypeID",0))] = int(row.get("Value",0))
	return {"ok":true,"groups":groups,"items":items,"output_item":output_item,"bands":bands,"base_groups":base_groups,"same_group":same_group,"divination":divination,"sets":sets,"set_of_group":set_of_group,"towers":towers,"floors":floors,"quest_groups":quest_groups,"reroll":reroll,"constants":constants}

## Grade distribution of a merge whose registered stones total `price`.
static func grade_band(contract: Dictionary, price: int) -> Dictionary:
	for band: Dictionary in contract.get("bands",[]):
		if price >= int(band.low) and price <= int(band.high): return band
	return {}

## Weighted pick over [[value, weight]] with one integer roll in [0, total).
static func pick(pairs: Array, roll: int) -> int:
	var cursor: int = 0
	for pair: Array in pairs:
		cursor += int(pair[1])
		if roll < cursor: return int(pair[0])
	return int(pairs[-1][0]) if not pairs.is_empty() else -1

static func pair_total(pairs: Array) -> int:
	var total: int = 0
	for pair: Array in pairs: total += int(pair[1])
	return total
