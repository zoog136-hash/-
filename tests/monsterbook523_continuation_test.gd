extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node
var runtime: RefCounted
var fixture_unix: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MONSTERBOOK_CONTINUE_FAIL ",label)

func _initialize() -> void: call_deferred("run")
func reject_save(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE

func actor(npc_id: int) -> Node:
	var mob: Node = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(mob)
	mob.setup({"name":"source523-continuation-fixture","source_m_npc_id":npc_id,"hp":1,"xp":0,"gold":0,"drop":[],"lv":1},world.player,world,null)
	mob.global_position = world.player.global_position + Vector2(40,0)
	mob.set_physics_process(false)
	mob.died.connect(world._on_monster_died)
	return mob

func tap(button: Control) -> void:
	var point: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 8
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func press(button: Button,panel: Control) -> void:
	for frame: int in range(3): await process_frame
	panel.stage_scroll.ensure_control_visible(button)
	for frame: int in range(3): await process_frame
	if DisplayServer.get_name() == "headless": button.pressed.emit()
	else: await tap(button)

func text_of(node: Node) -> String:
	var value: String = str(node.text) if node is Label or node is Button else ""
	for child: Node in node.get_children(): value += "\n"+text_of(child)
	return value

func capture(name: String) -> void:
	var folder: String = OS.get_environment("MONSTERBOOK523_CAPTURES")
	if folder.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png") == OK,"actual OpenGL continuation capture")

func same_quantities(a: Dictionary,b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for key: Variant in a:
		if not b.has(key) or int(a[key]) != int(b[key]): return false
	return true

func reward_item(item_id: int) -> Dictionary:
	for book: Dictionary in runtime.catalog.books():
		for stage: Dictionary in runtime.catalog.levels(int(book.ID)):
			for reward: Dictionary in stage.rewards:
				if int(reward.RewardTypeID) == 2 and int(reward.RewardClassID) == item_id: return reward
	return {}

func run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main/current source-map entry")
	runtime = world.monsterbook523_runtime
	check(runtime.catalog.loaded(),"actual external v3 pack loaded")
	if not runtime.catalog.loaded(): world.queue_free(); quit(1); return
	# Regression of the source-date mode; local season rotation is covered by monsterbook523_rotation_test.
	runtime.catalog.rotate_ended_seasons = false
	check(runtime.local.window_problem(5903) == "도감 기간 종료","system date keeps original season closed")
	fixture_unix = int(Time.get_unix_time_from_datetime_string("2026-10-20T00:00:00"))
	runtime.local.unix_clock = func() -> int: return fixture_unix
	check(runtime.economy.settings.natural_counter_mode == "per_stage" and runtime.economy.settings.bonus_mode == "cumulative","production default policies are explicit configurable compatibility rules")
	var stages: Array = runtime.catalog.levels(5903)
	var epoch: String = runtime.local.epoch(5903)
	var natural_total: int = 0
	var counts: Dictionary = {}
	var registered: Array = []
	for stage: Dictionary in stages:
		var seed: Dictionary = runtime.catalog.export_state()
		counts[str(int(stage.ID))] = int(stage.Amount)-1
		natural_total += int(stage.Amount)-1
		seed.books['5903'] = {"sequence":1,"current_epoch":epoch,"epochs":{epoch:{"counts":counts.duplicate(),"kill_count":natural_total,"registered":registered.duplicate(),"claimed":[],"effective_levels":registered.duplicate(),"counter_policy":"per_stage","bonus_policy":"cumulative"}}}
		check(runtime.catalog.import_state(seed) and world._save_game(true) == OK,"durable near-threshold natural stage fixture")
		var mob := actor(104938)
		mob.take_damage(int(mob.hp)+1)
		natural_total += 1
		counts[str(int(stage.ID))] = int(stage.Amount)
		registered.append(int(stage.ID))
		check(runtime.catalog.progress(5903).registered == registered and int(runtime.catalog.progress(5903).kill_count) == natural_total,"actual death completes natural next stage with no Gem payment")
		check(runtime.catalog.progress(5903).effective_levels == registered,"actual natural completion automatically accumulates stage bonuses")
	check(runtime.incoming_damage(100,"magic") == 98 and runtime.incoming_damage(100,"melee") == 100,"both source stages feed actual typed channel reduction")
	# Restore a legitimately complete fixture to exercise every current reward.
	var complete: Dictionary = runtime.catalog.export_state()
	for book: Dictionary in runtime.catalog.books():
		var ids: Array = []
		var owned_counts: Dictionary = {}
		for stage: Dictionary in runtime.catalog.levels(int(book.ID)):
			ids.append(int(stage.ID)); owned_counts[str(int(stage.ID))] = int(stage.Amount)
		var key: String = runtime.local.epoch(int(book.ID))
		complete.books[str(int(book.ID))] = {"sequence":1,"current_epoch":key,"epochs":{key:{"counts":owned_counts,"registered":ids,"claimed":[],"effective_levels":ids.duplicate(),"bonus_policy":"cumulative","counter_policy":"per_stage"}}}
	check(runtime.catalog.import_state(complete) and world._save_game(true) == OK,"complete original stage fixtures preserve all source IDs")
	var effects: Dictionary = {}
	var paid: int = 0
	for book: Dictionary in runtime.catalog.books():
		for stage: Dictionary in runtime.catalog.levels(int(book.ID)):
			for bonus: Dictionary in stage.bonuses:
				effects[str(runtime.catalog.row("BonusType",int(bonus.BonusTypeID)).Name)] = true
				check(runtime.bonus_status(bonus).is_empty(),"every current typed effect has a consumer")
			check(world.request_monsterbook_action("claim",int(book.ID),int(stage.ID)).ok,"current source stage reward actually settles")
			paid += 1
	print("MONSTERBOOK_CONTINUE_PHASE all97_payouts_and_all39_effects")
	check(effects.size() == 39 and paid == 97,"all 39 current effect families and all 97 stage payouts covered")
	check(runtime.catalog.export_state().source_items.size() == 25,"all 25 item definitions including18 timed items reach actual inventory")
	var extra: Dictionary = runtime.extra_stats()
	check(extra.get("stun_accuracy") == 4 and extra.get("stun_resistance") == 4 and extra.get("fear_accuracy") == 4 and extra.get("fear_resistance") == 4,"original SpecialResistanceType6/8 and UI units reach status consumers")
	var stats: Dictionary = world._character_stats_snapshot()
	check(int(stats.stun_accuracy) >= 4 and int(stats.fear_resistance) >= 4,"actual Main character sheet consumes typed status values")
	world.hud.open_monsterbook523()
	var panel: Control = world.hud.find_child("MonsterBook523Panel",true,false)
	check(panel != null and text_of(panel).contains("TWILIGHT 호환 규칙"),"real UI distinguishes compatibility policy from original rows")
	var box: Dictionary = runtime.items.definition(reward_item(366812))
	var blessing: Dictionary = runtime.items.definition(reward_item(366772))
	var pack: Dictionary = runtime.items.definition(reward_item(366122))
	var mystery: Dictionary = runtime.items.definition(reward_item(366782))
	check(runtime.item_use.spec(pack).products[0].source.Amount == 5,"original MarketProduct pack size has priority over other seasons")
	var mystery_spec: Dictionary = runtime.item_use.spec(mystery)
	check(mystery_spec.get("hero_weight",-1) == world.card_draw_fusion.FUSION_WEIGHTS['희귀'],"missing mystery odds use separate existing-game balance setting")
	# Inventory activation opens the same actual item-use UI.
	world._on_inventory_item_activated(box.name)
	panel = world.hud.find_child("MonsterBook523Panel",true,false)
	var open: Button = panel.find_child("MonsterBookUse_366812",true,false)
	check(open != null,"actual inventory activation opens a source selection action")
	await press(open,panel)
	var choices: Array = runtime.item_use.spec(box).choices
	var choice: Dictionary = choices[0]
	var output: Dictionary = runtime.items.definition(choice)
	var box_before: int = int(world.inventory[box.name])
	var output_before: int = int(world.inventory.get(output.name,0))
	var choice_button: Button = panel.find_child("MonsterBookChoice_%d" % int(choice.ID),true,false)
	check(choice_button != null,"source choice rows become actual touch controls")
	for frame: int in range(3): await process_frame
	panel.stage_scroll.ensure_control_visible(choice_button)
	for frame: int in range(3): await process_frame
	await capture("monsterbook-v3-owned-selection")
	await press(choice_button,panel)
	check(int(world.inventory.get(box.name,0)) == box_before-1 and int(world.inventory[output.name]) == output_before+int(choice.Amount),"physical UI selects exact source output and consumes one box atomically")
	for frame: int in range(4): await process_frame
	await capture("monsterbook-v3-owned-result")
	var points_before: int = int(world.growth.state.points)
	var blessing_before: int = int(world.inventory[blessing.name])
	world.equipment_collections.test_save_writer = Callable(self,"reject_save")
	check(not runtime.item_use.use(blessing.name).ok and int(world.growth.state.points) == points_before and int(world.inventory[blessing.name]) == blessing_before,"point conversion failed save preserves both resources")
	world.equipment_collections.test_save_writer = Callable()
	check(runtime.item_use.use(blessing.name).ok and int(world.growth.state.points) == points_before+1000,"source BlessPoint14 goes to existing emblem points, not Ainhasad blessing")
	var card_before: Dictionary = world.card_draw_fusion.export_state()
	var pack_before: int = int(world.inventory[pack.name])
	var rng_before: int = runtime.item_use.rng.state
	world.equipment_collections.test_save_writer = Callable(self,"reject_save")
	check(not runtime.item_use.use(pack.name).ok and world.card_draw_fusion.export_state() == card_before and int(world.inventory[pack.name]) == pack_before and runtime.item_use.rng.state == rng_before,"draw save failure preserves item, card ownership and RNG")
	world.equipment_collections.test_save_writer = Callable()
	var drawn: Dictionary = runtime.item_use.use(pack.name)
	check(drawn.ok and drawn.results.size() == 5 and int(world.inventory.get(pack.name,0)) == pack_before-1,"native weighted pack actually grants original five cards")
	check(runtime.item_use.use(mystery.name).ok,"explicit custom mystery policy actually grants one existing card")
	# Force the one source pool outcome whose definition belongs to PR249.
	# Its original probability remains in the pool; ownership is never discarded.
	var relic_pack: Dictionary = runtime.items.definition(reward_item(366752))
	var relic_pool: Array = runtime.item_use.spec(relic_pack).products[0].pool
	var low: int = 0
	var high: int = 0
	for entry: Dictionary in relic_pool:
		if int(entry.ClassID) == 25162: high = low+int(entry.Probability); break
		low += int(entry.Probability)
	var probe := RandomNumberGenerator.new()
	var forced_state: String = ""
	for candidate: int in range(1,20000):
		probe.seed = candidate
		var initial: int = probe.state
		var roll: int = probe.randi_range(0,999999)
		if roll >= low and roll < high: forced_state = str(initial); break
	check(not forced_state.is_empty(),"fixture seed targets exact native new-card interval without changing weights")
	var seeded: Dictionary = runtime.catalog.export_state()
	seeded.item_actions.rng_state = forced_state
	check(runtime.catalog.import_state(seeded) and world._save_game(true) == OK,"native weighted RNG fixture durably installed")
	check(runtime.item_use.use(relic_pack.name).ok and world.card_draw_fusion.preserved_unmapped_collection.get("성물",{}).get("owned",{}).get("source:m523:98:25162",false),"new native card outcome is preserved through existing unknown-ownership API")
	print("MONSTERBOOK_CONTINUE_PHASE item_actions_settled")
	var snapshot: Dictionary = runtime.catalog.export_state()
	var inventory: Dictionary = world.inventory.duplicate(true)
	var cards: Dictionary = world.card_draw_fusion.export_state()
	var points: int = int(world.growth.state.points)
	var path: String = world.save_path()
	var digest: String = FileAccess.get_sha256(path)
	world._load_game(true)
	check(runtime.catalog.export_state() == snapshot and same_quantities(world.inventory,inventory) and world.card_draw_fusion.export_state() == cards and int(world.growth.state.points) == points and FileAccess.get_sha256(path) == digest,"real reload restores actual card/item/point transactions and unchanged save bytes")
	var ground_item: Dictionary = runtime.items.definition(reward_item(367142))
	check(world._drop_inventory_reference(ground_item.name,world.player.global_position),"original droppable timed item reaches actual floor ownership")
	var floor_id: String = ""
	for entry: Dictionary in world.ground_loot.records.values():
		if entry.item_name == ground_item.name: floor_id = str(entry.id)
	check(not floor_id.is_empty(),"source floor record retains item provenance")
	# End of the source event never reopens, but already acquired items remain
	# usable until their independent December deletion deadline.
	fixture_unix = int(Time.get_unix_time_from_datetime_string("2026-11-04T01:00:00"))
	check(runtime.local.window_problem(5903) == "도감 기간 종료" and runtime.extra_stats().is_empty(),"event end removes effects without deleting rewards")
	var remaining_pack: Dictionary = runtime.items.definition(reward_item(366162))
	check(runtime.item_use.use(remaining_pack.name).ok,"owned original event pack remains usable after book closes and before item deadline")
	fixture_unix = int(Time.get_unix_time_from_datetime_string("2026-12-29T20:00:00"))
	var before_expire: Dictionary = world.inventory.duplicate(true)
	var before_state: Dictionary = runtime.catalog.export_state()
	world.equipment_collections.test_save_writer = Callable(self,"reject_save")
	check(not runtime.items.expire_owned() and world.inventory == before_expire and runtime.catalog.export_state() == before_state and world.ground_loot.records.has(floor_id),"item deletion failed save preserves actual stock and history")
	world.equipment_collections.test_save_writer = Callable()
	check(runtime.items.expire_owned(),"exact source December30 Korean05 deadline expires stock")
	check(not world.ground_loot.records.has(floor_id),"source deadline retires dated floor stock in the same save transaction")
	var retired: Dictionary = runtime.catalog.export_state()
	var dated: int = 0
	for name: String in retired.source_items:
		if not retired.source_items[name].has("source_delete_clock"): continue
		dated += 1
		check(int(world.inventory.get(name,0)) == 0,"all timed inventory stacks retire at source deadline")
	check(dated == 18 and not retired.expired_items.is_empty(),"18 source timed definitions retain retired quantities and ownership proofs")
	check(not runtime.item_use.use(pack.name).ok and runtime.catalog.progress(5903).claimed.size() == 3,"expired item cannot be reused or reopen paid stage reward")
	world._load_game(true)
	check(runtime.catalog.export_state() == retired,"real reload preserves expiry archive and all prior reward receipts")
	fixture_unix = int(Time.get_unix_time_from_datetime_string("2026-10-20T00:00:00"))
	check(int(world.inventory.get(pack.name,0)) == 0,"clock rollback never resurrects a retired owned pack")
	print("MONSTERBOOK523_CONTINUATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_NATURAL_STAGES_ALL39_EFFECT_FAMILIES_ALL97_PAYOUTS_NATIVE_ITEM_ACTIONS_EXPIRY_UI_AND_SAVE; HISTORICAL_CLOCK_FIXTURE"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
