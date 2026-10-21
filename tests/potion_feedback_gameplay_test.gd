extends SceneTree

var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("POTION_GAMEPLAY FAIL: " + detail)

func emitted(world: Node) -> int:
	var fx: Node = world.get("potion_feedback") as Node
	return int(fx.get("emitted")) if is_instance_valid(fx) else 0

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.set("source_save_blocked", true)
	check(world is TwilightWorld, "production scene preserves world type")
	check(world.get_script().get_base_script().resource_path == "res://scripts/world.gd", "inherits authoritative gameplay")
	var inventory: Dictionary = world.get("inventory") as Dictionary
	var cooldowns: Dictionary = world.get("item_use_cooldowns") as Dictionary
	inventory["HP 물약"] = 5
	inventory["강력 HP 물약"] = 5
	cooldowns.clear()
	world.set("hp", 100)
	var before: int = emitted(world)
	world.call("_on_inventory_item_activated", "HP 물약")
	check(int(world.get("hp")) == 155 and int(inventory["HP 물약"]) == 4, "inventory HP heal and cost unchanged")
	check(emitted(world) == before + 1, "inventory success emits once")
	check(is_equal_approx(float(cooldowns.get("__hp_potion_shared__", 0.0)), 1.0), "shared cooldown unchanged")
	before = emitted(world)
	world.call("_use_quick_item", "강력 HP 물약")
	check(emitted(world) == before and int(inventory["강력 HP 물약"]) == 5, "cooldown denial emits nothing")
	world.call("_tick_item_buffs", 1.0)
	world.set("hp", 100)
	world.call("_use_quick_item", "강력 HP 물약")
	check(int(world.get("hp")) == 220 and int(inventory["강력 HP 물약"]) == 4, "quick/auto HP cost and healing unchanged")
	check(emitted(world) == before + 1, "quick/auto path emits once")
	world.call("_tick_item_buffs", 1.0)
	world.set("hp", int(world.call("_effective_max_hp")))
	before = emitted(world)
	world.call("_on_inventory_item_activated", "HP 물약")
	check(emitted(world) == before and int(inventory["HP 물약"]) == 4, "full HP emits nothing")
	world.set("hp", 100)
	inventory["HP 물약"] = 0
	world.call("_use_potion")
	check(emitted(world) == before and int(world.get("hp")) == 100, "empty inventory emits nothing")
	inventory["HP 물약"] = 2
	world.call("_use_potion")
	check(emitted(world) == before + 1 and int(inventory["HP 물약"]) == 1, "legacy potion button covered")
	inventory["마나 회복 물약"] = 2
	world.set("mp", 0)
	before = emitted(world)
	world.call("_on_inventory_item_activated", "마나 회복 물약")
	check(emitted(world) == before + 1 and int(inventory["마나 회복 물약"]) == 1, "timed mana emits only on consumption")
	world.call("_tick_item_buffs", 30.0)
	check(emitted(world) == before + 1 and int(world.get("mp")) == 5, "regen ticks heal without replaying drink effect")
	inventory["마녀의 마력 회복제"] = 3
	world.set("mp", 0)
	before = emitted(world)
	world.call("_use_quick_item", "마녀의 마력 회복제")
	check(emitted(world) == before + 1 and int(inventory["마녀의 마력 회복제"]) == 2, "instant mana quickslot emits once")
	check(int(world.get("mp")) == mini(1000, int(world.call("_effective_max_mp"))), "instant mana amount unchanged")
	before = emitted(world)
	world.call("_on_inventory_item_activated", "마녀의 마력 회복제")
	check(emitted(world) == before, "instant mana cooldown emits nothing")
	cooldowns.erase("마녀의 마력 회복제")
	world.set("mp", 0)
	world.call("_on_inventory_item_activated", "마녀의 마력 회복제")
	check(emitted(world) == before + 1, "instant mana inventory path covered")
	inventory["전투 강화의 주문서"] = 1
	before = emitted(world)
	world.call("_on_inventory_item_activated", "전투 강화의 주문서")
	check(emitted(world) == before and int(inventory["전투 강화의 주문서"]) == 0, "non-potion buff unchanged")
	var fx: Node = world.get("potion_feedback") as Node
	check(fx.get_parent() == world.get("player"), "light follows actual player")
	world.call("_clear_combat_actions")
	fx.call("_process", 0.01)
	check((fx.get("active") as Array).is_empty(), "world lifecycle clears light")
	world.queue_free()
	await process_frame
	if failures == 0: print("POTION_GAMEPLAY_OK checks=%d" % checks)
	quit(0 if failures == 0 else 1)
