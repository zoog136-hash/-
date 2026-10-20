extends SceneTree
## Articulated common run candidate. Source identity / final visual review HOLD.
## Bone transforms are baked without whole-character X scaling or frame repetition.
var revision: String
var OUT: String
var SOURCE: String
var recipe: Dictionary
var target_ids: Array[String] = []
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

func _initialize() -> void:
	call_deferred("_run")

func _canvas(texture: AtlasTexture) -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	# Import-time alpha-border repair can change transparent / edge RGB. Read
	# the preserved PNG bytes for the source-material contract instead.
	var source := Image.new()
	assert(source.load_png_from_buffer(FileAccess.get_file_as_bytes(texture.atlas.resource_path)) == OK)
	image.blit_rect(source, Rect2i(texture.region), Vector2i(texture.margin.position))
	return image

func _leg(skeleton: Skeleton2D, point: Vector2, knee: Vector2, ankle: Vector2) -> Array[Bone2D]:
	var lengths := Vector2(point.distance_to(knee), knee.distance_to(ankle))
	var thigh := Bone2D.new()
	thigh.set_autocalculate_length_and_angle(false)
	thigh.length = lengths.x
	thigh.bone_angle = PI / 2.0
	thigh.position = point
	thigh.rotation = (knee - point).angle() - PI / 2.0
	thigh.rest = thigh.transform
	skeleton.add_child(thigh)
	var shin := Bone2D.new()
	shin.set_autocalculate_length_and_angle(false)
	shin.length = lengths.y
	shin.bone_angle = PI / 2.0
	shin.position = Vector2(0, lengths.x)
	shin.rotation = (ankle - knee).angle() - PI / 2.0 - thigh.rotation
	shin.rest = shin.transform
	thigh.add_child(shin)
	var boot := Bone2D.new()
	boot.set_autocalculate_length_and_angle(false)
	boot.length = 4
	boot.position = Vector2(0, lengths.y)
	boot.rotation = -(thigh.rotation + shin.rotation)
	boot.rest = boot.transform
	shin.add_child(boot)
	for bone: Bone2D in [thigh, shin, boot]:
		bone.set_meta("source_inverse_bind", bone.global_transform.affine_inverse())
	thigh.set_meta("bind_knee_y", knee.y - point.y)
	thigh.set_meta("bind_ankle_y", ankle.y - point.y)
	thigh.set_meta("bind_joints", [point, knee, ankle])
	return [thigh, shin, boot]

func _opaque_bounds(image: Image) -> Rect2i:
	var bounds := Rect2i(256, 256, 0, 0)
	var first := true
	for y: int in range(256):
		for x: int in range(256):
			if image.get_pixel(x, y).a <= 16.0 / 255.0: continue
			if first:
				bounds = Rect2i(x, y, 1, 1)
				first = false
			else: bounds = bounds.merge(Rect2i(x, y, 1, 1))
	return bounds

func _material_center(image: Image, left: int, right: int, y: int, fallback: float) -> float:
	var xs: Array[int] = []
	for row: int in range(y - 2, y + 3):
		for x: int in range(left, right):
			if row >= 0 and row < 256 and image.get_pixel(x, row).a > 16.0 / 255.0: xs.append(x)
	if xs.is_empty(): return fallback
	xs.sort()
	return float(xs[xs.size() / 2])

func _leg_split(image: Image, bounds: Rect2i, ground: int) -> int:
	var split := int(_material_center(image, bounds.position.x, bounds.end.x, ground - 12, bounds.get_center().x))
	var best_score: int = 0
	for y: int in range(ground - 12, ground - 2):
		var runs: Array[Vector2i] = []
		for x: int in range(bounds.position.x, bounds.end.x):
			if image.get_pixel(x, y).a <= 16.0 / 255.0: continue
			if not runs.is_empty() and x == runs[-1].y + 1: runs[-1].y = x
			else: runs.append(Vector2i(x, x))
		for i: int in range(runs.size() - 1):
			var a: Vector2i = runs[i]
			var b: Vector2i = runs[i + 1]
			if a.y - a.x < 2 or b.y - b.x < 2: continue
			var gap := b.x - a.y - 1
			var score := gap * mini(a.y - a.x + 1, b.y - b.x + 1)
			if score > best_score:
				best_score = score
				split = int(round((a.y + b.x) * .5))
	return split

