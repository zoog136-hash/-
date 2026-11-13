extends RefCounted
## 에스카로스 (Escaros*) — the original 523 table model.
## Pure reader: every number comes from an original row; rules the tables do
## not hold are not filled in (docs/escaros_elfforest_territory523_missing_rules.md).
##
## Escaros is CompetitionDungeon EscarosConstant.EscarosDungeonID (314):
## LandTeleportId -> LandTeleport (cost, currency, LandTeleportPrerequisite)
## -> LandTeleportTerritories -> HomeTerritoriesID (the village, Land 47954);
## CompetitionDungeonLand lists its Lands (village + field 47964). The village
## EarthObjectSpawn teleporters carry EarthObjectUnit LandTeleportID.
## EscarosZone / EscarosLandmark(+Group) / EscarosArtifact name their
## Territories rows. `src` has rows(table) and related(table, field, id), as
## scripts/resources/current523_definition_rows.gd or a synthetic test table.
## Table numbers arrive as floats.

static func _i(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT,TYPE_FLOAT] else 0

static func _one(src: Variant, table: String, id: int) -> Dictionary:
	if id==0: return {}
	var matches: Array = src.related(table,"ID",id)
	return matches[-1] if not matches.is_empty() else {}

static func _text(src: Variant, id: int) -> String:
	if id<=0: return ""
	var matches: Array = src.related("DescData_Korean","ID",id)
	return "" if matches.is_empty() else str(matches[-1].get("Description",""))

static func box(territory: Dictionary) -> Array:
	return [_i(territory.get("StartX")),_i(territory.get("StartY")),_i(territory.get("EndX")),_i(territory.get("EndY"))]

static func center(territory: Dictionary) -> Array:
	var b: Array = box(territory)
	return [(int(b[0])+int(b[2]))/2,(int(b[1])+int(b[3]))/2]

## One LandTeleport with its destination Territory/Land, cost and prerequisites.
static func teleport(src: Variant, teleport_id: int) -> Dictionary:
	var row: Dictionary = _one(src,"LandTeleport",teleport_id)
	if row.is_empty(): return {}
	var out: Dictionary = {"id":teleport_id,"cost":_i(row.get("TeleportCost")),"currency":_i(row.get("CurrencyID")),
		"min_level":0,"max_level":0,"other_prerequisites":[],"territory":{},"land_id":0,"land_name":"","box":[]}
	var types: Dictionary = {}
	for type: Dictionary in src.rows("PrerequisiteType"): types[_i(type.ID)] = str(type.get("Name",""))
	for link: Dictionary in src.related("LandTeleportPrerequisite","LandTeleportID",teleport_id):
		var condition: Dictionary = _one(src,"Prerequisite",_i(link.get("PrerequisiteID")))
		var name: String = str(types.get(_i(condition.get("PrerequisiteTypeID")),""))
		if name=="MinLevel": out.min_level = maxi(int(out.min_level),_i(condition.get("Value")))
		elif name=="MaxLevel": out.max_level = _i(condition.get("Value"))
		else: out.other_prerequisites.append({"type":name,"value":_i(condition.get("Value"))})
	var targets: Array = src.related("LandTeleportTerritories","LandTeleportID",teleport_id)
	if targets.size()==1:
		var territory: Dictionary = _one(src,"Territories",_i(targets[0].get("TerritoryID")))
		out.territory = territory.duplicate(true)
		out.land_id = _i(territory.get("LandID"))
		out.land_name = str(_one(src,"Land",int(out.land_id)).get("Name",""))
		out.box = box(territory)
	out["targets"] = targets.size()
	return out

