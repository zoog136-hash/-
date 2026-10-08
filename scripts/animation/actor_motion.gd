extends RefCounted
class_name TwilightActorMotion

const PROFILE = preload("res://scripts/animation/animation_profile.gd")
signal strike(sequence: int)
signal cancelled(sequence: int)

var profile: TwilightAnimationProfile = PROFILE.new()
var state: String = "idle"
var direction: Vector2 = Vector2.DOWN
var facing8: int = 2 # clockwise: E, SE, S, SW, W, NW, N, NE
var facing4: int = 0 # legacy D,U,L,R
var sequence: int = 0
var attack_elapsed: float = 0.0
var attack_duration: float = 0.0
var attack_hit_ratio: float = 0.44
var attack_style: String = "slash"
var released: bool = false
var active: bool = false
var dead: bool = false
var death_clock: float = 0.0
var hit_clock: float = 0.0
var turn_clock: float = 0.0
var gait: float = 0.0
var idle_clock: float = 0.0
var visual_hold: float = 0.0
var visual_progress: float = 0.0
var move_ratio: float = 0.0

func face(vector: Vector2) -> void:
	if vector.length_squared() < 0.01: return
	var next: int = posmod(int(round(vector.angle() / (PI / 4.0))), 8)
	if next != facing8: turn_clock = 0.09
	facing8 = next
	direction = vector.normalized()
	if absf(vector.x) > absf(vector.y):
		facing4 = 2 if vector.x < 0.0 else 3
	else:
		facing4 = 1 if vector.y < 0.0 else 0

func begin_attack(total: float, aim: Vector2, style: String = "", marker: float = -1.0) -> int:
	cancel_attack()
	face(aim)
	sequence += 1
	attack_elapsed = 0.0
	attack_duration = maxf(0.06, total)
	attack_style = profile.motion_style if style.is_empty() else style
	attack_hit_ratio = profile.attack_hit_ratio if marker < 0.0 else clampf(marker, 0.1, 0.85)
	active = true
	released = false
	visual_hold = 0.0
	visual_progress = 0.0
	state = "attack"
	return sequence

func cancel_attack() -> void:
	if active: cancelled.emit(sequence)
	active = false
	attack_duration = 0.0
	attack_elapsed = 0.0
	visual_hold = 0.0
	state = "idle"

func react(critical: bool = false) -> void:
	hit_clock = 0.13 if critical else 0.085
	# Pose freeze only: physics, cooldowns and attack markers are never paused.
	visual_hold = 0.028 if critical else 0.0

func die() -> void:
	cancel_attack()
	dead = true
	death_clock = 0.0
	state = "death"

func advance(delta: float, real_velocity: Vector2) -> void:
	idle_clock += delta
	hit_clock = maxf(0.0, hit_clock - delta)
	turn_clock = maxf(0.0, turn_clock - delta)
	visual_hold = maxf(0.0, visual_hold - delta)
	if dead:
		death_clock += delta
		state = "death" if death_clock < 0.35 else "corpse"
		return
	move_ratio = real_velocity.length() / maxf(1.0, profile.reference_speed)
	gait += delta * profile.movement_fps * move_ratio
	if active:
		attack_elapsed += delta
		if visual_hold <= 0.0:
			var p: float = minf(1.0, attack_elapsed / attack_duration)
			var speed: float = clampf(profile.attack_animation_speed, 0.25, 4.0)
			# Speed changes pose easing inside each phase, preserving the marker and cadence.
			if p < attack_hit_ratio:
				visual_progress = attack_hit_ratio * (1.0 - pow(1.0 - p / attack_hit_ratio, speed))
			else:
				visual_progress = attack_hit_ratio + (1.0 - attack_hit_ratio) * (1.0 - pow(1.0 - (p - attack_hit_ratio) / (1.0 - attack_hit_ratio), speed))
		if not released and attack_elapsed >= attack_duration * attack_hit_ratio:
			# Receiving a critical just before this marker may freeze the windup pose.
			# The strike pose must still catch up without delaying gameplay clocks.
			visual_progress = attack_hit_ratio
			released = true # mark before signal: reentrant handlers cannot double-hit
			strike.emit(sequence)
		if active and attack_elapsed >= attack_duration:
			active = false
		if active:
			state = "attack" if attack_elapsed < attack_duration * 0.7 else "recovery"
			return
	if move_ratio > 0.01:
		face(real_velocity)
		state = "run" if move_ratio > 1.12 else "walk"
	elif hit_clock > 0.0:
		state = "hit"
	else:
		state = "turn" if turn_clock > 0.0 else "idle"

