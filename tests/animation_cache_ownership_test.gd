extends SceneTree

const CATALOG=preload("res://scripts/animation/animation_catalog.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String]=[]
	var path: String="res://assets/actors/eight_direction/monster_boss_repair/test/SpriteFrames.tres"
	var key: String=path+":native8"
	var frames:=SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle",ImageTexture.create_from_image(Image.create(4,4,false,Image.FORMAT_RGBA8)))
	CATALOG._cache_frames(key,frames)
	if CATALOG.frame_cache_bytes!=64:failures.append("unique texture estimate")
	CATALOG.release_region_frames()
	if CATALOG.frame_cache.has(key) or CATALOG.frame_cache_bytes!=0:failures.append("region lookup retained")
	var reused: SpriteFrames=CATALOG.frames(path,"native8")
	if not is_same(reused,frames):failures.append("live actor frame source duplicated")
	print("ANIMATION_CACHE_OWNERSHIP_RESULT ",JSON.stringify({"failures":failures,"same_source":is_same(reused,frames),"lookup_bytes":CATALOG.frame_cache_bytes}))
	quit(0 if failures.is_empty() else 1)
