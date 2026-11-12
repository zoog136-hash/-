extends RefCounted
## One sequential metadata verification. Main/GL scene loading stays on the
## main thread. The caller must join before loading/using these pack readers,
## starting another job or leaving the loading screen.
##
## The worker callable is static and owns only an immutable step copy; it
## never retains this job, a Node, a scene or a caller-supplied callable.
## Resource scripts are preloaded before Thread.start(), on the main thread.
const PREBAKE = preload("res://scripts/boot/source523_prebake.gd")
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")
var _thread: Thread
var _id: String = ""
var _result: Dictionary = {}

## A launch error leaves no started thread. The caller can announce a
## synchronous fallback, then call PREBAKE.run_result(step) on the main thread.
func start(step: Dictionary) -> Error:
	if _thread != null and _thread.is_started(): return ERR_BUSY
	if not PREBAKE.valid_step(step): return ERR_INVALID_PARAMETER
	_id = str(step.id)
	_result = {}
	_thread = Thread.new()
	var error: Error = _thread.start(PREBAKE.run_result.bind(step.duplicate(true)))
	if error != OK: _thread = null
	return error

## Poll from the main thread. Progress is a completed verification item, never
## an elapsed-time estimate. BOOT_LOG.current_stage() takes its own mutex.
func poll() -> Dictionary:
	if _thread != null and _thread.is_started() and not _thread.is_alive(): finish()
	var state: String = "complete" if not _result.is_empty() else ("running" if _thread != null and _thread.is_started() else "idle")
	var value: Dictionary = _result.duplicate(true)
	value["state"] = state
	value["id"] = _id
	value["stage"] = BOOT_LOG.current_stage() if state == "running" else ""
	return value

func completed() -> bool:
	return poll().state == "complete"

func result() -> Dictionary:
	poll()
	return _result.duplicate(true)

## Safe shutdown/cancel boundary: finish the current atomic verification and
## join it; do not terminate during cache writes. Boot may then stop without
## entering the game. A killed process is handled by the existing .part and
## pinned-cache validation on its next launch.
func finish() -> Dictionary:
	if _thread != null and _thread.is_started():
		var value: Variant = _thread.wait_to_finish()
		_result = value if value is Dictionary else {"id":_id, "ok":false, "baked":false, "ms":0, "reason":"worker_result"}
		_thread = null
	return _result.duplicate(true)

func _notification(what: int) -> void:
	# RefCounted may not call its own methods during PREDELETE. Join directly;
	# the static worker never needs this object or the main thread to finish.
	if what == NOTIFICATION_PREDELETE and _thread != null and _thread.is_started():
		_thread.wait_to_finish()
