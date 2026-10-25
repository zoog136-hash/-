extends SceneTree

# Private, unmapped body preview in the real Main scene. No production loader,
# profiles, stats, pixels, saved games, or transform identities are changed.
# TWILIGHT_OPTIONAL_RENDER_CAPTURE
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR122_NATIVE_OUTPUT
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
const PROP_QA = preload("res://tests/qa_rendered_prop_clearance.gd")
const STEP := 1.0 / 120.0
const COMPASS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const INPUTS := [["move_right"], ["move_right", "move_down"], ["move_down"], ["move_left", "move_down"],
	["move_left"], ["move_left", "move_up"], ["move_up"], ["move_right", "move_up"]]
var report: Dictionary = {"checks": 0, "failures": [], "actors": {}, "prototype_only": true,
	"production_applied": false, "target_identity": "UNMAPPED", "completed_added": 0,
	"Android_real_device": "NOT_RUN", "renderer": "OpenGL software llvmpipe, no physical GPU claim",
	"temporal_scope": "Production motion controller sampled at120Hz, Main paused for atomic readback; no wall-time performance claim",
	"rights": "All source and rendered pixels private; public receipt contains hashes/counts only"}
var fixture: Dictionary
var output: String
var world: TwilightWorld
var center := Vector2(25472, 22844)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, explanation: String) -> void:
	report.checks = int(report.checks) + 1
	if not ok:
		report.failures.append(explanation)
		print("NATIVE_MAIN_FAIL ", explanation)

func vec(value: Vector2) -> Array:
	return [value.x, value.y]

func heading(direction: int) -> Vector2:
	return Vector2.from_angle(float(direction) * PI / 4.0)

func bounds(sprite: AnimatedSprite2D) -> Rect2:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
	return Rect2(sprite.offset - texture.get_size() * 0.5 + texture.margin.position, texture.region.size)

func clear(point: Vector2, radius: float) -> bool:
	if not world.field_map.walkable(point) or not world.field_map.point_clear(point): return false
	for direction: int in range(8):
		var edge := point + heading(direction) * radius
		if not world.field_map.point_clear(edge) or not world.field_map.line_clear(point, edge): return false
	var envelope := Rect2(point + Vector2(-230, -290), Vector2(460, 470))
	for actor: Node in world.monsters_root.get_children():
		if actor is Node2D and (actor as Node2D).is_visible_in_tree() and (actor as Node2D).global_position.distance_to(point) < 400.0: return false
	return PROP_QA.clear_bounds(world.field_renderer, envelope)

func locate() -> bool:
	var start := center
	for radius: int in range(0, 3200, 160):
		for direction: int in range(16):
			var point := start + Vector2.from_angle(TAU * float(direction) / 16.0) * float(radius)
			world.player.position = point
			world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			if clear(point, 220.0):
				center = point
				report.review_position = vec(point)
				return true
	return false

func build_frames(actor: Dictionary) -> SpriteFrames:
	var images: Array[Texture2D] = []
	for page: int in range(actor.atlas_paths.size()):
		var path := str(actor.atlas_paths[page])
		check(FileAccess.get_sha256(path) == str(actor.atlas_SHA256[page]), "private native atlas unchanged")
		var image := Image.load_from_file(path)
		check(image != null and not image.is_empty(), "private native atlas decoded")
		images.append(ImageTexture.create_from_image(image))
	var frames := SpriteFrames.new()
	frames.clear_all()
	var source_bounds: Array = actor.source_bounds
	var canvas := Vector2(float(source_bounds[2]) - float(source_bounds[0]), float(source_bounds[3]) - float(source_bounds[1]))
	var cache: Dictionary = {}
	for key: String in actor.tracks:
		var track: Dictionary = actor.tracks[key]
		frames.add_animation(key)
		frames.set_animation_speed(key, 24.0)
		frames.set_animation_loop(key, str(track.role) in ["idle", "walk", "run", "run_right"])
		var total := 0
		for frame: Dictionary in track.frames:
			var native_key := str(frame.native_key)
			if not cache.has(native_key):
				var atlas := AtlasTexture.new()
				var rectangle: Array = frame.rect
				var origin: Array = frame.xy_offset
				atlas.atlas = images[int(frame.page)]
				atlas.region = Rect2(float(rectangle[0]), float(rectangle[1]), float(rectangle[2]), float(rectangle[3]))
				atlas.margin = Rect2(float(origin[0]) - float(source_bounds[0]), float(origin[1]) - float(source_bounds[1]),
					canvas.x - float(rectangle[2]), canvas.y - float(rectangle[3]))
				atlas.filter_clip = true
				cache[native_key] = atlas
			frames.add_frame(key, cache[native_key], float(frame.ticks))
			total += int(frame.ticks)
		check(total == int(track.total_ticks), "source ticks preserved " + key)
		check(frames.get_frame_count(key) == track.frames.size(), "source chronology complete " + key)
	return frames

