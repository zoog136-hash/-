extends "res://docs/remake/pr122-hero-parallel/build_full_art_candidate.gd"
## Reuse the verified hero SpriteFrames/proof registrar; complete source poses
## replace the false assumption that generated art always obeys equal cells.
func _initialize() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	target_id = OS.get_environment("TWILIGHT_HERO_FULL_ART_ID")
	var group := "death_155" if target_id == "155" else "hero_generated_"+target_id
	OUT = "res://assets/actors/eight_direction/hero_parallel/"+group+"/r001/"
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"source-layout.json"))
	var stage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	assert(stage.actors.has("transform:"+target_id) and not stage.actors["transform:"+target_id].final_approved)
	assert(not FileAccess.file_exists(OUT+"SpriteFrames.tres"),"Preserve previous outputs")
	var row: Dictionary = {}
	for record: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
		if str(record.sourceId) == target_id: row = record
	assert(not row.is_empty() and row.grade == "영웅")
	var profile: Resource = CATALOG.for_record("transform",row,row.image_path)
	var donor: String = profile.frames_path
	cell_size = int(layout.cell)
	pad_x = int(layout.pad)
	canvas_ground = float(layout.ground)+pad_x
	for name: String in ["run","attack","support","death"]:
		var source: Dictionary = layout.sources[name]
		assert(FileAccess.get_sha256(source.raw) == source.raw_sha256 and FileAccess.get_sha256(source.ownership) == source.ownership_sha256)
		var raw := _read(source.raw)
		var owner := _read(source.ownership)
		var rows := 3 if name == "death" else 8
		var columns := 2 if name == "death" else 6
		var sheet := Image.create(columns*cell_size,rows*cell_size,false,Image.FORMAT_RGBA8)
		var scale: float = layout.uniform_scale*source.unit_scale
		for pose: Dictionary in source.poses:
			var r: Array = pose.rect
			var region := Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
			var painted := Image.create(region.size.x,region.size.y,false,Image.FORMAT_RGBA8)
			for y: int in range(region.size.y):
				for x: int in range(region.size.x):
					var p := region.position+Vector2i(x,y)
					if int(round(owner.get_pixelv(p).r*255.0)) == int(pose.owner):
						var color := raw.get_pixelv(p)
						if layout.has("palette_variant") and color.a > 0.0:
							var palette: Dictionary = layout.palette_variant
							if (color.h <= palette.red_hue_tolerance or color.h >= 1.0-palette.red_hue_tolerance) and color.s >= palette.minimum_saturation:
								color = Color.from_hsv(fposmod(color.h+float(palette.hue_shift),1.0),color.s,color.v,color.a)
						painted.set_pixel(x,y,color)
			painted.generate_mipmaps()
			painted.resize(maxi(1,int(round(region.size.x*scale))),maxi(1,int(round(region.size.y*scale))),Image.INTERPOLATE_TRILINEAR)
			painted.clear_mipmaps()
			var offset := Vector2i(int(round(112.0+(region.position.x-float(pose.root_x))*scale)),int(round(float(layout.ground)+(region.position.y-float(pose.root_y))*scale)))
			if pose.get("mirrored_x",false):
				painted.flip_x()
				offset.x = cell_size-offset.x-painted.get_width()
			assert(offset.x >= 0 and offset.y >= 0 and offset.x+painted.get_width() < cell_size and offset.y+painted.get_height() < cell_size,"No clipped pose material")
			var column := int(pose.phase)%2 if name == "death" else int(pose.phase)
			var heading := int(pose.phase)/2 if name == "death" else int(pose.direction)
			sheet.blit_rect(painted,Rect2i(Vector2i.ZERO,painted.get_size()),Vector2i(column*cell_size,heading*cell_size)+offset)
		normalized[name] = sheet
		var path := OUT+"normalized-source-"+name+".png"
		assert(sheet.save_png(path) == OK)
		source_hashes[source.raw] = source.raw_sha256
		source_hashes[source.ownership] = source.ownership_sha256
		source_hashes[path] = FileAccess.get_sha256(path)
		var texture := ImageTexture.create_from_image(sheet)
		texture.take_over_path(path)
		textures[name] = texture
		anchors[name] = [layout.ground,layout.ground,layout.ground,layout.ground,layout.ground,layout.ground,layout.ground,layout.ground]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	run_atlas = Image.create(1536,2048,false,Image.FORMAT_RGBA8)
	for direction: int in range(8):
		_register(frames,"idle",direction,"support",0,3)
		_register(frames,"run",direction,"run",0,int(layout.sources.run.counts[direction]))
		_register(frames,"attack",direction,"attack",0,int(layout.sources.attack.counts[direction]))
		_register(frames,"hit",direction,"support",3,3)
	var south := SpriteFrames.new()
	south.remove_animation("default")
	_register(south,"death",2,"death",0,6)
	south.set_animation_speed("death_2",6.0/profile.death_duration)
	var death := DEATH_POLICY.install_new_south_death(frames,south,OUT+"DeathSouth.tres")
	for direction: int in range(8): track_sources["death_"+str(direction)] = track_sources.death_2
	frames.set_meta("twilight_native_locomotion_staging",true)
	frames.set_meta("hero_parallel_candidate",true)
	frames.set_meta("final_approved",false)
	assert(run_atlas.save_png(OUT+"run.png") == OK)
	assert(ResourceSaver.save(south,OUT+"DeathSouth.tres") == OK)
	assert(ResourceSaver.save(frames,OUT+"SpriteFrames.tres") == OK)
	profile.frames_path = OUT+"SpriteFrames.tres"
	profile.color_tint = Color.WHITE
	profile.movement_fps = 18.0
	profile.set_meta("hero_parallel_candidate",true)
	profile.set_meta("final_approved",false)
	assert(ResourceSaver.save(profile,OUT+"NativeMotionProfile.tres") == OK)
	source_hashes[OUT+"source-layout.json"] = FileAccess.get_sha256(OUT+"source-layout.json")
	var proof := {"schema":"hero-unique-full-atlas-v1","engine":Engine.get_version_info().string,"source":str(layout.sources.run.raw),"source_sha256":str(layout.sources.run.raw_sha256),"source_hashes":source_hashes,"preserved_donor_frames":donor,"frames":run_proofs,"track_sources":track_sources,"method":"Complete generated pose ownership, uniform scale, fixed row ground for RUN; no missing phases manufactured; reuse verified hero registrar","source_layout":OUT+"source-layout.json","death_policy":death,"visual_overrides":{"color_tint":"ffffff","floating":profile.floating},"source_paintings_generated":4,"source_paintings_reused":0,"final_approved":false}
	# A palette variant references the original immutable paintings directly.
	proof.source = layout.sources.run.raw
	proof.source_sha256 = layout.sources.run.raw_sha256
	if layout.has("palette_variant"):
		proof.palette_variant = layout.palette_variant
		proof.source_paintings_generated = 0
		proof.source_paintings_reused = 4
	proof.source_warnings = layout.get("source_warnings",[])
	proof.production_draft = layout.get("production_draft",false)
	_json(OUT+"rig-proof.json",proof)
	var entry: Dictionary = stage.actors["transform:"+target_id]
	if entry.has("frames") or entry.has("quality_holds"):
		var previous: Array = entry.get("prior_candidates",[])
		previous.append({"frames":entry.get("frames",""),"native_profile":entry.get("native_profile",""),"status":entry.status,"quality_holds":entry.get("quality_holds",[])})
		entry.prior_candidates = previous
	entry.merge({"frames":OUT+"SpriteFrames.tres","native_profile":OUT+"NativeMotionProfile.tres","rig":OUT+"rig-proof.json","source_donor":"NEW_HERO_IDENTITY_ART_FROM_BUILTIN_TOOL","source_frames_sha256":proof.source_sha256,"status":"UNIQUE_ART_FULL_CANDIDATE_QUALITY_HOLD","independent_validation":"NOT_RUN","new_run_poses":48,"new_death_authored_directions":["S"],"new_death_unique_poses":6,"quality_holds":["DIRECT_IDENTITY_AND_MAIN_MOTION_REVIEW"],"production_connected":false,"final_approved":false},true)
	entry.erase("main_validation_report")
	entry.new_run_poses = layout.sources.run.poses.size()
	entry.source_warnings = layout.get("source_warnings",[])
	if layout.get("production_draft",false):
		entry.status = "PRODUCED_AWAITING_FINAL_REVIEW"
		entry.quality_holds = ["DIRECT_IDENTITY_AND_MAIN_MOTION_REVIEW","SOURCE_WARNINGS_REQUIRE_REVIEW"]
	if layout.has("palette_variant"):
		entry.source_donor = "SAME_APPEARANCE_PALETTE_REUSE_179"
	_json("res://data/pr122_hero_parallel_staging.json",stage)
	print("HERO_DETECTED_SOURCE_PACK_PASS id="+target_id+" run_poses=48 attack_poses="+str(layout.sources.attack.poses.size())+" new_death_directions=1 approvals=0")
	quit()
