extends RefCounted
## Read-only endpoint bridge for copied authoritative native declarations.
## The caller owns provider authentication, manual activation and world changes.
## Clear endpoints establish only TWILIGHT's configured own movement policy.
const PACK = preload("res://scripts/maps/current523_source_pack.gd")
const FIELD = preload("res://scripts/maps/current523_source_field.gd")
const ACTIVATION_MODE = "TWILIGHT_OWN_MANUAL_DECLARED_POINT_V1"

static func _result(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"activation_mode":ACTIVATION_MODE,
		"native_m_rules_verified":false,"native_trigger_rules":"UNKNOWN"}

static func _uint(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value)==floorf(float(value)) and value>=0 and value<=maximum

static func _has_keys(row: Dictionary, keys: Array) -> bool:
	for key: String in keys:
		if not row.has(key): return false
	return true

static func _field_problem(field: RefCounted, record: Dictionary, catalog: RefCounted, pin: String) -> String:
	if not field is FIELD or not field.loaded or not field.has_meta("current523_generic_field") \
		or not field.has_meta("current523_source_field") or not field.coordinates.valid:
		return "field_unavailable"
	var land: Dictionary = record.declaration
	if field.catalog_sha256!=pin or field.definition.get("source_manifest_sha256")!=pin:
		return "field_manifest_mismatch"
	if field.native_land!=land or field.source_asset!=land.AssetPath \
		or field.definition.get("source_map_id")!=land.ID \
		or field.definition.get("source_asset_path")!=land.AssetPath:
		return "field_land_mismatch"
	var asset: Dictionary = catalog.asset_record(str(land.AssetPath))
	if asset.is_empty() or field.definition.get("source_sha256")!=asset.get("source_inventory_sha256"):
		return "field_inventory_mismatch"
	if field.uses_original_gameplay_rules() or field.policy.get("native_m_rules_verified")!=false:
		return "field_policy_unavailable"
	return ""

static func _endpoint_clear(field: RefCounted, cell: Vector2i, info: Dictionary) -> bool:
	if info.get("status")!="allowed" or info.get("walkable")!=true or info.get("source_cell")!=cell \
		or info.get("native_m_rules_verified")!=false or info.get("own_profile")!=str(field.policy.get("profile",field.OWN_PROFILE)):
		return false
	var member: Variant = info.get("member")
	if not member is String or not member.begins_with(PACK._asset_root(field.source_asset)): return false
	var origin: Variant = PACK.candidate_origin(member)
	if not origin is Vector2i or field.source_chunk_origins().get(member)!=origin \
		or info.get("local_cell")!=cell-origin: return false
	var metadata: Dictionary = field.source_metadata(member)
	if metadata.get("status")!="ready" or metadata.get("asset_path")!=field.source_asset \
		or metadata.get("sha256")!=info.get("source_sha256") \
		or not PACK.S32_FORMAT._sha(info.get("source_sha256")): return false
	var attributes: Variant = info.get("raw_pair")
	var floors: Variant = info.get("floor_pair")
	if not attributes is Array or attributes.size()!=2 or not floors is Array or floors.size()!=2: return false
	for word: Variant in attributes:
		if not _uint(word,65534): return false
	for reference: Variant in floors:
		if not _uint(reference,4294967294): return false
	# This is the field's existing actor-clearance predicate, never trigger radius.
	return field.point_clear(field.coordinates.to_world(Vector2(cell)),4.0)