func _sole_y(image: Image, left: int, right: int, fallback: int) -> int:
	for y: int in range(fallback - 1, fallback - 20, -1):
		var count: int = 0
		for x: int in range(left, right):
			if image.get_pixel(x, y).a > 16.0 / 255.0: count += 1
		if count >= 3: return y + 1
	return fallback

func _pose(bones: Array[Bone2D], hip: Vector2, ankle: Vector2, lengths: Vector2, bend_sign: float) -> void:
	var delta := ankle - hip
	var distance := clampf(delta.length(), absf(lengths.x - lengths.y) + .01, lengths.x + lengths.y - .01)
	var bearing := delta.angle()
	var bend := acos(clampf((lengths.x * lengths.x + distance * distance - lengths.y * lengths.y) / (2.0 * lengths.x * distance), -1.0, 1.0))
	var knee := hip + Vector2.from_angle(bearing + bend * bend_sign) * lengths.x
	bones[0].position = hip
	bones[0].rotation = (knee - hip).angle() - PI / 2.0
	bones[1].rotation = (ankle - knee).angle() - PI / 2.0 - bones[0].rotation
	bones[2].rotation = -(bones[0].rotation + bones[1].rotation)

func _raster_piece(source: Image, result: Image, rect: Rect2i, source_root: Vector2, bone: Bone2D) -> void:
	# Inverse nearest sampling from the ORIGINAL source part, with rotation and
	# translation only. Bone lengths and local material widths remain fixed.
	var warp := bone.global_transform * Transform2D(0.0, -source_root)
	var inverse := warp.affine_inverse()
	var corners: Array[Vector2] = [Vector2(rect.position), Vector2(rect.end), Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]
	var bounds := Rect2(warp * corners[0], Vector2.ZERO)
	for corner: Vector2 in corners: bounds = bounds.expand(warp * corner)
	var area := Rect2i(bounds.grow(2)).intersection(Rect2i(0, 0, 256, 256))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var q := Vector2i((inverse * Vector2(x + .5, y + .5)).floor())
			if not rect.has_point(q): continue
			var color := source.get_pixelv(q)
			if color.a > 0.0: result.set_pixel(x, y, color)

func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value, "  ") + "\n")

func _skin_vertex(point: Vector2, center: Vector2, bones: Array[Bone2D], root_down: float) -> Vector2:
	var rigid := point + Vector2(0, root_down)
	var thigh: Vector2 = bones[0].global_transform * (bones[0].get_meta("source_inverse_bind") as Transform2D) * point
	var shin: Vector2 = bones[1].global_transform * (bones[1].get_meta("source_inverse_bind") as Transform2D) * point
	var boot: Vector2 = bones[2].global_transform * (bones[2].get_meta("source_inverse_bind") as Transform2D) * point
	var y := point.y - center.y
	if y < 5: return rigid.lerp(thigh, _blend_weight(y / 5.0))
	if y < 15: return thigh.lerp(shin, _blend_weight((y - 9.0) / 6.0))
	return shin.lerp(boot, _blend_weight((y - 21.0) / 5.0))

func _blend_weight(value: float) -> float:
	var weight := clampf(value, 0, 1)
	var smooth: bool = recipe.get("smooth_skin", false)
	if not OS.get_environment("TWILIGHT_HERO_SMOOTH_SKIN").is_empty(): smooth = OS.get_environment("TWILIGHT_HERO_SMOOTH_SKIN") == "1"
	return smoothstep(0.0, 1.0, weight) if smooth else weight

func _triangle(source: Image, result: Image, uv: Array[Vector2], positions: Array[Vector2]) -> void:
	var raster_scale := float(result.get_width()) / 256.0
	var a: Vector2 = positions[0] * raster_scale
	var b: Vector2 = positions[1] * raster_scale
	var c: Vector2 = positions[2] * raster_scale
	var determinant: float = (b - a).cross(c - a)
	if absf(determinant) < .00001: return
	var bounds := Rect2(a, Vector2.ZERO).expand(b).expand(c).grow(1)
	var area := Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO, result.get_size()))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var relative := Vector2(x + .5, y + .5) - a
			var u: float = relative.cross(c - a) / determinant
			var v: float = (b - a).cross(relative) / determinant
			if u < -.001 or v < -.001 or u + v > 1.001: continue
			var sample := Vector2i((uv[0] * (1.0 - u - v) + uv[1] * u + uv[2] * v).floor())
			if sample.x < 0 or sample.y < 0 or sample.x >= 256 or sample.y >= 256: continue
			var color := source.get_pixelv(sample)
			if color.a > 0: result.set_pixel(x, y, color)

