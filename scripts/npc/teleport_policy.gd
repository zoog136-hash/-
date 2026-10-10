extends RefCounted
# TWILIGHT offline transit policy. This is LOCAL gameplay balancing, not an
# imported L1J teleport price table. No existing collision, map or portal data
# is rewritten. The world performs the final map load before gold is charged.

static func _rule(map_id: String) -> Dictionary:
	if map_id == "aden_world":
		return {"min_level":1, "price":0}
	if map_id.begins_with("oman_"):
		var floor_number: int = int(map_id.trim_prefix("oman_"))
		return {"min_level":20 + floor_number * 5, "price":1000 + floor_number * 500}
	if map_id.begins_with("faith_"):
		return {"min_level":45, "price":3000}
	if map_id == "domination_summit":
		return {"min_level":70, "price":12000}
	return {"min_level":20, "price":1500}

static func quote(map_id: String, maps_by_id: Dictionary, current_map_id: String, level: int, wallet: int) -> Dictionary:
	if not maps_by_id.has(map_id):
		return {"ok":false, "reason":"존재하지 않는 이동 목적지입니다"}
	if current_map_id == map_id:
		return {"ok":false, "reason":"이미 이 지역에 있습니다"}
	var entry: Variant = maps_by_id[map_id]
	if not (entry is Dictionary) or str((entry as Dictionary).get("id", "")) != map_id:
		return {"ok":false, "reason":"목적지 데이터가 유효하지 않습니다"}
	var rule: Dictionary = _rule(map_id)
	var required: int = int(rule["min_level"])
	var cost: int = int(rule["price"])
	if level < required:
		return {"ok":false, "reason":"이 지역은 %d레벨부터 이동 가능합니다" % required}
	if wallet < cost:
		return {"ok":false, "reason":"아데나가 부족합니다"}
	return {"ok":true, "map_id":map_id, "price":cost, "min_level":required}
