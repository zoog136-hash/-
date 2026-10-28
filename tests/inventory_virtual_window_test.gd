extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String]=[]
	var a:=Control.new();var b:=Control.new();var c:=Control.new()
	root.add_child(a);a.add_child(b);b.add_child(c)
	for node: Control in [a,b,c]:node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bag:=preload("res://scripts/ui/renewal_inventory.gd").new()
	c.add_child(bag)
	await process_frame
	var catalog: Array=[]
	var inventory: Dictionary={}
	for i: int in range(100):
		var name: String="검 %03d" % i
		catalog.append({"name":name,"grade":"일반","type":"무기"})
		inventory[name]=1
	bag.set_catalog_data({"아이템":catalog},{})
	bag.set_character_state({"item_instances":{"17":{"name":"검 050","level":2},"18":{"name":"검 050","level":0}}})
	inventory["검 050"]=2
	bag.set_inventory(inventory)
	bag.show_inventory()
	await process_frame
	bag._refresh_visible_window()
	if bag.sorted_references.size()!=101 or not bag.sorted_references.has("검 050@@@17") or not bag.sorted_references.has("검 050@@@18"):failures.append("physical instance IDs lost")
	if bag.slot_buttons.size()>=100 or bag.slot_buttons.is_empty():failures.append("window did not bound visible slots")
	var created: int=bag.slot_nodes_created
	bag.grid_scroll.scroll_vertical=800
	await process_frame
	bag._refresh_visible_window()
	if bag.visible_first_row<=0:failures.append("scroll did not advance window")
	if bag.slot_nodes_created>created+16:failures.append("scroll recreated full grid")
	var reference: String="검 050@@@18"
	bag.selected_item=reference
	bag._refresh_inventory_grid()
	await process_frame
	if bag.selected_item!=reference:failures.append("selection lost after refresh")
	if bag.sorted_references.size()!=101:failures.append("refresh lost records")
	print("INVENTORY_VIRTUAL_WINDOW_RESULT ",JSON.stringify({"failures":failures,"created":bag.slot_nodes_created,"total":bag.sorted_references.size()}))
	a.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
