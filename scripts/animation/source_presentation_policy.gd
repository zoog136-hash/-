extends RefCounted
## Identity-scoped observed presentation; never rewrites SPR ticks, FPS or source durations.
const PATH = "res://data/lineagem_base508/source_presentation_observations.json"
static var _rules: Array = []
static func rules() -> Array:
	if _rules.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if value is Dictionary and value.get("schema", 0) == 1 and value.get("source_snapshot", "") == "base508": _rules = value.get("rules", [])
	return _rules
static func apply(record: Dictionary, tracks: Dictionary, mode: String, consumer_kind: String) -> void:
	# Pack metadata cannot enable a presentation override, especially in strict mode.
	for track: Dictionary in tracks.values():
		track.erase("presentation_observation")
		for frames: Array in track.get("directions", []):
			for frame: Dictionary in frames: frame.erase("presentation_duration")
	if mode != "compatible": return
	for rule: Dictionary in rules():
		if rule.get("reference_evidence_status", "") != "verified_scoped_observation" or not rule.get("consumer_kinds", []).has(consumer_kind): continue
		if "--lineagem-%d-source-presentation" % int(rule.source_sprite_id) in OS.get_cmdline_user_args(): continue
		if int(record.get("source_sprite_id", 0)) != int(rule.source_sprite_id) or int(record.get("body_id", 0)) != int(rule.source_body_id): continue
		var track: Dictionary = tracks.get(str(rule.role), {})
		if track.is_empty() or bool(track.get("static_pending_timing", true)) or not bool(track.get("loop", false)): continue
		if float(rule.observed_boundary_seconds) <= 0.0 or float(rule.observed_boundary_seconds) >= float(rule.expected_ticks) / float(rule.effective_fps_required): continue
		if int(track.get("source_sprite_id", 0)) != int(rule.source_sprite_id) or int(track.get("source_action_id", -1)) != int(rule.source_action_id): continue
		if not is_equal_approx(float(track.get("effective_fps", 0.0)), float(rule.effective_fps_required)) or str(track.get("source_raw_body", "")).sha256_text() != str(rule.source_raw_body_sha256): continue
		if track.get("fps") != rule.get("expected_source_fps"): continue
		var eligible: Array = []
		var valid: bool = track.get("directions", []).size() == 8
		for frames: Array in track.get("directions", []):
			if frames.is_empty(): valid = false; continue
			var bit: int = int(frames[0].get("stored_direction_bit", -1))
			var observed_bit: bool = false
			for value: Variant in rule.observed_stored_direction_bits:
				if int(value) == bit: observed_bit = true
			if not observed_bit: continue
			eligible.append(frames)
			if frames.size() != rule.expected_sequence.size(): valid = false; continue
			for index: int in range(frames.size()):
				var frame: Dictionary = frames[index]
				if int(frame.get("source_frame", -1)) != int(rule.expected_sequence[index]) or int(frame.get("source_group", -1)) != int(rule.expected_source_group) or int(frame.get("source_ticks", -1)) != int(rule.expected_ticks) or int(frame.get("physical_group", -1)) != int(rule.expected_physical_group) or int(frame.get("stored_direction_bit", -1)) != bit or not frame.get("source_annotations", []).is_empty(): valid = false
		if not valid or eligible.is_empty(): continue
		for frames: Array in eligible: frames[0]["presentation_duration"] = float(rule.observed_boundary_seconds)
		track["presentation_observation"] = rule.duplicate(true)
static func duration(frame: Dictionary) -> float:
	return float(frame.get("presentation_duration", frame.get("duration", 0.0)))
