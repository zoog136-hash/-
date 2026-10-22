extends SceneTree
## Exact-target existing actions plus new articulated RUN art. Never approves art.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _read(path: String) -> Image:
	var image := Image.new()
	assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
	return image

func _sha(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()

func _json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value, "  ") + "\n")

func _bounds(image: Image) -> Rect2i:
	var box := Rect2i()
	var first := true
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= 16.0 / 255.0: continue
			if first:
				box = Rect2i(x, y, 1, 1)
				first = false
			else: box = box.merge(Rect2i(x, y, 1, 1))
	assert(not first)
	return box

func _median(values: Array) -> float:
	values.sort()
	return (float(values[(values.size() - 1) / 2]) + float(values[values.size() / 2])) * .5

func _run() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	var sid := OS.get_environment("TWILIGHT_HERO_EXACT_REUSE_ID")
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/remake/pr122-hero-parallel/exact_reuse_run_recipes.json"))
	assert(recipes.has(sid))
	var recipe: Dictionary = recipes[sid]
	var out := "res://assets/actors/eight_direction/hero_parallel/" + str(recipe.group) + "/" + str(recipe.revision) + "/"
	var verify := OS.get_environment("TWILIGHT_HERO_VERIFY_BAKE") == "1"
	assert(verify or not FileAccess.file_exists(out + "SpriteFrames.tres"), "Preserve previous candidates")
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var key := "transform:" + sid
	assert(staging.actors.has(key) and not staging.actors[key].final_approved)
	assert(FileAccess.get_sha256(recipe.source_provenance) == recipe.source_provenance_sha256)
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(recipe.source_provenance))
	assert(provenance.reference.path == staging.actors[key].reference, "Exact target art only")
	assert(provenance.reference.sha256 == staging.actors[key].reference_sha256, "Exact target reference SHA")
	var row: Dictionary = {}
	for record: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
		if str(record.sourceId) == sid: row = record
	assert(not row.is_empty() and row.grade == "영웅")
	var profile: Resource = CATALOG.for_record("transform", row, row.image_path)
	var source: SpriteFrames = load(recipe.source)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for metadata: StringName in source.get_meta_list(): frames.set_meta(metadata, source.get_meta(metadata))
	for role: String in recipe.inherited_roles:
		for direction: int in range(8):
			var track := role + "_" + str(direction)
			assert(source.has_animation(track) and source.get_frame_count(track) >= 2)
			frames.add_animation(track)
			frames.set_animation_loop(track, source.get_animation_loop(track))
			frames.set_animation_speed(track, source.get_animation_speed(track))
			for phase: int in range(source.get_frame_count(track)):
				frames.add_frame(track, source.get_frame_texture(track, phase), source.get_frame_duration(track, phase))
	var raw_path := out + "raw/source-run.png"
	var raw := _read(raw_path)
	assert(raw.get_width() % 6 == 0 and raw.get_height() % 8 == 0)
	var raw_cell: int = raw.get_width() / 6
	assert(raw_cell == raw.get_height() / 8, "Square cells, no width stretching")
	var projected_heights: Array = []
	for direction: int in range(8):
		var pose: AtlasTexture = source.get_frame_texture("idle_" + str(direction), 0)
		projected_heights.append(pose.region.size.y * 256.0 / float(pose.get_height()))
	var target_height := _median(projected_heights)
	var basis := raw.get_region(Rect2i(raw_cell, raw_cell * 2, raw_cell, raw_cell))
	var cell: int = int(round(raw_cell * target_height / float(_bounds(basis).size.y)))
	assert(cell >= 48 and cell <= 230)
	var normalized := Image.create(cell * 6, cell * 8, false, Image.FORMAT_RGBA8)
	for direction: int in range(8):
		for phase: int in range(6):
			var part := raw.get_region(Rect2i(phase * raw_cell, direction * raw_cell, raw_cell, raw_cell))
			part.generate_mipmaps()
			part.resize(cell, cell, Image.INTERPOLATE_TRILINEAR)
			part.clear_mipmaps()
			normalized.blit_rect(part, Rect2i(0, 0, cell, cell), Vector2i(phase * cell, direction * cell))
	var normalized_path := out + "normalized-source-run.png"
	if verify: assert(_read(normalized_path).get_data() == normalized.get_data())
	else: assert(normalized.save_png(normalized_path) == OK)
	var texture := ImageTexture.create_from_image(normalized)
	texture.take_over_path(normalized_path)
	var atlas := Image.create(1536, 2048, false, Image.FORMAT_RGBA8)
	var proofs: Array = []
	var anchors: Array = []
	var foot: Array = provenance.foot
	var pad_x: int = int(round(128.0 - cell * .5))
	var ground: float = float(foot[1])
	for direction: int in range(8):
		var contacts: Array = []
		for phase: int in [0, 1, 3, 4]:
			contacts.append(_bounds(normalized.get_region(Rect2i(phase * cell, direction * cell, cell, cell))).end.y)
		var candidate_ground := _median(contacts)
		anchors.append(candidate_ground)
		var pad_y: int = int(round(ground - candidate_ground))
		assert(pad_y >= 0 and pad_y + cell <= 256)
		var track := "run_" + str(direction)
		frames.add_animation(track)
		frames.set_animation_loop(track, true)
		frames.set_animation_speed(track, 18.0)
		var seen: Dictionary = {}
		for phase: int in range(6):
			var region := Rect2i(phase * cell, direction * cell, cell, cell)
			var canvas := Image.create(256, 256, false, Image.FORMAT_RGBA8)
			canvas.blit_rect(normalized, region, Vector2i(pad_x, pad_y))
			var hash := _sha(canvas)
			assert(not seen.has(hash), "No repeated run frames")
			seen[hash] = true
			var box := _bounds(canvas)
			assert(box.position.x > 0 and box.position.y > 0 and box.end.x < 256 and box.end.y < 256)
			atlas.blit_rect(canvas, Rect2i(0, 0, 256, 256), Vector2i(phase * 256, direction * 256))
			var view := AtlasTexture.new()
			view.atlas = texture
			view.region = region
			view.margin = Rect2(pad_x, pad_y, 256 - cell, 256 - cell)
			view.filter_clip = true
			frames.add_frame(track, view)
			proofs.append({"direction": direction, "phase": phase, "rgba_sha256": hash, "source_reference": {"atlas": normalized_path, "region": [region.position.x, region.position.y, cell, cell], "margin_position": [pad_x, pad_y]}, "root_down": 0, "source_partition": {"hip_y": 256, "review": "EXACT_NEW_RUN_CELL_NOT_BONE_PROOF"}})
	if verify:
		assert(_read(out + "run.png").get_data() == atlas.get_data())
		print("HERO_EXACT_REUSE_REPRO_PASS id=" + sid + " run_poses=48 writes=0")
		quit(0)
		return
	assert(atlas.save_png(out + "run.png") == OK)
	frames.set_meta("twilight_native_locomotion_staging", true)
	frames.set_meta("hero_parallel_candidate", true)
	frames.set_meta("final_approved", false)
	assert(ResourceSaver.save(frames, out + "SpriteFrames.tres") == OK)
	profile.frames_path = out + "SpriteFrames.tres"
	profile.movement_fps = 18.0
	profile.color_tint = Color.WHITE # Exact fire artwork must not inherit the old proxy tint.
	profile.floating = false
	profile.sprite_offset = (Vector2(128, 128) - Vector2(foot[0], foot[1])) * profile.pixel_scale
	profile.set_meta("hero_parallel_candidate", true)
	profile.set_meta("final_approved", false)
	assert(ResourceSaver.save(profile, out + "NativeMotionProfile.tres") == OK)
	var proof := {"schema": "hero-unique-run-with-preserved-actions-v1", "engine": Engine.get_version_info().string, "source": recipe.source, "source_sha256": FileAccess.get_sha256(recipe.source), "source_hashes": {raw_path: FileAccess.get_sha256(raw_path), normalized_path: FileAccess.get_sha256(normalized_path), recipe.source_provenance: FileAccess.get_sha256(recipe.source_provenance)}, "frames": proofs, "unique_authored_poses": 48, "method": "new 48 RUN art, fixed uniform scale and per-view projected-root registration, all four existing exact-target actions retained byte-for-byte", "transform_lineage": {"raw_cell": raw_cell, "normalized_cell": cell, "uniform_scale": float(cell) / raw_cell}, "ground_registration": {"canvas_ground": ground, "source_ground_candidates": anchors, "actual_contact_approved": false}, "visual_overrides": recipe.visual_overrides, "new_death_source_directions": 0, "existing_death_directions": 8, "final_approved": false}
	_json(out + "rig-proof.json", proof)
	staging.actors[key].merge({"status": "EXACT_REUSE_NEW_RUN_QUALITY_HOLD", "frames": out + "SpriteFrames.tres", "native_profile": out + "NativeMotionProfile.tres", "rig": out + "rig-proof.json", "source_donor": recipe.source, "source_frames_sha256": proof.source_sha256, "new_run_poses": 48, "new_unique_authored_poses": 48, "new_death_authored_directions": [], "new_death_unique_poses": 0, "death_policy_scope": "EXISTING_EIGHT_DIRECTION_DEATH_PRESERVE", "death_reuse_assessment": "Exact same target catalog reference verified by provenance; existing eight-direction death copied unchanged.", "independent_validation": "NOT_RUN", "quality_holds": ["NEW_RUN_ORIGINAL_IDENTITY_AND_CROSS_ACTION_CONTINUITY", "ACTUAL_ANATOMICAL_SUPPORT_AND_CADENCE", "NEW_EIGHT_DIRECTION_CAMERAS"], "production_connected": false, "final_approved": false}, true)
	_json("res://data/pr122_hero_parallel_staging.json", staging)
	print("HERO_EXACT_REUSE_BUILD_PASS id=" + sid + " new_run=48 preserved_death_directions=8 new_death=0 approvals=0")
	quit(0)
