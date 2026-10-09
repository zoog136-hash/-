extends SceneTree

var failures: Array[String] = []

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("ORIGINAL_EFFECTS_FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene: PackedScene = load("res://Main.tscn") as PackedScene
	if main_scene == null:
		_check(false, "Cannot load project main scene")
		_finish()
		return
	var world: Node = main_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var library: Dictionary = world.get("verified_catalog_options") as Dictionary
	_check((library.get("마법인형", {}) as Dictionary).size() >= 16, "source-backed doll records missing")
	_check((library.get("성물", {}) as Dictionary).size() >= 5, "source-backed relic records missing")
	world.set("equipped_items", {})
	world.set("equipped_catalog", {"변신": {}, "마법인형": {}, "성물": {}})
	var baseline_speed: float = float(world.call("_effective_attack_speed_bonus_percent"))
	var base_damage: int = int(world.call("_melee_damage_stat"))
	var base_defense: int = int(world.call("_effective_defense"))
	var base_critical: int = int(world.call("_player_critical_rate", "ranged"))
	var base_capacity: int = int(world.call("_carrying_capacity"))
	var base_hp: int = int(world.call("_effective_max_hp"))
	var base_mp: int = int(world.call("_effective_max_mp"))
	var base_magic: int = int(world.call("_magic_damage_stat"))
	world.set("equipped_catalog", {"변신": {}, "마법인형": {"name":"린드비오르","atk":6,"speed":1.08,"xp":0.41}, "성물": {}})
	_check(absf(float(world.call("_effective_attack_speed_bonus_percent")) - baseline_speed - 15.0) < 0.001, "Lindvior +15 attack speed")
	_check(int(world.call("_melee_damage_stat")) == base_damage, "obsolete synthetic Lindvior atk must not leak")
	_check(int(world.call("_carrying_capacity")) == base_capacity + 3500, "Lindvior +3500 capacity")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{"name":"안타라스","def":5,"atk":6}, "성물":{}})
	_check(int(world.call("_damage_reduction_stat")) == 5, "Antharas +5 reduction instead of fake defense")
	_check(int(world.call("_effective_defense")) == base_defense, "Antharas synthetic defense should clear")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{"name":"푸른 드레이크","atk":2}, "성물":{}})
	_check(int(world.call("_player_critical_rate", "ranged")) == base_critical + 1, "Blue Drake ranged crit +1")
	_check(int(world.call("_ranged_damage_stat")) == int(world.call("_effective_attack")) + int(world.call("_stat_step_bonus", int(world.get("dex_stat")),10,2.0)) + int(world.call("_active_skill_buff_total","ranged_bonus")) + int(world.call("_active_item_buff_total","ranged_damage")), "Blue Drake must not provide fabricated ranged attack")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{"name":"판도라"}, "성물":{}})
	var inv: Dictionary = {"HP 물약":2}
	world.set("inventory", inv)
	world.set("hp", 100)
	world.call("_use_healing_item", "HP 물약", 55)
	_check(int(world.get("hp")) == 163, "Pandora potion 55 + flat 5 + 5% rounds to 63")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{"name":"리즈"}, "성물":{}})
	_check(int(world.call("_pve_damage_after_item_buffs", 23)) == 20, "Liz must reduce PvE incoming by flat 3")
	_check(int(world.call("_magic_accuracy_stat")) >= int(world.get("level")) + int(world.get("int_stat")) + 2, "Liz magic accuracy +2")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{"name":"서큐버스퀸"}, "성물":{}})
	_check(int(world.call("_effective_max_mp")) == base_mp + 50, "Succubus Queen max MP +50")
	_check(int(world.call("_magic_damage_stat")) == base_magic + 1, "Succubus Queen SP +1")
	var queen: Dictionary = world.call("_verified_catalog_record", "마법인형", {"name":"서큐버스퀸"})
	_check(int(queen.get("mpRecoveryTick",0)) == 12, "MP +12 must be recorded but not force a made-up tick cadence")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{"name":"다크 하딘"}, "성물":{}})
	_check(int(world.call("_pve_damage_after_item_buffs", 23)) == 18, "Dark Hadin former PVP reduction +5 now applies against PvE")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{"name":"버그베어"}, "성물":{}})
	_check(int(world.call("_carrying_capacity")) == base_capacity + 500, "Bugbear weight +500")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{}, "성물":{"name":"군터의 방패"}})
	_check(int(world.call("_damage_reduction_stat")) == 2, "Gunter Shield flat reduction +2")
	_check(absf(float(world.call("_skill_cooldown_factor")) - 0.93) < 0.001, "Gunter Shield skill cooldown -7%")
	_check(int(world.call("_effective_max_hp")) > base_hp, "Gunter Shield +7% max HP")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{}, "성물":{"name":"세계수의 꽃잎"}})
	_check(int(world.call("_effective_defense")) == base_defense + 2, "World Tree Leaf AC -2")
	_check(int(world.call("_damage_reduction_stat")) == 2, "World Tree Leaf DR +2")
	_check(absf(float(world.call("_skill_cooldown_factor")) - 0.95) < 0.001, "World Tree Leaf cooldown -5%")
	world.set("equipped_catalog", {"변신": {}, "마법인형":{}, "성물":{"name":"타로스의 창"}})
	var spear: Dictionary = world.call("_verified_catalog_record", "성물", {"name":"타로스의 창"})
	_check(int(spear.get("hpAbsoluteRecovery", 0)) == 6, "Taros absolute HP recovery +6 must be sourced")
	_check(absf(float(world.call("_skill_cooldown_factor")) - 0.95) < 0.001, "Taros Spear cooldown -5%")
	_check(int(world.call("_catalog_stat_sum", "potionHealFlat")) == 0, "Taros HP steal must not be converted to potion heal")
	var snapshot: Dictionary = world.call("_character_stats_snapshot")
	_check(int(snapshot.get("carrying_capacity",0)) > 0, "previous item option snapshot preserved")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("ORIGINAL_LINEAGEM_EFFECTS_OK: verified doll and relic runtime bonuses checked")
		quit(0)
	else:
		print("ORIGINAL_LINEAGEM_EFFECTS_FAILED: %d failure(s)" % failures.size())
		quit(1)