func _raster_skin(source: Image, result: Image, rect: Rect2i, center: Vector2, bones: Array[Bone2D], root_down: float) -> void:
	# Continuous two-pixel triangulation with linear bone weights bridges the
	# original hip/knee/ankle material. No disconnected rigid limb rectangles.
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var uv: Array[Vector2] = [Vector2(x, y), Vector2(x + 1, y), Vector2(x, y + 1), Vector2(x + 1, y + 1)]
			var points: Array[Vector2] = []
			for point: Vector2 in uv: points.append(_skin_vertex(point, center, bones, root_down))
			_triangle(source, result, [uv[0], uv[1], uv[2]], [points[0], points[1], points[2]])
			_triangle(source, result, [uv[1], uv[3], uv[2]], [points[1], points[3], points[2]])

func _raster_combined_skin(source: Image, result: Image, rect: Rect2i, centers: Array, legs: Array, root_down: float, split: int) -> void:
	# One shared mesh. A hard per-leg texture cut could bisect a toe or cloth
	# bridge; smooth source-space weights retain that material's connectivity.
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var uv: Array[Vector2] = [Vector2(x, y), Vector2(x + 1, y), Vector2(x, y + 1), Vector2(x + 1, y + 1)]
			var points: Array[Vector2] = []
			for point: Vector2 in uv:
				var a := _skin_vertex(point, centers[0], legs[0], root_down)
				var b := _skin_vertex(point, centers[1], legs[1], root_down)
				var distances: Array[float] = []
				for chain: Array[Bone2D] in legs:
					var joints: Array = chain[0].get_meta("bind_joints")
					var upper := Geometry2D.get_closest_point_to_segment(point, joints[0], joints[1])
					var lower := Geometry2D.get_closest_point_to_segment(point, joints[1], joints[2])
					distances.append(minf(point.distance_to(upper), point.distance_to(lower)))
				points.append(a.lerp(b, smoothstep(-2.0, 2.0, distances[0] - distances[1])))
			_triangle(source, result, [uv[0], uv[1], uv[2]], [points[0], points[1], points[2]])
			_triangle(source, result, [uv[1], uv[3], uv[2]], [points[1], points[3], points[2]])

