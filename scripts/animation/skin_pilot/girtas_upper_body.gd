extends RefCounted
## Girtas-only upper-body binding. Uses the supplied hit phase; owns no clock.
## These angles are authored retargeting choices, not measured source-game values.
static func curve(progress: float, hit: float, values: Array) -> float:
	var h := clampf(hit,0.1,0.85)
	return SharedGroundMotion._curve(progress,[0.0,h*0.55,h,h+(1.0-h)*0.22,1.0],values)
static func blend(progress: float) -> float:
	return smoothstep(0.0,0.12,progress)*(1.0-smoothstep(0.85,1.0,progress))
