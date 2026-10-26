extends SceneTree

# Real Main/HUD, real viewport dispatch; isolated user-data directory required.
const QA = preload("res://tests/qa_class_selection.gd")
const SHOP_UI = preload("res://scripts/ui/renewal_shop.gd")
const COLLECTION_ID: String = "eqc_b10d34dbc266c4e869ca"
var checks: int = 0
var failures: Array[String] = []
var world: Node

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("MOBILE_UI_STATE_FAIL: " + message)

func _point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * .5)

func _item_point(items: ItemList, index: int) -> Vector2:
	return items.get_global_transform_with_canvas() * items.get_item_rect(index).get_center()

func _touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 41
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event,true)

func _tap(point: Vector2) -> void:
	_touch(point,true)
	_touch(point,false)

func _drag(from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 41
	event.position = to
	event.relative = to-from
	root.push_input(event,true)

func _frames(count: int = 3) -> void:
	for frame: int in range(count): await process_frame

func _run() -> void:
	root.size = Vector2i(1280,720)
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await _frames(4)
	check(QA.enter_game(world),"real class picker enters game")
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.source_save_blocked = true
	world.save_timer = -10000
	for monster: Node in world.monsters_root.get_children():
		monster.set_process(false)
		monster.set_physics_process(false)
	if world.field_population != null: world.field_population.set_process(false)
	world.gold = 1000000000
	world._update_hud()
	world.gold += 17
	world._refresh_combat_hud()
	check(int(world.hud.lineage_inventory_ui.character_state.get("gold",0)) == world.gold,"lightweight kill refresh updates inventory wallet state")
	check(world.hud.lineage_inventory_ui.gold_label.text == "아데나  "+world.hud.lineage_inventory_ui._format_number(world.gold),"lightweight kill reward updates bag wallet without rebuilding slots")
	await _test_collections()
	await _test_shop()
	await _test_skills()
	world.queue_free()
	await process_frame
	print("MOBILE_UI_STATE_OK checks=%d" % checks if failures.is_empty() else "MOBILE_UI_STATE_FAILED %d/%d" % [failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

func _test_collections() -> void:
	var hud: Node = world.hud
	hud.toggle_menu()
	await _frames()
	var tile: Button = hud.workspace.find_child("MenuTile_equipment_collections",true,false) as Button
	check(tile != null,"equipment collection has a real menu tile")
	if tile == null: return
	_tap(_point(tile))
	await _frames()
	check(hud.active_section == "equipment_collections","native menu tap opens equipment collections")
	if hud.active_section != "equipment_collections": return
	var view: Control = hud.workspace.content.get_child(0)
	var items: ItemList = view.list
	check(items.item_count > 2,"real collection definitions are listed")
	if items.item_count <= 2: return
	var second_id: String = str(view.filtered[1].id)
	_tap(_item_point(items,1))
	check(str(view.selected_id) == second_id,"native list tap selects the requested collection")
	var before: String = str(view.selected_id)
	var start: Vector2 = _item_point(items,2)
	_touch(start,true)
	_drag(start,start+Vector2(0,-36))
	_touch(start+Vector2(0,-36),false)
	check(str(view.selected_id) == before,"collection swipe never selects another row")
	items.get_v_scroll_bar().value = 0
	await _frames()
	start = _item_point(items,0)
	_touch(start,true)
	_touch(start,false,true)
	check(str(view.selected_id) == before,"canceled collection touch preserves selection")
	# The registration picker must also select physical IDs through native input.
	var runtime: Object = world.equipment_collections
	var definition: Dictionary = runtime.core.resolve(COLLECTION_ID)
	var requirement: Dictionary = definition.requirements[0]
	var record: Dictionary = runtime.icon_record(str(requirement.name))
	for amount: int in range(2):
		var id: String = str(world.next_item_instance_id)
		world.next_item_instance_id += 1
		var item_name: String = str(record.name)
		world.inventory[item_name] = int(world.inventory.get(item_name,0))+1
		world.item_instances[id] = {"name":item_name,"level":int(requirement.enchant),"record":record.duplicate(true),"sourceId":str(record.sourceId)}
	view.selected_id = COLLECTION_ID
	view._choose(COLLECTION_ID,str(requirement.slot_id))
	await _frames()
	var candidates: ItemList = view.candidates_list
	check(candidates != null and candidates.item_count >= 2,"collection picker has distinct physical candidates")
	if candidates != null and candidates.item_count >= 2:
		view.detail_scroll.ensure_control_visible(candidates)
		await _frames()
		_tap(_item_point(candidates,1))
		check(candidates.get_selected_items() == PackedInt32Array([1]),"native candidate tap selects the exact physical row")
	# Compact catalog formerly hid the shortcut with its grade sidebar.
	root.size = Vector2i(960,540)
	await _frames()
	hud.open_catalog("변신")
	await _frames()
	check(not hud.catalog_grade_column.visible,"compact catalog uses its compact filters")
	var shortcut: Button = hud.equipment_collection_button
	check(shortcut.is_visible_in_tree() and not shortcut.disabled and shortcut.text == "장비 컬렉션","compact card page exposes a clearly named equipment route")
	check(shortcut.get_global_rect().end.x <= hud.workspace.get_global_rect().end.x,"compact collection shortcut stays inside its window")
	_tap(_point(shortcut))
	await _frames()
	check(hud.active_section == "equipment_collections","compact catalog shortcut responds to native touch")
	root.size = Vector2i(1280,720)
	await _frames()

func _test_shop() -> void:
	var hud: Node = world.hud
	SHOP_UI.selected_vendor_id = ""
	hud.open_npc_shop()
	await _frames()
	var shop: Control = hud.shop_view
	shop.search_field.text = "물약"
	await _frames()
	check(shop.filtered.size() > 2,"shop search has multiple actual offers")
	if shop.filtered.size() <= 2: return
	shop.listing.select(2)
	shop._select(2)
	shop.purchase_quantity.value = 2
	var selected_name: String = str(shop.selected[0])
	var before_count: int = int(world.inventory.get(selected_name,0))
	var before_gold: int = int(world.gold)
	var price: int = int(shop.selected[1])
	var bar: VScrollBar = shop.listing.get_v_scroll_bar()
	bar.value = minf(25,maxf(0,bar.max_value-bar.page))
	await _frames()
	var scroll_before: float = bar.value
	shop._buy()
	await _frames()
	var dialog: Control = hud.get_node_or_null("Root/TwilightConfirmation") as Control
	check(dialog != null,"purchase opens the actual confirmation")
	if dialog == null: return
	# A modal-backdrop tap over a different merchandise row must not reach raw input.
	_tap(_item_point(shop.listing,0))
	check(str(shop.selected[0]) == selected_name,"confirmation backdrop blocks underlying raw shop selection")
	_tap(_point(dialog.confirm_button))
	await _frames()
	check(int(world.inventory.get(selected_name,0)) == before_count+2,"native confirm buys the captured item and quantity")
	check(int(world.gold) == before_gold-price*2,"authoritative purchase charges the captured offer")
	check(str(shop.selected[0]) == selected_name,"purchase preserves selected product")
	check(shop.listing.get_selected_items() == PackedInt32Array([2]),"purchase preserves selected row")
	check(shop.search_field.text == "물약" and int(shop.purchase_quantity.value) == 2,"purchase preserves search and quantity")
	check(is_equal_approx(bar.value,scroll_before),"purchase preserves shop scroll")
	check(shop.wallet.text.contains(str(world.gold)),"purchase updates wallet without rebuilding rows")
	check(shop.listing.get_item_text(2).contains("보유 %d" % int(world.inventory.get(selected_name,0))),"purchase updates stock count on the same row")

func _test_skills() -> void:
	var hud: Node = world.hud
	var catalog: Object = world.original_skills.catalog
	world.level = 100
	var target: Dictionary = {}
	for record: Dictionary in catalog.records:
		if not catalog.permitted(record) or catalog.owned(record): continue
		world.inventory[str(record.book_name)] = 1
		if catalog.reason(record).is_empty():
			target = record
			break
	check(not target.is_empty(),"actual catalog has an unlearned skill with satisfiable learning requirements")
	if target.is_empty(): return
	world._update_hud()
	hud.open_skills()
	await _frames()
	var view: Control = hud.skills_view
	view.search.text = str(target.name)
	await _frames()
	var index: int = -1
	for row: int in range(view.filtered.size()):
		if str(view.filtered[row].get("id","")) == str(target.id): index = row
	check(index >= 0,"unlearned skill is available for inspection")
	if index < 0: return
	view.cards.select(index)
	view.select(index)
	check(view.cards.get_item_icon_modulate(index).a < .8,"unlearned icon is visibly faded")
	check(view.cards.get_item_text(index).begins_with("미습득"),"unlearned status remains readable")
	var image := Image.create(4,4,false,Image.FORMAT_RGBA8)
	image.fill(Color(1,.2,.1,.6))
	var source := ImageTexture.create_from_image(image)
	var gray: Texture2D = view._unlearned_icon(source)
	var pixel: Color = gray.get_image().get_pixel(0,0)
	check(is_equal_approx(pixel.r,pixel.g) and is_equal_approx(pixel.g,pixel.b),"unlearned icon conversion actually removes color")
	check(absf(pixel.a-.6) < .01,"grayscale conversion preserves source transparency")
	check(gray == view._unlearned_icon(source),"grayscale texture is cached across repeated refreshes")
	check(source.get_image().get_pixel(0,0).r > source.get_image().get_pixel(0,0).g,"grayscale conversion leaves the learned source texture unchanged")
	view.learn_button.pressed.emit()
	await _frames()
	check(catalog.owned(target),"real learn action succeeds")
	var chosen: int = view.cards.get_selected_items()[0]
	check(view.cards.get_item_icon_modulate(chosen) == Color.WHITE,"successful learning restores full color immediately")
	check(not view.cards.get_item_text(chosen).begins_with("미습득"),"successful learning clears faded status without reopening")
