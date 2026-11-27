extends RefCounted
## A count of finished boot work, not a prediction of elapsed/remaining time.
## Each selected pack verification and each scene handoff milestone is one
## item. Unmeasurable work keeps the last count and an honest status label.
const SCENE_TASKS := ["scene_load", "scene_change", "scene_ready"]
var _tasks: Array[String] = []
var _labels: Dictionary = {}
var _done: Dictionary = {}
var _current: String = ""
var _status: String = ""
var _failed: bool = false
var _scene_done: int = 0
var _scene_total: int = 0

## Also resets a failed attempt. Completed work is counted afresh on retry;
## callers may supply the current pending() list (valid device bakes skip work).
func configure(steps: Array[Dictionary]) -> void:
	_tasks.clear()
	_labels.clear()
	_done.clear()
	_current = ""
	_status = ""
	_failed = false
	_scene_done = 0
	_scene_total = 0
	for step: Dictionary in steps:
		var id: String = str(step.get("id", ""))
		if id.is_empty() or id in SCENE_TASKS or _labels.has(id): continue
		_tasks.append(id)
		_labels[id] = str(step.get("label", id))
	for id: String in SCENE_TASKS:
		_tasks.append(id)
		_labels[id] = id

## Beginning a task changes only its status. It never advances the count.
## Scene milestones must follow every earlier item, including verification.
func begin_task(id: String, label: String = "") -> bool:
	if _failed or not _labels.has(id) or _done.has(id): return false
	if not _current.is_empty() and _current != id: return false
	if id in SCENE_TASKS:
		for preceding: String in _tasks:
			if preceding == id: break
			if not _done.has(preceding): return false
	_current = id
	_status = str(_labels[id]) if label.is_empty() else label
	return true

## Call only after the underlying operation has succeeded. Duplicate, failed
## or unbegun completion is rejected. Time and render frames are never inputs.
func complete_task(id: String) -> bool:
	if _failed or _current != id or not _labels.has(id) or _done.has(id): return false
	_done[id] = true
	_current = ""
	return true

## A scene can report completed initialization steps inside its readiness
## task. Its final step completes only when the scene reports ready.
func observe_scene_work(completed: int, total: int, status: String) -> bool:
	if _failed or _current != "scene_ready" or total < 2 or completed < _scene_done or completed >= total: return false
	if _scene_total != 0 and total != _scene_total: return false
	if completed == _scene_done and total == _scene_total and status == _status: return false
	_scene_done = completed
	_scene_total = total
	_status = status
	return true

func fail_task(message: String) -> void:
	_failed = true
	_status = message

func snapshot() -> Dictionary:
	var total: int = _tasks.size()
	var ready: bool = not _failed and _done.has("scene_ready") and _done.size() == total and total > 0
	var scene_fraction: float = float(_scene_done) / _scene_total if not ready and _scene_total > 0 else 0.0
	var percent: int = int(floor(100.0 * (float(_done.size()) + scene_fraction) / total)) if total > 0 else 0
	return {"completed": _done.size(), "total": total, "percent": percent if ready else mini(percent, 99),
		"scene_completed": _scene_total if ready else _scene_done, "scene_total": _scene_total,
		"status": _status, "failed": _failed, "ready": ready, "current": _current}
