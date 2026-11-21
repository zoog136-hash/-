extends SceneTree

class SaveWorld extends TwilightWorld:
	var save_attempts: int = 0
	var saved_gold: int = -1
	var worker_busy: bool = false
	var worker_finished: bool = false

	func background_save_pending() -> bool:
		return worker_busy

	func _finish_background_save(wait: bool) -> void:
		if wait or worker_finished: worker_busy = false

	func _save_game(_quiet: bool, _collection_override: Dictionary = {}, _movement_override: Dictionary = {}, _validate_only: bool = false, background: bool = false) -> Error:
		save_attempts += 1
		saved_gold = gold
		assert(background)
		return OK

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := SaveWorld.new()
	world.gold = 100
	world.deferred_save.request()
	world._tick_automatic_save(world.deferred_save.interval)
	world._request_general_save()
	check(world.save_attempts == 0 and world.general_save_pending, "two timers share a deferred reservation")
	await process_frame
	check(world.save_attempts == 1 and not world.general_save_pending, "two timers trigger one save")

	# A writer may start between scheduling the callback and its execution.
	world._request_general_save()
	world.worker_busy = true
	await process_frame
	check(world.save_attempts == 1 and world.general_save_pending, "scheduled save does no work if a writer is busy")
	world.gold = 200
	world.deferred_save.request()
	world._tick_automatic_save(world.deferred_save.interval)
	world._request_general_save()
	await process_frame
	check(world.save_attempts == 1 and world.general_save_pending, "timer expiry and further requests remain pending without waiting")
	world.gold = 300
	world.worker_finished = true
	world._tick_automatic_save(0.0)
	await process_frame
	check(world.save_attempts == 2 and world.saved_gold == 300 and not world.general_save_pending, "worker completion saves the latest state once")
	world._tick_automatic_save(0.0)
	await process_frame
	check(world.save_attempts == 2, "no extra save without a reservation")
	world.free()
	print("AUTOMATIC_SAVE_SCHEDULE_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
