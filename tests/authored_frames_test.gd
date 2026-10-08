extends SceneTree

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
var failures: int = 0
var markers: Array[int] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("AUTHORED FRAMES FAIL: " + label)

func _run() -> void:
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var authored: SpriteFrames = player.class_sprite.sprite_frames.duplicate(true) as SpriteFrames
	var path: String = "user://authored-frames.tres"
	check(ResourceSaver.save(authored, path) == OK, "could not save native SpriteFrames fixture")
	var record: Dictionary = {"sourceId":"fixture", "animation_profile":{
		"frames_path":path, "dedicated_attack":true, "attack_hit_ratio":0.6,
		"attack_hit_frame":2, "attack_animation_speed":2.0,
		"animation_names":{"attack":"attack", "idle":"walk_down"}}}
	var profile: TwilightAnimationProfile = CATALOG.for_record("transform", record)
	player.set_transform_visual("", 1.0, profile)
	check(player.transform_active and player.transform_sprite.sprite_frames.get_frame_count("attack") == 5, "native authored frames not applied")
	check(is_equal_approx(profile.marker_for("bow"), 0.6), "per-form marker ignored weapon override")
	player.attack_strike.connect(func(id: int) -> void: markers.append(id))
	player.start_combat_attack(player.position + Vector2.RIGHT, 1.0, "slash", profile.marker_for("slash"))
	player.motion.advance(0.55, Vector2.ZERO)
	player.motion.apply(player.transform_sprite, player.transform_sprite.get_meta("base_scale"))
	check(markers.is_empty() and player.transform_sprite.frame < 2, "visual speed released damage before authored hit frame")
	player.motion.advance(0.05, Vector2.ZERO)
	player.motion.apply(player.transform_sprite, player.transform_sprite.get_meta("base_scale"))
	check(markers.size() == 1 and player.transform_sprite.frame == 2, "authored marker and hit frame differ")
	player.motion.advance(0.2, Vector2.ZERO)
	player.motion.apply(player.transform_sprite, player.transform_sprite.get_meta("base_scale"))
	check(player.transform_sprite.animation == "attack" and player.transform_sprite.frame >= 2, "recovery lost authored attack animation")
	player.motion.advance(0.3, Vector2.ZERO)
	check(markers.size() == 1 and not player.motion.active, "authored visual speed changed cadence or duplicated marker")
	check(CATALOG.frames(path, "still") == player.transform_sprite.sprite_frames, "authored frames cache not reused")
	player.queue_free()
	await process_frame
	if failures == 0: print("AUTHORED_FRAMES_OK native_resources=true configurable_hit_frame=true")
	quit(0 if failures == 0 else 1)
