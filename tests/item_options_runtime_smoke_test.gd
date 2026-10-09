extends SceneTree

const OPTIONS = preload("res://scripts/item_options.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, details: String) -> void:
	if not ok:
		failures.append(details)
		print("ITEM_OPTIONS_FAIL: " + details)

func _run() -> void:
	var dagger: Dictionary = {"name":"생명의 단검", "type":"단검", "slot":"weapon", "atk":21, "hit":10, "desc":"21/13 · 추가 대미지 +7 · 명중 +10"}
	_check(OPTIONS.accuracy(dagger, "melee") == 10, "structured hit must boost melee accuracy")
	_check(OPTIONS.accuracy(dagger, "ranged") == 10, "structured hit must boost ranged accuracy")
	_check(OPTIONS.accuracy(dagger, "magic") == 0, "physical hit must not boost magic accuracy")
	_check(OPTIONS.additional_damage(dagger, "melee") == 7, "description extra damage must contribute")
	_check(OPTIONS.weapon_size_adjustment(dagger, false) == 0, "small target baseline")
	_check(OPTIONS.weapon_size_adjustment(dagger, true) == -8, "21/13 large target adjustment")
	_check(OPTIONS.accuracy({"hit":5, "desc":"명중 +50"}, "melee") == 5, "structured hit must override description")
	_check(OPTIONS.attribute({"desc":"STR +2 · CON +3"}, "STR") == 2, "STR description parse")
	_check(OPTIONS.attribute({"desc":"STR +2 · CON +3"}, "CON") == 3, "CON description parse")
	_check(OPTIONS.attribute({"strFlat":4, "desc":"STR +2"}, "STR") == 4, "typed STR precedence")
	_check(OPTIONS.additional_damage({"desc":"추가 대미지 +5 · 근거리 대미지 +2"}, "melee") == 7, "shared/specific damage combined")
	_check(OPTIONS.item_weight({"weight":25}, {"단검":50}) == 25, "explicit weight has precedence")
	_check(OPTIONS.encumbrance_multiplier(50, 100) == 1.0, "normal capacity is unrestricted")
	_check(OPTIONS.encumbrance_multiplier(100, 100) == 0.85, "overweight should slow rather than disable movement")
	_check(OPTIONS.encumbrance_multiplier(160, 100) == 0.65, "heavy overweight penalty")
	_check(OPTIONS.encumbrance_multiplier(201, 100) == 0.5, "extreme overweight penalty")
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false, "Main.tscn could not be loaded")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":{}})
	world.set("equipped_items", {})
	var baseline_hit: int = int(world.call("_melee_accuracy_stat"))
	var baseline_damage: int = int(world.call("_melee_damage_stat"))
	var baseline_str: int = int(world.call("_effective_attribute", "STR"))
	world.set("equipped_items", {"weapon":dagger})
	_check(int(world.call("_melee_accuracy_stat")) == baseline_hit + 10, "equipped dagger hit not reflected in runtime")
	_check(int(world.call("_melee_damage_stat")) == baseline_damage + 21 + 7, "equipped dagger attack and bonus damage not reflected")
	_check(int(world.call("_weapon_size_adjustment", null)) == 0, "null target must not introduce size damage")
	var equipped_dagger: Dictionary = {"name":"군터의 단도", "type":"단검", "slot":"weapon", "atk":23, "hit":4, "desc":"23/12 · 추가 대미지 +9 · STR +2"}
	world.set("equipped_items", {"weapon":equipped_dagger})
	_check(int(world.call("_effective_attribute", "STR")) == baseline_str + 2, "equipped STR option missing")
	_check(int(world.call("_melee_accuracy_stat")) == baseline_hit + 6, "STR and hit must stack on accuracy")
	_check(int(world.call("_melee_damage_stat")) == baseline_damage + 23 + 9 + 1, "STR step and additional damage must affect melee damage")
	world.set("equipped_items", {"helmet":{"name":"test helmet", "slot":"helmet", "desc":"CON +3 · WIS +2"}})
	_check(int(world.call("_effective_max_hp")) >= int(world.get("max_hp")) + 30, "CON must affect maximum HP")
	_check(int(world.call("_effective_mr")) >= 10 + int(world.get("level")) + (int(world.get("wis_stat")) + 2) * 2, "WIS must affect MR")
	var weighted: Dictionary = world.get("item_weight_index") as Dictionary
	_check(int(weighted.get("HP 물약", -1)) == 3, "inventory weight rules should load from DB")
	world.set("inventory", {"HP 물약": 10})
	_check(int(world.call("_inventory_total_weight")) == 30, "inventory quantity x weight must calculate")
	var unburdened: float = float(world.call("_effective_move_speed_multiplier"))
	world.set("inventory", {"HP 물약": 2500})
	_check(int(world.call("_inventory_total_weight")) == 7500, "heavy inventory weight must calculate")
	_check(float(world.call("_effective_move_speed_multiplier")) < unburdened, "heavy inventory must slow movement")
	var state: Dictionary = world.call("_character_stats_snapshot")
	_check(int(state.get("inventory_weight", -1)) == 7500, "sheet should show current total carry weight")
	_check(int(state.get("carrying_capacity", 0)) > 0, "sheet should expose carrying capacity")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("ITEM_OPTIONS_SMOKE_OK: equipped bonuses, effective attributes, size rules and burden verified")
		quit(0)
	else:
		print("ITEM_OPTIONS_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
