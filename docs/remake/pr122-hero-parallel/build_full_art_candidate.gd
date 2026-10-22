extends SceneTree
## Full unique hero candidate. One SOUTH death source, eight resource aliases.
## Uniform resampling + fixed per-sheet/view registration; no per-phase snaps.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const DEATH_POLICY = preload("res://docs/remake/pr122-hero-parallel/shared_death_policy.gd")
var OUT: String
var target_id: String
var recipe: Dictionary
const DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
var normalized: Dictionary = {}
var textures: Dictionary = {}
var anchors: Dictionary = {}
var track_sources: Dictionary = {}
var run_proofs: Array = []
var cell_size: int
var canvas_ground: float
var pad_x: int
var source_hashes: Dictionary = {}
var run_atlas: Image

func _json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data, "  ") + "\n")

func _read(path: String) -> Image:
	var image := Image.new()
	assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
	return image

func _hash(image: Image) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(image.get_data())
	return h.finish().hex_encode()

func _bounds(image: Image) -> Rect2i:
	var first := true
	var box := Rect2i()
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= 16.0 / 255.0: continue
			if first:
				box = Rect2i(x, y, 1, 1)
				first = false
			else: box = box.merge(Rect2i(x, y, 1, 1))
	assert(not first)
	return box

func _ground(image: Image) -> int:
	# Opacity-based candidate, NOT anatomical sole/projected-root approval.
	var value := -1
	for y: int in range(image.get_height() / 2, image.get_height()):
		for x: int in range(image.get_width() / 4, image.get_width() * 3 / 4):
			if image.get_pixel(x, y).a > 16.0 / 255.0: value = maxi(value, y + 1)
	assert(value > 0)
	return value

func _source_cell(name: String, phase: int, direction: int) -> Image:
	var row: int = phase / 2 if name == "death" else direction
	var column: int = phase % 2 if name == "death" else phase
	return (normalized[name] as Image).get_region(Rect2i(column * cell_size, row * cell_size, cell_size, cell_size))

func _median(values: Array[int]) -> float:
	values.sort()
	var n := values.size()
	return float(values[n / 2]) if n % 2 else (float(values[n / 2 - 1]) + float(values[n / 2])) * .5

func _register(frames: SpriteFrames, role: String, direction: int, source_name: String, start: int, count: int) -> void:
	var track := role + "_" + str(direction)
	frames.add_animation(track)
	frames.set_animation_loop(track, role in ["idle", "run"])
	frames.set_animation_speed(track, 18.0 if role == "run" else (4.0 if role == "idle" else 10.0))
	track_sources[track] = []
	var source_direction := 2 if source_name == "death" else direction
	var pad_y := int(round(canvas_ground - float(anchors[source_name][source_direction])))
	assert(pad_x >= 0 and pad_y >= 0 and pad_x + cell_size < 256 and pad_y + cell_size < 256)
	for phase: int in range(count):
		var raw_phase := start + phase
		var column: int = raw_phase % 2 if source_name == "death" else raw_phase
		var row: int = raw_phase / 2 if source_name == "death" else direction
		var region := Rect2i(column * cell_size, row * cell_size, cell_size, cell_size)
		var view := AtlasTexture.new()
		view.atlas = textures[source_name]
		view.region = Rect2(region)
		view.margin = Rect2(pad_x, pad_y, 256 - cell_size, 256 - cell_size)
		view.filter_clip = true
		frames.add_frame(track, view)
		var canvas := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(normalized[source_name], region, Vector2i(pad_x, pad_y))
		var sha := _hash(canvas)
		var reference := {"atlas": OUT + "normalized-source-" + source_name + ".png", "region": [region.position.x, region.position.y, cell_size, cell_size], "margin_position": [pad_x, pad_y]}
		track_sources[track].append({"source_reference": reference, "canvas_rgba_sha256": sha, "authored_direction": "S" if source_name == "death" else DIRECTIONS[direction]})
		if role == "run":
			run_atlas.blit_rect(canvas, Rect2i(0, 0, 256, 256), Vector2i(phase * 256, direction * 256))
			run_proofs.append({"direction": direction, "phase": phase, "rgba_sha256": sha, "source_reference": reference, "root_down": 0, "source_partition": {"hip_y": 256, "review": "EXACT_NORMALIZED_CELL_NO_FAKE_BONE_PROOF"}})

