extends RefCounted
## Narrow consumer of PR230's unchanged production loader. No second catalog.
const OWNER=preload("res://scripts/maps/patch523_world_links.gd")
const SERVER=preload("res://scripts/cards/source_collection_conditions.gd")
const WINDOWS=preload("res://scripts/crafting/patch523_craft_conditions.gd")
const CIVIL=preload("res://scripts/monsterbook/monsterbook523_clock.gd")
const OPTIONS=preload("res://scripts/maps/current523_aden_play_options.gd")
const MANIFEST_SHA256="2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
const MAX_CACHED_LANDS=4
var loaded: bool=false
var root: String=""
var problem: String=""
var _lands: Dictionary={}
var _recent: Array[String]=[]
var _date_indexes: Dictionary={}

func load_pack(directory: String, expected_sha256: String) -> bool:
	if expected_sha256!=MANIFEST_SHA256: problem="원문 정의팩 SHA가 다릅니다."; return false
	if not _manifest_has_pin(directory): problem="원문 정의 manifest가 없거나 변경되었습니다."; return false
	var candidate:=OWNER.new()
	if not candidate.load_land(directory,0,"0/",expected_sha256): problem=candidate.problem; return false
	root=directory; loaded=true; problem=""; _lands.clear(); _recent.clear();_date_indexes.clear()
	_lands["0:0/"]=candidate; _recent.append("0:0/")
	return true

func matches_manifest(directory: String, expected_sha256: String) -> bool:
	return loaded and directory==root and expected_sha256==MANIFEST_SHA256 and _manifest_has_pin(directory)

static func _manifest_has_pin(directory: String) -> bool:
	var file:=FileAccess.open(directory.path_join("manifest.json"),FileAccess.READ)
	if file==null or file.get_length()<2 or file.get_length()>OWNER.MAX_FILE_BYTES: return false
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256)
	hash.update(file.get_buffer(file.get_length()))
	return hash.finish().hex_encode()==MANIFEST_SHA256

func _definition(land_id: int, exact_asset: String) -> RefCounted:
	if not matches_manifest(root,MANIFEST_SHA256): problem="원문 정의 manifest가 변경되었거나 없습니다."; return null
	var key: String=str(land_id)+":"+exact_asset
	if _lands.has(key): _recent.erase(key); _recent.append(key); problem=""; return _lands[key]
	var candidate: RefCounted=OWNER.shared_land(root,land_id,exact_asset,MANIFEST_SHA256)
	if candidate==null: problem=OWNER.shared_problem; return null
	_lands[key]=candidate; _recent.append(key)
	while _recent.size()>MAX_CACHED_LANDS: _lands.erase(_recent.pop_front())
	problem=""
	return candidate

func portal_evidence_for_land(land_id: int, exact_asset: String) -> Array:
	var definition: RefCounted=_definition(land_id,exact_asset)
	var result: Array=[]
	if definition==null: return result
	for record: Dictionary in definition.portal_evidence():
		if record.get("portal") is Dictionary: result.append(record.portal.duplicate(true))
	return result

static func _declared_inactive_restriction(type: Dictionary, row: Dictionary) -> bool:
	# Current523 Unit20=TrueFalse. Exact known negative restrictions only;
	# zero on an unknown type, another unit or a parameterized row is not permission.
	var expected_name: String={
		1:"NoCreateMonster",3:"NoDropItem",4:"NoLoseExperience",5:"NoUsePosition",
		6:"NoPolymorph",7:"NoMassattack",8:"NoTeleport",13:"NoTeleportCome",
		191:"BlockLoginEnter",234:"NeverTeleport",301:"NoParty",592:"CannotEscape",
		602:"NoQuestTeleport",612:"NoExperience",694:"NoPickupSelector",758:"NoChat",
		782:"NoBuff",1012:"NoReviveOnInterServer",1061:"NoPurplePushOnDie"
	}.get(int(type.get("ID",-1)),"")
	if expected_name.is_empty() or type.get("Name")!=expected_name or type.get("UnitID")!=20: return false
	for key: String in ["Value","Param1","Param2","Param3"]:
		if not (row.get(key) is int or row.get(key) is float) or row[key]!=0: return false
	return true

