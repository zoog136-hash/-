extends SceneTree

const FX = preload("res://scripts/animation/potion_feedback.gd")
var failures: int = 0
var checks: int = 0

class TestWorld extends Node:
	var hp: int = 100
	var combat_generation: int = 0
	var presentation_settings: Dictionary = {"impact_intensity":0.85, "reduced_motion":false, "effect_detail":"full"}

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("POTION_FEEDBACK FAIL: " + detail)

func _run() -> void:
	check(FX.channel_for("HP 물약", "hp") == "health", "red HP")
	check(FX.channel_for("고급 체력 회복제 (각인)", "hp") == "health_high", "amber advanced HP")
	check(FX.channel_for("강력 HP 물약", "hp") == "health_strong", "bright strong HP")
	check(FX.channel_for("마나 회복 물약 (각인)", "timed") == "mana", "blue timed mana")
	check(FX.channel_for("마녀의 마력 회복제", "instant_mp") == "mana", "blue instant MP")
	check(FX.channel_for("초록 물약", "timed") == "haste", "green haste")
	check(FX.channel_for("용기의 물약", "timed") == "brave", "gold bravery")
	for name_value: String in ["전투 강화의 주문서", "힘센 한우 스테이크", "드래곤의 다이아몬드", "귀환 주문서"]:
		check(FX.channel_for(name_value, "timed").is_empty(), "no potion art for " + name_value)
	var world: TestWorld = TestWorld.new()
	var actor: Node2D = Node2D.new()
	var fx: TwilightPotionFeedback = FX.new()
	root.add_child(world)
	world.add_child(actor)
	actor.add_child(fx)
	fx.setup(world, actor)
	check(not fx.is_processing(), "idle renderer sleeps")
	check(not fx.play("unknown") and fx.active.is_empty(), "unknown channel ignored")
	check(fx.play("health") and fx.active.size() == 1, "valid use shows one light")
	var texture: ImageTexture = fx.light.glow
	check(texture != null, "shared texture prepared")
	seed(20261021)
	var expected: int = randi()
	seed(20261021)
	for i: int in range(1000): fx.play("health")
	check(randi() == expected, "no gameplay RNG consumption")
	check(fx.active.size() == 1 and fx.get_child_count() == 0, "no per-use nodes or stacked identical lights")
	check(fx.light.glow == texture, "cached texture retained")
	for channel: String in FX.COLORS:
		fx.play(channel)
		check(fx.active.size() <= FX.CAPACITY, "bounded simultaneous colors")
	fx._process(FX.LIFETIME + 0.01)
	check(fx.active.is_empty() and not fx.is_processing(), "lifetime clears and sleeps")
	fx.play("health")
	fx._process(-1.0)
	check(is_zero_approx(float(fx.active[0].age)), "negative delta cannot rewind")
	actor.position += Vector2(8, 0)
	fx._process(0.02)
	check(fx.active.size() == 1 and fx.get_parent() == actor, "ordinary movement follows actor")
	world.combat_generation += 1
	fx._process(0.01)
	check(fx.active.is_empty(), "map/load/death generation clears")
	fx.play("mana")
	actor.position += Vector2(300, 0)
	fx._process(0.01)
	check(fx.active.is_empty(), "teleport cannot carry stale glow")
	world.hp = 0
	check(not fx.play("health"), "dead actor cannot emit")
	world.hp = 100
	fx.play("health")
	fx.clear()
	fx.clear()
	check(fx.active.is_empty() and not fx.is_processing(), "clear is idempotent")
	check(world.hp == 100 and world.combat_generation == 1, "presentation does not change gameplay state")
	world.queue_free()
	await process_frame
	check(not is_instance_valid(fx), "renderer freed with actor")
	if failures == 0: print("POTION_FEEDBACK_OK checks=%d stress=1000" % checks)
	quit(0 if failures == 0 else 1)
