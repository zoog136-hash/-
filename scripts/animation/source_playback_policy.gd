extends RefCounted
## Explicit host compatibility, never presented as verified Lineage M client behavior.
const POLICY_PATH = "res://data/lineagem_base508/playback_policy.json"
const CORRECTIONS_PATH = "res://data/lineagem_base508/source_timing_corrections.json"
static var _clock_corrections: Dictionary = {}
static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
		if value is Dictionary: _data = value
	return _data
static func mode(pack_root: String, override: String = "") -> String:
	var result: String = str(data().get("default_mode", "strict"))
	var config_path: String = preload("res://scripts/lineagem_pack_install.gd").resolve_file(pack_root, "playback_settings.json")
	if FileAccess.file_exists(config_path):
		var local: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
		if local is Dictionary: result = str(local.get("mode", result))
	if override in ["strict", "compatible"]: result = override
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--lineagem-source-strict": result = "strict"
		elif argument == "--lineagem-source-compatible": result = "compatible"
	return result if result in ["strict", "compatible"] else "strict"
static func clock_corrections() -> Dictionary:
	if _clock_corrections.is_empty() and FileAccess.file_exists(CORRECTIONS_PATH):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CORRECTIONS_PATH))
		if value is Dictionary and value.get("source_snapshot", "") == "base508": _clock_corrections = value.get("corrections", {})
	return _clock_corrections
static func tracks(record: Dictionary, consumer_kind: String, selected_mode: String) -> Dictionary:
	var result: Dictionary = record.get("tracks", {}).duplicate(true)
	return _configure_tracks(record,result,consumer_kind,selected_mode)

## Prepared NPC layers/provenance are recursively read-only. Copy only the
## track/frame containers this policy edits; clocks/events/nodes stay private.
static func tracks_from_prepared(record: Dictionary, consumer_kind: String, selected_mode: String) -> Dictionary:
	if not record.is_read_only(): return tracks(record,consumer_kind,selected_mode)
	var result: Dictionary = {}
	for role: String in record.tracks:
		var source: Dictionary = record.tracks[role]
		var track: Dictionary = source.duplicate()
		var directions: Array = []
		for frames: Array in source.directions:
			var copied: Array = []
			for frame: Dictionary in frames: copied.append(frame.duplicate())
			directions.append(copied)
		track.directions = directions
		result[role] = track
	return _configure_tracks(record,result,consumer_kind,selected_mode)

static func _configure_tracks(record: Dictionary, result: Dictionary, consumer_kind: String, selected_mode: String) -> Dictionary:
	for role: String in result:
		var track: Dictionary = result[role]
		var fps: float = float(track.get("fps", 0.0)) if track.get("fps") != null else 0.0
		var origin: String = "SPR_explicit_section"
		# Already-delivered v2 metadata predates whitespace-normalized code110 parsing.
		# Recover only the exact matching source action; no guessed global rate override.
		var correction_key: String = str(int(track.get("source_sprite_id", 0))) + ":" + str(int(track.get("source_action_id", -1))) + ":" + role
		var correction: Dictionary = clock_corrections().get(correction_key, {})
		if fps <= 0.0 and not correction.is_empty() and int(track.get("source_body_id", record.get("body_id", 0))) == int(correction.get("source_body_id", -1)) and str(track.get("source_raw_body", "")).sha256_text() == str(correction.get("source_raw_body_sha256", "")):
			fps = float(correction.fps)
			track["fps"] = fps
			track["source_timing_provenance"] = correction.source_rate_directive.duplicate(true)
			track["source_clock_metadata_repair"] = "exact_SPR_code110_whitespace_fix"

		if fps <= 0.0 and selected_mode == "compatible":
			var key: String = str(int(track.get("source_sprite_id", record.get("source_sprite_id", 0)))) + ":" + role
			var inherited: Dictionary = data().get("alias_base_rate_candidates", {}).get(key, {})
			if not inherited.is_empty():
				fps = float(inherited.fps)
				origin = "compat_alias_base_explicit_rate_M_inheritance_unverified"
			elif consumer_kind == "doll":
				var shared: Dictionary = data().get("doll_shared_compatibility", {}).get("ticks_per_second_by_role", {})
				fps = float(shared.get(role, shared.get("default", 24)))
				if fps > 0.0: origin = "compat_user_approved_doll_shared_24_not_verified_M_default"
			elif consumer_kind in ["transform","class"]:
				var row: Dictionary = data().get("m_player_actions", {}).get(str(int(track.get("source_action_id", -1))), {})
				fps = float(row.get("PlayerFrameRate", 0.0))
				if fps > 0.0: origin = "compat_M_ListSprAction_player_rate_scope_unverified"
			if fps <= 0.0:
				fps = float(data().get("pc_default_ticks_per_second", 24))
				origin = "compat_PC_3_81_default_24_not_verified_for_M"
		var valid: bool = fps > 0.0
		for frames: Array in track.get("directions", []):
			var ticks: float = 0.0
			for frame: Dictionary in frames:
				var value: float = float(frame.get("source_ticks", 0.0))
				if value < 0.0: valid = false
				ticks += value
				if fps > 0.0: frame["duration"] = value / fps
			if ticks <= 0.0: valid = false
		for issue: String in track.get("timing_issues", []):
			# Earlier checkpoints classified native instantaneous event tokens as invalid.
			if issue != "nonpositive frame duration": valid = false
		track["effective_fps"] = fps
		track["timing_origin"] = origin if valid else "strict_unresolved"
		track["static_pending_timing"] = not valid
	preload("res://scripts/animation/source_presentation_policy.gd").apply(record, result, selected_mode, consumer_kind)
	return result
static func effect(attributes: Array, selected_mode: String) -> Dictionary:
	if selected_mode != "compatible": return {"enabled":false,"reason":"strict_unverified_blend"}
	var bits: int = 0
	for value: Variant in attributes: bits |= int(str(value))
	if bits == 8:
		return {"enabled":true,"blend_mode":CanvasItemMaterial.BLEND_MODE_ADD,"alpha":1.0,"origin":"compat_PC_glowing_description_Godot_add_exact_M_equation_unverified"}
	if bits == 128:
		return {"enabled":true,"blend_mode":CanvasItemMaterial.BLEND_MODE_MIX,"alpha":float(data().get("attr128_compat_alpha", 0.5)),"origin":"compat_PC_black_edge_translucent_description_alpha_0_5_host_choice_M_unverified"}
	if bits == 0 or bits == 4:
		return {"enabled":true,"blend_mode":CanvasItemMaterial.BLEND_MODE_MIX,"alpha":1.0,"origin":"compat_standard_RGBA_source_pixels"}
	return {"enabled":false,"reason":"unmapped_native_attr_preserved"}