func _attribute_holds(definition: RefCounted, land_id: int, point: Vector2i) -> Array:
	return _attribute_evaluation(definition,land_id,point).holds

static func _actor_level_condition(type: Dictionary, row: Dictionary, actor_level: Variant) -> Dictionary:
	# Exact M LandAttributeType declarations:91 MinLevel,101 MaxLevel, Unit1.
	# Only a positive scalar threshold with no parameters is evaluated here.
	# Missing actor context/zero/unknown forms retain the existing hold.
	var type_id: int=int(type.get("ID",-1))
	var expected_name: String={91:"MinLevel",101:"MaxLevel"}.get(type_id,"")
	if expected_name.is_empty() or type.get("Name")!=expected_name or type.get("UnitID")!=1:return {}
	if not OWNER._integer(actor_level) or actor_level<1 or actor_level>2147483647:return {}
	if not OWNER._integer(row.get("Value")) or row.Value<1 or row.Value>2147483647:return {}
	for name: String in ["Param1","Param2","Param3"]:
		if not OWNER._integer(row.get(name)) or row[name]!=0:return {}
	var fulfilled: bool=actor_level>=row.Value if type_id==91 else actor_level<=row.Value
	return {"fulfilled":fulfilled,"actor_level":int(actor_level),"threshold":int(row.Value),"comparison":"at_least" if type_id==91 else "at_most","type":type.duplicate(true),"row":row.duplicate(true)}

func _attribute_evaluation(definition: RefCounted, land_id: int, point: Vector2i, actor_level: Variant=null, open_policy: String=OPTIONS.SOURCE_CONDITIONS_V1) -> Dictionary:
	var types: Dictionary={}
	for row: Dictionary in definition.context_rows("LandAttributeType"): types[int(row.ID)]=row
	var result: Array=[]
	var inactive: Array=[]
	var actor_conditions: Array=[]
	var waived: Array=[]
	for row: Dictionary in definition.context_rows("LandAttribute"):
		if int(row.get("LandID",-1))!=land_id: continue
		var territory_id: int=int(row.get("TerritoryID",0))
		if territory_id!=0:
			var territory: Dictionary=definition.territories.get(territory_id,{})
			if territory.is_empty() or territory.StartX>territory.EndX or territory.StartY>territory.EndY:
				result.append({"reason":"attribute_territory_unresolved","row":row.duplicate(true)}); continue
			if point.x<territory.StartX or point.x>territory.EndX or point.y<territory.StartY or point.y>territory.EndY: continue
		var type: Dictionary=types.get(int(row.get("LandAttributeTypeID",-1)),{})
		var name: String=str(type.get("Name","UNKNOWN"))
		if open_policy==OPTIONS.OWN_ALWAYS_OPEN_V1 and type.get("ID")==144 and name=="CloseTime" and type.get("UnitID")==17:
			waived.append({"table":"LandAttribute","type":type.duplicate(true),"row":row.duplicate(true),"policy":open_policy});continue
		# These declarations do not authorize entry or a teleport: this adapter
		# neither creates bookmarks nor changes depth/manner mechanics.
		if name in ["NoBookmark","Underground","IgnoreMannerMode"]: continue
		var level: Dictionary=_actor_level_condition(type,row,actor_level)
		if not level.is_empty():
			actor_conditions.append(level)
			if not level.fulfilled:result.append({"reason":"actor_level_requirement_not_met","evaluation":level.duplicate(true),"type":type.duplicate(true),"row":row.duplicate(true)})
			continue
		if _declared_inactive_restriction(type,row):
			inactive.append({"type":type.duplicate(true),"row":row.duplicate(true)}); continue
		result.append({"reason":"native_attribute_requires_policy","type":type.duplicate(true),"row":row.duplicate(true)})
	return {"holds":result,"declared_inactive":inactive,"actor_conditions":actor_conditions,"waived_time_conditions":waived}

