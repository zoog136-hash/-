extends SceneTree
## Authored guard fixtures never establish native declarations or resource delivery.
## Optional actual checks require caller pins for both source523.json and handoff.
const TRAVEL = preload("res://scripts/maps/current523_source_travel.gd")
const PACK = preload("res://scripts/maps/current523_source_pack.gd")
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
const PIN = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
var checks: int = 0
var failures: Array[String] = []
var actual_evidence: Dictionary = {}

class FixtureCatalog extends PACK:
	func prepare(source: Dictionary, target: Dictionary) -> void:
		catalog_loaded=true; _manifest_sha256=PIN
		for land: Dictionary in [source,target]:
			_lands[int(land.ID)]={"declaration":land.duplicate(true),"policy_status":"classified","excluded_content":[]}
			_assets[land.AssetPath]={"source_inventory_sha256":"b".repeat(64)}

class FixtureField extends FIELD:
	var infos: Dictionary = {}
	var metadata: Dictionary = {}
	var queries: Array[Vector2i] = []
	var fixture_clearance: bool = true
	func prepare(land: Dictionary, cell: Vector2i) -> void:
		loaded=true; native_land=land.duplicate(true); source_asset=land.AssetPath
		catalog_root="AUTHORED_FIXTURE_ONLY"; catalog_sha256=PIN
		definition={"source_map_id":land.ID,"source_asset_path":source_asset,
			"source_manifest_sha256":PIN,"source_sha256":"b".repeat(64)}
		_configure_policy({"allowed_raw_words":[0,4,8,12,32]})
		coordinates.configure([32768,32768],[64,64],policy.coordinate_mapping)
		set_meta("current523_generic_field",true); set_meta("current523_source_field",true)
		var member: String="Map/"+source_asset+"80008000.s32"
		source_origins[member]=Vector2i(32768,32768)
		infos[cell]={"source_cell":cell,"member":member,"source_sha256":"c".repeat(64),
			"local_cell":cell-Vector2i(32768,32768),"raw_pair":[0,0],"floor_pair":[0,1],
			"status":"allowed","walkable":true,"own_profile":OWN_PROFILE,"native_m_rules_verified":false}
		metadata[member]={"asset_path":source_asset,"status":"ready","sha256":"c".repeat(64)}
	func source_cell_info(cell: Vector2i) -> Dictionary:
		queries.append(cell)
		return infos.get(cell,{}).duplicate(true)
	func source_metadata(member: String) -> Dictionary: return metadata.get(member,{}).duplicate(true)
	func point_clear(_point: Vector2, _padding: float=4.0) -> bool: return fixture_clearance

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message)

func argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	_fixtures()
	var root: String=argument("--pack-root=")
	var pin: String=argument("--manifest-sha=")
	var handoff: String=argument("--handoff=")
	var handoff_pin: String=argument("--handoff-sha=")
	if not root.is_empty(): _actual(root,pin,handoff,handoff_pin)
	else: check(pin.is_empty() and handoff.is_empty() and handoff_pin.is_empty(),"actual inputs require source root plus both explicit pins")
	print("CURRENT523_SOURCE_TRAVEL_RESULT "+JSON.stringify({"checks":checks,"failures":failures,
		"fixture_only":root.is_empty(),"actual_source_evidence":actual_evidence,"native_m_rules_verified":false,"render_verified":false}))
	quit(0 if failures.is_empty() else 1)

func context() -> Dictionary:
	return {"Portal":{"ID":7,"SourceLandID":1,"SourceX":32778,"SourceY":32779,"AssetID":0,"TargetTerritoryID":90},
		"SourceLand":{"ID":1,"Name":"AUTHORED SOURCE","AssetPath":"fixture_one/","LandChannelTypeID":0,
			"IdealNumberOfPlayer":0,"BackgroundTypeId":0,"ExcludeManner":false,"ContentDirectionID":0,"ContentInstanceID":0},
		"TargetTerritory":{"ID":90,"Name":"AUTHORED POINT","DescID":0,"LandID":2,
			"StartX":32780,"StartY":32781,"EndX":32780,"EndY":32781,
			"ShowInSourceList":true,"IsVillage":false,"CanMoveToEarthObject":false},
		"TargetLand":{"ID":2,"Name":"AUTHORED TARGET","AssetPath":"fixture_two/","LandChannelTypeID":0,
			"IdealNumberOfPlayer":0,"BackgroundTypeId":0,"ExcludeManner":false,"ContentDirectionID":0,"ContentInstanceID":0}}

func fixture() -> Dictionary:
	var copy: Dictionary=context()
	var catalog=FixtureCatalog.new(); catalog.prepare(copy.SourceLand,copy.TargetLand)
	var source=FixtureField.new(); source.prepare(copy.SourceLand,Vector2i(32778,32779))
	var target=FixtureField.new(); target.prepare(copy.TargetLand,Vector2i(32780,32781))
	return {"context":copy,"catalog":catalog,"source":source,"target":target,"cell":Vector2i(32778,32779)}

