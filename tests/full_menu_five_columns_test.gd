extends SceneTree
## 전체 메뉴 as the original 523 grid (user decision 2026-11-22 "원본처럼 5열로
## 넓히기"): the client's Hud_TopMenu ListView is 350x470 of 70x67 MainMenu_*
## panels with no item margin and MainMenuUIButtons places them in FixedColumn
## 1-5 / FixedRow 1-7. On the phone (2408x1080) and the other screens below the
## menu shows five columns and seven full rows (35 slots) without scrolling,
## no tile is cut or overlaps another, the rest is reached by scrolling, the
## original exact row/column positions and the 저장 tile stay, retired tiles stay gone, and a real
## InputEventScreenTouch opens every available window (a missing original
## expedition shows its reason and preserves this menu instead).
const QA = preload("res://tests/qa_class_selection.gd")
const SCREENS: Array = [[Vector2i(2408,1080),null],[Vector2i(1280,720),null],[Vector2i(1920,1080),null],[Vector2i(2400,1080),Rect2(60,0,1160,720)],[Vector2i(1280,720),Rect2(0,40,1280,640)]]
const TWILIGHT_ONLY: Array[String] = ["character","inventory","skills","quests","map","shop","enhance","warehouse","auto"]
const GONE: Array[String] = ["spell_groups","protection523","clan_emblem523","growth96","sell"]
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FULL_MENU_FIVE_COLUMNS_FAIL: " + label)

func _initialize() -> void: call_deferred("run")

func frames(count: int = 3) -> void:
	for frame: int in count: await process_frame

func touch(control: Control) -> void:
	var at: Vector2 = root.get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))
	var down := InputEventScreenTouch.new(); down.index = 0; down.pressed = true; down.position = at
	Input.parse_input_event(down)
	await frames(2)
	var up := InputEventScreenTouch.new(); up.index = 0; up.pressed = false; up.position = at
	Input.parse_input_event(up)
	await frames(4)

func ids(hud: Node) -> Array[String]:
	var result: Array[String] = []
	for tile: Control in hud.menu_tiles: result.append(str(tile.name).trim_prefix("MenuTile_"))
	return result

