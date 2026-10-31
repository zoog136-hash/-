extends SceneTree

# A slot whose spawn search keeps failing backs off (2, 4, 8 ... 60 s, +/-20%
# jitter) instead of re-running the full search every 2 s.
const POPULATION = preload("res://scripts/maps/field_population.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("SPAWN_RETRY_BACKOFF_FAIL: ", label)

func _initialize() -> void:
	var population = POPULATION.new()
	population.retry_jitter.seed = 7
	var slot: Dictionary = {}
	var delays: Array[float] = []
	for i: int in range(8): delays.append(population._spawn_retry_delay(slot))
	var expected: Array[float] = [2.0, 4.0, 8.0, 16.0, 32.0, 60.0, 60.0, 60.0]
	for i: int in range(expected.size()):
		check(delays[i] >= expected[i] * 0.8 - 0.001 and delays[i] <= expected[i] * 1.2 + 0.001, "retry %d near %.0f s (got %.2f)" % [i + 1, expected[i], delays[i]])
	check(int(slot.spawn_failures) == 8, "failures are counted on the slot")
	var other: Dictionary = {}
	var spread: Dictionary = {}
	for i: int in range(20):
		other.spawn_failures = 0
		spread[snappedf(population._spawn_retry_delay(other), 0.01)] = true
	check(spread.size() > 5, "first retries are jittered so failing slots do not line up")
	population.free()
	print("SPAWN_RETRY_BACKOFF_RESULT ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
