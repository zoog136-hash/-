extends SceneTree

const EXTERNAL_SPX = preload("res://addons/twilight_l1j/twilight_external_spx_actor.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, explanation: String) -> void:
	if not value:
		failures.append(explanation)
		print("SPX_ACTOR_FAIL: ",explanation)

func _run() -> void:
	_check(EXTERNAL_SPX.frames("../../evil") == null, "reject relative paths")
	_check(EXTERNAL_SPX.frames("99999") == null, "reject unknown sprites")
	_check(EXTERNAL_SPX.frames("21625") == null, "reject unreviewed effects layers")
	var complete: bool = true
	for source_id: String in ["21624", "21653"]:
		var frames: SpriteFrames = EXTERNAL_SPX.frames(source_id)
		_check(frames != null, "synthetic fixture must be mounted " + source_id)
		if frames == null:
			complete = false
			continue
		for role: String in ["idle","walk","attack","hit"]:
			for direction: int in range(8):
				var action: String = role + "_" + str(direction)
				_check(frames.has_animation(action) and frames.get_frame_count(action) >= 2, "full directional track " + source_id + "/" + action)
	if complete:
		var scene: PackedScene = load("res://scenes/Player.tscn") as PackedScene
		var player: TwilightPlayer = scene.instantiate()
		root.add_child(player)
		await process_frame
		_check(player.select_external_spx_actor("21624"), "enable first real actor through public player method")
		player.motion.face(Vector2.LEFT)
		player._update_visual(.05)
		_check(player.spx_sprite.visible and not player.class_sprite.visible, "external sprite replaces class sheet, without adding collision")
		_check(player.spx_sprite.animation == "idle_4", "directional idle faces west")
		var original_shape: Shape2D = player.get_node("CollisionShape2D").shape
		player.start_combat_attack(player.global_position+Vector2.LEFT, .40, "slash", .44)
		player._update_visual(.10)
		_check(player.spx_sprite.animation == "attack_4", "real attack motion selects west facing action")
		_check(player.get_node("CollisionShape2D").shape == original_shape, "presentation must not change collision")
		_check(player.select_external_spx_actor("21653"), "enable second reviewed actor")
		player.cancel_attack()
		player.motion.face(Vector2.RIGHT)
		player._update_visual(.05)
		_check(player.spx_sprite.animation == "idle_0", "directional idle faces east")
		_check(player.select_external_spx_actor(""), "default graphics restore")
		player._update_visual(.05)
		_check(player.class_sprite.visible and not player.spx_sprite.visible, "classic art restored")
		player.queue_free()
		await process_frame
	if failures.is_empty():
		print("EXTERNAL_SPX_ACTOR_RUNTIME_OK sprites=2 directions=8 roles=4 art=synthetic")
		quit(0)
	else:
		print("EXTERNAL_SPX_ACTOR_RUNTIME_FAIL ",failures.size())
		quit(1)