func _run() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/remake/pr122-hero-parallel/recipes.json"))
	var name := OS.get_environment("TWILIGHT_HERO_RECIPE")
	if name.is_empty(): name = "lance"
	assert(recipes.has(name))
	recipe = recipes[name]
	assert(str(recipe.group).is_valid_identifier())
	revision = OS.get_environment("TWILIGHT_HERO_REVISION")
	if revision.is_empty(): revision = str(recipe.revision)
	SOURCE = str(recipe.source)
	assert(SOURCE.begins_with("res://assets/actors/eight_direction/"))
	OUT = "res://assets/actors/eight_direction/hero_parallel/" + str(recipe.group) + "/" + revision + "/"
	for sid: String in recipe.targets:
		assert(sid.is_valid_int())
		target_ids.append(sid)
	assert(revision.begins_with("r") and revision.substr(1).is_valid_int())
	var verify_only: bool = OS.get_environment("TWILIGHT_HERO_VERIFY_BAKE") == "1"
	assert(verify_only or not FileAccess.file_exists(OUT + "run.png"), "Preserve prior output; select a new revision before baking")
	DirAccess.make_dir_recursive_absolute(OUT)
	var source: SpriteFrames = load(SOURCE)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	# Preserve exact approved donor attack/hit/death textures and durations.
	# These are inherited legacy clips, not newly authored or visually approved.
	for key: StringName in source.get_animation_names():
		if str(key).begins_with("walk_"): continue
		frames.add_animation(key)
		frames.set_animation_loop(key, source.get_animation_loop(key))
		frames.set_animation_speed(key, source.get_animation_speed(key))
		for index: int in range(source.get_frame_count(key)):
			frames.add_frame(key, source.get_frame_texture(key, index), source.get_frame_duration(key, index))
	var atlas := Image.create(256 * 6, 256 * 8, false, Image.FORMAT_RGBA8)
	var proofs: Array = []
	var rig_root := Node2D.new()
	root.add_child(rig_root)
	for direction: int in range(8):
		var reference_track := "idle_" + str(direction)
		var reference_frame: int = 0
		if direction in [0, 4] and not OS.get_environment("TWILIGHT_HERO_OPEN_SIDE_POSE").is_empty():
			reference_track = "walk_" + str(direction)
			reference_frame = int(OS.get_environment("TWILIGHT_HERO_OPEN_SIDE_POSE"))
			assert(reference_frame >= 0 and reference_frame < source.get_frame_count(reference_track))
		var reference_override: String = OS.get_environment("TWILIGHT_HERO_REFERENCE_OVERRIDE")
		var overrides: Dictionary = recipe.get("reference_override", {})
		if not reference_override.is_empty(): overrides = JSON.parse_string(reference_override)
		if not overrides.is_empty():
			if overrides.has(str(direction)):
				reference_track = str(overrides[str(direction)].track)
				reference_frame = int(overrides[str(direction)].frame)
				assert(source.has_animation(reference_track) and reference_frame >= 0 and reference_frame < source.get_frame_count(reference_track))
		var neutral_texture: AtlasTexture = source.get_frame_texture(reference_track, reference_frame)
		var neutral := _canvas(neutral_texture)
		var box := _opaque_bounds(neutral)
		var ground: float = float(box.end.y)
		var hip_y: float = ground - 28.0
		var split: int = box.get_center().x
		var skin_split: int = split + int(OS.get_environment("TWILIGHT_HERO_SPLIT_SHIFT"))
		var per_direction := OS.get_environment("TWILIGHT_HERO_SPLITS").split(",", false)
		if not per_direction.is_empty():
			assert(per_direction.size() == 8)
			skin_split = split + int(per_direction[direction])
		elif OS.get_environment("TWILIGHT_HERO_SPLIT_SHIFT").is_empty():
			skin_split = split + int(recipe.splits[direction])
		# Initial partitions are an explicit unreviewed fit. They are saved so
		# seam/leg/weapon checks can reject the candidate, never silently approved.
		var alpha_box := neutral.get_used_rect()
		var lower := Rect2i(alpha_box.position.x, int(hip_y), alpha_box.size.x, alpha_box.end.y - int(hip_y))
		var skeleton := Skeleton2D.new()
		rig_root.add_child(skeleton)
		var centers := [Vector2(split - 4, hip_y), Vector2(split + 4, hip_y)]
		var legs: Array = []
		var leg_lengths: Array[Vector2] = []
		var source_joints: Array = []
		var source_soles: Array[int] = []
		for index: int in range(2):
			var left: int = lower.position.x if index == 0 else split
			var right: int = split if index == 0 else lower.end.x
			var knee := Vector2(_material_center(neutral, left, right, int(hip_y) + 12, centers[index].x), hip_y + 12)
			# A robe's widest cloth area is not an anatomical knee. The optional
			# hidden control stays inside the pelvis; record it as an authored fit.
			if recipe.has("knee_lateral_limit"):
				var limit: float = recipe.knee_lateral_limit
				knee.x = clampf(knee.x, centers[index].x - limit, centers[index].x + limit)
			var sole_y := int(ground)
			var ankle := Vector2(_material_center(neutral, left, right, sole_y - 4, knee.x), sole_y - 4)
			if recipe.has("knee_lateral_limit"):
				# Cloth silhouettes cannot locate the concealed foot either. Author
				# a balanced internal chain, retaining the original pixels and width.
				var limit: float = recipe.knee_lateral_limit
				ankle.x = clampf(ankle.x, centers[index].x - limit, centers[index].x + limit)
				knee.x = lerpf(centers[index].x, ankle.x, .5)
			legs.append(_leg(skeleton, centers[index], knee, ankle))
			leg_lengths.append(Vector2(centers[index].distance_to(knee), knee.distance_to(ankle)))
			source_joints.append({"hip": [centers[index].x, centers[index].y], "knee": [knee.x, knee.y], "ankle": [ankle.x, ankle.y], "fit_kind": "authored_hidden_robe_control" if recipe.has("knee_lateral_limit") else "source_material_median_fit"})
			source_soles.append(sole_y)
		var forward := Vector2(cos(direction * PI / 4.0), sin(direction * PI / 4.0) * .45)
		var hashes: Dictionary = {}
		for phase: int in range(6):
			# Four-times raster coverage preserves thin source-material connections
			# through rotation; no post-hoc bridge pixels or component deletion.
			var raster_size: int = 2048 if OS.get_environment("TWILIGHT_HERO_RASTER_8X") == "1" else 1024
			var result := Image.create(raster_size, raster_size, false, Image.FORMAT_RGBA8)
			var stage: int = phase % 3
			var root_down: float = [9.0, 11.0, 3.0][stage]
			var pose: Dictionary = {"direction": DIRECTIONS[direction], "phase": phase, "support": "AIR" if stage == 2 else ("A" if phase < 3 else "B"), "root_down": root_down, "legs": []}
			for leg_index: int in range(2):
				var supporting: bool = (phase < 3) == (leg_index == 0)
				var step: float = ([12.0, -3.0, -11.0] if supporting else [-11.0, 7.0, 12.0])[stage]
				var lift: float = ([0.0, 0.0, 5.0] if supporting else [9.0, 13.0, 5.0])[stage]
				var hip: Vector2 = centers[leg_index] + Vector2(0, root_down)
				var ankle := Vector2(centers[leg_index].x, source_soles[leg_index] - 4.0) + forward * step - Vector2(0, lift)
				var requested_ankle := ankle
				# A folded airborne leg may have an unreachable projected target.
				# Fit that free-leg trajectory to its actual source link lengths;
				# a stance foot is never moved to hide a contact error.
				if not supporting or stage == 2:
					var delta := ankle - hip
					var lengths: Vector2 = leg_lengths[leg_index]
					var reach := clampf(delta.length(), absf(lengths.x - lengths.y) + .25, lengths.x + lengths.y - .25)
					ankle = hip + delta.normalized() * reach
				var bones: Array[Bone2D] = legs[leg_index]
				_pose(bones, hip, ankle, leg_lengths[leg_index], -1.0 if forward.x >= 0 else 1.0)
				var left: int = lower.position.x if leg_index == 0 else skin_split
				var width: int = skin_split - lower.position.x if leg_index == 0 else lower.end.x - skin_split
				if not recipe.get("continuous_cloth_mesh", false):
					_raster_skin(neutral, result, Rect2i(left, int(hip_y), width, lower.size.y), centers[leg_index], bones, root_down)
				var actual_ankle: Vector2 = bones[2].global_position
				if actual_ankle.distance_to(ankle) >= .02:
					push_error("HERO_IK_REACH_FAIL direction=%d phase=%d leg=%d lengths=%s target=%s actual=%s" % [direction, phase, leg_index, leg_lengths[leg_index], ankle, actual_ankle])
					quit(1)
					return
				pose.legs.append({"leg": leg_index, "hip": [hip.x, hip.y], "knee": [bones[1].global_position.x, bones[1].global_position.y], "ankle": [actual_ankle.x, actual_ankle.y], "requested_ankle": [requested_ankle.x, requested_ankle.y], "lift": lift, "bone_lengths": [leg_lengths[leg_index].x, leg_lengths[leg_index].y], "source_joints": source_joints[leg_index], "source_sole_y": source_soles[leg_index]})
			if recipe.get("continuous_cloth_mesh", false):
				_raster_combined_skin(neutral, result, lower, centers, legs, root_down, skin_split)
			# Foreground upper armour / weapon remains the exact donor material.
			# A lifted thigh passes behind that layer rather than overwriting it.
			result.generate_mipmaps()
			result.resize(256, 256, Image.INTERPOLATE_TRILINEAR)
			result.clear_mipmaps()
			result.blit_rect(neutral, Rect2i(0, 0, 256, int(hip_y)), Vector2i(0, int(root_down)))
			var hasher := HashingContext.new()
			hasher.start(HashingContext.HASH_SHA256)
			hasher.update(result.get_data())
			var hash_value := hasher.finish().hex_encode()
			assert(not hashes.has(hash_value), "Repeated run pose is forbidden")
			hashes[hash_value] = true
			pose["rgba_sha256"] = hash_value
			pose["source_reference"] = {"track": reference_track, "frame": reference_frame, "atlas": neutral_texture.atlas.resource_path, "region": [neutral_texture.region.position.x, neutral_texture.region.position.y, neutral_texture.region.size.x, neutral_texture.region.size.y], "margin_position": [neutral_texture.margin.position.x, neutral_texture.margin.position.y]}
			pose["source_partition"] = {"split_x": skin_split, "bind_split_x": split, "hip_y": hip_y, "ground_y": ground, "review": "SOURCE_BIND_FIXED_MATERIAL_PARTITION_FIT"}
			proofs.append(pose)
			atlas.blit_rect(result, Rect2i(0, 0, 256, 256), Vector2i(phase * 256, direction * 256))
		skeleton.queue_free()
	if verify_only:
		var saved := Image.new()
		assert(saved.load_png_from_buffer(FileAccess.get_file_as_bytes(OUT + "run.png")) == OK)
		assert(saved.get_data() == atlas.get_data(), "Rebake must match all 48 saved RGBA poses exactly")
		print("HERO_RUN_REPRODUCIBLE_RGBA_PASS poses=48 writes=0 approvals=0")
		quit(0)
		return
	assert(atlas.save_png(OUT + "run.png") == OK)
	var texture := ImageTexture.create_from_image(atlas)
	texture.take_over_path(OUT + "run.png")
	for direction: int in range(8):
		var key := "run_" + str(direction)
		frames.add_animation(key)
		frames.set_animation_speed(key, 18.0)
		frames.set_animation_loop(key, true)
		for phase: int in range(6):
			var view := AtlasTexture.new()
			view.atlas = texture
			view.region = Rect2(phase * 256, direction * 256, 256, 256)
			view.filter_clip = true
			frames.add_frame(key, view)
	frames.set_meta("twilight_native_locomotion_staging", true)
	frames.set_meta("hero_parallel_candidate", true)
	frames.set_meta("final_approved", false)
	assert(ResourceSaver.save(frames, OUT + "SpriteFrames.tres") == OK)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	for sid: String in target_ids:
		var row: Dictionary = {}
		for item: Dictionary in catalog:
			if str(item.sourceId) == sid: row = item
		assert(not row.is_empty() and row.grade == "영웅")
		var profile: Resource = CATALOG.for_record("transform", row, row.image_path)
		profile.frames_path = OUT + "SpriteFrames.tres"
		profile.movement_fps = 18.0
		profile.set_meta("hero_parallel_candidate", true)
		profile.set_meta("final_approved", false)
		var folder := "res://assets/actors/eight_direction/hero_parallel/" + str(recipe.profile_prefix) + sid + "/" + revision + "/"
		DirAccess.make_dir_recursive_absolute(folder)
		assert(ResourceSaver.save(profile, folder + "NativeMotionProfile.tres") == OK)
		var entry: Dictionary = staging.actors["transform:" + sid]
		entry.merge({"status": "RIG_CANDIDATE_QUALITY_HOLD", "frames": OUT + "SpriteFrames.tres", "native_profile": folder + "NativeMotionProfile.tres", "rig": OUT + "rig-proof.json", "source_donor": str(recipe.source_donor), "source_frames_sha256": FileAccess.get_sha256(SOURCE), "new_run_poses": 48, "independent_validation": "NOT_RUN", "quality_holds": ["ORIGINAL_CHARACTER_IDENTITY", "HEURISTIC_LIMB_PARTITIONS_AND_SEAMS", "FOOT_CONTACT_CADENCE_VISUAL_REVIEW", "PALETTE_WEAPON_IDENTITY_REVIEW"], "production_connected": false, "final_approved": false}, true)
	_write_json(OUT + "rig-proof.json", {"schema": "hero-parallel-bone-run-v1", "engine": Engine.get_version_info().string, "source": SOURCE, "source_sha256": FileAccess.get_sha256(SOURCE), "new_unique_run_poses": 48, "method": "Skeleton2D/Bone2D fixed-length IK, continuous linear blend skin triangles, nearest source material, shared 8 directions", "scope": "CANDIDATE_NOT_VISUAL_ORIGINAL_IDENTITY_APPROVAL", "frames": proofs})
	_write_json("res://data/pr122_hero_parallel_staging.json", staging)
	print("HERO_RUN_BAKE_OK unique_run_poses=48 shared_targets=%d walk_tracks=0 approvals=0" % target_ids.size())
	quit(0)
