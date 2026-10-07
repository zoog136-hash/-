extends SceneTree

const INVENTORY_UI := preload("res://scripts/ui/lineage_inventory_ui.gd")

var failures: Array[String] = []
var activated_item: String = ""
var quick_item: String = ""

func _initialize() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	failures.append(message)
	print("INVENTORY UI FAIL: " + message)

func _run() -> void:
	var ui := INVENTORY_UI.new()
	ui.item_activate_requested.connect(func(item_name: String) -> void: activated_item = item_name)
	ui.quickslot_requested.connect(func(item_name: String) -> void: quick_item = item_name)
	get_root().add_child(ui)
	await process_frame

	ui.call("set_catalog_data", {
		"아이템":[
			{"name":"낡은 장검","grade":"일반","type":"한손검","slot":"weapon","desc":"초보자용 장검","atk":5,"hit":0,"weight":50},
			{"name":"HP 물약","grade":"일반","type":"소모품","slot":"consumable","desc":"HP 55 회복","heal":55,"weight":3}
		]
	}, {"아이템":{}})
	ui.call("set_character_state", {"gold":2131928})
	ui.call("set_inventory", {"낡은 장검":1,"HP 물약":119})
	ui.call("show_inventory")
	await process_frame

	var panel: PanelContainer = ui.get("inventory_panel") as PanelContainer
	var grid: GridContainer = ui.get("item_grid") as GridContainer
	var capacity: Label = ui.get("capacity_label") as Label
	var gold: Label = ui.get("gold_label") as Label
	if panel == null or not panel.visible:
		_fail("inventory panel did not open")
	if grid == null or grid.get_child_count() < 2:
		_fail("inventory grid did not create item slots")
	if capacity == null or capacity.text != "2 / 104":
		_fail("capacity indicator mismatch")
	if gold == null or gold.text.find("2,131,928") < 0:
		_fail("gold indicator mismatch")

	ui.call("_select_item", "낡은 장검")
	await process_frame
	var detail_name: Label = ui.get("detail_name") as Label
	var detail_text: RichTextLabel = ui.get("detail_text") as RichTextLabel
	if detail_name == null or detail_name.text != "낡은 장검":
		_fail("selected item name not shown")
	if detail_text == null or detail_text.text.find("공격력") < 0:
		_fail("weapon detail stats not shown")
	if detail_text == null or detail_text.text.find("무게") < 0:
		_fail("item weight not shown when present")

	ui.call("_activate_selected")
	if activated_item != "낡은 장검":
		_fail("item activation signal mismatch")

	ui.call("_select_item", "HP 물약")
	await process_frame
	var action_button: Button = ui.get("detail_action") as Button
	var quick_button: Button = ui.get("quick_button") as Button
	if action_button == null or action_button.text != "사용":
		_fail("consumable action button should say 사용")
	if quick_button == null or quick_button.disabled:
		_fail("consumable quickslot button should be enabled")
	ui.call("_quickslot_selected")
	if quick_item != "HP 물약":
		_fail("quickslot signal mismatch")

	ui.call("_set_category", "장비")
	await process_frame
	if grid.get_child_count() != 1:
		_fail("equipment category filter mismatch")

	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("LINEAGE_INVENTORY_UI_SMOKE_OK")
		quit(0)
	else:
		print("LINEAGE_INVENTORY_UI_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
