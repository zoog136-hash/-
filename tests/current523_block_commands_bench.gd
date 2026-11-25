extends SceneTree
## Optional headless CPU A/B. Pass --baseline-renderer=<base renderer .gd>.
## Each side assembles the same worker job, including signed block boundaries,
## unavailable tiles, missing subimages and multiple members sharing a layer.
const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")

class Tiles extends RefCounted:
	func has_tile(id: int) -> bool: return id >= 1 and id <= 8
	func has_subimage(_id: int, frame: int) -> bool: return frame != 255

func _initialize() -> void: run.call_deferred()

func input_for(members: int, rows: int, blank: bool) -> Array:
	var inputs: Array = []
	for member: int in members:
		var lane := PackedInt64Array()
		var indices := PackedInt32Array()
		for i: int in rows:
			var ref: int = ((1 + i % 9) << 8) | ((i * 7 + member) & 255)
			if blank or (i + member) % 19 == 0: ref = 4294967295
			lane.append((i * 17 + member * 7) % 535 - 535)
			lane.append(i * 11 % 535 - 535)
			lane.append(ref)
			indices.append(i * 3)
		inputs.append([{-2:lane, 3:lane}, {-2:indices, 3:indices}])
	return inputs

static func measure(play: Script, job: Dictionary, sample: Dictionary) -> void:
	var began: int = Time.get_ticks_usec()
	for repeat: int in 6: play._block_job(job)
	sample["usec"] = (Time.get_ticks_usec() - began) / 6.0

func run() -> void:
	var baseline: Script
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-renderer="):
			baseline = load(arg.trim_prefix("--baseline-renderer="))
	if baseline == null:
		printerr("Pass --baseline-renderer=<renderer extracted from the base revision>.")
		quit(1)
		return
	var tiles := Tiles.new()
	for workload: Array in [[1,128,false], [1,2048,false], [8,256,false], [48,32,false], [3,2048,false], [6,256,true]]:
		var inputs: Array = input_for(workload[0],workload[1],workload[2])
		var samples: Array = [[],[]]
		for pair: int in 15:
			var outputs: Array = [{},{}]
			for index: int in 2:
				var side: int = (index + pair) % 2
				var job := {"cell":Vector2i(-1,-1),"tiles":tiles,"has_subimage":true,"inputs":inputs,"include_objects":true}
				var sample: Dictionary = {}
				var task: int = WorkerThreadPool.add_task(measure.bind(baseline if side == 0 else PLAY,job,sample))
				# Dedicated benchmark. The timer is inside the worker, excluding dispatch and join.
				WorkerThreadPool.wait_for_task_completion(task)
				if not job.has("result") or not sample.has("usec"):
					printerr("Incomplete worker sample ",workload)
					quit(1)
					return
				outputs[side] = job.result
				if pair > 0: samples[side].append(sample.usec)
			if outputs[0] != outputs[1] or outputs[0].commands.keys() != outputs[1].commands.keys():
				printerr("Worker output differs ",workload)
				quit(1)
				return
		print("BLOCK_COMMAND_PAIRS ",JSON.stringify({"members":workload[0],"records":int(workload[0])*int(workload[1])*2,
			"blank":workload[2],"usec":samples}))
	print("BLOCK_COMMAND_BENCH_OK")
	quit()
