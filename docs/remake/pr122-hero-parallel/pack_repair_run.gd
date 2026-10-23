extends "res://docs/remake/pr122-hero-parallel/build_full_art_candidate.gd"
## Reuse the proven atlas registrar. Only RUN is replaced in the candidate;
## every existing non-WALK action and all eight death headings stay exact.
func _initialize() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	target_id = OS.get_environment("TWILIGHT_HERO_REPAIR_ID")
	OUT = "res://assets/actors/eight_direction/hero_parallel/hero_repair_"+target_id+"/r001/"
	assert(not FileAccess.file_exists(OUT+"SpriteFrames.tres"),"Preserve prior output")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"source-layout.json"))
	var stage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var entry: Dictionary = stage.remediation_18.actors["transform:"+target_id]
	assert(not entry.final_approved)
	var row: Dictionary = {}
	for record: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
		if str(record.sourceId)==target_id:row=record
	assert(not row.is_empty() and row.grade=="영웅")
	var profile: Resource = CATALOG.for_record("transform",row,row.image_path)
	var donor: String = profile.frames_path
	assert(donor==entry.original_frames)
	var source_frames: SpriteFrames = load(donor)
	var source: Dictionary = layout.sources.run
	assert(FileAccess.get_sha256(source.raw)==source.raw_sha256 and FileAccess.get_sha256(source.ownership)==source.ownership_sha256)
	var raw := _read(source.raw)
	var owner := _read(source.ownership)
	cell_size=int(layout.cell)
	pad_x=int(layout.pad)
	canvas_ground=float(layout.ground)+pad_x
	var sheet := Image.create(6*cell_size,8*cell_size,false,Image.FORMAT_RGBA8)
	for pose: Dictionary in source.poses:
		var r: Array = pose.rect
		var region := Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
		var painted := Image.create(region.size.x,region.size.y,false,Image.FORMAT_RGBA8)
		for y: int in range(region.size.y):
			for x: int in range(region.size.x):
				var p := region.position+Vector2i(x,y)
				if int(round(owner.get_pixelv(p).r*255))!=int(pose.owner):continue
				var color := raw.get_pixelv(p)
				if layout.has("palette_variant") and color.a>0:
					var palette: Dictionary = layout.palette_variant
					if color.h>=palette.hue_low and color.h<=palette.hue_high and color.s>=palette.minimum_saturation:
						color=Color.from_hsv(fposmod(color.h+float(palette.hue_shift),1.0),color.s,color.v,color.a)
				painted.set_pixel(x,y,color)
		painted.generate_mipmaps()
		painted.resize(maxi(1,int(round(region.size.x*float(layout.uniform_scale)))),maxi(1,int(round(region.size.y*float(layout.uniform_scale)))),Image.INTERPOLATE_TRILINEAR)
		painted.clear_mipmaps()
		var offset := Vector2i(int(round(112+(region.position.x-float(pose.root_x))*float(layout.uniform_scale))),int(round(float(layout.ground)+(region.position.y-float(pose.root_y))*float(layout.uniform_scale))))
		if pose.get("mirrored_x",false):
			painted.flip_x()
			offset.x=cell_size-offset.x-painted.get_width()
		assert(offset.x>=0 and offset.y>=0 and offset.x+painted.get_width()<cell_size and offset.y+painted.get_height()<cell_size)
		sheet.blit_rect(painted,Rect2i(Vector2i.ZERO,painted.get_size()),Vector2i(int(pose.phase)*cell_size,int(pose.direction)*cell_size)+offset)
	var normalized_path := OUT+"normalized-source-run.png"
	assert(sheet.save_png(normalized_path)==OK)
	normalized.run=sheet
	var texture := ImageTexture.create_from_image(sheet)
	texture.take_over_path(normalized_path)
	textures.run=texture
	anchors.run=[layout.ground,layout.ground,layout.ground,layout.ground,layout.ground,layout.ground,layout.ground,layout.ground]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for key: StringName in source_frames.get_meta_list():frames.set_meta(key,source_frames.get_meta(key))
	var inherited: Array = []
	var extra: Array = []
	for name: StringName in source_frames.get_animation_names():
		if str(name).begins_with("walk_") or str(name).begins_with("run_"):continue
		frames.add_animation(name)
		frames.set_animation_loop(name,source_frames.get_animation_loop(name))
		frames.set_animation_speed(name,source_frames.get_animation_speed(name))
		for phase: int in range(source_frames.get_frame_count(name)):
			frames.add_frame(name,source_frames.get_frame_texture(name,phase),source_frames.get_frame_duration(name,phase))
		inherited.append(str(name))
		if str(name).get_slice("_",0) not in ["idle","attack","hit","death"]:extra.append(str(name))
	run_atlas=Image.create(1536,2048,false,Image.FORMAT_RGBA8)
	for direction: int in range(8):_register(frames,"run",direction,"run",0,6)
	assert(run_atlas.save_png(OUT+"run.png")==OK)
	frames.set_meta("hero_parallel_candidate",true)
	frames.set_meta("final_approved",false)
	assert(ResourceSaver.save(frames,OUT+"SpriteFrames.tres")==OK)
	profile.frames_path=OUT+"SpriteFrames.tres"
	profile.movement_fps=18.0
	profile.set_meta("hero_parallel_candidate",true)
	profile.set_meta("final_approved",false)
	assert(ResourceSaver.save(profile,OUT+"NativeMotionProfile.tres")==OK)
	var hashes := {source.raw:source.raw_sha256,source.ownership:source.ownership_sha256,normalized_path:FileAccess.get_sha256(normalized_path),OUT+"source-layout.json":FileAccess.get_sha256(OUT+"source-layout.json"),donor:FileAccess.get_sha256(donor)}
	var proof := {"schema":"hero-unique-run-with-preserved-actions-v1","engine":Engine.get_version_info().string,"source":donor,"source_sha256":FileAccess.get_sha256(donor),"source_hashes":hashes,"source_layout":OUT+"source-layout.json","frames":run_proofs,"track_sources":track_sources,"preserved_tracks":inherited,"preserved_extra_tracks":extra,"method":"Existing complete-pose ownership and uniform per-actor scale; original non-WALK actions and profile fields retained; new real six-phase RUN only","new_death_source_directions":0,"existing_death_directions":8,"new_source_paintings":0 if layout.has("palette_variant") else 1,"palette_variant":layout.get("palette_variant",{}),"final_approved":false}
	_json(OUT+"rig-proof.json",proof)
	entry.merge({"frames":OUT+"SpriteFrames.tres","native_profile":OUT+"NativeMotionProfile.tres","rig":OUT+"rig-proof.json","status":"RUN_REPAIR_PRODUCED_AWAITING_FINAL_REVIEW","independent_validation":"NOT_RUN","new_run_poses":48,"new_death_authored_directions":[],"new_death_unique_poses":0,"quality_holds":["ACTUAL_MAIN_AND_SOURCE_VISUAL_REVIEW"],"final_approved":false,"production_connected":false},true)
	_json("res://data/pr122_hero_parallel_staging.json",stage)
	print("HERO_RUN_REPAIR_PRODUCED id="+target_id+" run_poses=48 preserved_tracks="+str(inherited.size())+" new_death=0 approvals=0")
	quit()