func portal_context_for_land(land_id: int, exact_asset: String, portal_id: int) -> Dictionary:
	return _portal_context(land_id,exact_asset,portal_id)

func portal_context_for_actor(land_id: int, exact_asset: String, portal_id: int, actor_level: Variant) -> Dictionary:
	return _portal_context(land_id,exact_asset,portal_id,actor_level)

func portal_context_for_actor_at_landing(land_id: int, exact_asset: String, portal_id: int, actor_level: Variant, source_cell: Vector2i, selection_policy: String) -> Dictionary:
	return _portal_context(land_id,exact_asset,portal_id,actor_level,{"source_cell":source_cell,"selection_policy":selection_policy})

func portal_context_for_actor_state(land_id: int, exact_asset: String, portal_id: int, actor_state: Dictionary) -> Dictionary:
	return _portal_context(land_id,exact_asset,portal_id,actor_state.get("level"),{},actor_state)

func portal_context_for_actor_state_at_landing(land_id: int, exact_asset: String, portal_id: int, actor_state: Dictionary, source_cell: Vector2i, selection_policy: String) -> Dictionary:
	return _portal_context(land_id,exact_asset,portal_id,actor_state.get("level"),{"source_cell":source_cell,"selection_policy":selection_policy},actor_state)

func _date_row(definition: RefCounted, table: String, id: int) -> Dictionary:
	if not _date_indexes.has(table):
		var index: Dictionary={}
		for row: Dictionary in definition.context_rows(table):
			if not OWNER._integer(row.get("ID")):continue
			var key: int=int(row.ID)
			index[key]={} if index.has(key) else row.duplicate(true)
		_date_indexes[table]=index
	return (_date_indexes[table].get(id,{}) as Dictionary).duplicate(true)

## false = source dates only (ended event regions stay closed).
const ROTATE_ENDED_EVENT_LANDS: bool = true

