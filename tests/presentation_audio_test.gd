extends SceneTree

const AUDIO = preload("res://scripts/audio/presentation_audio.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("PRESENTATION_AUDIO FAIL: ", message)

func run() -> void:
	var audio := AUDIO.new()
	root.add_child(audio)
	await process_frame
	check(audio.get_child_count() == 6, "fixed six-voice allocation")
	for event: String in AUDIO.WORLD_EVENTS:
		check(audio.play_world(event, Vector2(42, 84), event == "impact"), "valid world event " + event)
		var voice: AudioStreamPlayer2D = audio.world_voices[(audio.world_cursor + 3) % 4]
		check(voice.stream is AudioStreamWAV and voice.stream.get_length() > 0.0, "real shipped stream " + event)
		check(voice.global_position == Vector2(42, 84), "world event spatial origin")
		check(voice.volume_db <= -18.0, "bounded event gain")
	var world_cursor: int = audio.world_cursor
	for event: String in AUDIO.UI_EVENTS:
		check(audio.play_ui(event), "valid UI event " + event)
	check(audio.world_cursor == world_cursor, "UI never steals world voice")
	var before: int = audio.played
	check(not audio.play_world("missing", Vector2.ZERO), "unknown world event rejected")
	check(not audio.play_ui("missing"), "unknown UI event rejected")
	check(not audio.play_world("impact", Vector2(INF, 0)), "nonfinite source rejected")
	check(audio.played == before, "rejected events consume no voice")
	audio.clear()
	check(audio.recent.is_empty(), "map clear resets burst history")
	check(audio.play_world("drop", Vector2.ZERO), "first batch drop audible")
	for _index: int in range(100): audio.play_world("drop", Vector2.ZERO)
	check(audio.suppressed == 100, "same-tick drop burst coalesced")
	check(audio.get_child_count() == 6, "burst creates no extra nodes")
	# Force only the sound history old; no gameplay clock, timers or RNG involved.
	audio.recent["drop"] = Time.get_ticks_usec() - AUDIO.BURST_USEC
	check(audio.play_world("drop", Vector2.ZERO), "later drop remains audible")
	audio.muted = true
	before = audio.played
	check(not audio.play_world("hurt", Vector2.ZERO) and not audio.play_ui("confirm"), "mute covers both pools")
	check(audio.played == before, "mute consumes no voice")
	audio.clear()
	for voice: AudioStreamPlayer2D in audio.world_voices: check(not voice.playing, "map clear stops spatial voice")
	for voice: AudioStreamPlayer in audio.ui_voices: check(not voice.playing, "map clear stops UI voice")
	check(audio.world_cursor == 0 and audio.ui_cursor == 0, "map clear resets reusable cursors")
	audio.queue_free()
	# Let the audio mixer release stopped playback references before teardown.
	await create_timer(0.1).timeout
	if failures.is_empty(): print("PRESENTATION_AUDIO_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
