extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		print("SKILL_AUDIO FAIL: ", message)

func run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter actual gameplay")
	await process_frame
	world.set_process(false)
	world._clear_monsters()
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	var service := world.original_skills
	var audio := service.vfx.audio_pool
	check(audio.players.size() == 6, "bounded six-voice pool")
	for record: Dictionary in service.catalog.records:
		var id := str(record.id)
		check(audio.play_skill(id, Vector2(25, 50), "cast"), "play authored WAV " + str(record.name))
		var voice: AudioStreamPlayer2D = audio.players[(audio.next_voice + 5) % 6]
		check(voice.stream is AudioStreamWAV and voice.stream.get_length() > 0, "actual nonempty WAV stream " + str(record.name))
		check(voice.global_position == Vector2(25, 50) and is_equal_approx(voice.pitch_scale, .78), "cast spatial position and phase pitch")
	var before := audio.played
	check(not audio.play_skill("unknown-id", Vector2.ZERO), "missing resource rejected safely")
	check(not audio.play_skill(str(service.catalog.records[0].id), Vector2.ZERO, "unknown-phase"), "invalid phase rejected safely")
	check(audio.played == before, "rejected audio does not consume a voice")
	world.job_class = "마법사"
	world.level = 90
	var base := service.catalog.record_for("턴 언데드")
	var ancient := service.catalog.record_for("턴 언데드(에이션트)")
	service.catalog.learned[str(base.id)] = 1
	service.catalog.learned[str(ancient.id)] = 1
	var dummy: TwilightMonster = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"오디오 검사 NPC", "hp":1000, "mr":150, "undead":true}, world.player, world, null)
	dummy.global_position = world.player.global_position + Vector2(10, 0)
	dummy.set_physics_process(false)
	world.selected_monster = dummy
	world.mp = 999
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	check(world._cast_job_skill(str(base.name)), "real upgraded cast")
	check(audio.last_skill == str(ancient.id) and audio.last_phase == "cast", "cast uses upgraded resource at real cast event")
	before = audio.played
	check(not world._cast_job_skill(str(base.name)) and audio.played == before, "denied duplicate has no cast sound")
	service.vfx.emit_skill(str(base.id), "resist", dummy.global_position)
	var voice: AudioStreamPlayer2D = audio.players[(audio.next_voice + 5) % 6]
	check(audio.last_phase == "resist" and is_equal_approx(voice.pitch_scale, .62), "resist sound has a distinct phase")
	# Audio stays active when the optional visual pool is saturated.
	for _effect: int in range(service.vfx.MAX_EFFECTS): service.vfx.emit_skill(str(base.id), "end", Vector2.ZERO)
	before = audio.played
	service.vfx.emit_skill(str(base.id), "impact", dummy.global_position)
	check(audio.played == before + 1 and audio.last_phase == "impact", "visual budget cannot suppress confirmed-hit audio")
	world._clear_combat_actions()
	for player: AudioStreamPlayer2D in audio.players: check(not player.playing, "map/class clear stops active voice")
	check(audio.next_voice == 0 and audio.players.size() == 6, "clear retains bounded reusable pool")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_AUDIO_OK checks=", checks, " resources=", service.catalog.records.size(), " voices=6")
	quit(0 if failures.is_empty() else 1)
