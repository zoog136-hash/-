extends SceneTree

const Motion = preload("res://scripts/animation/actor_motion.gd")
const COMPASS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
var capture_enabled: bool = false
var output_dir: String
var texture_refs: Array[ImageTexture] = []
var ground: Node2D
var actor: Node2D
var sprite: AnimatedSprite2D
var camera: Camera2D
var hud: Label
var strike_events: Array = []
var current_tick: int = 0
var strike_this_tick: bool = false
var captures: Dictionary = {}
var samples: Array = []

class Grid extends Node2D:
	func _draw() -> void:
		for value: int in range(-4096, 4097, 32):
			draw_line(Vector2(value, -4096), Vector2(value, 4096), Color(.22, .25, .27), 1.0)
			draw_line(Vector2(-4096, value), Vector2(4096, value), Color(.22, .25, .27), 1.0)

class Origin extends Node2D:
	func _draw() -> void:
		draw_line(Vector2(-7, 0), Vector2(7, 0), Color(1.0, .7, .2), 1.0)
		draw_line(Vector2(0, -4), Vector2(0, 4), Color(1.0, .7, .2), 1.0)

class Target extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-9, -76, 18, 76), Color(.65, .2, .2, .18), true)
		draw_rect(Rect2(-9, -76, 18, 76), Color(.8, .35, .3), false, 1.0)
		draw_circle(Vector2.ZERO, 7, Color(.8, .35, .3), false, 1.0)

func _initialize() -> void:
	call_deferred("_run")

func _setup() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(960, 640)
	root.content_scale_size = Vector2i(960, 640)
	RenderingServer.set_default_clear_color(Color(.105, .125, .14))
	ground = Grid.new()
	root.add_child(ground)
	actor = Node2D.new()
	ground.add_child(actor)
	sprite = AnimatedSprite2D.new()
	actor.add_child(sprite)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var origin := Origin.new()
	origin.z_index = 10
	actor.add_child(origin)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE
	ground.add_child(camera)
	camera.make_current()
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(12, 12)
	hud.add_theme_font_size_override("font_size", 16)
	canvas.add_child(hud)

func _cache(frames_path: String) -> void:
	texture_refs.clear()
	var regex := RegEx.new()
	regex.compile('\\[ext_resource type="Texture2D" path="([^"]+)"')
	var text := FileAccess.get_file_as_string(frames_path)
	var seen: Dictionary = {}
	for match: RegExMatch in regex.search_all(text):
		var path := match.get_string(1)
		if seen.has(path): continue
		seen[path] = true
		var image := Image.load_from_file(path)
		assert(image != null and not image.is_empty(), "PNG load failed: " + path)
		var texture := ImageTexture.create_from_image(image)
		texture.take_over_path(path)
		texture_refs.append(texture)

func _sample(motion: RefCounted, profile: Resource, segment: String, stage: String, tick: int, elapsed: float, base_scale: Vector2) -> void:
	motion.apply(sprite, base_scale)
	camera.position = actor.position + Vector2(0, -40)
	camera.force_update_scroll()
	var frame_texture: Texture2D = null
	if sprite.sprite_frames.has_animation(sprite.animation):
		frame_texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var foot_error: Variant = null
	var region: Variant = null
	if frame_texture != null:
		foot_error = (sprite.position + Vector2(0, frame_texture.get_height() / 8.0) * sprite.scale).length()
		if frame_texture is AtlasTexture:
			var rect: Rect2 = frame_texture.region
			region = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	var row := {"tick": tick, "simulation_seconds": elapsed, "segment": segment, "stage": stage,
		"motion_state": motion.state, "resolved_clip": motion._resolved_key, "frame": sprite.frame,
		"actor_world": [actor.position.x, actor.position.y], "sprite_offset": [sprite.position.x, sprite.position.y],
		"sprite_scale": [sprite.scale.x, sprite.scale.y], "virtual_canvas_foot_error": foot_error,
		"source_region": region, "source_texture_size": [frame_texture.get_width(), frame_texture.get_height()] if frame_texture != null else null,
		"gait": motion.gait, "move_ratio": motion.move_ratio, "movement_fps": profile.movement_fps,
		"attack_elapsed": motion.attack_elapsed, "attack_release_event": strike_this_tick}
	var capture_key: String = segment + ":" + stage + ":" + motion._resolved_key + ":" + str(sprite.frame)
	if strike_this_tick: capture_key += ":strike"
	hud.text = "%s | %s | %s\nclip=%s frame=%d simulated %.3fs  speed_scale=1 camera_zoom=1\nAmber cross: actor root / virtual canvas anchor. Red target: distance marker, no automatic contact verdict." % [profile.profile_id, segment, stage, motion._resolved_key, sprite.frame, elapsed]
	if capture_enabled and not captures.has(capture_key):
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		assert(image != null and not image.is_empty(), "Rendering capture unavailable")
		var filename: String = capture_key.replace(":", "-").replace("/", "_") + ".png"
		var destination := output_dir.path_join("captures").path_join(filename)
		assert(image.save_png(destination) == OK)
		row["capture"] = destination
		captures[capture_key] = destination
	samples.append(row)