func profile_for(actor: Dictionary, frames: SpriteFrames, ratio: float) -> TwilightAnimationProfile:
	var profile := PROFILE.new()
	profile.profile_id = "qa-private-native:UNMAPPED"
	profile.layout = "directional8"
	profile.reference_speed = world.player.class_profile.reference_speed
	profile.authored_motion_weight = 0.0
	profile.hit_recoil = 0.0
	profile.death_duration = 39.0 / (24.0 * ratio)
	var box: Array = actor.source_bounds
	var size := Vector2(float(box[2]) - float(box[0]), float(box[3]) - float(box[1]))
	var foot := Vector2(float(fixture.foot_source_candidate[0]) - float(box[0]), float(fixture.foot_source_candidate[1]) - float(box[1]))
	var scale := 110.0 / float(actor.reference_height)
	profile.sprite_offset = (size * 0.5 - foot) * Vector2(0.90, 1.0) * scale
	for role: String in ["attack", "cast", "special"]:
		for key: String in actor.tracks:
			var track: Dictionary = actor.tracks[key]
			if str(track.role) != role: continue
			for index: int in range(track.frames.size()):
				if bool(track.frames[index].hit_marker): profile.action_hit_frames[role] = index
	return profile

func capture(stem: String, sprite: AnimatedSprite2D) -> Dictionary:
	var before := {"animation": str(sprite.animation), "phase": sprite.frame, "root": vec(world.player.position)}
	await RenderingServer.frame_post_draw
	check(before == {"animation": str(sprite.animation), "phase": sprite.frame, "root": vec(world.player.position)}, "atomic actual Main render " + stem)
	var rectangle := sprite.get_global_transform_with_canvas() * bounds(sprite)
	check(root.get_visible_rect().encloses(rectangle), "whole native body inside Main " + stem)
	check(PROP_QA.clear_bounds(world.field_renderer, sprite.global_transform * bounds(sprite)), "unmodified streamed map clear " + stem)
	var image := root.get_texture().get_image()
	# Preserve the complete native Main readback. Some source death poses extend
	# below the fixed authoring diagnostic window; never crop off those bodies.
	var crop := Rect2i(Vector2i.ZERO, image.get_size())
	check(Rect2(crop).encloses(rectangle), "complete native body in diagnostic readback " + stem)
	var path := output.path_join("captures").path_join(stem + ".png")
	check(not FileAccess.file_exists(path) and image.get_region(crop).save_png(path) == OK, "private actual Main PNG saved " + stem)
	return {"path": path, "sha256": FileAccess.get_sha256(path), "phase": sprite.frame,
		"root": vec(world.player.position), "visible_bounds": [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y],
		"crop": [crop.position.x, crop.position.y, crop.size.x, crop.size.y]}

