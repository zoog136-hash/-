extends SceneTree

const OPTIONS = preload("res://scripts/item_options.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("WEAPON_SIZE_DAMAGE_FAIL: " + label)

func _run() -> void:
	var test_weapon: Dictionary = {"name":"검증용 무기", "slot":"weapon", "type":"한손검",
		"stat":"10/20", "atk":13, "desc":"10/20 · 추가 대미지 +3"}
	check(OPTIONS.weapon_size_damage(test_weapon, false) == 10, "10/20 small = 10")
	check(OPTIONS.weapon_size_damage(test_weapon, true) == 20, "10/20 large = 20")
	check(OPTIONS.weapon_size_damage({"slot":"weapon","small_damage":11,"large_damage":22,"atk":999}, false) == 11,
		"typed small has priority over legacy atk")
	check(OPTIONS.weapon_size_damage({"slot":"weapon","small_damage":11,"large_damage":22,"atk":999}, true) == 22,
		"typed large has priority over legacy atk")
	check(OPTIONS.weapon_size_damage({"slot":"weapon","desc":"작은 대상 대미지 7 · 큰 대상 대미지 19"}, true) == 19,
		"named source options")
	check(OPTIONS.weapon_size_damage({"slot":"weapon","desc":"6/12 · 추가 대미지 +3","atk":9}, true) == 12,
		"legacy description 6/12 overrides aggregate atk")
	check(OPTIONS.weapon_size_damage({"slot":"weapon","atk":8}, false) == 8
		and OPTIONS.weapon_size_damage({"slot":"weapon","atk":8}, true) == 8, "no-pair fallback 8/8")
	check(OPTIONS.weapon_size_damage({"slot":"ring","atk":999}, true) == 0, "non-weapon never rolls")

	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		check(false, "Main scene available")
		finish()
		return
	var world: TwilightWorld = scene.instantiate() as TwilightWorld
	root.add_child(world)
	await process_frame
	await process_frame
	world.equipped_catalog = {"변신":{}, "마법인형":{}, "성물":{}}
	world.equipped_items = {}
	world._invalidate_equipment_static()
	var base_attack: int = world._effective_attack()
	var base_melee: int = world._melee_damage_stat()
	var base_ranged: int = world._ranged_damage_stat()
	world.equipped_items = {"weapon": test_weapon}
	world._invalidate_equipment_static()
	check(world._effective_attack() == base_attack, "legacy weapon atk cannot enter common attack")
	check(world._melee_damage_stat() == base_melee + 3, "melee stat keeps only explicit flat +3")
	check(world._ranged_damage_stat() == base_ranged + 3, "ranged stat keeps only explicit flat +3")
	var state: Dictionary = world._character_stats_snapshot()
	check(int(state.get("melee_damage", -1)) == base_melee + 3, "character sheet excludes 10/20 base")
	check(int(state.get("ranged_damage", -1)) == base_ranged + 3, "ranged sheet excludes base")
	check(int(state.get("weapon_small_damage", -1)) == 10, "character sheet displays small maximum")
	check(int(state.get("weapon_large_damage", -1)) == 20, "character sheet displays large maximum")

	var small: TwilightMonster = world.MONSTER_SCENE.instantiate() as TwilightMonster
	var large: TwilightMonster = world.MONSTER_SCENE.instantiate() as TwilightMonster
	world.monsters_root.add_child(small)
	world.monsters_root.add_child(large)
	small.set_meta("size_class", "small")
	large.set_meta("size_class", "large")
	world.rng.seed = 1022
	var saw_small_one: bool = false
	var saw_small_ten: bool = false
	var saw_large_one: bool = false
	var saw_large_twenty: bool = false
	for i: int in range(500):
		var small_roll: int = world._roll_weapon_damage(small)
		var large_roll: int = world._roll_weapon_damage(large)
		check(small_roll >= 1 and small_roll <= 10, "small 1..10 (sample " + str(i) + ")")
		check(large_roll >= 1 and large_roll <= 20, "large 1..20 (sample " + str(i) + ")")
		saw_small_one = saw_small_one or small_roll == 1
		saw_small_ten = saw_small_ten or small_roll == 10
		saw_large_one = saw_large_one or large_roll == 1
		saw_large_twenty = saw_large_twenty or large_roll == 20
	check(saw_small_one and saw_small_ten, "small roll covers 1 and 10")
	check(saw_large_one and saw_large_twenty, "large roll covers 1 and 20")

	world.equipped_items = {}
	world._invalidate_equipment_static()
	check(world._roll_weapon_damage(small) == 0, "unarmed adds no weapon roll")
	check(world._roll_weapon_damage(large) == 0, "unarmed large adds no weapon roll")
	var unarmed: Dictionary = world._character_stats_snapshot()
	check(int(unarmed.get("weapon_small_damage", -1)) == 0 and int(unarmed.get("weapon_large_damage", -1)) == 0,
		"unarmed sheet shows zero weapon maximum")
	world.queue_free()
	await process_frame
	finish()

func finish() -> void:
	if failures.is_empty():
		print("WEAPON_SIZE_DAMAGE_OK")
		quit(0)
	else:
		print("WEAPON_SIZE_DAMAGE_FAILED: " + str(failures.size()))
		quit(1)
