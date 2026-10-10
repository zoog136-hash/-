extends Node2D
class_name TwilightPlayerActionFX

# Read-only presentation. Never calls attack, modifies physics or awards damage.
var actor: TwilightPlayer
var clock: float = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(actor): return
	clock += delta
	visible = actor.motion.active or actor.motion.move_ratio > .10
	if visible: queue_redraw()

func _draw() -> void:
	if not is_instance_valid(actor): return
	var motion: TwilightActorMotion = actor.motion
	if motion.active:
		var phase: float = clampf(motion.visual_progress, 0.0, 1.0)
		var aim: Vector2 = motion.direction.normalized()
		if aim.length_squared() < .1: aim = Vector2.DOWN
		var direction_angle: float = aim.angle()
		var center := Vector2(0.0, -48.0)
		var fade: float = sin(phase * PI)
		if motion.attack_style in ["magic", "staff"]:
			var radius: float = 19.0 + phase * 31.0
			draw_arc(center, radius, 0.0, TAU, 36, Color(.60,.48,1.0,.65*fade), 3.2, true)
			draw_arc(center, radius*.75, 0.0, TAU, 28, Color(.92,.80,1.0,.40*fade), 2.0, true)
		elif motion.attack_style == "bow":
			var tip: Vector2 = center + aim * (30.0 + phase * 34.0)
			draw_line(center,tip,Color(1.0,.86,.50,.88*fade),3.0,true)
			draw_circle(tip,4.5,Color(1.0,.94,.73,.8*fade))
		else:
			var start_angle: float = direction_angle - 1.15 + phase * 1.85
			var end_angle: float = start_angle + .88
			draw_arc(center + aim*11.0, 35.0, start_angle,end_angle,22,Color(1.0,.83,.41,.84*fade),5.0,true)
			draw_arc(center + aim*11.0, 40.0, start_angle+.12,end_angle-.12,18,Color(1.0,1.0,.86,.53*fade),2.0,true)
		return
	if motion.move_ratio <= .10: return
	# Footfalls read the same gait clock as the movement sheet. Lightweight
	# ground dust distinguishes fast travel from idle without sprite replacements.
	var stride: float = absf(sin(motion.gait * PI))
	var motion_alpha: float = clampf(motion.move_ratio*.35,0.0,.48)*stride
	var foot: Vector2 = Vector2(-7.0 if sin(motion.gait * PI)>0.0 else 7.0, 1.0)
	for i: int in range(3):
		var spread: float = float(i)*9.0
		var drift: Vector2 = -motion.direction * (6.0+spread)
		var point: Vector2 = foot + drift + motion.direction.orthogonal()*(float(i)-1.0)*7.0
		draw_circle(point, 3.0+float(i)*1.8, Color(.66,.57,.42,motion_alpha*(1.0-float(i)*.22)))
