extends SceneTree
## Read all 109 selected hero resources once. Never save or replace a resource.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
func _initialize() -> void:
	var stage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var selected: Dictionary = stage.actors.duplicate()
	selected.merge(stage.remediation_18.actors)
	var rows: Array = []
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
		if row.grade != "영웅":continue
		var key := "transform:"+str(row.sourceId)
		var baseline: Resource = CATALOG.for_record("transform",row,row.image_path)
		var entry: Dictionary = selected.get(key,{})
		var profile: Resource = load(entry.native_profile) if not entry.is_empty() else baseline
		var frames: SpriteFrames = load(profile.frames_path)
		var item := {"id":key,"name":row.name,"candidate":not entry.is_empty(),"profile_path":entry.get("native_profile",""),"frames_path":profile.frames_path,"baseline_frames":baseline.frames_path,"reference":row.image_path,"tracks":{},"canvas":[],"profile":{},"baseline_profile":{}}
		for field: String in ["attack_hit_frame","attack_hit_ratio","attack_animation_speed","death_duration","pixel_scale","native_width_ratio","reference_speed","movement_fps","floating"]:
			item.profile[field]=profile.get(field)
			item.baseline_profile[field]=baseline.get(field)
		var canvas: Vector2 = frames.get_meta("twilight_canvas_size",Vector2(256,256))
		item.canvas=[canvas.x,canvas.y]
		for name: StringName in frames.get_animation_names():
			var track := {"loop":frames.get_animation_loop(name),"speed":frames.get_animation_speed(name),"frames":[]}
			for phase: int in range(frames.get_frame_count(name)):
				var texture := frames.get_frame_texture(name,phase)
				var data := {"duration":frames.get_frame_duration(name,phase),"width":texture.get_width(),"height":texture.get_height()}
				if texture is AtlasTexture:
					var atlas := texture as AtlasTexture
					data.path=atlas.atlas.resource_path
					data.region=[atlas.region.position.x,atlas.region.position.y,atlas.region.size.x,atlas.region.size.y]
					data.margin=[atlas.margin.position.x,atlas.margin.position.y,atlas.margin.size.x,atlas.margin.size.y]
				else:
					data.path=texture.resource_path
					data.region=[0,0,texture.get_width(),texture.get_height()]
					data.margin=[0,0,0,0]
				track.frames.append(data)
			item.tracks[str(name)]=track
		rows.append(item)
	var out := "res://docs/remake/pr122-hero-parallel/evidence/audit-once-20261023/"
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out+"resource-snapshot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"heroes":rows})+"\n")
	print("HERO_AUDIT_READONLY_SNAPSHOT actors="+str(rows.size())+" resource_writes=0")
	quit()
