extends RefCounted
class_name TwilightActorMotion

const PROFILE = preload("res://scripts/animation/animation_profile.gd")
const CLASS_DIRECTIONS = ["walk_down", "walk_up", "walk_left", "walk_right"]
const SHEET_DIRECTIONS = ["dir_down", "dir_up", "dir_left", "dir_right"]
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
var hit_duration: float = 0.085
var state_clock: float = 0.0
var frame_source: SpriteFrames = null # optional authored frames for an existing Sprite2D
var _tracks: Dictionary = {}
var _track_source: SpriteFrames = null
var _resolved_profile: TwilightAnimationProfile = null
var _resolved_state: String = ""
var _resolved_facing: int = -1
var _resolved_key: String = ""
var _resolved_role: String = "legacy"
var _resolved_directional: bool = false
var _legacy_frames: bool = false

func _set_state(value: String, delta: float = 0.0) -> void:
	state_clock = state_clock + delta if state == value else 0.0
	state = value

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
	state_clock = 0.0
	state = "attack"
	return sequence

func cancel_attack() -> void:
	if active: cancelled.emit(sequence)
	active = false
	attack_duration = 0.0
	attack_elapsed = 0.0
	visual_hold = 0.0
	_set_state("idle")

func react(critical: bool = false) -> void:
	hit_duration = 0.13 if critical else 0.085
	hit_clock = hit_duration
	# Pose freeze only: physics, cooldowns and attack markers are never paused.
	visual_hold = 0.028 if critical else 0.0

func die() -> void:
	cancel_attack()
	dead = true
	death_clock = 0.0
	state_clock = 0.0
	state = "death"

func advance(delta: float, real_velocity: Vector2) -> void:
	idle_clock += delta
	hit_clock = maxf(0.0, hit_clock - delta)
	turn_clock = maxf(0.0, turn_clock - delta)
	visual_hold = maxf(0.0, visual_hold - delta)
	if dead:
		death_clock += delta
		_set_state("death" if death_clock < 0.35 else "corpse", delta)
		return
	move_ratio = real_velocity.length() / maxf(1.0, profile.reference_speed)
	gait += delta * profile.movement_fps * move_ratio
	if active:
		var struck_this_tick: bool = false
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
			struck_this_tick = true
			strike.emit(sequence)
		if active and attack_elapsed >= attack_duration:
			active = false
		if active:
			_set_state("attack" if struck_this_tick or attack_elapsed < attack_duration * maxf(0.7, attack_hit_ratio) else "recovery", delta)
			return
	if move_ratio > 0.01:
		face(real_velocity)
		_set_state("run" if move_ratio >= 0.92 else "walk", delta)
	elif hit_clock > 0.0:
		_set_state("hit", delta)
	else:
		_set_state("turn" if turn_clock > 0.0 else "idle", delta)

func apply(sprite: Node2D, base_scale: Vector2) -> void:
	if not is_instance_valid(sprite): return
	var source: SpriteFrames = (sprite as AnimatedSprite2D).sprite_frames if sprite is AnimatedSprite2D else frame_source
	if dead and source != null: _resolve_frames(source)
	var bob: float = 0.0
	var stretch: Vector2 = Vector2.ONE
	var lean: float = 0.0
	var offset: Vector2 = Vector2.ZERO
	if dead:
		var fall: float = clampf(death_clock / 0.35, 0.0, 1.0)
		# Authored death art already contains its fall; retain the shared fade only.
		if source == null or _resolved_role not in ["death", "corpse"]:
			lean = fall * 1.35 * (-1.0 if direction.x < 0.0 else 1.0)
			offset.y = 9.0 * fall
			stretch = Vector2(1.0, 1.0 - fall * 0.2)
	else:
		bob = sin(idle_clock * 2.5) * (2.2 if profile.floating else 0.4)
		if move_ratio > 0.01 and not active:
			var footfall: float = absf(sin(gait * PI))
			var running: bool = state == "run"
			bob -= footfall * (1.2 if profile.floating else (4.6 if running else 2.3))
			lean = sin(gait * PI) * (0.050 if running else (0.025 if profile.motion_style != "crawl" else 0.05))
			if running and not profile.floating:
				stretch = Vector2(1.0 + footfall * .035, 1.0 - footfall * .044)
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
		apply_frames(sprite)
	elif sprite is Sprite2D:
		if frame_source != null: apply_frames(sprite)
		else: (sprite as Sprite2D).flip_h = direction.x < -0.1

