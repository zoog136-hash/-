extends "res://tests/quickslot_register523_main_test.gd"
## Actual Main, with the selected original UI pack or --without-ui.
const Chrome = preload("res://scripts/ui/original_ui/source_common_chrome.gd")

func run() -> void:
	root.size = Vector2i(2048,919) if "--wide" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	if not check(not FileAccess.file_exists("user://twilight_v20_save.json"),"fresh disposable Main profile"):
		_finish()
		return
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer = -100000
	if check(QA.enter_game(world,"기사"),"ordinary Main class entry"):
		await frames()
		var hud: Node = world.hud
		var installed: bool = "--without-ui" not in OS.get_cmdline_user_args()
		if check(is_instance_valid(hud.original_main_ui_controller) == installed,"expected original UI selection"):
			var before: String = FileAccess.get_sha256(world.save_path())
			await _combat_log(hud,installed)
			await _local_windows(hud,installed)
			await _confirmations(hud,installed)
			check(FileAccess.get_sha256(world.save_path()) == before,"presentation navigation and modal callbacks preserve the save")
			if installed: await _half_elixir(world,hud)
		hud._close_workspace()
	world.queue_free()
	await frames()
	_finish()

func _original_style(style: StyleBox, offset: int) -> bool:
	return style is StyleBoxTexture and style.texture != null and style.get_meta("original_ui_source",{}).get("node_offset") == offset

func _local_windows(hud: Node, installed: bool) -> void:
	for route: String in ["sell","combinations","field_activities523","growth96","아이템"]:
		hud._navigate(route)
		await frames(2)
		check(hud.workspace.visible,"local screen retains its functional owner: "+route)
		check(_original_style(hud.workspace.get_theme_stylebox("panel"),8940) == installed,"original common frame when selected: "+route)
		if route == "sell":
			check(is_instance_valid(hud.transaction_view) and hud.transaction_view.search.is_visible_in_tree(),"sale list and search remain reachable")
			check(_original_style(hud.transaction_view.action.get_theme_stylebox("normal"),1484) == installed,"primary sale action uses the common original button")
			check(_original_style(hud.transaction_view.listing.get_theme_stylebox("panel"),6948) == installed,"sale inventory uses the original inset")
			check(_original_style(hud.companion_window.get_theme_stylebox("panel"),8940) == installed,"companion bag uses the same original frame")
		hud._close_workspace()

func _combat_log(hud: Node, installed: bool) -> void:
	hud.append_log("기존 전투 기록")
	hud.open_combat_log()
	await frames()
	var history: RichTextLabel = hud.combat_log_view
	if not check(is_instance_valid(history) and history.is_visible_in_tree() and history.text.contains("기존 전투 기록"),"normal combat log opens with prior records"): return
	for index: int in range(125): hud.append_log("전투 기록 [%d]" % index)
	check(hud.log_history.size() == 120 and history.text.begins_with("전투 기록 [5]") and history.text.ends_with("전투 기록 [124]"),"live text synchronously keeps the same 120-entry cap")
	await frames()
	if installed:
		var controller: Node = hud.original_main_ui_controller
		if check(controller.feature_window_is_open("combat_log"),"authored chat shell is mounted through the real log entry"):
			var log_window: RefCounted = controller.feature_window("combat_log")
			var location: Dictionary = log_window._locate(log_window._scene,log_window._out,"Btn_Close")
			var close: Control = location.player.source_nodes[location.offset].get_meta("source_button")._input_area
			check(log_window._scene.source_member == Chrome.CHAT and history.get_theme_font("normal_font") == controller.original_font("Font/font_B.ttf"),"log uses the selected authored scene and font")
			var last_scroll: float = history.get_v_scroll_bar().value
			var point: Vector2 = center(history)
			await gesture(point,point+Vector2(0,120),0.0)
			check(history.get_v_scroll_bar().value < last_scroll,"real screen drag scrolls the published transcript (%s → %s)" % [last_scroll,history.get_v_scroll_bar().value])
			await tap(center(close))
			check(not controller.feature_window_is_open("combat_log") and hud.combat_log_view == null,"authored Close consumes the screen tap and clears the current transcript")
	hud._close_workspace()

func _confirmations(hud: Node, installed: bool) -> void:
	var result: Array[int] = []
	var modal: Control = hud.confirm_action("수량 확인","확인할 수량을 정하세요.","확인",func(count: int) -> void: result.append(count),5)
	check(_original_style(modal.panel.get_theme_stylebox("panel"),8940) == installed,"quantity dialog uses the original frame where available")
	check(_original_style(modal.cancel_button.get_theme_stylebox("normal"),2220) == installed,"cancel uses its original red action")
	check(_original_style(modal.confirm_button.get_theme_stylebox("normal"),1484) == installed,"accept uses its original blue action")
	modal.quantity.value = 4
	modal.cancel_button.pressed.emit()
	await frames(2)
	check(result.is_empty(),"cancelling never calls the selected action")
	modal = hud.confirm_action("수량 확인","확인할 수량을 정하세요.","확인",func(count: int) -> void: result.append(count),5)
	modal.quantity.value = 3
	modal.confirm_button.pressed.emit()
	modal.confirm_button.pressed.emit()
	await frames(2)
	check(result == [3],"one confirmation adopts the chosen quantity once")

func _half_elixir(world: TwilightWorld, hud: Node) -> void:
	var feature: String = "half_elixir"
	var controller: Node = hud.original_main_ui_controller
	hud.open_half_elixir()
	await frames(2)
	if not check(controller.feature_window_is_open(feature),"normal half-elixir menu links the source context"): return
	var runtime: RefCounted = world.half_elixir
	var item: Dictionary = {}
	for row: Dictionary in runtime.source.charges.values():
		if not row.get("blocked",true) and int(row.get("amount",0)) > 0:
			item = row
			break
	if not check(not item.is_empty(),"an eligible original half-elixir item is present"): return
	hud._close_workspace()
	var name_value: String = item.name
	world.level = maxi(int(world.level),int(item.raw.LevelLimitMin))
	world.inventory[name_value] = 1
	if not check(world._save_game(true) == OK,"isolated legacy half-elixir stock is saved"): return
	var saved: String = FileAccess.get_sha256(world.save_path())
	var points: int = int(runtime.state.points)
	hud.inventory_item_activated.emit(name_value)
	await frames()
	var modal: Control = hud.get_node_or_null("Root/TwilightConfirmation")
	if not check(controller.feature_window_is_open(feature) and is_instance_valid(modal),"using the legacy bag stack opens its original elixir window and confirmation"): return
	modal.cancel_button.pressed.emit()
	await frames(2)
	check(FileAccess.get_sha256(world.save_path()) == saved and int(world.inventory[name_value]) == 1,"bag cancellation preserves the exact elixir stock and save")
	hud.inventory_item_activated.emit(name_value)
	await frames()
	modal = hud.get_node_or_null("Root/TwilightConfirmation")
	if not check(is_instance_valid(modal),"the same held item can be selected again"): return
	modal.confirm_button.pressed.emit()
	modal.confirm_button.pressed.emit()
	await frames()
	check(int(runtime.state.points) == points + int(item.amount) and int(world.inventory.get(name_value,0)) == 0,"source-directed confirmation applies and consumes exactly once")
	hud._close_workspace()

func _finish() -> void:
	print("ORIGINAL_SHARED_CHROME_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
