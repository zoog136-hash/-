extends SceneTree
## Register new art against a measured opacity-based ground CANDIDATE.
## This does not approve anatomical soles, physical contact or projected roots.
const BEFORE := "res://assets/actors/eight_direction/hero_parallel/baphomet_unique/r002/"
const OUT := "res://assets/actors/eight_direction/hero_parallel/baphomet_unique/r003/"

func _json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ") + "\n")

func _initialize() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	assert(not FileAccess.file_exists(OUT + "SpriteFrames.tres"))
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BEFORE + "rig-proof.json"))
	var support_path := "res://assets/actors/eight_direction/hero_parallel/baphomet_unique/r001/source-support.png"
	var support := Image.new()
	assert(support.load_png_from_buffer(FileAccess.get_file_as_bytes(support_path)) == OK)
	var all_ground: Array[float] = []
	var ground_by_direction: Array = []
	for direction: int in range(8):
		var values: Array[float] = []
		for phase: int in range(2):
			var ground := -1
			for y: int in range(90, 181):
				for x: int in range(45, 136):
					if support.get_pixel(phase * 181 + x, direction * 181 + y).a > 16.0 / 255.0:
						ground = maxi(ground, y + 1)
			assert(ground > 0)
			values.append(float(ground))
			all_ground.append(float(ground + 37))
		ground_by_direction.append(values)
	all_ground.sort()
	var canvas_ground: float = (all_ground[7] + all_ground[8]) * .5
	var margins: Array[int] = []
	for values: Array in ground_by_direction:
		margins.append(int(round(canvas_ground - (float(values[0]) + float(values[1])) * .5)))
	var frames: SpriteFrames = load(BEFORE + "SpriteFrames.tres").duplicate(true)
	var source_images: Dictionary = {}
	var run := Image.create(1536, 2048, false, Image.FORMAT_RGBA8)
	for track: StringName in frames.get_animation_names():
		var direction := int(str(track).get_slice("_", 1))
		for phase: int in range(frames.get_frame_count(track)):
			var texture: AtlasTexture = frames.get_frame_texture(track, phase)
			texture.margin = Rect2(37, margins[direction], 75, 75)
			var record: Dictionary = proof.track_sources[str(track)][phase]
			var reference: Dictionary = record.source_reference
			reference.margin_position = [37, margins[direction]]
			if not source_images.has(str(reference.atlas)):
				var raw := Image.new()
				assert(raw.load_png_from_buffer(FileAccess.get_file_as_bytes(str(reference.atlas))) == OK)
				source_images[str(reference.atlas)] = raw
			var source: Image = source_images[str(reference.atlas)]
			var r: Array = reference.region
			var canvas := Image.create(256, 256, false, Image.FORMAT_RGBA8)
			canvas.blit_rect(source, Rect2i(r[0], r[1], r[2], r[3]), Vector2i(37, margins[direction]))
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(canvas.get_data())
			var sha := digest.finish().hex_encode()
			record.canvas_rgba_sha256 = sha
			if str(track).begins_with("run_"):
				run.blit_rect(canvas, Rect2i(0, 0, 256, 256), Vector2i(phase * 256, direction * 256))
				var row: Dictionary = proof.frames[direction * 6 + phase]
				row.rgba_sha256 = sha
				row.source_reference.margin_position = [37, margins[direction]]
	var profile: Resource = load(BEFORE + "NativeMotionProfile.tres").duplicate(true)
	var prior_offset: Vector2 = profile.sprite_offset
	profile.frames_path = OUT + "SpriteFrames.tres"
	profile.sprite_offset = Vector2(prior_offset.x, -(canvas_ground - 128.0) * profile.pixel_scale)
	proof["ground_registration"] = {"method": "central lower-body alpha>16 candidate from two idle source cells; same row translation for every role/phase", "raw_idle_lower_center_ground": ground_by_direction, "canvas_ground": canvas_ground, "margin_y_by_direction": margins, "prior_offset_y": prior_offset.y, "offset_y": profile.sprite_offset.y, "no_per_phase_ground_snapping": true, "actual_sole_or_projected_root_approved": false, "raw_art_unchanged": true}
	DirAccess.make_dir_recursive_absolute(OUT)
	assert(run.save_png(OUT + "run.png") == OK)
	assert(ResourceSaver.save(frames, OUT + "SpriteFrames.tres") == OK)
	assert(ResourceSaver.save(profile, OUT + "NativeMotionProfile.tres") == OK)
	_json(OUT + "rig-proof.json", proof)
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var entry: Dictionary = staging.actors["transform:7"]
	entry.prior_candidates.append({"frames": entry.frames, "native_profile": entry.native_profile, "status": "UNIQUE_FULL_R002_BEFORE_SOURCE_GROUND_REGISTRATION"})
	entry.merge({"frames": OUT + "SpriteFrames.tres", "native_profile": OUT + "NativeMotionProfile.tres", "rig": OUT + "rig-proof.json", "independent_validation": "NOT_RUN"}, true)
	entry.erase("main_validation_report")
	_json("res://data/pr122_hero_parallel_staging.json", staging)
	print("HERO_UNIQUE_GROUND_REGISTERED source_pixels_unchanged=true per_phase_snap=false physical_contact_approved=false")
	quit(0)
