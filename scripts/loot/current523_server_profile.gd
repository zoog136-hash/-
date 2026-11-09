extends RefCounted
## The server identity that item paths check an original ServerLimitSetID
## against: the declared card-collection server context when one is set,
## otherwise the offline Korean world 1 profile
## (current523_map_runtime_context.OFFLINE_PROFILE) that map events and the
## shop calendar already use. A set allows the profile only when one of its
## original ServerLimit rows names the same ServiceRegionCode and WorldNo; a set
## without rows is not resolved and stays closed. Nothing here bypasses a set.
const MAP_CONTEXT = preload("res://scripts/maps/current523_map_runtime_context.gd")
const SERVER_CONDITIONS = preload("res://scripts/cards/source_collection_conditions.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value))

static func profile(world: Variant) -> Dictionary:
	var collections: Variant = world.get("card_collections") if world is Object and is_instance_valid(world) else null
	if collections is Object and is_instance_valid(collections) and collections.has_method("source_server_context"):
		var declared: Variant = collections.call("source_server_context")
		if declared is Dictionary and SERVER_CONDITIONS.valid_context(declared): return declared.duplicate(true)
	return MAP_CONTEXT.OFFLINE_PROFILE.duplicate()

## Whether ServerLimit rows of one set name this region and world.
static func rows_allow(rows: Array, region: String, world_no: int) -> bool:
	for row: Variant in rows:
		if row is Dictionary and str(row.get("ServiceRegionCode","")) == region and _integer(row.get("WorldNo")) and int(row.WorldNo) == world_no: return true
	return false

## {ok:true} for set 0 or a set whose original rows name the current profile;
## otherwise {ok:false, reason} (item kept by the caller).
static func allows(world: Variant, set_id: Variant) -> Dictionary:
	if not _integer(set_id) or int(set_id) < 0: return {"ok":false,"reason":"원본 서버 세트 형식 오류"}
	if int(set_id) == 0: return {"ok":true}
	var rows: Array = SOURCE.related("ServerLimit","ServerLimitSetID",int(set_id))
	if rows.is_empty(): return {"ok":false,"reason":"원본 서버 세트 %d 정의 없음" % int(set_id)}
	var current: Dictionary = profile(world)
	if rows_allow(rows, str(current.ServiceRegionCode), int(current.WorldNo)): return {"ok":true,"profile":current}
	return {"ok":false,"reason":"원본 서버 조건 미충족 · %s %d서버 대상 아님" % [str(current.ServiceRegionCode), int(current.WorldNo)]}