func play_track(id: String, actor: Dictionary, frames: SpriteFrames, key: String, ratio: float) -> Dictionary:
	var track: Dictionary = actor.tracks[key]
	var role := str(track.role)
	var direction := int(track.direction)
	var controller := MOTION.new()
	var profile := profile_for(actor, frames, ratio)
	controller.profile = profile
	controller.face(heading(direction)); controller.turn_clock = 0.0
	var sprite := world.player.spx_sprite
	sprite.sprite_frames = frames
	sprite.visible = true
	var base_scale := Vector2(0.90, 1.0) * (110.0 / float(actor.reference_height))
	sprite.set_meta("base_scale", base_scale)
	var seconds := float(track.total_ticks) / (24.0 * ratio)
	frames.set_animation_speed(key, 24.0 * ratio)
	var velocity := Vector2.ZERO
	if role in ["walk", "run", "run_right"]:
		var move_ratio := 0.75 if role == "walk" else 1.25
		velocity = heading(direction) * profile.reference_speed * move_ratio
		profile.movement_fps = float(track.frames.size()) / seconds / move_ratio
		if role == "run_right": profile.animation_names["run:" + str(direction)] = key
	elif role in ["attack", "cast", "special"]:
		var elapsed := 0
		var marker := 0.5
		for frame: Dictionary in track.frames:
			if bool(frame.hit_marker): marker = float(elapsed) / float(track.total_ticks)
			elapsed += int(frame.ticks)
		controller.begin_attack(seconds, heading(direction), "thrust", marker)
		controller.action_role = role
	elif role == "hit":
		controller.react()
		controller.hit_duration = seconds; controller.hit_clock = seconds
	elif role == "death": controller.die()
	var result := {"track": key, "ratio": ratio, "source_action": track.source_action,
		"source_direction": track.source_direction, "native_frames": track.frames.size(),
		"native_total_ticks": track.total_ticks, "cycle_seconds": seconds,
		"distinct_RGBA": track.distinct_source_RGBA, "captures": [], "native_sequence": []}
	var seen: Dictionary = {}
	var prior := -1
	var prior_elapsed := 0.0
	var duration := seconds * (1.25 if role in ["idle", "walk", "run", "run_right"] else 0.999)
	for step: int in range(int(ceil(duration / STEP)) + 1):
		var elapsed := minf(float(step) * STEP, duration)
		world.player.position = center + velocity * (elapsed - seconds * 0.5)
		controller.advance(elapsed - prior_elapsed, velocity)
		prior_elapsed = elapsed
		controller.apply(sprite, base_scale)
		check(str(sprite.animation) == key, "production controller selected native role " + id + "/" + key)
		if str(sprite.animation) != key: break
		check(not sprite.flip_h and is_zero_approx(sprite.rotation), "unmirrored whole-body source " + key)
		check(is_equal_approx(sprite.scale.x / sprite.scale.y, 0.90), "candidate keeps X0.90 Y1.00 width ratio " + key)
		if sprite.frame != prior:
			result.native_sequence.append(sprite.frame)
			prior = sprite.frame
		if not seen.has(sprite.frame):
			seen[sprite.frame] = true
			world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll()
			world.field_renderer.refresh_visible()
			var stem := "%s-%s-%s-%02d" % [id, key, ("%.2f" % ratio).replace(".", "_"), sprite.frame]
			result.captures.append(await capture(stem, sprite))
	check(seen.size() == track.frames.size(), "all native frames actually rendered " + id + "/" + key + "/" + str(ratio))
	for index: int in range(1, result.native_sequence.size()):
		var expected: int = (int(result.native_sequence[index - 1]) + 1) % int(track.frames.size())
		check(int(result.native_sequence[index]) == expected, "unskipped native chronology " + key)
	return result

