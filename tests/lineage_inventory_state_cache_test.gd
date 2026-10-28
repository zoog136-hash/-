extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String] = []
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bag: TwilightInventoryUI = preload("res://scripts/ui/lineage_inventory_ui.gd").new()
	host.add_child(bag)
	await process_frame
	bag.set_catalog_data({"아이템":[{"name":"검","grade":"일반","type":"무기"}]},{})
	bag.set_inventory({"검":1})
	bag.set_character_state({"gold":1,"item_instances":{}})
	bag.show_inventory()
	var first: Button = bag.slot_buttons.get("검")
	if first == null:failures.append("initial item missing")
	var first_bind_count: int=bag.legacy_bind_updates
	bag.set_character_state({"gold":100,"hp":5,"experience":30,"item_instances":{}})
	if not is_same(first,bag.slot_buttons.get("검")) or bag.legacy_bind_updates!=first_bind_count:failures.append("vitals rebuilt legacy item grid")
	bag.set_inventory({"검":1})
	if not is_same(first,bag.slot_buttons.get("검")):failures.append("identical inventory rebuilt legacy grid")
	bag.set_character_state({"gold":100,"item_instances":{},"item_locks":{"검":true}})
	if not is_same(first,bag.slot_buttons.get("검")) or bag.legacy_bind_updates<=first_bind_count:failures.append("item lock revision did not rebind pooled slot")
	print("LINEAGE_INVENTORY_STATE_CACHE_RESULT ",JSON.stringify({"failures":failures}))
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
