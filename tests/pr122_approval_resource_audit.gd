extends SceneTree
const TexturePixels = preload("res://tests/texture_pixels.gd")

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")


func _initialize() -> void:
	call_deferred("_run")

func _frame(texture: Texture2D, index: int, duration: float) -> Dictionary:
	var row := {"index": index, "duration": duration, "failures": []}
	if texture == null:
		row.failures.append("NULL_FRAME_TEXTURE")
		return row
	row["size"] = [texture.get_width(), texture.get_height()]
	if texture.get_width() <= 0 or texture.get_height() <= 0: row.failures.append("EMPTY_FRAME_SIZE")
	if duration <= 0: row.failures.append("NONPOSITIVE_FRAME_DURATION")
	var source: Texture2D = texture
	var levels: Array = []
	while source is AtlasTexture:
		var atlas: AtlasTexture = source
		if atlas.atlas == null:
			row.failures.append("NULL_ATLAS_SOURCE")
			return row
		var region: Rect2 = atlas.region
		if is_zero_approx(region.size.x): region.size.x = atlas.atlas.get_width()
		if is_zero_approx(region.size.y): region.size.y = atlas.atlas.get_height()
		levels.append({"region": [region.position.x, region.position.y, region.size.x, region.size.y],
			"margin": [atlas.margin.position.x, atlas.margin.position.y, atlas.margin.size.x, atlas.margin.size.y],
			"atlas_size": [atlas.atlas.get_width(), atlas.atlas.get_height()]})
		if region.size.x <= 0 or region.size.y <= 0: row.failures.append("EMPTY_ATLAS_REGION")
		if region.position.x < 0 or region.position.y < 0 or region.end.x > atlas.atlas.get_width() or region.end.y > atlas.atlas.get_height():
			row.failures.append("ATLAS_REGION_OUT_OF_BOUNDS")
		source = atlas.atlas
		if levels.size() > 8:
			row.failures.append("ATLAS_NESTING_CYCLE")
			break
	row["atlas_levels"] = levels
	row["source_path"] = source.resource_path
	if levels.size() > 1:
		var image: Image = TexturePixels.image_of(texture)
		row["nested_render_alpha_empty"] = image == null or image.is_invisible()
	return row

func _resolve(entry: Dictionary, frames: SpriteFrames) -> Dictionary:
	var result := {"entry_id": entry.id, "key": entry.id, "scope": entry.scope,
		"category": entry.category,
		"frames": entry.frames, "resolved": [], "failures": [],
		"required_roles_direction_counts": {"idle": 8, "run": 8, "attack": 8, "hit": 8, "death": 1}}
	var profile: Resource
	if entry.scope == "runtime":
		# Apply the same canonical settings and record override precedence as
		# AnimationCatalog.for_record, without its unrelated global-class setup.
		profile = Profile.new()
		profile.reference_speed = 90.0
		var settings: Dictionary = entry.profile_settings.duplicate(true)
		settings.merge(entry.get("record", {}).get("animation_profile", {}), true)
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
		profile.profile_id = entry.id
	else:
		if not str(entry.get("native_profile", "")).is_empty():
			profile = ResourceLoader.load(entry.native_profile, "", ResourceLoader.CACHE_MODE_IGNORE)
	if profile == null or not profile is Profile:
		result.failures.append("PROFILE_LOAD_FAILED")
		for role: String in ["idle", "run", "attack", "hit", "death"]:
			for direction: int in range(8):
				result.resolved.append({"requested_role": role, "requested_direction": direction, "required": role != "death" or direction == 2, "role_available": false, "existing_runtime_walk_fallback": false, "frame_failure": "PROFILE_LOAD_FAILED"})
		return result
	if profile.frames_path != entry.frames:
		result.failures.append("PROFILE_FRAMES_BINDING_MISMATCH")
	result["profile_id"] = profile.profile_id
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
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
			var resolved_role: String = motion._resolved_role
			var count: int = frames.get_frame_count(clip) if not clip.is_empty() and frames.has_animation(clip) else 0
			var accepted: bool = resolved_role == role
			var existing_walk: bool = role == "run" and resolved_role == "walk" and entry.scope == "runtime"
			accepted = accepted or existing_walk or (role == "attack" and resolved_role in ["cast", "ranged_attack"])
			var row := {"requested_role": role, "requested_direction": ["E", "SE", "S", "SW", "W", "NW", "N", "NE"][direction],
				"required": role != "death" or direction == 2, "resolved_clip": clip,
				"resolved_role": resolved_role, "frame_count": count,
				"existing_runtime_walk_fallback": existing_walk, "role_available": accepted and count > 0}
			if not row.role_available:
				row["frame_failure"] = "NO_POSITIVE_FRAME_CLIP_FOR_REQUIRED_ROLE"
				if row.required: result.failures.append(role + ":" + row.requested_direction + ":MISSING_ROLE_CLIP")
			if row.role_available:
				var playback = Motion.new()
				playback.profile = profile
				playback.face(aim)
				if role == "attack": playback.begin_attack(.42, aim, profile.motion_style)
				elif role == "hit": playback.react(false, -aim)
				elif role == "death": playback.die()
				var phases: Dictionary = {}
				var selected: Dictionary = {}
				var invalid_frame: bool = false
				for tick: int in range(240):
					playback.advance(1.0/120.0, aim*profile.reference_speed*1.25 if role == "run" else Vector2.ZERO)
					playback.apply(sprite, Vector2.ONE*profile.pixel_scale)
					selected[str(sprite.animation)] = true
					if str(sprite.animation) == clip: phases[sprite.frame] = true
					if sprite.frame < 0 or sprite.frame >= frames.get_frame_count(sprite.animation): invalid_frame = true
				row["playback_observed_phases"] = phases.keys()
				row["playback_selected_clips"] = selected.keys()
				row["playback_invalid_frame"] = invalid_frame
				row["profile_attack_marker"] = profile.attack_hit_frame
				if invalid_frame: result.failures.append("PLAYBACK_FRAME_OUT_OF_BOUNDS")
			result.resolved.append(row)
	sprite.free()
	return result