static func build(src: Variant) -> Dictionary:
	var data: Dictionary = {"ok":false,"problem":"","constants":{},"dungeon":{},"lands":[],"teleporters":[],
		"zones":[],"landmarks":{},"groups":{},"artifacts":[],"rank_rewards":0,"counts":{}}
	for row: Dictionary in src.rows("EscarosConstant"): data.constants[str(row.get("Name",""))] = _i(row.get("Value"))
	var dungeon_id: int = int(data.constants.get("EscarosDungeonID",0))
	var dungeon: Dictionary = _one(src,"CompetitionDungeon",dungeon_id)
	if dungeon.is_empty():
		data.problem = "에스카로스 원본 표(EscarosConstant/CompetitionDungeon)가 없습니다"
		return data
	var village: Dictionary = _one(src,"Territories",int(data.constants.get("VillageTerritoryID",0)))
	var home: Dictionary = _one(src,"Territories",_i(dungeon.get("HomeTerritoriesID")))
	var entry: Dictionary = teleport(src,_i(dungeon.get("LandTeleportId")))
	data.dungeon = {"id":dungeon_id,"name":_text(src,_i(_one(src,"CompetitionDungeonView",dungeon_id).get("TitleDescId"))),
		"teleport":entry,"home":home.duplicate(true),"village":village.duplicate(true),
		"time_group":_one(src,"LandTimeLimitGroup",_i(dungeon.get("LandTimeLimitGroupId"))).duplicate(true),
		"hot_open_group":_i(dungeon.get("HotWeeklyOpenTimeGroupId")),"open_group":_i(dungeon.get("WeeklyOpenTimeGroupId")),"state":_i(dungeon.get("DungeonState"))}
	for link: Dictionary in src.related("CompetitionDungeonLand","CompetitionDungeonID",dungeon_id):
		var land_id: int = _i(link.get("LandID"))
		var land: Dictionary = _one(src,"Land",land_id)
		data.lands.append({"id":land_id,"name":str(land.get("Name","")),"asset":str(land.get("AssetPath","")),"boss":bool(link.get("IsBossLand",false))})
	var land_ids: Dictionary = {}
	for land: Dictionary in data.lands: land_ids[int(land.id)] = true
	# Teleporters placed in the Escaros Lands (EarthObjectSpawn -> one-cell
	# Territory; EarthObjectUnit Unit "LandTeleportID").
	var units: Dictionary = {}
	for unit: Dictionary in src.rows("Unit"): units[_i(unit.ID)] = str(unit.get("Name",""))
	var attribute_types: Dictionary = {}
	for row: Dictionary in src.rows("EarthObjectAttributeType"): attribute_types[_i(row.ID)] = str(row.get("Name",""))
	for spawn: Dictionary in src.rows("EarthObjectSpawn"):
		var territory: Dictionary = _one(src,"Territories",_i(spawn.get("TerritoriesID")))
		if territory.is_empty() or not land_ids.has(_i(territory.get("LandID"))): continue
		if _i(spawn.get("ServerLimitSetID"))!=0 or spawn.get("SpawnManually")==true: continue
		var class_id: int = _i(spawn.get("EarthObjectClassID"))
		for unit: Dictionary in src.related("EarthObjectUnit","EarthObjectClassID",class_id):
			if str(units.get(_i(unit.get("UnitID")),""))!="LandTeleportID": continue
			var route: Dictionary = teleport(src,_i(unit.get("Value")))
			if route.is_empty(): continue
			var object: Dictionary = _one(src,"EarthObjectClass",class_id)
			var reach: int = 0
			for attribute: Dictionary in src.related("EarthObjectAttribute","EarthObjectClassID",class_id):
				if str(attribute_types.get(_i(attribute.get("EarthObjectAttributeTypeID")),""))=="Range": reach = _i(attribute.get("Value"))
			var title: String = _text(src,_i(object.get("DescID")))
			data.teleporters.append({"spawn_id":_i(spawn.ID),"class_id":class_id,"name":title.get_slice("^",title.get_slice_count("^")-1),
				"object_name":str(object.get("Name","")),"land_id":_i(territory.get("LandID")),"cell":center(territory),"range":reach,"route":route})
	data.teleporters.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return int(a.spawn_id)<int(b.spawn_id))
	for row: Dictionary in src.rows("EscarosZone"):
		var territory: Dictionary = _one(src,"Territories",_i(row.get("TerritoriesID")))
		data.zones.append({"id":_i(row.ID),"land_id":_i(territory.get("LandID")),"box":box(territory),
			"name":_text(src,_i(row.get("ZoneNameDescID"))),"sub":_text(src,_i(row.get("SubZoneNameDescID"))),"interval_ms":_i(row.get("NotiIntervalTime"))})
	var group_names: Dictionary = {}
	for row: Dictionary in src.rows("EscarosLandmarkGroup"): group_names[_i(row.ID)] = str(row.get("Name",""))
	var reward_types: Dictionary = {}
	for row: Dictionary in src.rows("RewardType"): reward_types[_i(row.ID)] = str(row.get("Name",""))
	for row: Dictionary in src.rows("EscarosLandmark"):
		var territory: Dictionary = _one(src,"Territories",_i(row.get("TerritoriesID")))
		var reward: Dictionary = _one(src,"Reward",_i(row.get("RewardID")))
		var id: int = _i(row.ID)
		var group: int = _i(row.get("EscarosLandmarkGroupID"))
		data.landmarks[id] = {"id":id,"name":str(row.get("Name","")),"group":group,"group_name":str(group_names.get(group,"")),
			"prob":_i(row.get("Prob")),"land_id":_i(territory.get("LandID")),"cell":center(territory),
			"reward":{"id":_i(reward.get("ID")),"type":str(reward_types.get(_i(reward.get("RewardTypeID")),"")),"class_id":_i(reward.get("RewardClassID")),
				"amount":_i(reward.get("Amount")),"bless":_i(reward.get("ItemBlessCodeID"))},
			"story":_text(src,_i(row.get("StoryDescID"))),"object_class":_i(row.get("EarthObjectClassID"))}
		if not data.groups.has(group): data.groups[group] = []
		data.groups[group].append(id)
	for group: int in data.groups: data.groups[group].sort()
	# Artifacts: BuffClass bonuses through the UIUnit denominator.
	var denominators: Dictionary = {}
	for row: Dictionary in src.rows("UIUnit"): denominators[_i(row.get("UnitID"))] = _i(row.get("Denominator"))
	for row: Dictionary in src.rows("EscarosArtifact"):
		var territory: Dictionary = _one(src,"Territories",_i(row.get("TerritoriesID")))
		var buff_id: int = _i(row.get("BuffClassID"))
		var effects: Array = []
		for link: Dictionary in src.related("BuffBonus","BuffClassID",buff_id):
			var bonus: Dictionary = _one(src,"Bonus",_i(link.get("BonusID")))
			var type: Dictionary = _one(src,"BonusType",_i(bonus.get("BonusTypeID")))
			var denominator: int = int(denominators.get(_i(type.get("UnitID")),0))
			effects.append({"type":str(type.get("Name","")),"value":_i(bonus.get("Value")),"percent":float(_i(bonus.get("Value")))/float(denominator) if denominator>0 else 0.0})
		var teleport_territory: Dictionary = _one(src,"Territories",_i(row.get("TeleportTerritoriesID")))
		data.artifacts.append({"id":_i(row.ID),"code":str(row.get("Name","")),"name":_text(src,_i(row.get("DescID"))),"area":_text(src,_i(row.get("AreaDescID"))),
			"round":_i(row.get("Round")),"land_id":_i(territory.get("LandID")),"cell":center(territory),"range":_i(row.get("ActivationRange")),
			"buff_id":buff_id,"buff_name":str(_one(src,"BuffClass",buff_id).get("Name","")),"effects":effects,
			"buff_duration_raw":_i(row.get("BuffDuration")),"touchdown_delay_sec":_i(row.get("TouchdownDelaySec")),
			"max_rankers":_i(row.get("MaxRankerCount")),"teleport_box":box(teleport_territory)})
	data.artifacts.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return int(a.round)<int(b.round))
	data.rank_rewards = src.rows("EscarosArtifactRankReward").size()
	data.counts = {"lands":data.lands.size(),"teleporters":data.teleporters.size(),"zones":data.zones.size(),"landmarks":data.landmarks.size(),
		"groups":data.groups.size(),"artifacts":data.artifacts.size(),"rank_rewards":data.rank_rewards,"constants":data.constants.size()}
	if entry.is_empty() or int(entry.land_id)==0 or data.lands.is_empty():
		data.problem = "에스카로스 입장 이동(LandTeleport) 원본 행이 없습니다"
		return data
	data.ok = true
	return data

