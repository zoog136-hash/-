extends SceneTree
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
func _initialize() -> void:
	var archive: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--old-metadata="): archive = arg.trim_prefix("--old-metadata=")
	if archive.is_empty():
		push_error("Pass private old-metadata backup ZIP; no image data required.")
		quit(2)
		return
	var zip := ZIPReader.new()
	assert(zip.open(archive) == OK)
	var corrected: int = 0
	for path: String in zip.get_files():
		var record: Dictionary = JSON.parse_string(zip.read_file(path).get_string_from_utf8())
		var strict: Dictionary = POLICY.tracks(record, "transform", "strict")
		var compatible: Dictionary = POLICY.tracks(record, "transform", "compatible")
		for role: String in record.tracks:
			var old: Dictionary = record.tracks[role]
			if old.fps != null: continue
			corrected += 1
			var expected: int = 36 if role in ["walk", "run"] else 24
			assert(strict[role].fps == expected and strict[role].effective_fps == expected)
			assert(strict[role].timing_origin == "SPR_explicit_section")
			assert(not strict[role].static_pending_timing)
			assert(compatible[role].effective_fps == expected)
			for direction: int in range(8):
				for index: int in range(old.directions[direction].size()):
					var before: Dictionary = old.directions[direction][index]
					var after: Dictionary = strict[role].directions[direction][index]
					assert(is_equal_approx(float(after.duration), float(before.source_ticks) / expected))
					assert(after.layers == before.layers)
					assert(after.get("effect_layers", []) == before.get("effect_layers", []))
					assert(after.source_ticks == before.source_ticks and after.source_frame == before.source_frame)
			# An unrelated raw declaration must not inherit a matching sprite's repair.
			var changed: Dictionary = record.duplicate(true)
			changed.tracks[role].source_raw_body += " MODIFIED"
			assert(POLICY.tracks(changed, "transform", "strict")[role].static_pending_timing)
	zip.close()
	assert(corrected == 49)
	print("NATIVE_TIMING_WHITESPACE_SMOKE strict_and_compatible_corrected=", corrected, " pixels_ticks_order_unchanged=true")
	quit()