func apply(sprite: Node2D, base_scale: Vector2) -> void:
	if not is_instance_valid(sprite): return
	var bob: float = 0.0
	var stretch: Vector2 = Vector2.ONE
	var lean: float = 0.0
	var offset: Vector2 = Vector2.ZERO
	if dead:
		var fall: float = clampf(death_clock / 0.35, 0.0, 1.0)
		lean = fall * 1.35 * (-1.0 if direction.x < 0.0 else 1.0)
		offset.y = 9.0 * fall
		stretch = Vector2(1.0, 1.0 - fall * 0.2)
	else:
		bob = sin(idle_clock * 2.5) * (2.2 if profile.floating else 0.4)
		if move_ratio > 0.01 and not active:
			bob -= absf(sin(gait * PI)) * (1.2 if profile.floating else 2.3)
			lean = sin(gait * PI) * (0.025 if profile.motion_style != "crawl" else 0.05)
		if active:
			var p: float = visual_progress
			var impact: float = sin(clampf(p / attack_hit_ratio, 0.0, 1.0) * PI * 0.5) if p <= attack_hit_ratio else 1.0 - smoothstep(attack_hit_ratio, 1.0, p)
			match attack_style:
				"bow":
					offset = direction * (-4.0 if p < attack_hit_ratio else 2.0) * impact
					stretch = Vector2(1.0 - impact * 0.045, 1.0)
				"magic":
					bob -= impact * 4.0
					stretch = Vector2.ONE * (1.0 + impact * 0.035)
				"heavy":
					lean = (-0.10 + impact * 0.22) * signf(direction.x if absf(direction.x) > 0.1 else 1.0)
					offset = direction * impact * 7.0
				_:
					offset = direction * impact * (9.0 if attack_style == "thrust" else 5.0)
					lean = sin(p * TAU) * 0.065 * signf(direction.x if absf(direction.x) > 0.1 else 1.0)
	var anchor: Vector2 = profile.sprite_offset
	# Rotate/scale around the established foot anchor, never the collision body.
	sprite.scale = base_scale * stretch
	sprite.rotation = lean
	sprite.position = (anchor * stretch).rotated(lean) + offset + Vector2(0, bob)
	var tint: Color = Color(1.45, 0.8, 0.7) if hit_clock > 0.0 else Color.WHITE
	if dead: tint.a = 1.0 - clampf((death_clock - 0.55) / 0.45, 0.0, 1.0)
	sprite.modulate = tint
	if sprite is AnimatedSprite2D:
		_apply_frames(sprite as AnimatedSprite2D)
	elif sprite is Sprite2D:
		(sprite as Sprite2D).flip_h = direction.x < -0.1

func _apply_frames(sprite: AnimatedSprite2D) -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null: return
	var key: String = str(profile.animation_names.get(state + ":" + str(facing8), ""))
	if key.is_empty(): key = str(profile.animation_names.get(state, ""))
	if key.is_empty() and active:
		key = str(profile.animation_names.get("attack:" + str(facing8), profile.animation_names.get("attack", "")))
	if key.is_empty():
		if profile.layout == "class5":
			key = "attack" if active else ["walk_down", "walk_up", "walk_left", "walk_right"][facing4]
		elif profile.layout == "directional4":
			key = ["dir_down", "dir_up", "dir_left", "dir_right"][facing4]
		elif profile.layout == "directional8":
			key = "dir_" + str(facing8)
		else: key = "still"
	if not frames.has_animation(key): return
	if sprite.animation != key: sprite.animation = key
	sprite.pause() # one authoritative clock; no duplicate AnimatedSprite timing events
	sprite.flip_h = profile.layout == "still" and direction.x < -0.1
	if profile.layout == "class5" and active: sprite.flip_h = facing4 == 2
	var count: int = frames.get_frame_count(key)
	if count <= 0: return
	var frame_value: int = 0
	if active and (profile.dedicated_attack or profile.animation_names.has(state)):
		# Original class hit is frame 3/5, mapped exactly to the strike marker.
		var marker_frame: int = clampi(profile.attack_hit_frame, 0, count - 1)
		if visual_progress < attack_hit_ratio:
			frame_value = mini(marker_frame - 1, int(visual_progress / attack_hit_ratio * marker_frame))
		else:
			frame_value = marker_frame + int((visual_progress - attack_hit_ratio) / (1.0 - attack_hit_ratio) * (count - marker_frame))
	elif move_ratio > 0.01 and not active:
		frame_value = posmod(int(gait), count)
	var next_frame: int = clampi(frame_value, 0, count - 1)
	if sprite.frame != next_frame: sprite.frame = next_frame
