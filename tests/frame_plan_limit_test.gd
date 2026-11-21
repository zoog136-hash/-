extends SceneTree
## Frame plans hold their frame's layer textures; town NPC previews keep only a
## short loop of them (523.652 town: app memory 2,158 MB and still growing).
##   godot --headless --path <repo> --script res://tests/frame_plan_limit_test.gd
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const BODIES = preload("res://scripts/npc/source523_town_npc_bodies.gd")
const FOLLOWER = preload("res://scripts/animation/follower_motion.gd")
const RELIC = preload("res://scripts/animation/relic_motion.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FRAME_PLAN_LIMIT_FAIL: " + label)

func _initialize() -> void:
	var preview = PREVIEW.new()
	check(preview.frame_plan_max == PREVIEW.FRAME_PLAN_MAX, "field actors keep the full plan count")
	preview.free()
	check(BODIES.TOWN_FRAME_PLANS > 0 and BODIES.TOWN_FRAME_PLANS <= 32, "town NPCs keep a short loop of plans")
	var bodies: String = FileAccess.get_file_as_string("res://scripts/npc/source523_town_npc_bodies.gd")
	check(bodies.contains("preview.frame_plan_max = TOWN_FRAME_PLANS"), "town NPC previews use the short limit")
	var source: String = FileAccess.get_file_as_string("res://scripts/animation/original_source_preview.gd")
	check(source.contains("while _frame_plans.size() >= maxi(1, frame_plan_max):") and not source.contains("while _frame_plans.size() >= FRAME_PLAN_MAX:"), "plan eviction follows the preview's own limit")
	check(source.contains("child.frame_plan_max = frame_plan_max"), "independent source children inherit the limit")
	for owner: RefCounted in [FOLLOWER.new(), RELIC.new()]:
		check(owner.native_actor.cached_frames and owner.native_actor.frame_plan_max == 16 and not owner.native_actor._compose_frame_groups, "equipped companion uses a bounded node-only plan")
	print("FRAME_PLAN_LIMIT_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
