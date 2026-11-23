extends SceneTree
## Actual pinned original only. Run via tools/monsters/benchmark_npc_cold.py.
## Emits timings and hashes, never source rows. No save or actor is created.
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var ids: PackedStringArray = ["74161"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--npc-ids="): ids = arg.trim_prefix("--npc-ids=").split(",")
	var source_started: int = Time.get_ticks_usec()
	if ROWS.identity().get("source_sha256") != ROWS.SOURCE_SHA:
		printerr("NPC_COLD_PROBE: exact original archive unavailable")
		quit(1); return
	var source_ms: float = (Time.get_ticks_usec() - source_started) / 1000.0
	var report: Dictionary = {"fast_enabled": ROWS.npc_index_fast_enabled(),
		"source_open_ms": source_ms, "prepare_ms": 0.0, "npcs": []}
	var stage_total_ms: float = source_ms
	var started: int
	var catalog := CATALOG.new()
	for text: String in ids:
		if not text.is_valid_int(): quit(1); return
		var id: int = int(text)
		# Include NpcClass cost in the total, separately from the projection boundary.
		started = Time.get_ticks_usec()
		var source: Dictionary = ROWS.row("NpcClass", id)
		var class_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		var record: Dictionary = {"source_m_npc_id": id, "source_m_original": source, "level": 1}
		started = Time.get_ticks_usec()
		var projected: Dictionary = catalog.project_actor_record(record)
		var first_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		if projected.get("source_m_definition_snapshot") != "patch523":
			printerr("NPC_COLD_PROBE: NPC not projected: ", id, " ", catalog.error)
			quit(1); return
		stage_total_ms += class_ms + first_ms
		var samples: Array[float] = []
		for repeat: int in 40:
			started = Time.get_ticks_usec()
			catalog.project_actor_record(record)
			samples.append((Time.get_ticks_usec() - started) / 1000.0)
		samples.sort()
		report.npcs.append({"id": id, "npc_class_ms": class_ms, "first_projection_ms": first_ms, "warm_p50_ms": samples[20],
			"record_sha256": JSON.stringify(projected, "", true, true).sha256_text(),
			"closure_sha256": catalog.source_model_sha256})
	report["total_stage_ms"] = stage_total_ms
	report["fast_index_builds"] = ROWS.npc_fast_index_builds
	report["opened_tables"] = ROWS._tables.keys()
	report["static_peak_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	report["static_bytes"] = OS.get_static_memory_usage()
	print("NPC_COLD_PROBE_RESULT " + JSON.stringify(report))
	quit(0)
