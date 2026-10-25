extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")
const BASE = "res://docs/remake/evidence/pr122-monsters-20261023/review-boss-runtime/"

func _initialize() -> void:
	call_deferred("_run")

func _profile(entry: Dictionary) -> Resource:
	var profile: Resource = Profile.new()
	profile.reference_speed = 90.0
	var settings: Dictionary = entry.profile_settings.duplicate(true)
	settings.merge(entry.record.get("animation_profile", {}), true)
	var properties: Dictionary = {}
	for property: Dictionary in profile.get_property_list(): properties[property.name] = property.type
	for key: String in settings:
		if not properties.has(key): continue
		var value: Variant = settings[key]
		if properties[key] == TYPE_VECTOR2 and value is Array and value.size() == 2:
			value = Vector2(float(value[0]), float(value[1]))
		elif properties[key] == TYPE_COLOR:
			if value is Array and value.size() == 4: value = Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
			else: value = Color.from_string(str(value), Color.WHITE)
		profile.set(key, value)
	profile.profile_id = entry.key
	# Match PresentationCatalog's boss animation-name overrides; no appearance
	# values or animation poses are judged by this resource/playability check.
	var presentation: Dictionary = entry.presentation.duplicate(true)
	presentation.merge(entry.record.get("animation_profile", {}).get("presentation", {}), true)
	for role: String in ["attack", "cast", "special"]:
		if not profile.animation_names.has(role):
			profile.animation_names[role] = str(presentation.get(role + "_animation", role))
	return profile

func _entry(entry: Dictionary, frames: SpriteFrames) -> Dictionary:
	var profile := _profile(entry)
	var result := {"key": entry.key, "approved_preserved": entry.approved_preserved,
		"preserved_status": entry.preserved_status, "profile_id": profile.profile_id,
		"resolved": [], "failures": [], "art_quality_review": "NOT_PERFORMED"}
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
	sprite.speed_scale = 137.0
	for role: String in ["idle", "run", "attack", "hit", "death"]:
		for direction: int in range(8):
			var motion = Motion.new()
			motion.profile = profile
			var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
			motion.face(aim)
			if role == "attack": motion.begin_attack(.42, aim, profile.motion_style)
			motion.state = role
			motion._resolve_frames(frames)
			var clip: String = motion._resolved_key
			var resolved: String = motion._resolved_role
			var count: int = frames.get_frame_count(clip) if frames.has_animation(clip) else 0
			var existing_walk: bool = role == "run" and resolved == "walk"
			var available: bool = count > 0 and (resolved == role or existing_walk or (role == "attack" and resolved in ["cast", "ranged_attack"]))
			var row := {"requested_role": role, "direction": ["E", "SE", "S", "SW", "W", "NW", "N", "NE"][direction],
				"required": role != "death" or direction == 2, "resolved_clip": clip, "resolved_role": resolved,
				"frame_count": count, "existing_run_to_walk_fallback": existing_walk,
				"role_available": available, "AnimatedSprite2D_play": "NOT_RUN"}
			if available:
				sprite.stop()
				sprite.play(clip)
				sprite.set_frame_and_progress(0, 0.0)
				var before_frame: int = sprite.frame
				var before_progress: float = sprite.frame_progress
				# AnimatedSprite2D has no manual advance(delta) API. Let its real
				# internal engine-clock process run; accelerated speed tests only
				# playability, not gameplay cadence or full-pose timing quality.
				await create_timer(.002, true, false, true).timeout
				await process_frame
				var advanced: bool = sprite.frame != before_frame or not is_equal_approx(sprite.frame_progress, before_progress)
				var texture: Texture2D = frames.get_frame_texture(clip, sprite.frame)
				var valid: bool = texture != null and texture.get_width() > 0 and texture.get_height() > 0
				row["AnimatedSprite2D_play"] = "PASS" if advanced and valid else "FAIL"
				row["sampled_frame"] = sprite.frame
				row["sampled_frame_progress"] = sprite.frame_progress
				row["engine_clock_advanced"] = advanced
				if not advanced or not valid: result.failures.append(role + ":" + row.direction + ":SPRITE_PLAYBACK_FAILED")
			else:
				if row.required: result.failures.append(role + ":" + row.direction + ":MISSING_ROLE_FRAME")
			result.resolved.append(row)
	sprite.queue_free()
	await process_frame
	return result

func _run() -> void:
	Engine.max_fps = 240
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "plan.json"))
	var result := {"schema": "pr122-boss-runtime-playability-v1", "engine": Engine.get_version_info().string,
		"plan_HEAD": plan.HEAD, "exact_boss_ids": plan.exact_boss_ids, "required_roles_direction_counts": plan.required_roles_direction_counts,
		"art_quality_review": "NOT_PERFORMED", "approval_changes": 0, "resources": [],
		"playback_scope": "Actual ActorMotion resolver plus AnimatedSprite2D.play/internal-engine-clock advancement for every role/direction. speed_scale137; no Main/combat scene or gameplay-timing/appearance-quality claim."}
	for group: Dictionary in plan.resources:
		var record := {"frames": group.frames, "TRES_sha256": group.TRES_sha256, "PNG_sources": [], "entries": [], "failures": []}
		var textures: Array[ImageTexture] = []
		for path: String in group.texture_paths:
			var image := Image.new()
			var error: Error = image.load(path)
			var source := {"path": path, "file_present": FileAccess.file_exists(path), "load_error": error}
			if error != OK or image.is_empty():
				record.failures.append("PNG_LOAD_FAILED:" + path)
			else:
				var texture := ImageTexture.create_from_image(image)
				texture.take_over_path(path)
				textures.append(texture)
				source["size"] = [image.get_width(), image.get_height()]
			record.PNG_sources.append(source)
		var frames: SpriteFrames = null
		if record.failures.is_empty():
			frames = ResourceLoader.load(group.frames, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE) as SpriteFrames
		if frames == null:
			record.failures.append("SPRITEFRAMES_LOAD_FAILED")
		else:
			for entry: Dictionary in group.entries:
				record.entries.append(await _entry(entry, frames))
		record["SpriteFrames_loaded"] = frames != null
		result.resources.append(record)
		frames = null
		textures.clear()
		await process_frame
	var output := FileAccess.open(BASE + "godot-results.json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(result, "\t") + "\n")
	print("PR122_BOSS_RUNTIME_PLAYABILITY_DONE bosses=60 unique_TRES=%d engine=%s" % [result.resources.size(), result.engine])
	quit(0)
