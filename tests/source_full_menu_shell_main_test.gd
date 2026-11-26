extends SceneTree
## User's 2048×919 route: HUD menu tap, authored tray, tile scroll/navigation,
## and authored close. CI also exercises the compact pack-free fallback.
const QA=preload("res://tests/qa_class_selection.gd")
const TOP=preload("res://scripts/ui/original_ui/source_main_menu_bindings.gd")
var checks: int=0
var failures: Array[String]=[]

func _initialize() -> void: run.call_deferred()

func ck(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);printerr("SOURCE_FULL_MENU_SHELL_FAIL: "+label)
	return ok

func frames(count: int=4) -> void:
	for i: int in count:await process_frame

static func area(scene: Node2D, offset: int) -> Control:
	var target: Node=scene.source_nodes.get(offset) if is_instance_valid(scene) else null
	var b: Node=target.get_meta("source_button") if is_instance_valid(target) and target.has_meta("source_button") else null
	return b.get("_input_area") if is_instance_valid(b) else null

func tap(control: Control, index: int=5) -> bool:
	if not ck(is_instance_valid(control) and control.is_visible_in_tree(),"visible tap target"):return false
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	for pressed: bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=index;event.pressed=pressed;event.position=point
		root.push_input(event,true)
		await frames(2)
	return true

func swipe_from(control: Control) -> void:
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*.5)
	var touch:=InputEventScreenTouch.new();touch.index=7;touch.position=point;touch.pressed=true
	root.push_input(touch,true)
	await process_frame
	for i: int in range(1,7):
		var drag:=InputEventScreenDrag.new();drag.index=7;drag.position=point-Vector2(0,16*i);drag.relative=Vector2(0,-16)
		root.push_input(drag,true)
		await process_frame
	var release:=InputEventScreenTouch.new();release.index=7;release.position=point-Vector2(0,96)
	root.push_input(release,true)
	await frames()

func source_route(h: Node) -> void:
	var controller: Node=h.original_main_ui_controller
	if not ck(is_instance_valid(controller),"exact UI pack installed"):return
	var open_button: Control=area(controller._menu_scene,TOP.ALL)
	if not await tap(open_button):return
	var shell: Node2D=h.menu_original_shell.get("scene")
	if not ck(h.active_section=="menu" and is_instance_valid(shell) and shell.is_visible_in_tree(),"actual Hud_TopMenu Btn_All opens the original tray"):return
	ck(shell.source_member==TOP.MEMBER and shell.playback_status().frame==30,"authored Ani_On opened endpoint, not default transparent setup")
	var bg: Node2D=shell.source_nodes[39228]
	const SOURCE_PNG: Dictionary={"path":"Hud_MenuOpenImg.png","plistFile":"UI_Resource/Atlas_Hud.plist","resourceType":1}
	var pile: Array=bg.find_children("*","Sprite2D",true,false)
	var exact: Texture2D=controller._pack.texture(SOURCE_PNG,true)
	ck(bg.is_visible_in_tree() and bg.get_meta("source_rgba")[3]==255 and exact!=null and not pile.is_empty() and pile.all(func(node: Sprite2D) -> bool:return node.texture==exact),"exact MenuBG texture and fully visible source pose")
	ck(h.workspace.get_theme_stylebox("panel") is StyleBoxEmpty and not h.workspace._window_title_row.visible and not h.menu_category_filter.visible,"no handmade brown shell or duplicate heading")
	var view: Rect2=h.menu_scroll_view.get_global_rect()
	var authored: Rect2=controller._full_menu_node_rect(shell,35788)
	ck(authored.size==Vector2(350,470) and view.is_equal_approx(shell.get_global_transform()*authored),"active scroll is clipped by the exact source ListView rectangle")
	var transform: Control=h.menu_page.find_child("MenuTile_변신",true,false)
	ck(is_instance_valid(transform) and transform.position.is_equal_approx(Vector2(140,0)) and h.menu_original_spaces[0].visible,"source cells remain in authored positions")
	var scroll_start: Control=h.menu_page.find_child("MenuTile_domination_stone",true,false)
	if not ck(is_instance_valid(scroll_start),"visible original tile is a scroll source"):return
	await swipe_from(scroll_start)
	ck(h.menu_scroll_view.scroll_vertical>0 and h.active_section=="menu","touch drag starting on a tile scrolls without triggering that tile")
	if not await tap(area(shell,36572)):return
	ck(not h.workspace.visible and not shell.is_visible_in_tree(),"authored Btn_All_Off closes the tray without opening anything underneath")
	if not await tap(open_button):return
	ck(h.menu_original_shell.scene==shell and h.menu_scroll_view.scroll_vertical==0,"same original tray is reopened at top")
	if not await tap(transform):return
	ck(h.active_section=="변신" and not shell.is_visible_in_tree(),"original Transform tile reaches the existing live browse route")

func fallback_route(h: Node) -> void:
	h.toggle_menu();await frames()
	ck(h.menu_original_shell.is_empty() and h.menu_category_filter.visible and h.workspace._window_title_row.visible,"fallback keeps its reachable navigation when there is no verified original tray")
	var cells: Array=h.menu_page.find_child("MenuGrid",true,false).get_children().filter(func(cell: Control) -> bool:return cell.visible)
	ck(cells.size()==h.menu_tiles.size() and h.menu_original_spaces.all(func(space: Control) -> bool:return not space.visible),"fallback shows only live tiles, no holes")
	for index: int in cells.size():
		ck(cells[index].position.is_equal_approx(Vector2((index%5)*70,floori(float(index)/5.0)*67)),"fallback tile reaches the next cell")
	if await tap(h.workspace.find_child("CloseWindow",true,false)):
		ck(not h.workspace.visible,"fallback touch still closes")

func run() -> void:
	root.size=Vector2i(2048,919)
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world);current_scene=world;world.set_process(false);world.save_timer=-100000
	ck(QA.enter_game(world),"actual Main enters")
	await frames()
	world.player.set_physics_process(false);world.field_population.set_process(false)
	var original: bool=not OS.get_environment("TWILIGHT_SOURCE_UI").is_empty()
	if original:await source_route(world.hud)
	else:await fallback_route(world.hud)
	world.queue_free();await frames()
	print("SOURCE_FULL_MENU_SHELL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"original_checked":original}))
	quit(0 if failures.is_empty() else 1)
