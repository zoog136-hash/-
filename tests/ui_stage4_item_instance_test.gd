extends SceneTree

# Stage 4 regression: renewed UI must not collapse physically distinct equipment.
# All gameplay mutations are through the original world/HUD methods and signals.
var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		print("UI_STAGE4_FAIL: " + label)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false, "Main.tscn missing")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	for frame: int in range(5):
		await process_frame
	var hud: Node = world.get_node("HUD")
	var inventory_ui: Node = hud.get("lineage_inventory_ui") as Node
	_check(inventory_ui != null, "Renewed inventory is connected")
	_check(hud.has_signal("enhancement_requested"), "Existing enhancement signal survived")
	_check(hud.has_signal("inventory_item_activated"), "Existing inventory signal survived")
	_check(hud.has_signal("shop_buy_requested"), "Existing shop signal survived")
	if inventory_ui == null:
		world.queue_free()
		await process_frame
		_finish()
		return

	world.set("equipped_items", {})
	world.set("inventory", {"낡은 장검": 2, "무기 마법 주문서 (각인)": 5, "HP 물약": 10})
	world.set("item_instances", {})
	world.set("enhancement_levels", {})
	world.set("next_item_instance_id", 1)
	world.call("_sync_item_instances")
	var instances: Dictionary = world.get("item_instances") as Dictionary
	var ids: Array[String] = []
	for raw_id: Variant in instances.keys():
		var item: Variant = instances[raw_id]
		if item is Dictionary and str((item as Dictionary).get("name", "")) == "낡은 장검":
			ids.append(str(raw_id))
	ids.sort()
	_check(ids.size() == 2, "Two physical swords should have two IDs")
	if ids.size() < 2:
		world.queue_free()
		await process_frame
		_finish()
		return
	var first: String = "낡은 장검@@@" + ids[0]
	var second: String = "낡은 장검@@@" + ids[1]
	world.call("_update_hud")
	await process_frame
	var slots: Dictionary = inventory_ui.get("slot_buttons") as Dictionary
	_check(slots.has(first) and slots.has(second), "Renewed inventory has distinct buttons for identical swords")
	_check(int((world.get("inventory") as Dictionary).get("낡은 장검", 0)) == 2, "UI did not change aggregate item count")
	_check(bool(inventory_ui.call("_is_item_equipped", first)) == false, "First sword starts unequipped")
	_check(int(inventory_ui.call("_enhance_level", first)) == 0, "First sword starts +0")
	_check(int(inventory_ui.call("_enhance_level", second)) == 0, "Second sword starts +0")

	# Existing world enhancement rules must not leak levels into the other physical item.
	world.call("_attempt_enhancement", "무기 마법 주문서 (각인)", first)
	world.call("_update_hud")
	await process_frame
	_check(int(inventory_ui.call("_enhance_level", first)) == 1, "First sword reflects +1 after world enhancement")
	_check(int(inventory_ui.call("_enhance_level", second)) == 0, "Second sword remains +0")
	inventory_ui.call("_select_item", second)
	_check(str(inventory_ui.get("selected_item")) == second, "Selected equipment keeps exact instance reference")
	var detail_name: Label = inventory_ui.get("detail_name") as Label
	_check(detail_name != null and not detail_name.text.begins_with("+1"), "Unenhanced second sword detail must not show first sword's level")

	# The renewed forge must emit the selected candidate's target_id, not just its name.
	var candidates: Array = world.call("_enhancement_candidates", "weapon", "normal")
	_check(candidates.size() == 2, "Forge sees both physical swords")
	var recorded: Dictionary = {"target": ""}
	hud.enhancement_requested.connect(func(_scroll: String, target: String) -> void: recorded["target"] = target)
	hud.call("open_enhancement", "무기 마법 주문서 (각인)", candidates)
	await process_frame
	var workspace: Node = hud.get("workspace") as Node
	var list_node: ItemList = workspace.find_child("EnhancementChoices", true, false) as ItemList
	var button: Button = workspace.find_child("EnhanceAction", true, false) as Button
	_check(list_node != null and button != null, "Renewed forge displays target list and action")
	if list_node != null and button != null and list_node.item_count == 2:
		list_node.select(1)
		list_node.item_selected.emit(1)
		button.pressed.emit()
		await process_frame
		_check(str(recorded["target"]).contains("@@@"), "Forge submits physical target_id")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("UI_STAGE4_ITEM_INSTANCE_OK %d checks" % assertions)
		quit(0)
	else:
		print("UI_STAGE4_ITEM_INSTANCE_FAILED %d/%d" % [failures.size(), assertions])
		quit(1)