func _segment(config: Dictionary, profile: Resource, frames: SpriteFrames, role: String, direction: String, case_out: String) -> Dictionary:
	output_dir = case_out
	var index: int = COMPASS.find(direction)
	var aim := Vector2.RIGHT.rotated(index * PI / 4.0)
	var motion = Motion.new()
	motion.profile = profile
	motion.face(aim)
	motion.state = role
	if role == "attack": motion.begin_attack(float(config.attack_seconds), aim, profile.motion_style)
	motion._resolve_frames(frames)
	var available: bool = not str(motion._resolved_key).is_empty() and motion._resolved_role != "unavailable"
	if not available:
		return {"role": role, "direction": direction, "status": "NOT_AUTHORED", "actual_clip": motion._resolved_key}
	var segment := role + "-" + direction
	var segment_started: int = Time.get_ticks_usec()
	actor.position = Vector2.ZERO
	sprite.sprite_frames = frames
	sprite.animation = motion._resolved_key
	sprite.stop()
	var base_scale: Vector2 = Vector2.ONE * profile.pixel_scale
	base_scale.x *= profile.native_width_ratio
	var target := Target.new()
	target.position = aim * float(config.attack_range)
	ground.add_child(target)
	strike_events.clear()
	motion.strike.connect(func(sequence: int) -> void:
		strike_this_tick = true
		strike_events.append({"tick": current_tick, "sequence": sequence, "attack_elapsed": motion.attack_elapsed}))
	var seconds: float = float(config.get("idle_seconds", 1.4))
	if role == "run": seconds = float(config.get("run_seconds", 1.8))
	elif role == "attack": seconds = float(config.attack_seconds) + .35
	elif role == "hit": seconds = .55
	elif role == "death": seconds = profile.death_duration + .35
	var pre_seconds: float = .20 if frames.has_animation("idle_" + str(index)) else 0.0
	# Use fresh state for every segment. Death is irreversible; no dead flag is cleared.
	motion = Motion.new()
	motion.profile = profile
	motion.face(aim)
	motion.strike.connect(func(sequence: int) -> void:
		strike_this_tick = true
		strike_events.append({"tick": current_tick, "sequence": sequence, "attack_elapsed": motion.attack_elapsed}))
	var seen: Dictionary = {}
	var role_started := false
	for tick: int in range(int(ceil((pre_seconds + seconds) * 60))):
		current_tick = tick
		strike_this_tick = false
		var elapsed: float = tick / 60.0
		var stage := "pre-idle" if elapsed < pre_seconds else "action"
		if not role_started and stage == "action":
			role_started = true
			if role == "attack": motion.begin_attack(float(config.attack_seconds), aim, profile.motion_style)
			elif role == "hit": motion.react(false, -aim)
			elif role == "death": motion.die()
		var velocity := aim * float(config.move_speed) if stage == "action" and role == "run" else Vector2.ZERO
		actor.position += velocity / 60.0
		motion.advance(1.0 / 60.0, velocity)
		await process_frame
		await _sample(motion, profile, segment, stage, tick, elapsed, base_scale)
		seen[str(motion._resolved_key) + ":" + str(sprite.frame)] = true
	var answer := {"role": role, "direction": direction, "status": "PLAYED_AT_GAME_SCALE",
		"move_speed": config.move_speed, "attack_seconds": config.attack_seconds,
		"simulated_seconds": pre_seconds + seconds, "wall_seconds": (Time.get_ticks_usec() - segment_started) / 1000000.0,
		"gait_delta_rule": "dt * movement_fps * actual_speed / reference_speed, plus original ActorMotion cadence-width adapter",
		"attack_contact_source_index": profile.hit_frame_for("attack"), "sampled_clip_frames": seen.keys(),
		"strike_events": strike_events.duplicate(true), "virtual_foot_is_not_anatomical_contact_proof": true}
	target.queue_free()
	await process_frame
	return answer

