extends "res://tests/benchmark_reference_sp2_attributes.gd"
## Invented SP2/action input only; elapsed setup work, not Android or FPS.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const PREPARED = preload("res://scripts/resources/reference_sp2_prepared_bank.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
func run() -> void:
	token_count = 128
	var data: Dictionary = fixture("user://view_layout_benchmark")
	var results: Array = []
	for round_index: int in 5:
		PREPARED.clear()
		var owners: Array = []
		for instance: int in 3:
			HITCH._details.clear()
			HITCH._counters.clear()
			var view := PREVIEW.new()
			var started: int = HITCH.now()
			var ready: bool = view._configure_reference_bank(data.path,data.sha,ACTOR,CORE_BINDINGS,CORE_LOOPS,"idle","npc")
			var elapsed: int = HITCH.now()-started
			check(ready,"view configures")
			var signature: Array = []
			for node: Node in view.get_children():
				signature.append([node.name,node.get_class(),node.get_meta("source_layer_id",-1),node.get_meta("compatibility_style",{})])
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(var_to_bytes(view._playback_tracks))
			results.append({"round":round_index,"instance":instance,"configure_usec":elapsed,"details_usec":HITCH._details.duplicate(true),"counters":HITCH._counters.duplicate(),"node_signature":signature,"tracks_sha256":hash.finish().hex_encode()})
			owners.append(view)
		for view: Node in owners: view.free()
	var result: Dictionary = {"fixture":"synthetic 5 roles x 8 directions x 128 tokens; 3 tiny SP2 members","results":results,"failures":failures,"scope":"headless Linux view preparation; first prepared metadata and live snapshot reuse, not original input, disk-cold device timing, whole spawn or FPS"}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var file := FileAccess.open(argument.trim_prefix("--output="),FileAccess.WRITE)
			file.store_string(JSON.stringify(result))
	print("SOURCE_VIEW_LAYOUT_BENCHMARK ",JSON.stringify({"failures":failures,"cases":results.size()}))
	quit(0 if failures.is_empty() else 1)
