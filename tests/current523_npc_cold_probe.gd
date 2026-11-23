extends SceneTree
## Actual pinned original only. Run via tools/monsters/benchmark_npc_cold.py.
## Emits timings and hashes, never source rows. No save or actor is created.
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
const CATALOG = preload("res://scripts/monsters/patch523_npc_catalog.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var prepare: bool = "--npc-prepare" in OS.get_cmdline_user_args()
	var ids: PackedStringArray = ["74161"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--npc-ids="): ids = arg.trim_prefix("--npc-ids=").split(",")
	if ROWS.identity().get("source_sha256") != ROWS.SOURCE_SHA:
		printerr("NPC_COLD_PROBE: exact original archive unavailable")
		quit(1); return
	var memory: int = OS.get_static_memory_usage()
	var started: int = Time.get_ticks_usec()
	var prepare_ok: bool = true
	if prepare:
		for table: String in ROWS.encounter_tables_to_prepare():
			prepare_ok = ROWS.prepare_encounter_table(table) and prepare_ok
			ROWS.release_caches()
	var report: Dictionary = {"prepared": prepare, "prepare_ok": prepare_ok,
		"prepare_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"prepare_retained_bytes": OS.get_static_memory_usage() - memory, "npcs": []}
	var catalog := CATALOG.new()
	for text: String in ids:
		if not text.is_valid_int(): quit(1); return
		var id: int = int(text)
		# Match the diagnostic boundary: NpcClass has been read before projection.
		var source: Dictionary = ROWS.row("NpcClass", id)
		var record: Dictionary = {"source_m_npc_id": id, "source_m_original": source, "level": 1}
		started = Time.get_ticks_usec()
		var projected: Dictionary = catalog.project_actor_record(record)
		var first_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		if projected.get("source_m_definition_snapshot") != "patch523":
			printerr("NPC_COLD_PROBE: NPC not projected: ", id, " ", catalog.error)
			quit(1); return
		var samples: Array[float] = []
		for repeat: int in 40:
			started = Time.get_ticks_usec()
			catalog.project_actor_record(record)
			samples.append((Time.get_ticks_usec() - started) / 1000.0)
		samples.sort()
		report.npcs.append({"id": id, "first_projection_ms": first_ms, "warm_p50_ms": samples[20],
			"record_sha256": JSON.stringify(projected, "", true, true).sha256_text(),
			"closure_sha256": catalog.source_model_sha256})
	report["static_peak_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	report["static_bytes"] = OS.get_static_memory_usage()
	print("NPC_COLD_PROBE_RESULT " + JSON.stringify(report))
	quit(0 if prepare_ok else 1)
