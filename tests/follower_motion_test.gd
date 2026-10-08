extends SceneTree

const FOLLOWER = preload("res://scripts/animation/follower_motion.gd")
var failures: int = 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FOLLOWER FAIL: " + label)

func _run() -> void:
	var actor: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(actor)
	var anchor: Node2D = Node2D.new()
	root.add_child(anchor)
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	anchor.add_child(sprite)
	await process_frame
	actor.set_physics_process(false)
	var follower: TwilightFollowerMotion = FOLLOWER.new()
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/directional_art_v19.json"))
	for record: Dictionary in db["마법인형"]:
		var key: String = "doll:" + str(record.sourceId)
		var path: String = str(art.get(key, {}).get("path", record.image_path))
		follower.configure(record, path, anchor, sprite, actor)
		check(follower.enabled and sprite.visible, "missing " + key)
		if not art.has(key): check(sprite.sprite_frames.has_animation("still"), "single image sliced " + key)
	actor.velocity = Vector2(450, 0)
	for i: int in range(120):
		actor.position += actor.velocity / 60.0
		var before: Vector2 = anchor.position
		follower.update(1.0 / 60.0, anchor, sprite, actor)
		check(anchor.position.distance_to(before) <= 10.2, "follow teleported while running")
	check(follower.motion.direction.x > 0.0, "facing is not actual follow direction")
	actor.velocity = Vector2.ZERO
	for i: int in range(240): follower.update(1.0 / 60.0, anchor, sprite, actor)
	var stopped: Vector2 = anchor.position
	for i: int in range(60): follower.update(1.0 / 60.0, anchor, sprite, actor)
	check(anchor.position == stopped and follower.state == "idle", "idle follow jitter")
	check(anchor.position.distance_to(actor.position) >= 45.0, "doll overlaps player")
	follower.configure({}, "", anchor, sprite, actor)
	for i: int in range(30): follower.update(1.0 / 60.0, anchor, sprite, actor)
	check(not sprite.visible and follower.state == "despawn", "despawn did not finish")
	actor.queue_free()
	anchor.queue_free()
	await process_frame
	if failures == 0: print("FOLLOWER_MOTION_OK dolls=166")
	quit(0 if failures == 0 else 1)