func run_plan(value: Dictionary, pin: String=PIN) -> Dictionary:
	return TRAVEL.plan(value.context,value.catalog,value.source,value.target,value.cell,pin)

func _fixtures() -> void:
	var f: Dictionary=fixture()
	var result: Dictionary=run_plan(f)
	check(result.get("ok",false) and result.source_land_id==1 and result.target_land_id==2
		and result.target_position==Vector2i(32780,32781),"authored cross-Land bridge returns exact declared point")
	check(f.source.queries==[Vector2i(32778,32779)] and f.target.queries==[Vector2i(32780,32781)],"actual source and target fields queried independently")
	check(not result.native_m_rules_verified and result.native_trigger_rules=="UNKNOWN"
		and result.activation_mode==TRAVEL.ACTIVATION_MODE,"own manual readiness never claims native activation")
	check(not result.has("cost") and not result.has("radius") and not result.has("reverse_portal"),"planner supplies no inferred fee, radius or reverse edge")
	result.context.Portal.SourceX=0; result.source_info.raw_pair[0]=32
	check(f.context.Portal.SourceX==32778 and f.source.infos[f.cell].raw_pair==[0,0],"returned context and endpoint evidence are deep copies")
	f.context.SourceLand.Name="changed after plan"
	check(result.context.SourceLand.Name=="AUTHORED SOURCE","caller mutation cannot alter returned context")
	f=fixture(); f.cell+=Vector2i.RIGHT
	check(run_plan(f).reason=="actor_not_at_declared_portal" and f.source.queries.is_empty(),"adjacent actor cell denied without invented radius")
	check(run_plan(f,"").reason=="manifest_pin_invalid","missing caller manifest pin denied")
	f=fixture(); check(run_plan(f,"d".repeat(64)).reason=="catalog_manifest_mismatch","catalog must match caller pin")
	f=fixture(); f.catalog.catalog_loaded=false
	check(run_plan(f).reason=="catalog_unavailable","unloaded catalog denied")
	for key: String in ["Portal","SourceLand","TargetTerritory","TargetLand"]:
		f=fixture(); f.context.erase(key)
		check(run_plan(f).reason=="context_incomplete","missing copied full row denied: "+key)
	f=fixture(); f.context.TargetTerritory.erase("Name")
	check(run_plan(f).reason=="context_incomplete","truncated Territory row denied")
	for bad: Variant in [-1,65536,1.5,INF,"32778"]:
		f=fixture(); f.context.Portal.SourceX=bad
		check(run_plan(f).reason=="context_value_invalid","invalid declaration coordinate denied: "+str(bad))
	f=fixture(); f.context.Portal.TargetTerritoryID=91
	check(run_plan(f).reason=="context_join_mismatch","Portal to Territory join must be exact")
	f=fixture(); f.context.TargetLand.ID=3
	check(run_plan(f).reason=="context_join_mismatch","Territory to target Land join must be exact")
	f=fixture(); f.context.SourceLand.Name="same ID, altered row"
	check(run_plan(f).reason=="context_land_mismatch","full source Land row compared with catalog")
	f=fixture(); f.context.TargetLand.AssetPath="2/"
	check(run_plan(f).reason=="context_land_mismatch","numeric logical ID never substitutes physical AssetPath")
	f=fixture(); f.catalog._lands.erase(2)
	check(run_plan(f).reason=="land_unknown","missing logical Land denied")
	for endpoint: int in [1,2]:
		for scope: String in ["excluded","unclassified"]:
			f=fixture()
			if scope=="excluded": f.catalog._lands[endpoint].excluded_content=["siege"]
			else: f.catalog._lands[endpoint].policy_status="unclassified"
			check(run_plan(f).reason=="land_scope_blocked","scope checked at both logical ends: "+str(endpoint)+scope)
	f=fixture(); f.context.TargetTerritory.EndX+=1
	check(run_plan(f).reason=="target_territory_not_point","rectangle has no invented center or selected corner")
	f=fixture(); f.context.TargetTerritory.EndY-=1
	check(run_plan(f).reason=="target_territory_inverted","inverted Territory remains unnormalized")
	for side: String in ["source","target"]:
		f=fixture(); f[side]=null
		check(run_plan(f).reason==side+"_field_unavailable","missing actual field denied: "+side)
		f=fixture(); f[side].catalog_sha256="d".repeat(64)
		check(run_plan(f).reason==side+"_field_manifest_mismatch","both fields must share caller manifest pin: "+side)
		f=fixture(); f[side].native_land.Name="changed"
		check(run_plan(f).reason==side+"_field_land_mismatch","field must retain exact native declaration: "+side)
		f=fixture(); f[side].definition.source_sha256="d".repeat(64)
		check(run_plan(f).reason==side+"_field_inventory_mismatch","field per-asset inventory must match catalog: "+side)
		for status: String in ["policy_blocked","unknown_attribute","floor_sentinel","source_integrity_failure","unregistered_chunk","outside_source_bounds"]:
			f=fixture(); var cell: Vector2i=f[side].infos.keys()[0]
			f[side].infos[cell].status=status; f[side].infos[cell].walkable=false
			check(run_plan(f).reason==side+"_endpoint_blocked","endpoint status denied: "+side+status)
		for bad_info: String in ["hash","member","local_cell","raw_pair","floor_pair","clearance"]:
			f=fixture(); var cell: Vector2i=f[side].infos.keys()[0]
			match bad_info:
				"hash": f[side].infos[cell].source_sha256="d".repeat(64)
				"member": f[side].infos[cell].member="Map/other/80008000.s32"
				"local_cell": f[side].infos[cell].local_cell=Vector2i.ZERO
				"raw_pair": f[side].infos[cell].raw_pair=[0,65535]
				"floor_pair": f[side].infos[cell].floor_pair=[0,4294967295]
				"clearance": f[side].fixture_clearance=false
			check(run_plan(f).reason==side+"_endpoint_blocked","invalid actual support denied: "+side+bad_info)
	f=fixture(); f.target.catalog_root="another root"
	check(run_plan(f).reason=="field_catalog_root_mismatch","different catalog roots are not interchangeable")
	f=fixture(); f.target.policy.allowed_raw_words=[0,1]
	check(run_plan(f).reason=="field_policy_mismatch","target cannot silently widen configured own policy")
	# Distinct logical Lands may intentionally share the exact physical root.
	f=fixture(); f.context.TargetLand.AssetPath=f.context.SourceLand.AssetPath
	f.catalog.prepare(f.context.SourceLand,f.context.TargetLand)
	f.target=FixtureField.new(); f.target.prepare(f.context.TargetLand,Vector2i(32780,32781))
	result=run_plan(f)
	check(result.get("ok",false) and result.source_land_id!=result.target_land_id,"shared physical root never merges logical Land identities")

