extends SceneTree
## Touch TWILIGHT's actual production windows with an isolated save. Pass
## --expect-native with the pinned UI45 pack to exercise the two source tabs.
const QA = preload("res://tests/qa_class_selection.gd")
const TREE = preload("res://scripts/ui/original_ui/source_main_named_tree.gd")
const TOP = preload("res://scripts/ui/original_ui/source_main_menu_bindings.gd")
const CRAFT = preload("res://scripts/ui/renewal_crafting.gd")
const FAVORITES_KEY := "craft_recipe_favorites"
const TEST_CRAFT_ID := "patch523:13"
const IRON := "철 · 원본#379"
const HELMET := "해골 투구 (각인) · 원본#4891"
const UI45 := "47e593f4fa682dc4a8e839fd0af181687926e757ce57d1e09dddd190cd44c407"

var world: Node
var hud: Node
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:
		failures.append(description)
		printerr("CRAFT_LOOKUP_FAIL ", description)
	return ok

func _frames(count: int = 3) -> void:
	for index: int in count:
		await process_frame

func _touch_at(point: Vector2) -> void:
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 24
		touch.position = point
		touch.pressed = down
		root.push_input(touch, true)
		await _frames(2)

func _tap(control: Control) -> bool:
	if not _check(is_instance_valid(control) and control.is_visible_in_tree(), "button or field is visible for touch"):
		return false
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	if not _check(root.get_visible_rect().has_point(point), "touch target is in the viewport"):
		return false
	await _touch_at(point)
	return true

func _source_area(scene: Node2D, offset: int) -> Control:
	var node: Node = scene.source_nodes.get(offset)
	if node == null or not node.has_meta("source_button"):
		return null
	return node.get_meta("source_button")._input_area

func _source_tab(window: RefCounted, name: String) -> Control:
	var found: Dictionary = TREE.locate_exact(window._scene, window.node_keys(), "Nd_TabMenu/Btn_" + name + "_Off")
	return _source_area(found.player, found.offset) if found.get("ok", false) else null

func _open_from_menu(native: bool) -> void:
	var shortcut: Control = hud.find_child("Shortcut_menu", true, false) if not native else _source_area(hud.original_main_ui_controller._menu_scene, TOP.ALL)
	if not await _tap(shortcut):
		return
	var tile: Control = hud.workspace.find_child("MenuTile_crafting", true, false)
	if not _check(hud.active_section == "menu" and tile != null, "game menu offers the crafting entry"):
		return
	hud.menu_scroll_view.ensure_control_visible(tile)
	await _frames()
	await _tap(tile)
	_check(hud.active_section == "crafting", "menu tile opens actual crafting")

func _submit(text: String, native: bool, enter: bool = false) -> void:
	var field: LineEdit = hud.workspace.find_child("CraftNameFilter", true, false)
	if not await _tap(field):
		return
	var previous: Array[String] = []
	if native:
		previous = _ids()
	_check(field.has_focus() and field.is_editing(), "touch focuses the search field")
	field.clear()
	for offset: int in text.length():
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = text.unicode_at(offset)
		root.push_input(key, true)
	await _frames()
	_check(field.text == text, "search field receives the typed text")
	if native:
		_check(_ids() == previous, "typing keeps the current list until the search is submitted")
		if enter:
			var submit := InputEventKey.new()
			submit.pressed = true
			submit.keycode = KEY_ENTER
			root.push_input(submit, true)
			await _frames()
		else:
			await _tap(hud.workspace.find_child("CraftSubmitSearch", true, false))

func _listing() -> ItemList:
	return hud.workspace.find_child("CraftRecipes", true, false)

func _ids() -> Array[String]:
	var listing := _listing()
	var ids: Array[String] = []
	for index: int in listing.item_count:
		ids.append(str(listing.get_item_metadata(index)))
	return ids