func _date_window(definition: RefCounted, group: Dictionary, actor_state: Dictionary) -> Dictionary:
	var result: Dictionary={"status":"context_missing","native_calendar_boundary_verified":false,"boundary":"start_inclusive_end_exclusive","group":group.duplicate(true)}
	if not OWNER._integer(group.get("StartDateTimeID")) or not OWNER._integer(group.get("EndDateTimeID")):
		result.status="date_reference_invalid";return result
	var start: int=int(group.StartDateTimeID);var end: int=int(group.EndDateTimeID)
	if start==0 and end==0:result.status="not_declared";return result
	if start<1 or end<1:result.status="date_reference_incomplete";return result
	var profile: Variant=actor_state.get("server_profile")
	if not profile is Dictionary or not SERVER.valid_context(profile):return result
	var table: String={"KR":"DateTimes_Korean"}.get(str(profile.ServiceRegionCode),"")
	if table.is_empty():result.status="service_date_table_unresolved";return result
	result["date_table"]=table;result["server_profile"]=profile.duplicate(true)
	var first: Dictionary=_date_row(definition,table,start)
	var last: Dictionary=_date_row(definition,table,end)
	result["source_start"]=first;result["source_end"]=last
	if first.is_empty() or last.is_empty():result.status="date_definition_missing";return result
	if not CIVIL.valid(CIVIL.format_row(first)) or not CIVIL.valid(CIVIL.format_row(last)):
		result.status="source_civil_date_invalid";return result
	if not str(actor_state.get("calendar_hold","")).is_empty():result["reason"]=actor_state.calendar_hold;return result
	var offset: Variant=actor_state.get("calendar_offset_minutes")
	if not WINDOWS.integer(offset,-840,840) or not WINDOWS.integer(actor_state.get("now_unix"),0,4102444800):return result
	var origin: String=str(actor_state.get("calendar_clock_origin",""))
	if origin.is_empty():return result
	var first_fields: Dictionary={"year":int(first.Year),"month":int(first.Month),"day":int(first.Day),"hour":int(first.Hour),"minute":int(first.Minute),"second":0}
	var last_fields: Dictionary={"year":int(last.Year),"month":int(last.Month),"day":int(last.Day),"hour":int(last.Hour),"minute":int(last.Minute),"second":0}
	var window: Dictionary={"source_start":first,"source_end":last,"start_unix":Time.get_unix_time_from_datetime_dict(first_fields)-int(offset)*60,"end_unix":Time.get_unix_time_from_datetime_dict(last_fields)-int(offset)*60,"utc_offset_minutes":int(offset),"clock_origin":origin,"boundary":"start_inclusive_end_exclusive"}
	if not WINDOWS.valid_window(window):result.status="source_window_invalid";return result
	result["window"]=window
	result.status="open" if actor_state.now_unix>=window.start_unix and actor_state.now_unix<window.end_unix else "closed"
	# TWILIGHT is offline: an event region whose source window has ended repeats
	# the same window back to back (local rotation), so it is open again.
	var length: int=int(window.end_unix)-int(window.start_unix)
	if ROTATE_ENDED_EVENT_LANDS and length>0 and int(actor_state.now_unix)>=int(window.end_unix):
		var turn: int=floori(float(int(actor_state.now_unix)-int(window.start_unix))/float(length))
		result["local_rotation"]=turn
		result["rotated_window"]={"start_unix":int(window.start_unix)+turn*length,"end_unix":int(window.start_unix)+(turn+1)*length}
		result.status="open"
	return result

static func _open_policy(actor_state: Dictionary) -> String:
	var value: Variant=actor_state.get("map_open_policy",OPTIONS.OWN_ALWAYS_OPEN_V1)
	return value if value is String and value in [OPTIONS.OWN_ALWAYS_OPEN_V1,OPTIONS.SOURCE_CONDITIONS_V1] else ""

func _land_time_conditions(definition: RefCounted, land_id: int, actor_state: Dictionary) -> Dictionary:
	var result: Dictionary={"holds":[],"evaluations":[],"waived":[]}
	var open_policy: String=_open_policy(actor_state)
	if open_policy.is_empty():result.holds.append({"reason":"map_open_policy_invalid"});return result
	var always_open: bool=open_policy==OPTIONS.OWN_ALWAYS_OPEN_V1
	for row: Dictionary in definition.context_rows("LandTimeLimit"):
		if int(row.get("LandID",-1))!=land_id:continue
		var group: Dictionary={}
		for candidate: Dictionary in definition.context_rows("LandTimeLimitGroup"):
			if candidate.get("ID")==row.get("LandTimeLimitGroupID"):
				if not group.is_empty():group={};break
				group=candidate.duplicate(true)
		if group.is_empty():
			if always_open:
				result.evaluations.append({"land_id":land_id,"row":row.duplicate(true),"calendar":{"status":"group_definition_missing","group":{}},"time_conditions_waived":true,"map_open_policy":open_policy})
				result.waived.append({"table":"LandTimeLimit","row":row.duplicate(true),"group":{},"policy":open_policy})
			else:result.holds.append({"reason":"land_time_group_unresolved","row":row.duplicate(true)})
			continue
		var calendar: Dictionary=_date_window(definition,group,actor_state)
		result.evaluations.append({"land_id":land_id,"row":row.duplicate(true),"calendar":calendar,"time_conditions_waived":always_open,"map_open_policy":open_policy})
		if always_open:
			result.waived.append({"table":"LandTimeLimit","row":row.duplicate(true),"group":group.duplicate(true),"calendar":calendar.duplicate(true),"policy":open_policy})
			continue
		if calendar.status not in ["open","not_declared"]:result.holds.append({"reason":"land_date_window_"+str(calendar.status),"row":row.duplicate(true),"calendar":calendar.duplicate(true)})
		# A calendar result is never elapsed-time ownership. Existing dungeon
		# pools cannot grant map entry unless their accounting owns this session.
		result.holds.append({"reason":"native_land_time_pool_owner_required","row":row.duplicate(true),"group":group.duplicate(true)})
	return result

