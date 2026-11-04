extends RefCounted
## Narrow consumer of PR230's unchanged production loader. No second catalog.
const OWNER=preload("res://scripts/maps/patch523_world_links.gd")
const MANIFEST_SHA256="2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
const MAX_CACHED_LANDS=4
var loaded: bool=false
var root: String=""
var problem: String=""
var _lands: Dictionary={}
var _recent: Array[String]=[]

func load_pack(directory: String, expected_sha256: String) -> bool:
	if expected_sha256!=MANIFEST_SHA256: problem="원문 정의팩 SHA가 다릅니다."; return false
	if not _manifest_has_pin(directory): problem="원문 정의 manifest가 없거나 변경되었습니다."; return false
	var candidate:=OWNER.new()
	if not candidate.load_land(directory,0,"0/",expected_sha256): problem=candidate.problem; return false
	root=directory; loaded=true; problem=""; _lands.clear(); _recent.clear()
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
	var candidate:=OWNER.new()
	if not candidate.load_land(root,land_id,exact_asset,MANIFEST_SHA256): problem=candidate.problem; return null
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
	var expected_name: String={8:"NoTeleport",13:"NoTeleportCome"}.get(int(type.get("ID",-1)),"")
	if expected_name.is_empty() or type.get("Name")!=expected_name or type.get("UnitID")!=20: return false
	for key: String in ["Value","Param1","Param2","Param3"]:
		if not (row.get(key) is int or row.get(key) is float) or row[key]!=0: return false
	return true

func _attribute_holds(definition: RefCounted, land_id: int, point: Vector2i) -> Array:
	return _attribute_evaluation(definition,land_id,point).holds

func _attribute_evaluation(definition: RefCounted, land_id: int, point: Vector2i) -> Dictionary:
	var types: Dictionary={}
	for row: Dictionary in definition.context_rows("LandAttributeType"): types[int(row.ID)]=row
	var result: Array=[]
	var inactive: Array=[]
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
		# These declarations do not authorize entry or a teleport: this adapter
		# neither creates bookmarks nor changes depth/manner mechanics.
		if name in ["NoBookmark","Underground","IgnoreMannerMode"]: continue
		if _declared_inactive_restriction(type,row):
			inactive.append({"type":type.duplicate(true),"row":row.duplicate(true)}); continue
		result.append({"reason":"native_attribute_requires_policy","type":type.duplicate(true),"row":row.duplicate(true)})
	return {"holds":result,"declared_inactive":inactive}

func portal_context_for_land(land_id: int, exact_asset: String, portal_id: int) -> Dictionary:
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
	if territory.StartX!=territory.EndX or territory.StartY!=territory.EndY: holds.append({"reason":"native_region_arrival_policy_unverified"})
	var source_point:=Vector2i(int(portal.SourceX),int(portal.SourceY))
	var source_attributes: Dictionary=_attribute_evaluation(source,land_id,source_point)
	holds.append_array(source_attributes.holds)
	var inactive: Array=[]
	for item: Dictionary in source_attributes.declared_inactive:
		var evidence: Dictionary=item.duplicate(true); evidence["side"]="source"; inactive.append(evidence)
	if territory.StartX==territory.EndX and territory.StartY==territory.EndY:
		var target_attributes: Dictionary=_attribute_evaluation(target,int(target_land.ID),Vector2i(int(territory.StartX),int(territory.StartY)))
		holds.append_array(target_attributes.holds)
		for item: Dictionary in target_attributes.declared_inactive:
			var evidence: Dictionary=item.duplicate(true); evidence["side"]="target"; inactive.append(evidence)
	for table: String in ["LandTimeLimit","LandWeeklyOpenTime","CompetitionDungeonLand"]:
		for row: Dictionary in source.context_rows(table):
			var id: int=int(row.get("LandID",row.get("LandId",-1)))
			if id in [land_id,int(target_land.ID)]: holds.append({"reason":"native_land_condition_requires_policy","table":table,"row":row.duplicate(true)})
	return {"Portal":portal.duplicate(true),"SourceLand":source.land.duplicate(true),"TargetTerritory":territory.duplicate(true),"TargetLand":target_land.duplicate(true),"definition_manifest_sha256":MANIFEST_SHA256,"definition_owner":"PR230_PATCH523_WORLD_LINKS","native_definition_contract":contract.duplicate(true),"declared_inactive_restrictions":inactive,"source_travel_holds":holds,"source_travel_hold":"native_definition_conditions_require_policy" if not holds.is_empty() else "","native_m_rules_verified":false}

func cache_metrics() -> Dictionary:
	return {"cached_native_lands":_lands.size(),"maximum_native_lands":MAX_CACHED_LANDS,"definition_manifest_sha256":MANIFEST_SHA256 if loaded else ""}
