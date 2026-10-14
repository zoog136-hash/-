extends RefCounted

# Runs inside the actual Main.tscn fixture, using its normal input dispatcher.
const UI = preload("res://scripts/ui/renewal_theme.gd")

static func screen_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)

static func run(suite: Variant, ref0: String, ref1: String) -> void:
	var bag: Control = await suite.bag_search("낡은 장검")
	await suite.tap(suite.point(bag.slot_buttons[ref0]),true)
	var hint: Label = bag.item_name_hint
	var record: Dictionary = bag._find_item_record(ref0)
	suite.check(hint.is_visible_in_tree() and not bag.detail_panel.is_visible_in_tree(),"native selection shows name without details")
	suite.check(hint.text == bag._enhanced_display_name(record,ref0) and not hint.text.contains("@@@"),"name belongs to exact selected physical item without exposing ID")
	suite.check(hint.get_theme_color("font_color") == UI.grade(str(record.get("grade","일반"))),"name uses existing item grade palette")
	var slot: Rect2 = screen_rect(bag.slot_buttons[ref0])
	var label_rect: Rect2 = screen_rect(hint)
	suite.check(label_rect.end.y <= slot.position.y and slot.position.y-label_rect.end.y <= 8.0,"name sits directly above the selected item border")
	suite.check(hint.mouse_filter == Control.MOUSE_FILTER_IGNORE and bag.slot_buttons[ref0].tooltip_text.is_empty(),"name cannot intercept gestures or leave a default hover tooltip")
	var remaining: int = bag.item_name_until-Time.get_ticks_msec()
	suite.check(remaining > 4500 and remaining <= 5000,"single click starts approximately five real seconds")

	var details: Button = bag.find_child("InventoryDetail",true,false)
	var close: Button = bag.find_child("InventoryDetailClose",true,false)
	suite.check(details != null and details.text == "상세정보","explicit detail action is labeled 상세정보")
	await suite.tap(suite.point(details),true)
	suite.check(bag.detail_active and bag.detail_panel.is_visible_in_tree() and bag.selected_item == ref0,"native detail action opens selected item's details")
	suite.check(not hint.visible,"opening details clears only the transient name")
	await suite.tap(suite.point(close),true)
	suite.check(not bag.detail_active and not bag.detail_panel.is_visible_in_tree() and bag.selected_item == ref0,"native close dismisses details without deselecting item")
	await suite.tap(suite.point(details))
	suite.check(bag.detail_active and bag.detail_panel.is_visible_in_tree(),"mouse detail action also opens details")
	await suite.tap(suite.point(close))
	suite.check(not bag.detail_active,"mouse close dismisses details")

	# A fresh tap replaces the sole deadline, including another tap on the same item.
	suite.hud.pointer_transfer.cancel()
	await suite.tap(suite.point(bag.slot_buttons[ref0]),true)
	var first_deadline: int = bag.item_name_until
	await suite.create_timer(2.0,true,false,true).timeout
	suite.hud.pointer_transfer.cancel()
	await suite.tap(suite.point(bag.slot_buttons[ref0]),true)
	suite.check(bag.item_name_until >= first_deadline+1800,"same-item single tap refreshes the full name duration")
	await suite.tap(suite.point(bag.slot_buttons[ref1]),true)
	var final_deadline: int = bag.item_name_until
	suite.check(bag.selected_item == ref1 and hint.text == bag._enhanced_display_name(bag._find_item_record(ref1),ref1),"changing selection replaces the name instead of stacking labels")
	bag._refresh_inventory_grid()
	await suite.frames(4)
	suite.check(bag.item_name_until == final_deadline and hint.is_visible_in_tree(),"grid rebuild reanchors label without restarting its deadline")
	await suite.create_timer(3.2,true,false,true).timeout
	suite.check(Time.get_ticks_msec() > first_deadline and hint.is_visible_in_tree(),"old selection expiry cannot hide the newer selection's name")
	await suite.create_timer(2.1,true,false,true).timeout
	await suite.frames(2)
	suite.check(Time.get_ticks_msec() >= final_deadline and not hint.visible,"name disappears after five seconds without mouse exit")
	suite.check(bag.selected_item == ref1 and not bag.detail_active,"name expiry preserves selection and never opens details")
	var selected_style: StyleBoxFlat = bag.slot_buttons[ref1].get_theme_stylebox("normal") as StyleBoxFlat
	var other_style: StyleBoxFlat = bag.slot_buttons[ref0].get_theme_stylebox("normal") as StyleBoxFlat
	suite.check(selected_style.border_color != other_style.border_color and selected_style.border_width_top == 2,"selected border remains visibly highlighted after name expiry")
	await suite.tap(suite.point(details),true)
	suite.check(bag.detail_active and bag.selected_item == ref1,"details can still open after the name has expired")
	await suite.tap(suite.point(close),true)

	# Exercise all seven grade colors against pinned physical-item UI records.
	var instance_id: String = bag._ref_instance_id(ref0)
	var physical: Dictionary = bag.character_state.item_instances[instance_id]
	var original_physical: Dictionary = physical.duplicate(true)
	for grade_name: String in UI.GRADES:
		var fixture: Dictionary = record.duplicate(true)
		fixture["grade"] = grade_name
		physical["record"] = fixture
		bag._refresh_inventory_grid()
		await suite.frames(3)
		suite.hud.pointer_transfer.cancel()
		await suite.tap(suite.point(bag.slot_buttons[ref0]),true)
		suite.check(hint.is_visible_in_tree() and hint.get_theme_color("font_color") == UI.GRADES[grade_name],"grade-colored name: "+grade_name)
	bag.character_state.item_instances[instance_id] = original_physical
	bag._refresh_inventory_grid()
	await suite.frames(3)

	# Filtering/remounting must not leave a stale floating label behind.
	bag.search_line.text = "HP 물약"
	bag._refresh_inventory_grid()
	await suite.frames(3)
	suite.check(not hint.visible and bag.selected_item == ref0,"filtered-out slot clears name but preserves item selection")
	bag = await suite.bag_search("낡은 장검")
	await suite.tap(suite.point(bag.slot_buttons[ref0]),true)
	suite.hud._close_workspace()
	await suite.frames(3)
	suite.check(not hint.visible and bag.item_name_until == 0,"closing inventory cancels transient display")
	bag = await suite.bag_search("낡은 장검")
	suite.check(not hint.visible and not bag.detail_active and bag.selected_item == ref0,"reopening inventory keeps selection without stale name or auto-open details")
