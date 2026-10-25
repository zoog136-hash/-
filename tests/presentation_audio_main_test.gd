extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("PRESENTATION_AUDIO_MAIN FAIL: ", message)

func run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "actual class confirmation")
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world._clear_monsters()
	var audio: Node = world.presentation_audio
	check(root.get_tree().get_nodes_in_group("presentation_audio").size() == 1, "one live event sink")
	audio.clear()
	var before_inventory: int = int(world.inventory.get("HP 물약", 0))
	var drop: Button = world._spawn_ground_drop("HP 물약", world.player.global_position)
	check(is_instance_valid(drop) and audio.last_event == "drop", "successful ground spawn emits drop feedback")
	check(int(world.inventory.get("HP 물약", 0)) == before_inventory, "drop audio cannot grant inventory")
	audio.clear()
	var initial_played: int = audio.played
	check(not world._collect_ground_drop(drop), "new drop visibility guard rejects immediate pickup")
	check(audio.played == initial_played, "visibility guard stays silent")
	await create_timer(0.9).timeout
	check(world._collect_ground_drop(drop), "actual nearby drop pickup succeeds")
	check(audio.last_event == "pickup" and int(world.inventory.get("HP 물약", 0)) == before_inventory + 1, "pickup audio follows real inventory grant")
	var before_audio: int = audio.played
	check(not world._collect_ground_drop(drop), "duplicate pickup rejected")
	check(audio.played == before_audio, "rejected duplicate pickup stays silent")
	audio.clear()
	world.hud._open_window("인벤토리", "인벤토리", "")
	check(audio.last_event == "transition", "real window transition feedback")
	audio.clear()
	var button: Button = preload("res://scripts/ui/renewal_theme.gd").button("오디오 확인", func() -> void: pass)
	world.hud.workspace.content.add_child(button)
	button.pressed.emit()
	check(audio.last_event == "button", "live common UI button emits feedback")
	world._clear_combat_actions()
	for voice: AudioStreamPlayer2D in audio.world_voices: check(not voice.playing, "combat clear stops world audio")
	for voice: AudioStreamPlayer in audio.ui_voices: check(not voice.playing, "combat clear stops UI audio")
	world.queue_free()
	await create_timer(0.1).timeout
	if failures.is_empty(): print("PRESENTATION_AUDIO_MAIN_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
