extends SceneTree
## Private original pack integration. Install the normal 523 definitions and UI
## before process startup. Use one isolated XDG_DATA_HOME for three launches with
## TWILIGHT_POWDER_BAG_PHASE=seed, combat and reload, in that order. "control"
## exercises the same mixed save and pickup against the pre-fix Main.
const QA = preload("res://tests/qa_class_selection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const STOCK = preload("res://scripts/loot/current523_native_stack.gd")
const REFINE = preload("res://scripts/refine523/bless_refine523_service.gd")
const MIGRATION = preload("res://scripts/loot/legacy_item_migration523.gd")
const CASH = preload("res://scripts/shop/source523_cash_packages.gd")
const TOP = preload("res://scripts/ui/original_ui/source_main_menu_bindings.gd")
const ITEM = 117544
const BOX = 371431
const BOX_REWARD = 45000
const LABEL = "상급 축복의 가루"
const CANONICAL = "상급 축복의 가루 · 원본#117544"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		printerr("POWDER_BAG_FAIL ", label)
	return value

func frames() -> void:
	await process_frame
	await process_frame

func touch(control: Control) -> bool:
	if not check(is_instance_valid(control) and control.is_visible_in_tree(), "original touch target visible"):
		return false
	var position: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 3
		event.position = position
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	return true

func visible_amounts(world: Node) -> Array[int]:
	var amounts: Array[int] = []
	var controller: Node = world.hud.original_main_ui_controller
	if not check(is_instance_valid(controller), "installed original Main HUD"): return amounts
	if not world.hud.original_inventory_is_open():
		var hot: Node = controller._menu_scene.source_nodes[TOP.INVENTORY]
		await touch(hot.get_meta("source_button")._input_area)
		await frames()
	var view: RefCounted = controller._inventory_view
	var bag: Control = world.hud.lineage_inventory_ui
	var entries: Dictionary = view._slots.entries()
	if not check(entries.get("ok", false), "original bag opened with real owned rows"): return amounts
	for row: Dictionary in entries.current_display_rows:
		var ref: String = row.reference
		if bag._enhanced_display_name(bag._find_item_record(ref), ref) != LABEL: continue
		var slot: Dictionary = view._hits.get(ref, {})
		if slot.is_empty():
			check(false, "matching row has an original slot")
			continue
		await touch(slot.control)
		check(bag.selected_item == ref and bag._bag_display_amount(ref) == row.amount,
			"touch selects this row and its actual quantity")
		amounts.append(int(row.amount))
	amounts.sort()
	print("POWDER_BAG_ROWS ", amounts)
	return amounts

func seed_profile(world: Node) -> void:
	if not check(not world.inventory.has(LABEL) and not world.inventory.has(CANONICAL), "isolated empty powder profile"): return
	check(world._save_game(true) == OK, "existing character checkpoint")
	world._load_game(true)
	await frames()
	check(world.legacy_item_marker.get("schema") == 2, "ordinary old migration already ran")
	var previous: Dictionary = world._catalog_item_from_source_id(str(ITEM))
	if not check(previous.get("source") == "inven" and previous.get("name") == LABEL, "real historical shop catalog row"): return
	# Persist the former shop aggregate under the key the original catalog
	# actually supplied, alongside a receipt from the real dissolution supplier.
	world.inventory[previous.name] = 2202
	var issued: Dictionary = SUPPLY.stage(world, [{"item_class_id":ITEM, "amount":3, "bless_raw":1, "enchant":0}],
		{"kind":"powder_bag_regression", "item_class_id":ITEM})
	if not check(issued.get("ok", false), "normal production supplier issues three receipted units"): return
	world.inventory = issued.overrides.inventory
	world.item_instances = issued.overrides.item_instances
	check(world._save_game(true) == OK, "persist historical aggregate and independent receipt")

func open_powder_box(world: Node) -> void:
	var issued: Dictionary = SUPPLY.stage(world, [{"item_class_id":ITEM, "amount":3, "bless_raw":1, "enchant":0}],
		{"kind":"powder_bag_regression"})
	if not check(issued.get("ok", false), "existing powder is granted by the native owner"): return
	world.inventory = issued.overrides.inventory
	world.item_instances = issued.overrides.item_instances
	var box: Dictionary = CASH.box_record(world, BOX)
	var spec: Dictionary = CASH.definition(BOX)
	var rewards: Array = spec.get("entries", [])
	if not check(box.get("source") == CASH.TAG and spec.get("lucky_bag_class_id") == 82011 and rewards.size() == 1,
		"the 523 cash box is connected to its original LuckyBag"): return
	check(rewards[0].item_class_id == ITEM and rewards[0].amount == BOX_REWARD and rewards[0].bless == 1 and rewards[0].enchant == 0,
		"the box has the same original material, blessing and enchant as the existing stack")
	world.inventory[box.name] = 1
	var rejected: Dictionary = rewards[0].duplicate()
	rejected.bless = 2
	check(not CASH.open(world, box.name, [rejected]).ok and world.inventory.get(box.name) == 1 and world.inventory.get(CANONICAL) == 3,
		"an unproven blessing cannot go into the ordinary powder stack or debit the box")
	world.source_shop.save_blocked = true
	var denied: Dictionary = CASH.open(world, box.name, rewards)
	world.source_shop.save_blocked = false
	check(not denied.ok and world.inventory.get(box.name) == 1 and REFINE.powder_owned(world).total == 3,
		"the save guard preserves the unopened box and existing stacks")
	world._refresh_inventory_hud()
	check(await visible_amounts(world) == [3], "the bag shows the existing stack before opening the box")
	var hud: Node = world.hud
	var view: RefCounted = hud.original_main_ui_controller._inventory_view
	var bag: Control = hud.lineage_inventory_ui
	var slot: Dictionary = view._hits.get(box.name, {})
	if not await touch(slot.get("control")): return
	check(bag.selected_item == box.name and bag.item_action_armed(box.name), "first original slot touch selects and arms the box")
	var owned_cards: Dictionary = world.card_draw_fusion.owned["변신"]
	var card_state: Dictionary = world.card_draw_fusion.export_state()
	if not await touch(view._hits.get(box.name, {}).get("control")): return
	await frames()
	check(not world.inventory.has(box.name), "second original slot touch consumes one box")
	check(world.card_draw_fusion.export_state() == card_state and is_same(world.card_draw_fusion.owned["변신"], owned_cards),
		"a material-only opening keeps the existing card state and collection objects")
	check(await visible_amounts(world) == [3 + BOX_REWARD] and not world.inventory.has(LABEL), "the open bag shows one combined stack immediately")
	check(world.titles.powder_count() == 3 + BOX_REWARD and REFINE.powder_owned(world).total == 3 + BOX_REWARD,
		"title and refinement can spend the merged box reward")
	check(receipt_quantities(world) == [3, BOX_REWARD], "the merge accounts for both original quantities")
	check(world._save_game(true) == OK, "write the opened box and the merged ownership")

func auto_pickup(world: Node) -> void:
	# A full field pack is optional. Only the empty test field's walkable
	# geometry is synthetic. The title's NPC row, roll, floor and auto pickup
	# all go through World and the ordinary inventory publication.
	if world.field_map == null:
		world.astar = AStarGrid2D.new()
		world.astar.region = Rect2i(0, 0, 16, 16)
		world.astar.update()
		world.player.global_position = world._cell_to_world(Vector2i(8, 8))
	var npc_id: int = int(world.titles.source.powder_npcs.keys()[0])
	var monster := TwilightMonster.new()
	monster.position = world.player.global_position
	monster.source_m_npc_id = npc_id
	monster.source_m_original = world.titles.source.powder_npcs[npc_id]
	world.rng.seed = 523117544
	var drop: Button
	for attempt: int in 200:
		world._roll_drop(monster)
		for uid: String in world.ground_loot.records:
			if world.ground_loot.records[uid].item_name == CANONICAL:
				drop = world.ground_loot.views[uid]
				break
		if is_instance_valid(drop): break
	monster.free()
	if not check(is_instance_valid(drop), "an eligible original NPC's title drop spawned"): return
	drop.set("visible_since", Time.get_ticks_msec() - 1000)
	world.player.auto_enabled = true
	check(world._run_auto_ground_pickup() and not world.ground_loot.valid_view(drop), "automatic combat pickup takes the actual visible drop")
	world.player.auto_enabled = false
	await frames()

func receipt_quantities(world: Node) -> Array[int]:
	var amounts: Array[int] = []
	var owned: Dictionary = REFINE.powder_owned(world)
	if not check(owned.stacks.size() == 1, "exactly one spendable receipt"): return amounts
	var receipt: Dictionary = owned.stacks[0].owned.receipt
	var journal: Dictionary = world.consumable_service.export_state().get(STOCK.MERGES, {})
	var merged: Dictionary = journal.get(receipt.origin.get("merge_id", ""), {})
	for part: Dictionary in merged.get("components", []):
		check(part.receipt.item_class_id == ITEM and part.receipt.bless_raw == 1, "component retains source identity and blessing")
		amounts.append(int(part.remaining_quantity))
		if part.remaining_quantity == 2202:
			check(part.receipt.origin.get("kind") == "TWILIGHT_existing_shop_powder_117544", "only historical shop stock was reconciled")
	amounts.sort()
	return amounts

func compatible_ownership(world: Node) -> void:
	var old_inventory: Dictionary = world.inventory.duplicate()
	var old_instances: Dictionary = world.item_instances.duplicate()
	var old_locks: Dictionary = world.ui_preferences.item_locks.duplicate()
	var old_levels: Dictionary = world.enhancement_levels.duplicate()
	world.inventory[LABEL] = 2
	var digest: String = FileAccess.get_sha256(world.save_path())
	for ref: String in [LABEL, LABEL + "@@@orphan", CANONICAL]:
		world.ui_preferences.item_locks[ref] = true
		check(not world.titles.reconcile_powder_stock() and world.inventory[LABEL] == 2
			and world.item_instances == old_instances, "preserve retained lock " + ref)
		world.ui_preferences.item_locks.erase(ref)
	world.item_instances["foreign-owner"] = {"name":LABEL, "record":{"sourceId":"unknown"}}
	check(not world.titles.reconcile_powder_stock() and world.item_instances.has("foreign-owner"), "physical item with another identity is preserved")
	world.item_instances = old_instances.duplicate()
	world.enhancement_levels[LABEL] = 7
	check(not world.titles.reconcile_powder_stock(), "enhanced historical entry is preserved")
	world.enhancement_levels = old_levels
	for bad: Variant in [-1, 1.5, "2", 9999999]:
		world.inventory[LABEL] = bad
		check(not world.titles.reconcile_powder_stock() and world.inventory[LABEL] == bad, "malformed or over-cap quantity preserved")
	world.inventory = old_inventory
	world.ui_preferences.item_locks = old_locks
	check(world.item_instances == old_instances and FileAccess.get_sha256(world.save_path()) == digest, "denials do not write the save or change existing receipts")
	var token: Dictionary = {"unit_id":4, "class_id":ITEM, "amount":2}
	var pending: Dictionary = world.source_shop._grant([token], world.inventory.duplicate(), world.gold,
		world.item_instances.duplicate(), world.next_item_instance_id)
	check(pending.get("ok", false) and not pending.inventory.has(LABEL) and int(pending.inventory[CANONICAL]) == int(old_inventory[CANONICAL])+2
		and pending.instances.size() == old_instances.size()+1, "historical pending order is delivered with a new physical receipt")
	check(world.inventory == old_inventory and world.item_instances == old_instances, "staged order does not change player ownership")

func actual(phase: String) -> void:
	root.size = Vector2i(2048, 919)
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.save_timer = -100000
	if check(QA.enter_game(world), "normal entry from persisted character"):
		await frames()
		world.player.set_physics_process(false)
		world.field_population.set_process(false)
		var item: Dictionary = SOURCE.row("ItemClass", ITEM)
		if check(item.get("TestItem") == false and item.get("ID") == ITEM and world.titles.source.powder_record.get("source_item_row") == item, "original startup source bound before inventory"):
			match phase:
				"seed": await seed_profile(world)
				"box": await open_powder_box(world)
				"box_reload":
					check(await visible_amounts(world) == [3 + BOX_REWARD], "the same combined row survives a cold restart")
					check(REFINE.powder_owned(world).total == 3 + BOX_REWARD and receipt_quantities(world) == [3, BOX_REWARD],
						"the box has not credited or consumed any extra units across restart")
				"combat", "control":
					var control: bool = phase == "control"
					check(await visible_amounts(world) == ([3, 2202] if control else [2205]), "all powder rows after cold load")
					await auto_pickup(world)
					check(await visible_amounts(world) == ([4, 2202] if control else [2206]), "all powder rows after one visible auto pickup")
					if not control:
						check(world.titles.powder_count() == 2206 and REFINE.powder_owned(world).total == 2206, "title and refinement agree on spendable units")
						check(world._save_game(true) == OK, "save corrected live acquisition")
				"reload":
					check(await visible_amounts(world) == [2206] and not world.titles.reconcile_powder_stock(), "cold reload is idempotent")
					check(world.titles.powder_count() == 2206 and REFINE.powder_owned(world).total == 2206, "reload preserves both consumers")
					check(receipt_quantities(world) == [1, 3, 2202], "all three acquisition quantities survive save and restart")
					compatible_ownership(world)
				_: check(false, "unknown private QA phase")
	world.queue_free()
	await frames()

func run() -> void:
	var phase: String = OS.get_environment("TWILIGHT_POWDER_BAG_PHASE")
	if phase.is_empty():
		check(not MIGRATION.is_legacy(null, LABEL), "former registered supplier is never deleted by name")
		check(not MIGRATION.is_legacy(null, LABEL + " · 원본#?"), "damaged ID is not guessed by legacy cleanup")
	else:
		await actual(phase)
	print("NATIVE_ADVANCED_POWDER_COLD_RESULT ", JSON.stringify({"phase":phase,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