func land_entry_context_for_actor_state(land_id: int, exact_asset: String, actor_state: Dictionary, source_cell: Vector2i) -> Dictionary:
	# The ordinary selector/reopen path consumes the same M conditions as manual
	# portal travel. A source cursor is not an admission, calendar or time credit.
	var definition: RefCounted=_definition(land_id,exact_asset)
	if definition==null:return {}
	var attributes: Dictionary=_attribute_evaluation(definition,land_id,source_cell,actor_state.get("level"),_open_policy(actor_state))
	var time: Dictionary=_land_time_conditions(definition,land_id,actor_state)
	var holds: Array=attributes.holds.duplicate(true)
	holds.append_array(time.holds)
	var waived: Array=time.waived.duplicate(true)
	waived.append_array(attributes.waived_time_conditions)
	for table: String in ["LandWeeklyOpenTime","CompetitionDungeonLand"]:
		for row: Dictionary in definition.context_rows(table):
			if int(row.get("LandID",row.get("LandId",-1)))==land_id:
				if table=="LandWeeklyOpenTime" and _open_policy(actor_state)==OPTIONS.OWN_ALWAYS_OPEN_V1:
					waived.append({"table":table,"row":row.duplicate(true),"policy":OPTIONS.OWN_ALWAYS_OPEN_V1})
				else:holds.append({"reason":"native_land_condition_requires_policy","table":table,"row":row.duplicate(true)})
	return {"Land":definition.land.duplicate(true),"source_cell":[source_cell.x,source_cell.y],"definition_manifest_sha256":MANIFEST_SHA256,"definition_owner":"PR230_PATCH523_WORLD_LINKS","land_time_conditions":time.evaluations,"map_open_policy":_open_policy(actor_state),"waived_time_conditions":waived,"actor_level_conditions":attributes.actor_conditions,"declared_inactive_restrictions":attributes.declared_inactive,"source_travel_holds":holds,"source_travel_hold":"native_definition_conditions_require_policy" if not holds.is_empty() else "","native_admission_verified":false}

