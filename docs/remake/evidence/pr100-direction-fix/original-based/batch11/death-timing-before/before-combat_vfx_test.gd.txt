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
	fx.queue_free()
	await process_frame
	if failures == 0: print("COMBAT_VFX_OK stress=3000 pool=160 per_hit_nodes=0")
	quit(0 if failures == 0 else 1)