func _run() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PR122_APPROVAL_PLAN")))
	var report := {"schema": "pr122-normal-frame-audit-godot-v1", "engine": Engine.get_version_info().string,
		"plan_HEAD": plan.head, "art_quality_review": "REQUIRES_SEPARATE_VISUAL_AND_MAIN_EVIDENCE", "approval_changes": 0, "resources": []}
	for group: Dictionary in plan.resources:
		var resource := {"frames": group.frames, "source_files": [], "clips": {}, "entries": [], "failures": []}
		var textures: Array[ImageTexture] = []
		for path: String in group.texture_paths:
			var image := Image.new()
			var error: Error = image.load(path)
			var source := {"path": path, "file_present": FileAccess.file_exists(path), "load_error": error}
			if error != OK or image.is_empty():
				resource.failures.append("PNG_LOAD_FAILED:" + path)
			else:
				source["size"] = [image.get_width(), image.get_height()]
				var texture := ImageTexture.create_from_image(image)
				texture.take_over_path(path)
				textures.append(texture)
			resource.source_files.append(source)
		var frames: SpriteFrames = null
		if resource.failures.is_empty():
			frames = ResourceLoader.load(group.frames, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE) as SpriteFrames
		if frames == null:
			resource.failures.append("SPRITEFRAMES_LOAD_FAILED")
			for entry: Dictionary in group.entries:
				resource.entries.append({"entry_id": entry.id, "key": entry.id, "scope": entry.scope,
					"category": entry.category, "frames": entry.frames,
					"failures": resource.failures.duplicate(), "resolved": []})
		else:
			for name: String in frames.get_animation_names():
				var frame_rows: Array = []
				for index: int in range(frames.get_frame_count(name)):
					frame_rows.append(_frame(frames.get_frame_texture(name, index), index, frames.get_frame_duration(name, index)))
				resource.clips[name] = {"count": frames.get_frame_count(name), "speed": frames.get_animation_speed(name), "loop": frames.get_animation_loop(name), "frames": frame_rows}
			for entry: Dictionary in group.entries:
				resource.entries.append(_resolve(entry, frames))
		resource["SpriteFrames_loaded"] = frames != null
		report.resources.append(resource)
		# Report stores primitive metadata only. Free the decoded resource and
		# PNG textures before loading the next shared source family.
		frames = null
		textures.clear()
		await process_frame
	var output := FileAccess.open(OS.get_environment("PR122_APPROVAL_REPORT"), FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_APPROVAL_RESOURCE_AUDIT_DONE resources=%d engine=%s approvals_added=0" % [report.resources.size(), report.engine])
	quit(0)