func _resolve_frames(frames: SpriteFrames) -> void:
	if _track_source != frames or _resolved_profile != profile:
		_track_source = frames
		_tracks.clear()
		_resolved_state = ""
		_legacy_frames = profile.frames_path.is_empty() and profile.animation_names.is_empty() and bool(frames.get_meta("twilight_generated_sheet", false))
	if _resolved_profile == profile and _resolved_state == state and _resolved_facing == facing8: return
	_resolved_profile = profile
	_resolved_state = state
	_resolved_facing = facing8
	_resolved_key = ""
	_resolved_role = "legacy"
	_resolved_directional = false
	var roles: Array[String] = [state]
	match state:
		"recovery": roles.append("attack")
		"run": roles.append("walk")
		"turn": roles.append("idle")
		"corpse": roles.append("death")
	for role: String in roles:
		var candidates: Array[String] = [str(profile.animation_names.get(role + ":" + str(facing8), "")),
			str(profile.animation_names.get(role, "")), role + "_" + str(facing8),
			role + ["_down", "_up", "_left", "_right"][facing4], role]
		for index: int in range(candidates.size()):
			var key: String = candidates[index]
			if not key.is_empty() and frames.has_animation(key) and frames.get_frame_count(key) > 0:
				_resolved_key = key
				_resolved_role = role
				_resolved_directional = index in [0, 2, 3]
				return
	# Keep existing class/directional/single-image art as the final fallback.
	match profile.layout:
		"class5":
			_resolved_key = "attack" if active else CLASS_DIRECTIONS[facing4]
			_resolved_role = "attack" if active else "legacy"
		"directional4": _resolved_key = SHEET_DIRECTIONS[facing4]
		"directional8": _resolved_key = "dir_" + str(facing8)
		_: _resolved_key = "still"
	if not frames.has_animation(_resolved_key) or frames.get_frame_count(_resolved_key) == 0:
		_resolved_key = ""
		# An incomplete optional set still needs a visible pose, never a stale attack.
		for key: String in frames.get_animation_names():
			if frames.get_frame_count(key) > 0:
				_resolved_key = key
				break

func _track(frames: SpriteFrames, key: String) -> Dictionary:
	if _tracks.has(key): return _tracks[key]
	var ends: PackedFloat64Array = PackedFloat64Array([0.0])
	for index: int in range(frames.get_frame_count(key)):
		ends.append(ends[-1] + maxf(0.001, frames.get_frame_duration(key, index)))
	var result: Dictionary = {"ends":ends, "count":ends.size() - 1,
		"fps":maxf(0.001, frames.get_animation_speed(key)), "loop":frames.get_animation_loop(key)}
	_tracks[key] = result
	return result

func _weighted_frame(track: Dictionary, progress: float, first: int = 0, last: int = -1) -> int:
	var ends: PackedFloat64Array = track.ends
	if last < 0: last = int(track.count) - 1
	first = clampi(first, 0, last)
	var point: float = lerpf(ends[first], ends[last + 1], clampf(progress, 0.0, 1.0))
	# Small authored sequences use a binary search without per-frame allocations.
	var low: int = first
	var high: int = last
	while low < high:
		var middle: int = (low + high) / 2
		if point < ends[middle + 1]: high = middle
		else: low = middle + 1
	return low

