extends SceneTree
## Town NPC idle bodies advance a bounded number per frame and keep their
## skipped time (523.607: town_npc_bodies 541 ms per second on the phone).
##   godot --headless --path <repo> --script res://tests/town_npc_advance_budget_test.gd
const BODIES = preload("res://scripts/npc/source523_town_npc_bodies.gd")
var checks: int = 0
var failures: Array[String] = []

class StubPreview extends Node:
	var calls: int = 0
	var received: float = 0.0
	func advance_reference_source(delta: float, _role: String, _direction: int) -> bool:
		calls += 1
		received += delta
		return true

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("TOWN_NPC_ADVANCE_FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var bodies: Node2D = BODIES.new()
	root.add_child(bodies)
	var previews: Array[StubPreview] = []
	for index: int in 20:
		var holder := Node2D.new()
		var preview := StubPreview.new()
		holder.add_child(preview)
		holder.set_meta("preview", preview)
		holder.set_meta("role", "idle")
		holder.set_meta("direction", 4)
		bodies.add_child(holder)
		bodies._register_body("npc:%d" % index,holder)
		previews.append(preview)
	var frames: int = 30
	var step: float = 1.0 / 30.0
	var max_per_frame: int = 0
	var advance_frames: int = 0
	for frame: int in frames:
		var before: int = 0
		for p: StubPreview in previews: before += p.calls
		if Engine.get_process_frames() % BODIES.ADVANCE_EVERY_FRAMES == 0: advance_frames += 1
		bodies._advance_bodies(step)
		await process_frame
		var after: int = 0
		for p: StubPreview in previews: after += p.calls
		max_per_frame = maxi(max_per_frame, after - before)
	check(max_per_frame <= BODIES.ADVANCES_PER_FRAME, "at most %d advances per frame (%d)" % [BODIES.ADVANCES_PER_FRAME, max_per_frame])
	var total_calls: int = 0
	for p: StubPreview in previews: total_calls += p.calls
	check(total_calls <= advance_frames * BODIES.ADVANCES_PER_FRAME and advance_frames < frames, "advances happen only on every %d-th frame (%d calls over %d of %d frames)" % [BODIES.ADVANCE_EVERY_FRAMES, total_calls, advance_frames, frames])
	var every_body_moved: bool = true
	for p: StubPreview in previews: every_body_moved = every_body_moved and p.calls > 0
	check(every_body_moved, "every near body is advanced in turn")
	var total_time: float = 0.0
	for index: int in previews.size():
		var holder: Node = bodies.bodies["npc:%d" % index]
		total_time += previews[index].received + bodies._pending_idle(holder)
	check(is_equal_approx(total_time, frames * step * previews.size()), "no animation time is lost (%.4f)" % total_time)
	print("TOWN_NPC_ADVANCE_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "max_per_frame": max_per_frame}))
	quit(0 if failures.is_empty() else 1)
