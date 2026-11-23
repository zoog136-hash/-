extends RefCounted
## Main-thread ownership of discarded S32 and draw-list jobs. These workers
## only access their input snapshots. Their outputs must never be published.
## Keep their data/resources alive until the pool has released the callable.
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const BACKLOG_LIMIT: int = 32
const REAP_LIMIT: int = 4
const REAP_BUDGET_USEC: int = 1000
static var _retired: Dictionary = {}

static func accept_new_work() -> bool:
	return _retired.size() < BACKLOG_LIMIT

static func retire(task: int, keepalive: Dictionary) -> void:
	_retired[task] = keepalive

static func pending_count() -> int:
	return _retired.size()

static func pump() -> void:
	if _retired.is_empty(): return
	var started: int = Time.get_ticks_usec()
	var reaped: int = 0
	for task: int in _retired.keys():
		if not WorkerThreadPool.is_task_completed(task): continue
		WorkerThreadPool.wait_for_task_completion(task)
		_retired.erase(task)
		reaped += 1
		if reaped >= REAP_LIMIT or Time.get_ticks_usec() - started >= REAP_BUDGET_USEC: break
	FRAME_HITCH.detail("map.retired_job_reap", started)

## Process teardown only. Do not call from map unload or app focus changes.
static func finish() -> void:
	for task: int in _retired:
		WorkerThreadPool.wait_for_task_completion(task)
	_retired.clear()
