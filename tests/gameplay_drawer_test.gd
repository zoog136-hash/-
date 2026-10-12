extends "res://tests/integrated_ui_test.gd"

# Native GUI navigation through the visible drawer, including its child views.
# Fixtures use the real starter character; no gameplay snapshots are invented.
func _run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	hud = world.hud
	check(CLASS_QA.enter_game(world),"enter world through class selection")
	world.save_timer = -100000
	world.set_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.player.set_physics_process(false)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2400,1080)]:
		root.size = extent
		DisplayServer.window_set_size(extent)
		await frames()
		hud._fit_hud()
		hud._close_workspace()
		await click(hud.v20_layer.find_child("Shortcut_menu",true,false))
		var screen := root.get_visible_rect()
		var bounds: Rect2 = hud.workspace.get_global_rect()
		check(hud.active_section == "menu" and bounds.position.x > screen.size.x*.60 and screen.encloses(bounds),"menu leaves center playfield visible "+str(extent))
		check(not bounds.intersects(hud.v20_quickslot_buttons[7].get_global_rect()),"drawer leaves right slot bank accessible "+str(extent))
		await touch(named("MenuGroup_1"))
		check(named("MenuTile_crafting") != null and hud.menu_group == 1,"native category tab exposes gameplay routes "+str(extent))
		# The visible HUD strip must route directly, without a first click only
		# dismissing the backdrop and forcing the player to repeat the click.
		await click(hud.v20_layer.find_child("Shortcut_inventory",true,false))
		check(hud.active_section == "inventory","one HUD shortcut click switches menu to inventory "+str(extent))
		var inv: Control = hud.lineage_inventory_ui
		inv.back_to_list()
		inv.search_line.text = "HP 물약"
		inv.search_line.text_changed.emit(inv.search_line.text)
		await frames()
		var potion: Button = inv.slot_buttons["HP 물약"]
		await touch(potion)
		check(inv.detail_panel.is_visible_in_tree() and not inv.inventory_left.is_visible_in_tree(),"native item tap opens compact detail "+str(extent))
		check(inv.detail_panel.size.x >= inv.inventory_panel.size.x-30,"item detail fills available drawer width "+str(extent))
		check(hud.workspace.content.get_global_rect().encloses(inv.detail_action.get_global_rect()),"item actions stay within drawer "+str(extent))
		await click(named("BackWindow"))
		check(hud.active_section == "inventory" and inv.inventory_left.is_visible_in_tree() and inv.search_line.text == "HP 물약" and inv.selected_item == "HP 물약","Back returns detail to filtered item list "+str(extent))
		await drag_between(inv.slot_buttons["HP 물약"],hud.v20_quickslot_buttons[0])
		check(world.quickslots[0].get("id","") == "HP 물약","drag from drawer reaches bottom quickslot "+str(extent))
		await click(hud.v20_layer.find_child("Shortcut_skills",true,false))
		check(hud.active_section == "skills","one HUD shortcut click switches inventory to skills "+str(extent))
		var view: Node = hud.skills_view
		view.type_filter.select(1)
		view.type_filter.item_selected.emit(1)
		await frames()
		var browser: Node = view.cards.get_parent().get_parent()
		for index: int in view.filtered.size():
			if world._skill_owned_for_current_job(view.filtered[index]):
				view.select(index)
				break
		var skill_name := str(view.selected.get("name",""))
		await click(browser.tabs.get_child(1))
		check(view.quick_button.is_visible_in_tree(),"skill detail exposes registration action "+str(extent))
		await click(view.quick_button)
		check(hud.active_section == "quickslots","skill detail enters slot picker "+str(extent))
		await click(named("AssignQuickslot_1"))
		check(world.quickslots[1].get("id","") == skill_name and hud.active_section == "skills" and hud.skills_view.quick_button.is_visible_in_tree(),"registration returns to selected skill detail "+str(extent))
		key(KEY_ESCAPE); key(KEY_ESCAPE,false)
		await frames()
		check(hud.active_section == "skills" and hud.skills_view.cards.is_visible_in_tree(),"Esc returns skill detail to list "+str(extent))
		hud._close_workspace()
		await frames()
		check(not hud.blocks_world_input(),"closing drawer releases gameplay input "+str(extent))
	world.queue_free()
	await frames()
	print("GAMEPLAY_DRAWER_OK: %d checks" % checks.size() if failures.is_empty() else "GAMEPLAY_DRAWER_FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
