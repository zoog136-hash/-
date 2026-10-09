extends SceneTree

# Headless integration smoke; no destructive enhancement or file loading.
var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures.append(message)
		print("UI RENEWAL FAIL: "+message)

func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event,true)

func _drag(index: int, point: Vector2, delta: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = delta
	root.push_input(event,true)

func _screen_point(control: Control, local_point: Vector2) -> Vector2:
	return control.get_global_transform_with_canvas() * local_point

func _run() -> void:
	root.size = Vector2i(1280,720)
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false,"Main.tscn cannot load")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	for frame: int in range(8): await process_frame
	var hud: Node = world.get_node("HUD")
	var workspace: PanelContainer = hud.get("workspace") as PanelContainer
	_check(workspace != null,"renewal workspace exists")
	_check(hud.has_signal("shop_buy_requested"),"shop signal preserved")
	_check(hud.has_signal("enhancement_requested"),"enhancement signal preserved")
	_check(hud.has_signal("save_pressed"),"save signal preserved")
	_check(hud.has_signal("load_pressed"),"load signal preserved")
	if workspace == null:
		world.queue_free()
		_finish()
		return
	hud.call("open_shop")
	await process_frame
	_check(workspace.visible,"shop window visible")
	var listing: ItemList = workspace.find_child("ShopItems",true,false) as ItemList
	var buy: Button = workspace.find_child("ShopBuy",true,false) as Button
	_check(listing != null and listing.item_count >= 20,"original shop, blessing scroll and dragon items remain available")
	if listing != null:
		var blessing_in_shop: bool = false
		for shop_index: int in range(listing.item_count):
			if listing.get_item_text(shop_index).contains("축복 부여 주문서"):
				blessing_in_shop = true
				break
		_check(blessing_in_shop, "equipment blessing scroll visible in shop")
	_check(buy != null and not buy.disabled,"potion affordable")
	# Real viewport GUI touch events (not direct _select or item_selected.emit).
	if listing != null and listing.item_count > 1:
		var second: Vector2 = _screen_point(listing,listing.get_item_rect(1).get_center())
		_touch(40,second,true)
		_touch(40,second,false)
		await process_frame
		_check(listing.get_selected_items().has(1),"native touch selects second shop item")
		_check(buy.text.contains("180"),"shop details reflect touched item price")
		# Restore the initial potion so the original purchase assertion remains valid.
		listing.select(0)
		listing.item_selected.emit(0)
	var old_gold := int(world.get("gold"))
	var inventory: Dictionary = world.get("inventory")
	var old_count := int(inventory.get("HP 물약",0))
	if buy != null and not buy.disabled:
		buy.pressed.emit()
		await process_frame
		_check(int(world.get("gold")) == old_gold-50,"purchase deducts existing world currency")
		var updated: Dictionary = world.get("inventory")
		_check(int(updated.get("HP 물약",0)) == old_count+1,"purchase grants an existing item")
	# Make the window shorter so long lists really overflow, then swipe
	# the native ItemList and the shared menu controls through the viewport.
	root.size = Vector2i(960,480)
	await process_frame
	await process_frame
	if listing != null:
		var shop_bar: VScrollBar = listing.get_v_scroll_bar()
		_check(shop_bar.max_value > shop_bar.page,"short viewport requires shop list scrolling")
		if shop_bar.max_value > shop_bar.page:
			shop_bar.value = shop_bar.min_value
			var start: Vector2 = _screen_point(listing,listing.get_item_rect(0).get_center())
			var selected_before: PackedInt32Array = listing.get_selected_items()
			var gold_before_swipe: int = int(world.get("gold"))
			_touch(41,start,true)
			_drag(41,start+Vector2(0,-40),Vector2(0,-40))
			_drag(41,start+Vector2(0,-85),Vector2(0,-45))
			_touch(41,start+Vector2(0,-85),false)
			await process_frame
			_check(shop_bar.value > shop_bar.min_value,"finger swipe scrolls shop items")
			_check(int(world.get("gold")) == gold_before_swipe,"shop swipe never purchases")
	hud.call("toggle_menu")
	await process_frame
	var nav_scroll: ScrollContainer = workspace.find_child("WorkspaceNavigationScroll",true,false) as ScrollContainer
	var nav_button: Button = workspace.find_child("Nav_character",true,false) as Button
	_check(nav_scroll != null and nav_button != null,"navigation sidebar scroll exists")
	if nav_scroll != null and nav_button != null:
		var nav_bar: VScrollBar = nav_scroll.get_v_scroll_bar()
		_check(nav_bar.max_value > nav_bar.page,"navigation overflows shortened viewport")
		if nav_bar.max_value > nav_bar.page:
			nav_scroll.scroll_vertical = 0
			var nav_start: Vector2 = _screen_point(nav_button,nav_button.size*0.5)
			_touch(42,nav_start,true)
			_drag(42,nav_start+Vector2(0,-40),Vector2(0,-40))
			_drag(42,nav_start+Vector2(0,-100),Vector2(0,-60))
			_touch(42,nav_start+Vector2(0,-100),false)
			await process_frame
			_check(nav_scroll.scroll_vertical > 0,"finger dragging sidebar button scrolls navigation")
			_check(str(hud.get("active_section")) == "menu","sidebar swipe does not activate menu button")
	var menu_scroll: ScrollContainer = workspace.find_child("MenuContentScroll",true,false) as ScrollContainer
	_check(menu_scroll != null,"main menu uses a vertical ScrollContainer")
	if menu_scroll != null:
		# Force a genuinely scrollable content height even if the default
		# four-row menu fits on the current CI virtual viewport.
		var menu_grid: GridContainer = menu_scroll.get_child(0) as GridContainer
		menu_grid.custom_minimum_size.y = menu_scroll.size.y + 180.0
		await process_frame
		var menu_bar: VScrollBar = menu_scroll.get_v_scroll_bar()
		_check(menu_bar.max_value > menu_bar.page,"main menu can scroll when content overflows")
		if menu_bar.max_value > menu_bar.page:
			var grid_button: Button = menu_scroll.get_child(0).get_child(0) as Button
			var menu_start: Vector2 = _screen_point(grid_button,grid_button.size*0.5)
			_touch(43,menu_start,true)
			_drag(43,menu_start+Vector2(0,-40),Vector2(0,-40))
			_drag(43,menu_start+Vector2(0,-100),Vector2(0,-60))
			_touch(43,menu_start+Vector2(0,-100),false)
			await process_frame
			_check(menu_scroll.scroll_vertical > 0,"finger dragging main-menu tile scrolls")
			_check(str(hud.get("active_section")) == "menu","main-menu swipe does not activate a menu tile")
	root.size = Vector2i(1280,720)
	await process_frame
	hud.call("_open_enhance_chooser")
	await process_frame
	var choices: ItemList = workspace.find_child("EnhancementChoices",true,false) as ItemList
	_check(choices != null and choices.item_count > 0,"owned scrolls listed")
	hud.call("open_enhancement","무기 마법 주문서 (각인)",[])
	await process_frame
	var enhance: Button = workspace.find_child("EnhanceAction",true,false) as Button
	_check(enhance != null and enhance.disabled,"no target prevents enhancement")
	hud.call("open_quest_info")
	await process_frame
	var quest: ProgressBar = workspace.find_child("QuestProgress",true,false) as ProgressBar
	_check(quest != null,"quest progress exists")
	if quest != null:
		var state: Dictionary = (hud.get("character_state") as Dictionary).duplicate(true)
		state["quest_goal"] = 9
		state["quest_kills"] = 4
		hud.call("set_character_state",state)
		_check(is_equal_approx(quest.value,4.0),"quest reflects refreshed character state")
	hud.call("open_settings_info")
	await process_frame
	var audio: HSlider = workspace.find_child("MasterVolume",true,false) as HSlider
	var log_toggle: CheckButton = workspace.find_child("CombatLogToggle",true,false) as CheckButton
	_check(audio != null and log_toggle != null,"settings controls exist")
	if log_toggle != null:
		log_toggle.button_pressed = false
		_check(not (hud.get("log_label") as Control).visible,"log visibility updates")
		log_toggle.button_pressed = true
	for section: String in ["open_macro_info","open_chat_info","open_skills","open_character"]:
		hud.call(section)
		await process_frame
		_check(workspace.visible,"window visible "+section)
	# The merged 2,852-entry catalog must be visible and selectable after
	# the icon restyle. Compact viewports must not push its list offscreen.
	hud.call("open_catalog", "아이템")
	await process_frame
	var catalog_items: ItemList = hud.get("catalog_list") as ItemList
	var catalog_source: Dictionary = world.get("catalog_db") as Dictionary
	var raw_items: Array = catalog_source.get("아이템", []) as Array
	_check(raw_items.size() >= 2129, "item catalog source preserved after update")
	_check(catalog_items != null and catalog_items.item_count == mini(40,raw_items.size()), "item catalog renders first page of names")
	_check((hud.get("catalog_filtered_results") as Array).size() == raw_items.size(), "default All filter shows every catalog item")
	for frame: int in range(4): await process_frame
	if catalog_items != null and catalog_items.item_count > 1:
		_check(catalog_items.get_item_icon(0) != null, "catalog first item icon painted")
		root.size = Vector2i(720,720)
		await process_frame
		await process_frame
		var compact_tabs: HBoxContainer = workspace.find_child("CatalogCompactTabs",true,false) as HBoxContainer
		var detail_tab: Button = hud.get("catalog_details_tab") as Button
		var actions: ScrollContainer = workspace.find_child("CatalogActionsScroll",true,false) as ScrollContainer
		_check(compact_tabs != null and compact_tabs.visible, "compact catalog exposes list and detail tabs")
		_check(catalog_items.visible and catalog_items.max_columns == 2, "compact catalog keeps icon list visible")
		_check(catalog_items.get_global_rect().end.x <= workspace.get_global_rect().end.x + 1.0, "catalog list stays inside window width")
		var second_record: Dictionary = (hud.get("catalog_results") as Array)[1]
		var second_point: Vector2 = _screen_point(catalog_items,catalog_items.get_item_rect(1).get_center())
		_check(catalog_items.get_item_rect(1).get_center().y <= catalog_items.size.y,"compact catalog displays a tappable item row")
		_touch(60,second_point,true)
		_touch(60,second_point,false)
		await process_frame
		_check(str((hud.get("selected_catalog_record") as Dictionary).get("sourceId","")) == str(second_record.get("sourceId","")), "touch selects source-ID-specific catalog item")
		if detail_tab != null and actions != null:
			detail_tab.pressed.emit()
			await process_frame
			_check(actions.is_visible_in_tree() and not catalog_items.is_visible_in_tree(), "compact catalog shows selected item details")
			(hud.get("catalog_list_tab") as Button).pressed.emit()
			await process_frame
			_check(catalog_items.is_visible_in_tree() and not actions.is_visible_in_tree(), "compact catalog returns to items")
		var title_control: Control = workspace.find_child("WorkspaceTitleDragArea",true,false) as Control
		_check(title_control != null, "shared draggable title is present")
		if title_control != null:
			var origin: Vector2 = workspace.position
			var title_point: Vector2 = _screen_point(title_control,Vector2(title_control.size.x*0.5,12))
			_touch(61,title_point,true)
			_drag(61,title_point+Vector2(18,42),Vector2(18,42))
			_drag(61,title_point+Vector2(38,75),Vector2(20,33))
			_touch(61,title_point+Vector2(38,75),false)
			await process_frame
			_check(workspace.position.distance_to(origin) > 20.0, "title drag continues after finger exits title")
		root.size = Vector2i(1280,720)
		await process_frame
	hud.call("open_character")
	await process_frame
	# The original class grid was removed from the visible character panel.
	# Verify all 13 are restored and both startup and in-game entry work.
	var class_shortcut: Button = workspace.find_child("ChangeClassButton",true,false) as Button
	_check(class_shortcut != null,"character equipment view offers class selection")
	if class_shortcut != null:
		class_shortcut.pressed.emit()
		await process_frame
		_check(str(hud.get("active_section")) == "class_select","character shortcut opens class selection")
	hud.call("open_class_selection",true)
	await process_frame
	var class_grid: GridContainer = workspace.find_child("ClassGrid",true,false) as GridContainer
	var class_confirm: Button = workspace.find_child("ClassConfirm",true,false) as Button
	_check(class_grid != null and class_grid.get_child_count() == 13,"all 13 existing classes appear")
	_check(class_confirm != null and class_confirm.disabled,"starting character requires explicit class selection")
	_check(bool(hud.get("class_picker_initial")) and not (world.get_node("Player") as Node).is_physics_processing(),"starter selection freezes game movement")
	var protected_gold: int = int(world.get("gold"))
	var protected_inventory: Dictionary = (world.get("inventory") as Dictionary).duplicate(true)
	workspace.closed.emit()
	await process_frame
	_check(workspace.visible,"startup class selection cannot be dismissed without confirming")
	if class_grid != null and class_confirm != null:
		var elf_button: Button = workspace.find_child("Class_요정",true,false) as Button
		if elf_button != null:
			var elf_point: Vector2 = _screen_point(elf_button,elf_button.size*0.5)
			_touch(46,elf_point,true)
			_touch(46,elf_point,false)
			await process_frame
			_check(not class_confirm.disabled and class_confirm.text.contains("요정"),"native class card touch selects elf")
			class_confirm.pressed.emit()
			await process_frame
			_check(str(world.get("job_class")) == "요정","selected class applied through world job signal")
			_check(FileAccess.file_exists("user://twilight_v20_save.json"),"selected job committed to local save")
			_check(not bool(hud.get("class_picker_initial")) and not workspace.visible,"confirmation closes starter selection")
			_check((world.get_node("Player") as Node).is_physics_processing(),"confirmation resumes game movement")
			_check(int(world.get("gold")) == protected_gold and (world.get("inventory") as Dictionary) == protected_inventory,"class selection preserves Adena and inventory")
	# Current saved characters may still open and change classes via the menu.
	hud.call("open_class_selection")
	await process_frame
	var mage_button: Button = workspace.find_child("Class_마법사",true,false) as Button
	var class_confirm_again: Button = workspace.find_child("ClassConfirm",true,false) as Button
	_check(mage_button != null and class_confirm_again != null,"saved game class picker is accessible")
	if mage_button != null and class_confirm_again != null:
		mage_button.pressed.emit()
		class_confirm_again.pressed.emit()
		await process_frame
		_check(str(world.get("job_class")) == "마법사","existing character can change class without reset")
		_check(int(world.get("gold")) == protected_gold and (world.get("inventory") as Dictionary) == protected_inventory,"class change keeps gold and inventory")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("UI_RENEWAL_INTEGRATION_OK %d assertions" % assertions)
		quit(0)
	else:
		print("UI_RENEWAL_INTEGRATION_FAILED %d/%d" % [failures.size(),assertions])
		quit(1)
