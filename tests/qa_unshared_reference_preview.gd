extends "res://scripts/animation/original_source_preview.gd"
## Baseline NPC preparation at main 3ea41de9, for differential tests only.
func _configure_reference_bank(manifest_path: String, expected_manifest_sha: String, source_actor_id: int, explicit_role_action_bindings: Dictionary, caller_loop_policy: Dictionary, initial_role: String, card_consumer: String, role_actor_ids: Dictionary = {}) -> bool:
	clear()
	_current523_source_only = not card_consumer.is_empty()
	if not explicit_role_action_bindings.has(initial_role):
		reference_bank_status = {"ok":false,"error":"Explicit initial caller role is required."}
		return false
	var bank := REFERENCE_BANK.new()
	var loaded: Dictionary = bank.load_bank(manifest_path, expected_manifest_sha, source_actor_id, explicit_role_action_bindings, caller_loop_policy,card_consumer,role_actor_ids)
	reference_bank_status = {"ok":loaded.ok,"error":loaded.get("error", ""),"purpose":"diagnostic_reference_preview","source_actor_id":source_actor_id,"manifest_sha256":expected_manifest_sha}
	reference_bank_status["source_dummy_exclusion_policy"] = loaded.get("source_dummy_exclusion_policy")
	reference_bank_status["map_consumer_contract_dependency"] = loaded.get("map_consumer_contract_dependency")
	if loaded.has("source_exclusion"):
		reference_bank_status["source_exclusion"] = loaded.source_exclusion.duplicate(true)
		reference_bank_status["excluded_source_actor_id"] = loaded.excluded_source_actor_id
	if not loaded.ok: return false
	_reference_bank = bank
	_root = manifest_path.get_base_dir()
	_playback_mode = POLICY.mode(_root,playback_mode_override) if not card_consumer.is_empty() else (playback_mode_override if playback_mode_override in ["strict", "compatible"] else "strict")
	# Source FPS remains null when absent. Existing production policy owns only
	# the effective compatibility rate; strict mode holds unresolved actions.
	var tracks: Dictionary = POLICY.tracks(loaded.record,card_consumer,_playback_mode) if not card_consumer.is_empty() else loaded.tracks
	var layer_count: int = 0
	for track: Dictionary in tracks.values():
		for frames: Array in track.directions:
			for frame: Dictionary in frames: layer_count = maxi(layer_count, frame.layers.size())
	_configure_source_nodes(loaded.record, tracks, layer_count, manifest_path)
	_role = initial_role
	return true