func apply_frames(sprite: Node2D) -> void:
	var frames: SpriteFrames = (sprite as AnimatedSprite2D).sprite_frames if sprite is AnimatedSprite2D else frame_source
	if frames == null: return
	if _track_source != frames or _resolved_profile != profile:
		_track_source = frames
		_resolved_profile = profile
		_tracks.clear()
		_resolved_state = ""
		_legacy_frames = profile.frames_path.is_empty() and profile.animation_names.is_empty() and bool(frames.get_meta("twilight_generated_sheet", false))
	if _legacy_frames:
		_apply_legacy_frames(sprite, frames)
		return
	_resolve_frames(frames)
	var key: String = _resolved_key
	if key.is_empty(): return
	var track: Dictionary = _track(frames, key)
	var count: int = track.count
	var frame_value: int = 0
	if active and _resolved_role == "attack":
		var marker_frame: int = clampi(profile.attack_hit_frame, 0, count - 1)
		if visual_progress < attack_hit_ratio:
			frame_value = _weighted_frame(track, visual_progress / attack_hit_ratio, 0, maxi(0, marker_frame - 1))
		else:
			frame_value = _weighted_frame(track, (visual_progress - attack_hit_ratio) / (1.0 - attack_hit_ratio), marker_frame)
	elif active and _resolved_role == "recovery":
		var start: float = maxf(0.7, attack_hit_ratio)
		frame_value = _weighted_frame(track, (attack_elapsed / attack_duration - start) / (1.0 - start))
	elif dead and _resolved_role == "death":
		frame_value = _weighted_frame(track, death_clock / 0.35)
	elif _resolved_role == "hit":
		frame_value = _weighted_frame(track, 1.0 - hit_clock / hit_duration)
	elif move_ratio > 0.01 and not active and _resolved_role in ["walk", "run", "legacy"]:
		frame_value = _weighted_frame(track, fposmod(gait, float(count)) / float(count))
	elif _resolved_role != "legacy":
		var ends: PackedFloat64Array = track.ends
		var progress: float = state_clock * float(track.fps) / ends[-1]
		frame_value = _weighted_frame(track, fposmod(progress, 1.0) if track.loop else minf(progress, 1.0))
	var mirrored: bool = profile.layout == "still" and not _resolved_directional and direction.x < -0.1
	if profile.layout == "class5" and active and not _resolved_directional: mirrored = facing4 == 2
	if sprite is AnimatedSprite2D:
		var animated: AnimatedSprite2D = sprite as AnimatedSprite2D
		if animated.animation != key: animated.animation = key
		if animated.is_playing(): animated.pause() # one authoritative clock
		animated.flip_h = mirrored
		if animated.frame != frame_value: animated.frame = frame_value
	elif sprite is Sprite2D:
		var still: Sprite2D = sprite as Sprite2D
		var texture: Texture2D = frames.get_frame_texture(key, frame_value)
		if texture != null and still.texture != texture: still.texture = texture
		still.flip_h = mirrored

func _apply_legacy_frames(sprite: Node2D, frames: SpriteFrames) -> void:
	# Existing uniform sheets need neither authored-name search nor weighted tracks.
	var key: String = "still"
	match profile.layout:
		"class5": key = "attack" if active else CLASS_DIRECTIONS[facing4]
		"directional4": key = SHEET_DIRECTIONS[facing4]
		"directional8": key = "dir_" + str(facing8)
	if not frames.has_animation(key): return
	var count: int = frames.get_frame_count(key)
	if count <= 0: return
	var frame_value: int = 0
	if active and profile.layout == "class5":
		var marker: int = clampi(profile.attack_hit_frame, 0, count - 1)
		if visual_progress < attack_hit_ratio:
			frame_value = mini(maxi(0, marker - 1), int(visual_progress / attack_hit_ratio * marker))
		else:
			frame_value = marker + int((visual_progress - attack_hit_ratio) / (1.0 - attack_hit_ratio) * (count - marker))
	elif move_ratio > 0.01 and not active: frame_value = posmod(int(gait), count)
	frame_value = clampi(frame_value, 0, count - 1)
	var mirrored: bool = direction.x < -0.1 if profile.layout == "still" else (active and profile.layout == "class5" and facing4 == 2)
	if sprite is AnimatedSprite2D:
		var animated: AnimatedSprite2D = sprite as AnimatedSprite2D
		if animated.animation != key: animated.animation = key
		if animated.is_playing(): animated.pause()
		animated.flip_h = mirrored
		if animated.frame != frame_value: animated.frame = frame_value
	elif sprite is Sprite2D:
		var still: Sprite2D = sprite as Sprite2D
		var texture: Texture2D = frames.get_frame_texture(key, frame_value)
		if texture != null and still.texture != texture: still.texture = texture
		still.flip_h = mirrored
