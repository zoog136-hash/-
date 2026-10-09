extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Icons = preload("res://scripts/ui/renewal_icons.gd")
const Dialog = preload("res://scripts/ui/renewal_dialog.gd")
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, why: String) -> void:
	assertions += 1
	if not ok: failures.append(why); print("UI FIDELITY FAIL: "+why)
func _point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*.5)
func _touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index; event.position=point; event.pressed=down
	root.push_input(event,true)
func _drag(index: int, point: Vector2, motion: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index; event.position=point; event.relative=motion
	root.push_input(event,true)

func _run() -> void:
	root.size=Vector2i(1280,720)
	for key: String in Icons.PATHS:
		var texture: Texture2D = UI.icon(key)
		_check(texture != null and texture.get_width() > 0,"own SVG icon loads "+key)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for frame: int in range(8): await process_frame
	_check(QA.enter_game(world),"starter class confirmed through original signals")
	world.save_timer=-10000
	world.set_process(false)
	world.field_population.set_process(false)
	var hud: Node=world.hud
	var inventory_ui: Control=hud.lineage_inventory_ui
	var owned_before: Dictionary=world.inventory.duplicate(true)
	var samples: Dictionary={}
	for raw: Variant in world.catalog_db.get("아이템",[]):
		if raw is Dictionary: samples[str(raw.get("name",""))]=2
		if samples.size() >= 70: break
	inventory_ui.set_inventory(samples)
	hud.toggle_inventory()
	for frame: int in range(3): await process_frame
	var scroll: ScrollContainer=inventory_ui.get("grid_scroll")
	var slots: Dictionary=inventory_ui.get("slot_buttons")
	_check(slots.size() >= 70,"catalog-backed inventory scroll fixture")
	_check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,"inventory genuinely overflows")
	var button: Button=slots.values()[0]
	var start: Vector2=_point(button)
	var selected_before: String=str(inventory_ui.get("selected_item"))
	_touch(73,start,true)
	_drag(73,start+Vector2(0,-65),Vector2(0,-65))
	_touch(73,start+Vector2(0,-65),false)
	await process_frame
	_check(scroll.scroll_vertical > 0,"native swipe originating on slot scrolls inventory")
	_check(str(inventory_ui.get("selected_item")) == selected_before,"swipe never selects or activates a different item")
	_check(world.inventory == owned_before,"UI fixture and gestures never mutate authoritative inventory")
	scroll.scroll_vertical=0
	await process_frame
	start=_point(button)
	_touch(74,start,true); _touch(74,start,false)
	await process_frame
	_check(str(inventory_ui.get("selected_item")) != "","native slot tap selects an item")
	var side: Control=hud.lineage_side_ui
	var stage: Control=side.get("equipment_stage")
	_check(stage != null and (side.get("equipment_buttons") as Dictionary).size() == 12,"twelve equipment slots surround original class art")
	for category: String in ["아이템","변신","마법인형","성물"]:
		hud.open_catalog(category)
		hud._on_catalog_item_selected(0)
		hud._set_catalog_detail_view(true)
		for frame: int in range(4): await process_frame
		var detail: RichTextLabel=hud.get("catalog_detail")
		_check(detail.size.y > 80 and detail.get_content_height() > 80,"catalog options actually occupy visible layout "+category)
	var tools_toggle: Button=hud.get("catalog_test_toggle")
	hud.open_catalog("아이템")
	hud._set_catalog_detail_view(true)
	tools_toggle.button_pressed=true
	_check((hud.get("playtest_grant_button") as Button).is_visible_in_tree(),"existing QA grant tools remain accessible")
	inventory_ui.set_inventory(owned_before)
	hud._open_enhance_chooser()
	for frame: int in range(3): await process_frame
	var forge_items: ItemList=hud.workspace.find_child("EnhancementChoices",true,false)
	_check(forge_items.item_count > 1,"real starter scrolls available for native forge selection")
	if forge_items.item_count > 1:
		var item_point: Vector2=forge_items.get_global_transform_with_canvas()*forge_items.get_item_rect(1).get_center()
		_touch(76,item_point,true); _touch(76,item_point,false)
		await process_frame
		_check(forge_items.get_selected_items() == PackedInt32Array([1]),"native forge touch selects original scroll record")
	hud._close_workspace()
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(854,480),Vector2i(720,720),Vector2i(2400,1080)]:
		root.size=extent
		await process_frame
		await process_frame
		hud._fit_hud()
		var attack: Control=hud.get_node("Root/RightControls/AttackButton")
		var transform: Transform2D=attack.get_global_transform_with_canvas()
		var corner: Vector2=root.get_final_transform()*transform*attack.size
		_check(corner.x <= extent.x+1 and corner.y <= extent.y+1,"attack remains in viewport "+str(extent))
		hud.open_skills()
		for frame: int in range(3): await process_frame
		var panel_transform: Transform2D=root.get_final_transform()*hud.workspace.get_global_transform_with_canvas()
		var panel_corner: Vector2=panel_transform*hud.workspace.size
		_check(panel_corner.x <= extent.x+1 and panel_corner.y <= extent.y+1,"responsive workspace fits physical window "+str(extent))
		_check(panel_transform.get_scale().x >= .99,"window text avoids miniature canvas scaling "+str(extent))
		var cards: ItemList=hud.skills_view.get("cards")
		var browser: Control=cards.get_parent().get_parent()
		if hud.workspace.content.size.x < 660:
			_check(browser.tabs.visible and cards.is_visible_in_tree(),"compact skills initially shows list "+str(extent))
			browser.detail_active=true; browser.reflow()
			_check(not cards.is_visible_in_tree() and browser.details.is_visible_in_tree(),"compact skill detail accessible "+str(extent))
			browser.detail_active=false; browser.reflow()
			_check(cards.is_visible_in_tree(),"compact skills returns to list "+str(extent))
		hud.open_macro_info()
		for frame: int in range(3): await process_frame
		var auto_status: Label = hud.workspace.find_child("AutoStatusTitle",true,false)
		_check(auto_status.size.y < 40,"AUTO status stays one horizontal line "+str(extent))
		var settings_toggle: Button = hud.workspace.find_child("AutoSettingToggle",true,false)
		_check(settings_toggle.get_global_rect().end.y <= hud.workspace.content.get_global_rect().end.y,"AUTO setting toggle visible without scrolling "+str(extent))
	root.size=Vector2i(1280,720)
	await process_frame
	hud._close_workspace()
	var tracker: Control = hud.v20_layer.get_node("QuestTracker")
	_check(tracker.size.y <= 125,"quest tracker leaves the world visible below its two text lines")
	var auto: Button=hud.get("v20_auto_button")
	var original_auto: bool=world.player.auto_enabled
	_touch(77,_point(auto),true); _touch(77,_point(auto),false)
	await process_frame
	_check(world.player.auto_enabled != original_auto,"native AUTO touch changes actual hunt state")
	hud.open_macro_info()
	for frame: int in range(3): await process_frame
	var settings_toggle: Button = hud.workspace.find_child("AutoSettingToggle",true,false)
	original_auto = world.player.auto_enabled
	_touch(80,_point(settings_toggle),true); _touch(80,_point(settings_toggle),false)
	await process_frame
	_check(world.player.auto_enabled != original_auto,"native settings AUTO toggle changes actual hunt state")
	hud._close_workspace()
	var attack_count: Array[int]=[0]
	hud.attack_pressed.connect(func() -> void: attack_count[0]+=1)
	var attack: Button=hud.get_node("Root/RightControls/AttackButton")
	_touch(78,_point(attack),true); _touch(78,_point(attack),false)
	await process_frame
	_check(attack_count[0] == 1,"original attack signal emitted once by native touch")
	var modal := Dialog.new()
	modal.title_text="저장된 게임 불러오기"
	modal.message_text="현재 미저장 진행도가 사라질 수 있습니다. 저장본을 불러올까요?"
	hud.get_node("Root").add_child(modal)
	await process_frame
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480),Vector2i(720,720)]:
		root.size = extent
		for frame: int in range(3): await process_frame
		var card_transform: Transform2D = root.get_final_transform()*modal.card.get_global_transform_with_canvas()
		var first: Vector2 = card_transform*Vector2.ZERO
		var last: Vector2 = card_transform*modal.card.size
		_check(first.x >= 0 and first.y >= 0 and last.x <= extent.x and last.y <= extent.y,"confirmation card stays on screen "+str(extent))
		var visible_buttons: int = 0
		for candidate: Node in modal.card.find_children("*","Button",true,false):
			var confirmation_button: Button = candidate
			var button_transform: Transform2D = root.get_final_transform()*confirmation_button.get_global_transform_with_canvas()
			var button_corner: Vector2 = button_transform*confirmation_button.size
			if confirmation_button.is_visible_in_tree() and button_corner.x <= last.x and button_corner.y <= last.y: visible_buttons += 1
		_check(visible_buttons == 2,"cancel and confirm are visible inside card "+str(extent))
	root.size = Vector2i(1280,720)
	for frame: int in range(3): await process_frame
	original_auto=world.player.auto_enabled
	_touch(79,_point(auto),true); _touch(79,_point(auto),false)
	await process_frame
	_check(world.player.auto_enabled == original_auto,"confirmation backdrop blocks world controls")
	var escape := InputEventKey.new()
	escape.keycode=KEY_ESCAPE; escape.pressed=true
	root.push_input(escape,true)
	await process_frame
	_check(not is_instance_valid(modal),"Esc cancels confirmation without loading")
	world.queue_free()
	await process_frame
	print("UI_FIDELITY_REGRESSION_OK %d assertions" % assertions if failures.is_empty() else "UI_FIDELITY_REGRESSION_FAILED %d/%d" % [failures.size(),assertions])
	quit(0 if failures.is_empty() else 1)
