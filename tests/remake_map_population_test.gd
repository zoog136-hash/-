extends SceneTree
## Real population slots retain one actor per slot and one live actor per boss key.
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("REMAKE_MAP_POPULATION_FAIL "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -10000
	world.player.set_physics_process(false)
	world._set_map("oman_01",false)
	var population: FieldPopulation = world.field_population
	population.set_process(false)
	var ordinary: Dictionary = {}
	var boss: Dictionary = {}
	for slot: Dictionary in population.slots:
		if str(slot.region.get("mode","normal")) == "boss": boss = slot
		elif is_instance_valid(slot.monster): ordinary = slot
	check(not ordinary.is_empty(),"real map contains an occupied ordinary slot")
	if not ordinary.is_empty():
		var original: Node = ordinary.monster
		var before: int = world.monsters_root.get_child_count()
		population._spawn_slot(ordinary)
		population._spawn_slot(ordinary)
		check(ordinary.monster == original,"repeated ordinary spawn preserves slot actor")
		check(world.monsters_root.get_child_count() == before,"repeated ordinary spawn creates no orphan actor")
	check(not boss.is_empty(),"real map contains a boss slot")
	if not boss.is_empty():
		var state: Dictionary = population.boss_director.state_for("oman_01",boss.region)
		state.ready_at = 0.0
		population._spawn_slot(boss)
		check(is_instance_valid(boss.monster),"boss spawned from real map region")
		if is_instance_valid(boss.monster):
			var original: TwilightMonster = boss.monster
			var before: int = world.monsters_root.get_child_count()
			population._spawn_slot(boss)
			check(boss.monster == original and world.monsters_root.get_child_count() == before,"repeated boss slot spawn preserves live actor")
			var duplicate: Dictionary = {"region":boss.region.duplicate(true),"index":1,"slot_id":population.slots.size(),"monster":null,"remaining":0.0}
			population.slots.append(duplicate)
			population._spawn_slot(duplicate)
			check(duplicate.monster == null and world.monsters_root.get_child_count() == before,"second slot with same persistent boss identity is rejected")
			population.slots.pop_back()
			original.hp = maxi(1,original.max_hp/2)
			var saved_hp: int = original.hp
			var identity: String = population.boss_director.key("oman_01",boss.region)
			world._set_map("aden_world",false)
			world._set_map("oman_01",false)
			population = world.field_population
			population.set_process(false)
			var matches: int = 0
			for restored: Dictionary in population.slots:
				if str(restored.region.get("mode","normal")) != "boss" or population.boss_director.key("oman_01",restored.region) != identity: continue
				if is_instance_valid(restored.monster):
					matches += 1
					check(restored.monster.hp == saved_hp,"map reload preserves boss damage")
			check(matches == 1,"live boss restores exactly once after map reload")
	world.queue_free()
	await process_frame
	print("REMAKE_MAP_POPULATION_OK " if failures.is_empty() else "REMAKE_MAP_POPULATION_FAILED ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
