extends SceneTree
## Seed-for-seed comparison with the prior eager roll. Tests both an empty
## exact-source candidate list and a full list (including sized RNG picks).
const LOOT = preload("res://scripts/loot_drop.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
var calls: int = 0
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition and failures.size() < 12: failures.append(label)

func baseline(groups: Dictionary, is_boss: bool, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	if rng.randf() < (LOOT.BOSS_POTION_RATE if is_boss else LOOT.NORMAL_POTION_RATE):
		var potion: Dictionary = DROPS.pick(groups,"potion","",rng)
		if not potion.is_empty(): earned.append(potion)
	for attempt: int in range(LOOT.MAX_BOSS_EQUIPMENT_ROLLS if is_boss else 1):
		var grade: String = LOOT._roll_equipment_grade(is_boss,rng)
		if grade.is_empty(): continue
		var gear: Dictionary = DROPS.pick(groups,"equipment",grade,rng)
		if not gear.is_empty(): earned.append(gear)
	if rng.randf() < (LOOT.BOSS_MATERIAL_DROP_RATE if is_boss else LOOT.MATERIAL_DROP_RATE):
		var material: Dictionary = DROPS.pick(groups,"material","",rng)
		if not material.is_empty(): earned.append(material)
	if rng.randf() < (LOOT.BOSS_MATERIAL_DROP_RATE if is_boss else LOOT.MATERIAL_DROP_RATE):
		var currency: Dictionary = DROPS.pick(groups,"currency","",rng)
		if not currency.is_empty(): earned.append(currency)
	return earned

func groups_fixture() -> Dictionary:
	var groups: Dictionary = {}
	for kind: String in ["potion","material","currency","equipment"]:
		for grade: String in LOOT.EQUIPMENT_GRADES:
			for index: int in range(2):
				var id: int = groups.size()+1
				var item := {"name":"fixture_%d" % id,"grade":grade}
				var variants: Dictionary = {}
				for bless: int in [1,2,3]:
					variants["%d:0" % bless] = {"bless_state":str(bless),"bless_raw":bless,"variant_record":item}
				groups[str(id)]={"kind":kind,"item_class_id":id,"item":item,"variants":variants}
	return groups

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var seeded_groups: Dictionary = groups_fixture()
	var skipped: int = 0
	var sampled: int = 0
	for is_boss: bool in [false,true]:
		for groups: Dictionary in [seeded_groups,{}]:
			var before := RandomNumberGenerator.new()
			var after := RandomNumberGenerator.new()
			for seed_value: int in range(1500):
				before.seed = seed_value
				after.seed = seed_value
				calls = 0
				var provider := func() -> Dictionary:
					calls += 1
					return groups
				var old: Array[Dictionary] = baseline(groups,is_boss,before)
				var revised: Array[Dictionary] = LOOT.roll_patch523_lazy(provider,is_boss,after)
				check(old == revised and before.state == after.state,"roll outputs or RNG changed at seed %d" % seed_value)
				check(calls <= 1 and (old.is_empty() or calls == 1),"provider invoked more than once or skipped a pick")
				if not is_boss and not groups.is_empty():
					sampled += 1
					if calls == 0: skipped += 1
	check(skipped > 0 and skipped < sampled,"ordinary loot-free kills avoided source resolution")
	print("DROP_HOTPATH_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"ordinary_skip":skipped,"ordinary_sampled":sampled}))
	quit(0 if failures.is_empty() else 1)
