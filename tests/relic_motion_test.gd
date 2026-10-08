extends SceneTree

const RELIC = preload("res://scripts/animation/relic_motion.gd")
const FOLLOWER = preload("res://scripts/animation/follower_motion.gd")
var failures: int = 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("RELIC FAIL: " + label)

func _run() -> void:
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(player)
	var sprite: Sprite2D = Sprite2D.new()
	root.add_child(sprite)
	var doll: AnimatedSprite2D = AnimatedSprite2D.new()
	var anchor: Node2D = Node2D.new()
	root.add_child(anchor)
	anchor.add_child(doll)
	await process_frame
	player.set_physics_process(false)
	var motion: TwilightRelicMotion = RELIC.new()
	var follower: TwilightFollowerMotion = FOLLOWER.new()
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	for record: Dictionary in db["성물"]:
		motion.configure(record, sprite, player, Color(0.16, 1.0, 0.68))
		check(motion.enabled and sprite.texture != null, "missing relic " + str(record.name))
		check(sprite.z_index == 0 and sprite.offset.y < 0.0, "relic lost foot-based sorting")
	var record: Dictionary = db["마법인형"][0]
	follower.configure(record, record.image_path, anchor, doll, player)
	for i: int in range(180):
		player.position += Vector2(4, 1)
		player.velocity = Vector2(240, 60)
		motion.update(1.0 / 60.0, sprite, player)
		follower.update(1.0 / 60.0, anchor, doll, player)
	check(sprite.position.distance_to(anchor.position) > 50.0, "relic/doll overlap")
	player.start_combat_attack(player.position + Vector2.RIGHT, 0.7, "slash")
	motion.update(0.01, sprite, player)
	check(motion.state == "combat_reaction", "relic does not respond to combat")
	motion.configure({}, sprite, player, Color.WHITE)
	for i: int in range(30): motion.update(1.0 / 60.0, sprite, player)
	check(not sprite.visible and sprite.texture == null, "relic despawn retained visible resource")
	player.queue_free()
	sprite.queue_free()
	anchor.queue_free()
	await process_frame
	if failures == 0: print("RELIC_MOTION_OK relics=144 simultaneous_doll=true")
	quit(0 if failures == 0 else 1)