func run() -> void:
	var hud_script: Script = load("res://scripts/ui/renewal_hud.gd")
	var constants: Dictionary = hud_script.get_script_constant_map()
	check(int(constants.get("MENU_GRID_COLUMNS", 0)) == 5 and constants.get("MENU_TILE_SIZE", Vector2.ZERO) == Vector2(70,67) and int(constants.get("MENU_VISIBLE_ROWS", 0)) == 7, "the original grid constants: 5 columns, 70x67, 7 rows")
	root.size = SCREENS[0][0]; DisplayServer.window_set_size(root.size)
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "actual Main class confirmation")
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.save_timer = -100000.0
	await frames(6)
	var hud: Node = world.hud
	for screen: Array in SCREENS: await layout(hud, screen[0], screen[1])
	root.remove_meta("twilight_test_safe_rect")
	root.size = SCREENS[0][0]; DisplayServer.window_set_size(root.size)
	await frames(4)
	await order_and_retired(hud)
	await scrolling(hud)
	await every_tile_opens(hud)
	world.queue_free()
	await process_frame
	print("FULL_MENU_FIVE_COLUMNS_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func open_menu(hud: Node) -> void:
	if str(hud.active_section) != "": hud.call("_close_workspace")
	await frames(3)
	hud.toggle_menu(); await frames(6)

func layout(hud: Node, size: Vector2i, safe: Variant) -> void:
	var tag: String = "%dx%d%s" % [size.x, size.y, "" if safe == null else " safe " + str(safe)]
	if safe == null: root.remove_meta("twilight_test_safe_rect")
	else: root.set_meta("twilight_test_safe_rect", safe)
	root.size = size; DisplayServer.window_set_size(size)
	await frames(4)
	await open_menu(hud)
	var scroll: ScrollContainer = hud.menu_scroll_view
	var grid: GridContainer = hud.workspace.find_child("MenuGrid", true, false) as GridContainer
	check(grid != null and grid.columns == 5 and grid.get_theme_constant("h_separation") == 0 and grid.get_theme_constant("v_separation") == 0, tag + ": five columns with no gap")
	if grid == null: return
	var view: Rect2 = scroll.get_global_rect()
	var window: Rect2 = hud.workspace.get_global_rect()
	var screen: Rect2 = root.get_visible_rect()
	check(screen.encloses(window), tag + ": the menu window is on screen " + str(window))
	var unit: float = hud.workspace.get_global_transform().get_scale().y
	var rows: float = view.size.y / (67.0 * unit)
	check(rows >= 7.0 - 0.01 and rows < 8.0, tag + ": seven full rows on screen (%.2f)" % rows)
	check(view.size.x >= grid.get_global_rect().size.x and grid.get_global_rect().position.x >= view.position.x - 0.5 and grid.get_global_rect().end.x <= view.end.x + 0.5, tag + ": the five columns fit the list width")
	var first: int = 0
	var rects: Array[Rect2] = []
	for tile: Control in grid.get_children():
		if not tile.visible: continue
		var rect: Rect2 = tile.get_global_rect()
		check(tile.size == Vector2(70,67), tag + ": " + str(tile.name) + " is a 70x67 cell " + str(tile.size))
		for other: Rect2 in rects:
			if rect.intersection(other).get_area() > 0.5:
				check(false, tag + ": " + str(tile.name) + " overlaps another tile")
				break
		rects.append(rect)
		if view.encloses(rect.grow(-0.25)): first += 1
		for child: Node in tile.get_children():
			if child is Label and (child as Label).visible:
				var caption: Label = child
				check(caption.get_line_count() <= caption.get_visible_line_count() and caption.get_minimum_size().x <= caption.size.x + 0.5, tag + ": " + str(tile.name) + " caption is not cut")
	check(first == 35, tag + ": 35 original cells (including reserved spaces) on the first screen (%d)" % first)

func order_and_retired(hud: Node) -> void:
	await open_menu(hud)
	var shown: Array[String] = ids(hud)
	var grid: Control=hud.workspace.find_child("MenuGrid",true,false)
	var source: Dictionary={
		0:"crafting",1:"exchange",2:"변신",3:"마법인형",4:"성물",
		5:"source_dungeons",8:"skill_card523",9:"equipment_collections",10:"clan523",
		16:"refine523",18:"guardians",19:"emblems",20:"half_elixir",22:"weapon_mastery",
		23:"totems",24:"domination_stone",25:"titles",28:"settings",
	}
	var original: bool=hud.menu_original_shell.get("ok",false)
	var visible_cells: Array=grid.get_children().filter(func(cell: Control) -> bool:return cell.visible)
	if original:
		for index: int in 35:
			var cell: Control=visible_cells[index]
			var id:String=str(source.get(index,""))
			if id.is_empty():
				check(str(cell.name)=="OriginalMenuSpace_%d"%index and cell.mouse_filter==Control.MOUSE_FILTER_IGNORE and not cell is Button,"an original unavailable or empty cell cannot be filled or tapped: %d"%index)
			else:
				check(str(cell.name)=="MenuTile_"+id and cell is Button,"live original tile held its row/column: "+id)
			check(cell.position.is_equal_approx(Vector2((index%5)*70,floori(float(index)/5.0)*67)),"actual laid out original grid index %d"%index)
	else:
		check(visible_cells.size()==shown.size() and visible_cells.size()>=35,"fallback has every live tile and no visible holes")
		for index: int in visible_cells.size():
			var cell: Control=visible_cells[index]
			check(cell is Button and cell.position.is_equal_approx(Vector2((index%5)*70,floori(float(index)/5.0)*67)),"compact fallback has a live button every cell: %d"%index)
		var ordered: Array=[]
		for id: String in source.values():ordered.append(id)
		check(shown.slice(0,ordered.size())==ordered,"fallback compacts without changing original relative order")
	check(not shown.has("monsterbook523"), "the paused monster book tile is not shown")
	check(shown.has("save"), "the 저장 tile stays")
	for id: String in GONE: check(not shown.has(id), id + " stays out of the menu")
	for id: String in TWILIGHT_ONLY:
		var cell: Node=grid.get_node_or_null("MenuTile_"+id)
		check(cell!=null and cell.get_index()>=35,id+" is below the seven original rows")

func scrolling(hud: Node) -> void:
	await open_menu(hud)
	var scroll: ScrollContainer = hud.menu_scroll_view
	var view: Rect2 = scroll.get_global_rect()
	var last: Control = hud.menu_tiles[hud.menu_tiles.size() - 1]
	check(not view.encloses(last.get_global_rect()), "the last tile needs a scroll")
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	scroll.scroll_vertical = int(bar.max_value); await frames(3)
	check(view.encloses(last.get_global_rect().grow(-0.25)), "scrolled to the end the last tile is whole")
	scroll.scroll_vertical = 0; await frames(3)
	check(view.encloses(hud.menu_tiles[0].get_global_rect().grow(-0.25)), "back at the top the first tile is whole")
	hud.call("_select_menu_category", 1); await frames(3)
	var filtered: Array = hud.menu_tiles.filter(func(tile: Control) -> bool: return tile.visible)
	check(filtered.size() > 0 and filtered.all(func(tile: Control) -> bool: return tile.size == Vector2(70,67)) and hud.menu_original_spaces.all(func(space:Control)->bool:return not space.visible), "the legacy category function retains compact 70x67 cells, without reserved spaces")
	hud.call("_select_menu_category", 0); await frames(3)

## Every tile by a real touch (the save handler is held off: CI shares user://).
func every_tile_opens(hud: Node) -> void:
	var held: Array = hud.save_pressed.get_connections()
	for connection: Dictionary in held: hud.save_pressed.disconnect(connection.callable)
	var saved: Array = [0]
	var on_save := func() -> void: saved[0] += 1
	hud.save_pressed.connect(on_save)
	var mastery: Array = [0]
	var on_mastery := func() -> void: mastery[0] += 1
	hud.weapon_mastery_requested.connect(on_mastery)
	await open_menu(hud)
	var all: Array[String] = ids(hud)
	var opened: Array[String] = []
	for id: String in all:
		await open_menu(hud)
		var tile: Control = hud.workspace.find_child("MenuTile_" + id, true, false) as Control
		if tile == null:
			check(false, id + " tile missing")
			continue
		hud.menu_scroll_view.ensure_control_visible(tile); await frames(3)
		if id == "expedition": hud.message_label.text = ""
		await touch(tile)
		var section: String = str(hud.active_section)
		var ok: bool = (saved[0] == 1) if id == "save" else (section != "menu" and section != "")
		# With the original UI pack 월드맵 is the client's Map_All over the field.
		# Without it 무기 숙련 hands over to the existing mastery panel.
		if id == "weapon_mastery" and not ok: ok = mastery[0] > 0
		if id == "map" and not ok: ok = is_instance_valid(hud.original_main_ui_controller) and hud.original_main_ui_controller.world_map_is_open()
		if id == "expedition":
			var controller: Node = hud.original_main_ui_controller
			var has_window: bool = is_instance_valid(controller) and controller.feature_window_available("doll_explore")
			var expected: String = ""
			if not has_window: expected = "마법인형 탐험 원본 화면 리소스가 없습니다."
			elif not hud.get_parent().get_expedition_catalog().ready(): expected = "마법인형 탐험 원본 데이터가 없습니다."
			if expected.is_empty():
				ok = section == "doll_explore" and controller.feature_window_is_open("doll_explore")
			else:
				ok = section == "menu" and hud.workspace.visible and hud.message_label.text == expected
		check(ok, "a touch on " + id + " opens it or shows the exact missing original dependency (section " + section + ")")
		if ok: opened.append(id)
		if id == "save": saved[0] = 0
	print("FULL_MENU_FIVE_COLUMNS_OPENED " + JSON.stringify({"tiles":all.size(),"opened":opened.size()}))
	check(opened.size() == all.size(), "every tile opened (%d/%d)" % [opened.size(), all.size()])
	hud.save_pressed.disconnect(on_save)
	hud.weapon_mastery_requested.disconnect(on_mastery)
	for connection: Dictionary in held: hud.save_pressed.connect(connection.callable)
	if str(hud.active_section) != "": hud.call("_close_workspace")
	await frames(3)
