extends Node2D
class_name TwilightSkillSummonActor

## Independently drawn creature. The service drives both pose and hit markers.
var age: float = 0
var walking: bool = false
var facing: Vector2 = Vector2.RIGHT
var strike_phase: float = -1
var recovery_remaining: float = 0
var recovery_duration: float = 0
var just_struck: bool = false
var tint: Color = Color(0.35,0.78,1.0)

func update_pose(delta: float, moving: bool, direction: Vector2, attack_phase: float) -> void:
	age += delta
	walking = moving
	if direction.length_squared() > .01: facing = direction.normalized()
	if not just_struck: recovery_remaining = maxf(0,recovery_remaining-delta)
	just_struck = false
	strike_phase = recovery_remaining/maxf(.001,recovery_duration) if recovery_remaining > 0 else attack_phase
	queue_redraw()

func finish_strike(duration: float) -> void:
	recovery_duration = duration
	recovery_remaining = duration
	strike_phase = 1
	just_struck = true
	queue_redraw()

func _draw() -> void:
	var fade := minf(1,age*3)
	var bob := sin(age*(11 if walking else 2))*(3 if walking else 1)
	var center := Vector2(0,-28+bob)
	var dark := Color(tint.darkened(.72),fade)
	var light := Color(tint.lightened(.3),fade)
	var outline := Color(.02,.07,.12,fade)
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.35))
	draw_circle(Vector2.ZERO,22,Color(0,0,0,.3*fade))
	draw_set_transform(Vector2.ZERO)
	var stride := sin(age*11)*7 if walking else 0.0
	for leg: int in range(2):
		var x := -9.0 if leg == 0 else 9.0
		var foot := Vector2(x+stride*(-1 if leg == 0 else 1),-3)
		draw_line(center+Vector2(x,10),foot,outline,13,true)
		draw_line(center+Vector2(x,10),foot,dark,9,true)
	var body := PackedVector2Array([center+Vector2(-18,-11),center+Vector2(0,-19),center+Vector2(18,-11),center+Vector2(13,17),center+Vector2(-13,17)])
	draw_colored_polygon(body,dark)
	var closed := body.duplicate();closed.append(body[0])
	draw_polyline(closed,light,2,true)
	draw_line(center+Vector2(0,-13),center+Vector2(0,14),light,3,true)
	draw_circle(center+Vector2(0,-24),10,outline)
	draw_circle(center+Vector2(0,-24),8,dark)
	draw_line(center+Vector2(-7,-25),center+Vector2(7,-25),light,3,true)
	var punch := pow(clampf(strike_phase,0,1),3)*25 if strike_phase >= 0 else 0.0
	var hand := center+Vector2(21,0)+facing*punch
	draw_line(center+Vector2(14,-9),hand,outline,12,true)
	draw_line(center+Vector2(14,-9),hand,light,7,true)
	draw_circle(hand,5,light)
	var shield := center+Vector2(-23,0)
	var vertices := PackedVector2Array([shield+Vector2(-10,-13),shield+Vector2(10,-13),shield+Vector2(9,7),shield+Vector2(0,18),shield+Vector2(-9,7),shield+Vector2(-10,-13)])
	draw_colored_polygon(vertices,dark)
	draw_polyline(vertices,light,2,true)
	for spark: int in range(4):
		var position := center+Vector2(cos(age*1.4+spark*TAU/4)*31,sin(age*1.4+spark*TAU/4)*12-10)
		draw_circle(position,1.5,Color(tint,.5*fade))
