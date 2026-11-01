extends RefCounted
## Girtas-only upper-body binding. Uses the supplied hit phase; owns no clock.
## These angles are authored retargeting choices, not measured source-game values.
static func curve(progress: float, hit: float, values: Array) -> float:
	var h := clampf(hit,0.1,0.85)
	var times := [0.0,h*0.55,h,h+(1.0-h)*0.22,1.0]
	# Monotone Hermite: retain every authored key (especially the hit phase),
	# but flow through keys that continue in the same direction. No overshoot.
	var slopes := [0.0,0.0,0.0,0.0,0.0]
	for i in range(1,4):
		var left: float = (values[i]-values[i-1])/(times[i]-times[i-1])
		var right: float = (values[i+1]-values[i])/(times[i+1]-times[i])
		if left*right>0.0:
			slopes[i] = 2.0*left*right/(left+right)
	for i in range(1,5):
		if progress<=times[i]:
			var span: float = times[i]-times[i-1]
			var t: float = clampf((progress-times[i-1])/span,0.0,1.0)
			return (2*t*t*t-3*t*t+1)*values[i-1]+(t*t*t-2*t*t+t)*span*slopes[i-1]+(-2*t*t*t+3*t*t)*values[i]+(t*t*t-t*t)*span*slopes[i]
	return values[-1]
static func blend(progress: float) -> float:
	return smoothstep(0.0,0.12,progress)*(1.0-smoothstep(0.85,1.0,progress))
