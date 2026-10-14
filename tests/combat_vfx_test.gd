extends SceneTree

const VFX = preload("res://scripts/animation/combat_vfx.gd")
var failures: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		print("VFX FAIL: " + detail)

func _run() -> void:
	var fx: TwilightCombatVFX = VFX.new()
	root.add_child(fx)
	await process_frame
	var node_count: int = root.get_child_count()
	for i: int in range(1500):
		fx.impact(Vector2(i % 200, 200), Vector2.RIGHT, "slash", i % 3 == 0)
		fx.number(Vector2(100, 180), "321", Color.WHITE, i % 3 == 0)
	check(fx.active.size() == VFX.CAPACITY and fx.high_water == VFX.CAPACITY, "unbounded effect records")
	check(root.get_child_count() == node_count and fx.get_child_count() == 0, "per-hit node allocations")
	fx._process(2.0)
	check(fx.active.is_empty() and fx.available.size() == VFX.CAPACITY, "effect lifetime leaked records")
	check(not fx.is_processing(), "idle effect system consumes frames")
	fx.impact(Vector2.ZERO, Vector2.RIGHT, "magic")
	fx.clear()
	check(fx.active.is_empty() and fx.available.size() == VFX.CAPACITY, "map transition fails to return records")
	# The actual authored death lasts .65s. The former fixed .4s playback
	# skipped phase 0/1 at the .14s render intervals seen in real Main captures.
	var corpse_frames: SpriteFrames = load("res://assets/actors/eight_direction/original_based/spear_captain/SpriteFrames.tres")
	var corpse_texture: Texture2D = corpse_frames.get_frame_texture("death_0", 0)
	fx.death_pose(Vector2.ZERO, corpse_texture, Vector2.ONE, Vector2.ZERO, corpse_frames, "death_0")
	var corpse: Dictionary = fx.active.back()
	check(is_equal_approx(float(corpse.get("pose_duration", float(corpse.duration) * .5)), .65), "corpse discarded source animation duration")
	for sample: Array in [[.14, 0], [.14, 1], [.17, 2]]:
		fx._process(float(sample[0]))
		var progress: float = float(corpse.age) / float(corpse.get("pose_duration", float(corpse.duration) * .5))
		check(VFX._death_frame(corpse_frames, "death_0", progress) == int(sample[1]), "corpse skipped an authored phase at measured render cadence")
		check(VFX._death_frame_at_age(corpse) == int(sample[1]), "draw path differs from the real source timeline")
	check(is_equal_approx(float(corpse.duration), .8), "short authored corpse changed the existing fade lifetime")
	fx._process(.36)
	check(corpse.is_empty() and fx.active.is_empty(), "authored corpse did not return its pool record")
	# Reuse real textures only as a test fixture for unequal frame durations.
	# A longer track must finish before the pooled corpse is removed.
	var weighted: SpriteFrames = corpse_frames.duplicate() as SpriteFrames
	weighted.set_animation_speed("death_0", 4.0)
	for index: int in range(3):
		weighted.set_frame("death_0", index, corpse_frames.get_frame_texture("death_0", index), [2.0, 1.0, 3.0][index])
	fx.death_pose(Vector2.ZERO, corpse_texture, Vector2.ONE, Vector2.ZERO, weighted, "death_0")
	var slow: Dictionary = fx.active.back()
	check(is_equal_approx(float(slow.pose_duration), 1.5) and is_equal_approx(float(slow.duration), 1.65), "long weighted corpse truncated its source timing")
	for sample: Array in [[.45, 0], [.15, 1], [.30, 2]]:
		fx._process(float(sample[0]))
		check(VFX._death_frame_at_age(slow) == int(sample[1]), "weighted corpse phase lost its declared duration")
	fx._process(.61)
	check(not slow.is_empty(), "long corpse vanished before its final hold")
	fx._process(.20)
	check(slow.is_empty() and fx.available.size() == VFX.CAPACITY, "long corpse failed to expire and return its pool record")
	fx.queue_free()
	await process_frame
	if failures == 0: print("COMBAT_VFX_OK stress=3000 pool=160 per_hit_nodes=0")
	quit(0 if failures == 0 else 1)
