extends SceneTree

const ENCHANT = preload("res://scripts/original_enhancement.gd")
var errors: Array[String] = []

func check(condition: bool, label: String) -> void:
	if not condition:
		errors.append(label)
		print("NON_SKILL_OPTION_FAIL: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(int(ENCHANT.stats("weapon", 9).get("damage", 0)) == 9, "weapon +9 damage")
	check(int(ENCHANT.stats("weapon", 10).get("damage", 0)) == 11, "weapon +10 damage")
	check(int(ENCHANT.stats("weapon", 14).get("damage", 0)) == 19, "weapon +14 damage")
	check(int(ENCHANT.stats("weapon", 10).get("accuracy", 0)) == 10, "weapon +10 hit")
	check(int(ENCHANT.stats("armor", 6).get("defense", 0)) == 6, "armor +6 AC")
	check(int(ENCHANT.stats("accessory", 5, {"name":"도펠겡어 보스의 오른쪽 반지", "slot":"ring"}).get("hp", 0)) == 50, "ring HP +50")
	check(int(ENCHANT.stats("accessory", 5, {"name":"도펠겡어 보스의 오른쪽 반지", "slot":"ring"}).get("sp", 0)) == 1, "ring +5 SP +1")
	check(int(ENCHANT.stats("accessory", 5, {"name":"룸티스의 보랏빛 귀걸이", "slot":"earring"}).get("mp", 0)) == 50, "Roomtis purple earring +5 MP additional +50 over base")
	check((ENCHANT.stats("accessory", 5, {"name":"검증용 목걸이", "slot":"necklace"})).is_empty(), "unknown accessory enhancement must not be fabricated")

	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		check(false, "Main.tscn missing")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set("equipped_items", {})
	world.set("equipped_catalog", {"변신":{},"마법인형":{},"성물":{}})
	var max_mp_before: int = int(world.call("_effective_max_mp"))
	world.set("equipped_items", {"tshirt":{"name":"테스트용 MP+30 티셔츠", "slot":"tshirt", "desc":"방어 +2 · MP +30"}})
	check(int(world.call("_effective_max_mp")) == max_mp_before + 30, "item MP+30 must increase actual max MP")
	world.set("equipped_items", {"tshirt":{"name":"테스트용 MP+30 티셔츠", "slot":"tshirt", "mpFlat":30, "desc":"방어 +2 · MP +30"}})
	check(int(world.call("_effective_max_mp")) == max_mp_before + 30, "typed MP bonus must not stack with same description")

	var weight: Dictionary = world.call("_character_stats_snapshot")
	check(weight.has("current_weight") and weight.has("max_weight"), "UI needs current_weight and max_weight")
	check(int(weight.get("max_weight",0)) > 0, "carrying capacity must be positive")
	check(str(world.call("_monster_size_class", {"name":"거대 드레이크", "is_boss":false})) == "large", "large monster by body type")
	check(str(world.call("_monster_size_class", {"name":"커츠", "is_boss":true})) == "small", "boss does not imply large")
	check(str(world.call("_monster_size_class", {"name":"테스트", "size_class":"large"})) == "large", "explicit large metadata")

	world.set("equipped_items", {})
	world.set("inventory", {"낡은 장검":2, "무기 마법 주문서 (각인)":5})
	world.set("item_instances", {})
	world.set("enhancement_levels", {})
	world.set("next_item_instance_id", 1)
	world.call("_sync_item_instances")
	var ids: Array[String] = []
	for key: Variant in (world.get("item_instances") as Dictionary).keys():
		if str(((world.get("item_instances") as Dictionary)[key] as Dictionary).get("name","")) == "낡은 장검":
			ids.append(str(key))
	check(ids.size() == 2, "two physical copies need distinct IDs")
	if ids.size() == 2:
		var instances: Dictionary = world.get("item_instances") as Dictionary
		(instances[ids[0]] as Dictionary)["level"] = 4
		(instances[ids[1]] as Dictionary)["level"] = 8
		world.set("item_instances", instances)
		var candidates: Array = world.call("_enhancement_candidates", "weapon")
		check(candidates.size() == 2, "enhancement chooser lists both copies")
		var levels: Array[int] = []
		for c: Variant in candidates:
			levels.append(int((c as Dictionary).get("level",-1)))
		check(levels.has(4) and levels.has(8), "enhancement chooser uses each instance level")
		var weapon: Dictionary = {"name":"낡은 장검","slot":"weapon","instance_id":ids[1]}
		world.set("equipped_items", {"weapon":weapon})
		check(int(world.call("_equipment_enhancement_level", "weapon")) == 8, "equipped copy gains own enhancement")
		var attack_before: int = int(world.call("_effective_attack"))
		(instances[ids[0]] as Dictionary)["level"] = 12
		world.set("item_instances", instances)
		check(int(world.call("_effective_attack")) == attack_before, "changing inventory copy must not buff equipped copy")
		(instances[ids[1]] as Dictionary)["level"] = 10
		world.set("item_instances", instances)
		check(int(world.call("_effective_attack")) == attack_before + 3, "+8 to +10 should increase additional damage by 3")
		world.call("_destroy_enhancement_target", "낡은 장검", ids[0])
		check(int((world.get("inventory") as Dictionary).get("낡은 장검", 0)) == 1, "destroy only one physical copy")
		check((world.get("item_instances") as Dictionary).has(ids[1]), "destroy leaves other copy")
		check(int(world.call("_equipment_enhancement_level", "weapon")) == 10, "equipped copy stays at +10")
	var shield: Dictionary = world.call("_verified_catalog_record", "성물", {"name":"군터의 방패"})
	check(int(shield.get("pve_damage_reduction",0)) == 2, "previous PvP value converted to PVE")
	var bead: Dictionary = world.call("_verified_catalog_record", "성물", {"name":"진명황의 보주"})
	check(int(bead.get("damage_reduction_ignore",0)) == 5, "resistance-ignore becomes flat extra damage")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if errors.is_empty():
		print("NON_SKILL_OPTIONS_SMOKE_OK")
		quit(0)
	else:
		print("NON_SKILL_OPTIONS_SMOKE_FAILED: %d" % errors.size())
		quit(1)
