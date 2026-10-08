extends SceneTree

var failures: Array[String] = []
var strikes: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		print("MOTION FAIL: " + detail)

func _run() -> void:
	var actor: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	actor.attack_strike.connect(func(id: int) -> void: strikes.append(id))
	var foot: Vector2 = actor.position
	var shape: Transform2D = actor.get_node("CollisionShape2D").transform
	for i: int in range(8):
		var vector: Vector2 = Vector2.from_angle(i * PI / 4.0)
		actor.motion.face(vector)
		check(actor.facing8 == i, "8-way facing " + str(i))
		actor.motion.advance(0.12, vector * 210.0)
		actor.motion.apply(actor.class_sprite, Vector2.ONE)
		check(actor.position == foot, "animation moved collision body")
		check(actor.get_node("CollisionShape2D").transform == shape, "animation altered collider")
	actor.motion.advance(0.2, Vector2.ZERO)
	check(actor.animation_state == "idle", "stop did not settle to idle")
	for duration: float in [1.44, 0.72, 0.18]:
		strikes.clear()
		var id: int = actor.start_combat_attack(Vector2.RIGHT * 100, duration, "slash", 0.44)
		actor.motion.advance(duration * 0.43, Vector2.ZERO)
		check(strikes.is_empty(), "damage marker fired before hit frame")
		actor.motion.advance(duration * 0.02, Vector2.ZERO)
		actor.motion.apply(actor.class_sprite, Vector2.ONE)
		check(strikes == [id], "hit marker missing or duplicated")
		check(actor.class_sprite.frame == 3, "marker and class hit frame differ")
		actor.motion.react(true)
		actor.motion.advance(duration, Vector2.ZERO)
		check(strikes.size() == 1 and not actor.motion.active, "critical freeze changed attack count/cadence")
	strikes.clear()
	actor.start_combat_attack(Vector2.LEFT, 0.7, "bow")
	actor.cancel_attack()
	actor.motion.advance(1.0, Vector2.ZERO)
	check(strikes.is_empty(), "cancelled swing fired")
	actor.queue_free()
	await process_frame
	if failures.is_empty(): print("ACTOR_MOTION_OK")
	quit(0 if failures.is_empty() else 1)