func actual_input(id: String, actor: Dictionary, frames: SpriteFrames) -> Dictionary:
	var player := world.player
	var old_frames := player.spx_sprite.sprite_frames
	var old_profile := player.spx_profile
	var old_id := player.spx_actor_id
	var old_transform_active := player.transform_active
	player.clear_transform_visual()
	player.spx_sprite.sprite_frames = frames
	player.spx_profile = profile_for(actor, frames, 1.0)
	player.spx_profile.movement_fps = 12.0
	player.spx_actor_id = id
	for key: String in frames.get_animation_names(): frames.set_animation_speed(key, 24.0)
	var before_speed := player.move_speed
	var before_shape: Shape2D = player.get_node("CollisionShape2D").get("shape") as Shape2D
	var result := {"scope": "Unmapped in-memory source, real Input -> physics -> existing controller, unchanged gameplay speed", "directions": []}
	for direction: int in fixture.directions:
		player.cancel_attack(); player.clear_click_path()
		player.position = center
		player.motion.dead = false
		world.process_mode = Node.PROCESS_MODE_INHERIT
		var start := player.position
		for action: String in INPUTS[direction]: Input.action_press(action)
		var sequence: Array = []
		for step: int in range(40):
			await physics_frame; await process_frame
			check(player.motion.facing8 == direction, "real keyboard direction " + id)
			check(player.spx_sprite.is_visible_in_tree() and not player.transform_sprite.visible and not player.class_sprite.visible,
				"actual input displays the private candidate " + id)
			check(player.motion.profile == player.spx_profile, "actual input owns candidate profile " + id)
			check(str(player.spx_sprite.animation).begins_with("run_") or str(player.spx_sprite.animation).begins_with("walk_"), "native real movement role " + id)
			if sequence.is_empty() or sequence[-1] != player.spx_sprite.frame: sequence.append(player.spx_sprite.frame)
		for action: String in INPUTS[direction]: Input.action_release(action)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var displacement := player.position - start
		check(displacement.dot(heading(direction)) > 20.0, "real keyboard moves actual collision body " + id)
		check(player.move_speed == before_speed and player.get_node("CollisionShape2D").shape == before_shape, "movement and collision preserved " + id)
		world.player.camera.reset_smoothing(); world.player.camera.force_update_scroll(); world.field_renderer.refresh_visible()
		var image := await capture(id + "-actual-input-" + str(COMPASS[direction]), player.spx_sprite)
		result.directions.append({"direction": COMPASS[direction], "displacement": vec(displacement),
			"observed_native_sequence": sequence, "capture": image})
	player.spx_sprite.sprite_frames = old_frames
	player.spx_profile = old_profile
	player.spx_actor_id = old_id
	player.transform_active = old_transform_active
	return result

func run() -> void:
	output = OS.get_environment("TWILIGHT_PR122_NATIVE_OUTPUT")
	var fixture_path := OS.get_environment("TWILIGHT_PR122_NATIVE_FIXTURE")
	if output.is_empty() or fixture_path.is_empty() or not FileAccess.file_exists(fixture_path):
		print("NATIVE_MAIN_NOT_RUN: verified private fixture and output required; use tools/run_pr122_native_tick_preview.py")
		quit(2)
		return
	fixture = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(bool(fixture.prototype_only) and not bool(fixture.production_applied) and not bool(fixture.public_artifacts_allowed), "private unapproved candidate only")
	DirAccess.make_dir_recursive_absolute(output.path_join("captures"))
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world), "actual Main class picker entered")
	world.hud._close_workspace()
	world.save_timer = -10000.0
	world._set_map("aden_world", false)
	await process_frame; await physics_frame
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.camera.zoom = Vector2(1.6, 1.6)
	check(locate(), "unmodified actual Main clearing found")
	if report.failures.is_empty():
		world.player.class_sprite.hide(); world.player.transform_sprite.hide(); world.player.spx_sprite.show()
		for id: String in fixture.actors:
			var actor: Dictionary = fixture.actors[id]
			var frames := build_frames(actor)
			var result := {"source_header": actor.source_header, "target_identity": "UNMAPPED", "tracks": [],
				"quality": "HOLD: identity, source pivot, effects/contact and independent review not approved"}
			for key: String in actor.tracks:
				for ratio: float in [0.75, 1.0, 1.5]:
					result.tracks.append(await play_track(id, actor, frames, key, ratio))
			result.actual_input = await actual_input(id, actor, frames)
			report.actors[id] = result
	check(int(fixture.completed_added) == 0, "no completion credit for unmapped preview")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	world.queue_free()
	await process_frame
	print("NATIVE_MAIN_PREVIEW_RESULT checks=", report.checks, " failures=", report.failures.size())
	quit(0 if report.failures.is_empty() else 1)
