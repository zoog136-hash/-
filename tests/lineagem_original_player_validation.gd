extends SceneTree
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
var failures: int = 0
var hits: Array[int] = []
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_validation")
func run_validation() -> void:
	var manifest: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--lineagem-original-preview="):
			manifest = argument.trim_prefix("--lineagem-original-preview=")
	if manifest.is_empty():
		push_error("An explicit private source inspection manifest is required.")
		quit(1)
		return
	var host: Node2D = Node2D.new()
	root.add_child(host)
	var player = load("res://scenes/Player.tscn").instantiate()
	host.add_child(player)
	player.set_physics_process(false)
	await process_frame
	player.attack_strike.connect(func(sequence: int) -> void: hits.append(sequence))
	var collision: Shape2D = player.get_node("CollisionShape2D").shape
	for id: int in [267, 393]:
		var profile = PROFILE.new()
		profile.profile_id = "transform:" + str(id)
		player.set_transform_visual("", 1.0, profile)
		check(player.original_source_preview.installed(), "Source record did not load")
		player.motion.face(Vector2.DOWN)
		player._update_visual(0.0)
		check(player.original_source_preview.last_source_frame == 11, "Idle must start with native frame11")
		check(not player.transform_sprite.visible, "Authored transform must be hidden in inspection")
		check(not player.get_node("GroundShadow").visible, "Generated shadow must not duplicate native shadow")
		check(not player.get_node("PlayerActionFX").visible, "Generated actor overlay must not alter inspection")
		var before: int = hits.size()
		player.start_combat_attack(player.global_position + Vector2(0, 100), 0.4, "slash", 0.5)
		player._update_visual(0.1)
		check(hits.size() == before, "Damage struck before its existing marker")
		check(player.original_source_preview.last_source_frame == (2 if id == 267 else 0), "Source frame was normalized to the damage clock")
		player._update_visual(0.1)
		check(hits.size() == before + 1, "Existing damage marker did not strike once")
		player._update_visual(0.2)
		check(hits.size() == before + 1, "Source sampling duplicated damage")
		player.cancel_attack()
		for facing: int in range(8):
			for state: String in ["idle", "walk", "run"]:
				player.original_source_preview.advance_source(0.04, state, facing, player.motion.sequence, false)
				check(player.original_source_preview.scale == Vector2.ONE, "Root was rescaled")
				check(player.original_source_preview.position == Vector2.ZERO, "Native origin was normalized")
				check(player.original_source_preview.rotation == 0.0, "Procedural root rotation leaked")
		player.original_source_preview.clear()
		player.original_source_preview.configure(profile.profile_id, manifest)
		for tick: int in range(5):
			player.cancel_attack() # Actual manual input cancels every physics tick.
			player.original_source_preview.advance_source(0.04, "walk", 2, player.motion.sequence, false)
		check(player.original_source_preview.last_source_frame == 3, "Manual movement cancellation froze the source locomotion clock")
		before = hits.size()
		player.start_combat_attack(player.global_position + Vector2(0,100), 0.4, "slash", 0.5)
		player._update_visual(0.6) # A stalled tick can finish gameplay before the first visual sample.
		check(hits.size() == before + 1, "A long tick lost or duplicated the gameplay marker")
		check(player.original_source_preview._role == "attack", "A long tick lost the native attack presentation")
		player.cancel_attack()
		check(player.get_node("CollisionShape2D").shape == collision, "Presentation replaced physics shape")
		player.clear_transform_visual()
		player._update_visual(0.0)
		check(not player.original_source_preview.installed(), "Source pixels survived transform removal")
		check(player.class_sprite.visible, "Class visual did not return")
	print("ORIGINAL_SOURCE_PLAYER_VALIDATION: failures=", failures, "; body/shadow inspection only; sc/mu not approved")
	host.free()
	quit(1 if failures else 0)
