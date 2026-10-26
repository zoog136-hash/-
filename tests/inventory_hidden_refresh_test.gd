extends SceneTree

const INVENTORY = preload("res://scripts/ui/renewal_inventory.gd")
const SWORD_NAME: String = "갱신 검"
const POTION_NAME: String = "갱신 물약"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("INVENTORY_HIDDEN_REFRESH_FAIL: " + label)

func _run() -> void:
	# Match the bag's three-parent workspace shape without starting the game.
	var host := Control.new()
	host.size = Vector2(640, 600)
	root.add_child(host)
	var content := Control.new()
	host.add_child(content)
	var mount := Control.new()
	content.add_child(mount)
	var bag := INVENTORY.new()
	mount.add_child(bag)
	await process_frame
	var created: Dictionary = {"slots": 0}
	bag.item_grid.child_entered_tree.connect(func(_child: Node) -> void: created.slots += 1)
	var sword: Dictionary = {"sourceId":"inventory-refresh-sword", "name":SWORD_NAME, "grade":"일반", "type":"한손검", "slot":"weapon", "image_path":"res://assets/ui/potionRed.png"}
	var potion: Dictionary = {"sourceId":"inventory-refresh-potion", "name":POTION_NAME, "grade":"일반", "type":"소모품", "slot":"consumable", "image_path":"res://assets/ui/potionRed.png"}
	bag.set_catalog_data({"아이템":[sword,potion]}, {"아이템":{}})
	var state: Dictionary = {"gold":0, "current_weight":0, "max_weight":100, "equipped_items":{}, "enhancement_levels":{}, "item_locks":{}, "item_instances":{
		"1":{"name":SWORD_NAME, "level":0, "record":sword},
		"2":{"name":SWORD_NAME, "level":0, "record":sword}
	}}
	var counts: Dictionary = {SWORD_NAME:2, POTION_NAME:1}
	# The world sends state then counts on each pickup. Neither call may build
	# hidden slots, but shop balances and instance queries must stay current.
	for index: int in range(1, 41):
		state.gold = index * 100
		state.current_weight = index
		state.item_instances["1"].level = index % 5
		counts[POTION_NAME] = index
		bag.set_character_state(state)
		bag.set_inventory(counts)
	_check(created.slots == 0 and bag.item_grid.get_child_count() == 0, "40 hidden pickup updates allocate no slot controls")
	_check(bag.inventory == counts, "hidden inventory quantities stay current for the shop")
	_check(bag.character_state.item_instances.size() == 2, "hidden state preserves both physical swords")
	_check(bag.gold_label.text.contains("4,000"), "hidden wallet label is current")
	_check(is_equal_approx(bag.weight_gauge.value, 40.0), "hidden weight is current")
	_check(bag.inventory_grid_dirty, "hidden changes are pending for first open")

	bag.show_inventory()
	await process_frame
	_check(bag.slot_buttons.size() == 3, "first open renders two physical swords and a stack")
	_check(bag.slot_buttons.has(SWORD_NAME + "@@@1") and bag.slot_buttons.has(SWORD_NAME + "@@@2"), "first open retains exact physical IDs")
	_check(created.slots == bag.item_grid.get_child_count(), "show plus visibility signal builds only once")
	_check(not bag.inventory_grid_dirty, "first open consumes pending grid refresh")
	var slots_before: int = created.slots
	var first_button_id: int = bag.slot_buttons[SWORD_NAME + "@@@1"].get_instance_id()
	state.gold = 9876
	state.current_weight = 43
	bag.set_character_state(state)
	await process_frame
	_check(created.slots == slots_before, "currency and weight updates do not rebuild visible slots")
	_check(bag.slot_buttons[SWORD_NAME + "@@@1"].get_instance_id() == first_button_id, "currency updates preserve button identity")
	_check(bag.gold_label.text.contains("9,876") and is_equal_approx(bag.weight_gauge.value, 43.0), "currency and weight labels still update")

	bag._select_item(POTION_NAME)
	bag.open_detail()
	_check(bag.detail_panel.visible, "selected item detail can open")
	bag.hide_inventory()
	_check(not bag.detail_panel.visible, "hiding the bag closes its detail panel")
	for index: int in range(41, 61):
		state.item_instances["1"].level = index % 7
		counts[POTION_NAME] = index
		bag.set_character_state(state)
		bag.set_inventory(counts)
	_check(created.slots == slots_before, "updates after a prior open still allocate no hidden slots")
	_check(bag.selected_item == POTION_NAME and bag.inventory[POTION_NAME] == 60, "hidden quantity updates preserve selection and data")
	counts.erase(POTION_NAME)
	counts[SWORD_NAME] = 1
	state.item_instances.erase("2")
	bag.set_character_state(state)
	bag.set_inventory(counts)
	_check(bag.selected_item.is_empty(), "removing the selected stack clears selection while hidden")
	bag.show_inventory()
	await process_frame
	_check(bag.slot_buttons.size() == 1 and bag.slot_buttons.has(SWORD_NAME + "@@@1"), "reopen drops removed stacks and physical instances")
	_check(bag._enhance_level(SWORD_NAME + "@@@1") == 60 % 7, "reopen uses the latest physical enhancement")
	_check(created.slots - slots_before == bag.item_grid.get_child_count(), "reopen builds pending slots once")

	# Workspace.mount can reveal an ancestor after show_inventory was called.
	host.hide()
	slots_before = created.slots
	counts[POTION_NAME] = 7
	bag.set_inventory(counts)
	bag.show_inventory()
	_check(created.slots == slots_before, "show_inventory under a hidden ancestor remains deferred")
	_check(bag.inventory[POTION_NAME] == 7, "ancestor-hidden data remains current")
	host.show()
	await process_frame
	_check(bag.slot_buttons.has(POTION_NAME), "revealing the ancestor flushes the latest inventory")
	_check(created.slots - slots_before == bag.item_grid.get_child_count(), "ancestor visibility signals build slots once")
	_check(not bag.inventory_grid_dirty, "ancestor reveal clears the pending refresh")

	# Hidden filters are also applied on the next real opening.
	bag.hide_inventory()
	slots_before = created.slots
	bag._set_category("장비")
	bag.search_line.text = SWORD_NAME
	bag._on_search_changed(SWORD_NAME)
	_check(created.slots == slots_before, "hidden search and category changes do not build slots")
	bag.show_inventory()
	await process_frame
	_check(bag.slot_buttons.size() == 1 and bag.slot_buttons.has(SWORD_NAME + "@@@1"), "reopen applies pending category and search")
	bag._set_category("전체")
	bag.search_line.text = ""
	bag._on_search_changed("")
	_check(bag.slot_buttons.size() == 2, "visible filter changes still refresh synchronously")
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("INVENTORY_HIDDEN_REFRESH_OK checks=%d hidden_updates=60 hidden_slot_allocations=0" % checks)
		quit(0)
	else:
		print("INVENTORY_HIDDEN_REFRESH_FAILED %d/%d" % [failures.size(), checks])
		quit(1)
