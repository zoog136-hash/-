extends SceneTree
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
func _initialize() -> void:
	var scope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var output: Dictionary = {}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]:
		var key := "transform:"+str(row.sourceId)
		if not scope.actors.has(key) or scope.actors[key].final_approved: continue
		var p: Resource = CATALOG.for_record("transform",row,row.image_path)
		var frames: SpriteFrames = load(p.frames_path)
		var idle: AtlasTexture = frames.get_frame_texture("idle_2",0)
		var canvas: Vector2 = frames.get_meta("twilight_canvas_size",Vector2(256,256))
		output[str(row.sourceId)] = {"reference":row.image_path,"frames":p.frames_path,"height":idle.region.size.y*canvas.y/idle.get_height(),"ground":128.0-p.sprite_offset.y/p.pixel_scale,"attack_hit_frame":p.attack_hit_frame,"pixel_scale":p.pixel_scale,"sprite_offset":[p.sprite_offset.x,p.sprite_offset.y]}
	var f := FileAccess.open("res://docs/remake/pr122-hero-parallel/evidence/generation-recovered-20261023/baseline-profiles.json",FileAccess.WRITE)
	assert(f != null)
	f.store_string(JSON.stringify(output,"  ")+"\n")
	print("HERO_GENERATED_BASELINE_READ_ONLY_PASS actors="+str(output.size()))
	quit()