func _select(id: String) -> void:
	var listing := _listing()
	var index: int = _ids().find(id)
	if not _check(index >= 0, "requested recipe is present by registry ID"):
		return
	listing.get_v_scroll_bar().value = listing.get_item_rect(index, false).position.y
	await _frames()
	var point: Vector2 = listing.get_item_rect(index, false).get_center()
	point.y -= listing.get_v_scroll_bar().value
	if not _check(Rect2(Vector2.ZERO, listing.size).has_point(point), "recipe row is visible for touch"):
		return
	await _touch_at(listing.get_global_transform_with_canvas() * point)
	var view: Node = hud.workspace.find_child("CraftFavoriteRecipe", true, false)
	while is_instance_valid(view) and view.get_script() != CRAFT:
		view = view.get_parent()
	_check(view != null and view.current_id == id, "row touch picks exact recipe, including same-name results")

func _same_output_sample() -> Dictionary:
	var by_output: Dictionary = {}
	for id: String in world.crafting.recipes:
		var recipe: Dictionary = world.crafting.recipes[id]
		var output: String = str(recipe.get("result", {}).get("item", ""))
		if output.is_empty() or output.length() < 4:
			continue
		if by_output.has(output):
			return {"query":output.get_slice(" · 원본#", 0), "first":by_output[output], "second":id}
		by_output[output] = id
	return {}

func _run() -> void:
	if OS.get_environment("TWILIGHT_CRAFT_LOOKUP_ISOLATED") != "1":
		printerr("Use a dedicated XDG_DATA_HOME for the crafting save/reload test")
		quit(2)
		return
	var native := OS.get_cmdline_user_args().has("--expect-native")
	root.size = Vector2i(2048, 919)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await _frames()
	if not _check(QA.enter_game(world), "actual Main enters as a knight"):
		await _finish(native)
		return
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer = -100000.0
	hud = world.hud
	await _frames()
	var controller: Node = hud.original_main_ui_controller
	if native and not _check(is_instance_valid(controller) and controller._pack.manifest_sha256 == UI45 and is_instance_valid(controller._menu_scene), "Main uses pinned UI45 and its real menu"):
		await _finish(native)
		return
	await _open_from_menu(native)
	var native_window: RefCounted
	var original_id: String = ""
	if native:
		native_window = controller.production_window()
		if not _check(native_window != null and native_window.is_open(), "normal 제작 opens the original Production window"):
			await _finish(native)
			return
		original_id = native_window.selected()
		await _tap(_source_tab(native_window, "Search"))
	if not _check(_listing() != null and hud.workspace.visible, "recipe browser is visible after opening search"):
		await _finish(native)
		return
	var favorite: Button = hud.workspace.find_child("CraftFavoriteRecipe", true, false)
	if not _check(favorite != null, "the browser can register recipes"):
		await _finish(native)
		return
	if native:
		_check(not native_window.is_open() and _ids() == [original_id], "search opens one current recipe and does not rebuild the entire catalog")
	_check(not world.ui_preferences.has(FAVORITES_KEY), "opening or searching an old save does not create a preference")
	var sample := _same_output_sample()
	if not _check(not sample.is_empty() and world.crafting.recipes.has(TEST_CRAFT_ID), "the actual 523 recipe registry contains distinct recipes for one output and the helmet fixture"):
		await _finish(native)
		return
	await _submit("  " + str(sample.query) + "  ", native)
	_check(_ids().has(sample.first) and _ids().has(sample.second), "item-name search finds both real recipes for the same output")
	if native:
		var no_row_images: bool = true
		for index: int in _listing().item_count:
			no_row_images = no_row_images and _listing().get_item_icon(index) == null
		_check(no_row_images, "lookup results prepare no recipe-row textures")
	await _select(sample.second)
	var unchanged: Array = [world.inventory.duplicate(true), world.gold, world.crafting_log.duplicate(true)]
	var save_requests: int = world.deferred_save.requests
	await _tap(favorite)
	var expected := {sample.second:true}
	_check(world.ui_preferences.get(FAVORITES_KEY) == expected and favorite.text == "즐겨찾기 해제", "one tap bookmarks only the selected recipe ID")
	_check([world.inventory, world.gold, world.crafting_log] == unchanged, "bookmarking does not debit or grant items, spend currency or log a craft")
	_check(world.deferred_save.pending() and world.deferred_save.requests == save_requests + 1, "registration requests the existing deferred save")
	_check(world._save_game(true) == OK, "the normal character save accepts the preference")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	_check(saved.get("ui_preferences", {}).get(FAVORITES_KEY) == expected, "verified exact recipe ID in the saved preferences")
	world.ui_preferences.erase(FAVORITES_KEY)
	world._load_game(true)
	await _frames()
	_check(world.ui_preferences.get(FAVORITES_KEY) == expected, "normal load restores the saved recipe")
	if native:
		await _tap(hud.workspace.find_child("CraftReturnToProduction", true, false))
		_check(native_window.is_open() and native_window.selected() == original_id, "return to basic crafting restores the previous recipe")
		await _tap(_source_tab(native_window, "Bookmark"))
	else:
		hud.open_crafting()
		await _frames()
		await _tap(hud.workspace.find_child("CraftFavoritesOnly", true, false))
	if not _check(_listing() != null and _ids() == [sample.second], "favorites route lists only the bookmarked ID"):
		await _finish(native)
		return
	await _tap(hud.workspace.find_child("CraftFavoriteRecipe", true, false))
	var execute: Button = hud.workspace.find_child("CraftExecute", true, false)
	_check(_ids().is_empty() and execute.disabled and world.ui_preferences.get(FAVORITES_KEY) == {}, "removing the only bookmark clears the list and prevents a stale craft")
	await _tap(hud.workspace.find_child("CraftFavoritesOnly", true, false))
	await _submit("없는 제작법 1234", native, true)
	_check(_ids().is_empty() and execute.disabled, "empty search has no selected transaction")
	await _submit(str(world.crafting.recipes[TEST_CRAFT_ID].name), native)
	_check(_ids().has(TEST_CRAFT_ID), "recipe-name search finds an active source recipe")
	await _craft_helmet()
	await _check_compact(native, native_window)
	await _finish(native)

