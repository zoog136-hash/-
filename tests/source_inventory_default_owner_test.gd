extends SceneTree

const INVENTORY = preload("res://scripts/ui/renewal_inventory.gd")
const SLOTS = preload("res://scripts/ui/original_ui/source_main_inventory_slots.gd")
const ROWS: int = 500
const SWORD: String = "Fixture sword"
var checks: int = 0
var failures: Array[String] = []

class ObservedInventory extends INVENTORY:
	var lookups: int = 0
	var former_preparation: bool = false
	func _find_item_record(reference: String) -> Dictionary:
		lookups += 1
		return super._find_item_record(reference)
	func source_inventory_entries_for_view() -> Array[Dictionary]:
		if not former_preparation: return super.source_inventory_entries_for_view()
		var prepared: Variant = prepare_source_inventory_model()
		return prepared if prepared is Array else _inventory_entries()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr(label)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var host := Control.new()
	root.add_child(host)
	var content := Control.new()
	host.add_child(content)
	var bag := ObservedInventory.new()
	content.add_child(bag)
	var source := SLOTS.new()
	source._bag = weakref(bag)
	var catalog: Array = []
	var inventory: Dictionary = {}
	for i: int in range(ROWS):
		var name: String = "Fixture %03d" % (ROWS - i)
		catalog.append({"name":name,"grade":"일반","slot":"other"})
		inventory[name] = i + 1
	var sword: Dictionary = {"name":SWORD,"grade":"희귀","slot":"weapon"}
	catalog.append(sword)
	inventory[SWORD] = 2
	bag.set_catalog_data({"아이템":catalog},{})
	bag.set_inventory(inventory)
	bag.set_character_state({"item_instances":{
		"20":{"name":SWORD,"record":sword,"source_native_stack_quantity":1},
		"9":{"name":SWORD,"record":sword,"source_native_stack_quantity":1}}})
	var duration_old: Array[int] = []
	var duration_new: Array[int] = []
	var fast: Dictionary
	for sample: int in range(9):
		bag.inventory_grid_dirty = true
		bag.former_preparation = false
		bag.lookups = 0
		var started: int = Time.get_ticks_usec()
		fast = source.entries()
		duration_new.append(Time.get_ticks_usec() - started)
		var fast_lookups: int = bag.lookups
		bag.inventory_grid_dirty = true
		bag.former_preparation = true
		bag.lookups = 0
		started = Time.get_ticks_usec()
		var prior: Dictionary = source.entries()
		duration_old.append(Time.get_ticks_usec() - started)
		check(fast == prior and fast.ok and fast_lookups == 1 and bag.lookups == ROWS + 3,
			"native cold model drops only the offscreen/default classification reads; exact model matches former path")
	check(fast.current_display_rows.size() == ROWS + 2 and fast.current_display_rows[0].reference == "Fixture 500"
		and fast.current_display_rows[-2].reference == SWORD + "@@@9" and fast.current_display_rows[-1].reference == SWORD + "@@@20",
		"acquisition order and both opaque physical references preserved")
	var picked: Dictionary = source.select_reference(SWORD + "@@@9")
	check(picked.ok and bag.selected_item == SWORD + "@@@9", "fresh native action admission still uses exact physical ownership")
	bag.former_preparation = false
	bag.search_line.text = "sword"
	bag.inventory_grid_dirty = true
	var searched: Dictionary = source.entries()
	check(searched.ok and searched.current_display_rows.size() == 2, "native text filter preserves both matching physical rows")
	bag.search_line.text = "   "
	bag._set_category("장비")
	var categorized: Dictionary = source.entries()
	check(categorized.ok and categorized.current_display_rows == searched.current_display_rows,
		"non-default category still validates existing catalog filter with empty normalized query")
	bag._set_category("전체")
	var before: Dictionary = source.entries()
	inventory.erase(SWORD)
	bag.set_inventory(inventory)
	bag.set_character_state({"item_instances":{}})
	var after: Dictionary = source.entries()
	check(before.owned_by_reference.has(SWORD + "@@@9") and after.ok and not after.owned_by_reference.has(SWORD + "@@@9")
		and not source.select_reference(SWORD + "@@@9").ok, "removed physical row cannot be seen or activated through a former hit")
	duration_old.sort()
	duration_new.sort()
	print("SOURCE_INVENTORY_DEFAULT_OWNER_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
		"fixture_rows":ROWS+2,"samples":duration_old.size(),"former_median_us":duration_old[4],"current_median_us":duration_new[4]}))
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
