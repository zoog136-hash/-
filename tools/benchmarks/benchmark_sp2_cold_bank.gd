extends "res://tests/benchmark_reference_sp2_attributes.gd"
## Diagnostic visual preparation, not monster gameplay admission/setup.
## Five core roles x 32 tokens x eight directions; only the body SP2 is enlarged.
## All inputs are synthetic. No private pack, device or upload claim.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const CACHE = preload("res://scripts/resources/sp2_parse_cache.gd")
const LARGE = preload("res://tests/sp2_parse_cache_test.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")

func run() -> void:
	token_count = 32
	var directory: String = "user://cold_bank_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var data: Dictionary = fixture(directory)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data.path))
	var member: String = "Sprite/%d-0.sp2" % ACTOR
	write_bytes(data.raw,LARGE.build(8,200,31,0))
	manifest.members[member].sha256 = FileAccess.get_sha256(data.raw)
	manifest.members[member].bytes = FileAccess.get_size(data.raw)
	data.sha = write_json(data.path,manifest)
	CACHE.reset_for_test(directory.path_join("parse-cache"))
	ASSETS.reset_for_tests()
	BANK.forget_verified_members()
	var rows: Array = []
	var signature: String = ""
	for state: String in ["cold", "shared_warm", "disk_warm"]:
		if state == "disk_warm": ASSETS.reset_for_tests()
		HITCH._details.clear()
		HITCH._counters.clear()
		var preview := PREVIEW.new()
		var start: int = Time.get_ticks_usec()
		var configured: bool = preview.configure_reference_bank(data.path,data.sha,ACTOR,CORE_BINDINGS,CORE_LOOPS,"idle")
		var configure_us: int = Time.get_ticks_usec() - start
		var preparation: Dictionary = {"details":HITCH._details.duplicate(true),"counters":HITCH._counters.duplicate(true)}
		HITCH._details.clear()
		HITCH._counters.clear()
		start = Time.get_ticks_usec()
		var shown: bool = configured and preview.advance_reference_source(0.0,"idle",0)
		var first_frame_us: int = Time.get_ticks_usec() - start
		var drawing: Dictionary = {"details":HITCH._details.duplicate(true),"counters":HITCH._counters.duplicate(true)}
		var current: String = var_to_str(preview._playback_tracks).sha256_text()
		if signature.is_empty(): signature = current
		check(configured and shown and current == signature, "cold/warm exact tracks and initial frame: " + state)
		rows.append({"state":state,"configure_us":configure_us,"first_frame_us":first_frame_us,"preparation":preparation,"drawing":drawing,"cache_hits_cumulative":CACHE.hits,"cache_misses_cumulative":CACHE.misses,"asset_status":ASSETS.stats(),"tracks_sha256":current})
		preview.free()
	var result: Dictionary = {"engine":Engine.get_version_info().string,"synthetic_only":true,"android_measured":false,"body_bytes":FileAccess.get_size(data.raw),"body_sha256":FileAccess.get_sha256(data.raw),"action_bytes":data.action_bytes,"rows":rows,"failures":failures,"scope":"Diagnostic reference preview; excludes NPC admission, pool, map/physics, actual GPU upload and full original manifest bake."}
	var path: String = "user://cold_bank_result.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): path = argument.trim_prefix("--output=")
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"  ")); file.close()
	print("SP2_COLD_BANK_BENCHMARK " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
