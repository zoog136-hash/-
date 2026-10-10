extends SceneTree
## Real Main.tscn flow. Private bundle = original art; CI fixture = synthetic art.
const ASSETS = preload("res://addons/twilight_l1j/twilight_runtime_assets.gd")
const THEME = preload("res://scripts/ui/renewal_theme.gd")
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
var world: TwilightWorld

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("L1J_RUNTIME_FAIL: ", message)

func _run() -> void:
	ASSETS.reset()
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(CLASS_QA.enter_game(world), "class confirmation before real gameplay")
	await process_frame
	await process_frame
	world.set_process(false)
	world.save_timer = -10000
	world.field_population.set_process(false)
	world._clear_monsters()
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550,4300)))
	var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSETS.PATH))
	var installed: int = 0
	for binding: Dictionary in bindings.items:
		var item: Dictionary = world._catalog_item_from_source_id(str(binding.game_source_id))
		var before: Dictionary = item.duplicate(true)
		var icon: Texture2D = THEME.item_icon(item, str(item.get("name", "")), {})
		var available: bool = FileAccess.file_exists(str(binding.inventory_texture))
		if available:
			check(icon != null and icon.resource_path == str(binding.inventory_texture), "catalog icon " + str(binding.game_name))
			installed += 1
		check(item == before, "icon lookup preserves record and grade")
		var mismatched: Dictionary = item.duplicate(true)
		mismatched["sourceId"] = "different-existing-game-id"
		check(ASSETS.item_icon(mismatched, str(item.name)) == null, "same name with different source ID must not override")
	check(installed in [0,5], "bundle must expose the entire reviewed item set")
	var record: Dictionary = world._catalog_item_from_source_id("423")
	var name_value: String = str(record.name)
	world.hud.open_catalog("아이템")
	world._grant_playtest_catalog_variant("423", 2)
	world.hud.refresh_inventory(world.inventory)
	var ids: Array[String] = []
	for id: String in world.item_instances:
		if str(world.item_instances[id].get("name", "")) == name_value: ids.append(id)
	check(ids.size() >= 2, "two independent physical gear IDs")
	if ids.size() >= 2:
		var first: String = ids[0]
		var second: String = ids[1]
		world.job_class = "군주"
		world._equip_or_acquire_item(record, false, first)
		check(str(world.equipped_items.weapon.get("instance_id", "")) == first, "equip existing physical ID")
		world.inventory["무기 마법 주문서"] = 2
		world._attempt_enhancement("무기 마법 주문서", name_value + "@@@" + first)
		check(int(world.item_instances[first].level) == 1 and int(world.item_instances[second].level) == 0, "enchant only selected physical ID")
		var physical: Dictionary = world.item_instances.duplicate(true)
		world._save_game(true)
		world.item_instances.clear()
		world._load_game(true)
		for physical_id: String in physical:
			check(world.item_instances.has(physical_id), "saved physical ID survives: " + physical_id)
			if world.item_instances.has(physical_id):
				var saved: Dictionary = physical[physical_id]
				var restored: Dictionary = world.item_instances[physical_id]
				for key: String in ["name", "level", "element", "element_level"]:
					if key in ["level", "element_level"]:
						check(int(saved.get(key,0)) == int(restored.get(key,0)), "saved physical property " + key)
					else:
						check(str(saved.get(key,"")) == str(restored.get(key,"")), "saved physical property " + key)
				if saved.has("record"):
					check(str(saved.record.get("sourceId","")) == str(restored.get("record",{}).get("sourceId","")), "source ID survives catalog re-normalization")
	var origin: Vector2 = world.player.global_position
	var count_before: int = int(world.inventory.get(name_value, 0))
	var drop: Button = world._spawn_ground_drop(name_value, origin)
	check(drop != null, "ground drop is created")
	if drop != null:
		check(int(world.inventory.get(name_value,0)) == count_before, "drop does not grant inventory")
		var visual: TwilightDropVisual = (drop as TwilightGroundLoot).visual
		if installed == 5:
			check(visual.texture != null and visual.texture.resource_path.begins_with("res://assets/l1j/verified/ground/"), "actual ground image")
			check(is_instance_valid(visual.source_icon), "source ground icon uses independent display key")
		check(not world._collect_ground_drop(drop), "minimum visible lifetime remains enforced")
		drop.set("visible_since", Time.get_ticks_msec() - 900)
		drop.pressed.emit()
		check(world.loot_pickup.selected_id == str(drop.get_meta("id")), "manual selection resolves existing drop ID")
		check(world._collect_ground_drop(drop), "manual pickup grants after ground stage")
		check(int(world.inventory.get(name_value,0)) == count_before+1, "pickup grants once")
		check(not world._collect_ground_drop(drop), "stale pickup cannot grant twice")
	var auto_drop: Button = world._spawn_ground_drop(name_value, world.player.global_position)
	if auto_drop != null:
		auto_drop.set("visible_since", Time.get_ticks_msec() - 900)
		world.player.set_auto_enabled(true)
		for tick: int in range(20):
			world._run_auto_ground_pickup()
			await physics_frame
		check(int(world.inventory.get(name_value,0)) == count_before+2, "auto pickup uses the same ground record")
		world.player.set_auto_enabled(false)
	for binding: Dictionary in bindings.monsters:
		var monster_record: Dictionary = {}
		for value: Dictionary in world.monster_db:
			if str(value.name) == str(binding.game_name): monster_record = value.duplicate(true); break
		check(not monster_record.is_empty(), "existing monster " + str(binding.game_name))
		if monster_record.is_empty(): continue
		var texture: Texture2D = world._monster_texture(monster_record)
		if FileAccess.file_exists(str(binding.texture)):
			check(texture.resource_path == str(binding.texture), "source monster image " + str(binding.game_name))
			var pixels: Image = texture.get_image()
			if not bool(bindings.get("synthetic_fixture_only",false)):
				check(pixels.get_pixel(0,0).a == 0.0, "portrait border is transparent in every spawn path")
		var actor: TwilightMonster = world.MONSTER_SCENE.instantiate()
		world.monsters_root.add_child(actor)
		actor.global_position = world.player.global_position + Vector2(200,0)
		actor.setup(monster_record, world.player, world, texture)
		actor.set_physics_process(false)
		actor.died.connect(world._on_monster_died)
		check(actor.monster_name == str(binding.game_name) and actor.sprite.texture == texture, "live field actor is bound")
		actor.take_damage(999999)
		check(actor.dead, "existing death callback with external static art")
		check(str(binding.animation_status) == "STATIC_ONLY", "unclassified SPX cannot claim native combat animations")
	# Real auto-hunt approach and basic attack markers. Test HP is bounded to 80;
	# production stats, AI and drop tables are never edited by this fixture.
	world.quickslots.clear()
	world.rng.seed = 20261010
	for mob_name: String in ["버그베어", "데스나이트"]:
		world._clear_drops()
		world._clear_combat_actions()
		world.player.cancel_attack()
		world.auto_target = null
		world.selected_monster = null
		world.player.global_position = origin
		var combat_record: Dictionary = {}
		for value: Dictionary in world.monster_db:
			if str(value.name) == mob_name: combat_record = value.duplicate(true); break
		combat_record["hp"] = 80
		combat_record["ac"] = 0
		var actor: TwilightMonster = world.MONSTER_SCENE.instantiate()
		world.monsters_root.add_child(actor)
		actor.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(origin+Vector2(220,0)))
		actor.setup(combat_record,world.player,world,world._monster_texture(combat_record))
		actor.set_physics_process(false)
		actor.died.connect(world._on_monster_died)
		var inventory_before: int = int(world.inventory.get(name_value,0))
		world.player.set_auto_enabled(true)
		var ticks: int = 0
		while not actor.dead and ticks < 900:
			world.auto_attack_timer = maxf(0.0,world.auto_attack_timer-1.0/60.0)
			world.auto_repath_timer = maxf(0.0,world.auto_repath_timer-1.0/60.0)
			world._run_auto_hunt()
			await physics_frame
			ticks += 1
		if not actor.dead:
			# Keep evidence BEFORE clearing AUTO and its path: intermittent
			# pursuit failures must be diagnosed, not hidden by CI retries.
			var track: Dictionary = {
				"monster":mob_name, "ticks":ticks,
				"player":[world.player.global_position.x,world.player.global_position.y],
				"enemy":[actor.global_position.x,actor.global_position.y],
				"distance":world.player.global_position.distance_to(actor.global_position),
				"weapon_cells":world._current_attack_range_cells(),
				"cell_distance":world._weapon_cell_distance(actor),
				"line_clear":world._has_line_of_sight_world(world.player.global_position,actor.global_position),
				"active_target":world.auto_target == actor,
				"auto_enabled":world.player.auto_enabled,
				"click_path_length":world.player.click_path.size(),
				"path_index":world.player.path_index,
				"repath_timer":world.auto_repath_timer,
				"world_path_length":world.find_world_path(world.player.global_position,actor.global_position).size(),
				"pending_attack":not world.pending_attack.is_empty(),
				"stunned":world.player.is_stunned(),
				"held":world.player.is_held(),
				"feared":world.player.is_feared()
			}
			print("L1J_COMBAT_DIAG ",JSON.stringify(track))
		world.player.set_auto_enabled(false)
		world.player.clear_click_path()
		print("L1J_COMBAT_TRACE ", mob_name, " ticks=", ticks, " hp=", actor.hp, " hits=", actor.damage_hit_count)
		check(world.player.global_position.distance_to(origin)>40,"auto hunt physically approaches "+mob_name)
		check(actor.damage_hit_count>0 and actor.dead,"basic hit markers kill source-image actor "+mob_name)
		check(int(world.inventory.get(name_value,0))==inventory_before,"death cannot directly grant representative gear")
	ASSETS.set_enabled(false)
	check(ASSETS.item_icon(record, name_value) == null, "global rollback disables overrides")
	ASSETS.set_enabled(true)
	var report: Dictionary = {"checks":checks, "installed_item_images":installed, "failures":failures,
		"engine":Engine.get_version_info().string, "source_art":not bool(bindings.get("synthetic_fixture_only",false)),
		"auto_hunt_combat_actors":2,"combat_fixture_hp":80,"production_balance_validation":false}
	print("L1J_RUNTIME_OK " if failures.is_empty() else "L1J_RUNTIME_FAIL ", JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
