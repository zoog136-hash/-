extends SceneTree

# The full menu is built once and re-mounted. Reopening must reuse the same
# tiles, start on the full category at the top, and keep tiles working.
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("MENU_PAGE_REUSE_FAIL: " + message)

func _frames(count: int = 3) -> void:
	for frame: int in range(count): await process_frame

func _tiles(hud: Node) -> Array[Node]:
	var grid: Node = hud.workspace.find_child("MenuGrid",true,false)
	return [] if grid == null else grid.get_children()

func _run() -> void:
	root.size = Vector2i(1280,720)
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await _frames(4)
	check(QA.enter_game(world),"real class picker enters game")
	world.set_process(false)
	world.set_physics_process(false)
	world.source_save_blocked = true
	world.save_timer = -10000
	var hud: Node = world.hud
	var started: int = Time.get_ticks_usec()
	hud.toggle_menu()
	var first_open_usec: int = Time.get_ticks_usec() - started
	await _frames()
	var first_tiles: Array[Node] = _tiles(hud)
	check(first_tiles.size() == 20,"menu shows 20 tiles once (got %d)" % first_tiles.size())
	check(hud.menu_tiles.size() == 20,"category filter tracks each tile once")
	var filter: OptionButton = hud.workspace.find_child("MenuCategoryFilter",true,false) as OptionButton
	check(filter != null,"category filter is mounted")
	if filter == null:
		_finish(world)
		return
	filter.select(3)
	filter.item_selected.emit(3)
	var shown: int = first_tiles.filter(func(tile: Node) -> bool: return (tile as Control).visible).size()
	check(shown > 0 and shown < 20,"category filter narrows tiles (shown %d)" % shown)
	hud.menu_scroll_view.scroll_vertical = 40
	hud.toggle_menu()
	await _frames()
	check(str(hud.active_section) != "menu","second toggle closes the menu")
	check(is_instance_valid(hud.menu_page),"closing parks the cached page instead of freeing it")
	started = Time.get_ticks_usec()
	hud.toggle_menu()
	var reopen_usec: int = Time.get_ticks_usec() - started
	await _frames()
	var reopened: Array[Node] = _tiles(hud)
	check(reopened.size() == 20 and reopened[0] == first_tiles[0],"reopen reuses the same tile nodes")
	check(filter.selected == 0,"reopen resets the filter to the full list")
	check(reopened.all(func(tile: Node) -> bool: return (tile as Control).visible),"reopen shows every tile")
	check(hud.menu_scroll_view.scroll_vertical == 0,"reopen starts at the top")
	var tile: Button = hud.workspace.find_child("MenuTile_settings",true,false) as Button
	check(tile != null,"settings tile is reachable after reopen")
	if tile != null:
		tile.pressed.emit()
		await _frames()
		check(str(hud.active_section) == "settings","reused tile still navigates")
		hud.toggle_menu()
		await _frames()
		check(_tiles(hud).size() == 20 and str(hud.active_section) == "menu","menu reopens from another window")
	print("MENU_PAGE_REUSE_TIMING first_open_usec=%d reopen_usec=%d" % [first_open_usec,reopen_usec])
	_finish(world)

func _finish(world: Node) -> void:
	world.queue_free()
	await process_frame
	print("MENU_PAGE_REUSE_OK checks=%d" % checks if failures.is_empty() else "MENU_PAGE_REUSE_FAILED %d/%d" % [failures.size(),checks])
	quit(0 if failures.is_empty() else 1)
