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
	var native_count: int = 0
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
		if art.has(id): directional_count+=1
		if profile.layout == "directional8" and not profile.frames_path.is_empty():
			native_count+=1
			for direction: int in range(8):
				for role: String in ["idle", "walk", "attack", "hit", "death"]:
					var key := role + "_" + str(direction)
					check(frames.has_animation(key) and frames.get_frame_count(key) >= 2, "native eight-view action " + id + key)
			continue
		if art.has(id):
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
	# PR122 exact-name reuse: share the COMPLETE existing source atlas without
	# merging distinct catalog/monster identities or altering battle contracts.
	var shared_six: Dictionary = {
		"transform:7":"monster:바포메트",
		"transform:11":"monster:베레스",
		"transform:352":"monster:알비노 뿔 개구리",
		"monster:알비노 피쉬맨":"transform:350",
		"transform:351":"monster:알비노 자이언트 크랩",
		"transform:349":"monster:알비노 악어거북"
	}
	var profile_db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_animation_profiles.json"))["profiles"]
	for target: String in shared_six:
		var donor_id: String = str(shared_six[target])
		var target_data: Dictionary = profile_db.get(target, {})
		var donor_data: Dictionary = profile_db.get(donor_id, {})
		check(not target_data.is_empty() and not donor_data.is_empty(), "six-way source record " + target)
		if target_data.is_empty() or donor_data.is_empty(): continue
		check(str(target_data.get("name","")) == str(donor_data.get("name","")), "exact same name " + target)
		check(str(target_data.get("shared_visual_source","")) == donor_id, "explicit no-heuristic source " + target)
		var source_path: String = str(donor_data.get("frames_path",""))
		check(not source_path.is_empty() and source_path == str(target_data.get("frames_path","")), "reuse identical original SpriteFrames " + target)
		if source_path.is_empty() or not ResourceLoader.exists(source_path): continue
		for key: String in ["pixel_scale","sprite_offset","color_tint","embedded_shadow","movement_fps"]:
			check(target_data.get(key,null) == donor_data.get(key,null), "copy only visual source metadata " + target + ":" + key)
		var art_frames: SpriteFrames = CATALOG.frames(source_path, "directional8")
		for direction: int in range(8):
			for role: String in ["idle","walk","attack","hit","death"]:
				var animation: String = role + "_" + str(direction)
				check(art_frames.has_animation(animation) and art_frames.get_frame_count(animation) >= 2, "complete shared motion " + target + ":" + animation)
		var split: PackedStringArray = target.split(":", false, 1)
		var record: Dictionary = {"sourceId":split[1]} if split[0] == "transform" else {"name":split[1]}
		var target_profile: TwilightAnimationProfile = CATALOG.for_record(split[0], record)
		check(target_profile.frames_path == source_path and target_profile.layout == "directional8", "real actor profile uses shared source " + target)
	check(directional_count == 78, "directional coverage changed")
	check(CATALOG.frame_cache.size() <= CATALOG.MAX_FRAME_CACHE, "unbounded frame cache")
	actor.clear_transform_visual()
	check(actor.class_sprite.visible and not actor.transform_sprite.visible, "clear leaves transform residue")
	actor.queue_free()
	await process_frame
	if failures == 0: print("ANIMATION_CATALOG_OK transforms=413 registered_directional=78 native_eight_way=",native_count," shared_attack=413")
	quit(0 if failures == 0 else 1)
