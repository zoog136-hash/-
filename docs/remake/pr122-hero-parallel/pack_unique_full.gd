extends SceneTree
## Register three immutable new-art sheets; quality/identity remain unapproved.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const RAW := "res://assets/actors/eight_direction/hero_parallel/baphomet_unique/r001/"
const OUT := "res://assets/actors/eight_direction/hero_parallel/baphomet_unique/r002/"

func _json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data, "  ") + "\n")

func _initialize() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	assert(not FileAccess.file_exists(OUT + "SpriteFrames.tres"))
	DirAccess.make_dir_recursive_absolute(OUT)
	var sources: Dictionary = {}
	var textures: Dictionary = {}
	var source_hashes: Dictionary = {}
	for name: String in ["run", "support", "attack"]:
		var path := RAW + "source-" + name + ".png"
		var image := Image.new()
		assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
		assert(image.get_size() == Vector2i(1086, 1448), "six by eight exact 181px source grid required")
		sources[name] = image
		var texture := ImageTexture.create_from_image(image)
		texture.take_over_path(path)
		textures[name] = texture
		source_hashes[path] = FileAccess.get_sha256(path)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var run_atlas := Image.create(1536, 2048, false, Image.FORMAT_RGBA8)
	var run_proofs: Array = []
	var track_sources: Dictionary = {}
	for direction: int in range(8):
		for role: String in ["idle", "run", "attack", "hit", "death"]:
			var source_name := "run" if role == "run" else ("attack" if role == "attack" else "support")
			var count := 6 if role in ["run", "attack"] else 2
			var start := 2 if role == "hit" else (4 if role == "death" else 0)
			var track := role + "_" + str(direction)
			frames.add_animation(track)
			frames.set_animation_loop(track, role in ["idle", "run"])
			frames.set_animation_speed(track, 18.0 if role == "run" else (4.0 if role == "idle" else 10.0))
			track_sources[track] = []
			for phase: int in range(count):
				var region := Rect2i((start + phase) * 181, direction * 181, 181, 181)
				var source_image: Image = sources[source_name]
				var original := source_image.get_region(region)
				var canvas := Image.create(256, 256, false, Image.FORMAT_RGBA8)
				canvas.blit_rect(original, Rect2i(0, 0, 181, 181), Vector2i(37, 37))
				var digest := HashingContext.new()
				digest.start(HashingContext.HASH_SHA256)
				digest.update(canvas.get_data())
				var sha := digest.finish().hex_encode()
				var reference := {"atlas": RAW + "source-" + source_name + ".png", "region": [region.position.x, region.position.y, 181, 181], "margin_position": [37, 37]}
				track_sources[track].append({"source_reference": reference, "canvas_rgba_sha256": sha})
				var view := AtlasTexture.new()
				view.atlas = textures[source_name]
				view.region = Rect2(region)
				view.margin = Rect2(37, 37, 75, 75)
				view.filter_clip = true
				frames.add_frame(track, view)
				if role == "run":
					run_atlas.blit_rect(canvas, Rect2i(0, 0, 256, 256), Vector2i(phase * 256, direction * 256))
					run_proofs.append({"direction": direction, "phase": phase, "rgba_sha256": sha, "source_reference": reference, "root_down": 0, "source_partition": {"hip_y": 256, "review": "FULL_EXACT_GENERATED_CELL_NO_BIND_FIT"}})
	assert(run_atlas.save_png(OUT + "run.png") == OK)
	frames.set_meta("twilight_native_locomotion_staging", true)
	frames.set_meta("hero_parallel_candidate", true)
	frames.set_meta("final_approved", false)
	assert(ResourceSaver.save(frames, OUT + "SpriteFrames.tres") == OK)
	var proof := {"schema": "hero-unique-full-atlas-v1", "engine": Engine.get_version_info().string, "source": RAW + "source-run.png", "source_sha256": FileAccess.get_sha256(RAW + "source-run.png"), "source_hashes": source_hashes, "method": "exact generated source cell registration, padding only; no scaling/repainting", "scope": "FULL_ACTION_TECHNICAL_CANDIDATE_NOT_QUALITY_APPROVAL", "frames": run_proofs, "track_sources": track_sources, "final_approved": false}
	_json(OUT + "rig-proof.json", proof)
	var row: Dictionary = {}
	for item: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
		if str(item.sourceId) == "7": row = item
	assert(not row.is_empty() and row.grade == "영웅")
	var profile: Resource = CATALOG.for_record("transform", row, row.image_path)
	profile.frames_path = OUT + "SpriteFrames.tres"
	profile.movement_fps = 18.0
	profile.set_meta("hero_parallel_candidate", true)
	profile.set_meta("final_approved", false)
	assert(ResourceSaver.save(profile, OUT + "NativeMotionProfile.tres") == OK)
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var entry: Dictionary = staging.actors["transform:7"]
	entry["prior_candidates"] = [{"frames": entry.frames, "native_profile": entry.native_profile, "status": "ROBE_MATERIAL_CONNECTIONS_QUALITY_HOLD"}]
	entry.merge({"frames": OUT + "SpriteFrames.tres", "native_profile": OUT + "NativeMotionProfile.tres", "rig": OUT + "rig-proof.json", "source_donor": "new generated Baphomet action art; reference identity not approved", "source_frames_sha256": str(proof.source_sha256), "status": "UNIQUE_ART_FULL_CANDIDATE_QUALITY_HOLD", "independent_validation": "NOT_RUN", "quality_holds": ["ORIGINAL_CHARACTER_IDENTITY", "CROSS_SHEET_DESIGN_CONTINUITY", "ACTUAL_SHOE_CONTACT_AND_CADENCE_NOT_APPROVED", "CAMERA_AND_THREE_RUN_SOURCE_CELL_EDGES"], "final_approved": false, "production_connected": false}, true)
	entry.erase("main_validation_report")
	_json("res://data/pr122_hero_parallel_staging.json", staging)
	print("HERO_UNIQUE_FULL_PACK_PASS roles=5 directions=8 phases=144 source_pixels_unchanged=true approvals=0")
	quit(0)
