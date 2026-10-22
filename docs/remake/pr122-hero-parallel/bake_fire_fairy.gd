extends SceneTree
## Original portrait parts, articulated wings/tendrils, actual 3D yaw projection.
## File-only production; no game catalog, physics or shared runtime writes.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const DEATH = preload("res://docs/remake/pr122-hero-parallel/shared_death_policy.gd")
const SOURCE := "res://assets/catalog/64d25f3ba900292ba831c0b3.png"
var out: String
var source: Image
var parts: Array[Dictionary] = []
var lineage: Dictionary = {}
var run_proof: Array = []
var verify: bool

func _json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data, "  ") + "\n")

func _hash(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

func _initialize() -> void:
	call_deferred("_run")

func _part(name: String, polygon: Array, anchor: Vector2, kind: String, side: float) -> void:
	var uv := PackedVector2Array()
	for p: Array in polygon: uv.append(Vector2(p[0], p[1]))
	var triangles := Geometry2D.triangulate_polygon(uv)
	assert(not triangles.is_empty())
	parts.append({"name": name, "uv": uv, "triangles": triangles, "anchor": anchor, "kind": kind, "side": side})

func _leg_center_x(part: Dictionary, y: float) -> float:
	var points: Array = [[74,60],[82,50],[88,45],[97,42],[101,37],[104,34]] if part.side < 0 else [[76,54],[86,53],[95,52],[101,49],[104,45]]
	if y <= points[0][0]: return float(points[0][1])
	for i: int in range(1, points.size()):
		if y <= points[i][0]: return lerpf(points[i-1][1], points[i][1], (y - float(points[i-1][0])) / float(points[i][0] - points[i-1][0]))
	return float(points[-1][1])

func _vertex(uv: Vector2, part: Dictionary, pose: Dictionary) -> Vector3:
	var d: Vector2 = uv - part.anchor
	var point: Vector3
	match str(part.kind):
		"fore", "hind":
			var local: Vector2 = d.rotated(deg_to_rad(-55.0 if part.kind == "fore" else -20.0))
			local.x *= float(part.side)
			var angle: float = pose.flap + (pose.hind_lag if part.kind == "hind" else 0.0)
			point = Vector3(local.x * cos(angle), local.y + (-2.0 if part.kind == "fore" else 1.5), absf(local.x) * sin(angle))
		"body":
			point = Vector3(d.x * .75, d.y * .35, -d.y)
			point = point.rotated(Vector3.RIGHT, pose.fall)
		_:
			var phase: float = pose.leg_phase + (0.0 if part.side < 0.0 else PI)
			var blend: float = clampf(d.y / 38.0, 0.0, 1.0)
			var hip_delta: Vector2 = (part.anchor as Vector2) - Vector2(61,73)
			var hip := Vector3(hip_delta.x * .75, hip_delta.y * .35, -hip_delta.y)
			point = hip + Vector3(d.x * .15, -d.x * .60 + sin(phase) * 6.0 * blend, -d.y + cos(phase) * 2.0 * blend)
			point = point.rotated(Vector3.RIGHT, pose.fall)
	if pose.is_death and part.kind not in ["fore", "hind"]: point.z *= maxf(0.0, cos(pose.fall))
	point.y += pose.lunge
	return point.rotated(Vector3.BACK, pose.yaw)

func _project(point: Vector3, height: float) -> Vector2:
	return Vector2(128.0 + point.x, 160.0 + point.y * .5 - point.z - height)

func _triangle(image: Image, uv: Array[Vector2], positions: Array[Vector2], shade: float) -> void:
	var scale := float(image.get_width()) / 256.0
	var a: Vector2 = positions[0] * scale
	var b: Vector2 = positions[1] * scale
	var c: Vector2 = positions[2] * scale
	var det: float = (b - a).cross(c - a)
	if absf(det) < .00001: return
	var bounds := Rect2(a, Vector2.ZERO).expand(b).expand(c).grow(1)
	var area := Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var relative := Vector2(x + .5, y + .5) - a
			var u := relative.cross(c - a) / det
			var v := (b - a).cross(relative) / det
			if u < -.0001 or v < -.0001 or u + v > 1.0001: continue
			var sample := Vector2i((uv[0] * (1.0 - u - v) + uv[1] * u + uv[2] * v).floor())
			if sample.x < 0 or sample.y < 0 or sample.x >= source.get_width() or sample.y >= source.get_height(): continue
			var color := source.get_pixelv(sample)
			# Portrait-only outer black matte is excluded from derived part layers.
			if color.a <= 0.0 or maxf(color.r, maxf(color.g, color.b)) <= .10: continue
			color.r *= shade
			color.g *= shade
			color.b *= shade
			var old := image.get_pixel(x, y)
			var alpha: float = color.a + old.a * (1.0 - color.a)
			image.set_pixel(x, y, Color((color.r * color.a + old.r * old.a * (1.0 - color.a)) / alpha, (color.g * color.a + old.g * old.a * (1.0 - color.a)) / alpha, (color.b * color.a + old.b * old.a * (1.0 - color.a)) / alpha, alpha))

func _pose(role: String, direction: int, phase: int) -> Dictionary:
	var data := {"yaw": direction * PI / 4.0 + PI / 2.0, "flap": 0.0, "hind_lag": .1, "height": 47.0, "leg_phase": phase * TAU / 6.0, "fall": 0.0, "lunge": 0.0, "shade": 1.0, "body_shade": .8 + .2 * sin(direction * PI / 4.0), "is_death": role == "death"}
	match role:
		"idle":
			data.flap = deg_to_rad([25.0, 60.0, 12.0][phase])
			data.height = [47.0, 48.0, 46.0][phase]
		"run":
			data.flap = deg_to_rad([-45.0, 0.0, 50.0, 65.0, 15.0, -60.0][phase])
			data.height = [50.0, 51.0, 55.0, 50.0, 51.0, 55.0][phase]
		"attack":
			data.flap = deg_to_rad([55.0, -35.0, 15.0, 40.0, 25.0, 10.0][phase])
			data.lunge = [0.0, -14.0, -8.0, -3.0, 1.0, 0.0][phase]
		"hit":
			data.flap = deg_to_rad([20.0, 5.0, 30.0][phase])
			data.lunge = [4.0, 7.0, 2.0][phase]
			data.fall = [-.1, -.2, -.05][phase]
		"death":
			data.flap = deg_to_rad([20.0, 50.0, 35.0, 10.0, 0.0, 0.0][phase])
			data.height = [46.0, 37.0, 25.0, 11.0, 2.0, 1.0][phase]
			data.fall = [0.0, .2, .5, 1.0, 1.45, PI / 2.0][phase]
			data.shade = [1.0, 1.0, .95, .9, .85, .8][phase]
	return data

func _render(pose: Dictionary) -> Image:
	var image := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	var drawing: Array = []
	for part: Dictionary in parts:
		var points: Array[Vector2] = []
		var depth := 0.0
		for uv: Vector2 in part.uv:
			var transverse := 0.0
			var sample := uv
			if part.kind == "leg":
				var center_x := _leg_center_x(part, uv.y)
				transverse = uv.x - center_x
				sample.x = center_x
			var point := _vertex(sample, part, pose)
			var projected := _project(point, pose.height)
			projected.x += transverse * .85 # Camera-facing thin tendril ribbon, retains painted width.
			points.append(projected)
			depth += point.y
		drawing.append({"part": part, "points": points, "depth": depth / part.uv.size()})
	drawing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for item: Dictionary in drawing:
		var part: Dictionary = item.part
		for index: int in range(0, part.triangles.size(), 3):
			var uv: Array[Vector2] = []
			var points: Array[Vector2] = []
			for offset: int in range(3):
				var vertex: int = part.triangles[index + offset]
				uv.append(part.uv[vertex])
				points.append(item.points[vertex])
			_triangle(image, uv, points, pose.shade * (pose.body_shade if part.kind == "body" else 1.0))
	image.generate_mipmaps()
	image.resize(256, 256, Image.INTERPOLATE_TRILINEAR)
	image.clear_mipmaps()
	return image

func _run() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	var revision := OS.get_environment("TWILIGHT_HERO_FAIRY_REVISION")
	if revision.is_empty(): revision = "r001"
	assert(revision.begins_with("r") and revision.substr(1).is_valid_int())
	out = "res://assets/actors/eight_direction/hero_parallel/fire_fairy_405/" + revision + "/"
	verify = OS.get_environment("TWILIGHT_HERO_VERIFY_BAKE") == "1"
	assert(verify or not FileAccess.file_exists(out + "SpriteFrames.tres"))
	DirAccess.make_dir_recursive_absolute(out)
	source = Image.new()
	assert(source.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE)) == OK)
	for side: float in [-1.0, 1.0]:
		_part("fore_" + str(side), [[61,66],[56,54],[58,39],[62,29],[67,41],[69,54],[66,65]], Vector2(62,66), "fore", side)
		_part("hind_" + str(side), [[58,70],[47,65],[34,67],[30,70],[37,74],[49,75],[59,73]], Vector2(58,71), "hind", side)
	_part("body", [[60,64],[70,63],[76,69],[67,74],[63,83],[54,86],[52,78],[57,70]], Vector2(61,73), "body", 0.0)
	_part("leg_A", [[60,72],[62,75],[52,84],[47,90],[44,99],[38,104],[33,104],[32,101],[36,99],[40,96],[43,86],[49,79],[56,74]], Vector2(60,74), "leg", -1.0)
	_part("leg_B", [[54,74],[57,76],[55,89],[54,97],[51,103],[44,104],[43,101],[47,99],[50,94],[51,85],[51,77]], Vector2(54,76), "leg", 1.0)
	var row: Dictionary = {}
	for record: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
		if str(record.sourceId) == "405": row = record
	assert(not row.is_empty() and row.grade == "영웅")
	var profile: Resource = CATALOG.for_record("transform", row, row.image_path)
	var donor: String = profile.frames_path
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var south := SpriteFrames.new()
	south.remove_animation("default")
	var hashes: Dictionary = {SOURCE: FileAccess.get_sha256(SOURCE)}
	for sheet_name: String in ["run", "attack", "support", "death"]:
		var rows := 1 if sheet_name == "death" else 8
		var atlas := Image.create(1536, rows * 256, false, Image.FORMAT_RGBA8)
		var registrations: Array = []
		for heading: int in range(rows):
			var direction: int = 2 if sheet_name == "death" else heading
			var roles: Array = ["idle", "hit"] if sheet_name == "support" else [sheet_name]
			for role: String in roles:
				var count := 3 if role in ["idle", "hit"] else 6
				var start := 3 if role == "hit" else 0
				var track := role + "_" + str(direction)
				lineage[track] = []
				var target: SpriteFrames = south if role == "death" else frames
				target.add_animation(track)
				target.set_animation_loop(track, role in ["idle", "run"])
				target.set_animation_speed(track, 18.0 if role == "run" else (6.0 / profile.death_duration if role == "death" else 9.0))
				for phase: int in range(count):
					var pose := _pose(role, direction, phase)
					var image := _render(pose)
					var region := Rect2i((start + phase) * 256, heading * 256, 256, 256)
					atlas.blit_rect(image, Rect2i(0, 0, 256, 256), region.position)
					registrations.append({"target": target, "track": track, "region": region})
					var reference := {"atlas": out + sheet_name + ".png", "region": [region.position.x, region.position.y, 256, 256], "margin_position": [0,0]}
					var signature := _hash(image)
					lineage[track].append({"source_reference": reference, "canvas_rgba_sha256": signature, "articulation": pose})
					if role == "run": run_proof.append({"direction": direction, "phase": phase, "rgba_sha256": signature, "source_reference": reference, "root_down": 0, "source_partition": {"hip_y": 256, "review": "ORIGINAL_PARTS_PROJECTED_RIG_NOT_FAKE_LEG_BIND"}})
		var path := out + sheet_name + ".png"
		if verify:
			var old := Image.new()
			assert(old.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and old.get_data() == atlas.get_data())
		else: assert(atlas.save_png(path) == OK)
		hashes[path] = FileAccess.get_sha256(path)
		var texture := ImageTexture.create_from_image(atlas)
		texture.take_over_path(path)
		for registration: Dictionary in registrations:
			var view := AtlasTexture.new()
			view.atlas = texture
			view.region = registration.region
			view.filter_clip = true
			registration.target.add_frame(registration.track, view)
	if verify:
		print("HERO_FIRE_FAIRY_REPRO_PASS unique_rig_poses=150 writes=0")
		quit()
		return
	var result := DEATH.install_new_south_death(frames, south, out + "DeathSouth.tres")
	for direction: int in range(8): lineage["death_" + str(direction)] = lineage.death_2
	frames.set_meta("twilight_native_locomotion_staging", true)
	frames.set_meta("hero_parallel_candidate", true)
	frames.set_meta("final_approved", false)
	assert(ResourceSaver.save(south, out + "DeathSouth.tres") == OK)
	assert(ResourceSaver.save(frames, out + "SpriteFrames.tres") == OK)
	profile.frames_path = out + "SpriteFrames.tres"
	profile.movement_fps = 18.0
	profile.color_tint = Color.WHITE
	profile.floating = true
	profile.set_meta("hero_parallel_candidate", true)
	profile.set_meta("final_approved", false)
	assert(ResourceSaver.save(profile, out + "NativeMotionProfile.tres") == OK)
	var part_definitions: Array = []
	for part: Dictionary in parts:
		var coordinates: Array = []
		for uv: Vector2 in part.uv: coordinates.append([uv.x, uv.y])
		part_definitions.append({"name":part.name, "kind":part.kind, "side":part.side, "anchor":[part.anchor.x,part.anchor.y], "uv_polygon":coordinates, "triangles":Array(part.triangles)})
	_json(out + "rig-proof.json", {"schema":"hero-unique-full-atlas-v1", "engine":Engine.get_version_info().string, "source":SOURCE, "source_sha256":FileAccess.get_sha256(SOURCE), "source_hashes":hashes, "frames":run_proof, "track_sources":lineage, "unique_authored_poses":150, "runtime_phase_references":192, "preserved_donor_frames":donor, "death_policy":result, "visual_overrides":{"color_tint":"ffffff","floating":true}, "method":"Existing original portrait polygon parts, mirrored wing pair articulation, true 3D yaw/flap projection, separate alternating tendrils, source UV texture rendering", "source_part_definitions":part_definitions, "authoring_script_sha256":FileAccess.get_sha256("res://docs/remake/pr122-hero-parallel/bake_fire_fairy.gd"), "source_paintings_reused":1, "new_hand_painted_sources":0, "portrait_matte_max_rgb_excluded":.10, "final_approved":false})
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	assert(staging.actors.has("transform:405") and not staging.actors["transform:405"].final_approved)
	staging.actors["transform:405"].merge({"status":"ORIGINAL_PARTS_RIG_CANDIDATE_QUALITY_HOLD", "frames":out+"SpriteFrames.tres", "native_profile":out+"NativeMotionProfile.tres", "rig":out+"rig-proof.json", "source_donor":SOURCE, "source_frames_sha256":FileAccess.get_sha256(SOURCE), "new_run_poses":48, "new_unique_authored_poses":150, "new_death_authored_directions":["S"], "new_death_unique_poses":6, "death_policy_scope":"NEW_S_ONLY_SHARED_AT_RESOURCE_LEVEL", "death_reuse_assessment":"Existing harpy body is a different creature. Its eight-direction death art is preserved read-only; new actual fire-fairy appearance uses one authored S death.", "independent_validation":"NOT_RUN", "quality_holds":["SOURCE_PART_EXTRACTION_AND_EIGHT_VIEW_VISUAL_REVIEW","ACTUAL_MAIN_FLIGHT_AND_DEATH_REVIEW"], "production_connected":false, "final_approved":false}, true)
	_json("res://data/pr122_hero_parallel_staging.json", staging)
	print("HERO_FIRE_FAIRY_BUILD_PASS baked_rig_poses=150 reused_paintings=1 new_death_directions=1 approvals=0")
	quit()
