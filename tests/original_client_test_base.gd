extends SceneTree
## Shared helpers for the original-client contract acceptance tests. A test script
## extends this file, implements run(), and ends by calling finish().
var results: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	finish("ORIGINAL_CLIENT_UNIMPLEMENTED_RESULT")

func check(test_id: String, condition: bool, detail: String = "") -> void:
	var entry: Dictionary = results.get(test_id, {"pass": true, "details": []})
	if not condition:
		entry["pass"] = false
		(entry["details"] as Array).append(detail)
	results[test_id] = entry

func finish(marker: String, extra: Dictionary = {}) -> void:
	var failures: Array = []
	for id: String in results:
		if not results[id].pass:
			failures.append({"test": id, "details": results[id].details})
	var report := {"target_binary_executed": false, "executed": results.size(), "failures": failures, "tests": results}
	report.merge(extra, true)
	print(marker, " ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