func _craft_helmet() -> void:
	world.inventory[IRON] = 20
	world.inventory.erase(HELMET)
	world.gold = 10500
	await _select(TEST_CRAFT_ID)
	var execute: Button = hud.workspace.find_child("CraftExecute", true, false)
	_check(world._craft_quote(TEST_CRAFT_ID, 1).get("ok", false) and not execute.disabled, "an admitted recipe uses the real quote and execute control")
	await _tap(execute)
	await _tap(hud.find_child("CancelTransaction", true, false))
	_check(world.gold == 10500 and world.inventory.get(IRON) == 20 and not world.inventory.has(HELMET), "canceling the existing confirmation spends nothing")
	await _tap(execute)
	await _tap(hud.find_child("ConfirmTransaction", true, false))
	_check(world.gold == 500 and world.inventory.get(IRON, 0) == 0 and world.inventory.get(HELMET) == 1, "confirmation uses the ordinary transaction and saves one helmet with exact cost and materials")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	var history: Array = saved.get("crafting_log", [])
	var last: Dictionary = history.back() if not history.is_empty() else {}
	_check(last.get("recipe_id") == TEST_CRAFT_ID and last.get("output") == HELMET and last.get("gold") == 10000,
		"the normal transaction saves exact result identity and fee")

func _check_compact(native: bool, window: RefCounted) -> void:
	root.size = Vector2i(960, 432)
	await _frames(5)
	if native:
		await _tap(_source_tab(window, "Search"))
	var field: LineEdit = hud.workspace.find_child("CraftNameFilter", true, false)
	var filter: Button = hud.workspace.find_child("CraftFavoritesOnly", true, false)
	_check(is_instance_valid(field) and field.size.x >= 64, "compact landscape leaves a usable text field")
	await _tap(filter)
	_check(is_instance_valid(filter) and filter.button_pressed, "favorites filter remains touchable in compact landscape")

func _finish(native: bool) -> void:
	world.queue_free()
	await _frames(2)
	print("CRAFT_LOOKUP_RESULT ", JSON.stringify({"native":native, "checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