func _actual(root: String, pin: String, path: String, handoff_pin: String) -> void:
	check(PACK.S32_FORMAT._sha(pin) and PACK.S32_FORMAT._sha(handoff_pin) and not path.is_empty(),"actual source and handoff pins are explicit")
	if not PACK.S32_FORMAT._sha(pin) or not PACK.S32_FORMAT._sha(handoff_pin) or path.is_empty(): return
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
	check(not bytes.is_empty() and PACK._hash(bytes)==handoff_pin,"private authoritative handoff matches caller pin")
	if bytes.is_empty() or PACK._hash(bytes)!=handoff_pin: return
	var rows: Variant=JSON.parse_string(bytes.get_string_from_utf8())
	check(rows is Array and rows.size()==1150,"all1150 copied declaration contexts available")
	if not rows is Array or rows.size()!=1150: return
	var catalog=PACK.new()
	check(catalog.load_catalog(root,pin),"actual caller-pinned generic catalog loads: "+catalog.problem)
	if not catalog.catalog_loaded: return
	var evidence: Array=[]
	for id: int in [1101,523]:
		var copy: Dictionary={}
		for row: Variant in rows:
			if row is Dictionary and row.get("Portal") is Dictionary and row.Portal.get("ID")==id: copy=row.duplicate(true); break
		check(not copy.is_empty(),"exact native Portal context found: "+str(id))
		if copy.is_empty(): continue
		var source=FIELD.new(); var target=FIELD.new()
		check(source.configure_catalog(root,pin,int(copy.SourceLand.ID)),"actual source field loads: "+str(id)+source.problem)
		check(target.configure_catalog(root,pin,int(copy.TargetLand.ID)),"actual target field loads: "+str(id)+target.problem)
		var cell:=Vector2i(int(copy.Portal.SourceX),int(copy.Portal.SourceY))
		var result: Dictionary=TRAVEL.plan(copy,catalog,source,target,cell,pin)
		if id==1101:
			check(result.get("ok",false) and result.target_position==Vector2i(32477,32855)
				and result.source_land_id==1 and result.target_land_id==0,"Portal1101 exact native point passes both actual own-policy fields")
			if result.get("ok",false):
				check(result.source_info.raw_pair==[0,0] and result.target_info.raw_pair==[0,0],"Portal1101 actual raw pairs are explicit zeros")
				evidence.append(result)
		else:
			check(result.get("reason")=="source_endpoint_blocked","Portal523 remains blocked without widening default own policy")
			var target_cell:=Vector2i(int(copy.TargetTerritory.StartX),int(copy.TargetTerritory.StartY))
			check(source.source_cell_info(cell).raw_pair==[0,1] and target.source_cell_info(target_cell).raw_pair==[0,1],"Portal523 actual source and target both contain unlisted word1")
			result.source_info=source.source_cell_info(cell); result.target_info=target.source_cell_info(target_cell)
			result.portal_id=id; evidence.append(result)
		source.close(); target.close()
	actual_evidence={"manifest_sha256":pin,"handoff_sha256":handoff_pin,"portals":evidence}
