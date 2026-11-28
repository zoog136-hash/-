extends RefCounted
## The server identity that item paths check an original ServerLimitSetID
## against: the declared card-collection server context when one is set,
## otherwise the offline Korean world 1 profile
## (current523_map_runtime_context.OFFLINE_PROFILE) that map events and the
## shop calendar already use. Original ServerLimit rows take precedence.
const MAP_CONTEXT = preload("res://scripts/maps/current523_map_runtime_context.gd")
const SERVER_CONDITIONS = preload("res://scripts/cards/source_collection_conditions.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")

static func has_offline_fixed_card_rule(item_id: int, card_id: int, set_id: int) -> bool:
	# TWILIGHT approximation for the held mercenary reward 성십자단. ItemClass
	# 365402 names BuffCard 25252; the verified archive has no rows for set 274.
	return item_id == 365402 and card_id == 25252 and set_id == 274

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

## A verified fixed card may supply its exact item and card IDs for the one
## offline rule. All other callers use the original server table.
static func allows(world: Variant, set_id: Variant, item_id: int = 0, card_id: int = 0) -> Dictionary:
	if not _integer(set_id) or int(set_id) < 0: return {"ok":false,"reason":"원본 서버 세트 형식 오류"}
	if int(set_id) == 0: return {"ok":true}
	var rows: Array = SOURCE.related("ServerLimit","ServerLimitSetID",int(set_id))
	var current: Dictionary = profile(world)
	if rows.is_empty():
		if has_offline_fixed_card_rule(item_id,card_id,int(set_id)) and current == MAP_CONTEXT.OFFLINE_PROFILE:
			return {"ok":true,"profile":current}
		return {"ok":false,"reason":"원본 서버 세트 %d 정의 없음" % int(set_id)}
	if rows_allow(rows, str(current.ServiceRegionCode), int(current.WorldNo)): return {"ok":true,"profile":current}
	return {"ok":false,"reason":"원본 서버 조건 미충족 · %s %d서버 대상 아님" % [str(current.ServiceRegionCode), int(current.WorldNo)]}