func _initialize() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	target_id = OS.get_environment("TWILIGHT_HERO_FULL_ART_ID")
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/remake/pr122-hero-parallel/full_art_recipes.json"))
	assert(recipes.has(target_id))
	recipe = recipes[target_id]
	OUT = "res://assets/actors/eight_direction/hero_parallel/" + str(recipe.group) + "/" + str(recipe.revision) + "/"
	var verify := OS.get_environment("TWILIGHT_HERO_VERIFY_BAKE") == "1"
	assert(verify or not FileAccess.file_exists(OUT + "SpriteFrames.tres"), "Preserve prior output")
	var row: Dictionary = {}
	for record: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
		if str(record.sourceId) == target_id: row = record
	assert(not row.is_empty() and row.grade == "영웅")
	var profile: Resource = CATALOG.for_record("transform", row, row.image_path)
	var old_source: SpriteFrames = load(profile.frames_path)
	var idle: AtlasTexture = old_source.get_frame_texture("idle_2", 0)
	var original_canvas: Vector2 = old_source.get_meta("twilight_canvas_size", Vector2(256, 256))
	var target_height: float = idle.region.size.y * original_canvas.y / float(idle.get_height())
	var raw_support := _read(OUT + "raw/source-support.png")
	assert(raw_support.get_size() == Vector2i(1086, 1448))
	var new_idle := raw_support.get_region(Rect2i(0, 2 * 181, 181, 181))
	cell_size = int(round(181.0 * float(target_height) / float(_bounds(new_idle).size.y)))
	assert(cell_size >= 48 and cell_size <= 180)
	pad_x = int(round(128.0 - float(cell_size) * .5))
	canvas_ground = 128.0 - profile.sprite_offset.y / profile.pixel_scale
	var lineage: Dictionary = {}
	for name: String in ["run", "attack", "support", "death"]:
		var raw_path := OUT + "raw/source-" + name + ".png"
		var raw := _read(raw_path)
		var columns := 2 if name == "death" else 6
		var rows := 3 if name == "death" else 8
		assert(raw.get_width() % columns == 0 and raw.get_height() % rows == 0)
		var raw_cell := raw.get_width() / columns
		assert(raw_cell == raw.get_height() / rows, "Never stretch a source cell's width")
		var sheet := Image.create(columns * cell_size, rows * cell_size, false, Image.FORMAT_RGBA8)
		for y: int in range(rows):
			for x: int in range(columns):
				var part := raw.get_region(Rect2i(x * raw_cell, y * raw_cell, raw_cell, raw_cell))
				part.generate_mipmaps()
				part.resize(cell_size, cell_size, Image.INTERPOLATE_TRILINEAR)
				part.clear_mipmaps()
				sheet.blit_rect(part, Rect2i(0, 0, cell_size, cell_size), Vector2i(x * cell_size, y * cell_size))
		normalized[name] = sheet
		var normalized_path := OUT + "normalized-source-" + name + ".png"
		if verify:
			assert(_read(normalized_path).get_data() == sheet.get_data(), "Normalized source RGBA reproducibility")
		else: assert(sheet.save_png(normalized_path) == OK)
		source_hashes[raw_path] = FileAccess.get_sha256(raw_path)
		source_hashes[normalized_path] = FileAccess.get_sha256(normalized_path)
		lineage[name] = {"raw_source": raw_path, "raw_cell": raw_cell, "normalized_cell": cell_size, "uniform_scale": float(cell_size) / float(raw_cell), "kernel": "Godot mipmap/trilinear", "no_per_phase_scale": true, "rgba_sha256": _hash(sheet)}
		var texture := ImageTexture.create_from_image(sheet)
		texture.take_over_path(normalized_path)
		textures[name] = texture
		var ground: Array[float] = []
		for direction: int in range(8):
			var values: Array[int] = []
			var samples: Array = [0] if name == "death" else ([0, 1, 3, 4] if name == "run" else ([0, 5] if name == "attack" else [0, 1, 2]))
			for phase: int in samples: values.append(_ground(_source_cell(name, phase, direction)))
			ground.append(_median(values))
		anchors[name] = ground
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	run_atlas = Image.create(1536, 2048, false, Image.FORMAT_RGBA8)
	for direction: int in range(8):
		_register(frames, "idle", direction, "support", 0, 3)
		_register(frames, "run", direction, "run", 0, 6)
		_register(frames, "attack", direction, "attack", 0, 6)
		_register(frames, "hit", direction, "support", 3, 3)
	var south := SpriteFrames.new()
	south.remove_animation("default")
	_register(south, "death", 2, "death", 0, 6)
	var death_result := DEATH_POLICY.install_new_south_death(frames, south, OUT + "DeathSouth.tres")
	assert(death_result.new_source_directions == 1)
	for direction: int in range(8):
		track_sources["death_" + str(direction)] = track_sources["death_2"]
	frames.set_meta("twilight_native_locomotion_staging", true)
	frames.set_meta("hero_parallel_candidate", true)
	frames.set_meta("final_approved", false)
	if verify:
		assert(_read(OUT + "run.png").get_data() == run_atlas.get_data())
		print("HERO_FULL_ART_REPRO_PASS normalized_sources=4 run_poses=48 writes=0 approvals=0")
		quit(0)
		return
	assert(run_atlas.save_png(OUT + "run.png") == OK)
	assert(ResourceSaver.save(south, OUT + "DeathSouth.tres") == OK)
	assert(ResourceSaver.save(frames, OUT + "SpriteFrames.tres") == OK)
	profile.frames_path = OUT + "SpriteFrames.tres"
	profile.color_tint = Color.WHITE
	profile.movement_fps = 18.0
	profile.set_meta("hero_parallel_candidate", true)
	profile.set_meta("final_approved", false)
	assert(ResourceSaver.save(profile, OUT + "NativeMotionProfile.tres") == OK)
	var proof := {"schema": "hero-unique-full-atlas-v1", "engine": Engine.get_version_info().string, "source": OUT + "raw/source-run.png", "source_sha256": source_hashes[OUT + "raw/source-run.png"], "source_hashes": source_hashes, "preserved_donor_frames": old_source.resource_path, "frames": run_proofs, "track_sources": track_sources, "method": "uniform source-cell normalization + fixed per-sheet/view registration; new S death shared via 8 resource aliases", "transform_lineage": lineage, "source_ground_candidates": anchors, "visual_overrides": recipe.visual_overrides, "registration": {"cell_size": cell_size, "pad_x": pad_x, "canvas_ground": canvas_ground, "actual_contact_approved": false}, "death_policy": death_result, "unique_authored_poses": 150, "runtime_phase_references": 192, "final_approved": false}
	_json(OUT + "rig-proof.json", proof)
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	assert(staging.actors.has("transform:" + target_id) and not staging.actors["transform:" + target_id].final_approved)
	staging.actors["transform:" + target_id].merge({"status": "UNIQUE_ART_FULL_CANDIDATE_QUALITY_HOLD", "frames": OUT + "SpriteFrames.tres", "native_profile": OUT + "NativeMotionProfile.tres", "rig": OUT + "rig-proof.json", "source_donor": "new generated hero-specific art; all prior donor resources preserved read-only", "source_frames_sha256": str(proof.source_sha256), "new_run_poses": 48, "new_unique_authored_poses": 150, "new_death_authored_directions": ["S"], "new_death_unique_poses": 6, "death_policy_scope": "NEW_S_ONLY_SHARED_AT_RESOURCE_LEVEL", "death_reuse_assessment": "Existing donor has a different appearance; preserve its death art and author S-only death for this new unique appearance. This does not reduce any existing candidate death directions.", "independent_validation": "NOT_RUN", "quality_holds": ["ORIGINAL_CHARACTER_IDENTITY", "CROSS_SHEET_DESIGN_CONTINUITY", "ACTUAL_FOOT_CONTACT_AND_CADENCE", "DIRECTION_CAMERA_REVIEW"], "production_connected": false, "final_approved": false}, true)
	_json("res://data/pr122_hero_parallel_staging.json", staging)
	print("HERO_FULL_ART_BUILD_PASS roles=5 nondeath_directions=8 new_death_directions=1 unique_art_poses=150 runtime_phase_refs=192 approvals=0")
	quit(0)
