extends RefCounted
## 요정 숲 방어전 (ElfForestDefense*) — the original 523 table model.
## ElfForestDefenseGrade (GradeNo 0..5) -> SpecialDungeon -> LandTeleport ->
## LandTeleportTerritories -> Territories/Land (the "[방어전][N승]" Lands);
## ElfForestDefenseBlessing(+Type) the four team blessings;
## ElfForestDefenseRewardGroup(+Set) WinNo -> QuestID -> QuestGoal/Goal
## (GoalType ArenaWin) + QuestReward/Reward. Win, team and grade-up rules are
## not in the tables; the user's own win rule (2026-11-13) lives in
## content523.gd (docs/escaros_elfforest_territory523_missing_rules.md).
const ESCAROS = preload("res://scripts/content523/escaros523.gd")

static func _i(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT,TYPE_FLOAT] else 0

static func build(src: Variant) -> Dictionary:
	var data: Dictionary = {"ok":false,"problem":"","grades":[],"blessings":[],"wins":[],"special_type":"","counts":{}}
	for row: Dictionary in src.rows("SpecialDungeonType"):
		if str(row.get("Name",""))=="ElfForestDefense": data.special_type = str(row.Name); data["special_type_id"] = _i(row.ID)
	for row: Dictionary in src.rows("ElfForestDefenseGrade"):
		var dungeon: Dictionary = ESCAROS._one(src,"SpecialDungeon",_i(row.get("SpecialDungeonID")))
		var route: Dictionary = ESCAROS.teleport(src,_i(dungeon.get("LandTeleportID")))
		var land: Dictionary = ESCAROS._one(src,"Land",int(route.get("land_id",0)))
		data.grades.append({"id":_i(row.ID),"grade_no":_i(row.get("GradeNo")),"name":str(row.get("Name","")),
			"title":ESCAROS._text(src,_i(row.get("GradeNameID"))),"desc":ESCAROS._text(src,_i(row.get("DescID"))),
			"special_dungeon":_i(dungeon.get("ID")),"special_type":_i(dungeon.get("SpecialDungeonTypeID")),"route":route,
			"ideal_players":_i(land.get("IdealNumberOfPlayer")),"channel_type":_i(land.get("LandChannelTypeID"))})
	data.grades.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return int(a.grade_no)<int(b.grade_no))
	var types: Dictionary = {}
	for row: Dictionary in src.rows("ElfForestDefenseBlessingType"): types[_i(row.ID)] = {"name":str(row.get("Name","")),"title":ESCAROS._text(src,_i(row.get("DescID")))}
	for row: Dictionary in src.rows("ElfForestDefenseBlessing"):
		var effect_id: int = _i(row.get("StatusEffectID"))
		var attrs: Array = []
		for attr: Dictionary in src.related("StatusEffectAttr","StatusEffectID",effect_id): attrs.append({"type":_i(attr.get("StatusEffectAttrType")),"value":_i(attr.get("Value"))})
		data.blessings.append({"id":_i(row.ID),"type":_i(row.get("BlessingType")),"name":str(types.get(_i(row.get("BlessingType")),{}).get("name","")),
			"title":str(types.get(_i(row.get("BlessingType")),{}).get("title","")),"advantage":_i(row.get("AdvantageBlessingType")),
			"advantage_title":str(types.get(_i(row.get("AdvantageBlessingType")),{}).get("title","")),
			"status_effect":effect_id,"status_attrs":attrs,"select_text":ESCAROS._text(src,_i(row.get("SelectDescID"))),"random_text":ESCAROS._text(src,_i(row.get("RandomDescID")))})
	data.blessings.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return int(a.id)<int(b.id))
	var sets: Dictionary = {}
	for row: Dictionary in src.rows("ElfForestDefenseRewardGroupSet"): sets[_i(row.ID)] = _i(row.get("WinNo"))
	var reward_types: Dictionary = {}
	for row: Dictionary in src.rows("RewardType"): reward_types[_i(row.ID)] = str(row.get("Name",""))
	var goal_types: Dictionary = {}
	for row: Dictionary in src.rows("GoalType"): goal_types[_i(row.ID)] = str(row.get("Name",""))
	for row: Dictionary in src.rows("ElfForestDefenseRewardGroup"):
		var quest: int = _i(row.get("QuestID"))
		var goals: Array = []
		for link: Dictionary in src.related("QuestGoal","QuestID",quest):
			var goal: Dictionary = ESCAROS._one(src,"Goal",_i(link.get("GoalID")))
			goals.append({"type":str(goal_types.get(_i(goal.get("GoalTypeID")),"")),"class":_i(goal.get("GoalClassID")),"amount":_i(goal.get("Amount")),"text":ESCAROS._text(src,_i(goal.get("DescID")))})
		var rewards: Array = []
		for link: Dictionary in src.related("QuestReward","QuestID",quest):
			var reward: Dictionary = ESCAROS._one(src,"Reward",_i(link.get("RewardID")))
			rewards.append({"id":_i(reward.get("ID")),"type":str(reward_types.get(_i(reward.get("RewardTypeID")),"")),"class_id":_i(reward.get("RewardClassID")),"amount":_i(reward.get("Amount")),"bless":_i(reward.get("ItemBlessCodeID"))})
		data.wins.append({"win_no":int(sets.get(_i(row.get("RewardGroupSetID")),0)),"quest":quest,"goals":goals,"rewards":rewards})
	data.wins.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return int(a.win_no)<int(b.win_no))
	data.counts = {"grades":data.grades.size(),"blessings":data.blessings.size(),"wins":data.wins.size()}
	if data.grades.is_empty() or int(data.grades[0].route.get("land_id",0))==0:
		data.problem = "요정 숲 방어전 원본 표(ElfForestDefenseGrade/SpecialDungeon)가 없습니다"
		return data
	data.ok = true
	return data