## The landmark of each group shown in `period` (EscarosLandmark.Prob within
## its group). The period is TWILIGHT's daily key (own: the tables give no
## re-selection timing); the draw is seeded so it is stable for that period.
static func active_landmarks(data: Dictionary, period: int) -> Array:
	var out: Array = []
	for group: int in data.get("groups",{}):
		var ids: Array = data.groups[group]
		var total: int = 0
		for id: int in ids: total += maxi(0,int(data.landmarks[id].prob))
		if total<=0: continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([period,group])
		var pick: int = rng.randi_range(1,total)
		for id: int in ids:
			pick -= maxi(0,int(data.landmarks[id].prob))
			if pick<=0: out.append(id); break
	out.sort()
	return out

## Zone of a cell (first EscarosZone whose Territory box holds it).
static func zone_at(data: Dictionary, land_id: int, cell: Array) -> Dictionary:
	for zone: Dictionary in data.get("zones",[]):
		var b: Array = zone.box
		if int(zone.land_id)==land_id and int(cell[0])>=int(b[0]) and int(cell[0])<=int(b[2]) and int(cell[1])>=int(b[1]) and int(cell[1])<=int(b[3]): return zone
	return {}

static func cell_distance(a: Array, b: Array) -> int:
	return maxi(absi(int(a[0])-int(b[0])),absi(int(a[1])-int(b[1])))
