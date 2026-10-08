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
	ui.call("set_character_state", {"gold":2131928, "equipped_items":{"weapon":{"name":"낡은 장검"}}, "enhancement_levels":{"낡은 장검":7}})
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
	var slot_buttons: Dictionary = ui.get("slot_buttons") as Dictionary
	var sword_slot: Button = slot_buttons.get("낡은 장검") as Button
	if sword_slot == null or not sword_slot.text.begins_with("E"):
		_fail("equipped item is missing E marker")
	if sword_slot == null or sword_slot.text.find("+7") < 0:
		_fail("enhancement level is missing from slot")

	ui.call("_select_item", "낡은 장검")
	await process_frame
	var detail_name: Label = ui.get("detail_name") as Label
	var detail_text: RichTextLabel = ui.get("detail_text") as RichTextLabel
	if detail_name == null or detail_name.text.find("낡은 장검") < 0:
		_fail("selected item name not shown")
	if detail_name == null or detail_name.text.find("+7") < 0:
		_fail("enhancement level not shown in detail name")
	if detail_text == null or detail_text.text.find("공격력") < 0:
		_fail("weapon detail stats not shown")
	if detail_text == null or detail_text.text.find("무게") < 0:
		_fail("item weight not shown when present")
	var detail_grade: Label = ui.get("detail_grade") as Label
	if detail_grade == null or detail_grade.text.find("장착중") < 0:
		_fail("equipped state not shown in detail panel")
	var equipped_action: Button = ui.get("detail_action") as Button
	if equipped_action == null or equipped_action.text != "장착 중":
		_fail("equipped item action state mismatch")
	var normal_color: Color = ui.call("_grade_color", "일반")
	var hero_color: Color = ui.call("_grade_color", "영웅")
	var legend_color: Color = ui.call("_grade_color", "전설")
	var myth_color: Color = ui.call("_grade_color", "신화")
	var unique_color: Color = ui.call("_grade_color", "유일")
	if normal_color == unique_color:
		_fail("grade colors are not differentiated")
	if hero_color.r <= hero_color.b or hero_color.r <= hero_color.g:
		_fail("hero grade must be red dominant")
	if legend_color.b <= legend_color.r:
		_fail("legend grade must be purple dominant")
	if myth_color.r < 0.9 or myth_color.g < 0.6:
		_fail("myth grade must be gold")
	if unique_color.g < 0.9 or unique_color.b < 0.5:
		_fail("unique grade must be bright emerald")
	var unique_style: StyleBoxFlat = ui.call("_slot_style_for_grade", "유일", true)
	if unique_style.shadow_size < 7:
		_fail("unique grade must have strong glow")
	if unique_style.shadow_color.g <= unique_style.shadow_color.r:
		_fail("unique glow must be emerald/green dominant")
	if str(ui.call("_bless_state", {"blessed":true}, "테스트")) != "blessed":
		_fail("explicit blessed flag not recognized")
	if str(ui.call("_bless_state", {"cursed":true}, "테스트")) != "cursed":
		_fail("explicit cursed flag not recognized")
	if not bool(ui.call("_is_engraved", {}, "무기 마법 주문서 (각인)")):
		_fail("engraved name marker not recognized")

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
