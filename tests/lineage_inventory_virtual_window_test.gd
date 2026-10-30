extends SceneTree

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var failures: Array[String]=[]
	var host:=Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bag: TwilightInventoryUI=preload("res://scripts/ui/lineage_inventory_ui.gd").new()
	host.add_child(bag)
	await process_frame
	var catalog: Array=[]
	var inventory: Dictionary={}
	for index: int in range(100):
		var item_name: String="검 %03d" % index
		catalog.append({"name":item_name,"grade":"일반","type":"무기"})
		inventory[item_name]=1
	inventory["검 050"]=2
	bag.set_catalog_data({"아이템":catalog},{})
	var state: Dictionary={"item_instances":{"17":{"name":"검 050","level":2},"18":{"name":"검 050","level":0}}}
	bag.set_character_state(state)
	bag.set_inventory(inventory)
	bag.show_inventory()
	await process_frame
	if bag.legacy_rows.size()!=101 or bag.slot_buttons.size()>=100:failures.append("legacy window materialized all entries")
	var first_created: int=bag.legacy_slot_nodes_created
	bag.legacy_scroll.scroll_vertical=800
	await process_frame
	bag._refresh_legacy_visible_window()
	if bag.legacy_scroll.scroll_vertical<500 or bag.slot_buttons.has("검 000"):failures.append("legacy scroll did not move visible window")
	if bag.legacy_slot_nodes_created>first_created+20:failures.append("scroll recreated unbounded slots")
	var reference: String="검 050@@@18"
	if not bag.slot_buttons.has(reference):failures.append("selected physical ID was not visible at fixture scroll")
	else:
		var selected_button: Button=bag.slot_buttons[reference]
		if selected_button.pressed.get_connections().size()!=1:failures.append("reused slot has duplicate pressed handlers")
		selected_button.pressed.emit()
		if bag.selected_item!=reference:failures.append("reused slot bound wrong physical ID")
	var before_bind: int=bag.legacy_bind_updates
	state=state.duplicate(true)
	state.item_instances["18"].level=3
	bag.set_character_state(state)
	await process_frame
	if bag.selected_item!=reference or bag.legacy_scroll.scroll_vertical<500:failures.append("item change lost selection or scroll")
	if bag.legacy_bind_updates<=before_bind:failures.append("changed physical instance did not rebind")
	if bag.legacy_slot_nodes_created>first_created+20:failures.append("item change recreated all controls")
	print("LINEAGE_INVENTORY_WINDOW_RESULT ",JSON.stringify({"failures":failures,"entries":bag.legacy_rows.size(),"created":bag.legacy_slot_nodes_created,"visible":bag.slot_buttons.size()}))
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
