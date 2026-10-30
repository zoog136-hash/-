extends SceneTree

# The bag stacks items in acquisition order and never re-sorts on its own; the
# "정렬" button sorts once (grade, then name, then physical ID) and keeps it.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String] = []
	var holder := Control.new()
	root.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bag = preload("res://scripts/ui/renewal_inventory.gd").new()
	holder.add_child(bag)
	await process_frame
	bag.set_catalog_data({"아이템":[
		{"name":"사과", "grade":"일반"}, {"name":"전설검", "grade":"전설"},
		{"name":"갑옷", "grade":"희귀"}, {"name":"가죽", "grade":"일반"}, {"name":"영웅반지", "grade":"영웅"}]}, {})
	bag.set_character_state({"item_instances":{}})
	var inventory: Dictionary = {"사과":3, "전설검":1, "가죽":2}
	bag.set_inventory(inventory)
	bag.show_inventory()
	await process_frame
	if bag.sorted_references != ["사과", "전설검", "가죽"]:
		failures.append("initial order is not acquisition order: %s" % str(bag.sorted_references))
	# New pickups stack at the end, never re-sorted by grade or name.
	inventory["영웅반지"] = 1
	inventory["갑옷"] = 1
	bag.set_inventory(inventory.duplicate())
	if bag.sorted_references != ["사과", "전설검", "가죽", "영웅반지", "갑옷"]:
		failures.append("pickups did not stack at the end: %s" % str(bag.sorted_references))
	# A count change keeps the position.
	inventory["사과"] = 9
	bag.set_inventory(inventory.duplicate())
	if bag.sorted_references[0] != "사과": failures.append("stack size change moved the item")
	# The sort button sorts once by grade (highest first), then name.
	bag.find_child("InventorySort", true, false).emit_signal("pressed")
	var sorted_expected: Array[String] = ["전설검", "영웅반지", "갑옷", "가죽", "사과"]
	if bag.sorted_references != sorted_expected:
		failures.append("sort button order wrong: %s" % str(bag.sorted_references))
	# After sorting, a used-up item disappears and comes back at the end.
	inventory.erase("갑옷")
	bag.set_inventory(inventory.duplicate())
	inventory["갑옷"] = 1
	bag.set_inventory(inventory.duplicate())
	if bag.sorted_references != ["전설검", "영웅반지", "가죽", "사과", "갑옷"]:
		failures.append("re-acquired item did not stack at the end: %s" % str(bag.sorted_references))
	# Drag reorder swaps within the full order, even while a filter hides items.
	bag.reorder("전설검", "사과")
	if bag.sorted_references != ["사과", "영웅반지", "가죽", "전설검", "갑옷"]:
		failures.append("reorder swap wrong: %s" % str(bag.sorted_references))
	if bag.find_child("InventorySort", true, false) is OptionButton: failures.append("automatic sort selector still present")
	print("INVENTORY_ORDER_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
