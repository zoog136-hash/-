extends RefCounted
## Rejected v7 hand-target experiment, retained for diagnosis only.
## Current E/S bindings do not use this path; do not reuse as the shared motion.
## Shoulder-relative 2D hand targets. The authoritative attack clock is supplied.
## No elapsed time, skin clock, frame duplication, or movement-speed changes.
static func solve_elbow(shoulder: Vector2, hand: Vector2, upper: float, lower: float, bend: float = 1.0) -> Vector2:
	var offset := hand-shoulder
	var d := clampf(offset.length(),absf(upper-lower)+0.01,upper+lower-0.01)
	var axis := offset.normalized()
	var along := (upper*upper-lower*lower+d*d)/(2.0*d)
	var height := sqrt(maxf(0.0,upper*upper-along*along))
	return shoulder+axis*along+Vector2(-axis.y,axis.x)*height*bend
static func curve(progress: float, hit: float, values: Array) -> float:
	var h := clampf(hit,0.1,0.85)
	return SharedGroundMotion._curve(progress,[0.0,h*0.55,h,h+(1.0-h)*0.22,1.0],values)
static func attack_hand(progress: float, hit: float, rest: Vector2, direction: String, near: bool) -> Vector2:
	var points: Array
	if direction=="E":
		points=[rest,Vector2(-4,-17),Vector2(18,1),Vector2(14,8),rest] if near else [rest,Vector2(2,-10),Vector2(-3,-2),Vector2(2,8),rest]
	else:
		points=[rest,Vector2(4,-17),Vector2(12,10),Vector2(8,14),rest] if near else [rest,Vector2(-5,-7),Vector2(-7,2),Vector2(-3,8),rest]
	var xs: Array=[];var ys: Array=[]
	for p: Vector2 in points:xs.append(p.x);ys.append(p.y)
	return Vector2(curve(progress,hit,xs),curve(progress,hit,ys))
static func run_hand(arm: float, direction: String, side: int) -> Vector2:
	var drive := clampf(-arm/0.32,-1.0,1.0)
	if direction=="E":return Vector2(8.0+4.0*drive,-3.0-drive)
	var sign_x := 1.0 if side==0 else -1.0
	return Vector2(-sign_x*(7.0+2.0*drive),-4.0+3.0*drive)
