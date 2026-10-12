extends Node2D
class_name TwilightPlayerActionFX

# Read-only presentation. Never calls attack, modifies physics or awards damage.
const VISUALS = preload("res://scripts/animation/impact_visuals.gd")
var actor: TwilightPlayer
var clock: float = 0.0
var visuals = VISUALS.new()

func _ready() -> void:
	visuals.prepare()

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
		var center: Vector2 = to_local(actor.combat_hit_position())
		var fade: float = VISUALS.swing_envelope(phase, motion.attack_hit_ratio)
		var kind: String = VISUALS.family(motion.attack_style)
		match kind:
			"magic":
				var charge: float = sin(phase * PI) * 0.18 + fade * 0.5
				visuals.halo(self, center + aim * 18.0, Vector2.ONE * 46.0, Color(.59, .55, 1.0, charge))
				draw_arc(center, 18.0 + phase * 10.0, -phase, TAU - phase, 28, Color(.74, .73, 1.0, charge), 1.5, true)
			"arrow", "bullet":
				# A release glint only. The existing flight system owns the projectile.
				visuals.beam(self, center + aim * 30.0, aim, 13.0 if kind == "arrow" else 20.0, 2.2, Color(1.0, .93, .73, fade * .65))
			"thrust":
				visuals.beam(self, center + aim * (22.0 + phase * 18.0), aim, 24.0, 1.8, Color(1.0, .94, .80, fade * .72))
			_:
				var radius: float = 43.0 if kind == "heavy" else 35.0
				var tip: Vector2 = center + aim * 22.0
				visuals.crescent(self, tip, aim, radius, phase, Color(1.0, .62, .24, fade * .28))
				visuals.crescent(self, tip, aim, radius * .90, phase, Color(1.0, .96, .80, fade * .68))
		return
	if motion.move_ratio <= .10: return
	# Preserve the existing movement dust and gait clock.
	var stride: float = absf(sin(motion.gait * PI))
	var motion_alpha: float = clampf(motion.move_ratio*.35,0.0,.48)*stride
	var foot: Vector2 = Vector2(-7.0 if sin(motion.gait * PI)>0.0 else 7.0, 1.0)
	for i: int in range(3):
		var spread: float = float(i)*9.0
		var drift: Vector2 = -motion.direction * (6.0+spread)
		var point: Vector2 = foot + drift + motion.direction.orthogonal()*(float(i)-1.0)*7.0
		draw_circle(point, 3.0+float(i)*1.8, Color(.66,.57,.42,motion_alpha*(1.0-float(i)*.22)))
