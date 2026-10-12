extends SceneTree

const VFX = preload("res://scripts/animation/combat_vfx.gd")
const VISUALS = preload("res://scripts/animation/impact_visuals.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("HIT_FEEDBACK FAIL: " + detail)

func _run() -> void:
	var fx: TwilightCombatVFX = VFX.new()
	root.add_child(fx)
	await process_frame
	fx.set_process(false)
	var texture: ImageTexture = fx.visuals.glow
	fx.visuals.prepare()
	check(texture != null and fx.visuals.glow == texture, "glow texture must be cached")
	check(texture.get_size() == Vector2(48, 48), "bounded generated texture")
	var styles: Dictionary = {"slash":"slash", "melee":"slash", "thrust":"thrust", "heavy":"heavy", "bow":"arrow", "ranged":"arrow", "gun":"bullet", "magic":"magic", "staff":"magic", "poison":"poison", "bleed":"bleed", "unknown":"slash"}
	for style: String in styles:
		fx.impact(Vector2(200, 200), Vector2.ZERO, style, false)
		var entry: Dictionary = fx.active.back()
		check(str(entry.family) == str(styles[style]), "style routing " + style)
		check(not bool(entry.critical) and is_equal_approx(float(entry.duration), .22), "no synthetic crit " + style)
	fx.clear()
	fx.impact(Vector2.ZERO, Vector2.ONE, "magic", true)
	check(bool(fx.active.back().critical) and is_equal_approx(float(fx.active.back().duration), .30), "actual critical input preserved")
	check(is_equal_approx(VISUALS.core_envelope(0.0), 1.0), "immediate contact core")
	check(VISUALS.core_envelope(.02) > VISUALS.core_envelope(.04), "fast core decay")
	check(is_zero_approx(VISUALS.core_envelope(.065)), "no sustained white flash")
	check(VISUALS.number_scale(.035, true) > 1.2, "critical number punch")
	check(is_equal_approx(VISUALS.number_scale(.2, true), 1.0), "critical number settles")
	check(is_equal_approx(VISUALS.number_scale(.035, false), 1.0), "normal text does not pulse")
	for marker: float in [.1, .44, .7, .85]:
		check(is_equal_approx(VISUALS.swing_envelope(marker, marker), 1.0), "swing centered on existing marker")
		check(is_zero_approx(VISUALS.swing_envelope(marker - .17, marker)), "no early swing")
		check(is_zero_approx(VISUALS.swing_envelope(marker + .23, marker)), "no late swing")
	fx.clear()
	fx.number(Vector2(100, 100), "CRIT 321", Color.RED, true)
	check(str(fx.active.back().display) == "321" and bool(fx.active.back().caption), "separate critical heading")
	fx.number(Vector2(100, 100), "CRIT 322", Color.RED, true)
	check(not bool(fx.active.back().caption) and str(fx.active.back().display) == "322", "volley keeps damage but suppresses duplicate heading")
	fx.number(Vector2(500, 100), "CRIT 400", Color.RED, true)
	check(bool(fx.active.back().caption), "different target keeps its heading")
	fx._process(.12)
	fx.number(Vector2(100, 100), "CRIT 323", Color.RED, true)
	check(bool(fx.active.back().caption), "new strike can display heading")
	fx.number(Vector2.ZERO, "MISS", Color.GRAY, false)
	check(str(fx.active.back().display) == "MISS" and not bool(fx.active.back().caption), "MISS unchanged")
	fx.number(Vector2.ZERO, "+40", Color.GREEN, false)
	check(fx.active.back().color == Color.GREEN, "healing color unchanged")
	seed(81231)
	var expected: int = randi()
	seed(81231)
	var time_scale: float = Engine.time_scale
	for i: int in range(1500):
		fx.impact(Vector2(100, 100), Vector2.RIGHT, "slash", i % 3 == 0)
		fx.number(Vector2(100, 100), str(i), Color.WHITE, i % 3 == 0)
	check(randi() == expected, "visuals consumed gameplay RNG")
	check(Engine.time_scale == time_scale, "global time changed")
	check(fx.active.size() == 160 and fx.get_child_count() == 0, "pool or per-hit nodes regressed")
	check(fx.visuals.glow == texture, "stress rebuilt texture")
	fx._process(2.0)
	check(fx.active.is_empty() and fx.available.size() == 160, "pool not returned")
	check(not fx.is_processing(), "idle processing not disabled")
	fx.clear()
	fx.clear()
	check(fx.available.size() == 160, "clear not idempotent")
	fx.queue_free()
	await process_frame
	if failures == 0: print("HIT_FEEDBACK_OK checks=%d stress=3000 per_hit_nodes=0" % checks)
	quit(0 if failures == 0 else 1)
