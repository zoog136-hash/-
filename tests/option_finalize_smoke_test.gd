extends SceneTree

const ENCHANT = preload("res://scripts/original_enhancement.gd")
const RULES = preload("res://scripts/consumable_rules.gd")
const ITEM_OPTIONS = preload("res://scripts/item_options.gd")
var failures: Array[String] = []

func assert_ok(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("OPTION_FINALIZE_FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert_ok(int(ENCHANT.stats("weapon", 10).get("damage", 0)) == 11, "official +10 weapon damage")
	assert_ok(int(ITEM_OPTIONS.weapon_size_adjustment({"slot":"weapon","stat":"54 / 35","desc":"추가 대미지 +84"}, true)) == -19, "Inven 54/35 source stat large minus small damage")
	assert_ok(int(ITEM_OPTIONS.weapon_size_adjustment({"slot":"weapon","desc":"작은 대상 대미지 54 · 큰 대상 대미지 35"}, true)) == -19, "Inven named size damage parses")
	assert_ok(int(ITEM_OPTIONS.weapon_size_adjustment({"slot":"weapon","stat":"54 / 35"}, false)) == 0, "small target gets unmodified small weapon base")
	assert_ok(int(ENCHANT.stats("armor", 5, {"name":"마법 망토"}).get("mr", 0)) == 10, "magic cloak +5 MR+10")
	assert_ok(int(ENCHANT.stats("armor", 6, {"name":"리치 로브"}).get("sp", 0)) == 4, "lich robe +6 SP+4")
	assert_ok(int(ENCHANT.stats("accessory", 5, {"name":"도펠겡어 보스의 오른쪽 반지"}).get("hp", 0)) == 50, "Doppel ring HP progression")
	assert_ok(ENCHANT.stats("accessory", 5, {"name":"다른 반지", "slot":"ring"}).is_empty(), "Doppel bonuses must not leak to all rings")
	assert_ok(int(ENCHANT.stats("accessory", 8, {"name":"룸티스의 푸른빛 귀걸이"}).get("potion_heal_flat", 0)) == 18, "blue earring +8 flat potion delta")
	assert_ok(int(ENCHANT.stats("accessory", 8, {"name":"룸티스의 푸른빛 귀걸이"}).get("potion_heal_pct", 0)) == 23, "blue earring +8 potion rate delta")
	assert_ok(int(ENCHANT.stats("accessory", 6, {"name":"룸티스의 검은빛 귀걸이"}).get("melee_damage", 0)) == 4, "black earring melee +4")
	assert_ok(int(ENCHANT.stats("accessory", 5, {"name":"룸티스의 붉은빛 귀걸이"}).get("reduction", 0)) == 3, "red earring reduction +3")
	assert_ok(int(ENCHANT.stats("accessory", 8, {"name":"룸티스의 보랏빛 귀걸이"}).get("mp", 0)) == 95, "purple earring MP delta")
	assert_ok(int(ENCHANT.stats("accessory", 8, {"name":"룸티스의 보랏빛 귀걸이"}).get("sp", 0)) == 4, "purple earring SP")
	assert_ok(int(ENCHANT.stats("accessory", 8, {"name":"룸티스의 보랏빛 귀걸이"}).get("mp_recovery", 0)) == 3, "purple earring MP recovery option")
	assert_ok(str(RULES.definition("속성 변경 주문서").get("kind", "")) == "element_change", "change scroll recognized")
	assert_ok(str(RULES.definition("속성 초기화 주문서").get("kind", "")) == "element_reset", "reset scroll recognized")
	for i: int in range(5):
		assert_ok(RULES.element_success_chance(i) > 0.0, "element chance configured stage " + str(i))
	print("OPTION_FINALIZE_TRACE: pre-scene assertions complete")
	var save_file: String = "user://twilight_v20_save.json"
	var had_previous_save: bool = FileAccess.file_exists(save_file)
	var previous_save: String = FileAccess.get_file_as_string(save_file) if had_previous_save else ""
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		assert_ok(false, "Main.tscn missing")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	print("OPTION_FINALIZE_TRACE: world scene ready")
	var db: Array = world.get("monster_db") as Array
	var sizes: Dictionary = world.get("monster_size_index") as Dictionary
	assert_ok(db.size() == 163, "163 monster records expected")
	for value: Variant in db:
		var monster: Dictionary = value as Dictionary
		var name_value: String = str(monster.get("name", ""))
		assert_ok(sizes.has(name_value), "explicit size missing: " + name_value)
		assert_ok(str(world.call("_monster_size_class", monster)) in ["small", "large"], "invalid size for: " + name_value)
	assert_ok(str(world.call("_monster_size_class", {"name":"커츠", "is_boss":true})) == "small", "boss need not be large")
	assert_ok(str(world.call("_monster_size_class", {"name":"거대 드레이크", "is_boss":false})) == "large", "nonboss may be large")

	var index: Dictionary = world.get("item_weight_index") as Dictionary
	var all_items: Array = world.get("item_db") as Array
	for raw: Variant in all_items:
		var entry: Dictionary = raw as Dictionary
		var item_name: String = str(entry.get("name", ""))
		assert_ok(index.has(item_name), "item weight missing: " + item_name)
		assert_ok(int(index.get(item_name, -1)) >= 0, "negative item weight: " + item_name)
	assert_ok(int(index.get("도펠겡어 보스의 오른쪽 반지",0)) == 3, "verified ring weight =3")
	assert_ok(int(index.get("다마스커스 검 (각인)",0)) == 45, "verified Damascus weight =45")
	print("OPTION_FINALIZE_TRACE: monster and weights checked")
	world.set("equipped_catalog", {"변신":{},"마법인형":{},"성물":{}})
	world.set("inventory", {})
	world.set("equipped_items", {})
	world.set("item_instances", {"11":{"name":"마법 망토","level":5}, "12":{"name":"룸티스의 보랏빛 귀걸이","level":8}})
	world.set("equipped_items", {"cloak":{"name":"마법 망토","slot":"cloak","instance_id":"11"}, "earring1":{"name":"룸티스의 보랏빛 귀걸이","slot":"earring","instance_id":"12"}})
	var mp_base: int = int(world.get("max_mp"))
	assert_ok(int(world.call("_effective_max_mp")) == mp_base + 95, "enchanted earring raises effective MP by 95")
	assert_ok(int(world.call("_effective_mr")) >= 10, "special cloak enhancement MR actually applied")
	var cloak_detail: Dictionary = {"name":"마법 망토","slot":"cloak","instance_id":"11","desc":"물리 방어력(AC) -1 · 마법 방어력(MR) +10"}
	var only_cloak: Dictionary = {"cloak":cloak_detail}
	world.set("equipped_items", only_cloak)
	var original_mr: int = int(world.call("_effective_mr"))
	assert_ok(original_mr >= 20, "base cloak MR+10 and +5 enhancement MR+10 both apply")
	var blue_earring: Dictionary = {"name":"룸티스의 푸른빛 귀걸이","slot":"earring","desc":"물약 회복률 +2% · 물약 회복량 +2"}
	var equipped_potion: Dictionary = {"earring1":blue_earring}
	world.set("equipped_items", equipped_potion)
	assert_ok(int(world.call("_equipment_potion_heal_stat", "물약 회복량")) == 2, "blue earring +0 base potion flat+2")
	assert_ok(int(world.call("_equipment_potion_heal_stat", "물약 회복률")) == 2, "blue earring +0 base potion +2%")
	world.set("equipped_items", {"cloak":{"name":"마법 망토","slot":"cloak","instance_id":"11"}, "earring1":{"name":"룸티스의 보랏빛 귀걸이","slot":"earring","instance_id":"12"}})
	var earring_slots: Array[String] = ["earring1", "earring2"]
	assert_ok(int(world.call("_enhancement_stat_for_slots", earring_slots, "mp_recovery")) == 3, "earring MP tick wired")

	print("OPTION_FINALIZE_TRACE: enhancement MP/MR checked")
	world.set("equipped_items", {"tshirt":{"name":"지식의 티셔츠","slot":"tshirt","desc":"방어 +2 · MP +30"}})
	world.set("max_mp", 200)
	world.set("mp", 200)
	world.set("inventory", {"마녀의 마력 회복제":1})
	var service: Node = world.get("consumable_service") as Node
	service.call("_use_instant_mp", "마녀의 마력 회복제", RULES.definition("마녀의 마력 회복제"))
	assert_ok(int(world.get("mp")) == 230, "instant MP potion must use equipped 230 cap")
	assert_ok(int((world.get("inventory") as Dictionary).get("마녀의 마력 회복제", 0)) == 0, "MP potion consumes one")

	print("OPTION_FINALIZE_TRACE: instant MP potion checked")
	world.set("inventory", {"낡은 장검":2, "속성 변경 주문서":1, "속성 초기화 주문서":1})
	world.set("item_instances", {"111":{"name":"낡은 장검", "level":11,"element":"fire","element_level":4},
		"222":{"name":"낡은 장검","level":8,"element":"earth","element_level":2}})
	service.call("apply_element_management", "속성 변경 주문서", "낡은 장검@@@111", "water")
	var instances: Dictionary = world.get("item_instances") as Dictionary
	assert_ok(str((instances["111"] as Dictionary).get("element","")) == "water", "change element on selected copy")
	assert_ok(int((instances["111"] as Dictionary).get("element_level",0)) == 4, "element change preserves stage")
	assert_ok(str((instances["222"] as Dictionary).get("element","")) == "earth", "other weapon unaffected by change")
	service.call("apply_element_management", "속성 초기화 주문서", "낡은 장검@@@111", "")
	instances = world.get("item_instances") as Dictionary
	assert_ok(str((instances["111"] as Dictionary).get("element","")) == "" and int((instances["111"] as Dictionary).get("element_level",0)) == 0, "reset selected copy only")
	assert_ok(int((instances["222"] as Dictionary).get("element_level",0)) == 2, "other copy stays upgraded")
	print("OPTION_FINALIZE_TRACE: elemental change and reset checked")
	world.queue_free()
	await process_frame
	if had_previous_save:
		var restore_file: FileAccess = FileAccess.open(save_file, FileAccess.WRITE)
		if restore_file != null:
			restore_file.store_string(previous_save)
			restore_file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("OPTION_FINALIZE_OK: original tables, monsters, inventory weight, MP and elemental manage")
		quit(0)
	else:
		print("OPTION_FINALIZE_FAILED: %d failures" % failures.size())
		quit(1)
