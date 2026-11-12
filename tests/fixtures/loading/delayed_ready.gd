extends Node
## Synthetic readiness contract: no original resources or game save writes.
## Awaiting SceneTree frames also works while the loader owns the pause.
var waiting_frames: int = 0
var ready_gate: bool = false
var reject: bool = false

func _ready() -> void:
	reject = OS.get_environment("TWILIGHT_LOADING_TEST_REJECT_READY") == "1"
	_settle.call_deferred()

func _settle() -> void:
	for index: int in 8:
		await get_tree().process_frame
		waiting_frames += 1
	ready_gate = OS.get_environment("TWILIGHT_LOADING_TEST_NEVER_READY") != "1"

func loading_readiness() -> Dictionary:
	return {"ready": ready_gate and not reject, "failed": ready_gate and reject,
		"reason": "synthetic_readiness_rejection" if reject else ""}