func _run() -> void:
	var path := OS.get_environment("BOSS_FIX_QA_CONFIG")
	assert(not path.is_empty())
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	capture_enabled = bool(config.capture)
	_setup()
	var report := {"schema": "pr122-boss-fix-real-speed-qa-v1", "engine": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(), "video_adapter": RenderingServer.get_video_adapter_name(),
		"simulation_dt": 1.0 / 60.0, "speed_scale": 1.0, "camera_zoom": 1.0, "capture_enabled": capture_enabled,
		"scope": "Original ActorMotion applied to a game-scale AnimatedSprite2D in a diagnostic ground arena; not actual Main, combat damage or automatic visual approval.",
		"quality_approval_changes": 0, "cases": []}
	for item: Dictionary in config.cases:
		var case_out := str(config.output).path_join(item.slug)
		DirAccess.make_dir_recursive_absolute(case_out.path_join("captures"))
		var profile: Resource = load(item.native_profile)
		assert(profile != null and profile.profile_id == item.key and profile.pixel_scale > 0.0)
		profile = profile.duplicate(true)
		var original_reference_speed: float = profile.reference_speed
		# scripts/monster.gd::_setup_visual sets reference_speed to the actual
		# monster's base_move_speed after loading the catalog profile.
		profile.reference_speed = maxf(1.0, float(item.move_speed))
		_cache(profile.frames_path)
		var frames: SpriteFrames = load(profile.frames_path) as SpriteFrames
		assert(frames != null)
		captures.clear()
		samples.clear()
		var result := {"key": item.key, "profile": item.native_profile, "frames": profile.frames_path,
			"pixel_scale": profile.pixel_scale, "native_width_ratio": profile.native_width_ratio, "segments": []}
		result["source_canvas_metadata"] = var_to_str(frames.get_meta("twilight_canvas_size", null))
		result["native_sprite_offset"] = [profile.sprite_offset.x, profile.sprite_offset.y]
		result["movement_fps"] = profile.movement_fps
		result["movement_cadence_width_ratio"] = profile.movement_cadence_width_ratio
		result["original_profile_reference_speed"] = original_reference_speed
		result["actual_Monster_reference_speed"] = profile.reference_speed
		for role: String in item.roles:
			var directions: Array = ["S"] if role == "death" else item.directions
			for direction: String in directions:
				result.segments.append(await _segment(item, profile, frames, role, direction, case_out))
		var output := FileAccess.open(case_out.path_join("samples.json"), FileAccess.WRITE)
		output.store_string(JSON.stringify(samples, "\t") + "\n")
		result["samples_file"] = case_out.path_join("samples.json")
		result["capture_count"] = captures.size()
		report.cases.append(result)
		print("BOSS_FIX_QA_CASE_DONE key=%s segments=%d captures=%d" % [item.key, result.segments.size(), captures.size()])
		frames = null
		texture_refs.clear()
		await process_frame
	var output := FileAccess.open(str(config.output).path_join("report.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	print("BOSS_FIX_QA_DONE real_scale=true speed_scale=1 capture=%s approval_changes=0" % capture_enabled)
	quit(0)
