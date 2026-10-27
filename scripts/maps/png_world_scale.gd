extends RefCounted
## Display units, not a PNG-to-server registration. All runtime geometry uses
## this same transform; source plans, packed image bytes and actor scale stay put.
const ADEN_SCALE: float=6.0
const ADEN_REVISION: int=2026102301
const FAITH_SCALE: float=1.3
const FAITH_REVISION: int=2026102401

static func map_scale(mid: String) -> float:
	return ADEN_SCALE if mid=="aden_world" else (FAITH_SCALE if mid in ["faith_01","faith_02","faith_03","faith_04"] else 1.0)

static func geometry(value: Variant, factor: float, key: String="", map_id: String="aden_world") -> Variant:
	if factor==1.0:return value
	if value is Dictionary:
		var row: Dictionary=value.duplicate(true)
		for raw: Variant in row:
			var name: String=str(raw)
			if name=="target_position" and row.has("target_map") and str(row.target_map)!=map_id:continue
			if name in ["radius","roaming_radius","spawn_radius","min_spacing","activation_distance"]:row[raw]=float(row[raw])*factor
			else:row[raw]=geometry(row[raw],factor,name,map_id)
		return row
	if value is Array:
		var rect: bool=key in ["rect","bounds"] and value.size()==4
		var point: bool=key in ["spawn","spawn_position","position","target_position","center","point","from","to","polygon","points","polygons","walk_polygons","route_checks","blocked_probes","waypoints","path","hunting_routes"] and value.size()==2
		if (rect or point) and value.all(func(n: Variant) -> bool:return n is int or n is float):
			var scaled: Array=[]
			for n: Variant in value:scaled.append(float(n)*factor)
			return scaled
		var result: Array=[]
		for child: Variant in value:result.append(geometry(child,factor,key,map_id))
		return result
	return value
