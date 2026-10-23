extends SceneTree
## Production settings only: read existing exact-target profiles, never rewrite them.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
func _initialize() -> void:
	var stage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var result: Dictionary = {}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
		var sid := str(row.sourceId)
		if not stage.remediation_18.actors.has("transform:"+sid): continue
		var profile: Resource = CATALOG.for_record("transform",row,row.image_path)
		var source: SpriteFrames = load(profile.frames_path)
		assert(profile.frames_path == stage.remediation_18.actors["transform:"+sid].original_frames)
		var idle: AtlasTexture = source.get_frame_texture("idle_2",0)
		var canvas: Vector2 = source.get_meta("twilight_canvas_size",Vector2(256,256))
		var tracks: Dictionary = {}
		for name: StringName in source.get_animation_names(): tracks[str(name)] = source.get_frame_count(name)
		result[sid] = {"reference":row.image_path,"frames":profile.frames_path,"height":idle.region.size.y*canvas.y/idle.get_height(),"ground":128.0-profile.sprite_offset.y/profile.pixel_scale,"pixel_scale":profile.pixel_scale,"sprite_offset":[profile.sprite_offset.x,profile.sprite_offset.y],"color_tint":profile.color_tint.to_html(),"floating":profile.floating,"attack_hit_frame":profile.attack_hit_frame,"tracks":tracks}
	var file := FileAccess.open("res://docs/remake/pr122-hero-parallel/evidence/remediation18-20261023/baseline-profiles.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  ")+"\n")
	print("HERO_REPAIR_PRODUCTION_SETTINGS_READY actors="+str(result.size()))
	quit()
