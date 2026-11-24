extends SceneTree

const INVENTORY = preload("res://scripts/ui/renewal_inventory.gd")
const AMOUNT: int = 325
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr(label)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var frame := Control.new()
	frame.size = Vector2(640, 570)
	root.add_child(frame)
	var content := Control.new()
	frame.add_child(content)
	var bag := INVENTORY.new()
	content.add_child(bag)
	# This is the real companion/fallback grid, with no original CSB view.
	var catalog_rows: Array = []
	var inventory: Dictionary = {}
	for i: int in range(AMOUNT):
		var name: String = "Bag fixture %03d" % i
		catalog_rows.append({"name":name,"grade":"일반","type":"기타","slot":"other"})
		inventory[name] = i + 1
	var physical: Dictionary = {"name":"Fixture sword","grade":"희귀","type":"한손검","slot":"weapon"}
	inventory[physical.name] = 1
	catalog_rows.append(physical)
	bag.set_catalog_data({"아이템":catalog_rows},{})
	bag.set_inventory(inventory)
	bag.set_character_state({"item_instances":{"9":{"name":physical.name,"record":physical,"level":0}}})
	bag.show_inventory()
	await process_frame
	var reference: String = str(physical.name) + "@@@9"
	check(bag.inventory_list_rebuilds == 1 and bag.sorted_references.size() == AMOUNT + 1
		and bag.sorted_references[-1] == reference, "cold fallback opens exact acquisition order and physical ID")
	var baseline: int = bag.inventory_list_rebuilds
	var reuse_us: Array[int] = []
	var rebuild_us: Array[int] = []
	for i: int in range(9):
		bag.hide_inventory()
		var start: int = Time.get_ticks_usec()
		bag.show_inventory()
		reuse_us.append(Time.get_ticks_usec() - start)
		check(bag.inventory_list_rebuilds == baseline + i, "warm fallback does not rebuild full owner list")
		bag.hide_inventory()
		# Old behavior invalidated the model on every explicit show. Force the
		# same synchronous work against the same already-warmed fixture.
		bag.inventory_grid_dirty = true
		start = Time.get_ticks_usec()
		bag.show_inventory()
		rebuild_us.append(Time.get_ticks_usec() - start)
	check(bag.sorted_references.size() == AMOUNT + 1 and bag.slot_buttons.has("Bag fixture 000"),
		"warm opening still paints the visible slot window")
	bag.hide_inventory()
	var stored: Array = bag.local_order_store.inventory_order
	stored.remove_at(stored.size() - 1)
	stored.push_front(reference)
	baseline = bag.inventory_list_rebuilds
	bag.show_inventory()
	check(bag.inventory_list_rebuilds == baseline + 1 and bag.sorted_references[0] == reference,
		"in-place saved order change is detected without a new ownership publish")
	bag.hide_inventory()
	bag.search_line.text = "sword"
	bag.show_inventory()
	check(bag.sorted_references == [reference], "text restoration without a signal rebuilds exact filtered result")
	bag.hide_inventory()
	bag.search_line.text = ""
	bag._set_category("장비")
	check(bag.inventory_grid_dirty, "hidden filter invalidates without painting")
	bag.show_inventory()
	check(bag.sorted_references == [reference], "fallback applies pending category")
	bag.hide_inventory()
	bag._set_category("전체")
	inventory.erase(physical.name)
	inventory["Bag fixture 000"] = 777
	bag.set_inventory(inventory)
	bag.set_character_state({"item_instances":{}})
	bag.show_inventory()
	check(not bag.sorted_references.has(reference) and bag._bag_display_amount("Bag fixture 000") == 777,
		"hidden physical removal and new count show current committed state")
	bag.hide_inventory()
	baseline = bag.inventory_list_rebuilds
	catalog_rows.append({"name":"Previously unindexed","slot":"other"})
	bag.show_inventory()
	check(bag.inventory_list_rebuilds == baseline + 1, "same catalog array growing in place invalidates prep")
	bag.sort_inventory_now()
	check(bag.local_order_store.inventory_order == Array(bag.sorted_references),
		"explicit sort still writes the existing cosmetic order")
	reuse_us.sort()
	rebuild_us.sort()
	print("FALLBACK_INVENTORY_REOPEN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"fixture_owned_rows":AMOUNT+1,"sample_count":reuse_us.size(),"reuse_median_us":reuse_us[4],"force_rebuild_median_us":rebuild_us[4]}))
	frame.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
