extends SceneTree
## Run with TWILIGHT_PATCH523_CONTENT pointing to the pinned original, in an
## isolated XDG_DATA_HOME. Run again with the same directory for a cache hit.
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const NPC_ID := 71634

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := ROWS.row("NpcClass", NPC_ID)
	if source.get("Sprite") != 21309:
		printerr("NPC 71634 needs the verified 523 definitions archive.")
		quit(1)
		return
	var host := {"source_m_npc_id": NPC_ID, "source_m_original": {"ID": NPC_ID,
		"Sprite": source.Sprite, "DescId": source.DescId}, "attack_range": 88.0, "source_m_spawn_npc_level": 99}
	var digest := ""
	var samples: Array[Dictionary] = []
	for phase: String in ["first", "post_release"]:
		if phase == "post_release": ROWS.release_caches()
		var catalog := CATALOG.new()
		catalog.configure_original()
		HITCH._details.clear()
		var started := Time.get_ticks_usec()
		var actor := catalog.project_actor_record(host)
		var total := Time.get_ticks_usec() - started
		var typed: int = HITCH._details.get("npc.project_typed_growth", [0])[0]
		if actor.get("source_m_definition_snapshot") != "patch523" or not catalog.admitted_source_identities.has(str(NPC_ID)):
			printerr("NPC admission failed: ", catalog.error)
			quit(1)
			return
		started = Time.get_ticks_usec()
		var repeat := catalog.project_actor_record(host)
		var repeat_time := Time.get_ticks_usec() - started
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(var_to_bytes([actor, catalog.content, catalog.indexes,
			catalog.admitted_source_identities, catalog.source_model_sha256]))
		var current := hash.finish().hex_encode()
		if var_to_bytes(repeat) != var_to_bytes(actor) or (not digest.is_empty() and digest != current):
			printerr("Projected actor or registry changed between runs.")
			quit(1)
			return
		digest = current
		samples.append({"phase": phase, "projection_usec": total, "typed_growth_usec": typed,
			"repeat_projection_usec": repeat_time})
	print("FIRST_NPC_PROJECTION ", JSON.stringify({"sha256": digest, "samples": samples}))
	quit()
