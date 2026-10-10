extends SceneTree

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
var failures: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		print("ANIMATION CATALOG FAIL: " + text)

func _run() -> void:
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/directional_art_v19.json"))
	var actor: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	actor.position = Vector2(135, 237)
	actor.auto_enabled = true
	var directional_count: int = 0
	for item: Dictionary in db["변신"]:
		var id: String = "transform:" + str(item.sourceId)
		var resource: String = str(art.get(id, {}).get("path", item.image_path))
		var profile: TwilightAnimationProfile = CATALOG.for_record("transform", item, resource)
		actor.start_combat_attack(Vector2(250, 200), 0.72, "slash")
		var sequence: int = actor.motion.sequence
		actor.set_transform_visual(resource, 1.0, profile)
		check(actor.transform_active, "missing transform " + id)
		check(actor.position == Vector2(135, 237) and actor.auto_enabled, "switch altered position/AUTO " + id)
		check(actor.motion.sequence == sequence and actor.motion.active, "switch cancelled combat " + id)
		check(not actor.class_sprite.visible, "old class still visible " + id)
		var frames: SpriteFrames = actor.transform_sprite.sprite_frames
		var generated: Dictionary = preload("res://scripts/animation/visual_manifest.gd").record(id)
		if art.has(id):
			directional_count += 1
			if generated.is_empty():
				check(frames.get_animation_names().size() == 4, "directional layout " + id)
			else:
				for suffix: String in ["_down", "_up", "_left", "_right"]:
					for role: String in ["idle", "walk", "run", "attack", "hit", "death"]:
						check(frames.has_animation(role + suffix) and frames.get_frame_count(role + suffix) >= 2, "authored directional action " + id + role + suffix)
		else:
			if generated.is_empty():
				check(frames.has_animation("still") and frames.get_frame_count("still") == 1, "single-image fallback cut into tiles " + id)
			else:
				for role: String in ["idle", "walk", "run", "attack", "hit", "death"]:
					check(frames.has_animation(role) and frames.get_frame_count(role) >= 2, "authored single-view action " + id + role)
	check(directional_count == 78, "directional coverage changed")
	check(CATALOG.frame_cache.size() <= CATALOG.MAX_FRAME_CACHE, "unbounded frame cache")
	actor.clear_transform_visual()
	check(actor.class_sprite.visible and not actor.transform_sprite.visible, "clear leaves transform residue")
	actor.queue_free()
	await process_frame
	if failures == 0: print("ANIMATION_CATALOG_OK transforms=413 directional=78 shared_attack=413")
	quit(0 if failures == 0 else 1)
