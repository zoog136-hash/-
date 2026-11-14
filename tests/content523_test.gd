extends SceneTree
## 에스카로스 · 요정 숲 방어전 · 영지 퀘스트 (scripts/content523). Synthetic
## rows always run (floats, as the archive delivers numbers): Escaros
## CompetitionDungeon -> LandTeleport (cost, MinLevel) -> village Territory,
## teleporter EarthObjectSpawn + LandTeleportID unit + Range attribute, zones,
## landmark group Prob draw and Einasad reward, artifact ExperienceAddition
## through UIUnit; elf forest grade -> SpecialDungeon -> Land, blessings,
## WinNo -> ArenaWin quest rewards; territory quest ItemCollect playable,
## CanRank/PK not, rank rewards refused; save validator and the runtime
## (landmark pay once per day, touchdown count, quest start/timeout/complete).
## Actual Main gets the world owner, the menu window and the save key. With
## the original ZIP installed the real tables are counted too.
const ESC = preload("res://scripts/content523/escaros523.gd")
const ELF = preload("res://scripts/content523/elfforest523.gd")
const TQ = preload("res://scripts/content523/territory_quest523.gd")
const CONTENT = preload("res://scripts/content523/content523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CONTENT523_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

class Rows extends RefCounted:
	var tables: Dictionary = {}
	func rows(table: String) -> Array: return tables.get(table,[])
	func related(table: String, field: String, id: int) -> Array:
		var out: Array = []
		for row: Dictionary in tables.get(table,[]):
			if typeof(row.get(field)) in [TYPE_INT,TYPE_FLOAT] and int(row[field])==id: out.append(row)
		return out

func synthetic() -> Rows:
	var src := Rows.new()
	src.tables = {
		"EscarosConstant":[{"ID":4.0,"Name":"ArtifactUseCoolTime","Value":5000.0},{"ID":54.0,"Name":"EscarosDungeonID","Value":314.0},{"ID":64.0,"Name":"VillageTerritoryID","Value":201094.0}],
		"CompetitionDungeon":[{"ID":314.0,"LandTeleportId":14074.0,"HomeTerritoriesID":201094.0,"LandTimeLimitGroupId":31594.0,"HotWeeklyOpenTimeGroupId":1074.0,"WeeklyOpenTimeGroupId":0.0,"DungeonState":4.0}],
		"CompetitionDungeonView":[{"ID":314.0,"TitleDescId":1.0}],
		"CompetitionDungeonLand":[{"ID":1314.0,"CompetitionDungeonID":314.0,"LandID":47954.0,"IsBossLand":false},{"ID":1324.0,"CompetitionDungeonID":314.0,"LandID":47964.0,"IsBossLand":false},
			{"ID":531.0,"CompetitionDungeonID":121.0,"LandID":44631.0,"IsBossLand":false}],
		"LandTimeLimitGroup":[{"ID":31594.0,"TimeLimit":25200.0,"MaxRechargeTime":50400.0}],
		"DescData_Korean":[{"ID":1.0,"Description":"에스카로스"},{"ID":2.0,"Description":"[에스카로스]^영광의 협곡 입장 텔레포터"},{"ID":3.0,"Description":"에스카로스"},{"ID":4.0,"Description":"침묵의 평원"},
			{"ID":5.0,"Description":"침묵의 칼날"},{"ID":6.0,"Description":"운디네"},{"ID":7.0,"Description":"이그니스"},{"ID":8.0,"Description":"팀 속성으로 '운디네' 가호가 적용됩니다."},
			{"ID":9.0,"Description":"고대 주화 수집"},{"ID":10.0,"Description":"최후의 1인으로 살아남기"},{"ID":11.0,"Description":"요정 숲 방어전 승리 1회"},{"ID":12.0,"Description":"[무너지는 섬] 고대 주화 (동)"}],
		"PrerequisiteType":[{"ID":1.0,"Name":"MinLevel"},{"ID":2.0,"Name":"MaxLevel"}],
		"Prerequisite":[{"ID":31034.0,"PrerequisiteTypeID":1.0,"Value":85.0},{"ID":51992.0,"PrerequisiteTypeID":1.0,"Value":80.0}],
		"LandTeleport":[{"ID":14074.0,"TeleportCost":100000.0,"CurrencyID":1.0},{"ID":14084.0,"TeleportCost":100000.0,"CurrencyID":1.0},{"ID":15722.0,"TeleportCost":10000.0,"CurrencyID":1.0},{"ID":15732.0,"TeleportCost":10000.0,"CurrencyID":1.0}],
		"LandTeleportPrerequisite":[{"LandTeleportID":14074.0,"PrerequisiteID":31034.0},{"LandTeleportID":14084.0,"PrerequisiteID":31034.0},{"LandTeleportID":15722.0,"PrerequisiteID":51992.0}],
		"LandTeleportTerritories":[{"ID":1.0,"LandTeleportID":14074.0,"TerritoryID":201094.0},{"ID":2.0,"LandTeleportID":14084.0,"TerritoryID":201104.0},{"ID":3.0,"LandTeleportID":15722.0,"TerritoryID":290172.0},{"ID":4.0,"LandTeleportID":15732.0,"TerritoryID":290392.0}],
		"Territories":[{"ID":201094.0,"LandID":47954.0,"StartX":32731.0,"StartY":32784.0,"EndX":32755.0,"EndY":32810.0},
			{"ID":201104.0,"LandID":47964.0,"StartX":32668.0,"StartY":32824.0,"EndX":32681.0,"EndY":32896.0},
			{"ID":30504.0,"LandID":47954.0,"StartX":32740.0,"StartY":32801.0,"EndX":32740.0,"EndY":32801.0},
			{"ID":201494.0,"LandID":47964.0,"StartX":32685.0,"StartY":32834.0,"EndX":32738.0,"EndY":32896.0,"DescID":0.0},
			{"ID":201234.0,"LandID":47954.0,"StartX":32747.0,"StartY":32791.0,"EndX":32747.0,"EndY":32791.0},
			{"ID":201244.0,"LandID":47964.0,"StartX":32700.0,"StartY":32850.0,"EndX":32700.0,"EndY":32850.0},
			{"ID":201254.0,"LandID":47964.0,"StartX":32710.0,"StartY":32860.0,"EndX":32710.0,"EndY":32860.0},
			{"ID":201174.0,"LandID":47964.0,"StartX":32895.0,"StartY":32864.0,"EndX":32895.0,"EndY":32864.0},
			{"ID":201124.0,"LandID":47964.0,"StartX":32887.0,"StartY":32856.0,"EndX":32904.0,"EndY":32870.0},
			{"ID":290172.0,"LandID":51122.0,"StartX":32760.0,"StartY":32945.0,"EndX":32976.0,"EndY":33018.0},
			{"ID":290392.0,"LandID":51132.0,"StartX":32760.0,"StartY":32945.0,"EndX":32976.0,"EndY":33018.0},
			{"ID":115431.0,"LandID":44631.0,"StartX":32448.0,"StartY":32832.0,"EndX":32831.0,"EndY":33215.0,"DescID":0.0},
			{"ID":115451.0,"LandID":44651.0,"StartX":32610.0,"StartY":32993.0,"EndX":32670.0,"EndY":33053.0,"DescID":0.0}],
		"Land":[{"ID":47954.0,"Name":"[에스카로스] 비탄의 동굴 (마을)","AssetPath":"13410/"},{"ID":47964.0,"Name":"[에스카로스] 에스카로스","AssetPath":"13411/"},
			{"ID":51122.0,"Name":"[방어전][0승] 듀펠게넌 잔당 토벌","IdealNumberOfPlayer":30.0,"LandChannelTypeID":1.0},{"ID":51132.0,"Name":"[방어전][1승] 듀펠게넌 잔당 토벌","IdealNumberOfPlayer":30.0},
			{"ID":44631.0,"Name":"[무너지는 섬] 1라운드 지역"},{"ID":44651.0,"Name":"[무너지는 섬] 3라운드 지역"}],
		"Unit":[{"ID":3.0,"Name":"Percentage"},{"ID":32.0,"Name":"LandTeleportID"},{"ID":25.0,"Name":"Value"}],
		"UIUnit":[{"ID":3.0,"UnitID":3.0,"Denominator":10000.0}],
		"EarthObjectAttributeType":[{"ID":15.0,"Name":"Range"},{"ID":134.0,"Name":"SpriteInvisible"}],
		"EarthObjectSpawn":[{"ID":30504.0,"EarthObjectClassID":5174.0,"TerritoriesID":30504.0,"ServerLimitSetID":0.0,"SpawnManually":false},
			{"ID":30505.0,"EarthObjectClassID":5174.0,"TerritoriesID":30504.0,"ServerLimitSetID":274.0,"SpawnManually":false}],
		"EarthObjectClass":[{"ID":5174.0,"Name":"[에스카로스] 영광의 협곡 입장 텔레포터","DescID":2.0}],
		"EarthObjectUnit":[{"ID":1.0,"EarthObjectClassID":5174.0,"UnitID":32.0,"Value":14084.0}],
		"EarthObjectAttribute":[{"ID":1.0,"EarthObjectClassID":5174.0,"EarthObjectAttributeTypeID":15.0,"Value":12.0}],
		"EscarosZone":[{"ID":14.0,"TerritoriesID":201494.0,"ZoneNameDescID":3.0,"SubZoneNameDescID":4.0,"NotiIntervalTime":15000.0}],
		"EscarosLandmarkGroup":[{"ID":4.0,"Name":"A"},{"ID":14.0,"Name":"B"}],
		"RewardType":[{"ID":2.0,"Name":"Item"},{"ID":5.0,"Name":"Einasad"}],
		"Reward":[{"ID":152974.0,"RewardTypeID":5.0,"RewardClassID":1859.0,"Amount":100.0,"ItemBlessCodeID":1.0,"Ranking":0.0},
			{"ID":79291.0,"RewardTypeID":2.0,"RewardClassID":126642.0,"Amount":1.0,"ItemBlessCodeID":1.0,"Ranking":0.0},
			{"ID":79311.0,"RewardTypeID":2.0,"RewardClassID":152493.0,"Amount":1.0,"ItemBlessCodeID":1.0,"Ranking":1.0},
			{"ID":419818.0,"RewardTypeID":2.0,"RewardClassID":113892.0,"Amount":100.0,"ItemBlessCodeID":1.0,"Ranking":0.0}],
		"EscarosLandmark":[{"ID":4.0,"Name":"진실의 석판","EscarosLandmarkGroupID":4.0,"Prob":100.0,"TerritoriesID":201234.0,"RewardID":152974.0,"EarthObjectClassID":5134.0,"StoryDescID":0.0},
			{"ID":14.0,"Name":"엘카덴","EscarosLandmarkGroupID":14.0,"Prob":50.0,"TerritoriesID":201244.0,"RewardID":152974.0,"EarthObjectClassID":5144.0,"StoryDescID":0.0},
			{"ID":24.0,"Name":"엔리쉬","EscarosLandmarkGroupID":14.0,"Prob":50.0,"TerritoriesID":201254.0,"RewardID":152974.0,"EarthObjectClassID":5184.0,"StoryDescID":0.0}],
		"BuffClass":[{"ID":65894.0,"Name":"[에스카로스] 아티팩트 1지역 버프 (침묵의 칼날)"}],
		"BonusType":[{"ID":8.0,"Name":"ExperienceAdditionPercent","UnitID":3.0}],
		"Bonus":[{"ID":1.0,"BonusTypeID":8.0,"Value":50000.0}],
		"BuffBonus":[{"ID":1.0,"BuffClassID":65894.0,"BonusID":1.0}],
		"EscarosArtifact":[{"ID":4.0,"Name":"BladeOfSilent","EarthObjectClassID":5084.0,"TerritoriesID":201174.0,"BuffClassID":65894.0,"ActivationRange":15.0,"Round":1.0,
			"TeleportTerritoriesID":201124.0,"BuffDuration":15.0,"DescID":5.0,"AreaDescID":4.0,"MaxRankerCount":500.0,"TouchdownDelaySec":10.0}],
		"EscarosArtifactRankReward":[{"ID":1.0,"EscarosArtifactID":4.0,"Rank":1.0,"RewardID":152984.0}],
		"SpecialDungeonType":[{"ID":12.0,"Name":"ElfForestDefense"}],
		"SpecialDungeon":[{"ID":342.0,"LandTeleportID":15722.0,"SpecialDungeonTypeID":12.0},{"ID":352.0,"LandTeleportID":15732.0,"SpecialDungeonTypeID":12.0}],
		"ElfForestDefenseGrade":[{"ID":12.0,"Name":"푸른 잎 전사","GradeNo":1.0,"SpecialDungeonID":352.0,"DescID":0.0,"GradeNameID":0.0},{"ID":2.0,"Name":"숲의 방문자","GradeNo":0.0,"SpecialDungeonID":342.0,"DescID":0.0,"GradeNameID":0.0}],
		"ElfForestDefenseBlessingType":[{"ID":2.0,"Name":"Water","DescID":6.0},{"ID":32.0,"Name":"Fire","DescID":7.0}],
		"ElfForestDefenseBlessing":[{"ID":2.0,"BlessingType":2.0,"AdvantageBlessingType":32.0,"StatusEffectID":4272.0,"SelectDescID":8.0,"RandomDescID":0.0}],
		"StatusEffectAttr":[{"ID":9572.0,"StatusEffectID":4272.0,"StatusEffectAttrType":178.0,"Value":312.0}],
		"ElfForestDefenseRewardGroupSet":[{"ID":2.0,"WinNo":1.0}],
		"ElfForestDefenseRewardGroup":[{"ID":102.0,"RewardGroupSetID":2.0,"QuestID":100308.0}],
		"GoalType":[{"ID":2.0,"Name":"ItemCollect"},{"ID":14.0,"Name":"PK"},{"ID":401.0,"Name":"CanRank"},{"ID":902.0,"Name":"ArenaWin"}],
		"Goal":[{"ID":119708.0,"GoalTypeID":902.0,"GoalClassID":12.0,"Amount":1.0,"DescID":11.0},{"ID":77701.0,"GoalTypeID":2.0,"GoalClassID":125911.0,"Amount":100.0,"DescID":9.0},
			{"ID":77721.0,"GoalTypeID":401.0,"GoalClassID":0.0,"Amount":1.0,"DescID":10.0}],
		"QuestGoal":[{"QuestID":100308.0,"GoalID":119708.0}],
		"QuestReward":[{"QuestID":100308.0,"RewardID":419818.0}],
		"ItemClass":[{"ID":125911.0,"Name":"[무너지는 섬] 고대 주화 (동)","DescID":12.0}],
		"TerritoriesQuest":[{"ID":1.0,"TerritoriesID":115431.0,"TimeoutSecond":600.0,"AutoComplete":false,"FromMailTextID":32.0,"SubjectMailTextID":10271.0},
			{"ID":21.0,"TerritoriesID":115451.0,"TimeoutSecond":600.0,"AutoComplete":false},{"ID":42.0,"TerritoriesID":0.0,"TimeoutSecond":0.0}],
		"TerritoriesQuestGoal":[{"TerritoriesQuestID":1.0,"GoalID":77701.0},{"TerritoriesQuestID":21.0,"GoalID":77721.0}],
		"TerritoriesQuestReward":[{"TerritoriesQuestID":1.0,"RewardID":79291.0,"ServerLimitSetID":0.0},{"TerritoriesQuestID":21.0,"RewardID":79311.0,"ServerLimitSetID":0.0}],
		"TerritoriesQuestFailReward":[]}
	return src

func models() -> Dictionary:
	var src: Rows = synthetic()
	var e: Dictionary = ESC.build(src)
	check(e.ok,"Escaros model: "+str(e.problem))
	check(int(e.dungeon.teleport.cost)==100000 and int(e.dungeon.teleport.min_level)==85 and int(e.dungeon.teleport.land_id)==47954 and e.dungeon.teleport.box==[32731,32784,32755,32810],"CompetitionDungeon 314 -> LandTeleport 14074: 100,000 adena, Lv85, village box")
	check(e.lands.map(func(l: Dictionary)->int: return int(l.id))==[47954,47964],"CompetitionDungeonLand: village + field")
	check(e.teleporters.size()==1 and int(e.teleporters[0].range)==12 and int(e.teleporters[0].route.land_id)==47964 and str(e.teleporters[0].name)=="영광의 협곡 입장 텔레포터","village teleporter: Range 12, LandTeleport 14084 -> field; server-limited copy skipped")
	check(e.zones.size()==1 and ESC.zone_at(e,47964,[32700,32850]).get("name","")=="에스카로스" and ESC.zone_at(e,47964,[32600,32850]).is_empty(),"EscarosZone box lookup")
	check(e.groups.keys().size()==2 and e.groups[14]==[14,24] and str(e.landmarks[4].reward.type)=="Einasad" and int(e.landmarks[4].reward.amount)==100,"landmark groups + Einasad 100 reward")
	var picks: Array = ESC.active_landmarks(e,100)
	check(picks.size()==2 and 4 in picks and (14 in picks or 24 in picks),"one landmark per group by Prob: "+str(picks))
	check(ESC.active_landmarks(e,100)==picks,"same period, same draw")
	var art: Dictionary = e.artifacts[0]
	check(is_equal_approx(float(art.effects[0].percent),5.0) and int(art.range)==15 and int(art.touchdown_delay_sec)==10 and int(art.buff_duration_raw)==15,"artifact: ExperienceAdditionPercent 50000/10000 = 5%, range 15, delay 10, raw duration 15")
	check(int(e.rank_rewards)==1,"rank rewards counted (not paid)")
	var f: Dictionary = ELF.build(src)
	check(f.ok,"elf model: "+str(f.problem))
	check(int(f.grades[0].grade_no)==0 and int(f.grades[0].route.land_id)==51122 and int(f.grades[0].route.cost)==10000 and int(f.grades[0].route.min_level)==80 and int(f.grades[0].ideal_players)==30,"grade 0 -> SpecialDungeon 342 -> Land 51122, 10,000 adena, Lv80, 30 players")
	check(str(f.blessings[0].title)=="운디네" and str(f.blessings[0].advantage_title)=="이그니스" and f.blessings[0].status_attrs.size()==1,"blessing Water over Fire, StatusEffectAttr kept")
	check(int(f.wins[0].win_no)==1 and str(f.wins[0].goals[0].type)=="ArenaWin" and int(f.wins[0].rewards[0].amount)==100,"WinNo 1 -> ArenaWin quest -> reward")
	var q: Dictionary = TQ.build(src)
	check(q.ok and q.counts.quests==3 and q.counts.playable==1,"territory quests: 3 rows, 1 playable")
	check(q.quests[1].playable and int(q.quests[1].goals[0].class_id)==125911 and int(q.quests[1].timeout)==600 and q.quests[1].contests==[121],"quest 1: ItemCollect 125911 x100 in 600 s, contest 121")
	check(not q.quests[21].playable and str(q.quests[21].reasons).contains("CanRank"),"last survivor quest not playable")
	check(not q.quests[42].playable,"quest without Territory not playable")
	check(int(TQ.quest_at(q,44631,[32500,32900]).get("id",0))==1 and TQ.quest_at(q,44631,[30000,30000]).is_empty(),"quest box lookup")
	evidence["synthetic"] = {"escaros":e.counts,"elf":f.counts,"tq":q.counts,"landmarks":picks}
	return {"escaros":e,"elf":f,"tq":q}

class FakeAin extends RefCounted:
	var blessing: int = 0
	func export_state() -> Dictionary: return {"blessing":blessing}
	func import_state(value: Dictionary) -> void: blessing = int(value.blessing)

class FakeWorld extends Object:
	var level: int = 90
	var gold: int = 1000000
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var ain_service := FakeAin.new()
	var saves: int = 0
	var fail_save: bool = false
	var land: Dictionary = {}
	var moves: Array = []
	func _save_game(_quiet: bool, overrides: Dictionary = {}) -> Error:
		if fail_save: return ERR_UNAVAILABLE
		saves += 1; return OK
	func orim_current_land() -> Dictionary: return land
	var alive: int = 3
	func content523_spawn_metrics() -> Dictionary: return {"ok":true,"alive":alive}
	func content523_enter_land(land_id: int, bounds: Array, waive: Array) -> Dictionary:
		moves.append([land_id,bounds,waive]); land = {"land_id":land_id,"cell":[int(bounds[0]),int(bounds[1])]}
		return {"ok":true,"reason":""}

func runtime_rules(m: Dictionary) -> void:
	var service = CONTENT.new()
	var w := FakeWorld.new()
	service.configure(w)
	CONTENT._cache = {"sha":str(SOURCE.identity().get("source_sha256","")),"data":m}
	service.now_override = 1800000000
	var entered: Dictionary = service.enter_escaros()
	check(entered.ok and w.gold==900000 and int(w.moves[0][0])==47954 and "CompetitionDungeonLand" in w.moves[0][2],"Escaros entry: travel with CompetitionDungeonLand waived, then 100,000 adena")
	w.level = 80
	check(not service.enter_escaros().ok,"Lv85 prerequisite enforced")
	w.level = 90; w.gold = 5
	check(not service.enter_escaros().ok and w.gold==5,"not enough adena: nothing charged")
	w.gold = 1000000
	w.land = {"land_id":47954,"cell":[32760,32801]}
	check(not service.use_teleporter(30504).ok,"teleporter refused beyond Range 12 cells")
	w.land = {"land_id":47954,"cell":[32745,32801]}
	var hop: Dictionary = service.use_teleporter(30504)
	check(hop.ok and int(w.land.land_id)==47964 and w.gold==900000,"teleporter Range 12: village -> field, 100,000 adena")
	# Landmark: distance check needs a field; drive the reward path directly.
	var before: int = w.ain_service.blessing
	var next: Dictionary = service._escaros_rolled(); next.escaros.found.append(4)
	check(service._commit(next,{"ainhasad_state":{"blessing":before+100}}).ok and w.ain_service.blessing==before+100,"commit applies the Einasad blessing override")
	check(4 in service.state.escaros.found and int(service.state.escaros.period)==service.period(),"landmark recorded for today's key")
	service.now_override += 86400
	check(not (4 in service._escaros_rolled().escaros.found),"next day the landmark can be examined again")
	# Touchdown: inside ActivationRange for TouchdownDelaySec.
	w.land = {"land_id":47964,"cell":[32890,32864]}
	service._artifact_since["4"] = Time.get_ticks_msec()-11000
	service._artifact_tick(w.land)
	check(int(service.touchdowns().get("4",0))==1,"touchdown after 10 s inside 15 cells")
	check(int(service.state.escaros.buffs.get("65894",0))==900 and service.buff_value("xp")==5,"decision: BuffDuration 15 = 15 min, ExperienceAdditionPercent 5%")
	service._buff_tick(600.0)
	check(int(service.state.escaros.buffs.get("65894",0))==300 and service.buff_value("xp")==5,"buff counts down in game time")
	var mid: Variant = JSON.parse_string(JSON.stringify(service.export_state()))
	var reloaded = CONTENT.new(); reloaded.import_state(mid)
	CONTENT._cache = {"sha":str(SOURCE.identity().get("source_sha256","")),"data":m}
	check(reloaded.problem.is_empty() and is_equal_approx(float(reloaded.state.escaros.buffs.get("65894",0.0)),300.0) and reloaded.buff_value("xp")==5,"remaining buff time survives save/load")
	service._buff_tick(301.0)
	check(service.state.escaros.buffs.is_empty() and service.buff_value("xp")==0,"buff expires")
	service._artifact_tick(w.land)
	check(int(service.touchdowns().get("4",0))==1,"ArtifactUseCoolTime blocks a second touchdown at once")
	w.land = {"land_id":47964,"cell":[32800,32864]}
	service._artifact_tick(w.land)
	check(not service._artifact_since.has("4"),"leaving the range resets the wait")
	# Elf forest.
	w.gold = 100000
	check(service.enter_elf(2).ok and int(w.land.land_id)==51122 and w.gold==90000 and int(service.state.elf.entries)==1,"elf grade 0: Land 51122, 10,000 adena")
	check(not service.enter_elf(12).ok,"grade 1 needs a win")
	check(int(service.elf_run().land)==51122 and int(service.elf_run().target)==0,"elf run started on grade 0")
	w.land = {"land_id":51122,"cell":[32867,32983]}
	service._elf_tick(w.land)
	check(int(service.elf_run().target)==3,"decision: the 3 monsters that appeared are the target")
	service.record_kill(); service.record_kill(); w.alive = 1
	service._elf_tick(w.land)
	check(int(service.state.elf.wins)==0 and int(service.elf_run().kills)==2,"one still alive: no win yet")
	check(not service.claim_elf_reward(1).ok,"WinNo 1 reward locked before a win")
	w.alive = 2 # a new monster appeared before the last fell
	service.record_kill(); w.alive = 1
	service._elf_tick(w.land)
	check(int(service.state.elf.wins)==0,"a monster that appeared later must be killed too")
	service.record_kill(); w.alive = 0
	service._elf_tick(w.land)
	check(int(service.state.elf.wins)==1 and service.elf_run().is_empty(),"every appeared monster killed: win 1")
	check(service.open_elf_grades().size()==2 and service.elf_rewards()[0].reached and not service.elf_rewards()[0].claimed,"win 1 opens grade 1 and the WinNo 1 reward")
	var none: Dictionary = service.claim_elf_reward(1)
	check(not none.ok and str(none.reason).contains("보상 보존") and not (1 in service.state.elf.claimed),"a reward the supplier cannot pay stays claimable")
	check("BlockLoginEnter" in CONTENT.REOPEN_WAIVE and "CompetitionDungeonLand" in CONTENT.REOPEN_WAIVE,"in-Land re-check keeps the player in the content Land")
	check(service.enter_elf(12).ok and int(w.land.land_id)==51132,"grade 1 enterable after a win")
	w.land = {"land_id":4,"cell":[33923,33350]}
	service._elf_tick(w.land)
	check(service.elf_run().is_empty() and int(service.state.elf.wins)==1,"leaving the Land ends the run without a win")
	check(service.choose_blessing(2).ok and int(service.state.elf.blessing)==2,"blessing saved")
	# Territory quest: start on entering the box, ItemCollect pickups, complete.
	w.land = {"land_id":44631,"cell":[32500,32900]}
	service._quest_tick(w.land)
	check(int(service.state.tq.active.get("quest",0))==1 and int(service.state.tq.active.deadline)==service.now()+600,"quest 1 starts in its Territory, 600 s")
	service.record_pickup(999,5)
	service.record_pickup(125911,60)
	check(int(service.quest_progress().count)==60 and not bool(service.quest_progress().done),"only the goal item counts")
	check(not service.complete_quest().ok,"incomplete quest cannot be completed")
	service.record_pickup(125911,60)
	check(int(service.quest_progress().count)==100 and bool(service.quest_progress().done),"count capped at Amount 100")
	service.now_override += 700
	service._quest_tick(w.land)
	check(not service.state.tq.active.is_empty(),"a met goal is not failed by the timeout")
	service.state.tq.active = {"quest":1,"started":service.now()-700,"deadline":service.now()-100,"count":3}
	service._quest_tick(w.land)
	check(service.state.tq.active.is_empty() and service.state.tq.failed.has("1"),"timeout fails an unmet quest")
	service._quest_tick(w.land)
	check(service.state.tq.active.is_empty(),"one try per quest per day")
	# Save validator.
	var saved: Variant = JSON.parse_string(JSON.stringify(service.export_state()))
	check(CONTENT.validate(saved).is_empty(),"state survives a JSON round trip: "+CONTENT.validate(saved))
	var restored = CONTENT.new(); restored.import_state(saved)
	check(restored.problem.is_empty() and int(restored.state.elf.blessing)==2 and restored.state.tq.failed.has("1") and typeof(restored.state.elf.blessing)==TYPE_INT,"import restores ints")
	var bad: Dictionary = (saved as Dictionary).duplicate(true); bad.escaros.found = ["x"]
	check(not CONTENT.validate(bad).is_empty(),"corrupt landmark record refused")
	var blocked = CONTENT.new(); blocked.import_state(bad)
	check(not blocked.problem.is_empty() and not blocked._commit(blocked.state.duplicate(true)).ok,"a corrupt save blocks further content saves")
	check(CONTENT.validate({}).is_empty(),"empty (new game) state valid")
	w.fail_save = true
	var keep: Dictionary = service.state.duplicate(true)
	check(not service.choose_blessing(2).ok and service.state==keep,"failed save keeps the old state")
	CONTENT.release()
	w.free()

func actual_main() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	var job: String = str(world.get("job_class")) if not str(world.get("job_class")).is_empty() else "기사"
	check(QA.enter_game(world,job),"actual Main map entry")
	check(world.get("content523")!=null and world.content523.world==world,"world owns content523")
	check(world.has_method("content523_enter_land"),"content Land travel hook")
	world.hud.open_content523()
	await process_frame
	var panel: Node = world.hud.find_child("Content523Panel",true,false)
	check(panel!=null,"menu window opens")
	world.queue_free()
	await process_frame

func installed() -> void:
	CONTENT.release()
	var m: Dictionary = CONTENT.models()
	if not check(m.escaros.get("ok",false) and m.elf.get("ok",false) and m.tq.get("ok",false),"original tables: %s / %s / %s" % [m.escaros.get("problem",""),m.elf.get("problem",""),m.tq.get("problem","")]): return
	evidence["original"] = {"escaros":m.escaros.counts,"elf":m.elf.counts,"tq":m.tq.counts}
	check(int(m.escaros.counts.landmarks)==18 and int(m.escaros.counts.artifacts)==5 and int(m.escaros.counts.zones)==7 and int(m.escaros.counts.lands)==2,"18 landmarks, 5 artifacts, 7 zones, 2 Lands")
	check(int(m.escaros.dungeon.teleport.land_id)==47954 and int(m.escaros.dungeon.teleport.cost)==100000,"Escaros entry -> village 47954 for 100,000")
	check(int(m.elf.counts.grades)==6 and int(m.elf.counts.blessings)==4 and int(m.elf.counts.wins)==12,"6 grades, 4 blessings, 12 win rewards")
	check(int(m.tq.counts.quests)==7 and int(m.tq.counts.playable)==2,"7 territory quests, 2 playable (coin collection)")
	# The built models are stored on the device and read back unchanged, so
	# the first in-game content tick does not rebuild them (phone: 6.1 s frame).
	var sha: String = str(SOURCE.identity().get("source_sha256",""))
	var bake = preload("res://scripts/resources/current523_bake_cache.gd")
	var stored: Variant = bake.read(CONTENT.MODELS_BAKE, CONTENT.models_bake_key(sha))
	check(stored is Dictionary and var_to_str(stored)==var_to_str(m),"content models are stored on the device unchanged")
	check(CONTENT.models_bake_key(sha)!=CONTENT.models_bake_key("0".repeat(64)),"a different original never reuses stored content models")
	CONTENT.release()
	var started: int = Time.get_ticks_usec()
	var again: Dictionary = CONTENT.models()
	check(var_to_str(again)==var_to_str(m),"content models read back equal the built models")
	evidence["stored_read_ms"] = (Time.get_ticks_usec()-started)/1000
	CONTENT.release()

func run() -> void:
	var m: Dictionary = models()
	runtime_rules(m)
	await actual_main()
	if not SOURCE.not_installed(): installed()
	print("CONTENT523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
