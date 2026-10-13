extends SceneTree

const UI = preload("res://scripts/ui/renewal_theme.gd")
const RenewalWindow = preload("res://scripts/ui/renewal_window.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("LINEAGEM_UI_FAIL: " + description)

func _run() -> void:
	root.size = Vector2i(1280,720)
	await process_frame
	var theme: Theme = UI.make_theme()
	_check(theme.has_stylebox("panel","PanelContainer"),"shared panel theme")
	_check(theme.has_stylebox("normal","Button"),"shared button theme")
	_check(theme.has_stylebox("panel","ItemList"),"codex list frame")
	_check(theme.has_stylebox("separator","HSeparator"),"gold sectional divider")
	_check(theme.has_stylebox("fill","ProgressBar"),"status bar style")
	var panel: StyleBoxFlat = UI.chrome_panel()
	_check(panel.border_width_top == 2 and panel.border_width_left == 1,"thin game-window rim")
	_check(UI.slot_frame(UI.GOLD,true).border_color == UI.GOLD,"selected item border")
	var window: PanelContainer = RenewalWindow.new()
	root.add_child(window)
	await process_frame
	var title: Control = window.find_child("WorkspaceTitleDragArea",true,false) as Control
	var nav: ScrollContainer = window.find_child("WorkspaceNavigationScroll",true,false) as ScrollContainer
	var crest: Control = window.find_child("DecorativeFrame",true,false) as Control
	var compact: Button = window.find_child("CompactMenuButton",true,false) as Button
	_check(title != null and title.mouse_filter == Control.MOUSE_FILTER_STOP,"title drag zone preserved")
	_check(nav == null,"content windows do not include dashboard navigation")
	_check(crest == null,"no ornamental header occupying content area")
	# The shortcut is intentionally constructed, but only shown when a real
	# game-menu receiver is connected. Its mere existence is not a sidebar.
	_check(compact != null and not compact.visible,"unconnected game-menu shortcut stays hidden")
	window.open("inventory","인벤토리","선택한 장비를 확인합니다.")
	var active: Button = window.find_child("Nav_inventory",true,false) as Button
	_check(active == null and window.current_section == "inventory","inventory has its own window profile")
	_check(window.size.x <= 378 and window.position.x > 800,"inventory is a right shelf")
	_check(window.find_child("CloseWindow",true,false) != null,"close and Esc action retained")
	_check(compact != null and not compact.visible,"opening an unconnected window does not expose dead navigation")
	var navigated: Array[String] = []
	window.connect("navigate",func(section: String) -> void: navigated.append(section))
	window.open("inventory","인벤토리","")
	_check(compact != null and compact.visible,"connected inventory can return to the actual menu")
	if compact != null: compact.pressed.emit()
	_check(navigated == ["menu"],"shortcut emits the actual game-menu route exactly once")
	window.open("menu","메뉴","")
	_check(compact != null and not compact.visible,"menu does not link back to itself")
	var teleport: Button = window.find_child("MenuTeleportShortcut",true,false) as Button
	_check(teleport != null and teleport.visible,"regional teleport shortcut stays in the real menu")
	window.open("class_select","직업 선택","")
	_check(compact != null and not compact.visible and teleport != null and not teleport.visible,"class selection exposes no gameplay shortcuts")
	window.queue_free()
	await process_frame
	if failures.is_empty():
		print("LINEAGEM_UI_VISUAL_OK")
		quit(0)
	else:
		print("LINEAGEM_UI_VISUAL_FAILED: %d" % failures.size())
		quit(1)