static func plan(context: Dictionary, catalog: RefCounted, source_field: RefCounted,
		target_field: RefCounted, actor_source_cell: Vector2i, expected_manifest_sha256: String) -> Dictionary:
	if not PACK.S32_FORMAT._sha(expected_manifest_sha256): return _result("manifest_pin_invalid")
	if not catalog is PACK or not catalog.catalog_loaded: return _result("catalog_unavailable")
	var identity: Dictionary = catalog.catalog_identity()
	if identity.get("manifest_sha256")!=expected_manifest_sha256 \
		or identity.get("native_land_table_sha256")!=PACK.LAND_SHA256:
		return _result("catalog_manifest_mismatch")
	for key: String in ["Portal","SourceLand","TargetTerritory","TargetLand"]:
		if not context.get(key) is Dictionary: return _result("context_incomplete")
	var portal: Dictionary = context.Portal
	var territory: Dictionary = context.TargetTerritory
	if not _has_keys(portal,["ID","SourceLandID","SourceX","SourceY","AssetID","TargetTerritoryID"]) \
		or not _has_keys(territory,["ID","Name","DescID","LandID","StartX","StartY","EndX","EndY", \
			"ShowInSourceList","IsVillage","CanMoveToEarthObject"]): return _result("context_incomplete")
	for key: String in ["ID","SourceLandID","AssetID","TargetTerritoryID"]:
		if not _uint(portal.get(key),2147483647): return _result("context_value_invalid")
	for key: String in ["ID","LandID","DescID"]:
		if not _uint(territory.get(key),2147483647): return _result("context_value_invalid")
	for key: String in ["SourceX","SourceY"]:
		if not _uint(portal.get(key),65535): return _result("context_value_invalid")
	for key: String in ["StartX","StartY","EndX","EndY"]:
		if not _uint(territory.get(key),65535): return _result("context_value_invalid")
	if portal.TargetTerritoryID!=territory.ID or context.SourceLand.get("ID")!=portal.SourceLandID \
		or context.TargetLand.get("ID")!=territory.LandID: return _result("context_join_mismatch")
	var source_record: Dictionary = catalog.land_record(int(portal.SourceLandID))
	var target_record: Dictionary = catalog.land_record(int(territory.LandID))
	if source_record.is_empty() or target_record.is_empty(): return _result("land_unknown")
	for record: Dictionary in [source_record,target_record]:
		if record.get("policy_status")!="classified" or not record.get("excluded_content",["unknown"]).is_empty():
			return _result("land_scope_blocked")
	if context.SourceLand!=source_record.declaration or context.TargetLand!=target_record.declaration:
		return _result("context_land_mismatch")
	var definition_hold: Variant=context.get("source_travel_hold","")
	if not definition_hold is String: return _result("definition_hold_invalid")
	if not definition_hold.is_empty(): return _result("definition_conditions_hold: "+definition_hold)
	if territory.StartX>territory.EndX or territory.StartY>territory.EndY:
		return _result("target_territory_inverted")
	var source := Vector2i(int(portal.SourceX),int(portal.SourceY))
	var target := Vector2i(int(territory.StartX),int(territory.StartY))
	var arrival_policy: String="EXACT_POINT_ONLY"
	if territory.StartX!=territory.EndX or territory.StartY!=territory.EndY:
		if context.get("own_arrival_policy")!="OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1":return _result("target_territory_not_point")
		var selected: Variant=context.get("own_arrival_source_cell")
		if not selected is Array or selected.size()!=2 or not _uint(selected[0],65535) or not _uint(selected[1],65535):return _result("own_arrival_cell_invalid")
		target=Vector2i(int(selected[0]),int(selected[1]))
		if target.x<territory.StartX or target.x>territory.EndX or target.y<territory.StartY or target.y>territory.EndY:return _result("own_arrival_outside_declared_territory")
		arrival_policy="OWN_FIRST_CLEAR_IN_DECLARED_REGION_V1"
	if actor_source_cell!=source: return _result("actor_not_at_declared_portal")
	var problem: String = _field_problem(source_field,source_record,catalog,expected_manifest_sha256)
	if not problem.is_empty(): return _result("source_"+problem)
	problem = _field_problem(target_field,target_record,catalog,expected_manifest_sha256)
	if not problem.is_empty(): return _result("target_"+problem)
	if source_field.catalog_root!=target_field.catalog_root: return _result("field_catalog_root_mismatch")
	if source_field.policy!=target_field.policy: return _result("field_policy_mismatch")
	var source_info: Dictionary = source_field.source_cell_info(source)
	if not _endpoint_clear(source_field,source,source_info): return _result("source_endpoint_blocked")
	var target_info: Dictionary = target_field.source_cell_info(target)
	if not _endpoint_clear(target_field,target,target_info): return _result("target_endpoint_blocked")
	return {"ok":true,"reason":"","portal_id":int(portal.ID),"source_land_id":int(portal.SourceLandID),
		"target_land_id":int(territory.LandID),"source_position":source,"target_position":target,
		"source_info":source_info.duplicate(true),"target_info":target_info.duplicate(true),"context":context.duplicate(true),
		"landing_selection_policy":arrival_policy,"native_landing_rule_verified":false,
		"activation_mode":ACTIVATION_MODE,"native_m_rules_verified":false,"native_trigger_rules":"UNKNOWN"}
