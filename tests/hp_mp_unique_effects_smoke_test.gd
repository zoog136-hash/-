extends SceneTree

var failures: Array[String] = []

func _check(ok: bool, details: String) -> void:
	if not ok:
		failures.append(details)
		print("HP_MP_UNIQUE_EFFECT_FAIL: " + details)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	var monster_scene: PackedScene = load("res://scenes/Monster.tscn") as PackedScene
	if scene == null or monster_scene == null:
		_check(false, "required Godot scenes must load")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var player: TwilightPlayer = world.get("player") as TwilightPlayer
	var monsters_root: Node = world.get("monsters_root") as Node
	var victim: TwilightMonster = monster_scene.instantiate() as TwilightMonster
	monsters_root.add_child(victim)
	victim.setup({"name":"HP 흡수 검증 몬스터", "lv":1, "hp":10000, "atk":1, "is_boss":false}, player, world, null)
	victim.global_position = player.global_position + Vector2(30, 0)
	world.set("equipped_items", {})
	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":{}})

	world.set("hp", 300)
	var previous_monster_hp: int = victim.hp
	world.call("_deal_successful_player_hit", victim, 10, false)
	_check(victim.hp == previous_monster_hp - 10, "without absorption hit damage must not change")
	_check(int(world.get("hp")) == 300, "without absorption hit must not heal")
	_check(not bool(world.call("_has_hp_absorption")), "absorption must be inactive without an equipped effect")

	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":{"name":"타로스의 창"}})
	_check(bool(world.call("_has_hp_absorption")), "Taros Spear should enable absorption")
	var record: Dictionary = world.call("_verified_catalog_record", "성물", {"name":"타로스의 창"})
	_check(bool(record.get("hpAbsorption", false)), "verified Taros Spear must carry HP absorption metadata")
	for attempt: int in range(15):
		world.set("hp", 300)
		var hp_before: int = int(world.get("hp"))
		var monster_hp_before: int = victim.hp
		world.call("_deal_successful_player_hit", victim, 10, false)
		var monster_loss: int = monster_hp_before - victim.hp
		var stolen: int = monster_loss - 10
		var healed: int = int(world.get("hp")) - hp_before
		_check(stolen == 1, "successful hit must drain exactly 1 monster HP (attempt %d)" % attempt)
		_check(healed == stolen, "player heal must equal the HP actually stolen (attempt %d)" % attempt)

	world.set("hp", int(world.call("_effective_max_hp")))
	var full_hp_before: int = int(world.get("hp"))
	world.call("_deal_successful_player_hit", victim, 10, false)
	_check(int(world.get("hp")) == full_hp_before, "HP absorption may not exceed effective maximum")
	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":{}})
	world.set("hp", 250)
	previous_monster_hp = victim.hp
	world.call("_deal_successful_player_hit", victim, 10, false)
	_check(int(world.get("hp")) == 250 and victim.hp == previous_monster_hp - 10, "absorption must stop on unequip")

	world.set("hp", 100)
	world.set("mp", 100)
	world.call("_tick_catalog_recovery", 60.0)
	_check(int(world.get("hp")) == 100 and int(world.get("mp")) == 100, "no sources: no HP/MP recovery")
	_check(float(world.get("hp_recovery_elapsed")) == 0.0 and float(world.get("mp_recovery_elapsed")) == 0.0, "no source must reset timers")

	world.set("equipped_catalog", {"변신":{}, "마법인형":{"name":"서큐버스퀸"}, "성물":{}})
	_check(bool(world.call("_has_recovery_effect", "mpRecoveryTick")), "Succubus Queen MP tick should be recognized")
	world.call("_tick_catalog_recovery", 29.5)
	_check(int(world.get("mp")) == 100, "MP must not recover before the 30-second boundary")
	world.call("_tick_catalog_recovery", 0.5)
	_check(int(world.get("mp")) == 105, "MP must restore exactly 5 on 30-second boundary")
	_check(int(world.get("hp")) == 100, "MP-only source must not restore HP")
	world.call("_tick_catalog_recovery", 60.0)
	_check(int(world.get("mp")) == 115, "two additional MP ticks must restore 10")
	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":{}})
	world.call("_tick_catalog_recovery", 1.0)
	_check(float(world.get("mp_recovery_elapsed")) == 0.0, "unequipping MP source must clear pending tick")

	world.set("equipped_catalog", {"변신":{}, "마법인형":{}, "성물":{"name":"타로스의 창"}})
	world.set("hp", 100)
	world.set("mp", 100)
	world.set("hp_recovery_elapsed", 0.0)
	world.call("_tick_catalog_recovery", 30.0)
	_check(int(world.get("hp")) == 105, "Taros recovery must restore HP 5, not legacy 6")
	_check(int(world.get("mp")) == 100, "HP-only source must not restore MP")
	_check(not bool(world.call("_has_recovery_effect", "mpRecoveryTick")), "Taros alone must not enable MP tick")

	world.set("equipped_catalog", {"변신":{}, "마법인형":{"name":"서큐버스퀸"}, "성물":{"name":"타로스의 창"}})
	world.set("hp", 100)
	world.set("mp", 100)
	world.set("hp_recovery_elapsed", 0.0)
	world.set("mp_recovery_elapsed", 0.0)
	world.call("_tick_catalog_recovery", 29.9)
	_check(int(world.get("hp")) == 100 and int(world.get("mp")) == 100, "simultaneous HP and MP effects must respect 30 seconds")
	world.call("_tick_catalog_recovery", 0.1)
	_check(int(world.get("hp")) == 105 and int(world.get("mp")) == 105, "simultaneous HP and MP should each restore 5")
	world.set("hp", int(world.call("_effective_max_hp")) - 1)
	world.set("mp", int(world.call("_effective_max_mp")) - 2)
	world.call("_tick_catalog_recovery", 30.0)
	_check(int(world.get("hp")) == int(world.call("_effective_max_hp")), "HP recovery must cap at effective max HP")
	_check(int(world.get("mp")) == int(world.call("_effective_max_mp")), "MP recovery must cap at effective max MP")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("HP_MP_UNIQUE_EFFECTS_SMOKE_OK: successful hit HP steal, 30-second HP/MP ticks and caps validated")
		quit(0)
	else:
		print("HP_MP_UNIQUE_EFFECTS_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
