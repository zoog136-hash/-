extends SceneTree
func _initialize() -> void:
	var manifest: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="): manifest = arg.trim_prefix("--manifest=")
	assert(not manifest.is_empty())
	var actor := preload("res://scripts/animation/original_source_preview.gd").new()
	root.add_child(actor)
	actor.playback_mode_override = "strict"
	for sid: int in [17488, 18688, 18897]:
		assert(actor.configure("sprite:" + str(sid), manifest))
		for role: String in ["idle", "walk", "attack", "run"]:
			assert(not actor._playback_tracks[role].static_pending_timing)
			assert(actor._playback_tracks[role].timing_origin == "SPR_explicit_section")
		actor.advance_source(0.1, "run", 2, 0, false)
		assert(actor.last_source_frame >= 0)
		print("NATIVE_TIMING_SOURCE_LOAD sprite=", sid, " strict_run_fps=", actor._playback_tracks.run.effective_fps, " frame=", actor.last_source_frame)
	quit()
