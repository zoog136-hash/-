extends RefCounted
## 영지 퀘스트 (TerritoriesQuest*) — the original 523 table model.
## TerritoriesQuest: the quest of one Territories box (TerritoriesID), its
## TimeoutSecond and AutoComplete; TerritoriesQuestGoal -> Goal (+GoalType);
## TerritoriesQuestReward / TerritoriesQuestFailReward -> Reward (+RewardType).
## The CompetitionDungeonLand row of the quest Land names the contest it
## belongs to. Only goals with a local owner can be played: ItemCollect (the
## possessed amount of Goal.GoalClassID). Last-survivor (CanRank) and player
## kill (PK) goals need other players and stay unplayable.
const ESCAROS = preload("res://scripts/content523/escaros523.gd")
const SUPPORTED_GOALS := ["ItemCollect"]

static func _i(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT,TYPE_FLOAT] else 0

static func _rewards(src: Variant, table: String, quest_id: int, reward_types: Dictionary) -> Array:
	var out: Array = []
	for link: Dictionary in src.related(table,"TerritoriesQuestID",quest_id):
		var reward: Dictionary = ESCAROS._one(src,"Reward",_i(link.get("RewardID")))
		out.append({"id":_i(reward.get("ID")),"type":str(reward_types.get(_i(reward.get("RewardTypeID")),"")),"class_id":_i(reward.get("RewardClassID")),
			"amount":_i(reward.get("Amount")),"bless":_i(reward.get("ItemBlessCodeID")),"ranking":_i(reward.get("Ranking")),"server_limit":_i(link.get("ServerLimitSetID",link.get("ServerLimitsetID",0)))})
	return out

static func build(src: Variant) -> Dictionary:
	var data: Dictionary = {"ok":false,"problem":"","quests":{},"order":[],"counts":{}}
	var goal_types: Dictionary = {}
	for row: Dictionary in src.rows("GoalType"): goal_types[_i(row.ID)] = str(row.get("Name",""))
	var reward_types: Dictionary = {}
	for row: Dictionary in src.rows("RewardType"): reward_types[_i(row.ID)] = str(row.get("Name",""))
	var supported: int = 0
	for row: Dictionary in src.rows("TerritoriesQuest"):
		var id: int = _i(row.ID)
		var territory: Dictionary = ESCAROS._one(src,"Territories",_i(row.get("TerritoriesID")))
		var land_id: int = _i(territory.get("LandID"))
		var land: Dictionary = ESCAROS._one(src,"Land",land_id)
		var contests: Array = []
		for link: Dictionary in src.related("CompetitionDungeonLand","LandID",land_id): contests.append(_i(link.get("CompetitionDungeonID")))
		var goals: Array = []
		for link: Dictionary in src.related("TerritoriesQuestGoal","TerritoriesQuestID",id):
			var goal: Dictionary = ESCAROS._one(src,"Goal",_i(link.get("GoalID")))
			var item: Dictionary = ESCAROS._one(src,"ItemClass",_i(goal.get("GoalClassID")))
			goals.append({"id":_i(goal.get("ID")),"type":str(goal_types.get(_i(goal.get("GoalTypeID")),"")),"class_id":_i(goal.get("GoalClassID")),
				"amount":_i(goal.get("Amount")),"text":ESCAROS._text(src,_i(goal.get("DescID"))),"item_name":ESCAROS._text(src,_i(item.get("DescID"))) if not item.is_empty() else ""})
		var rewards: Array = _rewards(src,"TerritoriesQuestReward",id,reward_types)
		var reasons: Array = []
		if territory.is_empty() or land_id==0: reasons.append("영지(Territories) 없음")
		if goals.is_empty(): reasons.append("목표(TerritoriesQuestGoal) 없음")
		for goal: Dictionary in goals:
			if not str(goal.type) in SUPPORTED_GOALS: reasons.append("목표 %s(%s)는 다른 플레이어가 필요합니다" % [str(goal.text),str(goal.type)])
		for reward: Dictionary in rewards:
			if int(reward.ranking)!=0: reasons.append("순위 보상(Reward.Ranking)은 다른 플레이어 순위가 필요합니다"); break
		var quest: Dictionary = {"id":id,"territory":territory.duplicate(true),"box":ESCAROS.box(territory),"land_id":land_id,"land_name":str(land.get("Name","")),
			"area":ESCAROS._text(src,_i(territory.get("DescID"))),"timeout":_i(row.get("TimeoutSecond")),"auto_complete":bool(row.get("AutoComplete",false)),
			"mail_from":_i(row.get("FromMailTextID")),"mail_subject":_i(row.get("SubjectMailTextID")),"goals":goals,"rewards":rewards,
			"fail_rewards":_rewards(src,"TerritoriesQuestFailReward",id,reward_types),"contests":contests,"reasons":reasons,"playable":reasons.is_empty()}
		data.quests[id] = quest
		data.order.append(id)
		if quest.playable: supported += 1
	data.order.sort()
	data.counts = {"quests":data.quests.size(),"playable":supported}
	if data.quests.is_empty():
		data.problem = "영지 퀘스트 원본 표(TerritoriesQuest)가 없습니다"
		return data
	data.ok = true
	return data

## The playable quest whose Territory box holds `cell` on `land_id`.
static func quest_at(data: Dictionary, land_id: int, cell: Array) -> Dictionary:
	for id: int in data.get("order",[]):
		var quest: Dictionary = data.quests[id]
		var b: Array = quest.box
		if quest.playable and int(quest.land_id)==land_id and int(cell[0])>=int(b[0]) and int(cell[0])<=int(b[2]) and int(cell[1])>=int(b[1]) and int(cell[1])<=int(b[3]): return quest
	return {}
