extends SceneTree

# Fix only attacker accuracy to keep both attack kinds away from probability
# clamps. Exercise production World/Service/Catalog/Status code without a map.
class AccuracyWorld extends TwilightWorld:
	func _melee_accuracy_stat() -> int: return 90
	func _ranged_accuracy_stat() -> int: return 60

var checks := 0
var failures: Array[String] = []
var world: TwilightWorld
var target: TwilightMonster

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("NORMAL_ATTACK_STATUS_HIT_FAIL: ", message)

func compare(ac: int, dg: int, context: String) -> void:
	for kind: String in ["melee", "ranged"]:
		var accuracy := 90 if kind == "melee" else 60
		var expected := world._physical_hit_chance(accuracy, ac, dg)
		check(is_equal_approx(world._normal_attack_hit_chance(target, kind), expected), context + " normal " + kind)
		if world.original_skills != null:
			check(is_equal_approx(world.original_skills.hit_chance({"attack_type":kind}, target), expected), context + " skill " + kind)

func run() -> void:
	world = AccuracyWorld.new()
	target = TwilightMonster.new()
	target.armor_class = -100
	compare(-100, 0, "no service")
	check(world._normal_attack_hit_chance(null, "melee") == .05, "null target unchanged")
	world.job_class = "뇌신"
	world.original_skills = TwilightOriginalSkillService.new()
	world.original_skills.configure(world)
	var service := world.original_skills
	var status := service.status
	compare(-100, 0, "no modifier")
	var mark := service.catalog.record_for("썬더 마크")
	check(str(mark.id) == "lm_06640b26b09a5bc8" and mark.mode == "mark", "real catalog mark")
	service.catalog.learned[str(mark.id)] = 1
	# Deterministic proc scheduling; keep the actual runtime modifier producer.
	mark["proc_chance"] = 1.0
	mark["proc_cooldown"] = 0.0
	service.trigger("on_hit", target)
	check(status.modifier(target, "ac") == 5 and status.modifier(target, "dg") == -3, "real first mark values")
	compare(-95, -3, "first mark")
	service.trigger("on_hit", target)
	check(status.modifier(target, "ac") == 10, "real second mark AC")
	compare(-90, -6, "second mark")
	status.set_modifiers(target, "unrelated", 20, {"reduction":-3})
	status.remove_modifiers(target, "mark:" + str(mark.id))
	compare(-100, 0, "mark source removed")
	check(status.modifier(target, "reduction") == -3, "source removal preserves unrelated effect")
	service.marks.clear()
	service.trigger("on_hit", target)
	status.tick(10.1)
	compare(-100, 0, "mark expired")
	check(status.modifier(target, "reduction") == -3, "expiry preserves longer source")
	service.marks.clear()
	service.trigger("on_hit", target)
	target.life_id += 1
	compare(-100, 0, "new pooled life")
	check(status.debuffs.is_empty(), "old-life modifiers discarded")
	service.trigger("on_hit", target)
	target.dead = true
	compare(-100, 0, "dead target modifiers discarded")
	target.dead = false
	service.marks.clear()
	service.trigger("on_hit", target)
	service.clear()
	compare(-100, 0, "combat service cleared")
	# Excalibur's real negative DG remains floored at zero by the current
	# formula. This consistency fix does not claim to rebalance that skill.
	var excalibur := service.catalog.resolve(service.catalog.record_for("lm_4f90e0d7ce272c1f"))
	check(excalibur.debuff.size() == 1 and float(excalibur.debuff.get("dg", 0)) == -8, "real Excalibur DG data")
	status.set_modifiers(target, "excalibur", 3.5, excalibur.debuff)
	compare(-100, 0, "negative DG floor preserved")
	status.clear()
	# Positive DG is a controlled contract fixture, not a current monster buff.
	status.set_modifiers(target, "fixture", 1, {"dg":8})
	compare(-100, 8, "positive avoidance contract")
	status.tick(1.1)
	compare(-100, 0, "avoidance fixture expired")
	for ac: int in [-300, -100, -20, 0, 20, 100]:
		target.armor_class = ac
		compare(ac, 0, "unmodified AC %d" % ac)
	target.free()
	world.free()
	if failures.is_empty(): print("NORMAL_ATTACK_STATUS_HIT_OK checks=", checks)
	quit(0 if failures.is_empty() else 1)