func _portal_context(land_id: int, exact_asset: String, portal_id: int, actor_level: Variant=null, own_landing: Dictionary={}, actor_state: Dictionary={}) -> Dictionary:
	var source: RefCounted=_definition(land_id,exact_asset)
	if source==null: return {}
	var contract: Dictionary=source.portal_contract(portal_id)
	if contract.is_empty() or contract.get("manifest_sha256")!=MANIFEST_SHA256: return {}
	var declaration: Dictionary=contract.declaration
	var portal: Dictionary=declaration.portal
	var target_land: Dictionary=declaration.target_land
	var territory: Dictionary=declaration.target_territory
	var target: RefCounted=_definition(int(target_land.ID),str(target_land.AssetPath))
	if target==null: return {}
	var holds: Array=[]
	var area: bool=territory.StartX!=territory.EndX or territory.StartY!=territory.EndY
	var selected_point: Variant=null
	var arrival_policy: String="EXACT_POINT_ONLY"
	if not area:selected_point=Vector2i(int(territory.StartX),int(territory.StartY))
	elif own_landing.get("selection_policy")=="OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1" and own_landing.get("source_cell") is Vector2i:
		var cell: Vector2i=own_landing.source_cell
		if cell.x>=territory.StartX and cell.x<=territory.EndX and cell.y>=territory.StartY and cell.y<=territory.EndY:
			selected_point=cell;arrival_policy="OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1"
	if selected_point==null:holds.append({"reason":"native_region_arrival_policy_unverified"})
	var source_point:=Vector2i(int(portal.SourceX),int(portal.SourceY))
	var source_attributes: Dictionary=_attribute_evaluation(source,land_id,source_point,actor_level,_open_policy(actor_state))
	var waived_attributes: Array=source_attributes.waived_time_conditions.duplicate(true)
	holds.append_array(source_attributes.holds)
	var inactive: Array=[]
	var actor_conditions: Array=[]
	for item: Dictionary in source_attributes.actor_conditions:
		var evidence: Dictionary=item.duplicate(true);evidence["side"]="source";actor_conditions.append(evidence)
	for item: Dictionary in source_attributes.declared_inactive:
		var evidence: Dictionary=item.duplicate(true); evidence["side"]="source"; inactive.append(evidence)
	if selected_point is Vector2i:
		var target_attributes: Dictionary=_attribute_evaluation(target,int(target_land.ID),selected_point,actor_level,_open_policy(actor_state))
		waived_attributes.append_array(target_attributes.waived_time_conditions)
		holds.append_array(target_attributes.holds)
		for item: Dictionary in target_attributes.actor_conditions:
			var evidence: Dictionary=item.duplicate(true);evidence["side"]="target";actor_conditions.append(evidence)
		for item: Dictionary in target_attributes.declared_inactive:
			var evidence: Dictionary=item.duplicate(true); evidence["side"]="target"; inactive.append(evidence)
	var time_conditions: Array=[]
	var waived_time_conditions: Array=waived_attributes
	var time_lands: Dictionary={}
	time_lands[land_id]=source
	time_lands[int(target_land.ID)]=target
	for affected_land: int in time_lands:
		var conditions: Dictionary=_land_time_conditions(time_lands[affected_land],affected_land,actor_state)
		holds.append_array(conditions.holds);time_conditions.append_array(conditions.evaluations);waived_time_conditions.append_array(conditions.waived)
	for table: String in ["LandWeeklyOpenTime","CompetitionDungeonLand"]:
		for row: Dictionary in source.context_rows(table):
			var id: int=int(row.get("LandID",row.get("LandId",-1)))
			if id in [land_id,int(target_land.ID)]:
				if table=="LandWeeklyOpenTime" and _open_policy(actor_state)==OPTIONS.OWN_ALWAYS_OPEN_V1:
					waived_time_conditions.append({"table":table,"row":row.duplicate(true),"policy":OPTIONS.OWN_ALWAYS_OPEN_V1})
				else:holds.append({"reason":"native_land_condition_requires_policy","table":table,"row":row.duplicate(true)})
	return {"Portal":portal.duplicate(true),"SourceLand":source.land.duplicate(true),"TargetTerritory":territory.duplicate(true),"TargetLand":target_land.duplicate(true),"definition_manifest_sha256":MANIFEST_SHA256,"definition_owner":"PR230_PATCH523_WORLD_LINKS","native_definition_contract":contract.duplicate(true),"declared_inactive_restrictions":inactive,"actor_condition_level":actor_level,"actor_level_conditions":actor_conditions,"land_time_conditions":time_conditions,"map_open_policy":_open_policy(actor_state),"waived_time_conditions":waived_time_conditions,"own_arrival_policy":arrival_policy,"own_arrival_source_cell":[selected_point.x,selected_point.y] if selected_point is Vector2i else [],"native_landing_rule_verified":false,"source_travel_holds":holds,"source_travel_hold":"native_definition_conditions_require_policy" if not holds.is_empty() else "","native_m_rules_verified":false}

func cache_metrics() -> Dictionary:
	return {"cached_native_lands":_lands.size(),"maximum_native_lands":MAX_CACHED_LANDS,"definition_manifest_sha256":MANIFEST_SHA256 if loaded else ""}
